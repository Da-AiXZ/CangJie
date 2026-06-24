//
//  QualityGuardrailPanel.swift
//  Cangjie
//
//  质量护栏面板：总分圆形进度 + 六维度条形图 + 违规折叠列表 + 模式切换。
//  对齐原版 QualityGuardrailPanel.vue:1-330 + chapterWriting.ts:71-157。
//  机制4：每个区块标注原版文件+行号。
//

import SwiftUI

/// 质量护栏面板 — QualityGuardrailPanel.vue:1-330
struct QualityGuardrailPanel: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var novelStore: NovelStore
    @StateObject private var monitorStore = MonitorStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {

                // 区块1: 无章节时显示空状态 — QualityGuardrailPanel.vue:3
                if novelStore.currentChapter == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.textTertiary)
                        Text("请从左侧选择一个章节")
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    guardrailContent
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        // 区块: 切换章节时自动加载快照 — QualityGuardrailPanel.vue:240-246
        .onChange(of: novelStore.currentChapter?.number) { _ in
            loadSnapshot()
        }
        .onAppear {
            loadSnapshot()
        }
    }

    // MARK: - 护栏内容 — QualityGuardrailPanel.vue:5-136

    private var guardrailContent: some View {
        VStack(spacing: 10) {
            // 区块2: 顶部操作栏 — QualityGuardrailPanel.vue:7-31
            guardrailHeader

            // 区块3: info提示 — QualityGuardrailPanel.vue:33-38
            infoBanner

            // 区块4: 检查中 / 检查结果 / 空状态
            if monitorStore.isCheckingGuardrail {
                // QualityGuardrailPanel.vue:41 n-spin
                ProgressView("检查中…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if let report = monitorStore.guardrailReport {
                // 区块5: 总分圆形进度条 — QualityGuardrailPanel.vue:44-61
                overallScoreCard(report)

                // 区块6: 六维度条形图 — QualityGuardrailPanel.vue:63-87
                dimensionsCard(report)

                // 区块7: 违规详情 — QualityGuardrailPanel.vue:89-125
                if !report.violations.isEmpty {
                    violationsCard(report)
                } else {
                    // QualityGuardrailPanel.vue:122-125
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("所有维度检查通过，无违规项。")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                // QualityGuardrailPanel.vue:128-134
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textTertiary)
                    Text("尚无自动快照：请先保存本章正文；也可点「重新检查」立即运行")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            }
        }
    }

    // MARK: - 顶部操作栏 — QualityGuardrailPanel.vue:7-31

    private var guardrailHeader: some View {
        HStack {
            // 章节号 + 通过标签 — QualityGuardrailPanel.vue:8-13
            VStack(alignment: .leading, spacing: 2) {
                Text("第 \(novelStore.currentChapter?.number ?? 0) 章 质量检查")
                    .font(.system(size: 13, weight: .bold))
                if monitorStore.guardrailReport != nil {
                    Text(monitorStore.guardrailPassed ? "✓ 通过" : "✗ 未通过")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(monitorStore.guardrailPassed ? Color.green : Color.orange)
                        .cornerRadius(10)
                }
            }

            Spacer()

            // 模式选择 — QualityGuardrailPanel.vue:15-20
            Picker("模式", selection: $monitorStore.guardrailMode) {
                Text("建议模式").tag("advise")
                Text("强制模式").tag("enforce")
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            // 重新检查按钮 — QualityGuardrailPanel.vue:21-29
            Button {
                runCheck()
            } label: {
                Text(monitorStore.isCheckingGuardrail ? "检查中…" : "重新检查")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(monitorStore.isCheckingGuardrail || novelStore.currentChapter?.wordCount == 0)
        }
    }

    // MARK: - info提示 — QualityGuardrailPanel.vue:33-38

    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("保存章节正文后，系统会在后台自动运行建议模式护栏并写入快照；此处可查看快照或手动再次检查。")
                .font(.system(size: 11))
            Text("分数为小说家向启发式标尺（非读者打分）：缺具体章节目标、视点元数据或可用的人设约束时会保守折价，分项意在标出问题而非追求虚高。")
                .font(.system(size: 10))
                .opacity(0.92)
        }
        .foregroundColor(Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - 总分圆形进度条 — QualityGuardrailPanel.vue:44-61

    private func overallScoreCard(_ report: GuardrailCheckResponse) -> some View {
        HStack(spacing: 16) {
            // 圆形进度条 — QualityGuardrailPanel.vue:46-55
            ZStack {
                Circle()
                    .stroke(Theme.textTertiary.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: CGFloat(report.overallScore))
                    .stroke(guardrailScoreColor(report.overallScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(report.overallScore * 100))")
                    .font(.system(size: 20, weight: .bold))
            }

            // 综合评分标签 — QualityGuardrailPanel.vue:56-59
            VStack(alignment: .leading, spacing: 2) {
                Text("综合评分")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                Text("\(Int(report.overallScore * 100))")
                    .font(.system(size: 20, weight: .bold))
            }

            Spacer()
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 六维度条形图 — QualityGuardrailPanel.vue:63-87

    private func dimensionsCard(_ report: GuardrailCheckResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("六维度评分")
                .font(.system(size: 13, weight: .semibold))

            ForEach(report.dimensions) { dim in
                // QualityGuardrailPanel.vue:69-85 dimension-row
                HStack(spacing: 8) {
                    // 维度名称 — vue:70
                    Text(guardrailDimensionLabel(dim.key))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .frame(minWidth: 72, alignment: .leading)

                    // 进度条 — vue:71-78
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.textTertiary.opacity(0.15))
                                .frame(height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(guardrailScoreColor(dim.score))
                                .frame(width: geo.size.width * CGFloat(dim.score), height: 12)
                        }
                    }
                    .frame(height: 12)

                    // 分数 — vue:79-81
                    Text("\(Int(dim.score * 100))")
                        .font(.system(size: 12))
                        .frame(minWidth: 36, alignment: .trailing)

                    // 权重 — vue:82-84
                    Text("×\(Int(dim.weight * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 违规详情 — QualityGuardrailPanel.vue:89-120

    @State private var expandedViolationIndex: Int? = 0

    private func violationsCard(_ report: GuardrailCheckResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("违规详情 (\(report.violations.count))")
                .font(.system(size: 13, weight: .semibold))

            ForEach(Array(report.violations.enumerated()), id: \.offset) { index, v in
                // QualityGuardrailPanel.vue:95-118 n-collapse-item
                VStack(alignment: .leading, spacing: 4) {
                    // 折叠头部 — vue:100-107
                    Button {
                        expandedViolationIndex = expandedViolationIndex == index ? nil : index
                    } label: {
                        HStack(spacing: 6) {
                            // 严重程度标签 — vue:102-104
                            Text(guardrailSeverityLabel(v.severity))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(guardrailSeverityColor(v.severity))
                                .cornerRadius(8)

                            // 维度标签 — vue:105
                            Text(guardrailDimensionLabel(v.dimension))
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.textTertiary.opacity(0.15))
                                .cornerRadius(8)

                            // 角色名 — vue:106
                            if !v.character.isEmpty {
                                Text("→ \(v.character)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }

                            Spacer()

                            Image(systemName: expandedViolationIndex == index ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    // 展开内容 — vue:109-117
                    if expandedViolationIndex == index {
                        VStack(alignment: .leading, spacing: 4) {
                            // 描述 — vue:110
                            if !v.description.isEmpty {
                                Text(v.description)
                                    .font(.system(size: 12))
                            }
                            // 原文 — vue:111-113
                            if !v.original.isEmpty {
                                HStack(spacing: 4) {
                                    Text("原文：").font(.system(size: 11)).foregroundColor(Theme.textTertiary)
                                    Text("「\(v.original)」")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            // 建议 — vue:114-116
                            if !v.suggestion.isEmpty {
                                HStack(spacing: 4) {
                                    Text("💡").font(.system(size: 11))
                                    Text(v.suggestion)
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                }
                                .padding(6)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(4)
                            }
                        }
                        .padding(.leading, 4)
                    }

                    if index < report.violations.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 方法

    /// 手动检查 — QualityGuardrailPanel.vue:200-225 runCheck()
    private func runCheck() {
        guard let chapter = novelStore.currentChapter,
              let novelId = appState.currentNovelId else { return }

        Task {
            await monitorStore.loadGuardrailCheck(
                novelId: novelId,
                text: chapter.content,
                chapterNumber: chapter.number,
                chapterTitle: chapter.title,
                characterNames: []
            )
        }
    }

    /// 加载快照 — QualityGuardrailPanel.vue:227-238 hydrateFromSnapshot()
    private func loadSnapshot() {
        guard let novelId = appState.currentNovelId,
              let chapter = novelStore.currentChapter else {
            monitorStore.guardrailReport = nil
            return
        }

        Task {
            await monitorStore.loadGuardrailSnapshot(
                novelId: novelId,
                chapterNumber: chapter.number
            )
        }
    }
}
