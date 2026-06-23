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

    /// 处理章节生成事件
    private func handleChapterEvent(_ event: SSEEvent) {
        guard let chapterEvent = try? event.decode(ChapterStreamEvent.self) else { return }
        chapterEvents.append(chapterEvent)

        // 保留最近 100 条
        if chapterEvents.count > 100 {
            chapterEvents.removeFirst(chapterEvents.count - 100)
        }

        // 【修复】章节完成时刷新状态和章节列表（修复前为空操作死代码）
        if chapterEvent.done == true {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // 通过日志事件中的 novelId 或外部传入的 novelId 刷新状态
                // 由于 SSE 事件不含 novelId，使用 novelStore 的 currentNovelId
                if let novelId = self.novelStore?.currentNovel?.id {
                    await self.refreshStatus(novelId: novelId)
                    await self.novelStore?.loadChapters(novelId)
                }
            }
        }

        // 章节生成出错时显示错误
        if let error = chapterEvent.error, !error.isEmpty {
            errorMessage = error
        }
    }

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
