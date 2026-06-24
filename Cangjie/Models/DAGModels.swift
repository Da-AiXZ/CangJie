//
//  DAGModels.swift
//  Cangjie
//
//  DAG 模型，字段对齐后端 application/engine/dag/models.py 的 Pydantic 模型。
//

import Foundation

// MARK: - 节点状态枚举

enum NodeStatus: String, Codable, CaseIterable {
    case idle
    case pending
    case running
    case success
    case warning
    case error
    case bypassed
    case disabled
    case completed
}

// MARK: - 节点分类枚举

enum NodeCategory: String, Codable, CaseIterable {
    case context
    case execution
    case validation
    case gateway
    case world
    case review
    case antiAI = "anti-ai"
    case planning
    case prop
}

// MARK: - 边条件枚举

enum EdgeCondition: String, Codable, CaseIterable {
    case onSuccess = "on_success"
    case onError = "on_error"
    case onDriftAlert = "on_drift_alert"
    case onNoDrift = "on_no_drift"
    case onBreakerOpen = "on_breaker_open"
    case onBreakerClosed = "on_breaker_closed"
    case onReviewApproved = "on_review_approved"
    case onReviewRejected = "on_review_rejected"
    case always
}

// MARK: - 端口数据类型

enum PortDataType: String, Codable, CaseIterable {
    case text
    case json
    case score
    case boolean
    case list
    case prompt
    case object
}

// MARK: - 节点端口

/// 节点端口，对应后端 NodePort
struct NodePort: Codable, Equatable {
    let name: String
    let dataType: String
    let required: Bool
    let `default`: AnyCodable?
    let description: String

    enum CodingKeys: String, CodingKey {
        case name
        case dataType = "data_type"
        case required
        case `default`
        case description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.dataType = try c.decodeIfPresent(String.self, forKey: .dataType) ?? "text"
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? true
        self.default = try c.decodeIfPresent(AnyCodable.self, forKey: .default)
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

// MARK: - 节点配置

/// 节点运行时配置，对应后端 NodeConfig
struct NodeConfig: Codable, Equatable {
    // 对齐 types/dag.ts:54-63 NodeConfig
    // var 而非 let：updateNodeConfig 需内存直接修改（对齐 dagStore.ts:290-305）
    var promptTemplate: String?
    var promptVariables: [String: String]
    var thresholds: [String: Double]
    var modelOverride: String?
    var maxRetries: Int
    var timeoutSeconds: Int
    var temperature: Double
    var maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTemplate = "prompt_template"
        case promptVariables = "prompt_variables"
        case thresholds
        case modelOverride = "model_override"
        case maxRetries = "max_retries"
        case timeoutSeconds = "timeout_seconds"
        case temperature
        case maxTokens = "max_tokens"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.promptTemplate = try c.decodeIfPresent(String.self, forKey: .promptTemplate)
        self.promptVariables = try c.decodeIfPresent([String: String].self, forKey: .promptVariables) ?? [:]
        self.thresholds = try c.decodeIfPresent([String: Double].self, forKey: .thresholds) ?? [:]
        self.modelOverride = try c.decodeIfPresent(String.self, forKey: .modelOverride)
        self.maxRetries = try c.decodeIfPresent(Int.self, forKey: .maxRetries) ?? 1
        self.timeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? 60
        self.temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.7
        self.maxTokens = try c.decodeIfPresent(Int.self, forKey: .maxTokens)
    }
}

// MARK: - 节点定义

/// DAG 中的节点实例定义，对应后端 NodeDefinition
struct NodeDefinition: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let label: String
    let position: [String: Double]
    let enabled: Bool
    // var 而非 let：updateNodeConfig 需内存直接修改（对齐 dagStore.ts:293-301）
    var config: NodeConfig?

    enum CodingKeys: String, CodingKey {
        case id, type, label, position, enabled, config
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.position = try c.decodeIfPresent([String: Double].self, forKey: .position) ?? ["x": 0, "y": 0]
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.config = try c.decodeIfPresent(NodeConfig.self, forKey: .config)
    }
}

// MARK: - 边定义

/// DAG 中的边定义，对应后端 EdgeDefinition
struct EdgeDefinition: Codable, Identifiable, Equatable {
    let id: String
    let source: String
    let sourcePort: String
    let target: String
    let targetPort: String
    let condition: String
    let animated: Bool

