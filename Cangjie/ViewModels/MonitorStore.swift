//
//  MonitorStore.swift
//  Cangjie
//
//  张力曲线/文风漂移/伏笔统计数据拉取。
//

import SwiftUI
import Foundation

/// 监控 Store
@MainActor
final class MonitorStore: ObservableObject {

    @Published var tensionCurve: TensionCurveResponse?
    @Published var voiceDrifts: [VoiceDrift] = []
    @Published var foreshadowStats: ForeshadowStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载全部监控数据
    /// - Parameter novelId: 小说 ID
    func loadAll(novelId: String) async {
        isLoading = true
        errorMessage = nil

        async let tension: TensionCurveResponse? = try? apiClient.request(
            APIEndpoint.Monitor.tensionCurve(novelId: novelId)
        )
        async let drifts: [VoiceDrift] = try? apiClient.request(
            APIEndpoint.Monitor.voiceDrift(novelId: novelId)
        )
        async let foreshadow: ForeshadowStats? = try? apiClient.request(
            APIEndpoint.Monitor.foreshadowStats(novelId: novelId)
        )

        self.tensionCurve = await tension
        self.voiceDrifts = await drifts
        self.foreshadowStats = await foreshadow

        isLoading = false
    }

    /// 仅加载张力曲线
    func loadTensionCurve(novelId: String) async {
        do {
            tensionCurve = try await apiClient.request(
                APIEndpoint.Monitor.tensionCurve(novelId: novelId)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 仅加载文风漂移
    func loadVoiceDrift(novelId: String) async {
        do {
            voiceDrifts = try await apiClient.request(
                APIEndpoint.Monitor.voiceDrift(novelId: novelId)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 仅加载伏笔统计
    func loadForeshadowStats(novelId: String) async {
        do {
            foreshadowStats = try await apiClient.request(
                APIEndpoint.Monitor.foreshadowStats(novelId: novelId)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 便捷属性

    /// 张力点列表
    var tensionPoints: [TensionPoint] {
        return tensionCurve?.points ?? []
    }

    /// 张力统计
    var tensionStats: TensionCurveStats? {
        return tensionCurve?.stats
    }
}
