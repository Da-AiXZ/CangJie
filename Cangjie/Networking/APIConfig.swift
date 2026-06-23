//
//  APIConfig.swift
//  Cangjie
//
//  服务器地址与凭证的 Keychain 管理单例。
//  基于 APIConfig 单例管理 baseURL、Bearer Token、Basic Auth 凭证。
//  所有配置持久化到 Keychain（非 UserDefaults），因为可能含 Token。
//  基于架构文档 6.1 节。
//

import Foundation
import KeychainAccess

/// 服务器配置管理单例，负责 Base URL、Bearer Token、Basic Auth 凭证的存取。
///
/// - 服务器地址格式：`https://host:port`（不带尾斜杠）
/// - 所有 API 路径以 `/api/v1` 为前缀
/// - 统计 API 前缀为 `/api/stats`
/// - 健康检查端点：`GET /health`（无前缀，根路径）
/// - 首次启动若无配置，强制显示服务器配置引导页
///
/// 存储策略：优先使用 UserDefaults（TrollStore 环境下可靠），
/// Keychain 作为 fallback（老版本数据迁移）。
final class APIConfig: ObservableObject {

    // MARK: - 单例

    /// 全局共享实例
    static let shared = APIConfig()

    // MARK: - Keychain（fallback）

    /// Keychain 实例，用于读取旧版数据
    private let keychain: Keychain

    // MARK: - UserDefaults 键

    /// UserDefaults 存储键（TrollStore 环境下比 Keychain 更可靠）
    private enum UserDefaultsKey {
        static let baseURL = "cangjie.server.baseURL"
        static let bearerToken = "cangjie.server.bearerToken"
        static let basicAuthUser = "cangjie.server.basicAuthUser"
        static let basicAuthPassword = "cangjie.server.basicAuthPassword"
    }

    // MARK: - Keychain 键（仅用于 fallback 读取）

    private enum KeychainKey {
        static let baseURL = "cangjie.server.baseURL"
        static let bearerToken = "cangjie.server.bearerToken"
        static let basicAuthUser = "cangjie.server.basicAuthUser"
        static let basicAuthPassword = "cangjie.server.basicAuthPassword"
    }

    // MARK: - 常量

    /// API v1 前缀
    static let apiV1Prefix = "/api/v1"

    /// 统计 API 前缀
    static let statsPrefix = "/api/stats"

    /// 健康检查端点
    static let healthEndpoint = "/health"

    /// 默认请求超时时间（秒）
    static let defaultTimeoutInterval: TimeInterval = 30.0

    /// SSE 请求超时时间（秒），SSE 长连接需要较长超时
    static let sseTimeoutInterval: TimeInterval = 3600.0

    // MARK: - 可观察属性

    /// 服务器 Base URL（如 `https://plotpilot.example.com`）
    @Published var baseURL: String {
        didSet {
            // 优先写入 UserDefaults（TrollStore 环境下杀后台不丢失）
            UserDefaults.standard.set(baseURL, forKey: UserDefaultsKey.baseURL)
        }
    }

    /// Bearer Token（用于 Nginx Bearer Auth 中间件，可选）
    @Published var bearerToken: String {
        didSet {
            UserDefaults.standard.set(bearerToken, forKey: UserDefaultsKey.bearerToken)
        }
    }

    /// Basic Auth 用户名（用于 Nginx Basic Auth，可选）
    @Published var basicAuthUser: String {
        didSet {
            UserDefaults.standard.set(basicAuthUser, forKey: UserDefaultsKey.basicAuthUser)
        }
    }

    /// Basic Auth 密码（用于 Nginx Basic Auth，可选）
    @Published var basicAuthPassword: String {
        didSet {
            UserDefaults.standard.set(basicAuthPassword, forKey: UserDefaultsKey.basicAuthPassword)
        }
    }

    /// 请求超时时间
    var timeoutInterval: TimeInterval = APIConfig.defaultTimeoutInterval

    // MARK: - 初始化

    private init() {
        self.keychain = Keychain(service: "com.cangjie.ios")

        // 优先从 UserDefaults 加载配置（TrollStore 环境下杀后台不丢失）
        // 如果 UserDefaults 没有，尝试从 Keychain 读取（老版本数据迁移）
        if let savedBaseURL = UserDefaults.standard.string(forKey: UserDefaultsKey.baseURL) {
            self.baseURL = savedBaseURL
        } else {
            self.baseURL = (try? keychain.get(KeychainKey.baseURL)) ?? ""
            // 迁移：如果 Keychain 有值，同步到 UserDefaults
            if !self.baseURL.isEmpty {
                UserDefaults.standard.set(self.baseURL, forKey: UserDefaultsKey.baseURL)
            }
        }

        if let savedBearerToken = UserDefaults.standard.string(forKey: UserDefaultsKey.bearerToken) {
            self.bearerToken = savedBearerToken
        } else {
            self.bearerToken = (try? keychain.get(KeychainKey.bearerToken)) ?? ""
            if !self.bearerToken.isEmpty {
                UserDefaults.standard.set(self.bearerToken, forKey: UserDefaultsKey.bearerToken)
            }
        }

        if let savedBasicAuthUser = UserDefaults.standard.string(forKey: UserDefaultsKey.basicAuthUser) {
            self.basicAuthUser = savedBasicAuthUser
        } else {
            self.basicAuthUser = (try? keychain.get(KeychainKey.basicAuthUser)) ?? ""
            if !self.basicAuthUser.isEmpty {
                UserDefaults.standard.set(self.basicAuthUser, forKey: UserDefaultsKey.basicAuthUser)
            }
        }

        if let savedBasicAuthPassword = UserDefaults.standard.string(forKey: UserDefaultsKey.basicAuthPassword) {
            self.basicAuthPassword = savedBasicAuthPassword
        } else {
            self.basicAuthPassword = (try? keychain.get(KeychainKey.basicAuthPassword)) ?? ""
            if !self.basicAuthPassword.isEmpty {
                UserDefaults.standard.set(self.basicAuthPassword, forKey: UserDefaultsKey.basicAuthPassword)
            }
        }
    }

