//
//  AutopilotStore.swift
//  Cangjie
//
//  自动驾驶控制：start/stop/resume + 章节生成 SSE + 日志 SSE + 熔断器。
//

import SwiftUI
import Foundation

/// 自动驾驶 Store
@MainActor
final class AutopilotStore: ObservableObject {

    // MARK: - 状态

    /// 自动驾驶状态
    @Published var status: AutopilotStatus?

    /// 熔断器状态
    @Published var circuitBreaker: CircuitBreakerStatus?

    /// 日志流（最近 N 条）
    @Published var logs: [LogStreamEvent] = []

    /// 章节生成事件流
    @Published var chapterEvents: [ChapterStreamEvent] = []

    /// 是否正在启动/停止
    @Published var isControlling: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// SSE 连接状态
    @Published var sseConnected: Bool = false

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry
    private let novelStore: NovelStore?

    // MARK: - 状态轮询定时器

    private var statusPollingTask: Task<Void, Never>?

    // MARK: - 初始化

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared, novelStore: NovelStore? = nil) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
        self.novelStore = novelStore
    }

    // MARK: - 自动驾驶控制

    /// 启动自动驾驶
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - targetChapters: 目标章数
    ///   - targetWordsPerChapter: 每章字数
    func startAutopilot(
        novelId: String,
        targetChapters: Int? = nil,
        targetWordsPerChapter: Int? = nil
    ) async {
        isControlling = true
        errorMessage = nil

        let request = AutopilotStartRequest(
            targetChapters: targetChapters,
            targetWordsPerChapter: targetWordsPerChapter
        )

        do {
            // 后端返回 dict，用 AnyCodable 接收
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.Autopilot.start(novelId: novelId),
                body: request
            )
            Logger.engine.info("自动驾驶已启动: \(novelId)")
            await refreshStatus(novelId: novelId)
            startSSEStreams(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
            Logger.engine.error("启动自动驾驶失败: \(error.localizedDescription)")
        }

        isControlling = false
    }

    /// 停止自动驾驶
    /// - Parameter novelId: 小说 ID
    func stopAutopilot(novelId: String) async {
        isControlling = true

        do {
            let _: AnyCodable = try await apiClient.request(APIEndpoint.Autopilot.stop(novelId: novelId))
            Logger.engine.info("自动驾驶已停止: \(novelId)")
            stopSSEStreams(novelId: novelId)
            await refreshStatus(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isControlling = false
    }

    /// 恢复自动驾驶（审阅确认后继续）
    /// - Parameter novelId: 小说 ID
    func resumeAutopilot(novelId: String) async {
        isControlling = true

        do {
            let _: AnyCodable = try await apiClient.request(APIEndpoint.Autopilot.resume(novelId: novelId))
            Logger.engine.info("自动驾驶已恢复: \(novelId)")
            await refreshStatus(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isControlling = false
    }

    // MARK: - 状态刷新

    /// 刷新自动驾驶状态
    /// - Parameter novelId: 小说 ID
    func refreshStatus(novelId: String) async {
        do {
            // 后端 /status 返回 dict，用 AnyCodable 接收后手动解析
            // 【修复】使用配置微秒日期格式的共享解码器，修复前用裸 JSONDecoder() 导致日期字段解码失败
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.Autopilot.status(novelId: novelId))
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                status = try? CangjieDecoder.shared.decode(AutopilotStatus.self, from: data)
            }
        } catch {
            Logger.engine.error("刷新自动驾驶状态失败: \(error.localizedDescription)")
        }
    }

    /// 刷新熔断器状态
    /// - Parameter novelId: 小说 ID
    func refreshCircuitBreaker(novelId: String) async {
        do {
            // 【修复】使用配置微秒日期格式的共享解码器
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.Autopilot.circuitBreaker(novelId: novelId))
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                circuitBreaker = try? CangjieDecoder.shared.decode(CircuitBreakerStatus.self, from: data)
            }
        } catch {
            Logger.engine.error("刷新熔断器状态失败: \(error.localizedDescription)")
        }
    }

    /// 重置熔断器
    /// - Parameter novelId: 小说 ID
    func resetCircuitBreaker(novelId: String) async {
        do {
            let _: AnyCodable = try await apiClient.request(APIEndpoint.Autopilot.resetCircuitBreaker(novelId: novelId))
            await refreshCircuitBreaker(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - SSE 订阅

    /// 启动 SSE 流（日志流 + 章节生成流）
    /// - Parameter novelId: 小说 ID
    func startSSEStreams(novelId: String) {
        // 日志流
        sseRegistry.startAutopilotStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleLogEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        )

        // 章节生成流
        sseRegistry.startChapterStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleChapterEvent(event)
                }
            },
            onError: nil
        )

        sseConnected = true

        // 启动状态轮询（SSE 是事件推送，但状态需要定期刷新）
        startStatusPolling(novelId: novelId)
    }

    /// 停止 SSE 流
    /// - Parameter novelId: 小说 ID
    func stopSSEStreams(novelId: String) {
        sseRegistry.cancelStream(type: .autopilotStream, novelId: novelId)
        sseRegistry.cancelStream(type: .chapterStream, novelId: novelId)
        sseConnected = false
        stopStatusPolling()
    }

    /// 启动状态轮询
    private func startStatusPolling(novelId: String) {
        stopStatusPolling()
        statusPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 秒
                if Task.isCancelled { break }
                await self.refreshStatus(novelId: novelId)
            }
        }
    }

    /// 停止状态轮询
    private func stopStatusPolling() {
        statusPollingTask?.cancel()
        statusPollingTask = nil
    }

    // MARK: - 事件处理

    /// 处理日志事件
    private func handleLogEvent(_ event: SSEEvent) {
        guard let logEvent = try? event.decode(LogStreamEvent.self) else { return }
        logs.append(logEvent)
        // 保留最近 200 条
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
    }

    /// 处理章节生成事件（config.ts:382-423 dispatchSseEvent）
    ///
    /// chapter-stream 是 data-only 格式（无 event: 行），事件类型在 JSON data.type 字段中。
    /// 9 类事件：connected/outline_planning/beats_planned/chapter_start/chapter_chunk/
    /// chapter_content/autopilot_stopped/paused_for_review/heartbeat
    private func handleChapterEvent(_ event: SSEEvent) {
        // chapter-stream 是 data-only 格式，用 typeFromData 获取事件类型（config.ts:382）
        guard let eventType = event.typeFromData else { return }

        // 解析事件 data 为字典，取 message/timestamp/metadata 字段
        guard let dict = event.decodeAsDictionary() else { return }

        let message = dict["message"] as? String ?? ""
        let _ = dict["timestamp"] as? String ?? ""  // timestamp 暂不使用

        // 解析 metadata（config.ts:316-325）
        let metadataDict = dict["metadata"] as? [String: Any] ?? [:]
        let chapterNumber = metadataDict["chapter_number"] as? Int
        let chunk = metadataDict["chunk"] as? String
        let beatIndex = metadataDict["beat_index"] as? Int
        let content = metadataDict["content"] as? String
        let wordCount = metadataDict["word_count"] as? Int
        let beats = metadataDict["beats"] as? [Any]
        let outlinePlanMode = metadataDict["outline_plan_mode"] as? String

        switch eventType {
        case ChapterStreamEvent.typeConnected:
            // connected（config.ts:376）：流建立成功
            Logger.engine.info("chapter-stream 已连接")
            onConnected?()

        case ChapterStreamEvent.typeOutlinePlanning:
            // outline_planning（config.ts:383-384）：metadata.chapter_number != null 时触发
            if let cn = chapterNumber {
                Logger.engine.info("chapter-stream 大纲规划中: 第\(cn)章")
                onOutlinePlanning?(cn, message)
            }

        case ChapterStreamEvent.typeBeatsPlanned:
            // beats_planned（config.ts:385-391）：metadata.chapter_number != null 时触发
            if let cn = chapterNumber {
                let beatsAnyCodable = (beats ?? []).map { AnyCodable($0) }
                Logger.engine.info("chapter-stream 节拍已规划: 第\(cn)章, \(beatsAnyCodable.count)个节拍")
                onBeatsPlanned?(cn, beatsAnyCodable, outlinePlanMode ?? "")
            }

        case ChapterStreamEvent.typeChapterStart:
            // chapter_start（config.ts:392-393）：metadata.chapter_number 存在时触发
            if let cn = chapterNumber {
                Logger.engine.info("chapter-stream 章节开始: 第\(cn)章")
                onChapterStart?(cn)
            }

        case ChapterStreamEvent.typeChapterChunk:
            // chapter_chunk（config.ts:394-408）
            // content 非空 → isSnapshot=true 传 content；否则 chunk → isSnapshot=false 传 chunk
            if let content = content, !content.isEmpty {
                onChapterChunk?(nil, content, beatIndex ?? 0, true)
            } else if let chunk = chunk {
                onChapterChunk?(chunk, nil, beatIndex ?? 0, false)
            }

        case ChapterStreamEvent.typeChapterContent:
            // chapter_content（config.ts:409-415）：完整章节内容快照
            if let cn = chapterNumber {
                onChapterContent?(cn, content ?? "", wordCount ?? 0, beatIndex ?? 0)
                // 章节完成时刷新状态和章节列表
                if let novelId = novelStore?.currentNovel?.id {
                    Task {
                        await self.refreshStatus(novelId: novelId)
                        await self.novelStore?.loadChapters(novelId)
                    }
                }
            }

        case ChapterStreamEvent.typeAutopilotStopped:
            // autopilot_stopped（config.ts:416-418）：设置 streamTerminal="stopped"
            Logger.engine.info("chapter-stream 自动驾驶已停止: \(message)")
            chapterStreamTerminal = "stopped"
            onAutopilotStopped?(message)
            // 刷新状态和章节列表
            if let novelId = novelStore?.currentNovel?.id {
                Task {
                    await self.refreshStatus(novelId: novelId)
                    await self.novelStore?.loadChapters(novelId)
                }
            }

        case ChapterStreamEvent.typePausedForReview:
            // paused_for_review（config.ts:419-421）：设置 streamTerminal="review"
            // 应尽快拉 /status 同步 needs_review
            Logger.engine.info("chapter-stream 暂停待审阅")
            chapterStreamTerminal = "review"
            onPausedForReview?()
            // 拉取最新状态同步 needs_review
            if let novelId = novelStore?.currentNovel?.id {
                Task { await self.refreshStatus(novelId: novelId) }
            }

        case ChapterStreamEvent.typeHeartbeat:
            // heartbeat（config.ts:313）：Q5决策——忽略，不触发回调
            break

        default:
            break
        }

        // 保留最近 100 条原始事件（用于调试）
        if let chapterEvent = try? event.decode(ChapterStreamEvent.self) {
            chapterEvents.append(chapterEvent)
            if chapterEvents.count > 100 {
                chapterEvents.removeFirst(chapterEvents.count - 100)
            }
        }
    }

    // MARK: - chapter-stream 回调入口（config.ts:329-354）

    /// 流连接成功回调（config.ts:349 onConnected）
    var onConnected: (() -> Void)?

    /// 大纲规划回调（config.ts:331 onOutlinePlanning）
    var onOutlinePlanning: ((Int, String) -> Void)?

    /// 节拍规划回调（config.ts:332-336 onBeatsPlanned）
    var onBeatsPlanned: ((Int, [AnyCodable], String) -> Void)?

    /// 章节开始回调（config.ts:337 onChapterStart）
    var onChapterStart: ((Int) -> Void)?

    /// 章节流式增量回调（config.ts:338-343 onChapterChunk）
    var onChapterChunk: ((String?, String?, Int, Bool) -> Void)?

    /// 章节完整内容回调（config.ts:344 onChapterContent）
    var onChapterContent: ((Int, String, Int, Int) -> Void)?

    /// 自动驾驶停止回调（config.ts:345 onAutopilotStopped）
    var onAutopilotStopped: ((String) -> Void)?

    /// 暂停待审阅回调（config.ts:347 onPausedForReview）
    var onPausedForReview: (() -> Void)?

    /// 流结束回调（config.ts:353 onStreamEnd）
    var onStreamEnd: ((String) -> Void)?

    /// 流结束原因（config.ts:359 streamTerminal: 'stopped' | 'review' | 'idle' | nil）
    private var chapterStreamTerminal: String?

    // MARK: - 便捷属性

    /// 是否运行中
    var isRunning: Bool {
        return status?.autopilotStatus == "running"
    }

    /// 是否需要审阅
    var needsReview: Bool {
        return status?.needsReview ?? false
    }

    /// 当前进度百分比
    var progressPercentage: Double {
        return status?.progressPct ?? 0.0
    }

    /// 当前章节号
    var currentChapterNumber: Int? {
        return status?.currentChapterNumber
    }
}
