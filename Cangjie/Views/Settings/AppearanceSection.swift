//
//  AppearanceSection.swift
//  Cangjie
//
//  外观设置：主题色/深浅色/字号/行距/字体偏好，本地 @AppStorage。
//

import SwiftUI

/// 外观设置分区
struct AppearanceSection: View {

    @AppStorage("cangjie.themeMode") private var themeMode: String = ThemeMode.system.rawValue
    @AppStorage("cangjie.fontSizeScale") private var fontSizeScale: String = FontSizeScale.medium.rawValue

    var body: some View {
        // 主题模式
        Picker("主题模式", selection: $themeMode) {
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)

        // 字号
        Picker("字号", selection: $fontSizeScale) {
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
