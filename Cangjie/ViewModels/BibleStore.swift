//
//  BibleStore.swift
//  Cangjie
//
//  Bible 设定集 CRUD + 流式生成。
//

import SwiftUI
import Foundation

/// Bible Store
@MainActor
final class BibleStore: ObservableObject {

    // MARK: - 状态

    @Published var bible: BibleDTO?
    @Published var generationStatus: BibleGenerationStatus?
    @Published var generationLog: [String] = []
    @Published var isLoading: Bool = false
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
    }

    // MARK: - Bible CRUD

    /// 加载 Bible
    /// - Parameter novelId: 小说 ID
    func loadBible(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            bible = try await apiClient.request(APIEndpoint.Bible.get(novelId: novelId))
        } catch let error as APIError {
            if case .notFound = error {
                bible = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 更新 Bible
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - bible: 更新后的 Bible
    func updateBible(novelId: String, bible: BibleDTO) async {
        do {
            let updated: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.update(novelId: novelId),
                body: AnyCodable(bible.dictionaryValue ?? [:])
            )
            self.bible = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 角色/设定/地点管理

    /// 添加角色
    func addCharacter(novelId: String, request: AddCharacterRequest) async {
        do {
            let updated: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.addCharacter(novelId: novelId),
                body: request
            )
            bible = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 添加世界设定
    func addWorldSetting(novelId: String, request: AddWorldSettingRequest) async {
        do {
            let updated: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.addWorldSetting(novelId: novelId),
                body: request
            )
            bible = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 添加地点
    func addLocation(novelId: String, request: AddLocationRequest) async {
        do {
            let updated: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.addLocation(novelId: novelId),
                body: request
            )
            bible = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 流式生成

    /// 启动 Bible 流式生成
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - stage: 生成阶段
    func startGeneration(novelId: String, stage: String = "full") async {
        isGenerating = true
        errorMessage = nil
        generationLog.removeAll()

        sseRegistry.startBibleGenerateStream(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleSSEEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                    self?.isGenerating = false
                }
            }
        )
    }

    /// 处理 SSE 事件
    private func handleSSEEvent(_ event: SSEEvent) {
        if let dict = event.decodeAsDictionary() {
            if let message = dict["message"] as? String {
                generationLog.append(message)
            }
            if let text = dict["text"] as? String {
                generationLog.append(text)
            }
            if let done = dict["done"] as? Bool, done {
                isGenerating = false
                // 重新加载 Bible
                if let novelId = bible?.novelId {
                    Task { await self.loadBible(novelId: novelId) }
                }
            }
            if let error = dict["error"] as? String {
                errorMessage = error
                isGenerating = false
            }
        }
    }

    /// 加载生成状态
    /// - Parameter novelId: 小说 ID
    func loadGenerationStatus(novelId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.Bible.status(novelId: novelId))
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                generationStatus = try? JSONDecoder().decode(BibleGenerationStatus.self, from: data)
            }
        } catch {
            // 状态不存在时忽略
        }
    }

    // MARK: - 便捷属性

    /// 角色列表
    var characters: [CharacterDTO] {
        return bible?.characters ?? []
    }

    /// 世界设定列表
    var worldSettings: [WorldSettingDTO] {
        return bible?.worldSettings ?? []
    }

    /// 地点列表
    var locations: [LocationDTO] {
        return bible?.locations ?? []
    }

    /// 时间线笔记
    var timelineNotes: [TimelineNoteDTO] {
        return bible?.timelineNotes ?? []
    }
}
