//
//  ForeshadowStore.swift
//  Cangjie
//
//  伏笔手账 CRUD。
//

import SwiftUI
import Foundation

/// 伏笔 Store
@MainActor
final class ForeshadowStore: ObservableObject {

    @Published var entries: [ForeshadowEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载伏笔列表
    /// - Parameter novelId: 小说 ID
    func loadEntries(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            entries = try await apiClient.request(APIEndpoint.Foreshadow.list(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 创建伏笔
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - request: 创建请求
    func createEntry(novelId: String, request: CreateForeshadowRequest) async {
        do {
            let entry: ForeshadowEntry = try await apiClient.request(
                APIEndpoint.Foreshadow.create(novelId: novelId),
                body: request
            )
            entries.append(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 更新伏笔
    func updateEntry(novelId: String, entryId: String, request: UpdateForeshadowRequest) async {
        do {
            let updated: ForeshadowEntry = try await apiClient.request(
                APIEndpoint.Foreshadow.update(novelId: novelId, entryId: entryId),
                body: request
            )
            if let index = entries.firstIndex(where: { $0.id == entryId }) {
                entries[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除伏笔
    func deleteEntry(novelId: String, entryId: String) async {
        do {
            try await apiClient.send(APIEndpoint.Foreshadow.delete(novelId: novelId, entryId: entryId))
            entries.removeAll { $0.id == entryId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 标记伏笔已消耗
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - entryId: 条目 ID
    ///   - consumedAtChapter: 消耗章节号
    func markConsumed(novelId: String, entryId: String, consumedAtChapter: Int) async {
        let request = UpdateForeshadowRequest(
            chapter: nil, characterId: nil, question: nil,
            status: "consumed", consumedAtChapter: consumedAtChapter,
            suggestedResolveChapter: nil, resolveChapterWindow: nil,
            importance: nil, isPriorityForChapter: nil
        )
        await updateEntry(novelId: novelId, entryId: entryId, request: request)
    }

    // MARK: - 便捷属性

    /// 待处理伏笔
    var pendingEntries: [ForeshadowEntry] {
        return entries.filter { $0.status == "pending" }
    }

    /// 已消耗伏笔
    var consumedEntries: [ForeshadowEntry] {
        return entries.filter { $0.status == "consumed" }
    }
}
