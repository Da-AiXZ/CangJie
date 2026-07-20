import CangJieCore
import XCTest
@testable import CangJie

final class S1ConversationWorkspaceDatabaseTests: XCTestCase {
    func testFreshWorkspaceHasNoConversationAndDoesNotCreateProject() throws {
        try withDatabase { database in
            let workspace = try database.restoreS1ConversationWorkspace()

            XCTAssertNil(workspace.selectedConversation)
            XCTAssertTrue(workspace.conversations.isEmpty)
            XCTAssertEqual(workspace.draft, "")
            XCTAssertTrue(workspace.messageWindow.messages.isEmpty)
            XCTAssertFalse(workspace.messageWindow.hasEarlierMessages)
            XCTAssertTrue(try database.listProjects().isEmpty)
        }
    }

    func testUnboundDraftSurvivesRestoreWithoutCreatingConversation() throws {
        try withDatabase { database in
            try database.saveS1ConversationDraft(
                "unsent idea",
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_000)
            )

            let restored = try database.restoreS1ConversationWorkspace()

            XCTAssertNil(restored.selectedConversation)
            XCTAssertTrue(restored.conversations.isEmpty)
            XCTAssertEqual(restored.draft, "unsent idea")
        }
    }

    func testFirstTurnCreatesBindsAndTitlesConversationInOneTransaction() throws {
        try withDatabase { database in
            let idea = "a protagonist wakes without memories"
            try database.saveS1ConversationDraft(
                idea,
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_000)
            )
            let turn = try S1ConversationPreview.makeTurn(from: idea)

            let appended = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: turn,
                now: Date(timeIntervalSince1970: 1_001)
            )
            let restored = try database.restoreS1ConversationWorkspace()

            XCTAssertEqual(restored.selectedConversation?.id, appended.conversation.id)
            XCTAssertEqual(
                restored.selectedConversation?.title,
                S1ConversationPreview.makeHistoryTitle(fromValidatedUserText: idea)
            )
            XCTAssertEqual(restored.draft, "")
            XCTAssertEqual(
                restored.messageWindow.messages.map(\.content),
                [turn.userText, turn.systemReceipt]
            )
            XCTAssertTrue(try database.listProjects().isEmpty)
        }
    }

    func testConversationSelectionKeepsEachDraftIsolated() throws {
        try withDatabase { database in
            let first = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "first story"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            try database.saveS1ConversationDraft(
                "first draft",
                selectedConversationID: first.id,
                now: Date(timeIntervalSince1970: 1_001)
            )

            try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 1_002))
            let second = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "second story"),
                now: Date(timeIntervalSince1970: 1_003)
            ).conversation
            try database.saveS1ConversationDraft(
                "second draft",
                selectedConversationID: second.id,
                now: Date(timeIntervalSince1970: 1_004)
            )
            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 1_005))
            try database.saveS1ConversationDraft(
                "unbound second story",
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_006)
            )

            let restoredFirst = try database.selectS1Conversation(first.id)
            XCTAssertEqual(restoredFirst.selectedConversation?.id, first.id)
            XCTAssertEqual(restoredFirst.draft, "first draft")
            XCTAssertEqual(restoredFirst.messageWindow.messages.first?.content, "first story")

            let restoredSecond = try database.selectS1Conversation(second.id)
            XCTAssertEqual(restoredSecond.selectedConversation?.id, second.id)
            XCTAssertEqual(restoredSecond.draft, "second draft")
            XCTAssertEqual(restoredSecond.messageWindow.messages.first?.content, "second story")

            let restoredNew = try database.selectNewS1Conversation()
            XCTAssertNil(restoredNew.selectedConversation)
            XCTAssertEqual(restoredNew.draft, "unbound second story")
            XCTAssertTrue(restoredNew.messageWindow.messages.isEmpty)
        }
    }

    func testSendingExistingConversationDoesNotClearUnboundNewConversationDraft() throws {
        try withDatabase { database in
            let existing = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "existing conversation"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation

            try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 1_001))
            try database.saveS1ConversationDraft(
                "new conversation draft",
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_002)
            )
            _ = try database.selectS1Conversation(
                existing.id,
                now: Date(timeIntervalSince1970: 1_003)
            )

            _ = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: existing.id,
                turn: S1ConversationPreview.makeTurn(from: "continue existing"),
                now: Date(timeIntervalSince1970: 1_004)
            )

            let restoredNew = try database.selectNewS1Conversation(
                now: Date(timeIntervalSince1970: 1_005)
            )
            XCTAssertEqual(restoredNew.draft, "new conversation draft")
        }
    }

    func testDelayedDraftSaveFailsWhenSelectionChanged() throws {
        try withDatabase { database in
            let existing = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "first"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            _ = try database.selectNewS1Conversation(
                now: Date(timeIntervalSince1970: 1_001)
            )

            XCTAssertThrowsError(
                try database.saveS1ConversationDraft(
                    "stale save",
                    selectedConversationID: existing.id,
                    now: Date(timeIntervalSince1970: 1_002)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidAgentSession)
            }
            XCTAssertEqual(try database.restoreS1ConversationWorkspace().draft, "")
        }
    }

    func testCheckpointPayloadIsScopedPerConversationWorkspace() throws {
        try withDatabase { database in
            let taskID = UUID()
            let newWorkspaceCheckpoint = try database.checkpointS1ConversationDraft(
                content: "same payload",
                selectedConversationID: nil,
                taskID: taskID,
                reason: "new workspace",
                payloadHash: "same-hash",
                now: Date(timeIntervalSince1970: 1_000)
            )
            let conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "bind conversation"),
                now: Date(timeIntervalSince1970: 1_001)
            ).conversation
            let conversationCheckpoint = try database.checkpointS1ConversationDraft(
                content: "same payload",
                selectedConversationID: conversation.id,
                taskID: taskID,
                reason: "bound conversation",
                payloadHash: "same-hash",
                now: Date(timeIntervalSince1970: 1_002)
            )

            XCTAssertNotEqual(newWorkspaceCheckpoint.id, conversationCheckpoint.id)
            XCTAssertEqual(newWorkspaceCheckpoint.scopeKey, "s1:new")
            XCTAssertEqual(
                conversationCheckpoint.scopeKey,
                "s1:conversation:\(conversation.id.uuidString)"
            )
            XCTAssertEqual(conversationCheckpoint.sequence, newWorkspaceCheckpoint.sequence + 1)
            XCTAssertEqual(
                try database.latestS1ConversationCheckpoint(
                    taskID: taskID,
                    selectedConversationID: conversation.id
                ),
                conversationCheckpoint
            )
            XCTAssertEqual(
                try database.latestS1ConversationCheckpoint(
                    taskID: taskID,
                    selectedConversationID: nil
                ),
                newWorkspaceCheckpoint
            )
        }
    }

    func testCheckpointFailsClosedAfterWorkspaceSelectionChanges() throws {
        try withDatabase { database in
            let conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "first"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            _ = try database.selectNewS1Conversation(
                now: Date(timeIntervalSince1970: 1_001)
            )

            XCTAssertThrowsError(
                try database.checkpointS1ConversationDraft(
                    content: "stale",
                    selectedConversationID: conversation.id,
                    taskID: UUID(),
                    reason: "stale selection",
                    payloadHash: "stale-hash",
                    now: Date(timeIntervalSince1970: 1_002)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidAgentSession)
            }
        }
    }

    func testLegacySaveDraftOnlyUpdatesCompatibilityMirrorAndLeavesWorkspaceUntouched() throws {
        try withDatabase { database in
            let conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "workspace source of truth"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            try database.saveS1ConversationDraft(
                "scoped workspace draft",
                selectedConversationID: conversation.id,
                now: Date(timeIntervalSince1970: 1_001)
            )
            let workspaceBeforeLegacyWrite = try database.restoreS1ConversationWorkspace()

            try database.saveDraft(
                "legacy mirror only",
                now: Date(timeIntervalSince1970: 1_002)
            )

            XCTAssertEqual(try database.loadDraft()?.content, "legacy mirror only")
            XCTAssertEqual(
                try database.restoreS1ConversationWorkspace(),
                workspaceBeforeLegacyWrite
            )
        }
    }

    func testLegacyCheckpointOnlyUpdatesCompatibilityMirrorAndLeavesWorkspaceUntouched() throws {
        try withDatabase { database in
            let conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "checkpoint workspace source"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            try database.saveS1ConversationDraft(
                "scoped checkpoint draft",
                selectedConversationID: conversation.id,
                now: Date(timeIntervalSince1970: 1_001)
            )
            let workspaceBeforeLegacyCheckpoint = try database.restoreS1ConversationWorkspace()
            let taskID = UUID()

            let checkpoint = try database.checkpointDraft(
                content: "legacy checkpoint mirror",
                taskID: taskID,
                reason: "legacy compatibility",
                payloadHash: "legacy-only-hash",
                now: Date(timeIntervalSince1970: 1_002)
            )

            XCTAssertEqual(checkpoint.scopeKey, "legacy:m0")
            XCTAssertNil(checkpoint.conversationID)
            XCTAssertEqual(try database.loadDraft()?.content, "legacy checkpoint mirror")
            XCTAssertEqual(try database.latestCheckpoint(taskID: taskID), checkpoint)
            XCTAssertEqual(
                try database.restoreS1ConversationWorkspace(),
                workspaceBeforeLegacyCheckpoint
            )
        }
    }

    func testSelectedConversationPersistsAcrossDatabaseReopen() throws {
        try withDatabasePath { path in
            let firstDatabase = try AppDatabase(path: path)
            let first = try firstDatabase.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "persistent selection"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            try firstDatabase.saveS1ConversationDraft(
                "survives restart",
                selectedConversationID: first.id,
                now: Date(timeIntervalSince1970: 1_001)
            )

            let reopened = try AppDatabase(path: path)
            let restored = try reopened.restoreS1ConversationWorkspace()

            XCTAssertEqual(restored.selectedConversation?.id, first.id)
            XCTAssertEqual(restored.draft, "survives restart")
        }
    }

    func testSelectingUnknownConversationFailsClosed() throws {
        try withDatabase { database in
            XCTAssertThrowsError(try database.selectS1Conversation(UUID())) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidAgentSession)
            }
        }
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        try withDatabasePath { path in
            try body(AppDatabase(path: path))
        }
    }

    private func withDatabasePath(_ body: (String) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1Workspace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("test.sqlite").path)
    }
}
