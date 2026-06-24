//
//  AIInvocationModels.swift
//  Cangjie
//
//  AI Invocation 审批系统数据模型。
//  对齐原版 aiInvocation.ts:1-256 全部模型、枚举、Payload。
//  机制4：每个模型标注原版文件+行号。
//

import Foundation

// MARK: - 枚举（aiInvocation.ts:5-27）

/// Invocation 策略枚举 — aiInvocation.ts:5-11
enum InvocationPolicy: String, Codable, CaseIterable {
    case direct = "DIRECT"
    case reviewBeforeCall = "REVIEW_BEFORE_CALL"
    case reviewAfterCall = "REVIEW_AFTER_CALL"
    case fullInteractive = "FULL_INTERACTIVE"
    case interactiveWhenAvailable = "INTERACTIVE_WHEN_AVAILABLE"
    case autopilotPause = "AUTOPILOT_PAUSE"
}

/// Invocation 会话状态枚举（14种） — aiInvocation.ts:13-27
/// 注意：原版有14种（含 cancelled），PRD写"13种"有误，以原版为准。
enum InvocationSessionStatus: String, Codable, CaseIterable {
    case requested
    case specResolved = "spec_resolved"
    case contextResolved = "context_resolved"
    case variablesResolved = "variables_resolved"
    case promptCompiled = "prompt_compiled"
    case awaitingPreCallReview = "awaiting_pre_call_review"
    case generating
    case awaitingAcceptance = "awaiting_acceptance"
    case awaitingCommit = "awaiting_commit"
    case committing
    case completed
    case blocked
    case failed
    case cancelled
}

// MARK: - 提示词快照（aiInvocation.ts:29-54）

/// 提示词对（system + user）
/// aiInvocation.ts:30-32, 34-36, 38-40
struct InvocationPromptPair: Codable, Equatable {
    let system: String?
    let user: String?

    init(system: String? = nil, user: String? = nil) {
        self.system = system
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.system = try c.decodeIfPresent(String.self, forKey: .system)
        self.user = try c.decodeIfPresent(String.self, forKey: .user)
    }
}

/// Invocation 提示词快照 — aiInvocation.ts:29-54
struct InvocationPromptSnapshot: Codable, Equatable {
    var prompt: InvocationPromptPair?
    var templatePrompt: InvocationPromptPair?
    var draftPrompt: InvocationPromptPair?
    var nodeKey: String?
    var nodeVersionId: String?
    var assetLinkSetId: String?
    var inputBindingSetId: String?
    var outputBindingSetId: String?
    var variableSnapshotHash: String?
    var templateHash: String?
    var compositionHash: String?
    var renderedPromptHash: String?
    var missingVariables: [String]?
    var diagnostics: [String]?
    var assetVersionIds: [String]?

    enum CodingKeys: String, CodingKey {
        case prompt
        case templatePrompt = "template_prompt"
        case draftPrompt = "draft_prompt"
        case nodeKey = "node_key"
        case nodeVersionId = "node_version_id"
        case assetLinkSetId = "asset_link_set_id"
        case inputBindingSetId = "input_binding_set_id"
        case outputBindingSetId = "output_binding_set_id"
        case variableSnapshotHash = "variable_snapshot_hash"
        case templateHash = "template_hash"
        case compositionHash = "composition_hash"
        case renderedPromptHash = "rendered_prompt_hash"
        case missingVariables = "missing_variables"
        case diagnostics
        case assetVersionIds = "asset_version_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.prompt = try c.decodeIfPresent(InvocationPromptPair.self, forKey: .prompt)
        self.templatePrompt = try c.decodeIfPresent(InvocationPromptPair.self, forKey: .templatePrompt)
        self.draftPrompt = try c.decodeIfPresent(InvocationPromptPair.self, forKey: .draftPrompt)
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey)
        self.nodeVersionId = try c.decodeIfPresent(String.self, forKey: .nodeVersionId)
        self.assetLinkSetId = try c.decodeIfPresent(String.self, forKey: .assetLinkSetId)
        self.inputBindingSetId = try c.decodeIfPresent(String.self, forKey: .inputBindingSetId)
        self.outputBindingSetId = try c.decodeIfPresent(String.self, forKey: .outputBindingSetId)
        self.variableSnapshotHash = try c.decodeIfPresent(String.self, forKey: .variableSnapshotHash)
        self.templateHash = try c.decodeIfPresent(String.self, forKey: .templateHash)
        self.compositionHash = try c.decodeIfPresent(String.self, forKey: .compositionHash)
        self.renderedPromptHash = try c.decodeIfPresent(String.self, forKey: .renderedPromptHash)
        self.missingVariables = try c.decodeIfPresent([String].self, forKey: .missingVariables)
        self.diagnostics = try c.decodeIfPresent([String].self, forKey: .diagnostics)
        self.assetVersionIds = try c.decodeIfPresent([String].self, forKey: .assetVersionIds)
    }

    init() {
        self.prompt = nil
        self.templatePrompt = nil
        self.draftPrompt = nil
        self.nodeKey = nil
        self.nodeVersionId = nil
        self.assetLinkSetId = nil
        self.inputBindingSetId = nil
        self.outputBindingSetId = nil
        self.variableSnapshotHash = nil
        self.templateHash = nil
        self.compositionHash = nil
        self.renderedPromptHash = nil
        self.missingVariables = nil
        self.diagnostics = nil
        self.assetVersionIds = nil
    }
}

