//
//  PromptPlazaModels.swift
//  Cangjie
//
//  提示词广场模型，逐字段对齐原版 llmControl.ts:101-476 全部 17 个接口/模型。
//  阶段2 完全重写——修复前几乎所有模型字段都与原版不符。
//

import Foundation

// MARK: - 提示词分类信息

/// 提示词分类信息，对应原版 llmControl.ts:104-111 PromptCategoryInfo
struct PromptCategoryInfo: Codable, Identifiable, Equatable {
    var id: String { key }
    /// 分类 key（llmControl.ts:105）
    let key: String
    /// 分类名称（llmControl.ts:106）
    let name: String
    /// 图标（llmControl.ts:107）
    let icon: String
    /// 描述（llmControl.ts:108）
    let description: String
    /// 颜色（llmControl.ts:109）
    let color: String
    /// 节点计数（llmControl.ts:110）
    let count: Int

    enum CodingKeys: String, CodingKey {
        case key, name, icon, description, color, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        self.count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

// MARK: - 提示词模板包

/// 提示词模板包，对应原版 llmControl.ts:114-126 PromptTemplate
struct PromptTemplate: Codable, Identifiable, Equatable {
    /// 模板 ID（llmControl.ts:115）
    let id: String
    /// 模板名称（llmControl.ts:116）
    let name: String
    /// 描述（llmControl.ts:117）
    let description: String
    /// 分类（llmControl.ts:118）
    let category: String
    /// 版本（llmControl.ts:119）
    let version: String
    /// 作者（llmControl.ts:120）
    let author: String
    /// 图标（llmControl.ts:121）
    let icon: String
    /// 颜色（llmControl.ts:122）
    let color: String
    /// 是否内置（llmControl.ts:123）
    let isBuiltin: Bool
    /// 元数据（llmControl.ts:124，动态 JSON）
    let metadata: AnyCodable
    /// 节点数（llmControl.ts:125）
    let nodeCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, version, author, icon, color
        case isBuiltin = "is_builtin"
        case metadata
        case nodeCount = "node_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        self.author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        self.color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        self.isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        self.metadata = try c.decodeIfPresent(AnyCodable.self, forKey: .metadata) ?? AnyCodable([:])
        self.nodeCount = try c.decodeIfPresent(Int.self, forKey: .nodeCount) ?? 0
    }
}

// MARK: - 提示词变量定义

/// 提示词变量定义，对应原版 llmControl.ts:129-135 PromptVariable
struct PromptVariable: Codable, Equatable {
    /// 变量名（llmControl.ts:130）
    let name: String
    /// 描述（llmControl.ts:131）
    let desc: String
    /// 类型（llmControl.ts:132）
    let type: String
    /// 是否必填（llmControl.ts:133，可选）
    let required: Bool?
    /// 默认值（llmControl.ts:134，可选，动态 JSON）
    /// 注：原版字段名为 default，Swift 关键字，属性名用 defaultValue，CodingKey 映射为 default
    let defaultValue: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case name, desc, type, required
        case defaultValue = "default"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.desc = try c.decodeIfPresent(String.self, forKey: .desc) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required)
        self.defaultValue = try c.decodeIfPresent(AnyCodable.self, forKey: .defaultValue)
    }
}

// MARK: - 提示词节点（列表项）

