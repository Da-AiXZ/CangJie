import Foundation

public enum AgentRuntimeCanonicalMessage {
    public static let strategicQuestions = [
        "What is the one-sentence hook that makes this novel impossible to confuse with another?",
        "Who is the protagonist before the first major change, and what do they want right now?",
        "What concrete cost or danger makes the first victory matter?"
    ]

    public static func projectCreated(title: String) -> String {
        "Project created: \(title)"
    }

    public static let askForNovelIdea =
        "Tell me the idea or ask me to create a novel, and I will lead the next step."

    public static let openingPlanAwaitingConfirmation =
        "The opening plan is waiting for your exact approval. Review the bound revision, budget, expiration, and expected change before we continue."

    public static let openingPlanPrepared =
        "I have compiled the opening plan. Review its exact approval card before chapter planning."

    public static let openingPlanConfirmed =
        "Opening plan approved and persisted. Chapter planning is now unlocked."

    public static let chapterPlanningUnlocked =
        "Chapter planning is unlocked. Say \u{2018}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{5F00}\u{59CB}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{7EE7}\u{7EED}\u{2019}, or \u{2018}generate chapter\u{2019} to begin the governed Chapter 1 calibration."

    public static let chapterGenerationReady =
        "Chapter 1 is ready to generate when you say \u{2018}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019} or \u{2018}\u{7EE7}\u{7EED}\u{2019}."

    public static func chapterReviewReminder(revision: Int) -> String {
        "Review Chapter 1 revision \(revision). You may accept and freeze it, or reject it and enter diagnosis. I will not reroll it without a diagnosis."
    }

    public static let rewriteConfirmationRequired =
        "The diagnosis and exact rewrite scope are ready. Confirm that scope before I create revision 2; a generic regenerate request will not bypass this gate."

    public static func approvedChapterAudit(revision: Int) -> String {
        "Chapter 1 revision \(revision) is approved and frozen. Its versions, diagnosis, and tool receipts remain available for audit."
    }

    public static let firstChapterReady =
        "Chapter 1 revision 1 has been generated and evidence-reviewed. Review the exact revision, then accept and freeze it or reject it for diagnosis."

    public static func diagnosisStarted(question: String) -> String {
        "I will not reroll the chapter. We will diagnose it one high-information question at a time.\n\n" + question
    }

    public static func diagnosisNeedsMoreDetail(question: String) -> String {
        "A direct reroll would hide the root cause and is not allowed. Please answer the current diagnosis question with one concrete observation:\n\n" + question
    }

    public static func diagnosisComplete(summary: String, scope: String) -> String {
        "Diagnosis complete. Review the exact rewrite scope before revision 2 is created.\n\n\(summary)\n\nRewrite scope:\n\(scope)\n\nSay \u{2018}\u{786E}\u{8BA4}\u{91CD}\u{5199}\u{2019} to authorize only this scope."
    }

    public static func rewrittenChapterReady(revision: Int) -> String {
        "Chapter 1 revision \(revision) is ready. Locked paragraphs were verified byte-for-byte. Review the V1/V2 diff, then accept and freeze this final calibration candidate."
    }

    public static func chapterConfirmed(revision: Int) -> String {
        "Chapter 1 revision \(revision) is approved and frozen. The exact content hash, version history, and receipts have been preserved."
    }

    public static let chapterStatusNotStarted = "Chapter 1 has not started."

    public static func chapterStatusReviewing(revision: Int) -> String {
        "Chapter 1 revision \(revision) is waiting for your review."
    }

    public static func chapterStatusDiagnosing(question: Int, total: Int) -> String {
        "Chapter 1 is in diagnosis question \(question) of \(total)."
    }

    public static let chapterStatusAwaitingRewriteConfirmation =
        "The diagnosis is complete and the exact rewrite scope is waiting for confirmation."

    public static let chapterStatusRewriting =
        "The confirmed Chapter 1 rewrite is resumable from its idempotent tool binding."

    public static func chapterStatusConfirmed(revision: Int) -> String {
        "Chapter 1 revision \(revision) is approved and frozen."
    }
}

public enum AgentRuntimeOrdinaryCopy {
    public enum Delivery: CaseIterable, Sendable {
        case normal
        case recovered
        case replayed
    }

    public enum ChapterStatus: Sendable {
        case notStarted
        case reviewing
        case diagnosing(question: Int, total: Int)
        case awaitingRewriteConfirmation
        case rewriting
        case confirmed
    }

    public static let strategicQuestions = [
        "这本小说最不容易和别的书混淆的一句话卖点是什么？",
        "故事刚开始时，主角是什么样的人，他现在最想要什么？",
        "第一次胜利需要付出什么具体代价，或者会带来什么危险？"
    ]

    public static func projectCreated(title: String) -> String {
        "已经为你建好《\(title)》。名字和方向都可以之后再调整。"
    }

    public static let askForNovelIdea =
        "你可以直接说想写什么，哪怕只有一个模糊念头也可以，我会带你继续往下想。"