// MARK: - 变量计划（aiInvocation.ts:56-120）

/// 变量解析项 — aiInvocation.ts:68-79
struct InvocationVariableResolutionItem: Codable, Equatable {
    var alias: String?
    var variableKey: String?
    var displayName: String?
    var status: String?
    var currentValue: AnyCodable?
    var valueType: String?
    var versionNumber: Int?
    var source: String?
    var contextKey: String?
    var required: Bool?

    enum CodingKeys: String, CodingKey {
        case alias
        case variableKey = "variable_key"
        case displayName = "display_name"
        case status
        case currentValue = "current_value"
        case valueType = "value_type"
        case versionNumber = "version_number"
        case source
        case contextKey = "context_key"
        case required
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.alias = try c.decodeIfPresent(String.self, forKey: .alias)
        self.variableKey = try c.decodeIfPresent(String.self, forKey: .variableKey)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.currentValue = try c.decodeIfPresent(AnyCodable.self, forKey: .currentValue)
        self.valueType = try c.decodeIfPresent(String.self, forKey: .valueType)
        self.versionNumber = try c.decodeIfPresent(Int.self, forKey: .versionNumber)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.contextKey = try c.decodeIfPresent(String.self, forKey: .contextKey)
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required)
    }
}

/// 变量绑定 — aiInvocation.ts:81-97
struct InvocationVariableBinding: Codable, Equatable, Identifiable {
    var id: String { alias }
    var alias: String
    var variableKey: String?
    var required: Bool?
    var defaultValue: AnyCodable?
    var source: String?
    var enabled: Bool?
    var valueType: String?
    var scope: String?
    var stage: String?
    var displayName: String?
    var targetDisplayName: String?
    var sourcePath: String?
    var projectionKey: String?
    var renderMode: String?
    var previewSource: String?

    enum CodingKeys: String, CodingKey {
        case alias
        case variableKey = "variable_key"
        case required
        case defaultValue = "default"
        case source
        case enabled
        case valueType = "value_type"
        case scope
        case stage
        case displayName = "display_name"
        case targetDisplayName = "target_display_name"
        case sourcePath = "source_path"
        case projectionKey = "projection_key"
        case renderMode = "render_mode"
        case previewSource = "preview_source"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.alias = try c.decodeIfPresent(String.self, forKey: .alias) ?? ""
        self.variableKey = try c.decodeIfPresent(String.self, forKey: .variableKey)
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required)
        self.defaultValue = try c.decodeIfPresent(AnyCodable.self, forKey: .defaultValue)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        self.valueType = try c.decodeIfPresent(String.self, forKey: .valueType)
        self.scope = try c.decodeIfPresent(String.self, forKey: .scope)
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.targetDisplayName = try c.decodeIfPresent(String.self, forKey: .targetDisplayName)
        self.sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
        self.projectionKey = try c.decodeIfPresent(String.self, forKey: .projectionKey)
        self.renderMode = try c.decodeIfPresent(String.self, forKey: .renderMode)
        self.previewSource = try c.decodeIfPresent(String.self, forKey: .previewSource)
    }

    init(alias: String) {
        self.alias = alias
        self.variableKey = nil
        self.required = nil
        self.defaultValue = nil
        self.source = nil
        self.enabled = nil
        self.valueType = nil
        self.scope = nil
        self.stage = nil
        self.displayName = nil
        self.targetDisplayName = nil
        self.sourcePath = nil
        self.projectionKey = nil
        self.renderMode = nil
        self.previewSource = nil
    }
}

