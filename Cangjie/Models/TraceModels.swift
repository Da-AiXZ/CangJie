//
//  TraceModels.swift
//  Cangjie
//
//  AI Trace 溯源模型，字段对齐后端 interfaces/api/v1/engine/trace_routes.py 的 DTO。
//

import Foundation

// MARK: - 引擎 Trace

/// 引擎 Trace，对应后端 TraceDTO
struct TraceDTO: Codable, Identifiable, Equatable {
    var id: String { traceId }
    let traceId: String
    let nodeType: String
    let operation: String
    let inputSummary: String
    let outputSummary: String
    let score: Double?
    let violations: [String]
    let durationMs: Int
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case nodeType = "node_type"
        case operation
        case inputSummary = "input_summary"
        case outputSummary = "output_summary"
        case score, violations
        case durationMs = "duration_ms"
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traceId = try c.decodeIfPresent(String.self, forKey: .traceId) ?? ""
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType) ?? ""
        self.operation = try c.decodeIfPresent(String.self, forKey: .operation) ?? ""
        self.inputSummary = try c.decodeIfPresent(String.self, forKey: .inputSummary) ?? ""
        self.outputSummary = try c.decodeIfPresent(String.self, forKey: .outputSummary) ?? ""
        self.score = try c.decodeIfPresent(Double.self, forKey: .score)
        self.violations = try c.decodeIfPresent([String].self, forKey: .violations) ?? []
        self.durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs) ?? 0
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }
}

/// Trace 列表响应
struct TraceListResponse: Codable, Equatable {
    let traces: [TraceDTO]
    let total: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traces = try c.decodeIfPresent([TraceDTO].self, forKey: .traces) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

/// Trace 统计
struct TraceStats: Codable, Equatable {
    let totalTraces: Int
    let byNodeType: [String: Int]
    let byOperation: [String: Int]
    let avgScore: Double?
    let avgDurationMs: Double

    enum CodingKeys: String, CodingKey {
        case totalTraces = "total_traces"
        case byNodeType = "by_node_type"
        case byOperation = "by_operation"
        case avgScore = "avg_score"
        case avgDurationMs = "avg_duration_ms"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalTraces = try c.decodeIfPresent(Int.self, forKey: .totalTraces) ?? 0
        self.byNodeType = try c.decodeIfPresent([String: Int].self, forKey: .byNodeType) ?? [:]
        self.byOperation = try c.decodeIfPresent([String: Int].self, forKey: .byOperation) ?? [:]
        self.avgScore = try c.decodeIfPresent(Double.self, forKey: .avgScore)
        self.avgDurationMs = try c.decodeIfPresent(Double.self, forKey: .avgDurationMs) ?? 0.0
    }
}

// MARK: - AI Trace

/// AI Trace 摘要，对应后端 AiTraceSummaryDTO
struct AiTraceSummary: Codable, Identifiable, Equatable {
    var id: String { traceId }
    let traceId: String
    let novelId: String
    let operation: String
    let startedAt: String
    let lastAt: String
    let spanCount: Int
    let errorCount: Int

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case novelId = "novel_id"
        case operation
        case startedAt = "started_at"
        case lastAt = "last_at"
        case spanCount = "span_count"
        case errorCount = "error_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traceId = try c.decodeIfPresent(String.self, forKey: .traceId) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.operation = try c.decodeIfPresent(String.self, forKey: .operation) ?? "ai_call"
        self.startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt) ?? ""
        self.lastAt = try c.decodeIfPresent(String.self, forKey: .lastAt) ?? ""
        self.spanCount = try c.decodeIfPresent(Int.self, forKey: .spanCount) ?? 0
        self.errorCount = try c.decodeIfPresent(Int.self, forKey: .errorCount) ?? 0
    }
}

