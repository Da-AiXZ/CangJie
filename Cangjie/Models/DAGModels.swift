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
    let promptTemplate: String?
    let promptVariables: [String: String]
    let thresholds: [String: Double]
    let modelOverride: String?
    let maxRetries: Int
    let timeoutSeconds: Int
    let temperature: Double
    let maxTokens: Int?

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
    let config: NodeConfig?

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
    let nodes: [NodeDefinition]
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