/// 变量快照项 — aiInvocation.ts:99-112
struct InvocationVariableSnapshotItem: Codable, Equatable {
    var key: String?
    var displayName: String?
    var value: AnyCodable?
    var type: String?
    var scope: String?
    var stage: String?
    var source: String?
    var variableKey: String?
    var required: Bool?
    var sourcePath: String?
    var projectionKey: String?
    var renderMode: String?

    enum CodingKeys: String, CodingKey {
        case key
        case displayName = "display_name"
        case value
        case type, scope, stage, source
        case variableKey = "variable_key"
        case required
        case sourcePath = "source_path"
        case projectionKey = "projection_key"
        case renderMode = "render_mode"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.value = try c.decodeIfPresent(AnyCodable.self, forKey: .value)
        self.type = try c.decodeIfPresent(String.self, forKey: .type)
        self.scope = try c.decodeIfPresent(String.self, forKey: .scope)
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.variableKey = try c.decodeIfPresent(String.self, forKey: .variableKey)
        self.required = try c.decodeIfPresent(Bool.self, forKey: .required)
        self.sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
        self.projectionKey = try c.decodeIfPresent(String.self, forKey: .projectionKey)
        self.renderMode = try c.decodeIfPresent(String.self, forKey: .renderMode)
    }
}

/// 变量快照分组 — aiInvocation.ts:114-120
struct InvocationVariableSnapshotGroup: Codable, Equatable, Identifiable {
    var id: String { groupId ?? "\(scope ?? "")_\(stage ?? "")_\(title ?? "")" }
    var groupId: String?
    var scope: String?
    var stage: String?
    var title: String?
    var items: [InvocationVariableSnapshotItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case scope, stage, title, items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.groupId = try c.decodeIfPresent(String.self, forKey: .id)
        self.scope = try c.decodeIfPresent(String.self, forKey: .scope)
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.items = try c.decodeIfPresent([InvocationVariableSnapshotItem].self, forKey: .items)
    }
}

/// 变量计划 — aiInvocation.ts:56-66
struct InvocationVariablePlan: Codable, Equatable {
    var aliases: [String: AnyCodable]?
    var resolutionItems: [InvocationVariableResolutionItem]?
    var requiredMissing: [String]?
    var diagnostics: [String]?
    var lineage: [String: String]?
    var snapshotHash: String?
    var snapshotItems: [InvocationVariableSnapshotItem]?
    var snapshotGroups: [InvocationVariableSnapshotGroup]?
    var bindings: [InvocationVariableBinding]?

    enum CodingKeys: String, CodingKey {
        case aliases
        case resolutionItems = "resolution_items"
        case requiredMissing = "required_missing"
        case diagnostics
        case lineage
        case snapshotHash = "snapshot_hash"
        case snapshotItems = "snapshot_items"
        case snapshotGroups = "snapshot_groups"
        case bindings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.aliases = try c.decodeIfPresent([String: AnyCodable].self, forKey: .aliases)
        self.resolutionItems = try c.decodeIfPresent([InvocationVariableResolutionItem].self, forKey: .resolutionItems)
        self.requiredMissing = try c.decodeIfPresent([String].self, forKey: .requiredMissing)
        self.diagnostics = try c.decodeIfPresent([String].self, forKey: .diagnostics)
        self.lineage = try c.decodeIfPresent([String: String].self, forKey: .lineage)
        self.snapshotHash = try c.decodeIfPresent(String.self, forKey: .snapshotHash)
        self.snapshotItems = try c.decodeIfPresent([InvocationVariableSnapshotItem].self, forKey: .snapshotItems)
        self.snapshotGroups = try c.decodeIfPresent([InvocationVariableSnapshotGroup].self, forKey: .snapshotGroups)
        self.bindings = try c.decodeIfPresent([InvocationVariableBinding].self, forKey: .bindings)
    }

    init() {
        self.aliases = nil
        self.resolutionItems = nil
        self.requiredMissing = nil
        self.diagnostics = nil
        self.lineage = nil
        self.snapshotHash = nil
        self.snapshotItems = nil
        self.snapshotGroups = nil
        self.bindings = nil
    }
}

// MARK: - Session / Attempt / Decision / Commit（aiInvocation.ts:122-178）