/// 提示词节点（列表项），对应原版 llmControl.ts:138-159 PromptNode
/// 主理人决策：用原版 id 字段作 Identifiable.id，nodeKey 独立保留
struct PromptNode: Codable, Identifiable, Equatable {
    /// 节点 ID（llmControl.ts:139，主理人决策：用原版 id 字段作 Identifiable.id）
    let id: String
    /// 节点 key（llmControl.ts:140）
    let nodeKey: String
    /// 节点名称（llmControl.ts:141）
    let name: String
    /// 描述（llmControl.ts:142）
    let description: String
    /// 分类（llmControl.ts:143）
    let category: String
    /// 来源（llmControl.ts:144）
    let source: String
    /// 输出格式：text/json（llmControl.ts:145）
    let outputFormat: String
    /// 契约模块（llmControl.ts:146，可选）
    let contractModule: String?
    /// 契约模型（llmControl.ts:147，可选）
    let contractModel: String?
    /// 标签（llmControl.ts:148）
    let tags: [String]
    /// 变量定义列表（llmControl.ts:149）
    let variables: [PromptVariable]
    /// 变量名列表（llmControl.ts:150）
    let variableNames: [String]
    /// 系统文件路径（llmControl.ts:151，可选）
    let systemFile: String?
    /// 是否内置（llmControl.ts:152）
    let isBuiltin: Bool
    /// 排序序号（llmControl.ts:153）
    let sortOrder: Int
    /// 模板 ID（llmControl.ts:154）
    let templateId: String
    /// 版本数（llmControl.ts:155）
    let versionCount: Int
    /// 系统提示预览（llmControl.ts:156）
    let systemPreview: String
    /// 用户模板预览（llmControl.ts:157）
    let userTemplatePreview: String
    /// 是否有用户编辑（llmControl.ts:158）
    let hasUserEdit: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nodeKey = "node_key"
        case name, description, category, source
        case outputFormat = "output_format"
        case contractModule = "contract_module"
        case contractModel = "contract_model"
        case tags, variables
        case variableNames = "variable_names"
        case systemFile = "system_file"
        case isBuiltin = "is_builtin"
        case sortOrder = "sort_order"
        case templateId = "template_id"
        case versionCount = "version_count"
        case systemPreview = "system_preview"
        case userTemplatePreview = "user_template_preview"
        case hasUserEdit = "has_user_edit"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.outputFormat = try c.decodeIfPresent(String.self, forKey: .outputFormat) ?? "text"
        self.contractModule = try c.decodeIfPresent(String.self, forKey: .contractModule)
        self.contractModel = try c.decodeIfPresent(String.self, forKey: .contractModel)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.variables = try c.decodeIfPresent([PromptVariable].self, forKey: .variables) ?? []
        self.variableNames = try c.decodeIfPresent([String].self, forKey: .variableNames) ?? []
        self.systemFile = try c.decodeIfPresent(String.self, forKey: .systemFile)
        self.isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.templateId = try c.decodeIfPresent(String.self, forKey: .templateId) ?? ""
        self.versionCount = try c.decodeIfPresent(Int.self, forKey: .versionCount) ?? 0
        self.systemPreview = try c.decodeIfPresent(String.self, forKey: .systemPreview) ?? ""
        self.userTemplatePreview = try c.decodeIfPresent(String.self, forKey: .userTemplatePreview) ?? ""
        self.hasUserEdit = try c.decodeIfPresent(Bool.self, forKey: .hasUserEdit) ?? false
    }

    /// Memberwise init（用于从 PromptNodeDetail 构造列表项）
    init(
        id: String, nodeKey: String, name: String, description: String,
        category: String, source: String, outputFormat: String,
        contractModule: String?, contractModel: String?, tags: [String],
        variables: [PromptVariable], variableNames: [String], systemFile: String?,
        isBuiltin: Bool, sortOrder: Int, templateId: String, versionCount: Int,
        systemPreview: String, userTemplatePreview: String, hasUserEdit: Bool
    ) {
        self.id = id
        self.nodeKey = nodeKey
        self.name = name
        self.description = description
        self.category = category
        self.source = source
        self.outputFormat = outputFormat
        self.contractModule = contractModule
        self.contractModel = contractModel
        self.tags = tags
        self.variables = variables
        self.variableNames = variableNames
        self.systemFile = systemFile
        self.isBuiltin = isBuiltin
        self.sortOrder = sortOrder
        self.templateId = templateId
        self.versionCount = versionCount
        self.systemPreview = systemPreview
        self.userTemplatePreview = userTemplatePreview
        self.hasUserEdit = hasUserEdit
    }
}

// MARK: - DAG 绑定子结构

/// DAG 绑定，对应原版 llmControl.ts:166-171 dag_bindings 数组元素
struct DagBinding: Codable, Equatable {
    let nodeId: String
    let nodeType: String
    let label: String
    let displayName: String
    let promptMode: String

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case nodeType = "node_type"
        case label
        case displayName = "display_name"
        case promptMode = "prompt_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.promptMode = try c.decodeIfPresent(String.self, forKey: .promptMode) ?? ""
    }
}

/// DAG 注册表绑定，对应原版 llmControl.ts:173-176 dag_registry_bindings 数组元素
struct DagRegistryBinding: Codable, Equatable {
    let nodeType: String
    let displayName: String
    let promptMode: String

    enum CodingKeys: String, CodingKey {
        case nodeType = "node_type"
        case displayName = "display_name"
        case promptMode = "prompt_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.promptMode = try c.decodeIfPresent(String.self, forKey: .promptMode) ?? ""
    }
}

// MARK: - 提示词节点详情

/// 提示词节点详情，对应原版 llmControl.ts:162-177 PromptNodeDetail（继承 PromptNode）
struct PromptNodeDetail: Codable, Identifiable, Equatable {
    /// 节点 ID（继承 PromptNode.id）
    let id: String
    /// 节点 key（继承 PromptNode.nodeKey）
    let nodeKey: String
    /// 节点名称（继承 PromptNode.name）
    let name: String
    /// 描述（继承 PromptNode.description）
    let description: String
    /// 分类（继承 PromptNode.category）
    let category: String
    /// 来源（继承 PromptNode.source）
    let source: String
    /// 输出格式（继承 PromptNode.outputFormat）
    let outputFormat: String
    /// 契约模块（继承 PromptNode.contractModule）
    let contractModule: String?
    /// 契约模型（继承 PromptNode.contractModel）
    let contractModel: String?
    /// 标签（继承 PromptNode.tags）
    let tags: [String]
    /// 变量定义列表（继承 PromptNode.variables）
    let variables: [PromptVariable]
    /// 变量名列表（继承 PromptNode.variableNames）
    let variableNames: [String]
    /// 系统文件路径（继承 PromptNode.systemFile）
    let systemFile: String?
    /// 是否内置（继承 PromptNode.isBuiltin）
    let isBuiltin: Bool
    /// 排序序号（继承 PromptNode.sortOrder）
    let sortOrder: Int
    /// 模板 ID（继承 PromptNode.templateId）
    let templateId: String
    /// 版本数（继承 PromptNode.versionCount）
    let versionCount: Int
    /// 系统提示预览（继承 PromptNode.systemPreview）
    let systemPreview: String
    /// 用户模板预览（继承 PromptNode.userTemplatePreview）
    let userTemplatePreview: String
    /// 是否有用户编辑（继承 PromptNode.hasUserEdit）
    let hasUserEdit: Bool

