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

    // MARK: - T04 新增：写作遥测字段（对齐 NodeDetailPanel.vue:91-94）
    /// 累计章节字数 — accumulated_words
    let accumulatedWords: Int?
    /// 本章目标字数 — chapter_target_words
    let chapterTargetWords: Int?
    /// 上下文 token 数 — context_tokens
    let contextTokens: Int?

    // MARK: - 批次2 新增：StoryPipeline 可观测性字段（对齐 StoryPipelineObservability.vue:86-123 StatusLike）
    /// 当前管线波次索引（1-10）— story_pipeline_wave_index
    let storyPipelineWaveIndex: Int?
    /// 当前波次进入时间（unix timestamp）— story_pipeline_wave_entered_at
    let storyPipelineWaveEnteredAt: Double?
    /// 管线事件列表 — story_pipeline_events
    let storyPipelineEvents: [StoryPipelineEvent]?
    /// 章后管线实时状态 — aftermath_live_status ('running'|'done'|'failed'|null)
    let aftermathLiveStatus: String?
    /// 章后管线实时章节号 — aftermath_live_chapter_number
    let aftermathLiveChapterNumber: Int?
    /// 叙事同步是否OK — narrative_sync_ok
    let narrativeSyncOk: Bool?
    /// 向量是否已存储 — vector_stored
    let vectorStored: Bool?
    /// 伏笔是否已存储 — foreshadow_stored
    let foreshadowStored: Bool?
    /// 三元组是否已抽取 — triples_extracted
    let triplesExtracted: Bool?
    /// 因果边是否已存储 — causal_edges_stored
    let causalEdgesStored: Bool?
    /// 角色变更是否已存储 — character_mutations_stored
    let characterMutationsStored: Bool?
    /// 叙事债务是否已更新 — debt_updated
    let debtUpdated: Bool?
    /// 角色对账是否OK — character_reconcile_ok
    let characterReconcileOk: Bool?
    /// 演化快照是否OK — evolution_snapshot_ok
    let evolutionSnapshotOk: Bool?

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
        // T04 新增写作遥测字段 CodingKeys
        case accumulatedWords = "accumulated_words"
        case chapterTargetWords = "chapter_target_words"
        case contextTokens = "context_tokens"
        // 批次2 StoryPipeline 可观测性字段 CodingKeys
        case storyPipelineWaveIndex = "story_pipeline_wave_index"
        case storyPipelineWaveEnteredAt = "story_pipeline_wave_entered_at"
        case storyPipelineEvents = "story_pipeline_events"
        case aftermathLiveStatus = "aftermath_live_status"
        case aftermathLiveChapterNumber = "aftermath_live_chapter_number"
        case narrativeSyncOk = "narrative_sync_ok"
        case vectorStored = "vector_stored"
        case foreshadowStored = "foreshadow_stored"
        case triplesExtracted = "triples_extracted"
        case causalEdgesStored = "causal_edges_stored"
        case characterMutationsStored = "character_mutations_stored"
        case debtUpdated = "debt_updated"
        case characterReconcileOk = "character_reconcile_ok"
        case evolutionSnapshotOk = "evolution_snapshot_ok"
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
        // T04 新增写作遥测字段解码（对齐 NodeDetailPanel.vue:91-94）
        self.accumulatedWords = try c.decodeIfPresent(Int.self, forKey: .accumulatedWords)
        self.chapterTargetWords = try c.decodeIfPresent(Int.self, forKey: .chapterTargetWords)
        self.contextTokens = try c.decodeIfPresent(Int.self, forKey: .contextTokens)
        // 批次2 StoryPipeline 可观测性字段解码（对齐 StoryPipelineObservability.vue:86-123）
        self.storyPipelineWaveIndex = try c.decodeIfPresent(Int.self, forKey: .storyPipelineWaveIndex)
        self.storyPipelineWaveEnteredAt = try c.decodeIfPresent(Double.self, forKey: .storyPipelineWaveEnteredAt)
        self.storyPipelineEvents = try c.decodeIfPresent([StoryPipelineEvent].self, forKey: .storyPipelineEvents)
        self.aftermathLiveStatus = try c.decodeIfPresent(String.self, forKey: .aftermathLiveStatus)
        self.aftermathLiveChapterNumber = try c.decodeIfPresent(Int.self, forKey: .aftermathLiveChapterNumber)
        self.narrativeSyncOk = try c.decodeIfPresent(Bool.self, forKey: .narrativeSyncOk)
        self.vectorStored = try c.decodeIfPresent(Bool.self, forKey: .vectorStored)
        self.foreshadowStored = try c.decodeIfPresent(Bool.self, forKey: .foreshadowStored)
        self.triplesExtracted = try c.decodeIfPresent(Bool.self, forKey: .triplesExtracted)
        self.causalEdgesStored = try c.decodeIfPresent(Bool.self, forKey: .causalEdgesStored)
        self.characterMutationsStored = try c.decodeIfPresent(Bool.self, forKey: .characterMutationsStored)
        self.debtUpdated = try c.decodeIfPresent(Bool.self, forKey: .debtUpdated)
        self.characterReconcileOk = try c.decodeIfPresent(Bool.self, forKey: .characterReconcileOk)
        self.evolutionSnapshotOk = try c.decodeIfPresent(Bool.self, forKey: .evolutionSnapshotOk)
    }
}

// MARK: - StoryPipeline 事件（对齐 StoryPipelineObservability.vue:89-95）

