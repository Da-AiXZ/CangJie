//
//  OutlineStep.swift
//  Cangjie
//
//  向导第3步：宏观规划提示页。
//
//  【修复】原实现在 onAppear 自动调用 store.startMacroPlanning() 触发 macro API，
//  但原版 Vue 向导（NovelSetupGuide.vue）全程不调 macro API——宏观规划是工作台
//  MacroPlanModal.vue 手动触发的。向导第3步误调 macro 导致 autopilot 启动报 409
//  （结构未确认/未生成）。现改为纯提示页，引导用户进入工作台后手动触发宏观规划。
//

import SwiftUI

/// 宏观规划提示步骤（向导第3步）
///
/// 对齐原版 Vue NovelSetupGuide.vue：向导不调 macro API，
/// macro 在工作台 MacroPlanModal 手动触发。
struct OutlineStep: View {

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 图标
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.primary)
                    .padding(.top, Theme.Spacing.xxl)

                // 标题
                Text("进入工作台后生成宏观结构")
                    .font(Theme.headlineFont())
                    .foregroundColor(Theme.textPrimary)

                // 说明文字
                Text("宏观规划将在工作台中手动触发。进入工作台后，请点击工具栏的「宏观规划」按钮，AI 会生成故事骨架（部/卷/幕），确认后即可启动自动驾驶托管。")
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.lg)

                // 步骤指引卡片
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    macroStep(number: 1, icon: "wand.and.stars",
                              title: "点击「宏观规划」",
                              desc: "在工作台工具栏点击宏观规划按钮")
                    macroStep(number: 2, icon: "sparkles",
                              title: "AI 生成故事骨架",
                              desc: "AI 自动编排 部 → 卷 → 幕 结构")
                    macroStep(number: 3, icon: "checkmark.circle.fill",
                              title: "确认写入结构树",
                              desc: "审阅后确认，结构将写入数据库")
                    macroStep(number: 4, icon: "car.fill",
                              title: "启动自动驾驶",
                              desc: "结构就绪后即可启动全托管")
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 步骤指引项

    /// 渲染单个步骤指引
    private func macroStep(number: Int, icon: String, title: String, desc: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // 序号圆
            ZStack {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            // 图标
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.primary)
                .frame(width: 24)

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyFont())
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
