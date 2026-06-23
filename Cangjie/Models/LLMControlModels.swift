//
//  LLMControlModels.swift
//  Cangjie
//
//  LLM 控制面板模型，字段对齐后端 application/ai/llm_control_service.py 的 Pydantic 模型。
//  以及 interfaces/api/v1/workbench/llm_control.py 的请求/响应。
//

import Foundation

// MARK: - LLM 预设

/// LLM 预设，对应后端 LLMPreset
struct LLMPreset: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let protocol: String
    let defaultBaseUrl: String
    let defaultModel: String
    let description: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case key, label
        case `protocol`
        case defaultBaseUrl = "default_base_url"
        case defaultModel = "default_model"
        case description, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.protocol = try c.decodeIfPresent(String.self, forKey: .protocol) ?? "openai"
        self.defaultBaseUrl = try c.decodeIfPresent(String.self, forKey: .defaultBaseUrl) ?? ""
        self.defaultModel = try c.decodeIfPresent(String.self, forKey: .defaultModel) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

// MARK: - LLM Profile

/// LLM 端点配置，对应后端 LLMProfile
struct LLMProfile: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let presetKey: String
    let `protocol`: String
    let baseUrl: String
    let apiKey: String
    let model: String
    let temperature: Double
    let maxTokens: Int
    let timeoutSeconds: Int
    let extraHeaders: [String: String]
    let extraQuery: [String: AnyCodable]
    let extraBody: [String: AnyCodable]
    let notes: String
    let useLegacyChatCompletions: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case presetKey = "preset_key"
        case `protocol`
        case baseUrl = "base_url"
        case apiKey = "api_key"
        case model, temperature
        case maxTokens = "max_tokens"
        case timeoutSeconds = "timeout_seconds"
        case extraHeaders = "extra_headers"
        case extraQuery = "extra_query"
        case extraBody = "extra_body"
        case notes
        case useLegacyChatCompletions = "use_legacy_chat_completions"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.presetKey = try c.decodeIfPresent(String.self, forKey: .presetKey) ?? "custom-openai-compatible"
        self.protocol = try c.decodeIfPresent(String.self, forKey: .protocol) ?? "openai"
        self.baseUrl = try c.decodeIfPresent(String.self, forKey: .baseUrl) ?? ""
        self.apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        self.temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
        self.maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 16000
        self.timeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? 300
        self.extraHeaders = try c.decodeIfPresent([String: String].self, forKey: .extraHeaders) ?? [:]
        self.extraQuery = try c.decodeIfPresent([String: AnyCodable].self, forKey: .extraQuery) ?? [:]
        self.extraBody = try c.decodeIfPresent([String: AnyCodable].self, forKey: .extraBody) ?? [:]
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.useLegacyChatCompletions = try c.decodeIfPresent(Bool.self, forKey: .useLegacyChatCompletions) ?? false
    }
}

// MARK: - LLM 控制配置

/// LLM 控制配置，对应后端 LLMControlConfig
struct LLMControlConfig: Codable, Equatable {
    let version: Int
    let activeProfileId: String?
    let endpointMode: String
    let profiles: [LLMProfile]

    enum CodingKeys: String, CodingKey {
        case version
        case activeProfileId = "active_profile_id"
        case endpointMode = "endpoint_mode"
        case profiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.activeProfileId = try c.decodeIfPresent(String.self, forKey: .activeProfileId)
        self.endpointMode = try c.decodeIfPresent(String.self, forKey: .endpointMode) ?? "unified"
        self.profiles = try c.decodeIfPresent([LLMProfile].self, forKey: .profiles) ?? []
    }
}

// MARK: - LLM 运行时摘要

