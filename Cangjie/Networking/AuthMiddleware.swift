//
//  AuthMiddleware.swift
//  Cangjie
//
//  Bearer Token / Basic Auth 注入中间件。
//  处理请求头注入与 401 重定向到配置页。
//  基于架构文档 6.1 / 6.3 节。
//

import Foundation

/// 认证中间件，负责在 URLRequest 中注入认证头。
///
/// 支持两种认证方式（可同时使用）：
/// 1. **Bearer Token**：注入 `Authorization: Bearer <token>` 头
/// 2. **Basic Auth**：注入 `Authorization: Basic <base64(user:pass)>` 头
///
/// 优先级：Bearer Token > Basic Auth（两者同时配置时仅使用 Bearer Token）
final class AuthMiddleware {

    /// 关联的 APIConfig 实例
    private let config: APIConfig

    /// 认证失败回调（用于触发重定向到服务器配置页）
    var onAuthenticationFailed: (() -> Void)?

    /// 初始化
    /// - Parameter config: APIConfig 实例
    init(config: APIConfig = .shared) {
        self.config = config
    }

    /// 对 URLRequest 注入认证头。
    ///
    /// - Parameter request: 原始 URLRequest
    /// - Returns: 注入认证头后的 URLRequest
    func apply(to request: URLRequest) -> URLRequest {
        var modified = request

        // 优先使用 Bearer Token
        if !config.bearerToken.isEmpty {
            modified.setValue(
                "Bearer \(config.bearerToken)",
                forHTTPHeaderField: "Authorization"
            )
        }
        // 其次使用 Basic Auth
        else if !config.basicAuthUser.isEmpty {
            let credentials = "\(config.basicAuthUser):\(config.basicAuthPassword)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                modified.setValue(
                    "Basic \(base64)",
                    forHTTPHeaderField: "Authorization"
                )
            }
        }

        return modified
    }

    /// 检查 HTTP 响应是否为认证失败（401/403）。
    ///
    /// - Parameter statusCode: HTTP 状态码
    /// - Returns: 是否为认证失败
    func isAuthenticationFailed(statusCode: Int) -> Bool {
        let failed = statusCode == 401 || statusCode == 403
        if failed {
            // 触发认证失败回调
            DispatchQueue.main.async { [weak self] in
                self?.onAuthenticationFailed?()
            }
        }
        return failed
    }

    /// 构建带有认证头的 URLRequest。
    ///
    /// 便捷方法，等价于先创建 URLRequest 再调用 apply(to:)。
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - body: 请求体数据
    ///   - additionalHeaders: 额外请求头
    /// - Returns: 带认证头的 URLRequest
    func makeAuthenticatedRequest(
        url: URL,
        method: HTTPMethod = .get,
        body: Data? = nil,
        additionalHeaders: [String: String] = [:]
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = method.rawValue
        request.timeoutInterval = config.timeoutInterval

        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // 注入额外请求头
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 注入认证头
        request = apply(to: request)

        return request
    }
}
