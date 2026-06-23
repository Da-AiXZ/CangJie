//
//  PromptPlazaModels.swift
//  Cangjie
//
//  提示词广场模型，字段对齐后端 interfaces/api/v1/workbench/llm_control.py 的提示词相关模型。
//  以及 domain/ai/value_objects/prompt.py。
//

import Foundation

// MARK: - 提示词分类

/// 提示词分类信息
struct PromptCategoryInfo: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let icon: String?
    let color: String?
    let description: String?
    let sortOrder: Int?
    let promptCount: Int?

    enum CodingKeys: String, CodingKey {
        case key, label, icon, color, description
        case sortOrder = "sort_order"
        case promptCount = "prompt_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon)
        self.color = try c.decodeIfPresent(String.self, forKey: .color)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
        self.promptCount = try c.decodeIfPresent(Int.self, forKey: .promptCount)
    }
}

// MARK: - 提示词节点

/// 提示词节点，对应后端 /llm-control/prompts/{node_key} 返回
struct PromptNode: Codable, Identifiable, Equatable {
    var id: String { nodeKey }
    let nodeKey: String
    let title: String?
    let category: String?
    let description: String?
    let currentVersionId: String?
    let content: String?
    let variables: [String]?
    let tags: [String]?
    let enabled: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case nodeKey = "node_key"
        case title, category, description, content, variables, tags, enabled
        case currentVersionId = "current_version_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.category = try c.decodeIfPresent(String.self, forKey: .category)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.currentVersionId = try c.decodeIfPresent(String.self, forKey: .currentVersionId)
        self.content = try c.decodeIfPresent(String.self, forKey: .content)
        self.variables = try c.decodeIfPresent([String].self, forKey: .variables)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - 提示词版本

/// 提示词版本
struct PromptVersion: Codable, Identifiable, Equatable {
    let id: String
    let nodeKey: String
    let versionNumber: Int
    let content: String
    let changeLog: String?
    let createdBy: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nodeKey = "node_key"
        case versionNumber = "version_number"
        case content
        case changeLog = "change_log"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.versionNumber = try c.decodeIfPresent(Int.self, forKey: .versionNumber) ?? 0
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.changeLog = try c.decodeIfPresent(String.self, forKey: .changeLog)
        self.createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - 提示词模板

/// 提示词模板
struct PromptTemplate: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let content: String
    let description: String?
    let variables: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, category, content, description, variables
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.variables = try c.decodeIfPresent([String].self, forKey: .variables)
    }
}

// MARK: - 提示词渲染请求

/// 提示词渲染请求，对应后端 PromptRenderRequest
struct PromptRenderRequest: Codable {
    let nodeKey: String
    let variables: [String: String]?

    enum CodingKeys: String, CodingKey {
        case nodeKey = "node_key"
        case variables
    }
}

/// 提示词渲染结果
struct PromptRenderResult: Codable, Equatable {
    let rendered: String
    let variablesUsed: [String]?

    enum CodingKeys: String, CodingKey {
        case rendered
        case variablesUsed = "variables_used"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.rendered = dict["rendered"]?.stringStringValue ?? ""
        self.variablesUsed = (dict["variables_used"]?.arrayValue ?? []).compactMap { $0 as? String }
    }
}

// MARK: - 提示词调试结果

/// 提示词调试结果
struct PromptDebugResult: Codable, Equatable {
    let nodeKey: String
    let renderedPrompt: String
    let variables: [String: String]?
    let modelResponse: String?
    let tokenInput: Int?
    let tokenOutput: Int?
    let latencyMs: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case nodeKey = "node_key"
        case renderedPrompt = "rendered_prompt"
        case variables
        case modelResponse = "model_response"
        case tokenInput = "token_input"
        case tokenOutput = "token_output"
        case latencyMs = "latency_ms"
        case error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.nodeKey = dict["node_key"]?.stringStringValue ?? ""
        self.renderedPrompt = dict["rendered_prompt"]?.stringStringValue ?? ""
        self.variables = (dict["variables"]?.dictionaryValue ?? [:]).compactMapValues { $0.stringStringValue }
        self.modelResponse = dict["model_response"]?.stringStringValue
        self.tokenInput = dict["token_input"]?.intValue
        self.tokenOutput = dict["token_output"]?.intValue
        self.latencyMs = dict["latency_ms"]?.intValue
        self.error = dict["error"]?.stringStringValue
    }
}

// MARK: - 提示词更新请求

/// 提示词更新请求
struct PromptUpdateRequest: Codable {
    let content: String
    let changeLog: String?

    enum CodingKeys: String, CodingKey {
        case content
        case changeLog = "change_log"
    }
}

// MARK: - 提示词广场初始化

/// 提示词广场初始化响应（GET /llm-control/prompts/plaza-init）
struct PromptPlazaInit: Codable, Equatable {
    let categories: [PromptCategoryInfo]
    let nodes: [PromptNode]
    let stats: AnyCodable?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        let catData = try JSONSerialization.data(withJSONObject: dict["categories"]?.value ?? [])
        self.categories = (try? JSONDecoder().decode([PromptCategoryInfo].self, from: catData)) ?? []
        let nodeData = try JSONSerialization.data(withJSONObject: dict["nodes"]?.value ?? [])
        self.nodes = (try? JSONDecoder().decode([PromptNode].self, from: nodeData)) ?? []
        self.stats = dict["stats"].map { AnyCodable($0) }
    }
}

// MARK: - 提示词统计

/// 提示词统计（GET /llm-control/prompts/stats）
struct PromptStats: Codable, Equatable {
    let totalNodes: Int
    let totalVersions: Int
    let byCategory: [String: Int]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.totalNodes = dict["total_nodes"]?.intValue ?? 0
        self.totalVersions = dict["total_versions"]?.intValue ?? 0
        self.byCategory = (dict["by_category"]?.dictionaryValue ?? [:]).compactMapValues { $0.intValue }
    }
}

// MARK: - 提示词对比

/// 提示词版本对比结果
struct PromptComparison: Codable, Equatable {
    let v1Id: String
    let v2Id: String
    let v1Content: String
    let v2Content: String
    let diff: String?

    enum CodingKeys: String, CodingKey {
        case v1Id = "v1_id"
        case v2Id = "v2_id"
        case v1Content = "v1_content"
        case v2Content = "v2_content"
        case diff
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.v1Id = dict["v1_id"]?.stringStringValue ?? ""
        self.v2Id = dict["v2_id"]?.stringStringValue ?? ""
        self.v1Content = dict["v1_content"]?.stringStringValue ?? ""
        self.v2Content = dict["v2_content"]?.stringStringValue ?? ""
        self.diff = dict["diff"]?.stringStringValue
    }
}
