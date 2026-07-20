import Foundation

public enum S1OrdinaryProgress: CaseIterable, Sendable {
    case waitingForIdea
    case understandingIdea
    case waitingForOpeningPlan
    case openingPlanChanged
    case openingPlanExpired
    case openingPlanApproved
    case chapterReady
    case reviewingChapter
    case understandingChapterFeedback
    case waitingForRewritePlan
    case rewritingChapter
    case chapterApproved
}

public enum S1OrdinarySurfaceContract {
    public static let openingPlanHeading = "确认开篇方向"
    public static let openingPlanExplanation = "确认后，仓颉会按这版方向继续；在你确认前，不会把它当成已经定下来的内容。"
    public static let openingPlanApproveButton = "就按这个方向继续"
    public static let reviewLaterButton = "稍后再说"
    public static let chapterHeading = "看看第一章"
    public static let chapterExplanation = "你的意见会决定仓颉下一步怎么改，不满意也不会直接随机重写。"
    public static let chapterApproveButton = "就按这版继续"
    public static let chapterRejectButton = "这里不对"
    public static let rewriteHeading = "确认准备怎么改"
    public static let rewriteExplanation = "仓颉只会修改这里写明的范围，没有确认前不会开始修改。"
    public static let rewriteApproveButton = "按这个范围修改"

    public static let forbiddenEngineeringTerms = [
        "Artifact",
        "Binding",
        "Tool Receipt",
        "Revision",
        "Content hash",
        "Hash",
        "minor units",
        "exact revision",
        "版本 ID",
        "请求 ID"
    ]

    public static let ordinaryReviewCopy = [
        openingPlanHeading,
        openingPlanExplanation,
        openingPlanApproveButton,
        reviewLaterButton,
        chapterHeading,
        chapterExplanation,
        chapterApproveButton,
        chapterRejectButton,
        rewriteHeading,
        rewriteExplanation,
        rewriteApproveButton
    ]

    public static func progressDescription(_ progress: S1OrdinaryProgress) -> String {
        switch progress {
        case .waitingForIdea:
            return "等你说说想写什么"
        case .understandingIdea:
            return "正在和你一起想清楚"
        case .waitingForOpeningPlan:
            return "等你确认开篇方向"
        case .openingPlanChanged:
            return "开篇方向有变化，需要重新看看"
        case .openingPlanExpired:
            return "开篇方向需要重新确认"
        case .openingPlanApproved:
            return "开篇方向已确认，准备第一章"
        case .chapterReady:
            return "可以开始准备第一章"
        case .reviewingChapter:
            return "等你看看第一章"
        case .understandingChapterFeedback:
            return "正在理解第一章哪里不对"
        case .waitingForRewritePlan:
            return "等你确认准备怎么改"
        case .rewritingChapter:
            return "正在按确认的方向修改"
        case .chapterApproved:
            return "第一章已经确认"
        }
    }