/// Invocation Session DTO — aiInvocation.ts:122-134
struct InvocationSessionDTO: Codable, Equatable, Identifiable {
    var id: String
    var operation: String
    var nodeKey: String
    var policy: String
    var status: String
    var context: [String: AnyCodable]?
    var metadata: [String: AnyCodable]?
    var attempts: [String]?
    var promptSnapshot: InvocationPromptSnapshot?
    var variablePlan: InvocationVariablePlan?
    var outputBindings: [InvocationVariableBinding]?

    enum CodingKeys: String, CodingKey {
        case id, operation
        case nodeKey = "node_key"
        case policy, status, context, metadata, attempts
        case promptSnapshot = "prompt_snapshot"
        case variablePlan = "variable_plan"
        case outputBindings = "output_bindings"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.operation = try c.decodeIfPresent(String.self, forKey: .operation) ?? ""
        self.nodeKey = try c.decodeIfPresent(String.self, forKey: .nodeKey) ?? ""
        self.policy = try c.decodeIfPresent(String.self, forKey: .policy) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.context = try c.decodeIfPresent([String: AnyCodable].self, forKey: .context)
        self.metadata = try c.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        self.attempts = try c.decodeIfPresent([String].self, forKey: .attempts)
        self.promptSnapshot = try c.decodeIfPresent(InvocationPromptSnapshot.self, forKey: .promptSnapshot)
        self.variablePlan = try c.decodeIfPresent(InvocationVariablePlan.self, forKey: .variablePlan)
        self.outputBindings = try c.decodeIfPresent([InvocationVariableBinding].self, forKey: .outputBindings)
    }

    init() {
        self.id = ""
        self.operation = ""
        self.nodeKey = ""
        self.policy = ""
        self.status = ""
        self.context = nil
        self.metadata = nil
        self.attempts = nil
        self.promptSnapshot = nil
        self.variablePlan = nil
        self.outputBindings = nil
    }
}

/// Invocation Attempt DTO — aiInvocation.ts:136-142
struct InvocationAttemptDTO: Codable, Equatable, Identifiable {
    var id: String
    var sessionId: String
    var status: String
    var content: String
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case status, content, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// Adoption Decision DTO — aiInvocation.ts:144-153
struct AdoptionDecisionDTO: Codable, Equatable, Identifiable {
    var id: String
    var sessionId: String
    var attemptId: String
    var decision: String
    var acceptContent: Bool
    var commitPromptVersion: Bool
    var commitVariableOutputs: Bool
    var commitVariableBindings: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case attemptId = "attempt_id"
        case decision
        case acceptContent = "accept_content"
        case commitPromptVersion = "commit_prompt_version"
        case commitVariableOutputs = "commit_variable_outputs"
        case commitVariableBindings = "commit_variable_bindings"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        self.attemptId = try c.decodeIfPresent(String.self, forKey: .attemptId) ?? ""
        self.decision = try c.decodeIfPresent(String.self, forKey: .decision) ?? ""
        self.acceptContent = try c.decodeIfPresent(Bool.self, forKey: .acceptContent) ?? false
        self.commitPromptVersion = try c.decodeIfPresent(Bool.self, forKey: .commitPromptVersion) ?? false
        self.commitVariableOutputs = try c.decodeIfPresent(Bool.self, forKey: .commitVariableOutputs) ?? false
        self.commitVariableBindings = try c.decodeIfPresent(Bool.self, forKey: .commitVariableBindings) ?? false
    }
}

/// Adoption Commit Step DTO — aiInvocation.ts:155-160
struct AdoptionCommitStepDTO: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var status: String
    var result: [String: AnyCodable]?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case name, status, result, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.result = try c.decodeIfPresent([String: AnyCodable].self, forKey: .result)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// Adoption Commit DTO — aiInvocation.ts:162-170
struct AdoptionCommitDTO: Codable, Equatable, Identifiable {
    var id: String
    var sessionId: String
    var decisionId: String
    var status: String
    var steps: [AdoptionCommitStepDTO]
    var result: [String: AnyCodable]?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case decisionId = "decision_id"
        case status, steps, result, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        self.decisionId = try c.decodeIfPresent(String.self, forKey: .decisionId) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.steps = try c.decodeIfPresent([AdoptionCommitStepDTO].self, forKey: .steps) ?? []
        self.result = try c.decodeIfPresent([String: AnyCodable].self, forKey: .result)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// Invocation Response DTO — aiInvocation.ts:172-178
struct InvocationResponseDTO: Codable, Equatable {
    var session: InvocationSessionDTO
    var attempt: InvocationAttemptDTO?
    var decision: AdoptionDecisionDTO?
    var commit: AdoptionCommitDTO?
    var nextAction: String?

