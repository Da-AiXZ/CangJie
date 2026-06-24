//
//  SSEConnection.swift
//  Cangjie
//
//  单条 SSE 连接封装，管理连接生命周期与指数退避重连。
//  状态机：connecting → connected → disconnected / reconnecting
//  基于架构文档 6.4 节重连策略：1s → 2s → 4s → 8s → 15s（上限）。
//

import Foundation

/// SSE 连接状态
enum SSEConnectionState: Equatable {

    /// 未连接
    case disconnected

    /// 正在连接
    case connecting

    /// 已连接
    case connected

    /// 正在重连
    case reconnecting(retryCount: Int)
}

/// 单条 SSE 连接管理器。
///
/// 功能：
/// - 建立与取消 SSE 连接
/// - 指数退避自动重连（1s → 2s → 4s → 8s → 15s）
/// - 连接状态机管理
/// - 支持 `after_seq` 断点续传
final class SSEConnection: ObservableObject {

    /// 指数退避重连延迟序列（秒），基于架构文档 6.4 节
    static let retryDelays: [TimeInterval] = [1, 2, 4, 8, 15]

    /// 最大重连次数（达到后停止重连）
    static let maxRetryCount: Int = 5

    // MARK: - 属性

    /// SSE 客户端
    private let client: SSEClient

    /// 连接 URL
    let url: URL

    /// 流类型
    let streamType: SSEStreamType

    /// 当前连接状态
    @Published private(set) var state: SSEConnectionState = .disconnected

    /// 当前重连次数
    @Published private(set) var retryCount: Int = 0

    /// 最后接收到的 seq（用于 after_seq 断点续传，仅 autopilot 流）
    private(set) var lastSeq: Int?

    /// 是否手动取消（手动取消后不再自动重连）
    private var isManuallyCancelled: Bool = false

    /// 当前连接任务
    private var connectionTask: Task<Void, Never>?

    /// 事件回调
    private var onEvent: ((SSEEvent) -> Void)?

    /// 状态变更回调
    private var onStateChange: ((SSEConnectionState) -> Void)?

    /// 错误回调
    private var onError: ((Error) -> Void)?

    /// HTTP 方法（POST 用于单章生成流，GET 用于其他流）
    private let httpMethod: String

    /// POST 请求体数据（仅 httpMethod == "POST" 时使用）
    private let postBody: Data?

    // MARK: - 初始化

    /// 初始化 SSE 连接。
    ///
    /// - Parameters:
    ///   - streamType: 流类型
    ///   - url: 连接 URL
    ///   - client: SSE 客户端实例
    ///   - method: HTTP 方法（"GET" 或 "POST"，默认 "GET"）
    ///   - body: POST 请求体数据（仅 method == "POST" 时使用，已编码为 JSON Data）
    init(streamType: SSEStreamType, url: URL, client: SSEClient = SSEClient(), method: String = "GET", body: Data? = nil) {
        self.streamType = streamType
        self.url = url
        self.client = client
        self.httpMethod = method
        self.postBody = body
    }

    // MARK: - 状态控制

    /// 启动 SSE 连接，返回事件流。
    ///
    /// - Parameters:
    ///   - onEvent: 事件回调
    ///   - onStateChange: 状态变更回调
    ///   - onError: 错误回调
    func start(
        onEvent: @escaping (SSEEvent) -> Void,
        onStateChange: @escaping (SSEConnectionState) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onEvent = onEvent
        self.onStateChange = onStateChange
        self.onError = onError
        self.isManuallyCancelled = false
        self.retryCount = 0

        startConnection()
    }

    /// 取消连接（手动取消，不触发自动重连）。
    func cancel() {
        Logger.sse.info("SSE 连接手动取消: \(streamType.displayName)")
        isManuallyCancelled = true
        connectionTask?.cancel()
        connectionTask = nil
        updateState(.disconnected)
    }

