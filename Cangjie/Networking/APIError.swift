//
//  APIError.swift
//  Cangjie
//
//  API 错误类型枚举，基于架构文档 6.3 节错误处理方案。
//  后端无统一 {code, data, message} 封装，错误时返回 {"detail": "..."} + HTTP 状态码。
//

import Foundation

/// API 请求错误类型
enum APIError: Error, LocalizedError, Equatable {

    /// 网络传输错误（URLSession 层面，如超时、DNS 解析失败、连接拒绝）
    case networkError(Error)

    /// 服务器错误（HTTP 非 2xx），包含状态码和从 detail 字段提取的消息
    case serverError(statusCode: Int, message: String)

    /// JSON 解码错误
    case decodingError(Error)

    /// 认证失败（HTTP 401/403）
    case authenticationFailed

    /// 资源不存在（HTTP 404）
    case notFound

    /// 服务不可用（HTTP 503，数据库繁忙等）
    case serviceUnavailable

    /// 无效的 URL
    case invalidURL

    /// 请求超时
    case timeout

    /// 未知错误
    case unknown(String)

    // MARK: - Equatable

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationFailed, .authenticationFailed):
            return true
        case (.notFound, .notFound):
            return true
        case (.serviceUnavailable, .serviceUnavailable):
            return true
        case (.invalidURL, .invalidURL):
            return true
        case (.timeout, .timeout):
            return true
        case let (.serverError(lc, lm), .serverError(rc, rm)):
            return lc == rc && lm == rm
        case let (.unknown(l), .unknown(r)):
            return l == r
        case (.networkError, .networkError):
            // 网络错误底层 Error 不可比较，仅比较类型
            return true
        case (.decodingError, .decodingError):
            return true
        default:
            return false
        }
    }

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "服务器错误（\(statusCode)）：\(message)"
        case .decodingError(let error):
            return "数据解析失败：\(error.localizedDescription)"
        case .authenticationFailed:
            return "认证失败，请检查 Token 配置"
        case .notFound:
            return "请求的资源不存在"
        case .serviceUnavailable:
            return "服务不可用，请稍后重试"
        case .invalidURL:
            return "无效的服务器地址"
        case .timeout:
            return "请求超时，请检查网络连接"
        case .unknown(let message):
            return message
        }
    }

    // MARK: - 工厂方法

    /// 根据 HTTP 状态码和响应体创建对应的 APIError
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 状态码
    ///   - data: 响应体数据
    /// - Returns: 对应的 APIError
    static func from(statusCode: Int, data: Data?) -> APIError {
        // 尝试从响应体解析 detail 字段
        var detailMessage = "未知服务器错误"

        if let data = data {
            let decoder = JSONDecoder()
            if let backendError = try? decoder.decode(BackendErrorResponse.self, from: data) {
                detailMessage = backendError.detail
            } else if let jsonObject = try? JSONSerialization.jsonObject(with: data),
                      let dict = jsonObject as? [String: Any],
                      let detail = dict["detail"] as? String {
                detailMessage = detail
            } else if let plainText = String(data: data, encoding: .utf8), !plainText.isEmpty {
                detailMessage = plainText
            }
        }

        switch statusCode {
        case 401, 403:
            return .authenticationFailed
        case 404:
            return .notFound
        case 503:
            return .serviceUnavailable
        default:
            return .serverError(statusCode: statusCode, message: detailMessage)
        }
    }

    /// 是否为认证类错误
    var isAuthenticationError: Bool {
        if case .authenticationFailed = self {
            return true
        }
        return false
    }

    /// 是否为可重试的错误
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .serviceUnavailable:
            return true
        case .serverError(let statusCode, _):
            // 5xx 错误可重试，4xx 不可重试
            return statusCode >= 500
        default:
            return false
        }
    }
}
