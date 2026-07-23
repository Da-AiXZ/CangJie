import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class AgentTaskControlPersistenceTests: XCTestCase {
    func testOnePrimaryTaskQueuesAndPromotesTheNextConversationFIFO() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 7_000)
        let firstIntent = try makeIntent(
            in: database,
            request: "整理第一段讨论",
            now: now
        )
        let secondIntent = try makeIntent(
            in: database,
            request: "整理第二段讨论",
            now: now.addingTimeInterval(1),
            newConversation: true
        )

        let first = try database.enqueueAgentTask(
            for: firstIntent,
            commandID: UUID(),
            now: now.addingTimeInterval(2)
        )
        let second = try database.enqueueAgentTask(
            for: secondIntent,
            commandID: UUID(),
            now: now.addingTimeInterval(3)
        )

        XCTAssertEqual(first.status, .running)
        XCTAssertEqual(second.status, .queued)
        XCTAssertLessThan(first.queueOrdinal, second.queueOrdinal)

        let pauseRequested = try database.transitionAgentTask(
            id: first.id,
            expectedRevision: first.revision,
            commandID: UUID(),
            to: .pauseRequested,
            now: now.addingTimeInterval(4)
        ).task
        let paused = try database.transitionAgentTask(
            id: first.id,
            expectedRevision: pauseRequested.revision,
            commandID: UUID(),
            to: .paused,
            now: now.addingTimeInterval(5)
        ).task
        XCTAssertEqual(try database.agentTask(id: second.id)?.status, .queued)

        let stopRequested = try database.transitionAgentTask(
            id: first.id,
            expectedRevision: paused.revision,
            commandID: UUID(),
            to: .stopRequested,
            now: now.addingTimeInterval(6)
        ).task
        let settled = try database.transitionAgentTask(
            id: first.id,
            expectedRevision: stopRequested.revision,
            commandID: UUID(),
            to: .completed,
            outcome: .kept,
            now: now.addingTimeInterval(7)
        )

        XCTAssertEqual(settled.task.status, .completed)
        XCTAssertEqual(settled.task.outcome, .kept)
        XCTAssertEqual(settled.promotedTask?.id, second.id)
        XCTAssertEqual(settled.promotedTask?.status, .running)
        XCTAssertEqual(try database.activeAgentTask()?.id, second.id)
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: firstIntent.conversationID
            )
        )
        let resolution = try database.queue.read { db -> (String?, String?) in
            let row = try XCTUnwrap(Row.fetchOne(
                db,
                sql: """
                    SELECT resolutionKind, resolvedTaskID
                    FROM pendingModelIntent WHERE id = ?
                    """,
                arguments: [firstIntent.id.uuidString]
            ))
            return (row["resolutionKind"], row["resolvedTaskID"])
        }
        XCTAssertEqual(resolution.0, "kept")
        XCTAssertEqual(resolution.1, first.id.uuidString)
    }

    func testTransitionCommandReplayIsExactAndDoesNotAdvanceRevisionTwice() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 8_000)
        let intent = try makeIntent(
            in: database,
            request: "保存这次讨论",
            now: now
        )
        let task = try database.enqueueAgentTask(
            for: intent,
            commandID: UUID(),
            now: now.addingTimeInterval(1)
        )
        let commandID = UUID()

        let first = try database.transitionAgentTask(
            id: task.id,
            expectedRevision: task.revision,
            commandID: commandID,
            to: .pauseRequested,
            now: now.addingTimeInterval(2)
        )
        let replay = try database.transitionAgentTask(
            id: task.id,
            expectedRevision: task.revision,
            commandID: commandID,
            to: .pauseRequested,
            now: now.addingTimeInterval(3)
        )

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.task.revision, task.revision + 1)
        XCTAssertEqual(
            try database.agentTask(id: task.id)?.revision,
            task.revision + 1
        )
    }

    func testDiscardFailsClosedWhenOutputWasAlreadyAdopted() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 9_000)
        let intent = try makeIntent(
            in: database,
            request: "整理但不要覆盖",
            now: now
        )
        let running = try database.enqueueAgentTask(
            for: intent,
            commandID: UUID(),
            now: now.addingTimeInterval(1)
        )
        let requested = try database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .pauseRequested,
            now: now.addingTimeInterval(2)
        ).task
        let paused = try database.transitionAgentTask(
            id: running.id,
            expectedRevision: requested.revision,
            commandID: UUID(),
            to: .paused,
            now: now.addingTimeInterval(3)
        ).task

        XCTAssertThrowsError(
            try database.transitionAgentTask(
                id: running.id,
                expectedRevision: paused.revision,
                commandID: UUID(),
                to: .discarded,
                outcome: .discarded,
                hasAdoptedOutput: true,
                now: now.addingTimeInterval(4)
            )
        ) { error in
            XCTAssertEqual(
                error as? AgentTaskControlError,
                .adoptedOutputCannotBeDiscarded
            )
        }
        XCTAssertEqual(try database.agentTask(id: running.id), paused)
    }

    func testDefinitelyFailedTaskRetryRequeuesAndPromotesExactlyOnce() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 9_500)
        let intent = try makeIntent(
            in: database,
            request: "失败后明确重试",
            now: now
        )
        let running = try database.enqueueAgentTask(
            for: intent,
            commandID: UUID(),
            now: now.addingTimeInterval(1)
        )
        let failed = try database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .failed,
            now: now.addingTimeInterval(2)
        ).task
        let commandID = UUID()

        let retried = try database.retryFailedAgentTask(
            id: failed.id,
            expectedRevision: failed.revision,
            commandID: commandID,
            now: now.addingTimeInterval(3)
        )
        let replay = try database.retryFailedAgentTask(
            id: failed.id,
            expectedRevision: failed.revision,
            commandID: commandID,
            now: now.addingTimeInterval(4)
        )

        XCTAssertEqual(retried, replay)
        XCTAssertEqual(retried.status, .running)
        XCTAssertEqual(retried.revision, failed.revision + 2)
        XCTAssertEqual(try database.activeAgentTask(), retried)
    }

    func testReconciliationPreservesTheRequestedPauseOrKeepAction() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 10_000)
        let pauseIntent = try makeIntent(
            in: database,
            request: "暂停后对账",
            now: now
        )
        let pauseRunning = try database.enqueueAgentTask(
            for: pauseIntent,
            commandID: UUID(),
            now: now.addingTimeInterval(1)
        )
        let pauseRequested = try database.transitionAgentTask(
            id: pauseRunning.id,
            expectedRevision: pauseRunning.revision,
            commandID: UUID(),
            to: .pauseRequested,
            now: now.addingTimeInterval(2)
        ).task
        let pauseReconciling = try database.transitionAgentTask(
            id: pauseRunning.id,
            expectedRevision: pauseRequested.revision,
            commandID: UUID(),
            to: .reconciling,
            now: now.addingTimeInterval(3)
        ).task
        XCTAssertEqual(pauseReconciling.requestedControl, .pauseNow)

        let paused = try database.transitionAgentTask(
            id: pauseRunning.id,
            expectedRevision: pauseReconciling.revision,
            commandID: UUID(),
            to: .paused,
            now: now.addingTimeInterval(4)
        ).task
        let stopRequested = try database.transitionAgentTask(
            id: pauseRunning.id,
            expectedRevision: paused.revision,
            commandID: UUID(),
            to: .stopRequested,
            now: now.addingTimeInterval(5)
        ).task
        let keepReconciling = try database.transitionAgentTask(
            id: pauseRunning.id,
            expectedRevision: stopRequested.revision,
            commandID: UUID(),
            to: .reconciling,
            now: now.addingTimeInterval(6)
        ).task
        XCTAssertEqual(
            keepReconciling.requestedControl,
            .stopKeepingResults
        )
    }

    func testRetryJoinsQueueTailAndReplaysItsHistoricalResult() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 11_000)
        let first = try database.enqueueAgentTask(
            for: makeIntent(in: database, request: "先失败", now: now),
            commandID: UUID(),
            now: now.addingTimeInterval(1)
        )
        let second = try database.enqueueAgentTask(
            for: makeIntent(
                in: database,
                request: "第二个任务",
                now: now.addingTimeInterval(2),
                newConversation: true
            ),
            commandID: UUID(),
            now: now.addingTimeInterval(3)
        )
        let failed = try database.transitionAgentTask(
            id: first.id,
            expectedRevision: first.revision,
            commandID: UUID(),
            to: .failed,
            now: now.addingTimeInterval(4)
        ).task
        let third = try database.enqueueAgentTask(
            for: makeIntent(
                in: database,
                request: "第三个任务",
                now: now.addingTimeInterval(5),
                newConversation: true
            ),
            commandID: UUID(),
            now: now.addingTimeInterval(6)
        )
        let retryCommandID = UUID()
        let retried = try database.retryFailedAgentTask(
            id: failed.id,
            expectedRevision: failed.revision,
            commandID: retryCommandID,
            now: now.addingTimeInterval(7)
        )

        XCTAssertEqual(retried.status, .queued)
        XCTAssertGreaterThan(retried.queueOrdinal, third.queueOrdinal)
        let secondCompleted = try database.transitionAgentTask(
            id: second.id,
            expectedRevision: second.revision + 1,
            commandID: UUID(),
            to: .completed,
            outcome: .natural,
            now: now.addingTimeInterval(8)
        )
        XCTAssertEqual(secondCompleted.promotedTask?.id, third.id)
        let thirdCompleted = try database.transitionAgentTask(
            id: third.id,
            expectedRevision: third.revision + 1,
            commandID: UUID(),
            to: .completed,
            outcome: .natural,
            now: now.addingTimeInterval(9)
        )
        XCTAssertEqual(thirdCompleted.promotedTask?.id, first.id)

        let replay = try database.retryFailedAgentTask(
            id: failed.id,
            expectedRevision: failed.revision,
            commandID: retryCommandID,
            now: now.addingTimeInterval(10)
        )
        XCTAssertEqual(replay, retried)
        XCTAssertEqual(replay.status, .queued)
    }

    private func makeIntent(
        in database: AppDatabase,
        request: String,
        now: Date,
        newConversation: Bool = false
    ) throws -> PendingModelIntent {
        let conversation: AgentConversation
        if newConversation {
            conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: request),
                now: now
            ).conversation
        } else {
            conversation = try database.ensureDefaultConversation(now: now)
        }
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: request,
            createdAt: now
        )
        return try database.storePendingModelIntent(intent)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-task-control-\(UUID()).sqlite")
            .path
    }
}
