//
//  Theme.swift
//  Cangjie
//
//  主题系统：颜色、字号、间距、圆角等设计 token。
//  适配 iPad 大屏，支持深色/浅色模式。
//

import SwiftUI

/// 主题模式，对齐原版 themeStore.ts:6 ThemeMode = 'light' | 'dark' | 'anchor' | 'auto'
/// 主理人决策：保持 system（不改 auto）
enum ThemeMode: String, CaseIterable, Codable {
    case light = "浅色"
    case dark = "深色"
    case anchor = "黑金"
    case system = "跟随系统"

    /// 转换为 ColorScheme
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .anchor:
            // anchor 是黑金模式，使用深色 ColorScheme（themeStore.ts:24-27 isDark=true）
            return .dark
        case .system:
            return nil
        }
    }

    /// 是否为深色模式（themeStore.ts:24-27 isDark computed）
    /// light → false; dark → true; anchor → true; auto → 跟随系统（这里返回 false，实际由 colorScheme=nil 时系统决定）
    var isDark: Bool {
        switch self {
        case .light:
            return false
        case .dark:
            return true
        case .anchor:
            return true
        case .system:
            return false
        }
    }

    /// 是否为黑金（主播限定色）模式（themeStore.ts:30 isAnchor computed）
    var isAnchor: Bool {
        return self == .anchor
    }
}

/// 字号档位，对齐原版 ThemeAppearanceSection.vue:101-106 SCALE_MAP
/// small=0.875, medium=1, large=1.125, xlarge=1.25
enum FontSizeScale: String, CaseIterable, Codable {
    case small = "较小"
    case medium = "默认"
    case large = "较大"
    case xlarge = "特大"

    /// 缩放因子（原版 SCALE_MAP: small=0.875, medium=1, large=1.125, xlarge=1.25）
    var scaleFactor: CGFloat {
        switch self {
        case .small:
            return 0.875
        case .medium:
            return 1.0
        case .large:
            return 1.125
        case .xlarge:
            return 1.25
        }
    }
}

/// 主题定义，包含颜色、字号、间距等设计 token。
///
/// 适配 iPad Pro 大屏，深色/浅色模式自动切换。
/// 颜色命名遵循语义化设计，不使用具体色值描述。
struct Theme {

    // MARK: - 主题色

    /// 主品牌色（仓颉墨金）
    static let accentColor = Color("AccentColor")

    /// 主品牌色（程序内引用）
    static var primary: Color { accentColor }

    /// 次要颜色
    static let secondary = Color.secondary

    // MARK: - 背景色

    /// 主背景色
    static let background = Color(.systemBackground)

    /// 次要背景色（卡片背景等）
    static let secondaryBackground = Color(.secondarySystemBackground)

    /// 第三层背景色（分组背景等）
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    // MARK: - 文字色

    /// 主文字色
    static let textPrimary = Color.primary

    /// 次要文字色
    static let textSecondary = Color.secondary

    /// 第三层文字色（占位符等）
    static let textTertiary = Color(.tertiaryLabel)

    // MARK: - 功能色

    /// 成功色
    static let success = Color.green

    /// 警告色
    static let warning = Color.orange

    /// 错误色
    static let error = Color.red

    /// 信息色
    static let info = Color.blue

    // MARK: - 状态色（DAG 节点状态）

    /// 空闲状态色
    static let statusIdle = Color.gray

    /// 运行中状态色
    static let statusRunning = Color.blue

    /// 成功状态色
    static let statusSuccess = Color.green

    /// 警告状态色
    static let statusWarning = Color.orange

    /// 错误状态色
    static let statusError = Color.red

    /// 旁路状态色
    static let statusBypassed = Color.purple

    /// 禁用状态色
    static let statusDisabled = Color.gray.opacity(0.5)

    // MARK: - 间距

    /// 间距 token
    enum Spacing {
        /// 超小间距（4pt）
        static let xxs: CGFloat = 4
        /// 小间距（8pt）
        static let xs: CGFloat = 8
        /// 中间距（12pt）
        static let sm: CGFloat = 12
        /// 标准间距（16pt）
        static let md: CGFloat = 16
        /// 大间距（20pt）
        static let lg: CGFloat = 20
        /// 超大间距（24pt）
        static let xl: CGFloat = 24
        /// 超超大间距（32pt）
        static let xxl: CGFloat = 32
    }

    // MARK: - 圆角

    /// 圆角 token
    enum CornerRadius {
        /// 小圆角（6pt）
        static let small: CGFloat = 6
        /// 中圆角（10pt）
        static let medium: CGFloat = 10
        /// 大圆角（14pt）
        static let large: CGFloat = 14
        /// 超大圆角（20pt）
        static let extraLarge: CGFloat = 20
    }

    // MARK: - 字号

