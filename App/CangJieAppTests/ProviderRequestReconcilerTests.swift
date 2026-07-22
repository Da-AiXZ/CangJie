@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class ProviderRequestReconcilerTests: XCTestCase {
    func testSendingRequestBecomesLifecycleUnknownWithoutNewAttempt() throws {
        let fixture = try makeFixture()
        let sending = try ProviderRequestLifecycle.markSending(
            fixture.request,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        let reconciler = ProviderRequestReconciler(
            database: fixture.database,
            now: { fixture.now.addingTimeInterval(2) }
        )

        let reconciled = try reconciler.reconcile(sending)
        let replay = try reconciler.reconcile(reconciled)

        XCTAssertEqual(reconciled.phase, .outcomeUnknown)
        XCTAssertEqual(reconciled.interruption, .lifecycleInterruption)
        XCTAssertEqual(reconciled.identity.attemptNumber, 1)
        XCTAssertEqual(reconciled.identity.turnSequence, 1)
        XCTAssertEqual(replay, reconciled)
        XCTAssertEqual(
            try fixture.database.providerRequest(intentID: fixture.intent.id),
            reconciled
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: reconciled.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.status,
            .reconciling
        )
    }

    private func makeFixture() throws -> (
        database: AppDatabase,
        intent: PendingModelIntent,
        request: ProviderRequestSnapshot,
        now: Date
    ) {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 8_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "继续这件事",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: hash("a"),
                credentialPayloadHash: hash("b")
            )
        )
        let request = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: intent,
            verifiedConnection: verified,
            now: now
        )
        _ = try database.persistPreparedProviderRequest(
            request,
            intent: intent,
            verifiedConnection: verified
        )
        return (database, intent, request, now)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-reconcile-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