    public static let openingPlanAwaitingConfirmation =
        "开篇方向已经整理好，正在等你确认。确认前我不会开始写第一章。"

    public static let openingPlanPrepared =
        "我已经把刚才讨论的内容整理成开篇方向。你看过并确认后，我们再准备第一章。"

    public static func openingPlanConfirmed(delivery: Delivery) -> String {
        _ = delivery
        return "开篇方向已经确认。接下来可以开始准备第一章。"
    }

    public static let chapterGenerationReady =
        "开篇方向已经确认。你说“生成第一章”或“继续”，我就开始准备第一章。"

    public static let chapterReviewReminder =
        "第一章已经准备好，正在等你看。满意就说“这一章就这样”，不满意直接告诉我哪里不对，我会先弄清原因，不会盲目重写。"

    public static let rewriteConfirmationRequired =
        "我已经根据你的反馈整理好准备怎么改。你确认这个理解后，我才会动手；只说“重写”不会跳过这一步。"

    public static func firstChapterReady(delivery: Delivery) -> String {
        _ = delivery
        return "第一章已经准备好了。你可以先看看；满意就说“这一章就这样”，不满意直接告诉我哪里不对。"
    }

    public static func diagnosisStarted(question: String) -> String {
        "我先不直接重写。我们先用一个最关键的问题找出哪里不对。\n\n\(question)"
    }

    public static func diagnosisNeedsMoreDetail(question: String) -> String {
        "我还没法从这句话判断真正问题，现在直接重写容易改错方向。请结合一个具体感受回答这个问题：\n\n\(question)"
    }

    public static func rewritePlan(summary: String, scope: String) -> String {
        _ = scope
        let lines = summary.split(whereSeparator: \.isNewline).map(String.init)
        let rootCause = value(after: "Root cause:", in: lines) ?? "还需要再确认"
        let mustPreserve = value(after: "Must preserve:", in: lines) ?? "你已经认可的内容"
        let endingEffect = value(after: "Required ending effect:", in: lines) ?? "符合你期待的章末感受"
        let lockedValue = value(after: "Locked paragraph indexes:", in: lines)
        let lockedDescription = lockedParagraphDescription(lockedValue)

        return [
            "我已经把你的反馈整理成准备怎么改：",
            "最主要的问题：\(rootCause)",
            "必须保留：\(mustPreserve)",
            "章末要达到的效果：\(endingEffect)",
            lockedDescription,
            "我只会调整第一章中需要改的内容，不会动你要求保留的段落，也不会擅自增加新设定。",
            "如果这个理解对，说“确认重写”就可以。"
        ].joined(separator: "\n")
    }

    public static func rewrittenChapterReady(delivery: Delivery) -> String {
        _ = delivery
        return "第一章已经按你确认的方向改好了。你要求保留的段落没有被改动，现在可以看看整体是否对味。"
    }

    public static func chapterConfirmed(delivery: Delivery) -> String {
        _ = delivery
        return "第一章已经确认。我会保留当前内容，后面继续写时以这一版为准。"
    }

    public static func projectPersistedAssistantMessage(_ content: String) -> String {
        if let index = AgentRuntimeCanonicalMessage.strategicQuestions.firstIndex(of: content) {
            return strategicQuestions[index]
        }

        switch content {
        case AgentRuntimeCanonicalMessage.askForNovelIdea:
            return askForNovelIdea
        case AgentRuntimeCanonicalMessage.openingPlanAwaitingConfirmation:
            return openingPlanAwaitingConfirmation
        case AgentRuntimeCanonicalMessage.openingPlanPrepared:
            return openingPlanPrepared
        case AgentRuntimeCanonicalMessage.openingPlanConfirmed:
            return openingPlanConfirmed(delivery: .normal)
        case AgentRuntimeCanonicalMessage.chapterPlanningUnlocked,
             AgentRuntimeCanonicalMessage.chapterGenerationReady:
            return chapterGenerationReady
        case AgentRuntimeCanonicalMessage.rewriteConfirmationRequired:
            return rewriteConfirmationRequired
        case AgentRuntimeCanonicalMessage.firstChapterReady:
            return firstChapterReady(delivery: .normal)
        case AgentRuntimeCanonicalMessage.chapterStatusNotStarted:
            return chapterStatus(.notStarted)
        case AgentRuntimeCanonicalMessage.chapterStatusAwaitingRewriteConfirmation:
            return chapterStatus(.awaitingRewriteConfirmation)
        case AgentRuntimeCanonicalMessage.chapterStatusRewriting:
            return chapterStatus(.rewriting)
        default:
            break
        }

        let projectPrefix = "Project created: "
        if content.hasPrefix(projectPrefix) {
            return projectCreated(title: String(content.dropFirst(projectPrefix.count)))
        }

        let diagnosisPrefix =
            "I will not reroll the chapter. We will diagnose it one high-information question at a time.\n\n"
        if content.hasPrefix(diagnosisPrefix) {
            return diagnosisStarted(question: String(content.dropFirst(diagnosisPrefix.count)))
        }

        let detailPrefix =
            "A direct reroll would hide the root cause and is not allowed. Please answer the current diagnosis question with one concrete observation:\n\n"
        if content.hasPrefix(detailPrefix) {
            return diagnosisNeedsMoreDetail(question: String(content.dropFirst(detailPrefix.count)))
        }

        if let diagnosis = diagnosisParts(from: content) {
            return rewritePlan(summary: diagnosis.summary, scope: diagnosis.scope)
        }

        if content.hasPrefix("Review Chapter 1 revision "),
           content.hasSuffix("I will not reroll it without a diagnosis.") {
            return chapterReviewReminder
        }
        if content.hasPrefix("Chapter 1 revision "),
           content.hasSuffix("Locked paragraphs were verified byte-for-byte. Review the V1/V2 diff, then accept and freeze this final calibration candidate.") {
            return rewrittenChapterReady(delivery: .normal)
        }
        if content.hasPrefix("Chapter 1 revision "),
           (content.hasSuffix("Its versions, diagnosis, and tool receipts remain available for audit.")
                || content.hasSuffix("The exact content hash, version history, and receipts have been preserved.")) {
            return chapterConfirmed(delivery: .normal)
        }
        if content.hasPrefix("Chapter 1 revision "),
           content.hasSuffix("is waiting for your review.") {
            return chapterStatus(.reviewing)
        }
        if content.hasPrefix("Chapter 1 is in diagnosis question ") {
            let numbers = content.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            if numbers.count >= 2 {
                return chapterStatus(.diagnosing(question: numbers[0], total: numbers[1]))
            }
        }
        if content.hasPrefix("Chapter 1 revision "),
           content.hasSuffix("is approved and frozen.") {
            return chapterStatus(.confirmed)
        }
        if content.hasPrefix("Verified:") {
            return "这一步已经完成，相关内容和记录都已安全保存。"
        }

        return content
    }

