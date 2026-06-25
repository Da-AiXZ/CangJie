//
//  StorylineGraphModels.swift
//  Cangjie
//
//  故事线 Git Graph 数据模型，对齐原版 api/workflow.ts 的 StorylineGraphDataDTO/StorylineMergePointDTO/StorylineMilestoneDTO。
//

import Foundation

// MARK: - 故事线里程碑（workflow.ts:730-738 StorylineMilestoneDTO）

/// 故事线里程碑，对应原版 workflow.ts:730-738 `StorylineMilestoneDTO`
struct StorylineMilestoneDTO: Codable, Identifiable, Equatable {
    let order: Int
    let title: String
    let description: String?
    let targetChapterStart: Int
    let targetChapterEnd: Int
    let prerequisites: [String]
    let triggers: [String]

    var id: Int { order }

    enum CodingKeys: String, CodingKey {
        case order, title, description
        case targetChapterStart = "target_chapter_start"
        case targetChapterEnd = "target_chapter_end"
        case prerequisites, triggers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.targetChapterStart = try c.decodeIfPresent(Int.self, forKey: .targetChapterStart) ?? 0
        self.targetChapterEnd = try c.decodeIfPresent(Int.self, forKey: .targetChapterEnd) ?? 0
        self.prerequisites = try c.decodeIfPresent([String].self, forKey: .prerequisites) ?? []
        self.triggers = try c.decodeIfPresent([String].self, forKey: .triggers) ?? []
    }

    init(order: Int = 0, title: String = "", description: String? = nil,
         targetChapterStart: Int = 0, targetChapterEnd: Int = 0,
         prerequisites: [String] = [], triggers: [String] = []) {
        self.order = order
        self.title = title
        self.description = description
        self.targetChapterStart = targetChapterStart
        self.targetChapterEnd = targetChapterEnd
        self.prerequisites = prerequisites
        self.triggers = triggers
    }
}

// MARK: - 故事线合并点（workflow.ts:740-745 StorylineMergePointDTO）

/// 故事线合并点，对应原版 workflow.ts:740-745 `StorylineMergePointDTO`
struct StorylineMergePointDTO: Codable, Identifiable, Equatable {
    let chapterNumber: Int
    let storylineIds: [String]
    let mergeType: String  // 'convergence' | 'divergence'
    let description: String?

    var id: String { "\(chapterNumber)_\(storylineIds.sorted().joined(separator: ","))" }

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case storylineIds = "storyline_ids"
        case mergeType = "merge_type"
        case description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.storylineIds = try c.decodeIfPresent([String].self, forKey: .storylineIds) ?? []
        self.mergeType = try c.decodeIfPresent(String.self, forKey: .mergeType) ?? "convergence"
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
    }

    init(chapterNumber: Int = 0, storylineIds: [String] = [],
         mergeType: String = "convergence", description: String? = nil) {
        self.chapterNumber = chapterNumber
        self.storylineIds = storylineIds
        self.mergeType = mergeType
        self.description = description
    }
}

// MARK: - 故事线 Git Graph 数据（workflow.ts:747-752 StorylineGraphDataDTO）

/// 故事线 Git Graph 数据，对应原版 workflow.ts:747-752 `StorylineGraphDataDTO`
struct StorylineGraphDataDTO: Codable, Equatable {
    let storylines: [StorylineDTO]
    let mergePoints: [StorylineMergePointDTO]
    let totalChapters: Int

    enum CodingKeys: String, CodingKey {
        case storylines
        case mergePoints = "merge_points"
        case totalChapters = "total_chapters"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.storylines = try c.decodeIfPresent([StorylineDTO].self, forKey: .storylines) ?? []
        self.mergePoints = try c.decodeIfPresent([StorylineMergePointDTO].self, forKey: .mergePoints) ?? []
        self.totalChapters = try c.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 0
    }

    init(storylines: [StorylineDTO] = [], mergePoints: [StorylineMergePointDTO] = [], totalChapters: Int = 0) {
        self.storylines = storylines
        self.mergePoints = mergePoints
        self.totalChapters = totalChapters
    }
}

// MARK: - 章节结构（chapter.ts:ChapterStructureDTO）

/// 章节结构，对应原版 chapter.ts `ChapterStructureDTO`
///
/// ```typescript
/// interface ChapterStructureDTO {
///   word_count: number
///   paragraph_count: number
///   dialogue_ratio: number
///   scene_count: number
///   pacing: string
/// }
/// ```
struct ChapterStructureDTO: Codable, Equatable {
    let wordCount: Int
    let paragraphCount: Int
    let dialogueRatio: Double
    let sceneCount: Int
    let pacing: String

