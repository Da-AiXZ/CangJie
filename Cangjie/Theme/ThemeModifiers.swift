//
//  ThemeModifiers.swift
//  Cangjie
//
//  主题修饰符：卡片样式、章节编辑器样式等自定义 ViewModifier。
//  统一 UI 组件视觉风格。
//

import SwiftUI

// MARK: - 卡片样式修饰符

/// 卡片样式修饰符，提供统一的卡片背景、圆角、阴影。
struct CardStyleModifier: ViewModifier {

    /// 内边距
    var padding: CGFloat = Theme.Spacing.md

    /// 是否显示阴影
    var showShadow: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .if(showShadow) { view in
                view.cardShadow(UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
            }
    }
}

extension View {

    /// 应用卡片样式。
    ///
    /// - Parameters:
    ///   - padding: 内边距（默认 16pt）
    ///   - showShadow: 是否显示阴影
    /// - Returns: 样式化后的视图
    func cardStyle(
        padding: CGFloat = Theme.Spacing.md,
        showShadow: Bool = true
    ) -> some View {
        modifier(CardStyleModifier(padding: padding, showShadow: showShadow))
    }
}

// MARK: - 章节编辑器样式修饰符

/// 章节编辑器样式修饰符，提供适合长文本编辑的排版。
struct ChapterEditorStyleModifier: ViewModifier {

    /// 字号缩放
    var fontSizeScale: CGFloat

    func body(content: Content) -> some View {
        content
            .font(Theme.editorFont(scale: fontSizeScale))
            .lineSpacing(8 * fontSizeScale)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.background)
    }
}

extension View {

    /// 应用章节编辑器样式。
    ///
    /// - Parameter fontSizeScale: 字号缩放因子
    /// - Returns: 样式化后的视图
    func chapterEditorStyle(fontSizeScale: CGFloat = 1.0) -> some View {
        modifier(ChapterEditorStyleModifier(fontSizeScale: fontSizeScale))
    }
}

// MARK: - 终端日志样式修饰符

/// 终端日志样式修饰符，用于自动驾驶日志流显示。
struct TerminalStyleModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.sm)
            .background(Color.black.opacity(0.9))
            .cornerRadius(Theme.CornerRadius.small)
    }
}

extension View {

    /// 应用终端日志样式。
    ///
    /// - Returns: 样式化后的视图
    func terminalStyle() -> some View {
        modifier(TerminalStyleModifier())
    }
}

// MARK: - 状态指示器修饰符

/// 状态指示器修饰符，根据状态着色。
struct StatusColorModifier: ViewModifier {

    /// 状态字符串
    let status: String

    /// 根据状态字符串获取颜色
    private var statusColor: Color {
        let lowercased = status.lowercased()
        switch lowercased {
        case "idle", "stopped", "disconnected":
            return Theme.statusIdle
        case "running", "connected", "pending":
            return Theme.statusRunning
        case "success", "completed", "healthy":
            return Theme.statusSuccess
        case "warning", "paused", "paused_for_review":
            return Theme.statusWarning
        case "error", "failed", "unhealthy":
            return Theme.statusError
        case "bypassed":
            return Theme.statusBypassed
        case "disabled":
            return Theme.statusDisabled
        default:
            return Theme.textSecondary
        }
    }

    func body(content: Content) -> some View {
        content.foregroundColor(statusColor)
    }
}

extension View {

    /// 根据状态字符串着色。
    ///
    /// - Parameter status: 状态字符串
    /// - Returns: 着色后的视图
    func statusColor(_ status: String) -> some View {
        modifier(StatusColorModifier(status: status))
    }
}

// MARK: - 条件修饰符辅助

extension View {

    /// 条件性应用修饰符（类似 SwiftUI 5.0 的 `if` 修饰符）。
    ///
    /// - Parameters:
    ///   - condition: 条件
    ///   - transform: 修饰符变换
    /// - Returns: 修饰后的视图
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - 主题环境键

/// 主题字号缩放环境键
private struct FontSizeScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

/// 主题模式环境键
private struct ThemeModeKey: EnvironmentKey {
    static let defaultValue: ThemeMode = .system
}

extension EnvironmentValues {

    /// 字号缩放因子
    var fontSizeScale: CGFloat {
        get { self[FontSizeScaleKey.self] }
        set { self[FontSizeScaleKey.self] = newValue }
    }

    /// 主题模式
    var themeMode: ThemeMode {
        get { self[ThemeModeKey.self] }
        set { self[ThemeModeKey.self] = newValue }
    }
}
