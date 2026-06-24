//
//  OnboardingWizardView.swift
//  Cangjie
//
//  全屏 TabView(.page) 三步向导：Bible 流式生成 → 角色创建 → 地点创建。
//  顶部进度指示，底部上一步/下一步按钮，调 OnboardingStore。
//  对齐 Vue3 NovelSetupGuide.vue:12-18 的 Steps + 向导交互。
//  Q4决策：去掉 macroPlanning 步骤的 UI 入口，保留 Store 中 macroPlanning 逻辑供工作台 MacroPlanModal 使用。
//

import SwiftUI

/// 新书向导视图
struct OnboardingWizardView: View {

    /// 已创建的小说
    let novel: NovelDTO

    /// 完成回调
    var onComplete: () -> Void

    @StateObject private var store = OnboardingStore()

    /// 向导步骤列表（Q4决策：3步，不含 macroPlanning）
    private let wizardSteps: [OnboardingStep] = [.bibleGeneration, .characterSetup, .locationSetup]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部进度指示
                progressIndicator

                // 步骤内容（Q4决策：3步 worldbuilding → characters → locations）
                TabView(selection: $store.currentStep) {
                    BibleStreamingStep()
                        .tag(OnboardingStep.bibleGeneration)

                    CharacterSetupStep()
                        .tag(OnboardingStep.characterSetup)

                    LocationSetupStep()
                        .tag(OnboardingStep.locationSetup)
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
            }
            .alert("错误", isPresented: .constant(store.errorMessage != nil)) {
                Button("确定") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
            // 【修复】必须将 store 注入环境，否则子视图的 @EnvironmentObject 找不到 store
            .environmentObject(store)
        }
    }

    // MARK: - 进度指示

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
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if store.currentStep == .locationSetup {
                // 最后一步：完成按钮
                Button("完成") {
                    Task {
                        // 保存最终 Bible（NovelSetupGuide.vue:1912-1931 updateBible）
                        await store.updateBible()
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isProcessing || store.generatingLocations)
            } else {
                Button("下一步") {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isProcessing || store.generatingBible || store.generatingCharacters)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 步骤导航

    /// 上一步
    private func goToPreviousStep() {
        guard let currentIndex = wizardSteps.firstIndex(of: store.currentStep) else { return }
        if currentIndex > 0 {
            store.currentStep = wizardSteps[currentIndex - 1]
        }
    }

    /// 下一步（每步"下一步"时调 updateBible 保存，NovelSetupGuide.vue:2076-2114 handleNext）
    private func goToNextStep() {
        Task {
            // 保存当前编辑（Q4决策：向导每步"下一步"时调用保存）
            await store.updateBible()

            guard let currentIndex = wizardSteps.firstIndex(of: store.currentStep) else { return }
            if currentIndex < wizardSteps.count - 1 {
                store.currentStep = wizardSteps[currentIndex + 1]
            }
        }
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
