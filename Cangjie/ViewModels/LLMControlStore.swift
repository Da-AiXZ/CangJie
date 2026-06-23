//
//  LLMControlStore.swift
//  Cangjie
//
//  LLM 端点 CRUD + 测试 + 拉取模型列表。
//

import SwiftUI
import Foundation

/// LLM 控制面板 Store
@MainActor
final class LLMControlStore: ObservableObject {

    // MARK: - 状态

    @Published var panelData: LLMControlPanelData?
    @Published var testResult: LLMTestResult?
    @Published var modelList: [LLMModelInfo] = []
    @Published var isLoading: Bool = false
    @Published var isTesting: Bool = false
    @Published var isFetchingModels: Bool = false
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 保存端点（新建/编辑）

    /// 保存端点（新建或编辑后整体提交配置）
    /// - Parameter profile: 要保存的端点
    /// - Returns: 是否保存成功
    @discardableResult
    func saveProfile(_ profile: LLMProfile) async -> Bool {
        guard var config = panelData?.config else {
            errorMessage = "配置数据未加载"
            return false
        }

        // 如果是新建（id 为空），生成 id；否则替换已有项
        var target = profile
        if target.id.isEmpty {
            target.id = "profile-\(UUID().uuidString.prefix(8))"
        }

        if let idx = config.profiles.firstIndex(where: { $0.id == target.id }) {
            config.profiles[idx] = target
        } else {
            config.profiles.append(target)
        }

        // 如果是第一个端点，自动设为激活
        if config.activeProfileId == nil || config.activeProfileId?.isEmpty == true {
            config.activeProfileId = target.id
        }

        await updateConfig(config)
        return errorMessage == nil
    }

    // MARK: - 设为默认端点

    /// 将指定端点设为激活
    func activateProfile(profileId: String) async {
        guard var config = panelData?.config else { return }
        config.activeProfileId = profileId
        await updateConfig(config)
    }

    // MARK: - 删除端点

    /// 删除端点
    func deleteProfile(profileId: String) async {
        guard var config = panelData?.config else { return }
        config.profiles.removeAll { $0.id == profileId }
        if config.activeProfileId == profileId {
            config.activeProfileId = config.profiles.first?.id
        }
        await updateConfig(config)
    }

    // MARK: - 加载面板数据

    /// 加载 LLM 控制面板数据
    func loadPanelData() async {
        isLoading = true
        errorMessage = nil

        do {
            panelData = try await apiClient.request(APIEndpoint.LLMControl.panel)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 更新配置

    /// 更新 LLM 配置
    /// - Parameter config: 新配置
    func updateConfig(_ config: LLMControlConfig) async {
        do {
            let updated: LLMControlPanelData = try await apiClient.request(
                APIEndpoint.LLMControl.update,
                body: AnyCodable(config.dictionaryValue ?? [:])
            )
            panelData = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 测试连通性

    /// 测试 LLM 端点连通性
    ///
    /// 后端 POST /test 期望完整的 LLMProfile 作为请求体（而非 profile_id）。
    /// 此方法根据 profileId 从已加载的配置中查找对应 profile 并发送。
    /// - Parameter profileId: 端点 ID（可选，默认测试当前激活端点）
    func testConnection(profileId: String? = nil) async {
        isTesting = true
        errorMessage = nil

        // 查找要测试的 profile
        let targetProfile: LLMProfile?
        if let pid = profileId {
            targetProfile = panelData?.config.profiles.first { $0.id == pid }
        } else {
            targetProfile = activeProfile
        }

        guard let profile = targetProfile else {
            errorMessage = "未找到端点配置"
            testResult = LLMTestResult(ok: false, providerLabel: "", model: "", latencyMs: 0, preview: "", error: "未找到端点配置")
            isTesting = false
            return
        }

        do {
            // 后端 POST /test 期望完整 LLMProfile 作为请求体
            testResult = try await apiClient.request(APIEndpoint.LLMControl.test, body: profile)
        } catch {
            errorMessage = error.localizedDescription
            testResult = LLMTestResult(ok: false, providerLabel: profile.name, model: profile.model, latencyMs: 0, preview: "", error: error.localizedDescription)
        }

        isTesting = false
    }

    /// 测试连通性（直接传入 LLMProfile，用于新建未保存的端点测试）
    ///
    /// 后端 POST /test 期望完整的 LLMProfile 作为请求体。
    /// - Parameter profile: 要测试的端点配置
    func testConnectionWithProfile(_ profile: LLMProfile) async {
        isTesting = true
        errorMessage = nil

        do {
            testResult = try await apiClient.request(APIEndpoint.LLMControl.test, body: profile)
        } catch {
            errorMessage = error.localizedDescription
            testResult = LLMTestResult(ok: false, providerLabel: profile.name, model: profile.model, latencyMs: 0, preview: "", error: error.localizedDescription)
        }

        isTesting = false
    }

    // MARK: - 拉取模型列表

    /// 拉取模型列表
    /// - Parameters:
    ///   - protocol: 协议
    ///   - baseUrl: Base URL
    ///   - apiKey: API Key
    func fetchModels(protocol proto: String, baseUrl: String, apiKey: String) async {
        isFetchingModels = true
        errorMessage = nil

        let request = ModelListRequest(protocol: proto, baseUrl: baseUrl, apiKey: apiKey, timeoutMs: nil)

        do {
            let response: LLMModelListResponse = try await apiClient.request(
                APIEndpoint.LLMControl.models,
                body: request
            )
            modelList = response.items
        } catch {
            errorMessage = error.localizedDescription
            modelList = []
        }

        isFetchingModels = false
    }

    // MARK: - 便捷属性

    /// 当前激活的端点
    var activeProfile: LLMProfile? {
        guard let config = panelData?.config,
              let activeId = config.activeProfileId else { return nil }
        return config.profiles.first { $0.id == activeId }
    }

    /// 所有端点列表
    var profiles: [LLMProfile] {
        return panelData?.config.profiles ?? []
    }

    /// 预设列表
    var presets: [LLMPreset] {
        return panelData?.presets ?? []
    }

    /// 是否使用 Mock
    var isUsingMock: Bool {
        return panelData?.runtime.usingMock ?? false
    }
}

// MARK: - LLMControlConfig 扩展

extension LLMControlConfig {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
