import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    static func replayAgentTaskTransition(
        _ event: Row,
        taskID: UUID,
        expectedRevision: Int,
        status: AgentTaskStatus,
        outcome: AgentTaskOutcome?,
        waitingReason: AgentTaskWaitingReason? = nil,
        hasAdoptedOutput: Bool,
        in db: Database
    ) throws -> AgentTaskTransitionResult {
        let storedTaskID: String = event["taskID"]
        let storedExpectedRevision: Int = event["expectedRevision"]
        let storedStatus: String = event["toStatus"]
        let storedOutcome: String? = event["toOutcome"]
        let storedWaitingReason: String? = event["toWaitingReason"]
        let storedRequestedControlText: String? = event["toRequestedControl"]
        let storedAdoption: Bool = event["hasAdoptedOutput"]
        guard storedTaskID == taskID.uuidString,
              storedExpectedRevision == expectedRevision,
              storedStatus == status.rawValue,
              storedOutcome == outcome?.rawValue,
              storedWaitingReason == waitingReason?.rawValue,
              storedAdoption == hasAdoptedOutput else {
            throw AppDatabaseError.idempotencyConflict
        }
        let current = try requiredAgentTask(id: taskID, in: db)
        let resultRevision: Int = event["resultRevision"]
        let resultQueueOrdinal: Int64 = event["resultQueueOrdinal"]
        let createdAt = Date(timeIntervalSince1970: event["createdAt"])
        let activeRunText: String? = event["resultActiveRunID"]
        let resultActiveRunID = try optionalAgentTaskUUID(activeRunText)
        let resultRequestedControl: AgentTaskRequestedControl?
        if let storedRequestedControlText {
            guard let control = AgentTaskRequestedControl(
                rawValue: storedRequestedControlText
            ) else {
                throw AppDatabaseError.invalidAgentTask
            }
            resultRequestedControl = control
        } else {
            resultRequestedControl = nil
        }
        guard resultQueueOrdinal > 0,
              isValidAgentTaskRequestedControl(
                resultRequestedControl,
                for: status
              ) else {
            throw AppDatabaseError.invalidAgentTask
        }
        do {
            _ = try AgentTaskControlState(
                status: status,
                outcome: outcome,
                waitingReason: waitingReason
            )
        } catch {
            throw AppDatabaseError.invalidAgentTask
        }
        let result = AgentTaskSnapshot(
            id: current.id,
            intentID: current.intentID,
            conversationID: current.conversationID,
            projectID: current.projectID,
            branchID: current.branchID,
            status: status,
            outcome: outcome,
            waitingReason: waitingReason,
            requestedControl: resultRequestedControl,
            revision: resultRevision,
            queueOrdinal: resultQueueOrdinal,
            activeRunID: resultActiveRunID,
            createdAt: current.createdAt,
            updatedAt: createdAt
        )
        let promotedTask: AgentTaskSnapshot?
        let promotedText: String? = event["promotedTaskID"]
        let promotedRevision: Int? = event["promotedRevision"]
        let promotedQueueOrdinal: Int64? = event["promotedQueueOrdinal"]
        let promotedActiveRunText: String? = event["promotedActiveRunID"]
        let promotedUpdatedAtValue: Double? = event["promotedUpdatedAt"]
        if let promotedText {
            guard let promotedID = UUID(uuidString: promotedText),
                  let promotedRevision,
                  let promotedQueueOrdinal,
                  promotedQueueOrdinal > 0,
                  let promotedUpdatedAtValue,
                  let promotedCurrent = try agentTask(id: promotedID, in: db)
            else {
                throw AppDatabaseError.invalidAgentTask
            }
            let promotedUpdatedAt = Date(
                timeIntervalSince1970: promotedUpdatedAtValue
            )
            let promotedActiveRunID = try optionalAgentTaskUUID(
                promotedActiveRunText
            )
            let promotedState = try promotedAgentTaskState(
                for: promotedCurrent.intentID,
                in: db
            )
            promotedTask = AgentTaskSnapshot(
                id: promotedCurrent.id,
                intentID: promotedCurrent.intentID,
                conversationID: promotedCurrent.conversationID,
                projectID: promotedCurrent.projectID,
                branchID: promotedCurrent.branchID,
                status: promotedState.status,
                outcome: promotedState.outcome,
                waitingReason: promotedState.waitingReason,
                requestedControl: nil,
                revision: promotedRevision,
                queueOrdinal: promotedQueueOrdinal,
                activeRunID: promotedActiveRunID,
                createdAt: promotedCurrent.createdAt,
                updatedAt: promotedUpdatedAt
            )
        } else {
            guard promotedRevision == nil,
                  promotedQueueOrdinal == nil,
                  promotedActiveRunText == nil,
                  promotedUpdatedAtValue == nil else {
                throw AppDatabaseError.invalidAgentTask
            }
            promotedTask = nil
        }
        return AgentTaskTransitionResult(task: result, promotedTask: promotedTask)
    }

    static func insertAgentTaskEvent(
        commandID: UUID,
        taskID: UUID,
        expectedRevision: Int,
        from: AgentTaskControlState?,
        to: AgentTaskControlState,
        fromRequestedControl: AgentTaskRequestedControl?,
        toRequestedControl: AgentTaskRequestedControl?,
        hasAdoptedOutput: Bool,
        resultActiveRunID: UUID?,
        resultQueueOrdinal: Int64,
        promoted: AgentTaskSnapshot?,
        now: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO agentTaskEvent (
                    commandID, taskID, expectedRevision, resultRevision,
                    fromStatus, fromOutcome, fromWaitingReason,
                    fromRequestedControl,
                    toStatus, toOutcome, toWaitingReason,
                    toRequestedControl,
                    hasAdoptedOutput, resultActiveRunID, resultQueueOrdinal,
                    promotedTaskID,
                    promotedRevision, promotedQueueOrdinal,
                    promotedActiveRunID, promotedUpdatedAt, createdAt
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?
                )
                """,
            arguments: [
                commandID.uuidString,
                taskID.uuidString,
                expectedRevision,
                expectedRevision + 1,
                from?.status.rawValue,
                from?.outcome?.rawValue,
                from?.waitingReason?.rawValue,
                fromRequestedControl?.rawValue,
                to.status.rawValue,
                to.outcome?.rawValue,
                to.waitingReason?.rawValue,
                toRequestedControl?.rawValue,
                hasAdoptedOutput,
                resultActiveRunID?.uuidString,
                resultQueueOrdinal,
                promoted?.id.uuidString,
                promoted?.revision,
                promoted?.queueOrdinal,
                promoted?.activeRunID?.uuidString,
                promoted?.updatedAt.timeIntervalSince1970,
                now.timeIntervalSince1970
            ]
        )
    }
}