    // PromptNodeDetail 扩展字段（llmControl.ts:163-176）
    /// 完整系统提示（llmControl.ts:163）
    let system: String
    /// 完整用户模板（llmControl.ts:164）
    let userTemplate: String
    /// DAG 绑定列表（llmControl.ts:165-171，可选）
    let dagBindings: [DagBinding]?
    /// DAG 注册表绑定列表（llmControl.ts:172-176，可选）
    let dagRegistryBindings: [DagRegistryBinding]?

    enum CodingKeys: String, CodingKey {
        case id
        case nodeKey = "node_key"
        case name, description, category, source
        case outputFormat = "output_format"
        case contractModule = "contract_module"
        case contractModel = "contract_model"
        case tags, variables
        case variableNames = "variable_names"
        case systemFile = "system_file"
        case isBuiltin = "is_builtin"
        case sortOrder = "sort_order"
        case templateId = "template_id"
        case versionCount = "version_count"
        case systemPreview = "system_preview"
        case userTemplatePreview = "user_template_preview"
        case hasUserEdit = "has_user_edit"
        case system
        case userTemplate = "user_template"
        case dagBindings = "dag_bindings"
        case dagRegistryBindings = "dag_registry_bindings"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.outputFormat = try c.decodeIfPresent(String.self, forKey: .outputFormat) ?? "text"
        self.contractModule = try c.decodeIfPresent(String.self, forKey: .contractModule)
        self.contractModel = try c.decodeIfPresent(String.self, forKey: .contractModel)
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.variables = try c.decodeIfPresent([PromptVariable].self, forKey: .variables) ?? []
        self.variableNames = try c.decodeIfPresent([String].self, forKey: .variableNames) ?? []
        self.systemFile = try c.decodeIfPresent(String.self, forKey: .systemFile)
        self.isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.templateId = try c.decodeIfPresent(String.self, forKey: .templateId) ?? ""
        self.versionCount = try c.decodeIfPresent(Int.self, forKey: .versionCount) ?? 0
        self.systemPreview = try c.decodeIfPresent(String.self, forKey: .systemPreview) ?? ""
        self.userTemplatePreview = try c.decodeIfPresent(String.self, forKey: .userTemplatePreview) ?? ""
        self.hasUserEdit = try c.decodeIfPresent(Bool.self, forKey: .hasUserEdit) ?? false
        self.system = try c.decodeIfPresent(String.self, forKey: .system) ?? ""
        self.userTemplate = try c.decodeIfPresent(String.self, forKey: .userTemplate) ?? ""
        self.dagBindings = try c.decodeIfPresent([DagBinding].self, forKey: .dagBindings)
        self.dagRegistryBindings = try c.decodeIfPresent([DagRegistryBinding].self, forKey: .dagRegistryBindings)
    }
}

// MARK: - 提示词版本

/// 提示词版本，对应原版 llmControl.ts:180-188 PromptVersion
struct PromptVersion: Codable, Identifiable, Equatable {
    /// 版本 ID（llmControl.ts:181）
    let id: String
    /// 版本号（llmControl.ts:182）
    let versionNumber: Int
    /// 变更摘要（llmControl.ts:183）
    let changeSummary: String
    /// 创建者（llmControl.ts:184）
    let createdBy: String
    /// 创建时间（llmControl.ts:185）
    let createdAt: String
    /// 系统提示预览（llmControl.ts:186）
    let systemPreview: String
    /// 用户模板预览（llmControl.ts:187）
    let userPreview: String

    enum CodingKeys: String, CodingKey {
        case id
        case versionNumber = "version_number"
        case changeSummary = "change_summary"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case systemPreview = "system_preview"
        case userPreview = "user_preview"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.versionNumber = try c.decodeIfPresent(Int.self, forKey: .versionNumber) ?? 0
        self.changeSummary = try c.decodeIfPresent(String.self, forKey: .changeSummary) ?? ""
        self.createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.systemPreview = try c.decodeIfPresent(String.self, forKey: .systemPreview) ?? ""
        self.userPreview = try c.decodeIfPresent(String.self, forKey: .userPreview) ?? ""
    }
}

// MARK: - 提示词版本详情

/// 提示词版本详情，对应原版 llmControl.ts:191-194 PromptVersionDetail（继承 PromptVersion）
struct PromptVersionDetail: Codable, Identifiable, Equatable {
    /// 版本 ID（继承 PromptVersion.id）
    let id: String
    /// 版本号（继承 PromptVersion.versionNumber）
    let versionNumber: Int
    /// 变更摘要（继承 PromptVersion.changeSummary）
    let changeSummary: String
    /// 创建者（继承 PromptVersion.createdBy）
    let createdBy: String
    /// 创建时间（继承 PromptVersion.createdAt）
    let createdAt: String
    /// 系统提示预览（继承 PromptVersion.systemPreview）
    let systemPreview: String
    /// 用户模板预览（继承 PromptVersion.userPreview）
    let userPreview: String

