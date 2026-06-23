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
}
