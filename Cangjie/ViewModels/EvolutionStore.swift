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

    /// 故事演化聚合模型 — StoryEvolutionPanel.vue:419-429 loadBundle
    @Published var evolutionBundle: StoryEvolutionReadModel?

    /// 治理状态 — StoryEvolutionPanel.vue:443-449 loadGovernanceState
    @Published var governanceState: GovernanceState?

    /// 世界线图 — StoryEvolutionPanel.vue:451-457 loadWorldlineGraph
    @Published var worldlineGraph: AnyCodable?

    /// 引导落点数据 — StoryEvolutionPanel.vue:459-473 loadSetupAnchors（P0-1修复）
    @Published var setupNovel: NovelDTO?
    @Published var setupBible: BibleDTO?
    @Published var setupPlotOutline: PlotOutlineDTO?
    @Published var setupAnchorsLoading: Bool = false

    /// 覆盖操作状态 — StoryEvolutionPanel.vue:479-495 updateCharacterStatus
    @Published var overrideLoading: Bool = false

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

    /// 应用覆盖 — evolution.ts:69-73 applyOverrides
    /// L-1修复：传入实际 chapterNumber，不硬编码0
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 实际章节号
    ///   - request: 覆盖请求（含 patches）
    func applyOverrides(novelId: String, chapterNumber: Int, request: EvolutionOverrideRequest) async {
        do {
            try await apiClient.send(
                APIEndpoint.Evolution.snapshotOverrides(novelId: novelId, chapterNumber: chapterNumber),
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

    // MARK: - 多路加载 — StoryEvolutionPanel.vue:419-473

    /// 加载故事演化聚合 — StoryEvolutionPanel.vue:419-429 loadBundle
    /// - Parameter novelId: 小说 ID
    func loadBundle(novelId: String) async {
        do {
            evolutionBundle = try await apiClient.request(
                APIEndpoint.NarrativeEngine.storyEvolution(novelId: novelId)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载治理状态 — StoryEvolutionPanel.vue:443-449 loadGovernanceState
    /// - Parameter novelId: 小说 ID
    func loadGovernanceState(novelId: String) async {
        do {
            governanceState = try await apiClient.request(
                APIEndpoint.Governance.state(novelId: novelId)
            )
        } catch {
            // 静默失败
        }
    }

    /// 加载世界线图 — StoryEvolutionPanel.vue:451-457 loadWorldlineGraph
    /// - Parameter novelId: 小说 ID
    func loadWorldlineGraph(novelId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Worldline.graph(novelId: novelId)
            )
            worldlineGraph = raw
        } catch {
            // 静默失败
        }
    }

    /// 加载引导落点 — StoryEvolutionPanel.vue:459-473 loadSetupAnchors（P0-1修复）
    /// 3路 Promise.allSettled: Novel详情 + Bible + PlotOutline
    /// - Parameter novelId: 小说 ID
    func loadSetupAnchors(novelId: String) async {
        setupAnchorsLoading = true
        // Promise.allSettled 等价：各路独立 try-catch，失败不影响其他路
        async let novelTask: NovelDTO? = {
            do { return try await apiClient.request(APIEndpoint.Novels.get(novelId: novelId)) }
            catch { return nil }
        }()
        async let bibleTask: BibleDTO? = {
            do { return try await apiClient.request(APIEndpoint.Bible.get(novelId: novelId)) }
            catch { return nil }
        }()
        async let outlineTask: GeneratePlotOutlineResponse? = {
            do { return try await apiClient.request(APIEndpoint.Workflow.getPlotOutline(novelId: novelId)) }
            catch { return nil }
        }()

        let (novel, bible, outlineResp) = await (novelTask, bibleTask, outlineTask)
        setupNovel = novel
        setupBible = bible
        setupPlotOutline = outlineResp?.plotOutline
        setupAnchorsLoading = false
    }

    /// 加载全部数据（5路并行）— StoryEvolutionPanel.vue:746-758
    /// - Parameter novelId: 小说 ID
    func loadAll(novelId: String) async {
        async let bundle: Void = loadBundle(novelId: novelId)
        async let snaps: Void = loadSnapshots(novelId: novelId)
        async let gov: Void = loadGovernanceState(novelId: novelId)
        async let world: Void = loadWorldlineGraph(novelId: novelId)
        async let anchors: Void = loadSetupAnchors(novelId: novelId)
        _ = await (bundle, snaps, gov, world, anchors)
    }
}