    // PromptVersionDetail 扩展字段（llmControl.ts:192-193）
    /// 完整系统提示（llmControl.ts:192）
    let systemPrompt: String
    /// 完整用户模板（llmControl.ts:193）
    let userTemplate: String

    enum CodingKeys: String, CodingKey {
        case id
        case versionNumber = "version_number"
        case changeSummary = "change_summary"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case systemPreview = "system_preview"
        case userPreview = "user_preview"
        case systemPrompt = "system_prompt"
        case userTemplate = "user_template"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.versionNumber = try c.decodeIfPresent(Int.self, forKey: .versionNumber) ?? 0
        self.changeSummary = try c.decodeIfPresent(String.self, forKey: .changeSummary) ?? ""
        self.createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.systemPreview = try c.decodeIfPresent(String.self, forKey: .systemPreview) ?? ""
        self.userPreview = try c.decodeIfPresent(String.self, forKey: .userPreview) ?? ""
        self.systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
        self.userTemplate = try c.decodeIfPresent(String.self, forKey: .userTemplate) ?? ""
    }
}

// MARK: - 版本对比结果

/// 版本对比 diff 子结构，对应原版 llmControl.ts:200-203 diff 对象
struct VersionDiff: Codable, Equatable {
    /// 系统提示是否变更（llmControl.ts:201）
    let systemChanged: Bool
    /// 用户模板是否变更（llmControl.ts:202）
    let userChanged: Bool

    enum CodingKeys: String, CodingKey {
        case systemChanged = "system_changed"
        case userChanged = "user_changed"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.systemChanged = try c.decodeIfPresent(Bool.self, forKey: .systemChanged) ?? false
        self.userChanged = try c.decodeIfPresent(Bool.self, forKey: .userChanged) ?? false
    }
}

/// 版本对比结果，对应原版 llmControl.ts:197-204 VersionCompareResult
struct VersionCompareResult: Codable, Equatable {
    /// 版本 1 详情（llmControl.ts:198）
    let v1: PromptVersionDetail
    /// 版本 2 详情（llmControl.ts:199）
    let v2: PromptVersionDetail
    /// 差异信息（llmControl.ts:200-203）
    let diff: VersionDiff

    enum CodingKeys: String, CodingKey {
        case v1, v2, diff
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.v1 = try c.decodeIfPresent(PromptVersionDetail.self, forKey: .v1) ?? PromptVersionDetail(systemPrompt: "", userTemplate: "")
        self.v2 = try c.decodeIfPresent(PromptVersionDetail.self, forKey: .v2) ?? PromptVersionDetail(systemPrompt: "", userTemplate: "")
        self.diff = try c.decodeIfPresent(VersionDiff.self, forKey: .diff) ?? VersionDiff(systemChanged: false, userChanged: false)
    }
}

/// PromptVersionDetail 的默认 init（用于 fallback）
extension PromptVersionDetail {
    init(systemPrompt: String, userTemplate: String) {
        self.id = ""
        self.versionNumber = 0
        self.changeSummary = ""
        self.createdBy = ""
        self.createdAt = ""
        self.systemPreview = ""
        self.userPreview = ""
        self.systemPrompt = systemPrompt
        self.userTemplate = userTemplate
    }
}

/// VersionDiff 的默认 init（用于 fallback）
extension VersionDiff {
    init(systemChanged: Bool, userChanged: Bool) {
        self.systemChanged = systemChanged
        self.userChanged = userChanged
    }
}

// MARK: - 提示词统计

/// 提示词统计，对应原版 llmControl.ts:207-214 PromptStats
struct PromptStats: Codable, Equatable {
    /// 总节点数（llmControl.ts:208）
    let totalNodes: Int
    /// 总模板数（llmControl.ts:209）
    let totalTemplates: Int
    /// 总版本数（llmControl.ts:210）
    let totalVersions: Int
    /// 内置节点数（llmControl.ts:211）
    let builtinCount: Int
    /// 自定义节点数（llmControl.ts:212）
    let customCount: Int
    /// 分类计数（llmControl.ts:213）
    let categories: [String: Int]

    enum CodingKeys: String, CodingKey {
        case categories
        case totalNodes = "total_nodes"
        case totalTemplates = "total_templates"
        case totalVersions = "total_versions"
        case builtinCount = "builtin_count"
        case customCount = "custom_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalNodes = try c.decodeIfPresent(Int.self, forKey: .totalNodes) ?? 0
        self.totalTemplates = try c.decodeIfPresent(Int.self, forKey: .totalTemplates) ?? 0
        self.totalVersions = try c.decodeIfPresent(Int.self, forKey: .totalVersions) ?? 0
        self.builtinCount = try c.decodeIfPresent(Int.self, forKey: .builtinCount) ?? 0
        self.customCount = try c.decodeIfPresent(Int.self, forKey: .customCount) ?? 0
        self.categories = try c.decodeIfPresent([String: Int].self, forKey: .categories) ?? [:]
    }
}

