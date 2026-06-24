//
//  OnboardingWizardView.swift
//  Cangjie
//
//  全屏 TabView(.page) 三步向导：Bible 流式生成 → 角色创建 → 宏观规划。
//  顶部进度指示，底部上一步/下一步按钮，调 OnboardingStore。
//  对齐 Vue3 NovelSetupGuide.vue 的 Steps + 向导交互。
//

import SwiftUI

/// 新书向导视图
struct OnboardingWizardView: View {

    /// 已创建的小说
    let novel: NovelDTO

    /// 完成回调
    var onComplete: () -> Void

    @StateObject private var store = OnboardingStore()

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

                    OutlineStep()
                        .tag(OnboardingStep.macroPlanning)
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
            // 【修复】必须将 store 注入环境，否则子视图 BibleStreamingStep/
            // CharacterSetupStep/OutlineStep 的 @EnvironmentObject 找不到 store
            // → SwiftUI assertionFailure → EXC_BREAKPOINT 崩溃
            .environmentObject(store)
        }
    }

    // MARK: - 进度指示

    private var progressIndicator: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(OnboardingStep.allCases.filter { $0 != .completed && $0 != .novelInfo }, id: \.self) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(stepNumberColor(step))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("\(stepIndex(step) + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Text(step.title)
                        .font(.system(size: 10))
                        .foregroundColor(step <= store.currentStep ? Theme.textPrimary : Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)

                if stepIndex(step) < 2 {
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
                    if let prev = OnboardingStep(rawValue: store.currentStep.rawValue - 1) {
                        store.currentStep = prev
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if store.currentStep == .macroPlanning {
                Button("完成") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("下一步") {
                    if let next = OnboardingStep(rawValue: store.currentStep.rawValue + 1) {
                        store.currentStep = next
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isProcessing)
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

    private func stepIndex(_ step: OnboardingStep) -> Int {
        let steps: [OnboardingStep] = [.bibleGeneration, .characterSetup, .macroPlanning]
        return steps.firstIndex(of: step) ?? 0
    }
}
