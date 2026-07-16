import Foundation

enum AgentMessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct AgentConversation: Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

struct AgentMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AgentMessageRole
    let content: String
    let createdAt: Date

    var displayText: String {
        switch role {
        case .user: return "You: " + content
        case .assistant: return "Agent: " + content
        case .system: return "System: " + content
        }
    }
}

struct AgentSessionState: Equatable {
    let focusedProjectID: UUID?
    let interviewStep: Int
    let currentQuestion: String
    let interviewAnswers: [String]
    let updatedAt: Date

    static func empty(now: Date = Date()) -> AgentSessionState {
        AgentSessionState(
            focusedProjectID: nil,
            interviewStep: 0,
            currentQuestion: AgentRuntime.interviewQuestions[0],
            interviewAnswers: [],
            updatedAt: now
        )
    }
}

enum AgentRunStatus: String, Codable, Equatable {
    case queued
    case running
    case waitingUser
    case paused
    case failed
    case completed
    case cancelled

    var canReconcileSuccessfulApproval: Bool {
        switch self {
        case .queued, .running, .waitingUser:
            return true
        case .paused, .failed, .completed, .cancelled:
            return false
        }
    }
}

struct AgentRunSnapshot: Identifiable, Equatable {
    let id: UUID
    let kind: String
    let status: AgentRunStatus
    let idempotencyKey: String
    let currentStage: String
    let startedAt: Date
    let updatedAt: Date
}

struct ProjectCreateToolResult: Equatable {
    let project: NovelProject
    let receipt: ToolReceipt
}

struct ArtifactToolResult: Equatable {
    let artifact: AgentArtifact
    let receipt: ToolReceipt
}

struct AgentRuntimeSnapshot {
    let conversation: AgentConversation
    let messages: [AgentMessage]
    let projects: [NovelProject]
    let session: AgentSessionState
    let openingPlan: AgentArtifact?
    let openingPlanApproval: ApprovalRequest?
    let lastReceipt: ToolReceipt?
    let latestRun: AgentRunSnapshot?
}

struct AgentTurnResult {
    let snapshot: AgentRuntimeSnapshot
    let status: String
}