// MARK: - 渲染结果

/// 渲染结果，对应原版 llmControl.ts:217-220 RenderResult
struct RenderResult: Codable, Equatable {
    /// 渲染后的系统提示（llmControl.ts:218）
    let system: String
    /// 渲染后的用户提示（llmControl.ts:219）
    let user: String

    enum CodingKeys: String, CodingKey {
        case system, user
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.system = try c.decodeIfPresent(String.self, forKey: .system) ?? ""
        self.user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
    }
}

// MARK: - 调试结果

/// 调试诊断信息，对应原版 llmControl.ts:227-233 diagnostics 对象
struct DebugDiagnostics: Codable, Equatable {
    /// 错误列表（llmControl.ts:228）
    let errors: [String]
    /// 警告列表（llmControl.ts:229）
    let warnings: [String]
    /// 缺失变量列表（llmControl.ts:230）
    let missingVariables: [String]
    /// 已渲染变量列表（llmControl.ts:231）
    let renderedVariables: [String]
    /// 缺失必填变量列表（llmControl.ts:232）
    let missingRequired: [String]

    enum CodingKeys: String, CodingKey {
        case errors, warnings
        case missingVariables = "missing_variables"
        case renderedVariables = "rendered_variables"
        case missingRequired = "missing_required"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.errors = try c.decodeIfPresent([String].self, forKey: .errors) ?? []
        self.warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
        self.missingVariables = try c.decodeIfPresent([String].self, forKey: .missingVariables) ?? []
        self.renderedVariables = try c.decodeIfPresent([String].self, forKey: .renderedVariables) ?? []
        self.missingRequired = try c.decodeIfPresent([String].self, forKey: .missingRequired) ?? []
    }
}

/// 调试结果，对应原版 llmControl.ts:223-239 DebugResult
struct DebugResult: Codable, Equatable {
    /// 是否成功（llmControl.ts:224）
    let success: Bool
    /// 渲染后的系统提示（llmControl.ts:225）
    let system: String
    /// 渲染后的用户提示（llmControl.ts:226）
    let user: String
    /// 诊断信息（llmControl.ts:227-233）
    let diagnostics: DebugDiagnostics
    /// 节点 key（llmControl.ts:234）
    let nodeKey: String
    /// 节点名称（llmControl.ts:235）
    let nodeName: String
    /// 已提供的变量列表（llmControl.ts:236）
    let variablesProvided: [String]
    /// 耗时毫秒（llmControl.ts:237）
    let elapsedMs: Int
    /// 错误信息（llmControl.ts:238，可选）
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, system, user, diagnostics, error
        case nodeKey = "node_key"
        case nodeName = "node_name"
        case variablesProvided = "variables_provided"
        case elapsedMs = "elapsed_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.system = try c.decodeIfPresent(String.self, forKey: .system) ?? ""
        self.user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        self.diagnostics = try c.decodeIfPresent(DebugDiagnostics.self, forKey: .diagnostics) ?? DebugDiagnostics()
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.nodeName = try c.decodeIfPresent(String.self, forKey: .nodeName) ?? ""
        self.variablesProvided = try c.decodeIfPresent([String].self, forKey: .variablesProvided) ?? []
        self.elapsedMs = try c.decodeIfPresent(Int.self, forKey: .elapsedMs) ?? 0
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// DebugDiagnostics 默认 init
extension DebugDiagnostics {
    init() {
        self.errors = []
        self.warnings = []
        self.missingVariables = []
        self.renderedVariables = []
        self.missingRequired = []
    }
}

// MARK: - COT 调用链结果

/// 链绑定，对应原版 llmControl.ts:248-253 bindings 数组元素
struct ChainBinding: Codable, Equatable {
    let workflowId: String
    let workflowName: String
    let slot: String
    let priority: Int
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case slot, priority, enabled
        case workflowId = "workflow_id"
        case workflowName = "workflow_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.workflowId = try c.decodeIfPresent(String.self, forKey: .workflowId) ?? ""
        self.workflowName = try c.decodeIfPresent(String.self, forKey: .workflowName) ?? ""
        self.slot = try c.decodeIfPresent(String.self, forKey: .slot) ?? ""
        self.priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
}

/// 反向依赖，对应原版 llmControl.ts:255-258 reverse_dependencies 数组元素
struct ReverseDep: Codable, Equatable {
    let workflowId: String
    let workflowName: String
    let slot: String

    enum CodingKeys: String, CodingKey {
        case slot
        case workflowId = "workflow_id"
        case workflowName = "workflow_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.workflowId = try c.decodeIfPresent(String.self, forKey: .workflowId) ?? ""
        self.workflowName = try c.decodeIfPresent(String.self, forKey: .workflowName) ?? ""
        self.slot = try c.decodeIfPresent(String.self, forKey: .slot) ?? ""
    }
}

/// 链变量，对应原版 llmControl.ts:260-265 variables 数组元素
struct ChainVariable: Codable, Equatable {
    let name: String
    let type: String
    let source: String
    let required: Bool
    /// 原版字段名为 default，Swift 关键字，属性名用 defaultValue，CodingKey 映射为 default
    let defaultValue: AnyCodable

