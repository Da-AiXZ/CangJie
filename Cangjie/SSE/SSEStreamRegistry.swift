//
//  SSEStreamRegistry.swift
//  Cangjie
//
//  SSE 流注册中心，统一管理 7 条 SSE 流的生命周期。
//  基于 APIConfig 构建 SSE URL，支持 App 进入后台挂起/回前台重连。
//  基于架构文档 6.5 节 7 条 SSE 流完整清单。
//

import Foundation
import SwiftUI

/// SSE 流注册中心，管理所有 SSE 连接的中央注册表。
///
/// 职责：
/// - 按 (streamType, novelId) 管理多条并发 SSE 连接
/// - 提供 startStream / cancelStream / cancelAll 接口
/// - 监听 App 生命周期，进入后台挂起、回到前台自动重连
/// - 统一事件分发
final class SSEStreamRegistry: ObservableObject {

    /// 共享单例
    static let shared = SSEStreamRegistry()

    /// SSE 客户端
    private let client: SSEClient

    /// API 配置
    private let config: APIConfig

    /// 连接注册表：key = "streamType:novelId"
    private var connections: [String: SSEConnection] = [:]

    /// 事件回调注册表：key = "streamType:novelId"
    private var eventHandlers: [String: (SSEEvent) -> Void] = [:]

    /// 状态回调注册表
    private var stateHandlers: [String: (SSEConnectionState) -> Void] = [:]

    /// 错误回调注册表
    private var errorHandlers: [String: (Error) -> Void] = [:]

    /// 活跃的 novelId 集合（用于回前台重连）
    private var activeNovelIds: Set<String> = []

    /// 活跃的流类型集合（按 novelId 分组）
    private var activeStreams: [String: Set<SSEStreamType>] = [:]

    /// 序列化队列访问锁
    private let lock = NSLock()

    // MARK: - 初始化

    init(
        config: APIConfig = .shared,
        client: SSEClient? = nil
    ) {
        self.config = config
        self.client = client ?? SSEClient(apiClient: APIClient.shared)

        // 监听 App 生命周期通知
        setupLifecycleObservers()
    }

    // MARK: - 流管理