    /// 获取带 after_seq 参数的连接 URL。
    ///
    /// autopilot 日志流支持断点续传，重连时传入上次最后一条 seq。
    ///
    /// - Parameter baseUrl: 原始 URL
    /// - Returns: 带 after_seq 参数的 URL
    func urlWithAfterSeq() -> URL {
        guard let seq = lastSeq else {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        // 移除已有的 after_seq
        queryItems.removeAll { $0.name == "after_seq" }
        queryItems.append(URLQueryItem(name: "after_seq", value: String(seq)))
        components?.queryItems = queryItems
        return components?.url ?? url
    }

    // MARK: - 内部连接逻辑

    /// 启动连接
    private func startConnection() {
        connectionTask?.cancel()

        updateState(.connecting)

        connectionTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                // 根据流类型选择连接方式
                let stream: AsyncThrowingStream<SSEEvent, Error>

                if self.streamType == .bibleGenerateStream {
                    // Bible 生成流使用 POST（空 body）
                    stream = self.client.connectPOST(url: self.url)
                } else if self.httpMethod == "POST" {
                    // 单章生成流等需要 POST body 的流
                    stream = self.client.connectPOST(url: self.url, body: self.postBody)
                } else {
                    // 其他流使用 GET，带 after_seq 断点续传
                    let connectUrl = self.urlWithAfterSeq()
                    stream = self.client.connect(url: connectUrl)
                }

                self.updateState(.connected)
                // 【修复】连接成功后重置重连计数器，否则连续重连会累积导致后续重连提前耗尽次数
                self.resetRetryCount()
                Logger.sse.info("SSE 连接已建立: \(self.streamType.displayName)")

                for try await event in stream {
                    if Task.isCancelled || self.isManuallyCancelled {
                        break
                    }

                    // 更新 lastSeq（从事件数据中提取）
                    self.updateLastSeq(from: event)

                    // 调用事件回调
                    self.onEvent?(event)
                }

                // 流正常结束
                if !self.isManuallyCancelled {
                    self.updateState(.disconnected)
                    Logger.sse.info("SSE 流正常结束: \(self.streamType.displayName)")
                }

            } catch SSEError.cancelled {
                if !self.isManuallyCancelled {
                    self.updateState(.disconnected)
                }
            } catch {
                Logger.sse.error("SSE 连接错误: \(error.localizedDescription)")

                if !self.isManuallyCancelled {
                    // 触发自动重连
                    self.scheduleReconnect()
                } else {
                    self.updateState(.disconnected)
                }
            }
        }
    }

    /// 安排重连
    private func scheduleReconnect() {
        guard retryCount < Self.maxRetryCount else {
            Logger.sse.error("SSE 重连次数耗尽: \(self.streamType.displayName)")
            updateState(.disconnected)
            onError?(SSEError.maxRetriesExceeded)
            return
        }

        let delay = Self.retryDelays[min(retryCount, Self.retryDelays.count - 1)]
        retryCount += 1

        Logger.sse.info("SSE 准备重连（第 \(retryCount) 次，延迟 \(delay)s）: \(streamType.displayName)")
        updateState(.reconnecting(retryCount: retryCount))

        Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if Task.isCancelled || self.isManuallyCancelled {
                return
            }

            Logger.sse.info("SSE 开始重连: \(self.streamType.displayName)")
            self.startConnection()
        }
    }

    /// 更新连接状态
    private func updateState(_ newState: SSEConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
            self?.onStateChange?(newState)
        }
    }

    /// 从事件中更新 lastSeq
    private func updateLastSeq(from event: SSEEvent) {
        // 从 JSON 数据中提取 seq 字段
        if let dict = event.decodeAsDictionary() {
            if let seq = dict["seq"] as? Int {
                lastSeq = seq
            } else if let seq = dict["seq"] as? Double {
                lastSeq = Int(seq)
            }
        }
    }
}

// MARK: - 便捷方法

extension SSEConnection {

    /// 是否已连接
    var isConnected: Bool {
        if case .connected = state {
            return true
        }
        return false
    }

    /// 是否正在重连
    var isReconnecting: Bool {
        if case .reconnecting = state {
            return true
        }
        return false
    }

    /// 重置重连计数（连接成功后调用）
    func resetRetryCount() {
        retryCount = 0
    }
}