    enum CodingKeys: String, CodingKey {
        case name, type, source, required
        case defaultValue = "default"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? false
        self.defaultValue = try c.decodeIfPresent(AnyCodable.self, forKey: .defaultValue) ?? AnyCodable("")
    }
}

/// COT 调用链结果，对应原版 llmControl.ts:242-267 PromptChainResult
struct PromptChainResult: Codable, Equatable {
    /// 节点 key（llmControl.ts:243）
    let nodeKey: String
    /// 节点名称（llmControl.ts:244）
    let nodeName: String
    /// 分类（llmControl.ts:245）
    let category: String
    /// 来源（llmControl.ts:246）
    let source: String
    /// 绑定列表（llmControl.ts:247-253）
    let bindings: [ChainBinding]
    /// 反向依赖列表（llmControl.ts:254-258）
    let reverseDependencies: [ReverseDep]
    /// 变量列表（llmControl.ts:259-265）
    let variables: [ChainVariable]
    /// 版本数（llmControl.ts:266）
    let versionCount: Int

    enum CodingKeys: String, CodingKey {
        case category, source, bindings, variables
        case nodeKey = "node_key"
        case nodeName = "node_name"
        case reverseDependencies = "reverse_dependencies"
        case versionCount = "version_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.nodeName = try c.decodeIfPresent(String.self, forKey: .nodeName) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.bindings = try c.decodeIfPresent([ChainBinding].self, forKey: .bindings) ?? []
        self.reverseDependencies = try c.decodeIfPresent([ReverseDep].self, forKey: .reverseDependencies) ?? []
        self.variables = try c.decodeIfPresent([ChainVariable].self, forKey: .variables) ?? []
        self.versionCount = try c.decodeIfPresent(Int.self, forKey: .versionCount) ?? 0
    }
}

// MARK: - 沙盒渲染结果

/// 模板变量子结构，对应原版 llmControl.ts:278-282 template_variables 对象
struct TemplateVariables: Codable, Equatable {
    /// 系统提示中的变量（llmControl.ts:279）
    let system: [String]
    /// 用户模板中的变量（llmControl.ts:280）
    let user: [String]
    /// 全部变量（llmControl.ts:281）
    let all: [String]

    enum CodingKeys: String, CodingKey {
        case system, user, all
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.system = try c.decodeIfPresent([String].self, forKey: .system) ?? []
        self.user = try c.decodeIfPresent([String].self, forKey: .user) ?? []
        self.all = try c.decodeIfPresent([String].self, forKey: .all) ?? []
    }
}

/// 沙盒渲染结果，对应原版 llmControl.ts:270-286 SandboxResult
struct SandboxResult: Codable, Equatable {
    /// 是否有效（llmControl.ts:271）
    let valid: Bool
    /// 错误列表（llmControl.ts:272）
    let errors: [String]
    /// 警告列表（llmControl.ts:273）
    let warnings: [String]
    /// 缺失变量列表（llmControl.ts:274）
    let missingVariables: [String]
    /// 缺失必填变量列表（llmControl.ts:275）
    let missingRequired: [String]
    /// 系统提示预览（llmControl.ts:276）
    let systemPreview: String
    /// 用户模板预览（llmControl.ts:277）
    let userPreview: String
    /// 模板变量（llmControl.ts:278-282）
    let templateVariables: TemplateVariables
    /// 已提供的变量列表（llmControl.ts:283）
    let providedVariables: [String]
    /// 耗时毫秒（llmControl.ts:284）
    let elapsedMs: Int
    /// 错误信息（llmControl.ts:285，可选）
    let error: String?

    enum CodingKeys: String, CodingKey {
        case valid, errors, warnings, error
        case missingVariables = "missing_variables"
        case missingRequired = "missing_required"
        case systemPreview = "system_preview"
        case userPreview = "user_preview"
        case templateVariables = "template_variables"
        case providedVariables = "provided_variables"
        case elapsedMs = "elapsed_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.valid = try c.decodeIfPresent(Bool.self, forKey: .valid) ?? false
        self.errors = try c.decodeIfPresent([String].self, forKey: .errors) ?? []
        self.warnings = try c.decodeIfPresent([String].self, forKey: .warnings) ?? []
        self.missingVariables = try c.decodeIfPresent([String].self, forKey: .missingVariables) ?? []
        self.missingRequired = try c.decodeIfPresent([String].self, forKey: .missingRequired) ?? []
        self.systemPreview = try c.decodeIfPresent(String.self, forKey: .systemPreview) ?? ""
        self.userPreview = try c.decodeIfPresent(String.self, forKey: .userPreview) ?? ""
        self.templateVariables = try c.decodeIfPresent(TemplateVariables.self, forKey: .templateVariables) ?? TemplateVariables()
        self.providedVariables = try c.decodeIfPresent([String].self, forKey: .providedVariables) ?? []
        self.elapsedMs = try c.decodeIfPresent(Int.self, forKey: .elapsedMs) ?? 0
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// TemplateVariables 默认 init
extension TemplateVariables {
    init() {
        self.system = []
        self.user = []
        self.all = []
    }
}

// MARK: - 变量 Schema

/// 变量 Schema，对应原版 llmControl.ts:289-299 VariableSchema
struct VariableSchema: Codable, Identifiable, Equatable {
    var id: String { name }
    /// 变量名（llmControl.ts:290）
    let name: String
    /// 显示名（llmControl.ts:291）
    let displayName: String
    /// 类型（llmControl.ts:292）
    let type: String
    /// 是否必填（llmControl.ts:293）
    let required: Bool
    /// 默认值（llmControl.ts:294，动态 JSON）
    /// 原版字段名为 default，Swift 关键字，属性名用 defaultValue，CodingKey 映射为 default
    let defaultValue: AnyCodable
    /// 描述（llmControl.ts:295）
    let description: String
    /// 来源（llmControl.ts:296）
    let source: String
    /// 作用域（llmControl.ts:297）
    let scope: String
    /// 枚举值列表（llmControl.ts:298）
    let enumValues: [String]