    enum CodingKeys: String, CodingKey {
        case id, source
        case sourcePort = "source_port"
        case target
        case targetPort = "target_port"
        case condition, animated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.sourcePort = try c.decodeIfPresent(String.self, forKey: .sourcePort) ?? ""
        self.target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        self.targetPort = try c.decodeIfPresent(String.self, forKey: .targetPort) ?? ""
        self.condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? "always"
        self.animated = try c.decodeIfPresent(Bool.self, forKey: .animated) ?? false
    }
}

// MARK: - DAG 元数据

/// DAG 元数据
struct DAGMetadata: Codable, Equatable {
    let createdAt: String
    let updatedAt: String
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        self.createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy) ?? "system"
    }
}

// MARK: - DAG 定义

/// DAG 完整定义，对应后端 DAGDefinition
struct DAGDefinition: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let version: Int
    let description: String
    // var 而非 let：updateNodeConfig 需内存直接修改节点 config（对齐 dagStore.ts:293-301）
    var nodes: [NodeDefinition]
    let edges: [EdgeDefinition]
    let metadata: DAGMetadata?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.nodes = try c.decodeIfPresent([NodeDefinition].self, forKey: .nodes) ?? []
        self.edges = try c.decodeIfPresent([EdgeDefinition].self, forKey: .edges) ?? []
        self.metadata = try c.decodeIfPresent(DAGMetadata.self, forKey: .metadata)
    }
}

// MARK: - 节点运行时状态

/// 节点运行时状态，对应后端 NodeRunState
struct NodeRunState: Codable, Equatable {
    let nodeId: String
    let status: String
    let startedAt: String?
    let completedAt: String?
    let durationMs: Int
    let outputs: AnyCodable
    let metrics: [String: Double]
    let error: String?
    let progress: Double

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case durationMs = "duration_ms"
        case outputs, metrics, error, progress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "idle"
        self.startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        self.completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        self.durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? 0
        self.outputs = try c.decodeIfPresent(AnyCodable.self, forKey: .outputs) ?? AnyCodable([:])
        self.metrics = try c.decodeIfPresent([String: Double].self, forKey: .metrics) ?? [:]
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
    }
}

// MARK: - DAG 运行状态响应

/// DAG 运行状态响应（GET /dag/{novel_id}/status）
struct DAGStatusResponse: Codable, Equatable {
    let novelId: String
    let dagEnabled: Bool
    let currentVersion: Int
    let nodeStates: [String: NodeRunState]

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case dagEnabled = "dag_enabled"
        case currentVersion = "current_version"
        case nodeStates = "node_states"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.dagEnabled = try c.decodeIfPresent(Bool.self, forKey: .dagEnabled) ?? true
        self.currentVersion = try c.decodeIfPresent(Int.self, forKey: .currentVersion) ?? 1
        self.nodeStates = try c.decodeIfPresent([String: NodeRunState].self, forKey: .nodeStates) ?? [:]
    }
}

// MARK: - DAG SSE 事件

/// DAG SSE 事件（event+data 格式），对应后端 NodeEvent
struct DAGEvent: Codable, Equatable {
    let type: String
    let novelId: String
    let nodeId: String?
    let timestamp: String?
    let status: String?
    let metrics: [String: AnyCodable]?
    let outputs: AnyCodable?
    let durationMs: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case type
        case novelId = "novel_id"
        case nodeId = "node_id"
        case timestamp, status, metrics, outputs
        case durationMs = "duration_ms"
        case error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId)
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.metrics = try c.decodeIfPresent([String: AnyCodable].self, forKey: .metrics)
        self.outputs = try c.decodeIfPresent(AnyCodable.self, forKey: .outputs)
        self.durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

// MARK: - DAG 健康检查

/// DAG 健康检查响应
struct DAGHealthResponse: Codable, Equatable {
    let status: String
    let checks: AnyCodable

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "ok"
        self.checks = try c.decodeIfPresent(AnyCodable.self, forKey: .checks) ?? AnyCodable([:])
    }
}

// MARK: - 节点元数据（对齐 types/dag.ts:32-50 NodeMeta）

