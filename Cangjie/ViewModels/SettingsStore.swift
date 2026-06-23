//
//  SettingsStore.swift
//  Cangjie
//
//  应用设置（主题/字号/写作偏好/全托管，本地 @AppStorage）+ 服务器连接（调 /health）。
//

import SwiftUI
import Foundation

/// 设置 Store
@MainActor
final class SettingsStore: ObservableObject {

    // MARK: - 本地设置（@AppStorage）

    /// 主题模式
    @AppStorage("cangjie.themeMode") var themeMode: String = ThemeMode.system.rawValue

    /// 字号档位
    @AppStorage("cangjie.fontSizeScale") var fontSizeScale: String = FontSizeScale.medium.rawValue

    /// 写作偏好：内联散文聚合
    @AppStorage("cangjie.writing.inlineProseAggregation") var inlineProseAggregation: Bool = true

    /// 写作偏好：阶段显示模式
    @AppStorage("cangjie.writing.phaseDisplayMode") var phaseDisplayMode: String = "detailed"

    /// 全托管：指挥器收敛阈值
    @AppStorage("cangjie.autopilot.convergeThreshold") var convergeThreshold: Double = 0.85

    /// 全托管：指挥器着陆阈值
    @AppStorage("cangjie.autopilot.landThreshold") var landThreshold: Double = 0.75

    // MARK: - 服务器连接状态

    /// 健康检查信息
    @Published var healthStatus: HealthStatus?

    /// 连接状态
    @Published var connectionState: ConnectionState = .disconnected

    // MARK: - 依赖

    private let apiClient: APIClient
    private let apiConfig: APIConfig

    init(apiClient: APIClient = .shared, apiConfig: APIConfig = .shared) {
        self.apiClient = apiClient
        self.apiConfig = apiConfig
    }

    // MARK: - 主题

    /// 获取主题枚举
    var themeModeEnum: ThemeMode {
        return ThemeMode(rawValue: themeMode) ?? .system
    }

    /// 设置主题
    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode.rawValue
    }

    /// 获取 ColorScheme
    var colorScheme: ColorScheme? {
        return themeModeEnum.colorScheme
    }

    // MARK: - 字号

    /// 获取字号枚举
    var fontSizeScaleEnum: FontSizeScale {
        return FontSizeScale(rawValue: fontSizeScale) ?? .medium
    }

    /// 设置字号
    func setFontSizeScale(_ scale: FontSizeScale) {
        fontSizeScale = scale.rawValue
    }

    /// 获取缩放因子
    var scaleFactor: CGFloat {
        return fontSizeScaleEnum.scaleFactor * Theme.ipadScale
    }

    // MARK: - 服务器连接

    /// 测试服务器连接
    /// - Returns: 健康状态
    @discardableResult
    func testConnection() async -> Bool {
        connectionState = .connecting

        do {
            let health = try await apiClient.healthCheck()
            healthStatus = health
            if health.isHealthy {
                connectionState = .connected
                return true
            } else {
                connectionState = .failed(message: "后端状态异常: \(health.status)")
                return false
            }
        } catch {
            healthStatus = nil
            connectionState = .failed(message: error.localizedDescription)
            return false
        }
    }

    /// 检查服务器配置
    var isServerConfigured: Bool {
        return apiConfig.isConfigured
    }

    /// 保存服务器配置
    /// - Parameters:
    ///   - baseURL: 服务器地址
    ///   - bearerToken: Bearer Token
    ///   - basicAuthUser: Basic Auth 用户名
    ///   - basicAuthPassword: Basic Auth 密码
    func saveServerConfig(
        baseURL: String,
        bearerToken: String = "",
        basicAuthUser: String = "",
        basicAuthPassword: String = ""
    ) {
        apiConfig.saveConfiguration(
            baseURL: baseURL,
            bearerToken: bearerToken,
            basicAuthUser: basicAuthUser,
            basicAuthPassword: basicAuthPassword
        )
    }

    /// 清除服务器配置
    func clearServerConfig() {
        apiConfig.clearConfiguration()
        healthStatus = nil
        connectionState = .disconnected
    }

    // MARK: - 写作偏好

    /// 获取写作偏好字典（用于 PUT /novels/{id} 的 generation_prefs）
    func writingPrefsDict() -> [String: AnyCodable] {
        return [
            "inline_prose_aggregation_enabled": AnyCodable(inlineProseAggregation),
            "phase_display_mode": AnyCodable(phaseDisplayMode),
            "conductor_converge_threshold": AnyCodable(convergeThreshold),
            "conductor_land_threshold": AnyCodable(landThreshold),
        ]
    }
}
