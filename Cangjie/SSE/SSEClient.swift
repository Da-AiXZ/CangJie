//
//  SSEClient.swift
//  Cangjie
//
//  SSE 客户端核心，基于 URLSession async bytes 实现帧解析。
//  支持两种帧格式：data-only（autopilot 流）和 event+data（DAG 事件流）。
//  基于架构文档 6.4 节 SSE 帧解析规则。
//

import Foundation

/// SSE 客户端，负责建立 SSE 连接并解析事件帧。
///
/// 解析逻辑（基于 6.4 节）：
/// - 按 `\n\n` 分隔事件帧
/// - 每帧内按行解析：`data:` → 累积 data，`event:` → 记录事件名，`retry:` → 更新重连间隔
/// - 空行触发事件派发
/// - 注释行以 `:` 开头，忽略
final class SSEClient {

    /// URLSession 实例（SSE 专用配置）
    private let session: URLSession

    /// API 客户端（用于构建带认证的请求）
    private let apiClient: APIClient

    /// 初始化
    /// - Parameters:
    ///   - apiClient: API 客户端实例
    ///   - session: 自定义 URLSession（可选）
    init(apiClient: APIClient = .shared, session: URLSession? = nil) {
        self.apiClient = apiClient
        self.session = session ?? URLSession(
            configuration: APIConfig.makeSSEURLSessionConfiguration()
        )
    }

    /// 建立 SSE 连接并返回事件流。
    ///
    /// 使用 `URLSession.bytes(for:)` 异步读取字节流，
    /// 逐行解析 SSE 帧格式。
    ///
    /// - Parameter url: SSE 端点 URL
    /// - Returns: 异步事件流
    func connect(url: URL) -> AsyncThrowingStream<SSEEvent, Error> {
        let request = apiClient.makeSSERequest(url: url)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    Logger.sse.info("SSE 连接中: \(url.absoluteString)")

                    let (bytes, response) = try await self.session.bytes(for: request)

                    // 检查 HTTP 响应
                    if let httpResponse = response as? HTTPURLResponse {
                        guard (200...299).contains(httpResponse.statusCode) else {
                            let error = APIError.from(
                                statusCode: httpResponse.statusCode,
                                data: nil
                            )
                            Logger.sse.error("SSE 连接失败，状态码: \(httpResponse.statusCode)")
                            continuation.finish(throwing: error)
                            return
                        }
                    }

                    Logger.sse.info("SSE 连接成功")

                    // 帧解析状态
                    var dataLines: [String] = []
                    var eventName: String?
                    var eventId: String?
                    var retryInterval: Int?

                    // 逐行读取
                    for try await line in bytes.lines {
                        // 任务被取消
                        if Task.isCancelled {
                            Logger.sse.info("SSE 连接被取消")
                            continuation.finish(throwing: SSEError.cancelled)
                            return
                        }

                        // 空行 = 事件帧分隔符
                        if line.isEmpty {
                            // 如果有累积的 data 行，派发事件
                            if !dataLines.isEmpty {
                                let data = dataLines.joined(separator: "\n")
                                let event = SSEEvent(
                                    event: eventName,
                                    data: data,
                                    id: eventId,
                                    retry: retryInterval
                                )
                                continuation.yield(event)

                                // 重置帧状态
                                dataLines = []
                                eventName = nil
                                eventId = nil
                                retryInterval = nil
                            }
                            continue
                        }

                        // 注释行（以 : 开头），忽略
                        if line.hasPrefix(":") {
                            continue
                        }

                        // 解析字段
                        let (field, value) = Self.parseField(line)

                        switch field {
                        case "data":
                            dataLines.append(value)
                        case "event":
                            eventName = value
                        case "id":
                            eventId = value
                        case "retry":
                            if let retry = Int(value) {
                                retryInterval = retry
                            }
                        default:
                            // 未知字段，忽略
                            break
                        }
                    }

                    // 流正常结束
                    Logger.sse.info("SSE 流结束")
                    continuation.finish()

                } catch let error as URLError {
                    Logger.sse.error("SSE 网络错误: \(error.localizedDescription)")
                    if error.code == .cancelled {
                        continuation.finish(throwing: SSEError.cancelled)
                    } else {
                        continuation.finish(throwing: SSEError.connectionError(error))
                    }
                } catch {
                    Logger.sse.error("SSE 错误: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            // 当流被终止时取消任务
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 建立 SSE POST 连接并返回事件流。
    ///
    /// 用于 Bible 生成流等需要 POST 请求的 SSE 端点。
    ///
    /// - Parameters:
    ///   - url: SSE 端点 URL
    ///   - body: 请求体数据
    /// - Returns: 异步事件流
    func connectPOST(url: URL, body: Data? = nil) -> AsyncThrowingStream<SSEEvent, Error> {
        let request = apiClient.makeSSEPostRequest(url: url, body: body)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    Logger.sse.info("SSE POST 连接中: \(url.absoluteString)")

                    let (bytes, response) = try await self.session.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse {
                        guard (200...299).contains(httpResponse.statusCode) else {
                            let error = APIError.from(
                                statusCode: httpResponse.statusCode,
                                data: nil
                            )
                            Logger.sse.error("SSE POST 连接失败，状态码: \(httpResponse.statusCode)")
                            continuation.finish(throwing: error)
                            return
                        }
                    }

                    Logger.sse.info("SSE POST 连接成功")

                    var dataLines: [String] = []
                    var eventName: String?
                    var eventId: String?
                    var retryInterval: Int?

                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            Logger.sse.info("SSE POST 连接被取消")
                            continuation.finish(throwing: SSEError.cancelled)
                            return
                        }

                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let data = dataLines.joined(separator: "\n")
                                let event = SSEEvent(
                                    event: eventName,
                                    data: data,
                                    id: eventId,
                                    retry: retryInterval
                                )
                                continuation.yield(event)

                                dataLines = []
                                eventName = nil
                                eventId = nil
                                retryInterval = nil
                            }
                            continue
                        }

                        if line.hasPrefix(":") {
                            continue
                        }

                        let (field, value) = Self.parseField(line)

                        switch field {
                        case "data":
                            dataLines.append(value)
                        case "event":
                            eventName = value
                        case "id":
                            eventId = value
                        case "retry":
                            if let retry = Int(value) {
                                retryInterval = retry
                            }
                        default:
                            break
                        }
                    }

                    Logger.sse.info("SSE POST 流结束")
                    continuation.finish()

                } catch let error as URLError {
                    Logger.sse.error("SSE POST 网络错误: \(error.localizedDescription)")
                    if error.code == .cancelled {
                        continuation.finish(throwing: SSEError.cancelled)
                    } else {
                        continuation.finish(throwing: SSEError.connectionError(error))
                    }
                } catch {
                    Logger.sse.error("SSE POST 错误: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 解析 SSE 字段行。
    ///
    /// SSE 行格式：`field:value` 或 `field: value`（冒号后可选空格）
    ///
    /// - Parameter line: 原始行
    /// - Returns: (字段名, 值) 元组
    private static func parseField(_ line: String) -> (String, String) {
        // 查找冒号位置
        guard let colonIndex = line.firstIndex(of: ":") else {
            // 无冒号，整行为字段名，值为空
            return (line, "")
        }

        let field = String(line[line.startIndex..<colonIndex])
        var value = String(line[line.index(after: colonIndex)...])

        // 冒号后第一个空格是可选分隔符，需要去掉
        if value.hasPrefix(" ") {
            value = String(value.dropFirst())
        }

        return (field, value)
    }
}
