//
//  AutopilotModels.swift
//  Cangjie
//
//  自动驾驶模型，字段对齐后端 interfaces/api/v1/engine/autopilot_routes.py
//  状态响应字段来自 _build_autopilot_status_sync / _build_status_pure_memory。
//

import Foundation

// MARK: - 自动驾驶状态

/// 自动驾驶状态响应，对应后端 GET /autopilot/{id}/status 返回。
///
/// 后端返回字段较多（snake_case），此处涵盖核心字段。
/// 降级模式下后端可能省略部分字段，全部用 decodeIfPresent 防御。
struct AutopilotStatus: Codable, Equatable {

    /// 自动驾驶状态（stopped/running/paused/error）
    let autopilotStatus: String

    /// 当前阶段
    let currentStage: String

    /// 当前幕号（0-based）
    let currentAct: Int?

    /// 当前幕内章节号
    let currentChapterInAct: Int?

    /// 当前节拍索引
    let currentBeatIndex: Int

    /// 已生成章节数
    let currentAutoChapters: Int

    /// 最大自动章节数
    let maxAutoChapters: Int

    /// 目标总章数
    let targetChapters: Int

    /// 每章目标字数
    let targetWordsPerChapter: Int

    /// 计划总字数
    let targetPlanTotalWords: Int

    /// 上一章张力
    let lastChapterTension: Int

    /// 连续错误计数
    let consecutiveErrorCount: Int

    /// 总字数
    let totalWords: Int

    /// 已完成章节数
    let completedChapters: Int

    /// 进度百分比
    let progressPct: Double

    /// 书稿章节数
    let manuscriptChapters: Int

    /// 书稿进度百分比
    let progressPctManuscript: Double

    /// 当前章节号
    let currentChapterNumber: Int?

    /// 是否需要人工审阅
    let needsReview: Bool

    /// 宏观结构是否就绪
    let macroStructureReady: Bool?

    /// 全自动模式
    let autoApproveMode: Bool

    /// 审计进度
    let auditProgress: AnyCodable?

    /// 守护进程是否存活
    let daemonAlive: Bool?

    /// 守护进程心跳时间
    let daemonHeartbeatAt: Double?

    /// 是否降级模式
    let degraded: Bool?

    /// 写作子步骤
    let writingSubstep: String?

    /// 写作子步骤标签
    let writingSubstepLabel: String?

    /// 自动驾驶暂停原因
    let autopilotPauseReason: String?

