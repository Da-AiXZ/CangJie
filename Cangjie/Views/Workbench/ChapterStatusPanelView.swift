//
//  ChapterStatusPanelView.swift
//  Cangjie
//
//  章节状态面板，对齐原版 components/workbench/ChapterStatusPanel.vue:1-417。
//  基本信息+正文结构+自动审阅8步+质量评分+生成质检。
//

import SwiftUI

/// 章节状态面板视图
///
/// 对齐原版 `components/workbench/ChapterStatusPanel.vue`。
struct ChapterStatusPanelView: View {

    /// 小说 ID（对齐 :279 props.slug）
    let novelId: String

    /// 章节信息（对齐 :280 props.chapter）
    let chapter: ChapterInfo?

    /// 只读模式（对齐 :281 props.readOnly）
    var readOnly: Bool = false

    /// 生成质检结果（对齐 :282 props.lastWorkflowResult）
    var lastWorkflowResult: GenerateChapterWorkflowResponse? = nil

    /// 质检章节号（对齐 :283 props.qcChapterNumber）
    var qcChapterNumber: Int? = nil

    /// 自动驾驶审阅（对齐 :284 props.autopilotChapterReview）
    var autopilotChapterReview: AutopilotChapterAudit? = nil

    // MARK: - 回调（对齐 :287-290 emits）

    var onClearQC: (() -> Void)? = nil
    var onGoEditor: (() -> Void)? = nil

    // MARK: - 状态

    @State private var metaLoading = false
    @State private var chapterStructure: ChapterStructureDTO?

    private let apiClient = APIClient.shared

    // MARK: - Body

    var body: some View {
        if chapter == nil {
            // 对齐 :3 空状态
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.textTertiary)
                Text("请从左侧选择一个章节")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    // 对齐 :7-20 章节基本信息
                    chapterInfoCard

                    // 对齐 :22-24 只读警告
                    if readOnly {
                        readOnlyWarning
                    }

                    // 对齐 :27-54 正文结构
                    structureCard

                    // 对齐 :57-178 自动审阅
                    if let review = autopilotChapterReview {
                        autopilotReviewCard(review)
                    }

                    // 对齐 :181-239 生成质检
                    if let workflow = lastWorkflowResult, let qcNum = qcChapterNumber {
                        qualityCheckCard(workflow, qcNum: qcNum)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .task {
                await loadChapterMeta()
            }
            .onChange(of: chapter?.number) { _ in
                Task { await loadChapterMeta() }
            }
        }
    }

    // MARK: - 章节基本信息卡（对齐 :7-20）

    private var chapterInfoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("第 \(chapter?.number ?? 0) 章")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                    Text(chapter?.title ?? "未命名")
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text((chapter?.wordCount ?? 0) > 0 ? "已收稿" : "未收稿")
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background((chapter?.wordCount ?? 0) > 0 ? Theme.success.opacity(0.15) : Color.gray.opacity(0.1))
                        .cornerRadius(999)
                        .foregroundColor((chapter?.wordCount ?? 0) > 0 ? Theme.success : Theme.textTertiary)
                    Text("\(chapter?.wordCount ?? 0) 字")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 只读警告（对齐 :22-24）

