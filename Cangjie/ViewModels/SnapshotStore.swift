//
//  SnapshotStore.swift
//  Cangjie
//
//  检查点/快照管理 + 回滚。
//

import SwiftUI
import Foundation

/// 快照 Store
@MainActor
final class SnapshotStore: ObservableObject {

    @Published var snapshots: [UnifiedSnapshot] = []
    @Published var checkpoints: [CheckpointDTO] = []
    @Published var headCheckpointId: String?
    @Published var storyPhase: StoryPhase?
    @Published var characterPsyches: [CharacterPsyche] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载快照列表
    func loadSnapshots(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: UnifiedSnapshotListResponse = try await apiClient.request(
                APIEndpoint.Snapshots.list(novelId: novelId)
            )
            snapshots = response.snapshots
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 创建快照
    func createSnapshot(novelId: String, request: CreateSnapshotRequest) async {
        do {
            let _: CreateSnapshotResponse = try await apiClient.request(
                APIEndpoint.Snapshots.create(novelId: novelId),
                body: request
            )
            await loadSnapshots(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除快照
    func deleteSnapshot(novelId: String, snapshotId: String) async {
        do {
            try await apiClient.send(APIEndpoint.Snapshots.delete(novelId: novelId, snapshotId: snapshotId))
            snapshots.removeAll { $0.id == snapshotId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载检查点列表
    func loadCheckpoints(novelId: String) async {
        do {
            let response: CheckpointListResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.list(novelId: novelId)
            )
            checkpoints = response.checkpoints
            headCheckpointId = response.headId
        } catch {
            Logger.data.error("加载检查点列表失败: \(error.localizedDescription)")
        }
    }

    /// 创建检查点
    func createCheckpoint(novelId: String, reason: String, chapterNumber: Int? = nil) async {
        let request = CreateCheckpointRequest(reason: reason, chapterNumber: chapterNumber)

        do {
            let _: CreateCheckpointResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.create(novelId: novelId),
                body: request
            )
            await loadCheckpoints(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 回滚检查点
    func rollbackCheckpoint(novelId: String, checkpointId: String) async {
        do {
            let _: RollbackResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.rollback(novelId: novelId, checkpointId: checkpointId)
            )
            await loadCheckpoints(novelId: novelId)
            await loadSnapshots(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载故事阶段
    func loadStoryPhase(novelId: String) async {
        do {
            storyPhase = try await apiClient.request(
                APIEndpoint.Checkpoints.storyPhase(novelId: novelId)
            )
        } catch {
            Logger.data.error("加载故事阶段失败: \(error.localizedDescription)")
        }
    }

    /// 加载角色心理
    func loadCharacterPsyches(novelId: String) async {
        do {
            let response: CharacterPsycheListResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.characterPsyches(novelId: novelId)
            )
            characterPsyches = response.characters
        } catch {
            Logger.data.error("加载角色心理失败: \(error.localizedDescription)")
        }
    }
}
