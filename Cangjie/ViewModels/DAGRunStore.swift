//
//  DAGRunStore.swift
//  Cangjie
//
//  DAG 运行状态管理 — 运行控制、历史记录、SSE 事件连接。
//  对齐原项目 stores/dagRunStore.ts L1-378 + composables/useDAGSSE.ts L1-451。
//
//  功能：
//  1. 10 个 @Published state + isRunning/canStart/canStop 计算属性
//  2. 8 个 action：startRun/stopRun/fetchStatus/connectSSE/disconnectSSE/scheduleReconnect/connectAutopilotLog/resetForNovel
//  3. 4 种事件回调注册：onNodeStatusChange/onNodeOutput/onEdgeFlow/onRunComplete
//  4. SSE 性能优化层（消息队列 + 节流 + 批处理 + 事件合并）
//  5. autopilot 日志桥接（stage/substep → resolveAutopilotLogToNodeType → 更新节点状态）
//

import SwiftUI
import Foundation

/// DAG 运行控制 Store — 对齐 dagRunStore.ts + useDAGSSE.ts
@MainActor
final class DAGRunStore: ObservableObject {

    // MARK: - State（10 个，对齐 dagRunStore.ts:15-29）

    /// 运行状态 — dagRunStore.ts:15
    @Published var runStatus: DAGRunStatus = .idle
    /// 当前运行 ID — dagRunStore.ts:16
    @Published var currentRunId: String?
    /// DAG 是否启用 — dagRunStore.ts:17
    @Published var dagEnabled: Bool = false
    /// 当前 DAG 版本 — dagRunStore.ts:18
    @Published var currentVersion: Int = 0
    /// 节点运行时状态快照 — dagRunStore.ts:21
    @Published var nodeStates: [String: NodeRunState] = [:]
    /// 运行历史 — dagRunStore.ts:24
    @Published var runHistory: [DAGRunResult] = []
    /// 最近运行结果 — dagRunStore.ts:25
    @Published var latestResult: DAGRunResult?
    /// SSE 连接状态 — dagRunStore.ts:28
    @Published var sseConnected: Bool = false
    /// SSE 错误信息 — dagRunStore.ts:29
    @Published var sseError: String?

    // MARK: - 计算属性（对齐 dagRunStore.ts:35-37）

    /// 是否正在运行 — dagRunStore.ts:35
    var isRunning: Bool { runStatus == .running }
    /// 是否可以启动 — dagRunStore.ts:36
    var canStart: Bool { runStatus == .idle || runStatus == .completed || runStatus == .error }
    /// 是否可以停止 — dagRunStore.ts:37
    var canStop: Bool { runStatus == .running }

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    // MARK: - 内部状态

    /// 重连定时器 — dagRunStore.ts:31 _reconnectTimer
    private var reconnectTask: Task<Void, Never>?
    /// 重连次数 — dagRunStore.ts:32 _reconnectAttempts
    private var reconnectAttempts: Int = 0
    /// 当前 SSE 连接的 novelId（用于重连）
    private var currentNovelId: String?
    /// autopilot 日志连接
    private var autopilotLogConnection: SSEConnection?
    /// autopilot 日志回调
    private var autopilotLogCallback: ((AutopilotLogData) -> Void)?

    // MARK: - SSE 性能优化层（对齐 useDAGSSE.ts:42-146）

    /// 消息队列 — useDAGSSE.ts:45
    private var messageQueue: [DAGEvent] = []
    /// 节流定时器 — useDAGSSE.ts:48
    private var throttleTask: Task<Void, Never>?
    /// 消息节流间隔（ms）— useDAGSSE.ts:22 MESSAGE_THROTTLE_MS = 100
    private let messageThrottleMs: UInt64 = 100
    /// 批量处理最大队列长度 — useDAGSSE.ts:25 MAX_QUEUE_SIZE = 50
    private let maxQueueSize: Int = 50
    /// 重连基础延迟（ms）— performance.ts reconnectBaseDelayMs = 1000
    private let reconnectBaseDelayMs: UInt64 = 1000
    /// 重连最大延迟（ms）— performance.ts reconnectMaxDelayMs = 30000
    private let reconnectMaxDelayMs: UInt64 = 30000

    /// 性能指标 — useDAGSSE.ts:51-58
    private var perfMetrics: (received: Int, processed: Int, dropped: Int) = (0, 0, 0)

    // MARK: - 事件回调注册表（对齐 dagRunStore.ts:200-228）

    private var nodeStatusCallbacks: [(DAGEvent) -> Void] = []
    private var nodeOutputCallbacks: [(DAGEvent) -> Void] = []
    private var edgeFlowCallbacks: [(DAGEvent) -> Void] = []
    private var runCompleteCallbacks: [(DAGRunResult) -> Void] = []