    private var readOnlyWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.warning)
            Text("全托管执行中，辅助撰稿区仅可阅读")
                .font(.system(size: 12))
                .foregroundColor(Theme.warning)
        }
        .padding(10)
        .background(Theme.warning.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - 正文结构卡（对齐 :27-54）

    private var structureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 正文结构")
                .font(.system(size: 13, weight: .semibold))

            if let struct_ = chapterStructure {
                HStack(spacing: 12) {
                    structureItem(label: "分段", value: "\(struct_.paragraphCount)")
                    structureItem(label: "场景", value: "\(struct_.sceneCount)")
                    structureItem(label: "对白", value: "\(Int(struct_.dialogueRatio * 100))%")
                    structureItem(label: "节奏", value: pacingLabel(struct_.pacing))
                }
            } else if metaLoading {
                ProgressView()
            } else {
                Text("暂无结构分析")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    private func structureItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 自动审阅卡（对齐 :57-178）

    private func autopilotReviewCard(_ review: AutopilotChapterAudit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🤖 自动审阅")
                .font(.system(size: 13, weight: .semibold))

            // 对齐 :62-68 章节不匹配提示
            if let chNum = chapter?.number, chNum != review.chapterNumber {
                Text("为第 \(review.chapterNumber) 章结果")
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Theme.info.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(Theme.info)
            }

            // 对齐 :72-80 张力评估
            VStack(alignment: .leading, spacing: 6) {
                Text("张力评估")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.tertiaryBackground)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(colors: [.green, .orange, .red], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(review.tension) / 10.0, height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text("\(review.tension)/10")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 40, alignment: .trailing)
                }
            }

            // 对齐 :83-108 章后管线8步
            aftermathStepsSection(review)

            // 对齐 :111-134 文风检测
            VStack(alignment: .leading, spacing: 6) {
                Text("文风检测")
                    .font(.system(size: 12, weight: .semibold))
                HStack {
                    Text("相似度")
                    Spacer()
                    if let score = review.similarityScore {
                        Text(String(format: "%.3f", score))
                    } else {
                        Text("指纹不足（需 ≥10 样本）")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                HStack {
                    Text("漂移告警")
                    Spacer()
                    if review.similarityScore != nil {
                        Text(review.driftAlert ? "⚠ 告警" : "✓ 正常")
                            .font(.system(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(review.driftAlert ? Theme.error.opacity(0.15) : Theme.success.opacity(0.15))
                            .cornerRadius(999)
                            .foregroundColor(review.driftAlert ? Theme.error : Theme.success)
                    } else {
                        Text("待采样")
                            .font(.system(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(999)
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            // 对齐 :137-152 质量评分
            if let scores = review.qualityScores, !scores.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("质量评分")
                        .font(.system(size: 12, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(scores.sorted(by: { $0.key < $1.key }), id: \.key) { key, score in
                            HStack(spacing: 8) {
                                Text(qualityLabel(key))
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(width: 50, alignment: .leading)
                                ProgressView(value: score)
                                    .tint(score > 0.7 ? .green : score > 0.4 ? .orange : .red)
                                Text("\(Int(score * 100))")
                                    .font(.system(size: 11))
                            }
                        }
                    }
                }
            }

            // 对齐 :155-170 问题摘要
            if let issues = review.issues, !issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("问题摘要")
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(issues.prefix(3)) { issue in
                        Text(issue.message)
                            .font(.system(size: 11))
                            .padding(8)
                            .background(issueBg(issue.severity))
                            .cornerRadius(8)
                            .foregroundColor(issueFg(issue.severity))
                    }
                    if issues.count > 3 {
                        Text("还有 \(issues.count - 3) 条问题...")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }

            // 对齐 :173-176 审阅时间
            if let at = review.at {
                HStack {
                    Text("审阅时间")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text(formatTime(at))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 章后管线8步（对齐 :90-108, 330-359）

    private func aftermathStepsSection(_ review: AutopilotChapterAudit) -> some View {
        let steps = aftermathSteps(review)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("章后管线")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(aftermathSummary(steps))
                    .font(.system(size: 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(aftermathTagColor(steps).opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(aftermathTagColor(steps))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(steps) { step in
                    aftermathStepCell(step)
                }
            }
        }
    }

    struct AftermathStep: Identifiable {
        let index: Int
        let id: String
        let label: String
        let detail: String
        let state: String // "done"/"fail"/"pending"
    }

    private func aftermathSteps(_ r: AutopilotChapterAudit) -> [AftermathStep] {
        func boolStep(_ i: Int, _ id: String, _ label: String, _ detail: String, _ value: Bool?, _ failWhenFalse: Bool = false) -> AftermathStep {
            let state = value == true ? "done" : (value == false && failWhenFalse ? "fail" : "pending")
            return AftermathStep(index: i, id: id, label: label, detail: detail, state: state)
        }
        return [
            boolStep(1, "narrative_summary", "摘要事件", "章节摘要、事件、场景信号写入叙事层", r.narrativeSyncOk, true),
            boolStep(2, "beat_sections", "叙事节拍", "大纲段落与 beat_sections 对齐", r.narrativeSyncOk, true),
            boolStep(3, "vector_index", "向量索引", "章节语义检索索引可被后续上下文命中", r.vectorStored),
            boolStep(4, "foreshadow", "伏笔账本", "埋线、兑现、回收信号进入账本", r.foreshadowStored),
            boolStep(5, "kg_triples", "KG 三元组", "人物、地点、道具与关系事实抽取", r.triplesExtracted),
            boolStep(6, "causal_edges", "因果边", "动作后果、承诺兑现链路更新", r.causalEdgesStored),
            boolStep(7, "character_state", "角色状态", "角色关系、情绪与立场突变投影", r.characterMutationsStored ?? r.characterReconcileOk),
            boolStep(8, "narrative_debt", "叙事债务", "未兑现承诺、风险与后续压力更新", r.debtUpdated ?? r.evolutionSnapshotOk),
        ]
    }

    private func aftermathSummary(_ steps: [AftermathStep]) -> String {
        let failed = steps.filter { $0.state == "fail" }.count
        let done = steps.filter { $0.state == "done" }.count
        if failed > 0 { return "\(failed) 项需复查" }
        if done == steps.count { return "全部完成" }
        if done > 0 { return "\(done)/\(steps.count) 已确认" }
        return "等待结果"
    }

    private func aftermathTagColor(_ steps: [AftermathStep]) -> Color {
        let failed = steps.filter { $0.state == "fail" }.count
        let done = steps.filter { $0.state == "done" }.count
        if failed > 0 { return Theme.warning }
        if done == steps.count { return Theme.success }
        if done > 0 { return Theme.info }
        return Theme.textTertiary
    }

    private func aftermathStepCell(_ step: AftermathStep) -> some View {
        let color: Color = step.state == "done" ? Theme.success : step.state == "fail" ? Theme.warning : Theme.textTertiary
        return HStack(alignment: .top, spacing: 8) {
            Text("\(step.index)")
                .font(.system(size: 10, weight: .heavy))
                .frame(width: 20, height: 20)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(999)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(step.label)
                        .font(.system(size: 12, weight: .bold))
                    if step.state == "done" {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.success)
                    } else if step.state == "fail" {
                        Image(systemName: "exclamationmark").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.warning)
                    }
                }
                Text(step.detail)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(8)
        .background(step.state == "pending" ? Theme.tertiaryBackground : color.opacity(0.06))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        .opacity(step.state == "pending" ? 0.72 : 1.0)
    }

    // MARK: - 生成质检卡（对齐 :181-239）

    private func qualityCheckCard(_ workflow: GenerateChapterWorkflowResponse, qcNum: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✨ 生成质检")
                .font(.system(size: 13, weight: .semibold))

            // 对齐 :187-192 章节不匹配提示
            if let chNum = chapter?.number, chNum != qcNum {
                Text("为第 \(qcNum) 章质检结果")
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Theme.info.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(Theme.info)
            }

            // 对齐 :194-198 ConsistencyReportPanel（独立子组件，对齐决策5）
            ChapterAuditSectionView(
                report: workflow.consistencyReport,
                tokenCount: workflow.tokenCount
            )

            // 对齐 :200-217 俗套句式折叠
            if let warnings = workflow.styleWarnings, !warnings.isEmpty {
                DisclosureGroup("俗套句式 \(warnings.count) 处") {
                    VStack(spacing: 6) {
                        ForEach(warnings) { w in
                            HStack {
                                Text(w.pattern)
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                Text("「\(w.text)」")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(8)
                            .background(Theme.tertiaryBackground)
                            .cornerRadius(8)
                        }
                    }
                }
                .font(.system(size: 12))
            }

            // 对齐 :234-237 操作按钮
            HStack(spacing: 8) {
                Button("打开编辑") { onGoEditor?() }
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
                Button("清除") { onClearQC?() }
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 辅助函数

    private func pacingLabel(_ p: String) -> String {
        switch p {
        case "fast": return "快"
        case "medium": return "中"
        case "slow": return "慢"
        default: return p
        }
    }

    private func qualityLabel(_ key: String) -> String {
        switch key {
        case "coherence": return "连贯性"
        case "vividness": return "生动性"
        case "emotion": return "情感"
        case "rhythm": return "节奏"
        default: return key
        }
    }

    private func issueBg(_ severity: String) -> Color {
        switch severity {
        case "error": return Theme.error.opacity(0.1)
        case "warning": return Theme.warning.opacity(0.1)
        default: return Theme.info.opacity(0.1)
        }
    }

    private func issueFg(_ severity: String) -> Color {
        switch severity {
        case "error": return Theme.error
        case "warning": return Theme.warning
        default: return Theme.info
        }
    }

    private func formatTime(_ t: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: t) else { return t }
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "zh_CN")
        displayFormatter.dateFormat = "M/d HH:mm"
        return displayFormatter.string(from: date)
    }

    // MARK: - 加载章节结构（对齐 :392-404 loadChapterMeta）

    private func loadChapterMeta() async {
        chapterStructure = nil
        guard !novelId.isEmpty, let ch = chapter else { return }
        metaLoading = true
        do {
            chapterStructure = try await apiClient.request(
                APIEndpoint.Chapters.structure(novelId: novelId, chapterNumber: ch.number)
            )
        } catch {
            chapterStructure = nil
        }
        metaLoading = false
    }
}

// MARK: - ChapterInfo

/// 章节信息（对齐 :252-257 Chapter interface）
struct ChapterInfo: Equatable {
    let id: String
    let number: Int
    let title: String
    let wordCount: Int
}