    public static func errorDescription(for diagnostic: String) -> String {
        let normalized = diagnostic.uppercased()

        if normalized.contains("DB-INIT") {
            return "暂时无法打开本地内容，请重新打开仓颉后再试"
        }
        if normalized.contains("DB-PROJECT-READER") {
            return "这次操作没有完成，请稍后再试"
        }
        if normalized.contains("DB-PROJECT-LIST") {
            return "书架暂时无法读取，请稍后再试"
        }
        if normalized.contains("S1-SELECT") {
            return "暂时无法切换到这段对话，请稍后再试"
        }
        if normalized.contains("S1-RESTORE") || normalized.contains("AGENT-RESTORE") {
            return "暂时无法恢复上次对话，请重新打开仓颉后再试"
        }
        if normalized.contains("S1-DRAFT-LIMIT") {
            return "草稿太长了，请先删减一部分再继续"
        }
        if normalized.contains("S1-INPUT-LIMIT") || normalized.contains("AGENT-INPUT-LIMIT") {
            return "你发的内容太长了，请分成几次发送"
        }
        if normalized.contains("S1-INPUT-DIRECTION") {
            return "这条消息包含会改变文字显示方向的特殊字符，请删除后再发送"
        }
        if normalized.contains("DB-DRAFT-AUTOSAVE") {
            return "草稿暂时无法保存，请稍后再试"
        }
        if normalized.contains("DB-WRITE") || normalized.contains("S1-SAVE") || normalized.contains("S1-INPUT") {
            return "这条内容暂时无法保存，请稍后再试"
        }
        if normalized.contains("DB-CHECKPOINT") {
            return "当前内容暂时无法创建恢复点，请稍后再试"
        }
        if normalized.contains("AGENT-APPROVAL-STALE") || normalized.contains("AGENT-APPROVAL-EXPIRED") {
            return "这个开篇方向已经发生变化，请重新打开最新内容"
        }
        if normalized.contains("CHAPTER-STALE") {
            return "第一章已经发生变化，请重新打开最新内容"
        }
        if normalized.contains("CHAPTER-") {
            return "这次章节操作没有完成，请稍后再试"
        }
        if normalized.contains("KEY-") {
            return "本机安全存储暂时不可用，请稍后再试"
        }
        if normalized.contains("NET-") || normalized.contains("STREAMING PROBE") {
            return "网络检查没有完成，请检查连接后重试"
        }
        if normalized.contains("BUILD-ACTIVATION") {
            return "这个安装版本暂时不能保存或执行操作"
        }
        if normalized.contains("AGENT-") {
            return "仓颉这次没有完成操作，请稍后再试"
        }
        return "这次操作没有完成，请稍后再试"
    }

    public static func noticeDescription(for diagnostic: String) -> String {
        let normalized = diagnostic.uppercased()

        if normalized.contains("RESTORED CHECKPOINT") {
            return "已恢复上次安全保存的内容"
        }
        if normalized.contains("DRAFT IS NEWER") {
            return "已恢复最新草稿"
        }
        if normalized.contains("SQLITE READY") {
            return "本地内容已准备好"
        }
        if normalized.contains("DRAFT PROTECTED BY CHECKPOINT") {
            return "当前内容已安全保存"
        }
        if normalized.contains("DRAFT SAVED") {
            return "草稿已保存"
        }
        if normalized.contains("CONNECTING TO HTTPS SSE") {
            return "正在检查网络连接…"
        }
        if normalized.contains("STREAMING PROBE COMPLETED") {
            return "网络连接检查已完成"
        }
        if normalized.contains("STREAMING PROBE CANCELLED") {
            return "已停止网络连接检查"
        }
        if normalized.contains("KEYCHAIN") || normalized.contains("ISOLATION CANARY") {
            return "本机安全存储检查已完成"
        }
        if diagnostic.hasPrefix("书架已刷新") {
            return diagnostic
        }
        return "操作已完成"
    }

    public static func chapterStageDescription(_ stage: ChapterCalibrationStage) -> String {
        switch stage {
        case .notStarted:
            return "还没有开始"
        case .reviewingV1:
            return "等你看看第一版"
        case .diagnosing:
            return "正在理解哪里不对"
        case .awaitingRewriteConfirmation:
            return "等你确认准备怎么改"
        case .rewriting:
            return "正在按确认的方向修改"
        case .reviewingV2:
            return "等你看看修改版"
        case .approvedFrozen:
            return "已经确认"
        }
    }

    public static func protectedParagraphsDescription(_ indexes: [Int]) -> String {
        let displayIndexes = normalizedDisplayIndexes(indexes)
        guard !displayIndexes.isEmpty else {
            return "还没有保留不动的段落"
        }
        return "第 " + displayIndexes.map(String.init).joined(separator: "、") + " 段会保留不动"
    }

    public static func changedParagraphsDescription(_ indexes: [Int]) -> String {
        let displayIndexes = normalizedDisplayIndexes(indexes)
        guard !displayIndexes.isEmpty else {
            return "和上一版相比没有正文变化"
        }
        return "和上一版相比，改了第 "
            + displayIndexes.map(String.init).joined(separator: "、")
            + " 段"
    }

    private static func normalizedDisplayIndexes(_ indexes: [Int]) -> [Int] {
        Array(Set(indexes.filter { $0 >= 0 })).sorted().map { $0 + 1 }
    }
}