/// LLM 运行时摘要，对应后端 LLMRuntimeSummary
struct LLMRuntimeSummary: Codable, Equatable {
    let source: String
    let activeProfileId: String?
    let activeProfileName: String?
    let `protocol`: String?
    let model: String?
    let baseUrl: String?
    let usingMock: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case source
        case activeProfileId = "active_profile_id"
        case activeProfileName = "active_profile_name"
        case `protocol`
        case model
        case baseUrl = "base_url"
        case usingMock = "using_mock"
        case reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "profile"
        self.activeProfileId = try c.decodeIfPresent(String.self, forKey: .activeProfileId)
        self.activeProfileName = try c.decodeIfPresent(String.self, forKey: .activeProfileName)
        self.protocol = try c.decodeIfPresent(String.self, forKey: .protocol)
        self.model = try c.decodeIfPresent(String.self, forKey: .model)
        self.baseUrl = try c.decodeIfPresent(String.self, forKey: .baseUrl)
        self.usingMock = try c.decodeIfPresent(Bool.self, forKey: .usingMock) ?? false
        self.reason = try c.decodeIfPresent(String.self, forKey: .reason)
    }
}

// MARK: - LLM 控制面板数据

/// LLM 控制面板数据，对应后端 LLMControlPanelData
struct LLMControlPanelData: Codable, Equatable {
    let config: LLMControlConfig
    let presets: [LLMPreset]
    let runtime: LLMRuntimeSummary

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.config = try c.decodeIfPresent(LLMControlConfig.self, forKey: .config) ?? LLMControlConfig(version: 1, activeProfileId: nil, endpointMode: "unified", profiles: [])
        self.presets = try c.decodeIfPresent([LLMPreset].self, forKey: .presets) ?? []
        self.runtime = try c.decodeIfPresent(LLMRuntimeSummary.self, forKey: .runtime) ?? LLMRuntimeSummary(source: "mock", activeProfileId: nil, activeProfileName: nil, protocol: nil, model: nil, baseUrl: nil, usingMock: true, reason: nil)
    }
}

// MARK: - LLM 测试结果

/// LLM 测试结果，对应后端 LLMTestResult
struct LLMTestResult: Codable, Equatable {
    let ok: Bool
    let providerLabel: String
    let model: String
    let latencyMs: Int
    let preview: String
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case providerLabel = "provider_label"
        case model
        case latencyMs = "latency_ms"
        case preview, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        self.providerLabel = try c.decodeIfPresent(String.self, forKey: .providerLabel) ?? ""
        self.model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        self.latencyMs = try c.decodeIfPresent(Int.self, forKey: .latencyMs) ?? 0
        self.preview = try c.decodeIfPresent(String.self, forKey: .preview) ?? ""
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

// MARK: - 模型列表

/// 模型列表项，对应后端 ModelItem
struct LLMModelInfo: Codable, Identifiable, Equatable {
    var id: String { itemId }
    let itemId: String
    let name: String
    let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case itemId = "id"
        case name
        case ownedBy = "owned_by"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.itemId = try c.decodeIfPresent(String.self, forKey: .itemId) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.ownedBy = try c.decodeIfPresent(String.self, forKey: .ownedBy) ?? ""
    }
}

/// 模型列表响应，对应后端 ModelListResponse
struct LLMModelListResponse: Codable, Equatable {
    let success: Bool
    let items: [LLMModelInfo]
    let count: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
        self.items = try c.decodeIfPresent([LLMModelInfo].self, forKey: .items) ?? []
        self.count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

// MARK: - 模型列表拉取请求

/// 模型列表拉取请求，对应后端 ModelListRequest
struct ModelListRequest: Codable {
    let `protocol`: String
    let baseUrl: String
    let apiKey: String
    let timeoutMs: Int?

    enum CodingKeys: String, CodingKey {
        case `protocol`
        case baseUrl = "base_url"
        case apiKey = "api_key"
        case timeoutMs = "timeout_ms"
    }
}

// MARK: - 测试请求

/// LLM 测试请求
struct LLMTestRequest: Codable {
    let profileId: String?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
    }
}
