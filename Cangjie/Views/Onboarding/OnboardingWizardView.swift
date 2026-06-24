//
//  OnboardingWizardView.swift
//  Cangjie
//
//  全屏 TabView(.page) 五步向导：Bible 流式生成 → 角色创建 → 地点创建 → 剧情总纲 → 完成。
//  对齐 Vue3 NovelSetupGuide.vue:12-18 的 Steps + 向导交互。
//  阶段3：新增第4步剧情总纲（PlotOutlineStep）。
//  Q4决策：maxVisitedStep 模式（顺序前进+后退到已到步骤）。
//

import SwiftUI

/// 新书向导视图
struct OnboardingWizardView: View {

    /// 已创建的小说
    let novel: NovelDTO

    /// 完成回调
    var onComplete: () -> Void

    @StateObject private var store = OnboardingStore()

    /// 向导步骤列表（5步：设定→角色→地点→剧情总纲→完成）
    private let wizardSteps: [OnboardingStep] = [.bibleGeneration, .characterSetup, .locationSetup, .plotOutline]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部进度指示
                progressIndicator

                // 步骤内容
                TabView(selection: $store.currentStep) {
                    BibleStreamingStep()
                        .tag(OnboardingStep.bibleGeneration)

                    CharacterSetupStep()
                        .tag(OnboardingStep.characterSetup)

                    LocationSetupStep()
                        .tag(OnboardingStep.locationSetup)

                    PlotOutlineStep()
                        .tag(OnboardingStep.plotOutline)

                    // 第5步：完成页
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("向导已完成")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("你可以进入工作台开始写作了。")
                            .foregroundColor(.secondary)
                        Button("进入工作台") {
                            if let novelId = store.createdNovel?.id {
                                WizardUiCache.markCompleted(novelId: novelId)
                            }
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .tag(OnboardingStep.completed)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // 底部导航按钮
                bottomBar
            }
            .background(Theme.background)
            .navigationTitle("新书向导")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳过") { onComplete() }
                        .font(Theme.captionFont())
                }
            }
            .onAppear {
                store.createdNovel = novel
                store.currentStep = .bibleGeneration
                store.maxVisitedStep = 1
            }
            .alert("错误", isPresented: .constant(store.errorMessage != nil)) {
                Button("确定") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
            // AI 审批面板（Sheet）
            .sheet(isPresented: $store.aiInvocationStore.visible) {
                NavigationStack {
                    AIInvocationReviewPanel(store: store.aiInvocationStore)
                }
            }
            .environmentObject(store)
        }
    }

    // MARK: - 进度指示（5步）

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(wizardSteps.indices, id: \.self) { index in
                let step = wizardSteps[index]
                VStack(spacing: 4) {
                    Circle()
                        .fill(stepNumberColor(step))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text(step.title)
                        .font(.system(size: 10))
                        .foregroundColor(step <= store.currentStep ? Theme.textPrimary : Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                if index < wizardSteps.count - 1 {
                    Rectangle()
                        .fill(step < store.currentStep ? Theme.primary : Theme.textTertiary.opacity(0.3))
                        .frame(height: 2)
                        .padding(.top, -14)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 底部栏

    private var bottomBar: some View {
        HStack {
            if store.currentStep != .bibleGeneration {
                Button("上一步") {
                    store.handlePrev()
                }
                .buttonStyle(.bordered)
                .disabled(store.isWizardGenerating)
            }

            Spacer()

            if store.currentStep == .plotOutline {
                // 第4步：确认修改并继续
                Button("确认修改并继续") {
                    Task {
                        let success = await store.savePlotOutlineEdits()
                        if success {
                            store.handleNext()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isProcessing || store.plotOutlineBusy || store.plotOutline == nil)
            } else if store.currentStep == .completed {
                // 第5步：进入工作台
                Button("进入工作台") {
                    if let novelId = store.createdNovel?.id {
                        WizardUiCache.markCompleted(novelId: novelId)
                    }
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("下一步") {
                    Task {
                        // 保存当前编辑（Q4决策：向导每步"下一步"时调用保存）
                        await store.updateBible()
                        store.handleNext()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isProcessing || store.isWizardGenerating)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 辅助

    private func stepNumberColor(_ step: OnboardingStep) -> Color {
        if step < store.currentStep {
            return Theme.primary
        } else if step == store.currentStep {
            return Theme.primary
        } else {
            return Theme.textTertiary.opacity(0.3)
        }
    }
}

// MARK: - 辅助类型

/// 空请求体（用于 POST body: {}）
struct EmptyBody: Codable {}

/// 剧情总纲保存请求
struct PlotOutlineSaveRequest: Codable {
    let plotOutline: PlotOutlineDTO

    enum CodingKeys: String, CodingKey {
        case plotOutline = "plot_outline"
    }
}