    /// 字号 token（基于 16pt 基准）
    enum FontSize {
        /// 标题字号
        static func title(scale: CGFloat = 1.0) -> CGFloat { 28 * scale }
        /// 大标题字号
        static func largeTitle(scale: CGFloat = 1.0) -> CGFloat { 34 * scale }
        /// 副标题字号
        static func headline(scale: CGFloat = 1.0) -> CGFloat { 20 * scale }
        /// 正文字号
        static func body(scale: CGFloat = 1.0) -> CGFloat { 16 * scale }
        /// 正文字号（编辑器专用，略大）
        static func editorBody(scale: CGFloat = 1.0) -> CGFloat { 17 * scale }
        /// 说明文字字号
        static func caption(scale: CGFloat = 1.0) -> CGFloat { 13 * scale }
        /// 小字号
        static let footnote: CGFloat = 12
    }

    // MARK: - 便捷字体

    /// 标题字体
    static func titleFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.title(scale: scale), weight: .bold, design: .default)
    }

    /// 大标题字体
    static func largeTitleFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.largeTitle(scale: scale), weight: .bold, design: .default)
    }

    /// 副标题字体
    static func headlineFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.headline(scale: scale), weight: .semibold, design: .default)
    }

    /// 正文字体
    static func bodyFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.body(scale: scale), weight: .regular, design: .default)
    }

    /// 编辑器正文字体（等宽，便于编辑）
    static func editorFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.editorBody(scale: scale), weight: .regular, design: .serif)
    }

    /// 说明文字字体
    static func captionFont(scale: CGFloat = 1.0) -> Font {
        .system(size: FontSize.caption(scale: scale), weight: .regular, design: .default)
    }

    // MARK: - iPad 适配

    /// 判断当前设备是否为 iPad
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    /// 获取适配 iPad 的字号缩放因子
    ///
    /// iPad 上字号略大，提升阅读体验
    static var ipadScale: CGFloat {
        return isIPad ? 1.1 : 1.0
    }

    /// 三栏布局的最小宽度（iPad）
    static let sidebarWidth: CGFloat = 240
    static let inspectorWidth: CGFloat = 320

    // MARK: - 阴影

    /// 卡片阴影
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowX: CGFloat = 0
    static let cardShadowY: CGFloat = 2

    // MARK: - Anchor 黑金色系（ThemeAppearanceSection.vue:266 CSS）

    /// Anchor 金色主色（原版 #d4a843，ThemeAppearanceSection.vue:250,282,302,336,380,384,457）
    static let anchorGold = Color(red: 0xD4/255.0, green: 0xA8/255.0, blue: 0x43/255.0)

    /// Anchor 金色亮色（原版 #f5d485，ThemeAppearanceSection.vue:148 SVG渐变stop）
    static let anchorGoldLight = Color(red: 0xF5/255.0, green: 0xD4/255.0, blue: 0x85/255.0)

    /// Anchor 深色背景1（原版 #0d0e14，ThemeAppearanceSection.vue:266 linear-gradient stop1）
    static let anchorBackgroundDark = Color(red: 0x0D/255.0, green: 0x0E/255.0, blue: 0x14/255.0)

    /// Anchor 深色背景2（原版 #12141c，ThemeAppearanceSection.vue:266 linear-gradient stop2）
    static let anchorBackgroundDark2 = Color(red: 0x12/255.0, green: 0x14/255.0, blue: 0x1C/255.0)

    /// Anchor 背景渐变
    static var anchorBackground: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [anchorBackgroundDark, anchorBackgroundDark2]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // P1 补充：anchor 模式语义色（U3 决策）

    /// Anchor 强调色（金色，用于按钮/链接/选中态）
    static let anchorAccent = anchorGold

    /// Anchor 主文字色（亮金色，用于标题/主文本）
    static let anchorTextPrimary = Color(red: 0xF5/255.0, green: 0xE8/255.0, blue: 0xC8/255.0)

    /// Anchor 次文字色（暗金色，用于副文本/描述）
    static let anchorTextSecondary = Color(red: 0xB0/255.0, green: 0x9A/255.0, blue: 0x60/255.0)

    /// Anchor 卡片背景色
    static let anchorCardBackground = Color(red: 0x1A/255.0, green: 0x1C/255.0, blue: 0x24/255.0)

    /// Anchor 分隔线颜色
    static let anchorSeparator = Color(red: 0x2A/255.0, green: 0x2C/255.0, blue: 0x34/255.0)

    /// Anchor 警告色（红色偏金）
    static let anchorWarning = Color(red: 0xE8/255.0, green: 0xA8/255.0, blue: 0x43/255.0)

    /// Anchor 成功色（金色偏绿）
    static let anchorSuccess = Color(red: 0xA8/255.0, green: 0xD4/255.0, blue: 0x85/255.0)
}
