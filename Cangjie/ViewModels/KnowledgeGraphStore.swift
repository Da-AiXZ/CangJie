//
//  KnowledgeGraphStore.swift
//  Cangjie
//
//  三元组查询 + 统计 + 推断证据。
//

import SwiftUI
import Foundation

/// 知识图谱 Store
///
/// 对齐原版 api/knowledgeGraph.ts:57-153 `knowledgeGraphApi` 的全部操作。
/// 已接线：loadTriples / loadStatistics / search / confirmTriple / deleteTriple / index
/// 本次补：inferNovel / loadInferenceEvidence / revokeChapterInference / revokeInferredTriple / starTriple
@MainActor
final class KnowledgeGraphStore: ObservableObject {

    @Published var triples: [KnowledgeTriple] = []
    @Published var statistics: KnowledgeGraphStatistics?
    @Published var searchResults: [KnowledgeSearchHit] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// 章节推断证据，对齐原版 knowledgeGraph.ts:60-68 getChapterInferenceEvidence
    @Published var inferenceEvidence: ChapterInferenceEvidenceData?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载三元组
    /// - Parameter novelId: 小说 ID
    func loadTriples(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 后端返回可能是数组或字典
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.triples(novelId: novelId)
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                triples = try CangjieDecoder.shared.decode([KnowledgeTriple].self, from: data)
            } else if let dict = raw.dictionaryValue, let items = dict["triples"] {
                let data = try JSONSerialization.data(withJSONObject: items)
                triples = try CangjieDecoder.shared.decode([KnowledgeTriple].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载统计
    func loadStatistics(novelId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.statistics(novelId: novelId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                statistics = try? CangjieDecoder.shared.decode(KnowledgeGraphStatistics.self, from: data)
            }
        } catch {
            Logger.data.error("加载 KG 统计失败: \(error.localizedDescription)")
        }
    }

    /// 搜索
    func search(novelId: String, query: String, topK: Int? = nil) async {
        let request = KnowledgeGraphSearchRequest(query: query, topK: topK)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.search(novelId: novelId),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(KnowledgeSearchResponse.self, from: data)
                searchResults = response?.hits ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 确认三元组
    func confirmTriple(tripleId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.confirmTriple(tripleId: tripleId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除三元组
    func deleteTriple(tripleId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.deleteTriple(tripleId: tripleId))
            triples.removeAll { $0.id == tripleId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 索引
    func index(novelId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.index(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 本次新增写操作（对齐原版 knowledgeGraph.ts）

    /// 全书推断 — POST /knowledge-graph/novels/{id}/infer
    ///
    /// 对齐原版 knowledgeGraph.ts:92-99 `inferNovel(novelId)`。
    /// 请求体为空 `{}`，返回 `{ success: boolean; data: Record<string, unknown> }`。
    /// 推断完成后刷新三元组列表。
    func inferNovel(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 原版 apiClient.post(url, {}, config) — 空请求体
            let body = EmptyBody()
            let _: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.infer(novelId: novelId),
                body: body
            )
            // 推断后刷新三元组
            await loadTriples(novelId: novelId)
            await loadStatistics(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载章节推断证据 — GET /knowledge-graph/novels/{id}/chapters/by-number/{chapter}/inference-evidence
    ///
    /// 对齐原版 knowledgeGraph.ts:60-68 `getChapterInferenceEvidence(novelId, chapterNumber)`。
    /// 返回 `{ success: boolean; data: ChapterInferenceEvidenceData }`。
    func loadInferenceEvidence(novelId: String, chapterNumber: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.inferenceEvidence(novelId: novelId, chapterNumber: chapterNumber)
            )
            // 后端返回 { success, data: ChapterInferenceEvidenceData }
            if let dict = raw.dictionaryValue, let dataValue = dict["data"] {
                let data = try JSONSerialization.data(withJSONObject: dataValue)
                inferenceEvidence = try CangjieDecoder.shared.decode(ChapterInferenceEvidenceData.self, from: data)
            } else {
                // 直接解码为 ChapterInferenceEvidenceData
                let data = try JSONSerialization.data(withJSONObject: raw.value)
                inferenceEvidence = try CangjieDecoder.shared.decode(ChapterInferenceEvidenceData.self, from: data)
            }
        } catch {
            Logger.data.error("加载推断证据失败: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 撤销章节推断 — DELETE /knowledge-graph/novels/{id}/chapters/by-number/{chapter}/inference
    ///
    /// 对齐原版 knowledgeGraph.ts:70-78 `revokeChapterInference(novelId, chapterNumber)`。
    /// 返回 `{ success, data: { removed_provenance_triples, deleted_inferred_facts } }`。
    /// 撤销后刷新三元组列表。
    func revokeChapterInference(novelId: String, chapterNumber: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: RevokeInferenceResponse = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.deleteChapterInference(novelId: novelId, chapterNumber: chapterNumber)
            )
            Logger.data.debug("撤销推断成功: 移除 \(response.data.removedProvenanceTriples) 条溯源, 删除 \(response.data.deletedInferredFacts) 条推断事实")
            // 撤销后刷新
            await loadTriples(novelId: novelId)
            await loadStatistics(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 撤销单条推断三元组 — DELETE /knowledge-graph/novels/{id}/inferred-triples/{tripleId}
    ///
    /// 对齐原版 knowledgeGraph.ts:80-88 `revokeInferredTriple(novelId, tripleId)`。
    /// 返回 `{ success: boolean; message: string }`。
    /// 撤销后从本地 triples 列表中移除。
    func revokeInferredTriple(novelId: String, tripleId: String) async {
        do {
            try await apiClient.send(
                APIEndpoint.KnowledgeGraph.deleteInferredTriple(novelId: novelId, tripleId: tripleId)
            )
            triples.removeAll { $0.id == tripleId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 标星三元组 — PATCH /knowledge-graph/novels/{id}/triples/{tripleId}/star
    ///
    /// 对齐原版 knowledgeGraph.ts:128-134 `starTriple(novelId, tripleId, starred)`。
    /// 请求体 `{ starred: boolean }`，返回 `{ success, triple_id, starred }`。
    /// 标星后更新本地三元组的 isStarred 状态。
    func starTriple(novelId: String, tripleId: String, starred: Bool) async {
        do {
            let request = StarTripleRequest(starred: starred)
            let response: StarTripleResponse = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.starTriple(novelId: novelId, tripleId: tripleId),
                body: request
            )
            // 更新本地三元组的标星状态
            if response.success {
                if let idx = triples.firstIndex(where: { $0.id == tripleId }) {
                    // KnowledgeTriple 是 let，需要重建
                    let existing = triples[idx]
                    triples[idx] = KnowledgeTriple(
                        id: existing.id,
                        subject: existing.subject,
                        predicate: existing.predicate,
                        object: existing.object,
                        chapterId: existing.chapterId,
                        note: existing.note,
                        entityType: existing.entityType,
                        importance: existing.importance,
                        locationType: existing.locationType,
                        description: existing.description,
                        firstAppearance: existing.firstAppearance,
                        relatedChapters: existing.relatedChapters,
                        tags: existing.tags,
                        attributes: existing.attributes,
                        confidence: existing.confidence,
                        sourceType: existing.sourceType,
                        subjectEntityId: existing.subjectEntityId,
                        objectEntityId: existing.objectEntityId,
                        provenance: existing.provenance,
                        isStarred: starred
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 空请求体
// EmptyBody 声明已移至 OnboardingWizardView.swift（模块级），此处直接引用（CI#29 修复：消除重复声明）
