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

struct S1PreviewConversationAppendResult: Equatable {
    let conversation: AgentConversation
    let messages: [AgentMessage]
    let workspace: S1ConversationWorkspaceSnapshot?

    init(
        conversation: AgentConversation,
        messages: [AgentMessage],
        workspace: S1ConversationWorkspaceSnapshot? = nil
    ) {
        self.conversation = conversation
        self.messages = messages
        self.workspace = workspace
    }
}

struct S1PreviewMessageWindow: Equatable {
    let messages: [AgentMessage]
    let hasEarlierMessages: Bool
}

struct S1ConversationWorkspaceSnapshot: Equatable {
    let selectedConversation: AgentConversation?
    let conversations: [AgentConversation]
    let draft: String
    let messageWindow: S1PreviewMessageWindow
}

struct AgentMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: AgentMessageRole
    let content: String
    let createdAt: Date

    var displayText: String {
        let speaker: S1ConversationSpeaker
        switch role {
        case .user:
            speaker = .user
        case .assistant:
            speaker = .assistant
        case .system:
            speaker = .system
        }
        let displayedContent = role == .assistant
            ? AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage(content)
            : content
        return S1ConversationPreview.displayText(speaker: speaker, content: displayedContent)
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
    case reconciling
    case waitingUser
    case paused
    case failed
    case completed
    case cancelled

    var canReconcileSuccessfulApproval: Bool {
        switch self {
        case .queued, .running, .reconciling, .waitingUser:
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