    // MARK: - DAG 版本缓存（对齐 useDAGSSE.ts:39-40）

    /// type→id 缓存版本号
    private var typeToIdCacheVersion: Int = -1
    /// type→id 缓存 Map
    private var typeToIdCache: [String: String] = [:]

    /// DAGStore 弱引用（读取 dagDefinition 用于 type→id 查找）
    private weak var dagStore: DAGStore?

    // MARK: - 初始化

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
    }

    /// 设置 DAGStore 引用（延迟注入）
    func setDAGStore(_ store: DAGStore) {
        self.dagStore = store
    }

    // MARK: - 运行控制（对齐 dagRunStore.ts:39-86）

    /// 启动 DAG 运行 — 对齐 dagRunStore.ts:41-52
    /// - Parameter novelId: 小说 ID
    func startRun(novelId: String) async {
        // 对齐 dagRunStore.ts:42 if (!canStart.value) return
        guard canStart else { return }
        do {
            // 对齐 dagRunStore.ts:44 runStatus.value = 'running'
            runStatus = .running
            // 对齐 dagRunStore.ts:45 const result = await dagApi.runDAG(novelId)
            let result: DAGRunResponse = try await apiClient.request(
                APIEndpoint.DAG.run(novelId: novelId),
                body: EmptyBody()
            )
            // 对齐 dagRunStore.ts:46 currentRunId.value = result.novel_id
            currentRunId = result.novelId
            currentNovelId = novelId
            sseError = nil
        } catch {
            // 对齐 dagRunStore.ts:48-50 catch → runStatus = 'error', sseError = message
            runStatus = .error
            sseError = error.localizedDescription
        }
    }

    /// 停止 DAG 运行 — 对齐 dagRunStore.ts:54-65
    /// - Parameter novelId: 小说 ID
    func stopRun(novelId: String) async {
        // 对齐 dagRunStore.ts:55 if (!canStop.value) return
        guard canStop else { return }
        do {
            // 对齐 dagRunStore.ts:57 runStatus.value = 'stopping'
            runStatus = .stopping
            // 对齐 dagRunStore.ts:58 await dagApi.stopDAG(novelId)
            _ = try await apiClient.request(
                APIEndpoint.DAG.stop(novelId: novelId),
                body: EmptyBody()
            ) as DAGRunResponse
            // 对齐 dagRunStore.ts:59 runStatus.value = 'idle'
            runStatus = .idle
        } catch {
            // 对齐 dagRunStore.ts:60-64 catch → sseError = message; runStatus = 'idle'
            sseError = error.localizedDescription
            // 即使停止失败，也标记为 idle 以避免 UI 卡住
            runStatus = .idle
        }
    }

    /// 获取 DAG 运行状态 — 对齐 dagRunStore.ts:67-86
    /// - Parameter novelId: 小说 ID
    func fetchStatus(novelId: String) async {
        do {
            // 对齐 dagRunStore.ts:69 const status = await dagApi.getStatus(novelId)
            let status: DAGStatusResponse = try await apiClient.request(
                APIEndpoint.DAG.status(novelId: novelId)
            )
            // 对齐 dagRunStore.ts:70-72
            dagEnabled = status.dagEnabled
            currentVersion = status.currentVersion
            nodeStates = status.nodeStates

            // 对齐 dagRunStore.ts:74-82 检查是否有节点正在运行
            let hasRunning = status.nodeStates.values.contains { state in
                state.status == "running" || state.status == "pending"
            }
            if hasRunning && runStatus != .running {
                runStatus = .running
            } else if !hasRunning && runStatus == .running {
                runStatus = .idle
            }
        } catch {
            // 对齐 dagRunStore.ts:83-85 静默失败
        }
    }

    // MARK: - SSE 事件连接（对齐 dagRunStore.ts:90-195）

    /// 连接 DAG SSE 事件流，注册 4 种事件监听 — 对齐 dagRunStore.ts:90-164
    /// - Parameter novelId: 小说 ID
    func connectSSE(novelId: String) {
        // 对齐 dagRunStore.ts:91 disconnectSSE({ resetReconnect: true })
        disconnectSSE(resetReconnect: true)

        currentNovelId = novelId
        sseConnected = false
        sseError = nil

        // 对齐 dagRunStore.ts:94-97 构建 SSE URL 并连接
        // 复用 SSEStreamRegistry.startDAGEvents（GET /dag/events?novel_id=xxx）
        sseRegistry.startDAGEvents(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleSSEEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.handleSSEError(error, novelId: novelId)
                }
            }
        )
    }

    /// 断开 SSE + 清除重连定时器 — 对齐 dagRunStore.ts:166-179
    /// - Parameter resetReconnect: 是否重置重连计数
    func disconnectSSE(resetReconnect: Bool = true) {
        // 对齐 dagRunStore.ts:167-170 关闭 EventSource
        if let nId = currentNovelId {
            sseRegistry.cancelStream(type: .dagEvents, novelId: nId)
        }
        // 对齐 dagRunStore.ts:171-174 清除重连定时器
        reconnectTask?.cancel()
        reconnectTask = nil
        // 对齐 dagRunStore.ts:175-177 重置重连计数
        if resetReconnect {
            reconnectAttempts = 0
        }
        // 对齐 dagRunStore.ts:178 sseConnected.value = false
        sseConnected = false
    }

    /// 指数退避重连 — 对齐 dagRunStore.ts:181-195
    /// - Parameter novelId: 小说 ID
    func scheduleReconnect(novelId: String) {
        // 对齐 dagRunStore.ts:182 if (_reconnectTimer) return
        if reconnectTask != nil { return }

        // 对齐 dagRunStore.ts:183 _reconnectAttempts += 1
        reconnectAttempts += 1

        // 对齐 dagRunStore.ts:185-188 delay = min(baseDelay * 2^(attempts-1), maxDelay)
        let exponent = min(reconnectAttempts - 1, 30) // 防止溢出
        let delayMs = min(
            reconnectBaseDelayMs * (1 << exponent),
            reconnectMaxDelayMs
        )

        Logger.sse.info("DAG SSE 准备重连（第 \(reconnectAttempts) 次，延迟 \(delayMs)ms）")

        reconnectTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)

            if Task.isCancelled { return }

            // 对齐 dagRunStore.ts:190-193 仅在 runStatus == 'running' 时重连
            if self.runStatus == .running {
                self.reconnectTask = nil
                self.connectSSE(novelId: novelId)
            } else {
                self.reconnectTask = nil
            }
        }
    }

    // MARK: - SSE 事件处理（对齐 dagRunStore.ts:230-282）

    /// P0-8：DAGStore 委托的事件分发入口
    /// DAGStore.handleDAGEvent 调用此方法，将原始 SSEEvent 交给 DAGRunStore 处理
    /// 这样 DAGRunStore 可以正确处理 dag_run_complete 事件（data 是 DAGRunResult JSON 而非 DAGEvent）
    /// - Parameter event: 原始 SSE 事件
    func dispatchSSEEvent(_ event: SSEEvent) {
        handleSSEEvent(event)
    }

    /// 处理 SSE 事件 — DAG 事件流使用 event+data 格式
    private func handleSSEEvent(_ event: SSEEvent) {
        // 忽略心跳和连接事件
        if event.isHeartbeat || event.isConnected { return }

        // 连接成功
        sseConnected = true
        sseError = nil
        reconnectAttempts = 0

        // DAG 事件流使用 event+data 格式，event 字段是事件名
        let eventType = event.event ?? ""

        // dag_run_complete 事件的 data 是 DAGRunResult JSON，需要特殊处理
        // 对齐 dagRunStore.ts:144-150 source.addEventListener('dag_run_complete', ...)
        if eventType == "dag_run_complete" {
            if let data = event.data.data(using: .utf8) {
                // 尝试用 CangjieDecoder 解码
                if let result = try? CangjieDecoder.shared.decode(DAGRunResult.self, from: data) {
                    // 立即刷新队列 — 对齐 useDAGSSE.ts:163 flushQueue()
                    flushQueue()
                    handleDAGRunCompleteResult(result)
                    return
                }
                // 解码失败，尝试从字典构造
                if let dict = event.decodeAsDictionary() {
                    let result = DAGRunResult.from(dict: dict)
                    flushQueue()
                    handleDAGRunCompleteResult(result)
                    return
                }
            }
            return
        }

        // 对齐 7.1 SSE 事件处理统一模式：用 decodeAsDictionary 手动取值
        guard let dict = event.decodeAsDictionary() else { return }

        // 构造 DAGEvent
        let dagEvent = DAGEvent.from(dict: dict, eventType: eventType)

        // 通过消息队列处理（性能优化层）
        enqueueEvent(dagEvent)
    }

    /// 处理 SSE 错误 — 对齐 dagRunStore.ts:152-159
    private func handleSSEError(_ error: Error, novelId: String) {
        sseConnected = false
        sseError = error.localizedDescription
        // 对齐 dagRunStore.ts:158 自动重连
        scheduleReconnect(novelId: novelId)
    }

    // MARK: - SSE 性能优化层（对齐 useDAGSSE.ts:63-146）

    /// 推入消息到队列 — 对齐 useDAGSSE.ts:63-84
    private func enqueueEvent(_ event: DAGEvent) {
        perfMetrics.received += 1

        // 对齐 useDAGSSE.ts:67-77 队列溢出保护
        if messageQueue.count >= maxQueueSize {
            perfMetrics.dropped += 1
            // 丢弃最旧的消息 — useDAGSSE.ts:71 messageQueue.shift()
            if !messageQueue.isEmpty {
                messageQueue.removeFirst()
            }
        }

        // useDAGSSE.ts:79 messageQueue.push(event)
        messageQueue.append(event)

        // 对齐 useDAGSSE.ts:83 触发节流处理
        scheduleFlush()
    }

    /// 调度队列刷新（节流）— 对齐 useDAGSSE.ts:89-96
    private func scheduleFlush() {
        // 对齐 useDAGSSE.ts:90 if (throttleTimer) return
        if throttleTask != nil { return }

        throttleTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: self.messageThrottleMs * 1_000_000)

            if Task.isCancelled { return }

            await MainActor.run {
                self.throttleTask = nil
                self.flushQueue()
            }
        }
    }

    /// 刷新队列（批量处理）— 对齐 useDAGSSE.ts:101-130
    private func flushQueue() {
        // 对齐 useDAGSSE.ts:102 if (messageQueue.length === 0) return
        if messageQueue.isEmpty { return }

        // 对齐 useDAGSSE.ts:111 const batch = messageQueue.splice(0, messageQueue.length)
        let batch = messageQueue
        messageQueue.removeAll()

        // 对齐 useDAGSSE.ts:114 合并同类事件
        let mergedEvents = mergeEvents(batch)

        // 对齐 useDAGSSE.ts:117-124 批量处理消息
        for event in mergedEvents {
            handleSSEMessage(event)
            perfMetrics.processed += 1
        }
    }

    /// 合并同类事件（优化渲染）— 对齐 useDAGSSE.ts:136-146
    private func mergeEvents(_ events: [DAGEvent]) -> [DAGEvent] {
        // 对齐 useDAGSSE.ts:137 const eventMap = new Map<string, NodeEvent>()
        var eventMap: [String: DAGEvent] = [:]

        for event in events {
            // 对齐 useDAGSSE.ts:139 const key = `${event.type}:${event.node_id}`
            let nodeId = event.nodeId ?? ""
            let key = "\(event.type):\(nodeId)"
            // 对齐 useDAGSSE.ts:142 只保留最新的事件
            eventMap[key] = event
        }

        // 对齐 useDAGSSE.ts:145 return Array.from(eventMap.values())
        return Array(eventMap.values)
    }

    // MARK: - SSE 消息分发（对齐 dagRunStore.ts:230-282）

    /// 通用消息分发 — 对齐 dagRunStore.ts:230-243
    /// 注意：dag_run_complete 事件在 handleSSEEvent 中直接处理，不经过消息队列
    private func handleSSEMessage(_ event: DAGEvent) {
        // 对齐 dagRunStore.ts:232-242 switch (event.type)
        switch event.type {
        case "node_status_change":
            handleNodeStatusChange(event)
        case "node_output":
            handleNodeOutput(event)
        case "edge_data_flow":
            handleEdgeFlow(event)
        default:
            break
        }
    }

    /// 处理节点状态变更 — 对齐 dagRunStore.ts:245-263
    private func handleNodeStatusChange(_ event: DAGEvent) {
        // 对齐 dagRunStore.ts:247-249 更新本地节点状态
        if let nodeId = event.nodeId, let status = event.status {
            let existing = nodeStates[nodeId] ?? NodeRunState(nodeId: nodeId, status: "idle")
            nodeStates[nodeId] = NodeRunState(
                nodeId: nodeId,
                status: status,
                startedAt: existing.startedAt,
                completedAt: existing.completedAt,
                durationMs: existing.durationMs,
                outputs: existing.outputs,
                metrics: existing.metrics,
                error: existing.error,
                progress: existing.progress,
                enabled: existing.enabled
            )

            // 对齐 dagRunStore.ts:252-259 如果所有节点完成，标记 DAG 完成
            if status == "success" || status == "error" {
                let allDone = nodeStates.values.allSatisfy { state in
                    ["success", "error", "bypassed", "disabled", "completed"].contains(state.status)
                }
                if allDone && runStatus == .running {
                    runStatus = .completed
                }
            }
        }
        // 对齐 dagRunStore.ts:262 通知回调
        for cb in nodeStatusCallbacks { cb(event) }
    }

    /// 处理节点输出 — 对齐 dagRunStore.ts:265-267
    private func handleNodeOutput(_ event: DAGEvent) {
        for cb in nodeOutputCallbacks { cb(event) }
    }

    /// 处理边数据流 — 对齐 dagRunStore.ts:269-271
    private func handleEdgeFlow(_ event: DAGEvent) {
        for cb in edgeFlowCallbacks { cb(event) }
    }

    /// 处理 DAG 运行完成 — 对齐 dagRunStore.ts:273-282
    /// 接收已解析的 DAGRunResult（dag_run_complete 事件的 data 直接是 DAGRunResult JSON）
    private func handleDAGRunCompleteResult(_ result: DAGRunResult) {
        // 对齐 dagRunStore.ts:274 runStatus = result.status === 'completed' ? 'completed' : 'error'
        runStatus = result.status == "completed" ? .completed : .error
        // 对齐 dagRunStore.ts:275 latestResult.value = result
        latestResult = result
        // 对齐 dagRunStore.ts:276 runHistory.value.unshift(result)
        runHistory.insert(result, at: 0)
        // 对齐 dagRunStore.ts:278-280 只保留最近 20 条
        if runHistory.count > 20 {
            runHistory = Array(runHistory.prefix(20))
        }
        // 对齐 dagRunStore.ts:281 通知回调
        for cb in runCompleteCallbacks { cb(result) }
    }

    // MARK: - 4 种事件回调注册（对齐 dagRunStore.ts:200-228）

    /// 注册 node_status_change 事件回调 — 对齐 dagRunStore.ts:213-216
    /// - Parameter cb: 回调闭包
    /// - Returns: 取消注册闭包
    @discardableResult
    func onNodeStatusChange(_ cb: @escaping (DAGEvent) -> Void) -> () -> Void {
        nodeStatusCallbacks.append(cb)
        return { [weak self] in
            self?.nodeStatusCallbacks.removeAll { ObjectIdentifier($0 as AnyObject) == ObjectIdentifier(cb as AnyObject) }
        }
    }

    /// 注册 node_output 事件回调 — 对齐 dagRunStore.ts:217-220
    @discardableResult
    func onNodeOutput(_ cb: @escaping (DAGEvent) -> Void) -> () -> Void {
        nodeOutputCallbacks.append(cb)
        return { [weak self] in
            self?.nodeOutputCallbacks.removeAll { ObjectIdentifier($0 as AnyObject) == ObjectIdentifier(cb as AnyObject) }
        }
    }

    /// 注册 edge_data_flow 事件回调 — 对齐 dagRunStore.ts:221-224
    @discardableResult
    func onEdgeFlow(_ cb: @escaping (DAGEvent) -> Void) -> () -> Void {
        edgeFlowCallbacks.append(cb)
        return { [weak self] in
            self?.edgeFlowCallbacks.removeAll { ObjectIdentifier($0 as AnyObject) == ObjectIdentifier(cb as AnyObject) }
        }
    }

    /// 注册 dag_run_complete 事件回调 — 对齐 dagRunStore.ts:225-228
    @discardableResult
    func onRunComplete(_ cb: @escaping (DAGRunResult) -> Void) -> () -> Void {
        runCompleteCallbacks.append(cb)
        return { [weak self] in
            self?.runCompleteCallbacks.removeAll { ObjectIdentifier($0 as AnyObject) == ObjectIdentifier(cb as AnyObject) }
        }
    }

    // MARK: - autopilot 日志流连接（对齐 dagRunStore.ts:289-321）

    /// 连接 autopilot 日志流，桥接到 DAG 节点状态 — 对齐 dagRunStore.ts:289-321
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - callback: 日志数据回调
    func connectAutopilotLog(
        novelId: String,
        callback: @escaping (AutopilotLogData) -> Void
    ) {
        // 对齐 dagRunStore.ts:293 disconnectAutopilotLog()
        disconnectAutopilotLog()
        // 对齐 dagRunStore.ts:294 _autopilotLogCallback = callback
        autopilotLogCallback = callback

        // 对齐 dagRunStore.ts:296 构建 log-stream URL
        // GET /autopilot/{novelId}/log-stream
        guard let url = APIConfig.shared.fullURL(
            path: "/autopilot/\(novelId)/log-stream",
            prefix: APIConfig.apiV1Prefix
        ) else {
            return
        }

        // 对齐 dagRunStore.ts:297-298 创建 EventSource
        autopilotLogConnection = SSEConnection(
            streamType: .autopilotStream,
            url: url,
            client: SSEClient(apiClient: .shared)
        )

        // 对齐 dagRunStore.ts:300-313 onmessage 处理
        autopilotLogConnection?.start(
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleAutopilotLogEvent(event, novelId: novelId)
                }
            },
            onStateChange: { _ in
                // 静默处理状态变更
            },
            onError: { _ in
                // 对齐 dagRunStore.ts:315-317 静默失败，不重连
            }
        )
    }

    /// 断开 autopilot 日志流 — 对齐 dagRunStore.ts:323-329
    func disconnectAutopilotLog() {
        // 对齐 dagRunStore.ts:324-327 _autopilotLogSource.close()
        autopilotLogConnection?.cancel()
        autopilotLogConnection = nil
        // 对齐 dagRunStore.ts:328 _autopilotLogCallback = null
        autopilotLogCallback = nil
    }

    // MARK: - autopilot 日志 → DAG 节点状态桥接（对齐 useDAGSSE.ts:264-351）

    /// 处理 autopilot 日志事件 — 对齐 useDAGSSE.ts:264-351
    private func handleAutopilotLogEvent(_ event: SSEEvent, novelId: String) {
        guard let dict = event.decodeAsDictionary() else { return }

        // 对齐 useDAGSSE.ts:269-270 解析 metadata
        let meta = (dict["metadata"] as? [String: Any]) ?? (dict["meta"] as? [String: Any]) ?? [:]
        let stage = String(meta["stage"] as? String ?? (meta["current_stage"] as? String ?? ""))
        let substep = String(meta["writing_substep"] as? String ?? "")

        // 对齐 useDAGSSE.ts:274 const subNorm = substep && substep !== 'undefined' ? substep : ''
        let subNorm = (substep.isEmpty || substep == "undefined") ? "" : substep

        // 对齐 useDAGSSE.ts:275-295 有 substep 时
        if !subNorm.isEmpty {
            let nodeType = resolveAutopilotLogToNodeType(stage: stage, substep: subNorm)
            if let nodeType = nodeType {
                if let nodeId = findNodeIdByType(nodeType) {
                    enqueueEvent(DAGEvent(
                        type: "node_status_change",
                        novelId: novelId,
                        nodeId: nodeId,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        status: "running",
                        metrics: nil,
                        outputs: nil,
                        durationMs: nil,
                        error: nil
                    ))
                }
            }
            return
        }

        // 对齐 useDAGSSE.ts:297-315 有 stage 时
        if !stage.isEmpty && stage != "undefined" {
            let nodeType = resolveAutopilotLogToNodeType(stage: stage, substep: "")
            if let nodeType = nodeType {
                markPreviousRunningAsComplete(novelId: novelId)
                if let nodeId = findNodeIdByType(nodeType) {
                    enqueueEvent(DAGEvent(
                        type: "node_status_change",
                        novelId: novelId,
                        nodeId: nodeId,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        status: "running",
                        metrics: nil,
                        outputs: nil,
                        durationMs: nil,
                        error: nil
                    ))
                }
            } else if stage == "completed" {
                markAllNodesComplete(novelId: novelId)
            }
        }

        // 对齐 useDAGSSE.ts:317-340 beat 进度
        if let beatIdx = meta["current_beat_index_1based"],
           let totalBeats = meta["total_beats"] {
            let writerNodeId = findNodeIdByType("exec_writer")
            if let nodeId = writerNodeId {
                let beatIdxVal = Double("\(beatIdx)") ?? 0
                let totalBeatsVal = Double("\(totalBeats)") ?? 1
                let accWords = Double("\(meta["accumulated_words"] ?? 0)") ?? 0
                let targetWords = Double("\(meta["chapter_target_words"] ?? 0)") ?? 0

                enqueueEvent(DAGEvent(
                    type: "node_status_change",
                    novelId: novelId,
                    nodeId: nodeId,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    status: "running",
                    metrics: nil,
                    outputs: nil,
                    durationMs: nil,
                    error: nil
                ))
                _ = (beatIdxVal, totalBeatsVal, accWords, targetWords) // 使用变量避免警告
            }
        }

        // 对齐 useDAGSSE.ts:342-350 日志消息判断
        let type = dict["type"] as? String ?? "log"
        let message = dict["message"] as? String ?? ""
        if type == "log" && !message.isEmpty {
            if message.contains("审计完成") || message.contains("audit_complete") {
                markValidationNodesComplete(novelId: novelId)
            }
            if message.contains("章节完成") || message.contains("chapter_complete") {
                markAllNodesComplete(novelId: novelId)
            }
        }

        // 调用外部回调
        autopilotLogCallback?(AutopilotLogData(
            type: type,
            message: message,
            metadata: meta
        ))
    }

    /// 解析日志元数据 → DAG 节点 type — 对齐 autopilotDagLogBridge.ts:73-87
    private func resolveAutopilotLogToNodeType(stage: String, substep: String) -> String? {
        let ws = substep.trimmingCharacters(in: .whitespaces)
        if !ws.isEmpty && ws != "undefined" {
            if let hit = AutopilotDagLogBridge.shared.substepToNodeType(ws) {
                return hit
            }
        }
        let st = stage.trimmingCharacters(in: .whitespaces)
        if st.isEmpty || st == "undefined" {
            return nil
        }
        return AutopilotDagLogBridge.shared.stageToNodeType(st)
    }

    /// 通过 type 查找 nodeId — 对齐 useDAGSSE.ts:353-366
    private func findNodeIdByType(_ nodeType: String) -> String? {
        guard let dagStore = dagStore, let dag = dagStore.dagDefinition else { return nil }
        let ver = dag.version
        // 对齐 useDAGSSE.ts:357-365 版本变化时重建缓存
        if typeToIdCacheVersion != ver || typeToIdCache.isEmpty {
            typeToIdCache.removeAll()
            for node in dag.nodes {
                if typeToIdCache[node.type] == nil {
                    typeToIdCache[node.type] = node.id
                }
            }
            typeToIdCacheVersion = ver
        }
        return typeToIdCache[nodeType]
    }

    /// 标记之前运行的节点为完成 — 对齐 useDAGSSE.ts:368-384
    private func markPreviousRunningAsComplete(novelId: String) {
        for (nodeId, state) in nodeStates {
            if state.status == "running" {
                enqueueEvent(DAGEvent(
                    type: "node_status_change",
                    novelId: novelId,
                    nodeId: nodeId,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    status: "success",
                    metrics: nil,
                    outputs: nil,
                    durationMs: state.durationMs,
                    error: nil
                ))
            }
        }
    }

    /// 标记验证节点为完成 — 对齐 useDAGSSE.ts:386-403
    private func markValidationNodesComplete(novelId: String) {
        guard let dagStore = dagStore, let dag = dagStore.dagDefinition else { return }
        for node in dag.nodes {
            if node.type.hasPrefix("val_") {
                let currentState = nodeStates[node.id]
                if currentState?.status == "running" {
                    enqueueEvent(DAGEvent(
                        type: "node_status_change",
                        novelId: novelId,
                        nodeId: node.id,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        status: "success",
                        metrics: nil,
                        outputs: nil,
                        durationMs: nil,
                        error: nil
                    ))
                }
            }
        }
    }

    /// 标记所有节点为完成 — 对齐 useDAGSSE.ts:405-419
    private func markAllNodesComplete(novelId: String) {
        guard let dagStore = dagStore, let dag = dagStore.dagDefinition else { return }
        for node in dag.nodes {
            if node.enabled {
                enqueueEvent(DAGEvent(
                    type: "node_status_change",
                    novelId: novelId,
                    nodeId: node.id,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    status: "success",
                    metrics: nil,
                    outputs: nil,
                    durationMs: nil,
                    error: nil
                ))
            }
        }
    }

    // MARK: - 重置（对齐 dagRunStore.ts:333-341）

    /// 重置所有状态 + 断开所有连接 — 对齐 dagRunStore.ts:333-341
    /// - Parameter novelId: 小说 ID
    func resetForNovel(novelId: String) {
        // 对齐 dagRunStore.ts:334-339
        runStatus = .idle
        currentRunId = nil
        latestResult = nil
        nodeStates = [:]
        sseError = nil
        // 对齐 dagRunStore.ts:339 disconnectSSE()
        disconnectSSE()
        // 对齐 dagRunStore.ts:340 disconnectAutopilotLog()
        disconnectAutopilotLog()
        currentNovelId = nil
        // 清理消息队列
        messageQueue.removeAll()
        throttleTask?.cancel()
        throttleTask = nil
    }
}

