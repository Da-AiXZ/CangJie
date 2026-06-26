//
//  JobModels.swift
//  Cangjie
//
//  任务管理模型，字段对齐原版 types/api.ts JobKind/JobStatus/JobCreateResponse/JobStatusResponse + LogEntry。
//

import Foundation

// MARK: - 任务类型

/// 任务类型，对应原版 types/api.ts JobKind = 'plan' | 'write' | 'run'
enum JobKind: String, Codable, Equatable {
    case plan
    case write
    case run
}

// MARK: - 任务状态

/// 任务状态，对应原版 types/api.ts JobStatus = 'queued' | 'running' | 'done' | 'error' | 'cancelled'
enum JobStatus: String, Codable, Equatable {
    case queued
    case running
    case done
    case error
    case cancelled

    /// 是否终态（不再变化）
    var isTerminal: Bool {
        switch self {
        case .done, .error, .cancelled:
            return true
        case .queued, .running:
            return false
        }
    }

    /// 中文显示名
    var displayName: String {
        switch self {
        case .queued: return "排队中"
        case .running: return "运行中"
        case .done: return "已完成"
        case .error: return "错误"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - 创建任务响应

/// 创建任务响应，对应原版 types/api.ts JobCreateResponse
struct JobCreateResponse: Codable, Equatable {
    let ok: Bool
    let jobId: String

    enum CodingKeys: String, CodingKey {
        case ok
        case jobId = "job_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        self.jobId = try c.decodeIfPresent(String.self, forKey: .jobId) ?? ""
    }

    init(ok: Bool = false, jobId: String = "") {
        self.ok = ok
        self.jobId = jobId
    }
}

// MARK: - 任务状态响应

/// 任务状态响应，对应原版 types/api.ts JobStatusResponse（11 字段）
struct JobStatusResponse: Codable, Identifiable, Equatable {
    var id: String { jobId }
    let jobId: String
    let kind: JobKind
    let slug: String
    let status: JobStatus
    let phase: String
    let message: String
    let error: String?
    let started: String?
    let finished: String?
    let done: Bool
    let ok: Bool

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case kind, slug, status, phase, message, error
        case started, finished, done, ok
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.jobId = try c.decodeIfPresent(String.self, forKey: .jobId) ?? ""
        self.kind = (try c.decodeIfPresent(String.self, forKey: .kind)).flatMap { JobKind(rawValue: $0) } ?? .run
        self.slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        self.status = (try c.decodeIfPresent(String.self, forKey: .status)).flatMap { JobStatus(rawValue: $0) } ?? .queued
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.started = try c.decodeIfPresent(String.self, forKey: .started)
        self.finished = try c.decodeIfPresent(String.self, forKey: .finished)
        self.done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
    }

    init(
        jobId: String = "",
        kind: JobKind = .run,
        slug: String = "",
        status: JobStatus = .queued,
        phase: String = "",
        message: String = "",
        error: String? = nil,
        started: String? = nil,
        finished: String? = nil,
        done: Bool = false,
        ok: Bool = false
    ) {
        self.jobId = jobId
        self.kind = kind
        self.slug = slug
        self.status = status
        self.phase = phase
        self.message = message
        self.error = error
        self.started = started
        self.finished = finished
        self.done = done
        self.ok = ok
    }
}

// MARK: - 日志条目

/// 日志条目，对应原版 types/api.ts LogEntry
struct LogEntry: Codable, Identifiable, Equatable {
    var id: String { "\(timestamp)-\(logger)-\(message.prefix(32))" }
    let timestamp: String
    let level: String
    let logger: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case timestamp, level, logger, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        self.level = try c.decodeIfPresent(String.self, forKey: .level) ?? "INFO"
        self.logger = try c.decodeIfPresent(String.self, forKey: .logger) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    init(timestamp: String = "", level: String = "INFO", logger: String = "", message: String = "") {
        self.timestamp = timestamp
        self.level = level
        self.logger = logger
        self.message = message
    }
}