/// AI Trace 列表响应
struct AiTraceListResponse: Codable, Equatable {
    let traces: [AiTraceSummary]
    let total: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traces = try c.decodeIfPresent([AiTraceSummary].self, forKey: .traces) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

// MARK: - AI Trace Span

/// AI Trace Span，对应后端 AiTraceSpanDTO
struct AiTraceSpan: Codable, Identifiable, Equatable {
    var id: String { spanId }
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let novelId: String
    let operation: String
    let phase: String
    let nodeId: String?
    let nodeType: String?
    let contractKey: String?
    let contractVersion: String?
    let source: String?
    let model: String?
    let generationProfile: String?
    let variablesHash: String?
    let variablesPreview: AnyCodable?
    let variablesFull: AnyCodable?
    let variableSources: AnyCodable?
    let promptHash: String?
    let promptPreview: AnyCodable?
    let promptFull: AnyCodable?
    let responseHash: String?
    let responsePreview: AnyCodable?
    let responseFull: AnyCodable?
    let tokenInput: Int?
    let tokenOutput: Int?
    let latencyMs: Int?
    let error: String?
    let metadata: [String: AnyCodable]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spanId = "span_id"
        case parentSpanId = "parent_span_id"
        case novelId = "novel_id"
        case operation, phase
        case nodeId = "node_id"
        case nodeType = "node_type"
        case contractKey = "contract_key"
        case contractVersion = "contract_version"
        case source, model
        case generationProfile = "generation_profile"
        case variablesHash = "variables_hash"
        case variablesPreview = "variables_preview"
        case variablesFull = "variables_full"
        case variableSources = "variable_sources"
        case promptHash = "prompt_hash"
        case promptPreview = "prompt_preview"
        case promptFull = "prompt_full"
        case responseHash = "response_hash"
        case responsePreview = "response_preview"
        case responseFull = "response_full"
        case tokenInput = "token_input"
        case tokenOutput = "token_output"
        case latencyMs = "latency_ms"
        case error, metadata
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traceId = try c.decodeIfPresent(String.self, forKey: .traceId) ?? ""
        self.spanId = try c.decodeIfPresent(String.self, forKey: .spanId) ?? ""
        self.parentSpanId = try c.decodeIfPresent(String.self, forKey: .parentSpanId)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.operation = try c.decodeIfPresent(String.self, forKey: .operation) ?? "ai_call"
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? ""
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId)
        self.nodeType = try c.decodeIfPresent(String.self, forKey: .nodeType)
        self.contractKey = try c.decodeIfPresent(String.self, forKey: .contractKey)
        self.contractVersion = try c.decodeIfPresent(String.self, forKey: .contractVersion)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.model = try c.decodeIfPresent(String.self, forKey: .model)
        self.generationProfile = try c.decodeIfPresent(String.self, forKey: .generationProfile)
        self.variablesHash = try c.decodeIfPresent(String.self, forKey: .variablesHash)
        self.variablesPreview = try c.decodeIfPresent(AnyCodable.self, forKey: .variablesPreview)
        self.variablesFull = try c.decodeIfPresent(AnyCodable.self, forKey: .variablesFull)
        self.variableSources = try c.decodeIfPresent(AnyCodable.self, forKey: .variableSources)
        self.promptHash = try c.decodeIfPresent(String.self, forKey: .promptHash)
        self.promptPreview = try c.decodeIfPresent(AnyCodable.self, forKey: .promptPreview)
        self.promptFull = try c.decodeIfPresent(AnyCodable.self, forKey: .promptFull)
        self.responseHash = try c.decodeIfPresent(String.self, forKey: .responseHash)
        self.responsePreview = try c.decodeIfPresent(AnyCodable.self, forKey: .responsePreview)
        self.responseFull = try c.decodeIfPresent(AnyCodable.self, forKey: .responseFull)
        self.tokenInput = try c.decodeIfPresent(Int.self, forKey: .tokenInput)
        self.tokenOutput = try c.decodeIfPresent(Int.self, forKey: .tokenOutput)
        self.latencyMs = try c.decodeIfPresent(Int.self, forKey: .latencyMs)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.metadata = try c.decodeIfPresent([String: AnyCodable].self, forKey: .metadata) ?? [:]
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

/// AI Trace 时间线响应
struct AiTraceTimelineResponse: Codable, Equatable {
    let traceId: String
    let spans: [AiTraceSpan]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case traceId = "trace_id"
        case spans, total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.traceId = try c.decodeIfPresent(String.self, forKey: .traceId) ?? ""
        self.spans = try c.decodeIfPresent([AiTraceSpan].self, forKey: .spans) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}
