@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import UserNotifications
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
                && consent.decision == .allowed
        }

        XCTAssertEqual(consent.decision, .allowed)
        XCTAssertFalse(fixture.viewModel.isAgentNotificationConsentPresented)
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(fixture.generation.callCount, 1)
    }

    func testAuthorizationSuccessSchedulesTaskCompletedWhileSheetWasOpen() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        notifications.suspendsAuthorization = true
        let consent = MemoryAgentTaskNotificationConsentStore()
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent
        )
        fixture.viewModel.draft = "finish while notification permission is open"

        fixture.viewModel.sendModelDependentMessage()
        fixture.viewModel.allowAgentTaskNotifications()
        try await waitUntil { notifications.authorizationRequestCount == 1 }
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertTrue(notifications.requests.isEmpty)

        notifications.resolveAuthorization()
        try await waitUntil {
            consent.decision == .allowed && notifications.requests.count == 1
        }

        XCTAssertEqual(notifications.requests.first?.kind, .completed)
        XCTAssertEqual(
            notifications.requests.first?.taskID,
            fixture.completedTaskID()
        )
    }

    func testNotificationPermissionSceneRoundTripDoesNotInterruptProviderStream() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore()
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent,
            generationEvents: [.textDelta("权限确认期间仍在流式处理。")],
            hangsAfterEvents: true
        )
        fixture.viewModel.draft = "通知权限不能中断当前模型请求"

        fixture.viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(
            fixture.viewModel.modelConnectionSetup.pendingIntent
        )
        try await waitUntil {
            (try? fixture.database.providerRequest(intentID: intent.id)?.phase)
                == .streaming
        }
        XCTAssertEqual(
            fixture.viewModel.displayedProviderStreamText,
            "权限确认期间仍在流式处理。"
        )

        fixture.viewModel.allowAgentTaskNotifications()
        try await waitUntil {
            notifications.authorizationRequestCount == 1
        }
        fixture.viewModel.handleScenePhase(.inactive)
        try await Task.sleep(nanoseconds: 50_000_000)
        fixture.viewModel.handleScenePhase(.active)

        XCTAssertEqual(
            try fixture.database.providerRequest(intentID: intent.id)?.phase,
            .streaming
        )
        XCTAssertEqual(
            try fixture.database.agentTask(intentID: intent.id)?.status,
            .running
        )
        XCTAssertTrue(fixture.viewModel.isProviderRunActive)
        XCTAssertEqual(fixture.generation.callCount, 1)
        XCTAssertEqual(
            fixture.viewModel.displayedProviderStreamText,
            "权限确认期间仍在流式处理。"
        )
        XCTAssertFalse(
            fixture.viewModel.modelConnectionSetup.isPresented(
                for: intent.conversationID
            )
        )

        fixture.viewModel.handleScenePhase(.background)
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(
            try fixture.database.providerRequest(intentID: intent.id)?.phase,
            .outcomeUnknown
        )
    }

    func testDeniedSystemPermissionDoesNotPersistAllowedConsent() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = false
        let consent = MemoryAgentTaskNotificationConsentStore()
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent
        )
        fixture.viewModel.draft = "拒绝系统通知也要继续处理"
        fixture.viewModel.sendModelDependentMessage()

        fixture.viewModel.allowAgentTaskNotifications()
        try await waitUntil {
            notifications.authorizationRequestCount == 1
                && consent.decision != .undecided
        }

        XCTAssertEqual(consent.decision, .declined)
        await fixture.viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(fixture.generation.callCount, 1)
    }

    func testResumingTaskCancelsItsPendingWaitingNotification() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore(
            decision: .allowed
        )
        let network = TestNetworkAvailabilityObserver(state: .unavailable)
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent,
            generationEvents: [.textDelta("确认后开始处理。")],
            hangsAfterEvents: true,
            network: network
        )
        fixture.viewModel.draft = "离线请求恢复后由我确认"

        fixture.viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(
            fixture.viewModel.modelConnectionSetup.pendingIntent
        )
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: intent.id)
        )
        try await waitUntil { notifications.requests.count == 1 }
        XCTAssertEqual(
            notifications.requests.first?.notificationID,
            AgentTaskNotificationRequest.notificationID(for: task.id)
        )

        network.update(.available)
        XCTAssertEqual(fixture.viewModel.networkAvailabilityState, .available)
        XCTAssertTrue(fixture.viewModel.canResumeProviderTask)
        fixture.viewModel.resumeProviderTask()
        let resumed = try XCTUnwrap(
            fixture.database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(resumed.status, .running)
        XCTAssertNil(resumed.waitingReason)
        XCTAssertGreaterThan(resumed.revision, task.revision)
        XCTAssertTrue(
            notifications.cancelledTasks.contains {
                $0.taskID == task.id
                    && $0.throughRevision == resumed.revision
            }
        )

        fixture.viewModel.handleScenePhase(.background)
        await fixture.viewModel.waitForProviderRunToSettle()
    }

    func testPausedResumeCancelsOldNotificationBeforeDispatchCanReturn() async throws {
        let notifications = RecordingAgentTaskNotificationScheduler()
        notifications.authorizationResult = true
        let consent = MemoryAgentTaskNotificationConsentStore(
            decision: .allowed
        )
        let network = TestNetworkAvailabilityObserver(state: .available)
        let fixture = try makeFixture(
            notifications: notifications,
            consent: consent,
            generationEvents: [.textDelta("checkpoint")],
            hangsAfterEvents: true,
            network: network
        )
        fixture.viewModel.draft = "pause and resume"

        fixture.viewModel.sendModelDependentMessage()
        try await waitUntil { fixture.viewModel.isProviderRunActive }
        fixture.viewModel.pauseProviderTask()
        await fixture.viewModel.waitForProviderRunToSettle()
        try await waitUntil { notifications.requests.last?.kind == .paused }
        let paused = try XCTUnwrap(
            fixture.database.activeAgentTask()
        )
        XCTAssertEqual(paused.status, .paused)

        network.update(.checking)
        fixture.viewModel.resumeProviderTask()
        try await waitUntil {
            notifications.cancelledTasks.contains {
                $0.taskID == paused.id && $0.throughRevision > paused.revision
            }
        }

        XCTAssertEqual(
            try fixture.database.agentTask(id: paused.id)?.status,
            .running
        )
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

    func testCancellingInvalidatesAnInFlightNotificationSchedule() async throws {
        let center = SuspendedAgentTaskNotificationCenter()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: MemoryAgentTaskNotificationDeliveryStore()
        )
        let task = notificationTask(
            revision: 1,
            status: .waitingUser,
            waitingReason: .networkConfirmation
        )
        let request = AgentTaskNotificationRequest(
            task: task,
            kind: .waitingUser
        )

        let scheduling = Task {
            try await scheduler.schedule(request)
        }
        try await waitUntil { center.authorizationRequestCount == 1 }
        scheduler.cancelPendingNotification(
            for: task.id,
            throughRevision: task.revision
        )
        center.resolveNextAuthorization(with: .authorized)
        _ = try? await scheduling.value

        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testCancelledRevisionCannotScheduleAfterCancellationWinsTheRace() async throws {
        let center = AuthorizedAgentTaskNotificationCenter()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: MemoryAgentTaskNotificationDeliveryStore()
        )
        let task = notificationTask(
            revision: 3,
            status: .waitingUser,
            waitingReason: .networkConfirmation
        )

        scheduler.cancelPendingNotification(
            for: task.id,
            throughRevision: task.revision
        )
        try await scheduler.schedule(
            AgentTaskNotificationRequest(task: task, kind: .waitingUser)
        )

        XCTAssertEqual(center.authorizationRequestCount, 0)
        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testOlderRevisionCannotSupersedeNewerScheduleWhenItStartsLater() async throws {
        let center = AuthorizedAgentTaskNotificationCenter()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: MemoryAgentTaskNotificationDeliveryStore()
        )
        let taskID = UUID()
        let newer = notificationTask(
            id: taskID,
            revision: 2,
            status: .completed,
            outcome: .natural
        )
        let older = notificationTask(
            id: taskID,
            revision: 1,
            status: .waitingUser,
            waitingReason: .networkConfirmation
        )

        try await scheduler.schedule(
            AgentTaskNotificationRequest(task: newer, kind: .completed)
        )
        try await scheduler.schedule(
            AgentTaskNotificationRequest(task: older, kind: .waitingUser)
        )

        let pending = try XCTUnwrap(center.pendingRequests.first)
        XCTAssertEqual(center.pendingRequests.count, 1)
        XCTAssertEqual(
            pending.identifier,
            AgentTaskNotificationRequest.notificationID(for: taskID)
        )
        XCTAssertEqual(
            pending.content.body,
            AgentTaskNotificationRequest(task: newer, kind: .completed).body
        )
    }

    func testOlderCancellationCannotDeleteNewerScheduledRevision() async throws {
        let center = AuthorizedAgentTaskNotificationCenter()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: MemoryAgentTaskNotificationDeliveryStore()
        )
        let taskID = UUID()
        let newer = notificationTask(
            id: taskID,
            revision: 2,
            status: .completed,
            outcome: .natural
        )
        try await scheduler.schedule(
            AgentTaskNotificationRequest(task: newer, kind: .completed)
        )

        scheduler.cancelPendingNotification(
            for: taskID,
            throughRevision: 1
        )

        let pending = try XCTUnwrap(center.pendingRequests.first)
        XCTAssertEqual(center.pendingRequests.count, 1)
        XCTAssertEqual(
            pending.content.body,
            AgentTaskNotificationRequest(task: newer, kind: .completed).body
        )
    }

    func testCancellationAfterClaimReleasesDeliveryClaim() async throws {
        let center = SuspendedAddAgentTaskNotificationCenter()
        let deliveryStore = MemoryAgentTaskNotificationDeliveryStore()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: deliveryStore
        )
        let task = notificationTask(
            revision: 4,
            status: .waitingUser,
            waitingReason: .networkConfirmation
        )
        let request = AgentTaskNotificationRequest(
            task: task,
            kind: .waitingUser
        )

        let scheduling = Task {
            try await scheduler.schedule(request)
        }
        try await waitUntil { center.addRequestCount == 1 }
        XCTAssertTrue(deliveryStore.contains(request.id))
        scheduler.cancelPendingNotification(
            for: task.id,
            throughRevision: task.revision
        )
        center.resolveNextAdd()
        _ = try? await scheduling.value

        XCTAssertTrue(center.pendingRequests.isEmpty)
        XCTAssertFalse(deliveryStore.contains(request.id))
    }

    func testNewerRevisionWaitsForAndSupersedesInFlightSchedule() async throws {
        let center = SuspendedAgentTaskNotificationCenter()
        let scheduler = UserNotificationAgentTaskScheduler(
            centerAdapter: center,
            deliveryStore: MemoryAgentTaskNotificationDeliveryStore()
        )
        let taskID = UUID()
        let waiting = notificationTask(
            id: taskID,
            revision: 1,
            status: .waitingUser,
            waitingReason: .networkConfirmation
        )
        let completed = notificationTask(
            id: taskID,
            revision: 2,
            status: .completed,
            outcome: .natural
        )

        let first = Task {
            try await scheduler.schedule(
                AgentTaskNotificationRequest(task: waiting, kind: .waitingUser)
            )
        }
        try await waitUntil { center.authorizationRequestCount == 1 }
        let second = Task {
            try await scheduler.schedule(
                AgentTaskNotificationRequest(task: completed, kind: .completed)
            )
        }

        center.resolveNextAuthorization(with: .authorized)
        try await waitUntil { center.authorizationRequestCount == 2 }
        center.resolveNextAuthorization(with: .authorized)
        _ = try? await first.value
        try await second.value

        let pending = try XCTUnwrap(center.pendingRequests.first)
        XCTAssertEqual(center.pendingRequests.count, 1)
        XCTAssertEqual(
            pending.identifier,
            AgentTaskNotificationRequest.notificationID(for: taskID)
        )
        XCTAssertEqual(pending.content.body, "这件事已经处理完成，结果已安全保存。")
    }

    private func notificationTask(
        id: UUID = UUID(),
        revision: Int,
        status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        waitingReason: AgentTaskWaitingReason? = nil
    ) -> AgentTaskSnapshot {
        AgentTaskSnapshot(
            id: id,
            intentID: UUID(),
            conversationID: UUID(),
            projectID: nil,
            branchID: nil,
            status: status,
            outcome: outcome,
            waitingReason: waitingReason,
            requestedControl: nil,
            revision: revision,
            queueOrdinal: 1,
            activeRunID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(revision))
        )
    }

    private func makeFixture(
        notifications: RecordingAgentTaskNotificationScheduler,
        consent: MemoryAgentTaskNotificationConsentStore,
        generationEvents: [ProviderGenerationEvent] = [
            .textDelta("任务已经完成。"),
            .finished(reason: "stop"),
            .usage(
                ProviderUsage(
                    inputTokens: 5,
                    outputTokens: 4,
                    totalTokens: 9
                )
            )
        ],
        hangsAfterEvents: Bool = false,
        network: TestNetworkAvailabilityObserver? = nil
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
            events: generationEvents,
            hangsAfterEvents: hangsAfterEvents
        )
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            networkAvailabilityObserver: network,
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
        throw AgentTaskNotificationTestError.timeout
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
    var suspendsAuthorization = false
    private(set) var authorizationRequestCount = 0
    private(set) var requests: [AgentTaskNotificationRequest] = []
    private(set) var cancelledTaskIDs: [UUID] = []
    private(set) var cancelledTasks: [(taskID: UUID, throughRevision: Int)] = []
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if suspendsAuthorization {
            return await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
            }
        }
        return authorizationResult
    }

    func resolveAuthorization() {
        authorizationContinuation?.resume(returning: authorizationResult)
        authorizationContinuation = nil
    }

    func schedule(_ request: AgentTaskNotificationRequest) async throws {
        guard authorizationResult else { return }
        requests.append(request)
    }

    func cancelPendingNotification(
        for taskID: UUID,
        throughRevision: Int
    ) {
        cancelledTaskIDs.append(taskID)
        cancelledTasks.append((taskID, throughRevision))
    }
}