    enum CodingKeys: String, CodingKey {
        case name, type, required, description, source, scope
        case defaultValue = "default"
        case displayName = "display_name"
        case enumValues = "enum_values"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? false
        self.defaultValue = try c.decodeIfPresent(AnyCodable.self, forKey: .defaultValue) ?? AnyCodable("")
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.scope = try c.decodeIfPresent(String.self, forKey: .scope) ?? ""
        self.enumValues = try c.decodeIfPresent([String].self, forKey: .enumValues) ?? []
    }
}

// MARK: - 节点绑定结果

/// 节点绑定，对应原版 llmControl.ts:306-313 bindings 数组元素
struct NodeBinding: Codable, Identifiable, Equatable {
    /// 绑定 ID（llmControl.ts:306）
    let id: String
    let workflowId: String
    let workflowName: String
    let nodeKey: String
    let slot: String
    let priority: Int
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, slot, priority, enabled
        case workflowId = "workflow_id"
        case workflowName = "workflow_name"
        case nodeKey = "node_key"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.workflowId = try c.decodeIfPresent(String.self, forKey: .workflowId) ?? ""
        self.workflowName = try c.decodeIfPresent(String.self, forKey: .workflowName) ?? ""
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.slot = try c.decodeIfPresent(String.self, forKey: .slot) ?? ""
        self.priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
}

/// 节点绑定结果，对应原版 llmControl.ts:302-315 NodeBindingsResult
struct NodeBindingsResult: Codable, Equatable {
    /// 节点 key（llmControl.ts:303）
    let nodeKey: String
    /// 节点名称（llmControl.ts:304）
    let nodeName: String
    /// 绑定列表（llmControl.ts:305-313）
    let bindings: [NodeBinding]
    /// 绑定数（llmControl.ts:314）
    let bindingCount: Int

    enum CodingKeys: String, CodingKey {
        case bindings
        case nodeKey = "node_key"
        case nodeName = "node_name"
        case bindingCount = "binding_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.nodeName = try c.decodeIfPresent(String.self, forKey: .nodeName) ?? ""
        self.bindings = try c.decodeIfPresent([NodeBinding].self, forKey: .bindings) ?? []
        self.bindingCount = try c.decodeIfPresent(Int.self, forKey: .bindingCount) ?? 0
    }
}

// MARK: - 广场初始化结果

/// 广场初始化结果，对应原版 llmControl.ts:350-354 PlazaInitResult
struct PlazaInitResult: Codable, Equatable {
    /// 统计信息（llmControl.ts:351）
    let stats: PromptStats
    /// 分类列表（llmControl.ts:352）
    let categories: [PromptCategoryInfo]
    /// 按分类分组的节点（llmControl.ts:353）
    let nodesByCategory: [String: [PromptNode]]

    enum CodingKeys: String, CodingKey {
        case stats, categories
        case nodesByCategory = "nodes_by_category"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stats = try c.decodeIfPresent(PromptStats.self, forKey: .stats) ?? PromptStats()
        self.categories = try c.decodeIfPresent([PromptCategoryInfo].self, forKey: .categories) ?? []
        self.nodesByCategory = try c.decodeIfPresent([String: [PromptNode]].self, forKey: .nodesByCategory) ?? [:]
    }
}

/// PromptStats 默认 init（用于 fallback）
extension PromptStats {
    init() {
        self.totalNodes = 0
        self.totalTemplates = 0
        self.totalVersions = 0
        self.builtinCount = 0
        self.customCount = 0
        self.categories = [:]
    }
}

// MARK: - 请求 Payload 类型

/// 更新提示词请求，对应原版 llmControl.ts:319-326 PromptUpdatePayload
struct PromptUpdatePayload: Codable {
    /// 系统提示（llmControl.ts:320，可选）
    let system: String?
    /// 用户模板（llmControl.ts:321，可选）
    let userTemplate: String?
    /// 名称（llmControl.ts:322，可选）
    let name: String?
    /// 描述（llmControl.ts:323，可选）
    let description: String?
    /// 标签（llmControl.ts:324，可选）
    let tags: [String]?
    /// 变更摘要（llmControl.ts:325，可选）
    let changeSummary: String?