/// 节点注册表元数据，GET /dag/registry/types 返回的 types 字典中的值。
/// 对齐 types/dag.ts:32-50
struct NodeMeta: Codable, Equatable {
    let nodeType: String
    let displayName: String
    let category: String
    let icon: String
    let color: String
    let inputPorts: [NodePort]
    let outputPorts: [NodePort]
    let promptTemplate: String
    let promptVariables: [String]
    let isConfigurable: Bool
    let canDisable: Bool
    let defaultTimeoutSeconds: Int
    let defaultMaxRetries: Int
    let cpmsNodeKey: String
    let description: String
    let defaultEdges: [String]

    enum CodingKeys: String, CodingKey {
        case nodeType = "node_type"
        case displayName = "display_name"
        case category
        case icon
        case color
        case inputPorts = "input_ports"
        case outputPorts = "output_ports"
        case promptTemplate = "prompt_template"
        case promptVariables = "prompt_variables"
        case isConfigurable = "is_configurable"
        case canDisable = "can_disable"
        case defaultTimeoutSeconds = "default_timeout_seconds"
        case defaultMaxRetries = "default_max_retries"
        case cpmsNodeKey = "cpms_node_key"
        case description
        case defaultEdges = "default_edges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        self.color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        self.inputPorts = try c.decodeIfPresent([NodePort].self, forKey: .inputPorts) ?? []
        self.outputPorts = try c.decodeIfPresent([NodePort].self, forKey: .outputPorts) ?? []
        self.promptTemplate = try c.decodeIfPresent(String.self, forKey: .promptTemplate) ?? ""
        self.promptVariables = try c.decodeIfPresent([String].self, forKey: .promptVariables) ?? []
        self.isConfigurable = try c.decodeIfPresent(Bool.self, forKey: .isConfigurable) ?? false
        self.canDisable = try c.decodeIfPresent(Bool.self, forKey: .canDisable) ?? true
        self.defaultTimeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .defaultTimeoutSeconds) ?? 60
        self.defaultMaxRetries = try c.decodeIfPresent(Int.self, forKey: .defaultMaxRetries) ?? 1
        self.cpmsNodeKey = try c.decodeIfPresent(String.self, forKey: .cpmsNodeKey) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.defaultEdges = try c.decodeIfPresent([String].self, forKey: .defaultEdges) ?? []
    }
}

// MARK: - 节点类型注册表响应（dagStore.ts:186-188 types 字段）

/// GET /dag/registry/types 返回的顶层结构 { types: Record<string, NodeMeta> }
struct NodeTypeRegistryResponse: Codable {
    let types: [String: NodeMeta]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.types = try c.decodeIfPresent([String: NodeMeta].self, forKey: .types) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case types
    }
}

// MARK: - 节点实时提示词（对齐 types/dag.ts:165-173 NodePromptLive）

/// GET /dag/{novel_id}/nodes/{node_id}/prompt-live 返回。
/// 对齐 types/dag.ts:165-173
struct NodePromptLive: Codable, Equatable {
    let nodeId: String
    let nodeType: String
    let cpmsNodeKey: String
    let system: String
    let userTemplate: String
    let source: String
    let variables: [String]

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case nodeType = "node_type"
        case cpmsNodeKey = "cpms_node_key"
        case system
        case userTemplate = "user_template"
        case source
        case variables
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.cpmsNodeKey = try c.decodeIfPresent(String.self, forKey: .cpmsNodeKey) ?? ""
        self.system = try c.decodeIfPresent(String.self, forKey: .system) ?? ""
        self.userTemplate = try c.decodeIfPresent(String.self, forKey: .userTemplate) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? "none"
        self.variables = try c.decodeIfPresent([String].self, forKey: .variables) ?? []
    }
}

// MARK: - DAG ↔ CPMS 联动（对齐 types/dag.ts:177-215）

/// CPMS 子键定义 — 对齐 types/dag.ts:177-182 DagLinkageSubKey
struct DagLinkageSubKey: Codable, Equatable {
    let cpmsNodeKey: String
    let targetVariable: String
    let description: String
    let required: Bool

    enum CodingKeys: String, CodingKey {
        case cpmsNodeKey = "cpms_node_key"
        case targetVariable = "target_variable"
        case description
        case required
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cpmsNodeKey = try c.decodeIfPresent(String.self, forKey: .cpmsNodeKey) ?? ""
        self.targetVariable = try c.decodeIfPresent(String.self, forKey: .targetVariable) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? false
    }
}