    enum CodingKeys: String, CodingKey {
        case wordCount = "word_count"
        case paragraphCount = "paragraph_count"
        case dialogueRatio = "dialogue_ratio"
        case sceneCount = "scene_count"
        case pacing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.paragraphCount = try c.decodeIfPresent(Int.self, forKey: .paragraphCount) ?? 0
        self.dialogueRatio = try c.decodeIfPresent(Double.self, forKey: .dialogueRatio) ?? 0.0
        self.sceneCount = try c.decodeIfPresent(Int.self, forKey: .sceneCount) ?? 0
        self.pacing = try c.decodeIfPresent(String.self, forKey: .pacing) ?? ""
    }

    init(wordCount: Int = 0, paragraphCount: Int = 0, dialogueRatio: Double = 0.0,
         sceneCount: Int = 0, pacing: String = "") {
        self.wordCount = wordCount
        self.paragraphCount = paragraphCount
        self.dialogueRatio = dialogueRatio
        self.sceneCount = sceneCount
        self.pacing = pacing
    }
}

// MARK: - 自动驾驶章节审计（ChapterStatusPanel.vue:259-276 AutopilotChapterAudit）

/// 自动驾驶章节审计，对应原版 ChapterStatusPanel.vue:259-276 `AutopilotChapterAudit`
struct AutopilotChapterAudit: Codable, Equatable {
    let chapterNumber: Int
    let tension: Int
    let driftAlert: Bool
    let similarityScore: Double?
    let narrativeSyncOk: Bool
    let vectorStored: Bool?
    let foreshadowStored: Bool?
    let triplesExtracted: Bool?
    let causalEdgesStored: Bool?
    let characterMutationsStored: Bool?
    let debtUpdated: Bool?
    let evolutionSnapshotOk: Bool?
    let characterReconcileOk: Bool?
    let qualityScores: [String: Double]?
    let issues: [AutopilotAuditIssue]?
    let at: String?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case tension
        case driftAlert = "drift_alert"
        case similarityScore = "similarity_score"
        case narrativeSyncOk = "narrative_sync_ok"
        case vectorStored = "vector_stored"
        case foreshadowStored = "foreshadow_stored"
        case triplesExtracted = "triples_extracted"
        case causalEdgesStored = "causal_edges_stored"
        case characterMutationsStored = "character_mutations_stored"
        case debtUpdated = "debt_updated"
        case evolutionSnapshotOk = "evolution_snapshot_ok"
        case characterReconcileOk = "character_reconcile_ok"
        case qualityScores = "quality_scores"
        case issues
        case at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.tension = try c.decodeIfPresent(Int.self, forKey: .tension) ?? 0
        self.driftAlert = try c.decodeIfPresent(Bool.self, forKey: .driftAlert) ?? false
        self.similarityScore = try c.decodeIfPresent(Double.self, forKey: .similarityScore)
        self.narrativeSyncOk = try c.decodeIfPresent(Bool.self, forKey: .narrativeSyncOk) ?? false
        self.vectorStored = try c.decodeIfPresent(Bool.self, forKey: .vectorStored)
        self.foreshadowStored = try c.decodeIfPresent(Bool.self, forKey: .foreshadowStored)
        self.triplesExtracted = try c.decodeIfPresent(Bool.self, forKey: .triplesExtracted)
        self.causalEdgesStored = try c.decodeIfPresent(Bool.self, forKey: .causalEdgesStored)
        self.characterMutationsStored = try c.decodeIfPresent(Bool.self, forKey: .characterMutationsStored)
        self.debtUpdated = try c.decodeIfPresent(Bool.self, forKey: .debtUpdated)
        self.evolutionSnapshotOk = try c.decodeIfPresent(Bool.self, forKey: .evolutionSnapshotOk)
        self.characterReconcileOk = try c.decodeIfPresent(Bool.self, forKey: .characterReconcileOk)
        self.qualityScores = try c.decodeIfPresent([String: Double].self, forKey: .qualityScores)
        self.issues = try c.decodeIfPresent([AutopilotAuditIssue].self, forKey: .issues)
        self.at = try c.decodeIfPresent(String.self, forKey: .at)
    }

    init(chapterNumber: Int = 0, tension: Int = 0, driftAlert: Bool = false,
         similarityScore: Double? = nil, narrativeSyncOk: Bool = false,
         vectorStored: Bool? = nil, foreshadowStored: Bool? = nil,
         triplesExtracted: Bool? = nil, causalEdgesStored: Bool? = nil,
         characterMutationsStored: Bool? = nil, debtUpdated: Bool? = nil,
         evolutionSnapshotOk: Bool? = nil, characterReconcileOk: Bool? = nil,
         qualityScores: [String: Double]? = nil, issues: [AutopilotAuditIssue]? = nil,
         at: String? = nil) {
        self.chapterNumber = chapterNumber
        self.tension = tension
        self.driftAlert = driftAlert
        self.similarityScore = similarityScore
        self.narrativeSyncOk = narrativeSyncOk
        self.vectorStored = vectorStored
        self.foreshadowStored = foreshadowStored
        self.triplesExtracted = triplesExtracted
        self.causalEdgesStored = causalEdgesStored
        self.characterMutationsStored = characterMutationsStored
        self.debtUpdated = debtUpdated
        self.evolutionSnapshotOk = evolutionSnapshotOk
        self.characterReconcileOk = characterReconcileOk
        self.qualityScores = qualityScores
        self.issues = issues
        self.at = at
    }
}

