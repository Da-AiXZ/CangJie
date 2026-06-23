//
//  TraceStore.swift
//  Cangjie
//
//  AI Trace 溯源查询。
//

import SwiftUI
import Foundation

/// Trace Store
@MainActor
final class TraceStore: ObservableObject {

    @Published var traces: [TraceDTO] = []
    @Published var traceStats: TraceStats?
    @Published var aiTraces: [AiTraceSummary] = []
    @Published var timeline: AiTraceTimelineResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载引擎 Trace 列表
    /// - Parameter novelId: 小说 ID
    func loadTraces(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: TraceListResponse = try await apiClient.request(
                APIEndpoint.Trace.list(novelId: novelId)
            )
            traces = response.traces
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载 Trace 统计
    func loadStats(novelId: String) async {
        do {
            traceStats = try await apiClient.request(
                APIEndpoint.Trace.stats(novelId: novelId)
            )
        } catch {
            Logger.data.error("加载 Trace 统计失败: \(error.localizedDescription)")
        }
    }

    /// 加载 AI Trace 列表
    func loadAITraces(novelId: String) async {
        do {
            let response: AiTraceListResponse = try await apiClient.request(
                APIEndpoint.Trace.aiTraces(novelId: novelId)
            )
            aiTraces = response.traces
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载 AI Trace 时间线
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - traceId: Trace ID
    func loadTimeline(novelId: String, traceId: String) async {
        do {
            timeline = try await apiClient.request(
                APIEndpoint.Trace.timeline(novelId: novelId, traceId: traceId)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 便捷属性

    /// 当前时间线的 Span 列表
    var spans: [AiTraceSpan] {
        return timeline?.spans ?? []
    }

    /// 按 node_type 分组的 Trace 统计
    var tracesByNodeType: [String: Int] {
        return traceStats?.byNodeType ?? [:]
    }
}