// MARK: - 辅助类型

/// DAG 运行/停止 API 响应 — 对齐 dag.ts:73/77
struct DAGRunResponse: Codable {
    let status: String
    let novelId: String

    enum CodingKeys: String, CodingKey {
        case status
        case novelId = "novel_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
    }
}

/// 空请求体（POST /dag/{id}/run 和 /stop 不需要 body）
struct EmptyBody: Encodable {}

/// autopilot 日志数据 — 对齐 dagRunStore.ts:287
struct AutopilotLogData {
    let type: String
    let message: String
    let metadata: [String: Any]
}

// MARK: - DAGEvent 辅助扩展

extension DAGEvent {
    /// 从字典构造 DAGEvent
    static func from(dict: [String: Any], eventType: String) -> DAGEvent {
        let novelId = dict["novel_id"] as? String ?? ""
        let nodeId = dict["node_id"] as? String
        let timestamp = dict["timestamp"] as? String
        let status = dict["status"] as? String
        let durationMs = dict["duration_ms"] as? Int
        let error = dict["error"] as? String

        let metrics: [String: AnyCodable]?
        if let metricsDict = dict["metrics"] as? [String: Any] {
            metrics = metricsDict.mapValues { AnyCodable($0) }
        } else {
            metrics = nil
        }

        let outputs: AnyCodable?
        if let outputsVal = dict["outputs"] {
            outputs = AnyCodable(outputsVal)
        } else {
            outputs = nil
        }

        // 使用显式 init
        return DAGEvent(
            type: eventType,
            novelId: novelId,
            nodeId: nodeId,
            timestamp: timestamp,
            status: status,
            metrics: metrics,
            outputs: outputs,
            durationMs: durationMs,
            error: error
        )
    }

