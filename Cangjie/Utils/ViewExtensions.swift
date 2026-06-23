//
//  ViewExtensions.swift
//  Cangjie
//
//  SwiftUI View 通用扩展：条件修饰符、shimmer 加载动画、隐藏键盘等。
//

import SwiftUI
import UIKit

// MARK: - 条件修饰符

extension View {

    /// 条件性地应用修饰符。
    ///
    /// 当 `condition` 为 true 时应用 `transform`，否则返回原视图。
    /// 用于在运行时决定是否添加某些修饰符，避免 if-else 分支。
    ///
    /// ```swift
    /// text.conditionallyApply(isEditing) { view in
    ///     view.border(Color.blue)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - condition: 是否应用修饰符
    ///   - transform: 修饰符变换闭包
    /// - Returns: 修饰后的视图
    @ViewBuilder
    func conditionallyApply<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 条件性地应用可选修饰符。
    ///
    /// 当 `condition` 为 true 时应用 `transform(value)`，否则返回原视图。
    /// 适合需要传入条件值的场景。
    ///
    /// - Parameters:
    ///   - value: 可选的条件值
    ///   - transform: 修饰符变换闭包，接收条件值
    /// - Returns: 修饰后的视图
    @ViewBuilder
    func conditionallyApply<T, Content: View>(
        _ value: T?,
        transform: (Self, T) -> Content
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Shimmer 加载动画

/// Shimmer 加载动画修饰符，用于骨架屏占位。
struct ShimmerModifier: ViewModifier {

    /// 是否激活动画
    let active: Bool

    /// 动画状态
    @State private var animationPhase: CGFloat = -1.0

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: animationPhase * 200)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            animationPhase = 1.0
                        }
                    }
                )
                .mask(content)
                .redacted(reason: active ? .placeholder : [])
        } else {
            content
        }
    }
}

extension View {

    /// 应用 shimmer 加载动画。
    ///
    /// - Parameter active: 是否激活动画
    /// - Returns: 带有 shimmer 效果的视图
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

// MARK: - 隐藏键盘

extension View {

    /// 收起键盘。
    ///
    /// 在 iOS 16 上通过 UIResponder 查找键盘实例来收起，
    /// 兼容 TextEditor 和 TextField。
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 圆角裁剪

extension View {

    /// 对指定角进行圆角裁剪。
    ///
    /// - Parameters:
    ///   - radius: 圆角半径
    ///   - corners: 需要圆角的角
    /// - Returns: 裁剪后的视图
    func cornerRadius(
        _ radius: CGFloat,
        corners: UIRectCorner
    ) -> some View {
        clipShape(
            RoundedCorner(radius: radius, corners: corners)
        )
    }
}

/// 自定义圆角形状，支持指定角圆角。
struct RoundedCorner: Shape {

    /// 圆角半径
    var radius: CGFloat

    /// 需要圆角的角
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 便捷修饰符

extension View {

    /// 设置自适应字号，适配 iPad 大屏。
    ///
    /// - Parameter scale: 字号缩放因子（1.0 = 默认）
    /// - Returns: 缩放后的视图
    func scaledFontSize(_ scale: CGFloat) -> some View {
        environment(\.font, .system(size: 16 * scale))
    }

    /// 添加卡片阴影。
    ///
    /// - Parameter colorScheme: 当前颜色方案
    /// - Returns: 带阴影的视图
    @ViewBuilder
    func cardShadow(_ colorScheme: ColorScheme) -> some View {
        shadow(
            color: colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - 粘贴按钮

extension View {

    /// 在视图右侧添加一个粘贴按钮，点击读取系统剪贴板并填入指定 Binding。
    ///
    /// 用于 TrollStore 侧载环境下，SwiftUI 长按"粘贴"菜单不可靠的场景。
    /// 用户可以直接点击粘贴按钮将剪贴板内容填入输入框，
    /// 无需依赖长按手势或第三方键盘。
    ///
    /// 用法：
    /// ```swift
    /// TextField("API Key", text: $apiKey)
    ///     .pasteButton(into: $apiKey)
    /// ```
    ///
    /// - Parameter binding: 要填入的文本绑定
    /// - Returns: 包含原视图和粘贴按钮的 HStack
    func pasteButton(into binding: Binding<String>) -> some View {
        HStack {
            self
            Button {
                // 读取系统剪贴板内容并填入
                if let text = UIPasteboard.general.string {
                    binding.wrappedValue = text
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.primary)
            }
            .buttonStyle(.plain)
        }
    }
}