/// 管线事件，对应原版 StatusLike.story_pipeline_events 数组项
///
/// ```typescript
/// { t: number; wave?: number; wave_id?: string; substep?: string; label?: string }
/// ```
struct StoryPipelineEvent: Codable, Equatable {
    /// 时间戳（unix seconds）— :90 t
    let t: Double
    /// 波次号 — :91 wave
    let wave: Int?
    /// 波次ID — :92 wave_id
    let waveId: String?
    /// 子步骤 — :93 substep
    let substep: String?
    /// 标签 — :94 label
    let label: String?

    enum CodingKeys: String, CodingKey {
        case t, wave
        case waveId = "wave_id"
        case substep, label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.t = try c.decodeIfPresent(Double.self, forKey: .t) ?? 0
        self.wave = try c.decodeIfPresent(Int.self, forKey: .wave)
        self.waveId = try c.decodeIfPresent(String.self, forKey: .waveId)
        self.substep = try c.decodeIfPresent(String.self, forKey: .substep)
        self.label = try c.decodeIfPresent(String.self, forKey: .label)
    }

    init(t: Double = 0, wave: Int? = nil, waveId: String? = nil, substep: String? = nil, label: String? = nil) {
        self.t = t
        self.wave = wave
        self.waveId = waveId
        self.substep = substep
        self.label = label
    }
}

// MARK: - StoryPipeline 十步波次常量（对齐 constants/storyPipelineWaves.ts:4-19）

/// StoryPipeline 十步波次定义，对齐原版 `constants/storyPipelineWaves.ts:4-19` STORY_PIPELINE_WAVES
struct StoryPipelineWave: Identifiable, Equatable {
    let index: Int
    let id: String
    let label: String
}

/// 十步波次常量 — storyPipelineWaves.ts:8-19
let STORY_PIPELINE_WAVES: [StoryPipelineWave] = [
    StoryPipelineWave(index: 1, id: "find_chapter", label: "章节定位"),
    StoryPipelineWave(index: 2, id: "build_context", label: "组装上下文"),
    StoryPipelineWave(index: 3, id: "generate_script", label: "剧本生成"),
    StoryPipelineWave(index: 4, id: "generate_prose", label: "正文撰写"),
    StoryPipelineWave(index: 5, id: "validate_policy", label: "策略校验"),
    StoryPipelineWave(index: 6, id: "persist_chapter", label: "章节落盘"),
    StoryPipelineWave(index: 7, id: "voice_audit", label: "文风审计"),
    StoryPipelineWave(index: 8, id: "aftermath", label: "章后管线"),
    StoryPipelineWave(index: 9, id: "score_tension", label: "张力打分"),
    StoryPipelineWave(index: 10, id: "finalize", label: "收尾"),
]

// MARK: - 启动自动驾驶请求

/// 启动自动驾驶请求，对应原版 autopilot.ts:12-16 AutopilotStartRequest
/// 三字段全部 required（非 Optional），默认值对齐原版 AutopilotPanel.vue:358-363
struct AutopilotStartRequest: Codable {
    /// 最大自动章节数（autopilot.ts:13，原版默认 120）
    let maxAutoChapters: Int
    /// 目标章数（autopilot.ts:14，原版默认 100）
    let targetChapters: Int
    /// 每章目标字数（autopilot.ts:15，原版默认 2500）
    let targetWordsPerChapter: Int

    enum CodingKeys: String, CodingKey {
        case maxAutoChapters = "max_auto_chapters"
        case targetChapters = "target_chapters"
        case targetWordsPerChapter = "target_words_per_chapter"
    }

    init(maxAutoChapters: Int = 120, targetChapters: Int = 100, targetWordsPerChapter: Int = 2500) {
        self.maxAutoChapters = maxAutoChapters
        self.targetChapters = targetChapters
        self.targetWordsPerChapter = targetWordsPerChapter
    }
}

// MARK: - 熔断器错误记录

/// 熔断器错误记录，对应原版 autopilot.ts:24-28 AutopilotErrorRecord
struct AutopilotErrorRecord: Codable, Equatable {
    /// 错误消息（autopilot.ts:25）
    let message: String
    /// 错误时间戳（autopilot.ts:26）
    let timestamp: String
    /// 错误上下文（autopilot.ts:27，可选）
    let context: String?

    enum CodingKeys: String, CodingKey {
        case message, timestamp, context
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        self.context = try c.decodeIfPresent(String.self, forKey: .context)
    }
}

// MARK: - 熔断器状态

/// 熔断器状态，对应原版 autopilot.ts:30-36 AutopilotCircuitBreakerData
/// GET /autopilot/{id}/circuit-breaker 返回
struct AutopilotCircuitBreakerData: Codable, Equatable {
    /// 熔断状态：closed/open/half_open（autopilot.ts:31）
    let status: String
    /// 错误计数（autopilot.ts:32）
    let errorCount: Int
    /// 最大错误数阈值（autopilot.ts:33）
    let maxErrors: Int
    /// 最近一次错误记录（autopilot.ts:34，可选嵌套对象）
    let lastError: AutopilotErrorRecord?
    /// 错误历史记录（autopilot.ts:35，可选数组）
    let errorHistory: [AutopilotErrorRecord]?

    enum CodingKeys: String, CodingKey {
        case status
        case errorCount = "error_count"
        case maxErrors = "max_errors"
        case lastError = "last_error"
        case errorHistory = "error_history"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "closed"
        self.errorCount = try c.decodeIfPresent(Int.self, forKey: .errorCount) ?? 0
        self.maxErrors = try c.decodeIfPresent(Int.self, forKey: .maxErrors) ?? 5
        self.lastError = try c.decodeIfPresent(AutopilotErrorRecord.self, forKey: .lastError)
        self.errorHistory = try c.decodeIfPresent([AutopilotErrorRecord].self, forKey: .errorHistory)
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