    /// 启动指定类型的 SSE 流。
    ///
    /// 如果该流已存在且连接中，先取消旧连接再创建新连接。
    ///
    /// - Parameters:
    ///   - streamType: 流类型
    ///   - novelId: 小说 ID
    ///   - onEvent: 事件回调
    ///   - onStateChange: 状态变更回调（可选）
    ///   - onError: 错误回调（可选）
    /// - Returns: 是否成功启动（URL 构建失败返回 false）
    @discardableResult
    func startStream(
        type streamType: SSEStreamType,
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onStateChange: ((SSEConnectionState) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        let key = registryKey(streamType: streamType, novelId: novelId)

        Logger.sse.info("启动 SSE 流: \(streamType.displayName) [novel: \(novelId)]")

        // 构建 SSE URL
        guard let url = sseURL(for: streamType, novelId: novelId) else {
            Logger.sse.error("SSE URL 构建失败: \(streamType.displayName)")
            onError?(APIError.invalidURL)
            return false
        }

        lock.lock()

        // 取消旧连接
        if let oldConnection = connections[key] {
            oldConnection.cancel()
            connections.removeValue(forKey: key)
        }

        // 创建新连接
        let connection = SSEConnection(streamType: streamType, url: url, client: client)
        connections[key] = connection
        eventHandlers[key] = onEvent
        stateHandlers[key] = onStateChange
        errorHandlers[key] = onError

        // 记录活跃流
        activeNovelIds.insert(novelId)
        if activeStreams[novelId] == nil {
            activeStreams[novelId] = []
        }
        activeStreams[novelId]?.insert(streamType)

        lock.unlock()

        // 启动连接
        connection.start(
            onEvent: { [weak self] event in
                self?.handleEvent(event, key: key)
            },
            onStateChange: { [weak self] state in
                self?.handleStateChange(state, key: key)
            },
            onError: { [weak self] error in
                self?.handleError(error, key: key)
            }
        )

        return true
    }

    /// 取消指定类型的 SSE 流。
    ///
    /// - Parameters:
    ///   - streamType: 流类型
    ///   - novelId: 小说 ID
    func cancelStream(type streamType: SSEStreamType, novelId: String) {
        let key = registryKey(streamType: streamType, novelId: novelId)

        Logger.sse.info("取消 SSE 流: \(streamType.displayName) [novel: \(novelId)]")

        lock.lock()
        connections[key]?.cancel()
        connections.removeValue(forKey: key)
        eventHandlers.removeValue(forKey: key)
        stateHandlers.removeValue(forKey: key)
        errorHandlers.removeValue(forKey: key)
        activeStreams[novelId]?.remove(streamType)
        lock.unlock()
    }

    /// 取消指定小说的所有 SSE 流。
    ///
    /// - Parameter novelId: 小说 ID
    func cancelAll(novelId: String) {
        Logger.sse.info("取消小说所有 SSE 流: \(novelId)")

        lock.lock()
        let keysToCancel = connections.keys.filter { $0.contains(":\(novelId)") }
        for key in keysToCancel {
            connections[key]?.cancel()
            connections.removeValue(forKey: key)
            eventHandlers.removeValue(forKey: key)
            stateHandlers.removeValue(forKey: key)
            errorHandlers.removeValue(forKey: key)
        }
        activeStreams.removeValue(forKey: novelId)
        activeNovelIds.remove(novelId)
        lock.unlock()
    }

    /// 取消所有 SSE 流。
    func cancelAll() {
        Logger.sse.info("取消所有 SSE 流")

        lock.lock()
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        eventHandlers.removeAll()
        stateHandlers.removeAll()
        errorHandlers.removeAll()
        activeStreams.removeAll()
        activeNovelIds.removeAll()
        lock.unlock()
    }

    /// 获取指定流的连接状态。
    ///
    /// - Parameters:
    ///   - streamType: 流类型
    ///   - novelId: 小说 ID
    /// - Returns: 连接状态，不存在返回 nil
    func connectionState(type streamType: SSEStreamType, novelId: String) -> SSEConnectionState? {
        let key = registryKey(streamType: streamType, novelId: novelId)
        lock.lock()
        let state = connections[key]?.state
        lock.unlock()
        return state
    }

    // MARK: - 生命周期管理

    /// 设置 App 生命周期监听
    private func setupLifecycleObservers() {
        // App 进入后台：挂起所有 SSE 连接
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // App 回到前台：重连所有活跃 SSE 流
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    /// App 进入后台
    @objc private func appDidEnterBackground() {
        Logger.sse.info("App 进入后台，挂起所有 SSE 连接")

        lock.lock()
        // 后台不主动取消连接（系统会自动挂起），但记录需要重连的流
        let snapshot = activeStreams
        lock.unlock()

        // 记录需要重连的流（用于回前台时恢复）
        // 系统会自动挂起 TCP 连接，这里不做额外操作
        _ = snapshot
    }

    /// App 回到前台
    @objc private func appWillEnterForeground() {
        Logger.sse.info("App 回到前台，重连活跃 SSE 流")

        lock.lock()
        let streamsToReconnect = activeStreams
        lock.unlock()

        // 重新启动所有活跃流（系统挂起后连接已失效）
        for (novelId, streamTypes) in streamsToReconnect {
            for streamType in streamTypes {
                let key = registryKey(streamType: streamType, novelId: novelId)

                // 保留原有回调，重新启动连接
                if let eventHandler = eventHandlers[key] {
                    let stateHandler = stateHandlers[key]
                    let errorHandler = errorHandlers[key]

                    // 取消旧连接
                    connections[key]?.cancel()

                    // 重新启动
                    startStream(
                        type: streamType,
                        novelId: novelId,
                        onEvent: eventHandler,
                        onStateChange: stateHandler,
                        onError: errorHandler
                    )
                }
            }
        }
    }

    // MARK: - 事件分发

    /// 处理 SSE 事件
    private func handleEvent(_ event: SSEEvent, key: String) {
        lock.lock()
        let handler = eventHandlers[key]
        lock.unlock()
        handler?(event)
    }

    /// 处理状态变更
    private func handleStateChange(_ state: SSEConnectionState, key: String) {
        lock.lock()
        let handler = stateHandlers[key]
        lock.unlock()
        handler?(state)
    }

    /// 处理错误
    private func handleError(_ error: Error, key: String) {
        lock.lock()
        let handler = errorHandlers[key]
        lock.unlock()
        handler?(error)
    }

    // MARK: - URL 构建

    /// 根据流类型和小说 ID 构建 SSE 端点 URL。
    ///
    /// 基于架构文档 6.5 节 7 条 SSE 流完整清单：
    /// 1. 章节生成流 — GET /api/v1/autopilot/{id}/chapter-stream
    /// 2. 自动驾驶事件/日志流 — GET /api/v1/autopilot/{id}/stream
    /// 3. Bible 流式生成 — POST /api/v1/bible/novels/{id}/generate-stream
    /// 4. 宏观规划流 — GET /api/v1/planning/novels/{id}/macro/stream
    /// 5. 宏观规划进度流 — GET /api/v1/planning/novels/{id}/macro/progress/stream
    /// 6. DAG 事件流 — GET /api/v1/dag/events?novel_id={id}
    /// 7. 扩展包安装流 — POST /api/v1/system/install-extensions
    ///
    /// - Parameters:
    ///   - streamType: 流类型
    ///   - novelId: 小说 ID
    /// - Returns: SSE 端点 URL
    private func sseURL(for streamType: SSEStreamType, novelId: String) -> URL? {
        let path: String

        switch streamType {
        case .chapterStream:
            // 1. 章节生成流
            path = "/autopilot/\(novelId)/chapter-stream"

        case .autopilotStream:
            // 2. 自动驾驶事件/日志流
            path = "/autopilot/\(novelId)/stream"

        case .bibleGenerateStream:
            // 3. Bible 流式生成
            path = "/bible/novels/\(novelId)/generate-stream"

        case .macroPlanStream:
            // 4. 宏观规划流
            path = "/planning/novels/\(novelId)/macro/stream"

        case .macroPlanProgressStream:
            // 5. 宏观规划进度流
            path = "/planning/novels/\(novelId)/macro/progress/stream"

        case .dagEvents:
            // 6. DAG 事件流（需要 query 参数 novel_id）
            if let url = config.fullURL(path: "/dag/events", prefix: APIConfig.apiV1Prefix) {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "novel_id", value: novelId)
                ]
                return components?.url
            }
            return nil

        case .extensionInstall:
            // 7. 扩展包安装流
            path = "/system/install-extensions"
        }

        return config.fullURL(path: path, prefix: APIConfig.apiV1Prefix)
    }

