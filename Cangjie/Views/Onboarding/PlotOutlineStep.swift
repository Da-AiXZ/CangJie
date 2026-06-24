//
//  PlotOutlineStep.swift
//  Cangjie
//
//  向导第4步：剧情总纲（生成+审批+可编辑卡片）。
//  对齐原版 NovelSetupGuide.vue:522-675 UI + 1068-1454 逻辑。
//  机制4：每个区块标注原版文件+行号。
//

import SwiftUI

/// 向导第4步：剧情总纲 — NovelSetupGuide.vue:522-675
struct PlotOutlineStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 区块1: 缓存恢复提示 — NovelSetupGuide.vue:524-533
                if store.step4RestoredFromCache {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已恢复上次生成的剧情总纲预览（本地缓存）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }

                // 区块2: 初始说明区 — NovelSetupGuide.vue:534-540
                if store.plotOutline == nil && !store.plotOutlineBusy {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("生成剧情总纲")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("基于世界观、人物和地图设定，AI 将推演故事主线、拆分阶段并规划章节范围。")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("开始生成") {
                            Task { await store.loadPlotOutline() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                // 区块3: 错误提示 — NovelSetupGuide.vue:542-544
                if !store.plotOutlineError.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(store.plotOutlineError)
                            .foregroundColor(.red)
                        Spacer()
                        Button("重试") {
                            Task { await store.loadPlotOutline() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // 区块4: 已保存提示 — NovelSetupGuide.vue:545-547
                if store.plotOutlineCommitted && store.plotOutline != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已保存剧情总纲")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // 区块5: 生成中状态 — NovelSetupGuide.vue:549-588
                if store.plotOutlineBusy && store.plotOutline == nil {
                    plotOutlineGeneratingView
                }

                // 区块6: 可编辑卡片 — NovelSetupGuide.vue:590-658
                if let outline = store.editablePlotOutline {
                    editablePlotOutlineCard(outline)
                }

                // 区块7: 重新生成+AI审阅按钮 — NovelSetupGuide.vue:661-673
                if store.plotOutline != nil {
                    HStack(spacing: 12) {
                        Button("重新生成") {
                            Task { await store.refreshPlotOutline() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.plotOutlineBusy)

                        if !store.plotOutlineSessionId.isEmpty {
                            Button("打开AI审阅") {
                                Task { await store.openPlotOutlineReviewPanel(sessionId: store.plotOutlineSessionId) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.plotOutlineBusy)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .onAppear {
            if store.plotOutline == nil && !store.plotOutlineBusy && !store.plotOutlineError.isEmpty == false {
                Task { await store.loadPlotOutline() }
            }
        }
    }

    // MARK: - 生成中视图 — NovelSetupGuide.vue:549-588

    private var plotOutlineGeneratingView: some View {
        VStack(spacing: 16) {
            // 生成头部
            HStack {
                ProgressView()
                VStack(alignment: .leading) {
                    Text("生成剧情总纲")
                        .font(.headline)
                    Text(store.plotOutlineStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // 进度项
            VStack(spacing: 8) {
                ForEach(store.plotOutlineProgressItems) { item in
                    HStack {
                        Circle()
                            .fill(progressStateColor(item.state))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(item.label).font(.caption).fontWeight(.medium)
                            Text(item.desc).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(8)

            // 实时预览
            if !store.plotOutlineLivePreview.isEmpty {
                Text(store.plotOutlineLivePreview)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Theme.background)
                    .cornerRadius(4)
            }
        }
        .padding()
    }

    // MARK: - 可编辑卡片 — NovelSetupGuide.vue:590-658

    private func editablePlotOutlineCard(_ outline: PlotOutlineDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("剧情总纲")
                .font(.headline)

            // 顶层字段编辑
            VStack(alignment: .leading, spacing: 8) {
                Text(plotFieldLabel("main_story_overview"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $store.editablePlotOutline.mainStoryOverview)
                    .frame(minHeight: 80)
                    .border(Theme.textTertiary.opacity(0.3))

                Text(plotFieldLabel("core_conflict"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $store.editablePlotOutline.coreConflict)
                    .frame(minHeight: 60)
                    .border(Theme.textTertiary.opacity(0.3))

                Text(plotFieldLabel("expected_ending"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $store.editablePlotOutline.expectedEnding)
                    .frame(minHeight: 60)
                    .border(Theme.textTertiary.opacity(0.3))
            }

            // 阶段规划列表
            Text("阶段规划")
                .font(.subheadline)
                .fontWeight(.medium)

            ForEach(Array(outline.stagePlan.enumerated()), id: \.offset) { index, stage in
                stageEditor(index: index, stage: stage)
            }
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 阶段编辑器 — NovelSetupGuide.vue:620-658

    private func stageEditor(index: Int, stage: PlotOutlineStageDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stage.label.isEmpty ? "阶段 \(index + 1)" : stage.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(store.stageRangePercentLabel(index: index))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("起始章节").font(.caption2).foregroundColor(.secondary)
                    TextField("1", value: Binding(
                        get: { store.editablePlotOutline.stagePlan[index].chapterStart ?? 0 },
                        set: { store.updateStageChapterNumber(index: index, key: "chapter_start", value: $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                }
                VStack(alignment: .leading) {
                    Text("结束章节").font(.caption2).foregroundColor(.secondary)
                    TextField("15", value: Binding(
                        get: { store.editablePlotOutline.stagePlan[index].chapterEnd ?? 0 },
                        set: { store.updateStageChapterNumber(index: index, key: "chapter_end", value: $0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                }
            }

            Text("阶段任务").font(.caption2).foregroundColor(.secondary)
            TextEditor(text: Binding(
                get: { store.editablePlotOutline.stagePlan[index].summary },
                set: { store.editablePlotOutline.stagePlan[index].summary = $0 }
            ))
            .frame(minHeight: 60)
            .border(Theme.textTertiary.opacity(0.3))
        }
        .padding()
        .background(Theme.background)
        .cornerRadius(6)
    }

    // MARK: - 辅助

    private func progressStateColor(_ state: PlotOutlineProgressState) -> Color {
        switch state {
        case .done: return .green
        case .active: return .blue
        case .pending: return .gray.opacity(0.3)
        }
    }
}
