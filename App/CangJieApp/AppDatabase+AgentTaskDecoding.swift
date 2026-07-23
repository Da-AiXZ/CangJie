import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    static func decodeAgentTask(_ row: Row) throws -> AgentTaskSnapshot {
        let idText: String = row["id"]
        let intentText: String = row["intentID"]
        let conversationText: String = row["conversationID"]
        let projectText: String? = row["projectID"]
        let branchText: String? = row["branchID"]
        let statusText: String = row["status"]
        let outcomeText: String? = row["outcome"]
        let waitingReasonText: String? = row["waitingReason"]
        let requestedControlText: String? = row["requestedControl"]
        let revision: Int = row["revision"]
        let queueOrdinal: Int64 = row["queueOrdinal"]
        let primarySlot: Int? = row["primarySlot"]
        let activeRunText: String? = row["activeRunID"]
        let createdAt = Date(timeIntervalSince1970: row["createdAt"])
        let updatedAt = Date(timeIntervalSince1970: row["updatedAt"])
        guard let id = UUID(uuidString: idText),
              let intentID = UUID(uuidString: intentText),
              let conversationID = UUID(uuidString: conversationText),
              let status = AgentTaskStatus(rawValue: statusText),
              revision > 0,
              queueOrdinal > 0,
              updatedAt >= createdAt,
              primarySlot == (isPrimaryAgentTaskStatus(status) ? 1 : nil) else {
            throw AppDatabaseError.invalidAgentTask
        }
        let projectID = try optionalAgentTaskUUID(projectText)
        let branchID = try optionalAgentTaskUUID(branchText)
        let activeRunID = try optionalAgentTaskUUID(activeRunText)
        let outcome: AgentTaskOutcome?
        if let outcomeText {
            guard let decoded = AgentTaskOutcome(rawValue: outcomeText) else {
                throw AppDatabaseError.invalidAgentTask
            }
            outcome = decoded
        } else {
            outcome = nil
        }
        let waitingReason: AgentTaskWaitingReason?
        if let waitingReasonText {
            guard let decoded = AgentTaskWaitingReason(
                rawValue: waitingReasonText
            ) else {
                throw AppDatabaseError.invalidAgentTask
            }
            waitingReason = decoded
        } else {
            waitingReason = nil
        }
        let requestedControl: AgentTaskRequestedControl?
        if let requestedControlText {
            guard let decoded = AgentTaskRequestedControl(
                rawValue: requestedControlText
            ) else {
                throw AppDatabaseError.invalidAgentTask
            }
            requestedControl = decoded
        } else {
            requestedControl = nil
        }
        guard isValidAgentTaskRequestedControl(
            requestedControl,
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
        return AgentTaskSnapshot(
            id: id,
            intentID: intentID,
            conversationID: conversationID,
            projectID: projectID,
            branchID: branchID,
            status: status,
            outcome: outcome,
            waitingReason: waitingReason,
            requestedControl: requestedControl,
            revision: revision,
            queueOrdinal: queueOrdinal,
            activeRunID: activeRunID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func isValidAgentTaskRequestedControl(
        _ control: AgentTaskRequestedControl?,
        for status: AgentTaskStatus
    ) -> Bool {
        switch status {
        case .pauseRequested:
            return control == .pauseNow
        case .stopRequested:
            return control == .stopKeepingResults
        case .reconciling:
            return true
        case .queued, .running, .paused, .waitingUser, .completed,
             .failed, .discarded:
            return control == nil
        }
    }

    static func optionalAgentTaskUUID(
        _ value: String?
    ) throws -> UUID? {
        guard let value else { return nil }
        guard let id = UUID(uuidString: value) else {
            throw AppDatabaseError.invalidAgentTask
        }
        return id
    }

    static func canonicalAgentTaskTimestamp(
        _ timestamp: Date
    ) throws -> Date {
        let microseconds = timestamp.timeIntervalSince1970 * 1_000_000
        guard microseconds.isFinite,
              microseconds >= Double(Int64.min),
              microseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidAgentTask
        }
        let epochMicroseconds = Int64(microseconds.rounded(.down))
        return Date(
            timeIntervalSince1970: Double(epochMicroseconds) / 1_000_000
        )
    }
}