    /// 上次审计信息
    let lastChapterAudit: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case autopilotStatus = "autopilot_status"
        case currentStage = "current_stage"
        case currentAct = "current_act"
        case currentChapterInAct = "current_chapter_in_act"
        case currentBeatIndex = "current_beat_index"
        case currentAutoChapters = "current_auto_chapters"
        case maxAutoChapters = "max_auto_chapters"
        case targetChapters = "target_chapters"
        case targetWordsPerChapter = "target_words_per_chapter"
        case targetPlanTotalWords = "target_plan_total_words"
        case lastChapterTension = "last_chapter_tension"
        case consecutiveErrorCount = "consecutive_error_count"
        case totalWords = "total_words"
        case completedChapters = "completed_chapters"
        case progressPct = "progress_pct"
        case manuscriptChapters = "manuscript_chapters"
        case progressPctManuscript = "progress_pct_manuscript"
        case currentChapterNumber = "current_chapter_number"
        case needsReview = "needs_review"
        case macroStructureReady = "macro_structure_ready"
        case autoApproveMode = "auto_approve_mode"
        case auditProgress = "audit_progress"
        case daemonAlive = "daemon_alive"
        case daemonHeartbeatAt = "daemon_heartbeat_at"
        case degraded = "_degraded"
        case writingSubstep = "writing_substep"
        case writingSubstepLabel = "writing_substep_label"
        case autopilotPauseReason = "autopilot_pause_reason"
        case lastChapterAudit = "last_chapter_audit"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.autopilotStatus = try c.decodeIfPresent(String.self, forKey: .autopilotStatus) ?? "stopped"
        self.currentStage = try c.decodeIfPresent(String.self, forKey: .currentStage) ?? ""
        self.currentAct = try c.decodeIfPresent(Int.self, forKey: .currentAct)
        self.currentChapterInAct = try c.decodeIfPresent(Int.self, forKey: .currentChapterInAct)
        self.currentBeatIndex = try c.decodeIfPresent(Int.self, forKey: .currentBeatIndex) ?? 0
        self.currentAutoChapters = try c.decodeIfPresent(Int.self, forKey: .currentAutoChapters) ?? 0
        self.maxAutoChapters = try c.decodeIfPresent(Int.self, forKey: .maxAutoChapters) ?? 9999
        self.targetChapters = try c.decodeIfPresent(Int.self, forKey: .targetChapters) ?? 0
        self.targetWordsPerChapter = try c.decodeIfPresent(Int.self, forKey: .targetWordsPerChapter) ?? 2500
        self.targetPlanTotalWords = try c.decodeIfPresent(Int.self, forKey: .targetPlanTotalWords) ?? 0
        self.lastChapterTension = try c.decodeIfPresent(Int.self, forKey: .lastChapterTension) ?? 0
        self.consecutiveErrorCount = try c.decodeIfPresent(Int.self, forKey: .consecutiveErrorCount) ?? 0
        self.totalWords = try c.decodeIfPresent(Int.self, forKey: .totalWords) ?? 0
        self.completedChapters = try c.decodeIfPresent(Int.self, forKey: .completedChapters) ?? 0
        self.progressPct = try c.decodeIfPresent(Double.self, forKey: .progressPct) ?? 0.0
        self.manuscriptChapters = try c.decodeIfPresent(Int.self, forKey: .manuscriptChapters) ?? 0
        self.progressPctManuscript = try c.decodeIfPresent(Double.self, forKey: .progressPctManuscript) ?? 0.0
        self.currentChapterNumber = try c.decodeIfPresent(Int.self, forKey: .currentChapterNumber)
        self.needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
        self.macroStructureReady = try c.decodeIfPresent(Bool.self, forKey: .macroStructureReady)
        self.autoApproveMode = try c.decodeIfPresent(Bool.self, forKey: .autoApproveMode) ?? false
        self.auditProgress = try c.decodeIfPresent(AnyCodable.self, forKey: .auditProgress)
        self.daemonAlive = try c.decodeIfPresent(Bool.self, forKey: .daemonAlive)
        self.daemonHeartbeatAt = try c.decodeIfPresent(Double.self, forKey: .daemonHeartbeatAt)
        self.degraded = try c.decodeIfPresent(Bool.self, forKey: .degraded)
        self.writingSubstep = try c.decodeIfPresent(String.self, forKey: .writingSubstep)
        self.writingSubstepLabel = try c.decodeIfPresent(String.self, forKey: .writingSubstepLabel)
        self.autopilotPauseReason = try c.decodeIfPresent(String.self, forKey: .autopilotPauseReason)
        self.lastChapterAudit = try c.decodeIfPresent(AnyCodable.self, forKey: .lastChapterAudit)
    }
}

// MARK: - 启动自动驾驶请求

/// 启动自动驾驶请求，对应后端 StartRequest
struct AutopilotStartRequest: Codable {
    let maxAutoChapters: Int?
    let targetChapters: Int?
    let targetWordsPerChapter: Int?

    enum CodingKeys: String, CodingKey {
        case maxAutoChapters = "max_auto_chapters"
        case targetChapters = "target_chapters"
        case targetWordsPerChapter = "target_words_per_chapter"
    }

    init(maxAutoChapters: Int? = 9999, targetChapters: Int? = nil, targetWordsPerChapter: Int? = nil) {
        self.maxAutoChapters = maxAutoChapters
        self.targetChapters = targetChapters
        self.targetWordsPerChapter = targetWordsPerChapter
    }
}

// MARK: - 熔断器状态

/// 熔断器状态（GET /autopilot/{id}/circuit-breaker）
struct CircuitBreakerStatus: Codable, Equatable {
    let state: String
    let failureCount: Int
    let threshold: Int
    let lastFailureAt: String?
    let resetTimeoutSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case state
        case failureCount = "failure_count"
        case threshold
        case lastFailureAt = "last_failure_at"
        case resetTimeoutSeconds = "reset_timeout_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.state = try c.decodeIfPresent(String.self, forKey: .state) ?? "closed"
        self.failureCount = try c.decodeIfPresent(Int.self, forKey: .failureCount) ?? 0
        self.threshold = try c.decodeIfPresent(Int.self, forKey: .threshold) ?? 5
        self.lastFailureAt = try c.decodeIfPresent(String.self, forKey: .lastFailureAt)
        self.resetTimeoutSeconds = try c.decodeIfPresent(Int.self, forKey: .resetTimeoutSeconds)
    }
}

