import Foundation

public enum S1ReadableContentStatus: String, Equatable, Hashable, Sendable {
    case preparing
    case waitingForReview
    case revisedWaitingForReview
    case understandingFeedback
    case waitingForChangeDecision
    case updating
    case approved

    public var description: String {
        switch self {
        case .preparing:
            return "这一章还没有准备好"
        case .waitingForReview:
            return "这一章正在等你阅读"
        case .revisedWaitingForReview:
            return "修改后的章节正在等你阅读"
        case .understandingFeedback:
            return "仓颉正在理解你对这一章的感觉"
        case .waitingForChangeDecision:
            return "修改方向正在等你确认"
        case .updating:
            return "仓颉正在调整这一章"
        case .approved:
            return "这一章已经按你的决定保存"
        }
    }
}

public struct S1ReadableContentCandidate: Equatable, Hashable, Sendable {
    public let conversationID: UUID
    public let projectID: UUID
    public let chapterLogicalID: UUID
    public let activeVersionID: UUID
    public let versionID: UUID
    public let projectTitle: String
    public let chapterNumber: Int
    public let chapterTitle: String
    public let body: String
    public let storedContentHash: String
    public let calculatedContentHash: String
    public let stage: ChapterCalibrationStage
    public let isCommitted: Bool

    public init(
        conversationID: UUID,
        projectID: UUID,
        chapterLogicalID: UUID,
        activeVersionID: UUID,
        versionID: UUID,
        projectTitle: String,
        chapterNumber: Int,
        chapterTitle: String,
        body: String,
        storedContentHash: String,
        calculatedContentHash: String,
        stage: ChapterCalibrationStage,
        isCommitted: Bool
    ) {
        self.conversationID = conversationID
        self.projectID = projectID
        self.chapterLogicalID = chapterLogicalID
        self.activeVersionID = activeVersionID
        self.versionID = versionID
        self.projectTitle = projectTitle
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.body = body
        self.storedContentHash = storedContentHash
        self.calculatedContentHash = calculatedContentHash
        self.stage = stage
        self.isCommitted = isCommitted
    }
}

public struct S1ReadableContentProjection: Equatable, Hashable, Sendable {
    public let conversationID: UUID
    public let projectID: UUID
    public let chapterLogicalID: UUID
    public let activeVersionID: UUID
    public let projectTitle: String
    public let chapterNumber: Int
    public let chapterTitle: String
    public let body: String
    public let status: S1ReadableContentStatus

    public init(
        conversationID: UUID,
        projectID: UUID,
        chapterLogicalID: UUID,
        activeVersionID: UUID,
        projectTitle: String,
        chapterNumber: Int,
        chapterTitle: String,
        body: String,
        status: S1ReadableContentStatus
    ) {
        self.conversationID = conversationID
        self.projectID = projectID
        self.chapterLogicalID = chapterLogicalID
        self.activeVersionID = activeVersionID
        self.projectTitle = projectTitle
        self.chapterNumber = chapterNumber
        self.chapterTitle = chapterTitle
        self.body = body
        self.status = status
    }

    public var statusDescription: String {
        status.description
    }

    public static func select(
        selectedConversationID: UUID?,
        focusedProjectID: UUID?,
        candidate: S1ReadableContentCandidate?
    ) -> S1ReadableContentProjection? {
        guard let selectedConversationID,
              let focusedProjectID,
              let candidate,
              candidate.isCommitted,
              candidate.conversationID == selectedConversationID,
              candidate.projectID == focusedProjectID,
              candidate.activeVersionID == candidate.versionID,
              candidate.chapterNumber > 0,
              !candidate.projectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.chapterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.storedContentHash.isEmpty,
              candidate.storedContentHash == candidate.calculatedContentHash else {
            return nil
        }

        return S1ReadableContentProjection(
            conversationID: candidate.conversationID,
            projectID: candidate.projectID,
            chapterLogicalID: candidate.chapterLogicalID,
            activeVersionID: candidate.activeVersionID,
            projectTitle: candidate.projectTitle,
            chapterNumber: candidate.chapterNumber,
            chapterTitle: candidate.chapterTitle,
            body: candidate.body,
            status: status(for: candidate.stage)
        )
    }

    private static func status(for stage: ChapterCalibrationStage) -> S1ReadableContentStatus {
        switch stage {
        case .notStarted:
            return .preparing
        case .reviewingV1:
            return .waitingForReview
        case .reviewingV2:
            return .revisedWaitingForReview
        case .diagnosing:
            return .understandingFeedback
        case .awaitingRewriteConfirmation:
            return .waitingForChangeDecision
        case .rewriting:
            return .updating
        case .approvedFrozen:
            return .approved
        }
    }
}