//
//  ChartColors.swift
//  Cangjie
//
//  图表配色常量，对齐原版 constants/chartTheme.ts CHART_COLORS。
//  A-1：Swift Charts 配色统一引用。
//

import SwiftUI

// MARK: - 图表配色

/// 图表配色常量，对齐原版 constants/chartTheme.ts CHART_COLORS。
struct ChartColors {
    /// 主色 — chartTheme.ts:2
    static let primary = Color(red: 0x66/255, green: 0x7e/255, blue: 0xea/255)

    /// 成功色 — chartTheme.ts:3
    static let success = Color(red: 0x10/255, green: 0xb9/255, blue: 0x81/255)

    /// 灰色 — chartTheme.ts:4
    static let gray = Color(red: 0xe5/255, green: 0xe7/255, blue: 0xeb/255)

    /// 渐变起始色（半透明主色）— chartTheme.ts:5
    static let gradientStart = Color(red: 0x66/255, green: 0x7e/255, blue: 0xea/255).opacity(0.3)

    /// 渐变终止色（极淡主色）— chartTheme.ts:6
    static let gradientEnd = Color(red: 0x66/255, green: 0x7e/255, blue: 0xea/255).opacity(0.05)
}
