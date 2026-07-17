import CangJieCore
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
    let projectID: UUID?
    let kind: String
    let status: AgentRunStatus
    let idempotencyKey: String
    let currentStage: String
    let startedAt: Date
    let updatedAt: Date

    init(
        id: UUID,
        projectID: UUID? = nil,
        kind: String,
        status: AgentRunStatus,
        idempotencyKey: String,
        currentStage: String,
        startedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.projectID = projectID
        self.kind = kind
        self.status = status
        self.idempotencyKey = idempotencyKey
        self.currentStage = currentStage
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

struct ProjectCreateToolResult: Equatable {
    let project: NovelProject
    let receipt: ToolReceipt
}

struct ArtifactToolResult: Equatable {
    let artifact: AgentArtifact
    let receipt: ToolReceipt
}

/// Read-only chapter projection exposed to the Agent-first UI. Persistence and
/// state transitions remain owned by the chapter repository/tool APIs.
struct ChapterRuntimeSnapshot: Equatable {
    let calibration: ChapterCalibration
    let activeVersion: ChapterVersion
    let versions: [ChapterVersion]
    let lastReceipt: ToolReceipt?

    var stage: ChapterCalibrationStage { calibration.stage }
    var activeDiagnosisEntries: [ChapterDiagnosisEntry] {
        calibration.diagnosisEntries.filter {
            $0.versionID == activeVersion.id && $0.versionHash == activeVersion.contentHash
        }
    }

    var diagnosisAnswers: [String] {
        activeDiagnosisEntries.map(\.answer)
    }

    var nextDiagnosisQuestionIndex: Int {
        min(activeDiagnosisEntries.count, ChapterDiagnosisProtocol.orderedQuestionIDs.count)
    }
}

struct AgentRuntimeSnapshot {
    let conversation: AgentConversation
    let messages: [AgentMessage]
    let projects: [NovelProject]
    let session: AgentSessionState
    let openingPlan: AgentArtifact?
    let openingPlanApproval: ApprovalRequest?
    let chapter: ChapterRuntimeSnapshot?
    let lastReceipt: ToolReceipt?
    let latestRun: AgentRunSnapshot?
}

struct AgentTurnResult {
    let snapshot: AgentRuntimeSnapshot
    let status: String
}