    enum CodingKeys: String, CodingKey {
        case system, name, description, tags
        case userTemplate = "user_template"
        case changeSummary = "change_summary"
    }

    init(
        system: String? = nil,
        userTemplate: String? = nil,
        name: String? = nil,
        description: String? = nil,
        tags: [String]? = nil,
        changeSummary: String? = nil
    ) {
        self.system = system
        self.userTemplate = userTemplate
        self.name = name
        self.description = description
        self.tags = tags
        self.changeSummary = changeSummary
    }
}

/// 创建节点请求，对应原版 llmControl.ts:328-336 CreateNodePayload
struct CreateNodePayload: Codable {
    /// 模板 ID（llmControl.ts:329，可选）
    let templateId: String?
    /// 节点 key（llmControl.ts:330，可选）
    let nodeKey: String?
    /// 名称（llmControl.ts:331，必填）
    let name: String
    /// 描述（llmControl.ts:332，可选）
    let description: String?
    /// 分类（llmControl.ts:333，可选）
    let category: String?
    /// 系统提示（llmControl.ts:334，可选）
    let system: String?
    /// 用户模板（llmControl.ts:335，可选）
    let userTemplate: String?

    enum CodingKeys: String, CodingKey {
        case name, description, category, system
        case templateId = "template_id"
        case nodeKey = "node_key"
        case userTemplate = "user_template"
    }

    init(
        templateId: String? = nil,
        nodeKey: String? = nil,
        name: String,
        description: String? = nil,
        category: String? = nil,
        system: String? = nil,
        userTemplate: String? = nil
    ) {
        self.templateId = templateId
        self.nodeKey = nodeKey
        self.name = name
        self.description = description
        self.category = category
        self.system = system
        self.userTemplate = userTemplate
    }
}

/// 创建模板请求，对应原版 llmControl.ts:338-342 CreateTemplatePayload
struct CreateTemplatePayload: Codable {
    /// 名称（llmControl.ts:339，必填）
    let name: String
    /// 描述（llmControl.ts:340，可选）
    let description: String?
    /// 分类（llmControl.ts:341，可选）
    let category: String?

    enum CodingKeys: String, CodingKey {
        case name, description, category
    }

    init(name: String, description: String? = nil, category: String? = nil) {
        self.name = name
        self.description = description
        self.category = category
    }
}

/// 渲染请求，对应原版 llmControl.ts:344-346 RenderPayload
/// nodeKey 在 URL 路径中，不在请求体内
struct RenderPayload: Codable {
    /// 变量（llmControl.ts:345）
    let variables: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case variables
    }

    init(variables: [String: AnyCodable]) {
        self.variables = variables
    }
}

/// 调试请求体，对应原版 llmControl.ts:450-454 debugNode 请求体
/// { variables, validate_schemas: boolean }
struct DebugRequest: Codable {
    let variables: [String: AnyCodable]
    let validateSchemas: Bool

    enum CodingKeys: String, CodingKey {
        case variables
        case validateSchemas = "validate_schemas"
    }

    init(variables: [String: AnyCodable], validateSchemas: Bool = true) {
        self.variables = variables
        self.validateSchemas = validateSchemas
    }
}

/// 沙盒渲染请求，对应原版 llmControl.ts:462-465 sandboxRender 请求体
/// { system, user_template, variables }
struct SandboxRenderRequest: Codable {
    let system: String
    let userTemplate: String
    let variables: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case system, variables
        case userTemplate = "user_template"
    }

    init(system: String, userTemplate: String, variables: [String: AnyCodable]) {
        self.system = system
        self.userTemplate = userTemplate
        self.variables = variables
    }
}

// MARK: - API 响应包装结构体

/// 创建模板响应，对应原版 llmControl.ts:371 { status, template }
struct CreateTemplateResponse: Codable {
    let status: String
    let template: PromptTemplate
}

/// 创建节点响应，对应原版 llmControl.ts:393 { status, node }
struct CreateNodeResponse: Codable {
    let status: String
    let node: PromptNode
}

/// 删除节点响应，对应原版 llmControl.ts:397 { status, node_id }
struct DeleteNodeResponse: Codable {
    let status: String
    let nodeId: String

    enum CodingKeys: String, CodingKey {
        case status
        case nodeId = "node_id"
    }
}

/// 更新节点响应，对应原版 llmControl.ts:411 { status, node: PromptNode|null, message }
struct UpdateNodeResponse: Codable {
    let status: String
    let node: PromptNode?
    let message: String
}

/// 回滚节点响应，对应原版 llmControl.ts:417 { status, node, message }
struct RollbackNodeResponse: Codable {
    let status: String
    let node: PromptNode
    let message: String
}

/// 导入摘要，对应原版 llmControl.ts:442 summary { created, updated, skipped, total }
struct ImportSummary: Codable {
    let created: Int
    let updated: Int
    let skipped: Int
    let total: Int
}

/// 导入响应，对应原版 llmControl.ts:442 { status, summary, errors, message }
struct ImportResponse: Codable {
    let status: String
    let summary: ImportSummary
    let errors: [String]
    let message: String
}
