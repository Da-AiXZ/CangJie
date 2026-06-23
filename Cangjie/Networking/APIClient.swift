//
//  APIClient.swift
//  Cangjie
//
//  URLSession 泛型封装，提供 async/await 风格的 REST API 客户端。
//  统一错误处理、JSON 编解码（微秒日期格式）、Bearer Token / Basic Auth 注入。
//  基于架构文档 3.2 节 API Client 设计。
//

import Foundation

/// API 客户端协议，定义 REST 操作接口。
protocol APIClientProtocol {

    /// 发送请求并解码响应
    func request<T: Decodable>(_ endpoint: APIEndpoint.EndpointInfo) async throws -> T

    /// 发送带请求体的请求并解码响应
    func request<T: Decodable, B: Encodable>(
        _ endpoint: APIEndpoint.EndpointInfo,
        body: B
    ) async throws -> T

    /// 发送请求（不期望响应体）
    func send(_ endpoint: APIEndpoint.EndpointInfo) async throws

    /// 发送带请求体的请求（不期望响应体）
    func send<B: Encodable>(
        _ endpoint: APIEndpoint.EndpointInfo,
        body: B
    ) async throws

    /// 下载原始数据
    func download(_ endpoint: APIEndpoint.EndpointInfo) async throws -> Data
}

/// 基于 URLSession 的 REST API 客户端实现。
///
/// 功能：
/// - 泛型请求/响应编解码
/// - 微秒日期格式支持（后端 Python datetime.isoformat()）
/// - Bearer Token / Basic Auth 自动注入
/// - 统一错误处理（APIError）
/// - 可配置超时
final class APIClient: APIClientProtocol, ObservableObject {

    /// 共享单例
    static let shared = APIClient()

    /// URLSession 实例
    private let session: URLSession

    /// API 配置
    let config: APIConfig

    /// 认证中间件
    let authMiddleware: AuthMiddleware

    /// JSON 解码器（配置微秒日期格式）
    private let jsonDecoder: JSONDecoder

    /// JSON 编码器
    private let jsonEncoder: JSONEncoder

    // MARK: - 初始化

    init(
        config: APIConfig = .shared,
        authMiddleware: AuthMiddleware? = nil,
        session: URLSession? = nil
    ) {
        self.config = config
        self.authMiddleware = authMiddleware ?? AuthMiddleware(config: config)

        let configuration = session?.configuration ?? APIConfig.makeURLSessionConfiguration()
        self.session = session ?? URLSession(configuration: configuration)

        // 配置 JSON 解码器
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom(DateDecodingStrategyHelper.decode)

        // 配置 JSON 编码器
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .custom(DateEncodingStrategyHelper.encode)
        // 使用 snake_case 编码（与后端一致）
        // 注意：Swift 默认使用 camelCase，需通过 CodingKeys 映射
    }

    // MARK: - 泛型请求

