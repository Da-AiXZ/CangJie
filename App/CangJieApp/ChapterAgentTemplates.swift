import CangJieCore
import Foundation

enum ChapterAgentIntent: Equatable {
    case generate
    case accept
    case reject
    case confirmRewrite
    case provideDiagnosis
    case status
    case unknown
}

enum ChapterAgentTemplates {
    static let diagnosisQuestions = ChapterDiagnosisProtocol.orderedQuestions

    static func intent(for text: String, stage: ChapterCalibrationStage) -> ChapterAgentIntent {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if containsAny(normalized, ["进度怎么样", "现在怎么样", "当前状态", "什么状态", "查看进度", "状态", "进度", "status", "how is it going"]) {
            return .status
        }
        if containsAny(normalized, ["确认重写", "按这个范围重写", "按确认范围重写", "同意重写范围", "confirm rewrite", "rewrite with this scope"]) {
            return .confirmRewrite
        }
        if containsAny(normalized, ["接受并冻结", "批准并冻结", "通过这一版", "确认通过", "接受这一版", "accept and freeze", "approve chapter"]) {
            return .accept
        }
        if containsAny(normalized, ["拒绝", "不通过", "不满意", "不对味", "退回修改", "reject", "not good", "rewrite this chapter"]) {
            return .reject
        }
        if containsAny(normalized, ["生成第一章", "开始第一章", "写第一章", "生成章节", "generate chapter", "generate the first chapter"]) {
            return .generate
        }
        if normalized == "继续" || normalized == "continue" {
            return stage == .notStarted ? .generate : .unknown
        }
        if stage == .diagnosing, !normalized.isEmpty { return .provideDiagnosis }
        return .unknown
    }

    static func isBlindRegenerationRequest(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return containsAny(normalized, ["直接重写", "重新生成", "再来一版", "换一版", "重抽一次", "regenerate", "reroll", "try again"])
    }

    static func isLowInformationDiagnosisAnswer(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        return ["不好", "不对", "一般", "没感觉", "随便", "不知道", "是", "否", "好", "继续", "ok", "okay", "continue", "yes", "no"].contains(normalized)
    }

    static func initialChapterBody(project: NovelProject, openingPlan: AgentArtifact) -> String {
        let premise = project.premise.trimmingCharacters(in: .whitespacesAndNewlines)
        let centralPremise = premise.isEmpty ? openingPlan.title : premise
        return [
            "第一章 命运转折",
            "暮色压在山门石阶上，少年攥紧掌心，知道自己若再退一步，往后便只能任人安排命运。",
            "他此刻唯一能够抓住的线索，正指向那桩无人愿意明说的秘密：\(centralPremise)。代价已经摆在眼前，但他没有第二条路。",
            "当众人的目光逼来时，他没有解释，而是做出了第一个无法收回的选择。",
            "石门在身后合拢。黑暗深处传来一声轻响，像有什么东西终于等到了他。"
        ].joined(separator: "\n\n")
    }

    static func initialEvidenceReview(openingPlan: AgentArtifact) -> String {
        [
            "Evidence review",
            "- Opening-plan revision: \(openingPlan.revision)",
            "- Opening-plan hash: \(openingPlan.contentHash)",
            "- Checks: immediate desire introduced; first pressure established; cost made explicit; irreversible chapter-end question present.",
            "- Guardrail: no unapproved world rule, modern-tech contamination, or character-knowledge escalation was introduced."
        ].joined(separator: "\n")
    }

    static func diagnosisSummary(answers: [String], lockedParagraphIndexes: [Int]) -> String {
        let padded = answers + Array(repeating: "未回答", count: max(0, diagnosisQuestions.count - answers.count))
        let locked = lockedParagraphIndexes.sorted().map(String.init).joined(separator: ", ")
        return [
            "Chapter 1 rejection diagnosis",
            "Root cause: \(padded[0])",
            "Must preserve: \(padded[1])",
            "Required ending effect: \(padded[2])",
            "Locked paragraph indexes: \(locked.isEmpty ? "none" : locked)"
        ].joined(separator: "\n")
    }

    static func rewriteScope(summary: String, source: ChapterVersion) -> String {
        [
            "Rewrite only Chapter 1 revision \(source.revision).",
            "Source version: \(source.id.uuidString)",
            "Source hash: \(source.contentHash)",
            "Apply the confirmed diagnosis below without changing locked paragraphs or silently adding canon:",
            summary
        ].joined(separator: "\n")
    }

    static func revisedChapterBody(source: ChapterVersion, snapshot: ChapterRuntimeSnapshot) -> String {
        let paragraphCount = ChapterContentIntegrity.paragraphs(in: source.body).count
        let locked = Set(snapshot.calibration.lockedParagraphIndexes)
        let rootCause = snapshot.diagnosisAnswers.first ?? "需要强化人物动机与场景压力"
        let ending = snapshot.diagnosisAnswers.count > 2
            ? snapshot.diagnosisAnswers[2]
            : "让读者明确期待主角下一步行动"

        return ChapterContentIntegrity.rewritingParagraphs(in: source.body) { index, paragraph in
            guard !locked.contains(index) else { return paragraph }
            switch index {
            case 0:
                return paragraph
            case 1:
                return "压力没有给他喘息的时间。对手当众封死退路，迫使他立刻在屈服与承担代价之间作出选择。"
            case 2:
                return "他终于看清真正的问题并非眼前输赢，而是\(rootCause)。这个判断让他的行动变得明确，也让每一步都必须付出代价。"
            case _ where index == paragraphCount - 1:
                return "决定落下的瞬间，局势彻底越过了能够回头的界线。章末必须实现的效果是：\(ending)。新的威胁随即显形。"
            default:
                return "\(paragraph)\n这一变化直接推动了人物选择，没有用解释性总结替代行动。"
            }
        }
    }

    static func revisedEvidenceReview(source: ChapterVersion, snapshot: ChapterRuntimeSnapshot) -> String {
        let locked = snapshot.calibration.lockedParagraphIndexes.sorted().map(String.init).joined(separator: ", ")
        return [
            "Evidence review for revision \(source.revision + 1)",
            "- Source version/hash: \(source.id.uuidString) / \(source.contentHash)",
            "- Diagnosis hash: \(snapshot.calibration.diagnosisHash)",
            "- Rewrite-scope hash: \(snapshot.calibration.rewriteScopeHash ?? "missing")",
            "- Locked paragraphs preserved byte-for-byte at indexes: \(locked.isEmpty ? "none" : locked)",
            "- No direct reroll was used; this revision is bound to the confirmed diagnosis and scope."
        ].joined(separator: "\n")
    }

    static func fingerprint(_ fields: [String]) -> String {
        ApprovalFingerprint.parametersHash(fields.joined(separator: "|"))
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }
}