import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ModelConnectionRecoveryViewModelTests: XCTestCase {
    private struct FailingSecretRepository: SecretRepository {
        private struct Failure: Error {}

        func save(_ secret: String, account: String) throws { throw Failure() }
        func read(account: String) throws -> String? { throw Failure() }
        func contains(account: String) throws -> Bool { throw Failure() }
        func delete(account: String) throws { throw Failure() }
    }

    private struct StubIsolationCanaryRepository: IsolationCanaryRepository {
        func prepare() throws -> String { "stub" }
        func currentDigest() throws -> String? { nil }
        func delete() throws {}
    }

    private final class StubBuildActivationStore: BuildActivationStore {
        private var token: String?

        func loadActivatedToken() -> String? { token }
        func saveActivatedToken(_ token: String) { self.token = token }
    }

    @MainActor
    func testModelConnectionReconciliationFailurePreservesTheLocalWorkspace() throws {
        try withDatabase { database in
            let turn = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "本地对话必须恢复"),
                now: Date(timeIntervalSince1970: 1_000)
            )
            try database.saveS1ConversationDraft(
                "仍在编辑的草稿",
                selectedConversationID: turn.conversation.id,
                now: Date(timeIntervalSince1970: 1_001)
            )
            let project = try database.createProject(
                title: "恢复测试小说",
                premise: "模型凭证恢复失败不影响本地内容",
                now: Date(timeIntervalSince1970: 1_002)
            )
            let candidate = try ModelConnectionTestFixture.makeSetupCandidate()
            _ = try database.stageModelConnectionSetup(
                candidate.connection,
                credentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 1_003)
            )

            let viewModel = AppViewModel(
                database: database,
                keychain: FailingSecretRepository(),
                isolationCanaryRepository: StubIsolationCanaryRepository(),
                compiledBuildStamp: .generated,
                buildActivationStore: StubBuildActivationStore(),
                bundleIdentityLoader: nil,
                taskID: UUID()
            )

            XCTAssertTrue(viewModel.isComposerAvailable)
            XCTAssertEqual(viewModel.selectedConversationID, turn.conversation.id)
            XCTAssertEqual(viewModel.draft, "仍在编辑的草稿")
            XCTAssertEqual(viewModel.conversationMessages.first, "你：本地对话必须恢复")
            XCTAssertEqual(viewModel.projects.map(\.id), [project.id])
            XCTAssertTrue(
                viewModel.diagnosticErrorMessage?.contains("MODEL-CONNECTION-RECOVERY") == true
            )
            XCTAssertFalse(viewModel.diagnosticErrorMessage?.contains("DB-INIT") == true)
            XCTAssertEqual(try database.pendingModelConnectionSetups().count, 1)
        }
    }

    @MainActor
    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        try body(
            AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
        )
    }
}