    enum CodingKeys: String, CodingKey {
        case session, attempt, decision, commit
        case nextAction = "next_action"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try c.decodeIfPresent(InvocationSessionDTO.self, forKey: .session) ?? InvocationSessionDTO()
        self.attempt = try c.decodeIfPresent(InvocationAttemptDTO.self, forKey: .attempt)
        self.decision = try c.decodeIfPresent(AdoptionDecisionDTO.self, forKey: .decision)
        self.commit = try c.decodeIfPresent(AdoptionCommitDTO.self, forKey: .commit)
        self.nextAction = try c.decodeIfPresent(String.self, forKey: .nextAction)
    }

    init(
        session: InvocationSessionDTO = InvocationSessionDTO(),
        attempt: InvocationAttemptDTO? = nil,
        decision: AdoptionDecisionDTO? = nil,
        commit: AdoptionCommitDTO? = nil,
        nextAction: String? = nil
    ) {
        self.session = session
        self.attempt = attempt
        self.decision = decision
        self.commit = commit
        self.nextAction = nextAction
    }
}

// MARK: - 请求 Payload（aiInvocation.ts:180-218）

/// 创建 Session Payload — aiInvocation.ts:180-188
struct InvocationCreatePayload: Codable {
    let operation: String
    let nodeKey: String
    var variables: [String: AnyCodable]?
    var context: [String: AnyCodable]?
    var policy: String?
    var config: [String: AnyCodable]?
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case operation
        case nodeKey = "node_key"
        case variables, context, policy, config, metadata
    }
}

/// 采纳 Payload — aiInvocation.ts:190-197
struct InvocationAcceptPayload: Codable {
    let attemptId: String
    var acceptedBy: String?
    var commitPromptVersion: Bool?
    var commitVariableOutputs: Bool?
    var commitVariableBindings: Bool?
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case attemptId = "attempt_id"
        case acceptedBy = "accepted_by"
        case commitPromptVersion = "commit_prompt_version"
        case commitVariableOutputs = "commit_variable_outputs"
        case commitVariableBindings = "commit_variable_bindings"
        case metadata
    }
}

/// 恢复 Payload — aiInvocation.ts:199-203
struct InvocationResumePayload: Codable {
    var resumedBy: String?
    var config: [String: AnyCodable]?
    var metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case resumedBy = "resumed_by"
        case config, metadata
    }
}

/// 提示词草稿 Payload — aiInvocation.ts:205-208
struct InvocationPromptDraftPayload: Codable {
    let systemTemplate: String
    var userTemplate: String?

    enum CodingKeys: String, CodingKey {
        case systemTemplate = "system_template"
        case userTemplate = "user_template"
    }
}

/// 变量更新 Payload — aiInvocation.ts:210-213
struct InvocationVariableUpdatePayload: Codable {
    let values: [String: AnyCodable]
    var updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case values
        case updatedBy = "updated_by"
    }
}

/// 提交 Payload — aiInvocation.ts:251-255 body
struct InvocationCommitPayload: Codable {
    let decisionId: String

    enum CodingKeys: String, CodingKey {
        case decisionId = "decision_id"
    }
}

// MARK: - 提示词草稿预览 DTO — aiInvocation.ts:215-218

/// 提示词草稿预览 DTO — aiInvocation.ts:215-218
struct InvocationPromptDraftPreviewDTO: Codable, Equatable {
    var promptSnapshot: InvocationPromptSnapshot
    var variablePlan: InvocationVariablePlan?

    enum CodingKeys: String, CodingKey {
        case promptSnapshot = "prompt_snapshot"
        case variablePlan = "variable_plan"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.promptSnapshot = try c.decodeIfPresent(InvocationPromptSnapshot.self, forKey: .promptSnapshot) ?? InvocationPromptSnapshot()
        self.variablePlan = try c.decodeIfPresent(InvocationVariablePlan.self, forKey: .variablePlan)
    }

    init(promptSnapshot: InvocationPromptSnapshot = InvocationPromptSnapshot(), variablePlan: InvocationVariablePlan? = nil) {
        self.promptSnapshot = promptSnapshot
        self.variablePlan = variablePlan
    }
}
