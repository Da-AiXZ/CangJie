//
//  AppState.swift
//  Cangjie
//
//  全局应用状态，使用 ObservableObject + @Published（iOS 16 兼容）。
//  通过 @EnvironmentObject 注入，管理当前小说 ID、导航路径、服务器连接状态、主题等。
//

import SwiftUI
import Combine

/// 服务器连接状态
enum ConnectionState: Equatable {
    /// 未连接
    case disconnected
    /// 正在连接
    case connecting
    /// 已连接
    case connected
    /// 连接失败
    case failed(message: String)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.connected, .connected):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// 侧边栏导航目标
enum SidebarDestination: String, CaseIterable, Hashable {
    case bookshelf = "书架"
    case workbench = "工作台"
    case autopilot = "自动驾驶"
    case bible = "设定集"
    case knowledgeGraph = "知识图谱"
    case cast = "人物关系"
    case locations = "地点"
    case monitor = "监控"
    case promptPlaza = "提示词广场"
    case governance = "叙事治理"
    case export = "导出"
    case snapshot = "快照"
    case trace = "AI Trace"
    case debug = "调试工具"
    case settings = "设置"

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .bookshelf:
            return "books.vertical.fill"
        case .workbench:
            return "book.fill"
        case .autopilot:
            return "car.fill"
        case .bible:
            return "person.text.rectangle.fill"
        case .knowledgeGraph:
            return "network"
        case .cast:
            return "person.2.fill"
        case .locations:
            return "map.fill"
        case .monitor:
            return "chart.line.uptrend.xyaxis"
        case .promptPlaza:
            return "text.bubble.fill"
        case .governance:
            return "shield.lefthalf.filled"
        case .export:
            return "square.and.arrow.up"
        case .snapshot:
            return "camera.fill"
        case .trace:
            return "waveform.path"
        case .debug:
            return "ladybug.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

/// 全局应用状态
///
/// 管理：
/// - 当前小说 ID
/// - 侧边栏导航选择
/// - 服务器连接状态
/// - 主题模式与字号
/// - 首次启动引导
final class AppState: ObservableObject {

    // MARK: - 小说状态

    /// 当前选中的小说 ID
    @Published var currentNovelId: String? {
        didSet {
            // 小说切换时取消旧小说的所有 SSE 连接
            if let oldId = oldValue, oldId != currentNovelId {
                SSEStreamRegistry.shared.cancelAll(novelId: oldId)
            }
        }
    }

    // MARK: - 导航状态

    /// 当前侧边栏选择
    @Published var sidebarSelection: SidebarDestination? = .bookshelf

    /// 导航路径（NavigationStack）
    @Published var navigationPath = NavigationPath()

    // MARK: - 服务器连接状态

    /// 服务器连接状态
    @Published var serverConnection: ConnectionState = .disconnected {
        didSet {
            Logger.network.info("服务器连接状态变更: \(String(describing: serverConnection))")
        }
    }

    /// 健康检查信息
    @Published var healthStatus: HealthStatus?

    /// 是否需要显示服务器配置引导
    @Published var needsServerConfig: Bool = false

    // MARK: - 主题

    /// 主题模式
    @Published var themeMode: ThemeMode = .system {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "cangjie.themeMode")
        }
    }

    /// 字号档位
    @Published var fontSizeScale: FontSizeScale = .medium {
        didSet {
            UserDefaults.standard.set(fontSizeScale.rawValue, forKey: "cangjie.fontSizeScale")
        }
    }

    // MARK: - 初始化

    init() {
        // 从 UserDefaults 加载主题偏好
        if let themeModeRaw = UserDefaults.standard.string(forKey: "cangjie.themeMode"),
           let savedThemeMode = ThemeMode(rawValue: themeModeRaw) {
            self.themeMode = savedThemeMode
        }

        if let fontSizeRaw = UserDefaults.standard.string(forKey: "cangjie.fontSizeScale"),
           let savedFontSize = FontSizeScale(rawValue: fontSizeRaw) {
            self.fontSizeScale = savedFontSize
        }

        // 检查是否需要服务器配置
        self.needsServerConfig = !APIConfig.shared.isConfigured
    }

    // MARK: - 服务器连接

    /// 执行健康检查，更新连接状态。
    ///
    /// 在 App 启动时和用户点击"测试连接"时调用。
    func checkServerConnection() async {
        guard APIConfig.shared.isConfigured else {
            await MainActor.run {
                self.needsServerConfig = true
                self.serverConnection = .disconnected
            }
            return
        }

        await MainActor.run {
            self.serverConnection = .connecting
        }

        do {
            let health = try await APIClient.shared.healthCheck()
            await MainActor.run {
                self.healthStatus = health
                if health.isHealthy {
                    self.serverConnection = .connected
                    self.needsServerConfig = false
                } else {
                    self.serverConnection = .failed(message: "后端状态异常：\(health.status)")
                }
            }
        } catch {
            await MainActor.run {
                self.healthStatus = nil
                self.serverConnection = .failed(message: error.localizedDescription)
            }
        }
    }

    /// 设置服务器地址并保存。
    ///
    /// - Parameter url: 服务器地址
    func setServerURL(_ url: String) {
        APIConfig.shared.baseURL = url
        self.needsServerConfig = false
    }

    // MARK: - 主题

    /// 获取字号缩放因子
    var currentFontSizeScale: CGFloat {
        return fontSizeScale.scaleFactor * Theme.ipadScale
    }

    /// 获取 ColorScheme
    var colorScheme: ColorScheme? {
        return themeMode.colorScheme
    }

    /// 是否为深色模式（themeStore.ts:24-27 isDark）
    /// light → false; dark → true; anchor → true; system → 跟随系统
    var isDark: Bool {
        if themeMode == .system {
            // system 模式跟随系统偏好
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        return themeMode.isDark
    }

    /// 是否为黑金模式（themeStore.ts:30 isAnchor）
    var isAnchor: Bool {
        return themeMode.isAnchor
    }

    // MARK: - 小说选择

    /// 选择小说
    /// - Parameter novelId: 小说 ID
    func selectNovel(_ novelId: String) {
        currentNovelId = novelId
    }

    /// 清除当前小说选择
    func clearNovelSelection() {
        if let novelId = currentNovelId {
            SSEStreamRegistry.shared.cancelAll(novelId: novelId)
        }
        currentNovelId = nil
    }
}
