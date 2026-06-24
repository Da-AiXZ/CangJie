//
//  AppearanceSection.swift
//  Cangjie
//
//  外观设置：4档主题（浅色/深色/黑金/跟随系统）+ 4档字号（较小/默认/较大/特大）。
//  对齐原版 ThemeAppearanceSection.vue:131-156（4档主题）+ :101-113（4档字号）。
//  字号标签名统一为原版标签（决策1）。
//

import SwiftUI

/// 外观设置分区
struct AppearanceSection: View {

    /// 通过 AppState 绑定主题和字号，确保变更立即触发 @Published → 视图重建
    @EnvironmentObject var appState: AppState

    /// 主题模式 Binding（String ↔ ThemeMode 转换）
    private var themeModeBinding: Binding<String> {
        Binding(
            get: { appState.themeMode.rawValue },
            set: { newValue in
                if let mode = ThemeMode(rawValue: newValue) {
                    appState.themeMode = mode
                }
            }
        )
    }

    /// 字号 Binding（String ↔ FontSizeScale 转换）
    private var fontSizeScaleBinding: Binding<String> {
        Binding(
            get: { appState.fontSizeScale.rawValue },
            set: { newValue in
                if let scale = FontSizeScale(rawValue: newValue) {
                    appState.fontSizeScale = scale
                }
            }
        )
    }

    var body: some View {
        // 主题模式（4档：浅色/深色/黑金/跟随系统，ThemeAppearanceSection.vue:131-156）
        Picker("主题模式", selection: themeModeBinding) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)

        // 字号（4档：较小/默认/较大/特大，ThemeAppearanceSection.vue:101-113）
        Picker("字号", selection: fontSizeScaleBinding) {
            ForEach(FontSizeScale.allCases, id: \.self) { scale in
                Text(scale.rawValue).tag(scale.rawValue)
            }
        }
        .pickerStyle(.segmented)

        // 预览
        VStack(alignment: .leading, spacing: 4) {
            Text("预览")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            // anchor 模式预览为黑金配色（ThemeAppearanceSection.vue:266 CSS）
            if appState.isAnchor {
                // 黑金模式预览
                HStack {
                    Text("仓颉 — 长篇叙事工作台")
                        .font(Theme.bodyFont(scale: Theme.ipadScale))
                        .foregroundColor(Theme.anchorGoldLight)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.anchorBackground)
                .cornerRadius(Theme.CornerRadius.medium)
            } else {
                Text("仓颉 — 长篇叙事工作台")
                    .font(Theme.bodyFont(scale: Theme.ipadScale))
            }
        }
    }
}