    // MARK: - 配置管理

    /// 是否已配置服务器地址
    var isConfigured: Bool {
        let url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !url.isEmpty
    }

    /// 是否配置了认证信息
    var hasAuth: Bool {
        return !bearerToken.isEmpty || !basicAuthUser.isEmpty
    }

    /// 获取标准化的 Base URL（去除尾斜杠）
    var normalizedBaseURL: String {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        return url
    }

    /// 构建完整 API v1 URL。
    ///
    /// - Parameter path: API 路径（如 `/novels/`、`/autopilot/{id}/start`）
    /// - Returns: 完整 URL，如 `https://host/api/v1/novels/`
    func apiV1URL(path: String) -> URL? {
        let base = normalizedBaseURL
        guard !base.isEmpty else { return nil }

        // 确保路径以 / 开头
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let urlString = "\(base)\(APIConfig.apiV1Prefix)\(normalizedPath)"
        return URL(string: urlString)
    }

    /// 构建统计 API URL。
    ///
    /// - Parameter path: 统计 API 路径
    /// - Returns: 完整 URL，如 `https://host/api/stats/...`
    func statsURL(path: String) -> URL? {
        let base = normalizedBaseURL
        guard !base.isEmpty else { return nil }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let urlString = "\(base)\(APIConfig.statsPrefix)\(normalizedPath)"
        return URL(string: urlString)
    }

    /// 构建根路径 URL（用于健康检查等无前缀端点）。
    ///
    /// - Parameter path: 根路径（如 `/health`）
    /// - Returns: 完整 URL，如 `https://host/health`
    func rootURL(path: String) -> URL? {
        let base = normalizedBaseURL
        guard !base.isEmpty else { return nil }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let urlString = "\(base)\(normalizedPath)"
        return URL(string: urlString)
    }

    /// 构建完整 URL（自定义前缀）。
    ///
    /// - Parameters:
    ///   - path: 路径
    ///   - prefix: 前缀（如 `/api/v1`、`/api/stats`、空字符串）
    /// - Returns: 完整 URL
    func fullURL(path: String, prefix: String = APIConfig.apiV1Prefix) -> URL? {
        let base = normalizedBaseURL
        guard !base.isEmpty else { return nil }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let normalizedPrefix = prefix.isEmpty ? "" : (prefix.hasPrefix("/") ? prefix : "/\(prefix)")
        let urlString = "\(base)\(normalizedPrefix)\(normalizedPath)"
        return URL(string: urlString)
    }

    // MARK: - 批量保存

    /// 批量保存服务器配置。
    ///
    /// - Parameters:
    ///   - baseURL: 服务器地址
    ///   - bearerToken: Bearer Token
    ///   - basicAuthUser: Basic Auth 用户名
    ///   - basicAuthPassword: Basic Auth 密码
    func saveConfiguration(
        baseURL: String,
        bearerToken: String = "",
        basicAuthUser: String = "",
        basicAuthPassword: String = ""
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bearerToken = bearerToken
        self.basicAuthUser = basicAuthUser
        self.basicAuthPassword = basicAuthPassword
    }

    /// 清除所有配置（用于退出登录/重置）。
    func clearConfiguration() {
        self.baseURL = ""
        self.bearerToken = ""
        self.basicAuthUser = ""
        self.basicAuthPassword = ""
        // 清除 UserDefaults
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.baseURL)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.bearerToken)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.basicAuthUser)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.basicAuthPassword)
        // 同时清除 Keychain（清理旧数据）
        try? keychain.remove(KeychainKey.baseURL)
        try? keychain.remove(KeychainKey.bearerToken)
        try? keychain.remove(KeychainKey.basicAuthUser)
        try? keychain.remove(KeychainKey.basicAuthPassword)
    }

    // MARK: - URLSession 配置

    /// 创建标准 URLSession 配置
    static func makeURLSessionConfiguration(timeout: TimeInterval = defaultTimeoutInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Charset": "utf-8",
        ]
        return config
    }

    /// 创建 SSE 专用 URLSession 配置（长超时）
    static func makeSSEURLSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = sseTimeoutInterval
        config.timeoutIntervalForResource = sseTimeoutInterval
        config.waitsForConnectivity = true
        // SSE 不使用缓存
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // 允许蜂窝网络
        config.allowsCellularAccess = true
        return config
    }
}