@MainActor
private final class AuthorizedAgentTaskNotificationCenter:
    AgentTaskUserNotificationCenter
{
    private(set) var authorizationRequestCount = 0
    private(set) var pendingRequests: [UNNotificationRequest] = []

    func requestAuthorization() async throws -> Bool { true }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationRequestCount += 1
        return .authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
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

@MainActor
private final class SuspendedAgentTaskNotificationCenter:
    AgentTaskUserNotificationCenter
{
    private var authorizationContinuations: [
        CheckedContinuation<UNAuthorizationStatus, Never>
    ] = []
    private(set) var authorizationRequestCount = 0
    private(set) var pendingRequests: [UNNotificationRequest] = []

    func requestAuthorization() async throws -> Bool { true }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationRequestCount += 1
        return await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
        }
    }

    func resolveNextAuthorization(with status: UNAuthorizationStatus) {
        guard !authorizationContinuations.isEmpty else { return }
        authorizationContinuations.removeFirst().resume(returning: status)
    }

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }
}

@MainActor
private final class MemoryAgentTaskNotificationDeliveryStore:
    AgentTaskNotificationDeliveryStoring
{
    private var identifiers: Set<String> = []

    func claim(_ identifier: String) -> Bool {
        identifiers.insert(identifier).inserted
    }

    func release(_ identifier: String) {
        identifiers.remove(identifier)
    }

    func contains(_ identifier: String) -> Bool {
        identifiers.contains(identifier)
    }
}

@MainActor
private final class SuspendedAddAgentTaskNotificationCenter:
    AgentTaskUserNotificationCenter
{
    private var pendingAdds: [(
        UNNotificationRequest,
        CheckedContinuation<Void, Never>
    )] = []
    private(set) var addRequestCount = 0
    private(set) var pendingRequests: [UNNotificationRequest] = []

    func requestAuthorization() async throws -> Bool { true }

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func add(_ request: UNNotificationRequest) async throws {
        addRequestCount += 1
        await withCheckedContinuation { continuation in
            pendingAdds.append((request, continuation))
        }
    }

    func resolveNextAdd() {
        guard !pendingAdds.isEmpty else { return }
        let (request, continuation) = pendingAdds.removeFirst()
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
        continuation.resume()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }
}

private enum AgentTaskNotificationTestError: Error {
    case timeout
}