    // MARK: - 工具方法

    /// 生成注册表键
    private func registryKey(streamType: SSEStreamType, novelId: String) -> String {
        return "\(streamType.rawValue):\(novelId)"
    }
}

// MARK: - 便捷扩展

extension SSEStreamRegistry {

    /// 启动章节生成流
    ///
    /// 【返工M4】增加 onStateChange 参数，传给 startStream，使调用方可监听流结束状态。
    /// 修复前未暴露此参数，导致 AutopilotStore 无法感知流结束、onStreamEnd 回调从未调用。
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - onEvent: 事件回调
    ///   - onStateChange: 状态变更回调（可选，流结束时状态为 .disconnected）
    ///   - onError: 错误回调（可选）
    /// - Returns: 是否成功启动
    @discardableResult
    func startChapterStream(
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onStateChange: ((SSEConnectionState) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        return startStream(
            type: .chapterStream,
            novelId: novelId,
            onEvent: onEvent,
            onStateChange: onStateChange,
            onError: onError
        )
    }

    /// 启动自动驾驶日志流
    @discardableResult
    func startAutopilotStream(
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        return startStream(
            type: .autopilotStream,
            novelId: novelId,
            onEvent: onEvent,
            onError: onError
        )
    }

    /// 根据 Bible 生成阶段构建 SSE URL（含 stage 查询参数）。
    ///
    /// 后端 generate_bible_stream 接口接受 stage 查询参数（默认 "worldbuilding"）。
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - stage: 生成阶段（worldbuilding / characters / locations / all）
    /// - Returns: SSE 端点 URL
    func bibleGenerateStreamURL(novelId: String, stage: String) -> URL? {
        let path = "/bible/novels/\(novelId)/generate-stream"
        guard let url = config.fullURL(path: path, prefix: APIConfig.apiV1Prefix) else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "stage", value: stage)]
        return components?.url
    }

    /// 启动 Bible 生成流
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - stage: 生成阶段（worldbuilding / characters / locations / all）
    ///   - onEvent: 事件回调
    ///   - onError: 错误回调
    @discardableResult
    func startBibleGenerateStream(
        novelId: String,
        stage: String = "worldbuilding",
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        // 【修复】Bible 生成流需要 stage 查询参数，后端默认 "worldbuilding"。
        // 修复前未传递 stage 参数，导致后端总是使用默认值而非用户指定阶段。
        Logger.sse.info("启动 Bible 生成流 [novel: \(novelId), stage: \(stage)]")

        // 构建带 stage 参数的 SSE URL
        guard let url = bibleGenerateStreamURL(novelId: novelId, stage: stage) else {
            Logger.sse.error("SSE URL 构建失败: Bible 生成流")
            onError?(APIError.invalidURL)
            return false
        }

        let key = registryKey(streamType: .bibleGenerateStream, novelId: novelId)

        lock.lock()

        // 取消旧连接
        if let oldConnection = connections[key] {
            oldConnection.cancel()
            connections.removeValue(forKey: key)
        }

        // 创建新连接
        let connection = SSEConnection(streamType: .bibleGenerateStream, url: url, client: client)
        connections[key] = connection
        eventHandlers[key] = onEvent
        stateHandlers[key] = nil
        errorHandlers[key] = onError

        // 记录活跃流
        activeNovelIds.insert(novelId)
        if activeStreams[novelId] == nil {
            activeStreams[novelId] = []
        }
        activeStreams[novelId]?.insert(.bibleGenerateStream)

        lock.unlock()

        // 启动连接
        connection.start(
            onEvent: { [weak self] event in
                self?.handleEvent(event, key: key)
            },
            onStateChange: { [weak self] state in
                self?.handleStateChange(state, key: key)
            },
            onError: { [weak self] error in
                self?.handleError(error, key: key)
            }
        )

        return true
    }

    /// 启动宏观规划流
    @discardableResult
    func startMacroPlanStream(
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        return startStream(
            type: .macroPlanStream,
            novelId: novelId,
            onEvent: onEvent,
            onError: onError
        )
    }

    /// 启动 DAG 事件流
    @discardableResult
    func startDAGEvents(
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        return startStream(
            type: .dagEvents,
            novelId: novelId,
            onEvent: onEvent,
            onError: onError
        )
    }

    // MARK: - 单章生成 SSE 流（M5, workflow.ts:392）

    /// 构建 generate-chapter-stream SSE URL（POST /api/v1/novels/{novelId}/generate-chapter-stream）
    /// 对齐 workflow.ts:392 `fetch(resolveHttpUrl('/api/v1/novels/${novelId}/generate-chapter-stream'))`
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - payload: 生成请求载荷（GenerateChapterWithContextPayload）
    /// - Returns: SSE 端点 URL
    func generateChapterStreamURL(novelId: String) -> URL? {
        let path = "/novels/\(novelId)/generate-chapter-stream"
        return config.fullURL(path: path, prefix: APIConfig.apiV1Prefix)
    }

    /// 启动单章生成 SSE 流（M5, workflow.ts:375-511）
    /// POST /api/v1/novels/{novelId}/generate-chapter-stream
    /// data-only 格式，7类事件：phase/llm_chunk/beats_generated/approval_required/chunk/done/error
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - payload: 生成请求载荷（GenerateChapterWithContextPayload）
    ///   - onEvent: 事件回调
    ///   - onError: 错误回调
    /// - Returns: 是否成功启动
    @discardableResult
    func startGenerateChapterStream(
        novelId: String,
        payload: GenerateChapterWithContextPayload,
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        Logger.sse.info("启动单章生成 SSE 流 [novel: \(novelId), chapter: \(payload.chapterNumber)]")

        // 构建 SSE URL（POST 请求，body 为 JSON）
        guard let url = generateChapterStreamURL(novelId: novelId) else {
            Logger.sse.error("SSE URL 构建失败: 单章生成流")
            onError?(APIError.invalidURL)
            return false
        }

        // 使用专门的流类型标识（复用 chapterStream 的 key 前缀但加 generate 前缀区分）
        let key = "generateChapterStream:\(novelId)"

        lock.lock()

        // 取消旧连接
        if let oldConnection = connections[key] {
            oldConnection.cancel()
            connections.removeValue(forKey: key)
        }

        // 将 payload 编码为 JSON Data
        let bodyData = try? JSONEncoder().encode(payload)

        // 创建新连接 — 单章生成是 POST 请求，需要特殊处理
        let connection = SSEConnection(
            streamType: .chapterStream,  // 复用 chapterStream 类型（同为章节生成相关）
            url: url,
            client: client,
            method: "POST",
            body: bodyData
        )
        connections[key] = connection
        eventHandlers[key] = onEvent
        stateHandlers[key] = nil
        errorHandlers[key] = onError

        // 记录活跃流
        activeNovelIds.insert(novelId)
        if activeStreams[novelId] == nil {
            activeStreams[novelId] = []
        }
        activeStreams[novelId]?.insert(.chapterStream)

        lock.unlock()

        // 启动连接
        connection.start(
            onEvent: { [weak self] event in
                self?.handleEvent(event, key: key)
            },
            onStateChange: { [weak self] state in
                self?.handleStateChange(state, key: key)
            },
            onError: { [weak self] error in
                self?.handleError(error, key: key)
            }
        )

        return true
    }

    /// 取消单章生成 SSE 流
    /// - Parameter novelId: 小说 ID
    func cancelGenerateChapterStream(novelId: String) {
        let key = "generateChapterStream:\(novelId)"
        Logger.sse.info("取消单章生成 SSE 流: [novel: \(novelId)]")

        lock.lock()
        connections[key]?.cancel()
        connections.removeValue(forKey: key)
        eventHandlers.removeValue(forKey: key)
        stateHandlers.removeValue(forKey: key)
        errorHandlers.removeValue(forKey: key)
        lock.unlock()
    }

    // MARK: - 剧情总纲 SSE 流（阶段3, workflow.ts:682-771）

    /// 构建剧情总纲 SSE URL — workflow.ts:682-771
    /// POST /api/v1/novels/{novelId}/setup/generate-plot-outline-stream
    ///
    /// - Parameter novelId: 小说 ID
    /// - Returns: SSE 端点 URL
    func plotOutlineStreamURL(novelId: String) -> URL? {
        let path = "/novels/\(novelId)/setup/generate-plot-outline-stream"
        return config.fullURL(path: path, prefix: APIConfig.apiV1Prefix)
    }

    /// 启动剧情总纲 SSE 流 — workflow.ts:682-771 consumePlotOutlineStream
    /// data-only 格式，4类事件：phase/approval_required/done/error
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - onEvent: 事件回调
    ///   - onError: 错误回调
    /// - Returns: 是否成功启动
    @discardableResult
    func startPlotOutlineStream(
        novelId: String,
        onEvent: @escaping (SSEEvent) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> Bool {
        Logger.sse.info("启动剧情总纲 SSE 流 [novel: \(novelId)]")

        guard let url = plotOutlineStreamURL(novelId: novelId) else {
            Logger.sse.error("SSE URL 构建失败: 剧情总纲流")
            onError?(APIError.invalidURL)
            return false
        }

        let key = "plotOutlineStream:\(novelId)"

        lock.lock()

        if let oldConnection = connections[key] {
            oldConnection.cancel()
            connections.removeValue(forKey: key)
        }

        let bodyData = try? JSONSerialization.data(withJSONObject: [String: Any](), options: [])

        let connection = SSEConnection(
            streamType: .bibleGenerateStream, // 复用 POST SSE 类型
            url: url,
            client: client,
            method: "POST",
            body: bodyData
        )
        connections[key] = connection
        eventHandlers[key] = onEvent
        stateHandlers[key] = nil
        errorHandlers[key] = onError

        activeNovelIds.insert(novelId)
        if activeStreams[novelId] == nil {
            activeStreams[novelId] = []
        }
        activeStreams[novelId]?.insert(.bibleGenerateStream)

        lock.unlock()

        connection.start(
            onEvent: { [weak self] event in
                self?.handleEvent(event, key: key)
            },
            onStateChange: { [weak self] state in
                self?.handleStateChange(state, key: key)
            },
            onError: { [weak self] error in
                self?.handleError(error, key: key)
            }
        )

        return true
    }

    /// 取消剧情总纲 SSE 流
    /// - Parameter novelId: 小说 ID
    func cancelPlotOutlineStream(novelId: String) {
        let key = "plotOutlineStream:\(novelId)"
        Logger.sse.info("取消剧情总纲 SSE 流: [novel: \(novelId)]")

        lock.lock()
        connections[key]?.cancel()
        connections.removeValue(forKey: key)
        eventHandlers.removeValue(forKey: key)
        stateHandlers.removeValue(forKey: key)
        errorHandlers.removeValue(forKey: key)
        lock.unlock()
    }
}