    /// 发送请求并解码响应。
    ///
    /// - Parameter endpoint: 端点信息
    /// - Returns: 解码后的响应对象
    func request<T: Decodable>(_ endpoint: APIEndpoint.EndpointInfo) async throws -> T {
        let data = try await performRequest(endpoint, body: nil)
        // 空响应处理
        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            Logger.network.error("JSON 解码失败: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    /// 发送带请求体的请求并解码响应。
    ///
    /// - Parameters:
    ///   - endpoint: 端点信息
    ///   - body: 请求体（Encodable）
    /// - Returns: 解码后的响应对象
    func request<T: Decodable, B: Encodable>(
        _ endpoint: APIEndpoint.EndpointInfo,
        body: B
    ) async throws -> T {
        let bodyData = try encodeBody(body)
        let data = try await performRequest(endpoint, body: bodyData)
        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
        }
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            Logger.network.error("JSON 解码失败: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    /// 发送请求（不期望响应体）。
    ///
    /// - Parameter endpoint: 端点信息
    func send(_ endpoint: APIEndpoint.EndpointInfo) async throws {
        let data = try await performRequest(endpoint, body: nil)
        _ = data
    }

    /// 发送带请求体的请求（不期望响应体）。
    ///
    /// - Parameters:
    ///   - endpoint: 端点信息
    ///   - body: 请求体
    func send<B: Encodable>(
        _ endpoint: APIEndpoint.EndpointInfo,
        body: B
    ) async throws {
        let bodyData = try encodeBody(body)
        let data = try await performRequest(endpoint, body: bodyData)
        _ = data
    }

    /// 下载原始数据。
    ///
    /// - Parameter endpoint: 端点信息
    /// - Returns: 原始响应数据
    func download(_ endpoint: APIEndpoint.EndpointInfo) async throws -> Data {
        return try await performRequest(endpoint, body: nil)
    }

    // MARK: - 核心请求逻辑

    /// 执行 HTTP 请求，返回原始响应数据。
    ///
    /// - Parameters:
    ///   - endpoint: 端点信息
    ///   - body: 请求体数据（可选）
    /// - Returns: 响应数据
    private func performRequest(
        _ endpoint: APIEndpoint.EndpointInfo,
        body: Data?
    ) async throws -> Data {
        // 构建 URL
        guard let url = endpoint.url(config: config) else {
            Logger.network.error("无效的 URL: \(endpoint.path)")
            throw APIError.invalidURL
        }

        // 构建请求
        let request = authMiddleware.makeAuthenticatedRequest(
            url: url,
            method: endpoint.method,
            body: body
        )

        Logger.network.debug("\(endpoint.method.rawValue) \(url.absoluteString)")

        // 发送请求
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            Logger.network.error("网络请求失败: \(error.localizedDescription)")

            switch error.code {
            case .timedOut:
                throw APIError.timeout
            default:
                throw APIError.networkError(error)
            }
        } catch {
            Logger.network.error("网络请求失败: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        // 检查 HTTP 响应
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("非 HTTP 响应")
            throw APIError.unknown("非 HTTP 响应")
        }

        Logger.network.debug("响应状态码: \(httpResponse.statusCode)")

        // 处理错误状态码
        if !(200...299).contains(httpResponse.statusCode) {
            // 检查认证失败
            if authMiddleware.isAuthenticationFailed(statusCode: httpResponse.statusCode) {
                throw APIError.authenticationFailed
            }

            throw APIError.from(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }

    // MARK: - 辅助方法

    /// 编码请求体
    private func encodeBody<B: Encodable>(_ body: B) throws -> Data {
        do {
            return try jsonEncoder.encode(body)
        } catch {
            Logger.network.error("请求体编码失败: \(error.localizedDescription)")
            throw APIError.unknown("请求体编码失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 健康检查

    /// 执行健康检查。
    ///
    /// - Returns: 健康状态
    func healthCheck() async throws -> HealthStatus {
        let healthEndpoint = APIEndpoint.health
        return try await request(healthEndpoint)
    }

    // MARK: - SSE 请求构建

    /// 构建 SSE 请求 URLRequest。
    ///
    /// 用于 SSEClient/SSEConnection，注入认证头并设置 SSE 特定请求头。
    ///
    /// - Parameter url: SSE 端点 URL
    /// - Returns: 带认证和 SSE 头的 URLRequest
    func makeSSERequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.sseTimeoutInterval

        // SSE 特定请求头
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        // 注入认证头
        request = authMiddleware.apply(to: request)

        return request
    }

    /// 构建 SSE POST 请求 URLRequest（用于 Bible 生成流等 POST SSE）。
    ///
    /// - Parameters:
    ///   - url: SSE 端点 URL
    ///   - body: 请求体
    /// - Returns: 带认证和 SSE 头的 URLRequest
    func makeSSEPostRequest(url: URL, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.sseTimeoutInterval

        // SSE 特定请求头
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body
        }

        // 注入认证头
        request = authMiddleware.apply(to: request)

        return request
    }
}

// MARK: - 空响应

/// 表示空响应体（用于 204 No Content 等无响应体的接口）
struct EmptyResponse: Codable, Equatable {
    init() {}
}
