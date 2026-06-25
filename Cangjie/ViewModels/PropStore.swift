//
//  PropStore.swift
//  Cangjie
//
//  道具管理 CRUD + 事件流。
//

import SwiftUI
import Foundation

/// 道具 Store
@MainActor
final class PropStore: ObservableObject {

    @Published var props: [PropDTO] = []
    @Published var currentPropEvents: [PropEventDTO] = []
    @Published var chapterMentions: [ChapterEntityMention] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载道具列表
    func loadProps(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            props = try await apiClient.request(APIEndpoint.Props.list(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 创建道具
    func createProp(novelId: String, request: CreatePropRequest) async {
        do {
            let prop: PropDTO = try await apiClient.request(
                APIEndpoint.Props.create(novelId: novelId),
                body: request
            )
            props.append(prop)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 更新道具
    func updateProp(novelId: String, propId: String, request: PatchPropRequest) async {
        do {
            let updated: PropDTO = try await apiClient.request(
                APIEndpoint.Props.update(novelId: novelId, propId: propId),
                body: request
            )
            if let index = props.firstIndex(where: { $0.id == propId }) {
                props[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除道具
    func deleteProp(novelId: String, propId: String) async {
        do {
            try await apiClient.send(APIEndpoint.Props.delete(novelId: novelId, propId: propId))
            props.removeAll { $0.id == propId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载道具事件
    func loadPropEvents(novelId: String, propId: String) async {
        do {
            currentPropEvents = try await apiClient.request(
                APIEndpoint.Props.events(novelId: novelId, propId: propId)
            )
        } catch {
            currentPropEvents = []
        }
    }

    /// 创建道具事件
    func createPropEvent(novelId: String, propId: String, request: CreatePropEventRequest) async {
        do {
            let event: PropEventDTO = try await apiClient.request(
                APIEndpoint.Props.createEvent(novelId: novelId, propId: propId),
                body: request
            )
            currentPropEvents.append(event)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 实体索引 — ManuscriptPropsPanel.vue:250-281

    /// 加载章节实体提及 — manuscript.ts:31-34
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func loadChapterMentions(novelId: String, chapterNumber: Int) async {
        do {
            let response: ChapterMentionsResponse = try await apiClient.request(
                APIEndpoint.Manuscript.chapterMentions(novelId: novelId, chapterNumber: chapterNumber)
            )
            chapterMentions = response.mentions
        } catch {
            chapterMentions = []
        }
    }

    /// 重建章节实体索引 — manuscript.ts:36-46
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func reindexChapterMentions(novelId: String, chapterNumber: Int) async {
        do {
            let response: ReindexMentionsResponse = try await apiClient.request(
                APIEndpoint.Manuscript.reindexMentions(novelId: novelId, chapterNumber: chapterNumber)
            )
            chapterMentions = response.mentions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 切换关键道具标记 — ManuscriptPropsPanel.vue:374-394 togglePropKey
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - propId: 道具 ID
    ///   - currentKeyContext: 当前 key_context 值
    func togglePropKey(novelId: String, propId: String, currentKeyContext: Bool) async {
        let newKey = !currentKeyContext
        let request = PatchPropRequest(
            name: nil, description: nil, aliases: nil,
            propCategory: nil, lifecycleState: nil,
            holderCharacterId: nil, introducedChapter: nil,
            attributes: ["key_context": AnyCodable(newKey)]
        )
        await updateProp(novelId: novelId, propId: propId, request: request)
    }
}