    /// 转换为字典
    func toDictionary() -> [String: Any]? {
        var dict: [String: Any] = [
            "type": type,
            "novel_id": novelId,
        ]
        if let nodeId = nodeId { dict["node_id"] = nodeId }
        if let timestamp = timestamp { dict["timestamp"] = timestamp }
        if let status = status { dict["status"] = status }
        if let durationMs = durationMs { dict["duration_ms"] = durationMs }
        if let error = error { dict["error"] = error }
        return dict
    }
}

// MARK: - DAGRunResult 辅助扩展

extension DAGRunResult {
    /// 从字典构造 DAGRunResult
    static func from(dict: [String: Any]) -> DAGRunResult {
        let dagRunId = dict["dag_run_id"] as? String ?? ""
        let novelId = dict["novel_id"] as? String ?? ""
        let status = dict["status"] as? String ?? "completed"
        let nodeResults = AnyCodable(dict["node_results"] ?? [:])
        let totalDurationMs = dict["total_duration_ms"] as? Int ?? 0
        let errorCount = dict["error_count"] as? Int ?? 0
        let startedAt = dict["started_at"] as? String ?? ""
        let completedAt = dict["completed_at"] as? String ?? ""

        return DAGRunResult(
            dagRunId: dagRunId,
            novelId: novelId,
            status: status,
            nodeResults: nodeResults,
            totalDurationMs: totalDurationMs,
            errorCount: errorCount,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

// MARK: - AutopilotDagLogBridge（对齐 autopilotDagLogBridge.ts）

/// 全托管日志流 → DAG 节点 type 桥接策略 — 对齐 autopilotDagLogBridge.ts
final class AutopilotDagLogBridge {

    static let shared = AutopilotDagLogBridge()

    /// substep → nodeType 查找表 — 对齐 autopilotDagLogBridge.ts:20-34
    private let substepLookup: [String: String]

    /// stage → nodeType 查找表（含 nil）— 对齐 autopilotDagLogBridge.ts:36-43
    private let stageLookup: [String: String?]

    private init() {
        // 对齐 autopilotDagLogBridge.ts:20-34 AUTOPILOT_SUBSTEP_PRIMARY_RULES
        var subMap: [String: String] = [:]
        let substepRules: [(substeps: [String], primaryNodeType: String)] = [
            (["macro_planning"], "ctx_blueprint"),
            (["act_planning"], "ctx_memory"),
            (["outline_planning"], "exec_beat"),
            (["llm_calling"], "exec_writer"),
            (["chapter_found", "context_assembly", "beat_magnification"], "exec_beat"),
            (["persisting", "continuity_check", "chapter_persist"], "exec_writer"),
            (["audit_voice_check"], "val_style"),
            (["audit_tension"], "val_tension"),
            (["audit_aftermath"], "val_narrative"),
            (["audit_anti_ai"], "val_anti_ai"),
        ]
        for rule in substepRules {
            for s in rule.substeps {
                if subMap[s] == nil {
                    subMap[s] = rule.primaryNodeType
                }
            }
        }
        substepLookup = subMap

        // 对齐 autopilotDagLogBridge.ts:36-43 AUTOPILOT_STAGE_PRIMARY_RULES
        var stageMap: [String: String?] = [:]
        let stageRules: [(stages: [String], primaryNodeType: String?)] = [
            (["macro_planning", "planning"], "ctx_blueprint"),
            (["act_planning"], "ctx_memory"),
            (["writing"], "exec_writer"),
            (["auditing"], "val_style"),
            (["paused_for_review"], "gw_review"),
            (["completed"], nil),
        ]
        for rule in stageRules {
            for s in rule.stages {
                if stageMap[s] == nil {
                    stageMap[s] = rule.primaryNodeType
                }
            }
        }
        stageLookup = stageMap
    }

    /// substep → nodeType — 对齐 buildSubstepLookup
    func substepToNodeType(_ substep: String) -> String? {
        return substepLookup[substep]
    }

    /// stage → nodeType — 对齐 buildStageLookup（返回 nil 表示阶段存在但无主节点）
    func stageToNodeType(_ stage: String) -> String? {
        // 对齐 autopilotDagLogBridge.ts:83-85
        // STAGE_TO_PRIMARY_TYPE.has(st) → return STAGE_TO_PRIMARY_TYPE.get(st) ?? null
        // 注意：stageLookup 的 value 是 String?，nil 表示阶段存在但无主节点
        // 如果 key 不存在，返回 nil（无匹配）
        // 如果 key 存在但 value 是 nil，也返回 nil（阶段存在但无主节点）
        // 两种情况在 Swift 中都是返回 nil，但语义不同
        // 原版代码先检查 has(st)，再返回 get(st) ?? null
        // 在 Swift 中，如果 key 存在但 value 是 nil（Optional<String?>.some(nil)），我们需要区分
        if let value = stageLookup[stage] {
            return value // 可能是 nil（阶段存在但无主节点）
        }
        return nil // key 不存在
    }
}