/// 审计问题项，对应原版 ChapterStatusPanel.vue:274 `{ severity: string; message: string }`
struct AutopilotAuditIssue: Codable, Identifiable, Equatable {
    let severity: String
    let message: String

    var id: String { "\(severity)_\(message)" }

    enum CodingKeys: String, CodingKey {
        case severity, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity) ?? "info"
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }

    init(severity: String = "info", message: String = "") {
        self.severity = severity
        self.message = message
    }
}

// MARK: - Cast Schedule 模型（cast.ts:73-96）

/// 选角合同项，对应原版 cast.ts:73-80 `ScheduledCharacterItem`
struct ScheduledCharacterItem: Codable, Identifiable, Equatable {
    let characterId: String
    let name: String
    let importance: String  // 'major' | 'normal' | 'minor'
    let isNewSuggestion: Bool
    let sceneFunction: String?
    let needsReview: Bool?

    var id: String { characterId }

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name, importance
        case isNewSuggestion = "is_new_suggestion"
        case sceneFunction = "scene_function"
        case needsReview = "needs_review"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characterId = try c.decodeIfPresent(String.self, forKey: .characterId) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.importance = try c.decodeIfPresent(String.self, forKey: .importance) ?? "normal"
        self.isNewSuggestion = try c.decodeIfPresent(Bool.self, forKey: .isNewSuggestion) ?? false
        self.sceneFunction = try c.decodeIfPresent(String.self, forKey: .sceneFunction)
        self.needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview)
    }

    init(characterId: String = "", name: String = "", importance: String = "normal",
         isNewSuggestion: Bool = false, sceneFunction: String? = nil, needsReview: Bool? = nil) {
        self.characterId = characterId
        self.name = name
        self.importance = importance
        self.isNewSuggestion = isNewSuggestion
        self.sceneFunction = sceneFunction
        self.needsReview = needsReview
    }
}

/// 选角调度请求，对应原版 cast.ts:82-87 `CastScheduleRequest`
struct CastScheduleRequest: Codable {
    let chapterNumber: Int
    let outline: String?
    let mode: String  // 'suggest' | 'apply'

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case outline, mode
    }

    init(chapterNumber: Int, outline: String? = nil, mode: String = "suggest") {
        self.chapterNumber = chapterNumber
        self.outline = outline
        self.mode = mode
    }
}

/// 选角调度响应，对应原版 cast.ts:89-96 `CastScheduleResponse`
struct CastScheduleResponse: Codable, Equatable {
    let chapterNumber: Int
    let cast: [ScheduledCharacterItem]
    let newCharacterHints: [String]
    let newCharacterCandidates: [AnyCodable]?
    let generatedContext: String?
    let schedulingLog: [String]?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case cast
        case newCharacterHints = "new_character_hints"
        case newCharacterCandidates = "new_character_candidates"
        case generatedContext = "generated_context"
        case schedulingLog = "scheduling_log"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.cast = try c.decodeIfPresent([ScheduledCharacterItem].self, forKey: .cast) ?? []
        self.newCharacterHints = try c.decodeIfPresent([String].self, forKey: .newCharacterHints) ?? []
        self.newCharacterCandidates = try c.decodeIfPresent([AnyCodable].self, forKey: .newCharacterCandidates)
        self.generatedContext = try c.decodeIfPresent(String.self, forKey: .generatedContext)
        self.schedulingLog = try c.decodeIfPresent([String].self, forKey: .schedulingLog)
    }

    init(chapterNumber: Int = 0, cast: [ScheduledCharacterItem] = [],
         newCharacterHints: [String] = [], newCharacterCandidates: [AnyCodable]? = nil,
         generatedContext: String? = nil, schedulingLog: [String]? = nil) {
        self.chapterNumber = chapterNumber
        self.cast = cast
        self.newCharacterHints = newCharacterHints
        self.newCharacterCandidates = newCharacterCandidates
        self.generatedContext = generatedContext
        self.schedulingLog = schedulingLog
    }
}

// MARK: - 快照回滚响应（chronicles.ts:SnapshotRollbackResponse）
// 声明已移至 SnapshotModels.swift（CI#29 修复：消除重复声明）