/// 联动节点行 — 对齐 types/dag.ts:184-194 DagLinkageNodeRow
struct DagLinkageNodeRow: Codable, Equatable {
    let nodeId: String
    let nodeType: String
    let label: String
    let enabledDefault: Bool
    let cpmsNodeKey: String
    let cpmsSubKeys: [DagLinkageSubKey]
    let promptMode: String
    let category: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case nodeType = "node_type"
        case label
        case enabledDefault = "enabled_default"
        case cpmsNodeKey = "cpms_node_key"
        case cpmsSubKeys = "cpms_sub_keys"
        case promptMode = "prompt_mode"
        case category
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.enabledDefault = try c.decodeIfPresent(Bool.self, forKey: .enabledDefault) ?? true
        self.cpmsNodeKey = try c.decodeIfPresent(String.self, forKey: .cpmsNodeKey) ?? ""
        self.cpmsSubKeys = try c.decodeIfPresent([DagLinkageSubKey].self, forKey: .cpmsSubKeys) ?? []
        self.promptMode = try c.decodeIfPresent(String.self, forKey: .promptMode) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    }
}

/// 注册表 CPMS 条目 — 对齐 types/dag.ts:196-202 RegistryCpmsEntry
struct RegistryCpmsEntry: Codable, Equatable {
    let cpmsNodeKey: String
    let cpmsSubKeys: [DagLinkageSubKey]
    let promptMode: String
    let category: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case cpmsNodeKey = "cpms_node_key"
        case cpmsSubKeys = "cpms_sub_keys"
        case promptMode = "prompt_mode"
        case category
        case displayName = "display_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cpmsNodeKey = try c.decodeIfPresent(String.self, forKey: .cpmsNodeKey) ?? ""
        self.cpmsSubKeys = try c.decodeIfPresent([DagLinkageSubKey].self, forKey: .cpmsSubKeys) ?? []
        self.promptMode = try c.decodeIfPresent(String.self, forKey: .promptMode) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
    }
}

/// 注册表缺口 — 对齐 types/dag.ts:204-207 DagRegistryGaps
struct DagRegistryGaps: Codable, Equatable {
    let complete: Bool
    let missing: [DagRegistryGapItem]

    enum CodingKeys: String, CodingKey {
        case complete
        case missing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.complete = try c.decodeIfPresent(Bool.self, forKey: .complete) ?? true
        self.missing = try c.decodeIfPresent([DagRegistryGapItem].self, forKey: .missing) ?? []
    }
}

/// 缺口项 — types/dag.ts:206
struct DagRegistryGapItem: Codable, Equatable, Identifiable {
    let nodeId: String
    let nodeType: String

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case nodeType = "node_type"
    }

    var id: String { nodeId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
    }
}

/// DAG ↔ CPMS 联动响应 — 对齐 types/dag.ts:209-215 DagRegistryLinkageResponse
struct DagRegistryLinkageResponse: Codable, Equatable {
    let pipelineNodeIds: [String]
    let nodes: [DagLinkageNodeRow]
    let registryCpmsByType: [String: RegistryCpmsEntry]
    let registryGaps: DagRegistryGaps?

    enum CodingKeys: String, CodingKey {
        case pipelineNodeIds = "pipeline_node_ids"
        case nodes
        case registryCpmsByType = "registry_cpms_by_type"
        case registryGaps = "registry_gaps"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pipelineNodeIds = try c.decodeIfPresent([String].self, forKey: .pipelineNodeIds) ?? []
        self.nodes = try c.decodeIfPresent([DagLinkageNodeRow].self, forKey: .nodes) ?? []
        self.registryCpmsByType = try c.decodeIfPresent([String: RegistryCpmsEntry].self, forKey: .registryCpmsByType) ?? [:]
        self.registryGaps = try c.decodeIfPresent(DagRegistryGaps.self, forKey: .registryGaps)
    }
}

// MARK: - 节点分类标签映射（对齐 types/dag.ts:226-231 CATEGORY_LABELS）

/// 节点分类 → 中文标签映射 — 对齐 types/dag.ts:226-231
let CATEGORY_LABELS: [String: String] = [
    "context": "上下文注入",
    "execution": "执行与生成",
    "validation": "校验与监控",
    "gateway": "网关与熔断",
]
