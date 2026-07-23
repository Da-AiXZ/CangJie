import CangJieCore
import Foundation

enum AgentTaskRequestedControl: String, Equatable {
    case pauseNow
    case stopKeepingResults
}

struct AgentTaskSnapshot: Identifiable, Equatable {
    let id: UUID
    let intentID: UUID
    let conversationID: UUID
    let projectID: UUID?
    let branchID: UUID?
    let status: AgentTaskStatus
    let outcome: AgentTaskOutcome?
    let waitingReason: AgentTaskWaitingReason?
    let requestedControl: AgentTaskRequestedControl?
    let revision: Int
    let queueOrdinal: Int64
    let activeRunID: UUID?
    let createdAt: Date
    let updatedAt: Date
}

struct AgentTaskTransitionResult: Equatable {
    let task: AgentTaskSnapshot
    let promotedTask: AgentTaskSnapshot?
}
