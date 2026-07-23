@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class AgentTaskNotificationTests: XCTestCase {
    func testFirstTaskOffersConsentWithoutRequestingPermissionOrBlocking() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore()
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent
        )
        fixture.viewModel.draft = "处理第一件真实任务"

        fixture.viewModel.sendModelDependentMessage()

        XCTAssertTrue(fixture.viewModel.isAgentNotificationConsentPresented)
        XCTAssertEqual(notifications.authorizationRequestCount, 0)
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(fixture.generation.callCount, 1)

        fixture.viewModel.declineAgentTaskNotifications()
        XCTAssertEqual(consent.decision, .declined)
        XCTAssertFalse(fixture.viewModel.isAgentNotificationConsentPresented)

        fixture.viewModel.draft = "拒绝通知后继续处理第二件事"
        fixture.viewModel.sendModelDependentMessage()
        await fixture.viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(fixture.generation.callCount, 2)
        XCTAssertFalse(fixture.viewModel.isAgentNotificationConsentPresented)
        XCTAssertEqual(notifications.authorizationRequestCount, 0)
        XCTAssertTrue(notifications.requests.isEmpty)
    }

    func testAllowRequestsSystemPermissionOnlyAfterExplicitAction() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore()
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent
        )
        fixture.viewModel.draft = "先解释再请求通知权限"
        fixture.viewModel.sendModelDependentMessage()
        XCTAssertEqual(notifications.authorizationRequestCount, 0)

        fixture.viewModel.allowAgentTaskNotifications()
        try await waitUntil {
            notifications.authorizationRequestCount == 1
        }

        XCTAssertEqual(consent.decision, .allowed)
        XCTAssertFalse(fixture.viewModel.isAgentNotificationConsentPresented)
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(fixture.generation.callCount, 1)
    }

    func testPreviouslyAuthorizedCompletionSchedulesOneScopedNotification() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore(
            decision: .allowed
        )
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent
        )
        fixture.viewModel.draft = "完成后发送一条脱敏通知"

        fixture.viewModel.sendModelDependentMessage()
        await fixture.viewModel.waitForProviderRunToSettle()
        try await waitUntil { notifications.requests.count == 1 }

        XCTAssertFalse(fixture.viewModel.isAgentNotificationConsentPresented)
        XCTAssertEqual(notifications.authorizationRequestCount, 0)
        let request = try XCTUnwrap(notifications.requests.first)
        XCTAssertEqual(request.kind, .completed)
        XCTAssertEqual(
            request.taskID,
            try XCTUnwrap(fixture.completedTaskID())
        )
        XCTAssertFalse(request.body.contains("fixture-secret"))
        XCTAssertFalse(request.body.contains("API"))
    }

    func testDeliveryStoreClaimsEachStableIdentifierOnlyOnce() {
        let suiteName = "agent-task-notification-delivery-\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = UserDefaultsAgentTaskNotificationDeliveryStore(
            defaults: defaults
        )

        XCTAssertTrue(first.claim("task.revision.event"))
        XCTAssertFalse(first.claim("task.revision.event"))
        XCTAssertFalse(
            UserDefaultsAgentTaskNotificationDeliveryStore(defaults: defaults)
                .claim("task.revision.event")
        )

        first.release("task.revision.event")
        XCTAssertTrue(first.claim("task.revision.event"))
    }

    private func makeFixture(
        notifications: RecordingAgentTaskNotificationScheduler,
        consent: MemoryAgentTaskNotificationConsentStore
    ) throws -> (
        database: AppDatabase,
        viewModel: AppViewModel,
        generation: AppViewModelProviderGenerationService,
        completedTaskID: () -> UUID?
    ) {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(connection, makeCurrent: true)
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let generation = AppViewModelProviderGenerationService(
            events: [
                .textDelta("任务已经完成。"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 5,
                        outputTokens: 4,
                        totalTokens: 9
                    )
                )
            ]
        )
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            agentTaskNotifications: notifications,
            notificationConsentStore: consent,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        return (
            database,
            viewModel,
            generation,
            {
                guard let conversationID = viewModel.selectedConversationID else {
                    return nil
                }
                return try? database.s2ProviderTaskProjection(
                    conversationID: conversationID
                )?.task.id
            }
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<1_000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for notification state")
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-task-notification-\(UUID()).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}

@MainActor
private final class RecordingAgentTaskNotificationScheduler:
    AgentTaskNotificationScheduling
{
    var authorizationResult = false
    private(set) var authorizationRequestCount = 0
    private(set) var requests: [AgentTaskNotificationRequest] = []

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return authorizationResult
    }

    func schedule(_ request: AgentTaskNotificationRequest) async throws {
        guard authorizationResult else { return }
        requests.append(request)
    }
}

@MainActor
private final class MemoryAgentTaskNotificationConsentStore:
    AgentTaskNotificationConsentStoring
{
    private(set) var decision: AgentTaskNotificationConsentDecision

    init(decision: AgentTaskNotificationConsentDecision = .undecided) {
        self.decision = decision
    }

    func setDecision(_ decision: AgentTaskNotificationConsentDecision) {
        self.decision = decision
    }
}