// MARK: - SSE 流事件

/// 章节生成流元数据，对应 ChapterStreamEvent.metadata（config.ts:316-325）
struct ChapterStreamMetadata: Codable, Equatable {
    /// 章节号
    let chapterNumber: Int?
    /// 流式增量 chunk
    let chunk: String?
    /// 节拍索引
    let beatIndex: Int?
    /// 完整内容快照
    let content: String?
    /// 字数
    let wordCount: Int?
    /// 节拍列表
    let beats: [AnyCodable]?
    /// 大纲规划模式
    let outlinePlanMode: String?
    /// 总节拍数
    let totalBeats: Int?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case chunk
        case beatIndex = "beat_index"
        case content
        case wordCount = "word_count"
        case beats
        case outlinePlanMode = "outline_plan_mode"
        case totalBeats = "total_beats"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.chunk = try c.decodeIfPresent(String.self, forKey: .chunk)
        self.beatIndex = try c.decodeIfPresent(Int.self, forKey: .beatIndex)
        self.content = try c.decodeIfPresent(String.self, forKey: .content)
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount)
        self.beats = try c.decodeIfPresent([AnyCodable].self, forKey: .beats)
        self.outlinePlanMode = try c.decodeIfPresent(String.self, forKey: .outlinePlanMode)
        self.totalBeats = try c.decodeIfPresent(Int.self, forKey: .totalBeats)
    }
}

/// 章节生成流事件（data-only 格式，type 字段在 JSON data 中）
/// 对应 config.ts:303-326 的 ChapterStreamEvent 接口
/// 9 类事件：connected/outline_planning/beats_planned/chapter_start/chapter_chunk/chapter_content/autopilot_stopped/paused_for_review/heartbeat
struct ChapterStreamEvent: Codable, Equatable {
    /// 事件类型（9种值之一）
    let type: String
    /// 消息
    let message: String
    /// 时间戳
    let timestamp: String
    /// 元数据
    let metadata: ChapterStreamMetadata?

    enum CodingKeys: String, CodingKey {
        case type, message, timestamp, metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        self.metadata = try c.decodeIfPresent(ChapterStreamMetadata.self, forKey: .metadata)
    }
}

// MARK: - ChapterStreamEvent 类型常量（config.ts:304-313）

extension ChapterStreamEvent {
    /// 事件类型常量（config.ts:304-313）
    static let typeConnected = "connected"
    static let typeOutlinePlanning = "outline_planning"
    static let typeBeatsPlanned = "beats_planned"
    static let typeChapterStart = "chapter_start"
    static let typeChapterChunk = "chapter_chunk"
    static let typeChapterContent = "chapter_content"
    static let typeAutopilotStopped = "autopilot_stopped"
    static let typePausedForReview = "paused_for_review"
    static let typeHeartbeat = "heartbeat"
}

/// 日志流事件（data-only 格式）
struct LogStreamEvent: Codable, Equatable {
    let type: String
    let message: String?
    let timestamp: String?
    let seq: Int?
    let level: String?
    let chapterNumber: Int?

    enum CodingKeys: String, CodingKey {
        case type, message, timestamp, seq, level
        case chapterNumber = "chapter_number"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp)
        self.seq = try c.decodeIfPresent(Int.self, forKey: .seq)
        self.level = try c.decodeIfPresent(String.self, forKey: .level)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
    }
}

// MARK: - 系统资源

/// 系统资源响应（GET /autopilot/system/resources）
struct SystemResources: Codable, Equatable {
    let cpuPercent: Double?
    let memoryMb: Double?
    let diskUsageMb: Double?
    let uptimeSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case memoryMb = "memory_mb"
        case diskUsageMb = "disk_usage_mb"
        case uptimeSeconds = "uptime_seconds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.cpuPercent = dict["cpu_percent"]?.doubleValue
        self.memoryMb = dict["memory_mb"]?.doubleValue
        self.diskUsageMb = dict["disk_usage_mb"]?.doubleValue
        self.uptimeSeconds = dict["uptime_seconds"]?.doubleValue
    }
}
