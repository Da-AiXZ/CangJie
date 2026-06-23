//
//  EvolutionStore.swift
//  Cangjie
//
//  故事演化记录。
//

import SwiftUI
import Foundation

/// 演化 Store
@MainActor
final class EvolutionStore: ObservableObject {

    @Published var snapshots: [EvolutionSnapshot] = []
    @Published var counts: [String: Int] = [:]
    @Published var gateReport: EvolutionGateReport?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载快照列表
    func loadSnapshots(novelId: String, branchId: String = "main") async {
        isLoading = true
        errorMessage = nil

        do {
            let response: EvolutionSnapshotListResponse = try await apiClient.request(
                APIEndpoint.Evolution.snapshots(novelId: novelId)
            )
            snapshots = response.snapshots
            counts = response.counts
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 获取指定章节快照
    func loadSnapshot(novelId: String, chapterNumber: Int, branchId: String = "main") async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Evolution.snapshotAtChapter(novelId: novelId, chapterNumber: chapterNumber)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let snapshot = try? CangjieDecoder.shared.decode(EvolutionSnapshot.self, from: data)
                if let snapshot = snapshot {
                    // 替换或追加
                    if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
                        snapshots[index] = snapshot
                    } else {
                        snapshots.append(snapshot)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 闸门检查
    func checkGate(novelId: String, request: EvolutionGateRequest) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Evolution.gate(novelId: novelId),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                gateReport = try? CangjieDecoder.shared.decode(EvolutionGateReport.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 应用覆盖
    func applyOverrides(novelId: String, request: EvolutionOverrideRequest) async {
        do {
            try await apiClient.send(
                APIEndpoint.Evolution.snapshotOverrides(novelId: novelId, chapterNumber: 0),
                body: request
            )
            await loadSnapshots(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 回放
    func replay(novelId: String, chapterNumber: Int, branchId: String = "main") async {
        let request = EvolutionReplayRequest(branchId: branchId)

        do {
            try await apiClient.send(
                APIEndpoint.Evolution.replay(novelId: novelId, chapterNumber: chapterNumber),
                body: request
            )
            await loadSnapshots(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