    public static func chapterStatus(_ status: ChapterStatus) -> String {
        switch status {
        case .notStarted:
            return "第一章还没有开始准备。你说“生成第一章”或“继续”就可以开始。"
        case .reviewing:
            return "第一章已经准备好，正在等你看。"
        case let .diagnosing(question, total):
            return "我正在理解第一章哪里不对，目前还需要你回答第 \(question) 个问题，共 \(total) 个。"
        case .awaitingRewriteConfirmation:
            return "我已经整理好准备怎么改，正在等你确认。"
        case .rewriting:
            return "我正在按你确认的方向修改第一章。中断后也可以继续，不会重复修改。"
        case .confirmed:
            return chapterConfirmed(delivery: .normal)
        }
    }

    static var contractSamples: [String] {
        let fixedSamples = [
            projectCreated(title: "测试小说"), askForNovelIdea,
            openingPlanAwaitingConfirmation, openingPlanPrepared,
            chapterGenerationReady, chapterReviewReminder, rewriteConfirmationRequired,
            diagnosisStarted(question: "这里最不对的是什么？"),
            diagnosisNeedsMoreDetail(question: "这里最不对的是什么？"),
            rewritePlan(
                summary: "Root cause: 人物反应不对\nMust preserve: 对话\nRequired ending effect: 紧张\nLocked paragraph indexes: 1",
                scope: "internal"
            ),
            chapterStatus(.notStarted), chapterStatus(.reviewing),
            chapterStatus(.diagnosing(question: 1, total: 3)),
            chapterStatus(.awaitingRewriteConfirmation), chapterStatus(.rewriting), chapterStatus(.confirmed)
        ]
        let deliverySamples = Delivery.allCases.flatMap { delivery in
            [
                openingPlanConfirmed(delivery: delivery),
                firstChapterReady(delivery: delivery),
                rewrittenChapterReady(delivery: delivery),
                chapterConfirmed(delivery: delivery)
            ]
        }
        return fixedSamples + deliverySamples
    }

    private static func diagnosisParts(from content: String) -> (summary: String, scope: String)? {
        let prefix = "Diagnosis complete. Review the exact rewrite scope before revision 2 is created.\n\n"
        let scopeMarker = "\n\nRewrite scope:\n"
        let suffix = "\n\nSay \u{2018}\u{786E}\u{8BA4}\u{91CD}\u{5199}\u{2019} to authorize only this scope."
        guard content.hasPrefix(prefix), content.hasSuffix(suffix) else { return nil }

        let body = content.dropFirst(prefix.count).dropLast(suffix.count)
        guard let markerRange = body.range(of: scopeMarker) else { return nil }
        let summary = String(body[..<markerRange.lowerBound])
        let scope = String(body[markerRange.upperBound...])
        guard !summary.isEmpty, !scope.isEmpty else { return nil }
        return (summary, scope)
    }

    private static func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func lockedParagraphDescription(_ value: String?) -> String {
        guard let value, value.localizedCaseInsensitiveCompare("none") != .orderedSame else {
            return "没有额外锁定的段落。"
        }
        let indexes = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !indexes.isEmpty else { return "没有额外锁定的段落。" }
        return "已经锁定第 \(indexes.joined(separator: "、")) 段，修改时不会动它们。"
    }
}
