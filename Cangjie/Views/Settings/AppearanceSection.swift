//
//  AppearanceSection.swift
//  Cangjie
//
//  外观设置：主题色/深浅色/字号/行距/字体偏好，本地 @AppStorage。
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
        // 主题模式
        Picker("主题模式", selection: themeModeBinding) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)

        // 字号
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
            Text("仓颉 — 长篇叙事工作台")
                .font(Theme.bodyFont(scale: Theme.ipadScale))
        }
    }
}
