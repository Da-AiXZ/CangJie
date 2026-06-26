//
//  APIEndpoint.swift
//  Cangjie
//
//  API 端点定义，覆盖 PlotPilot v4.6.0 后端全部模块。
//  路径前缀映射基于架构文档 6.2 节，并经源码确认。
//
//  后端路由注册在 interfaces/api/routes.py，所有路由前缀来自源码：
//  - API_V1_PREFIX = "/api/v1"
//  - NOVELS_API_PREFIX = "/api/v1/novels"
//  - STATS_API_PREFIX = "/api/stats"
//

import Foundation

/// API 端点枚举，定义所有后端 REST API 端点。
///
/// 每个枚举值提供：
/// - `path`: 路径（不含前缀）
/// - `prefix`: 前缀（默认 `/api/v1`）
/// - `method`: HTTP 方法
/// - `queryItems`: 可选查询参数
///
/// 使用方式：
/// ```swift
/// let endpoint = APIEndpoint.Novels.list
/// let url = endpoint.url(config: APIConfig.shared)
/// let request = authMiddleware.makeAuthenticatedRequest(
///     url: url,
///     method: endpoint.method
/// )
/// ```
enum APIEndpoint {

    // MARK: - Novels（小说管理）
    enum Novels {
        /// 列出所有小说 — `GET /novels/`
        case list
        /// 获取小说详情 — `GET /novels/{novel_id}`
        case get(novelId: String)
        /// 创建小说 — `POST /novels/`
        case create
        /// 更新小说 — `PUT /novels/{novel_id}`
        case update(novelId: String)
        /// 更新小说阶段 — `PUT /novels/{novel_id}/stage`
        case updateStage(novelId: String)
        /// 删除小说 — `DELETE /novels/{novel_id}`
        case delete(novelId: String)
        /// 触发 Bible 生成（别名路由）— `POST /novels/{novel_id}/bible/generate`
        case generateBibleAlias(novelId: String, stage: String)
        /// 更新全自动模式 — `PATCH /novels/{novel_id}/auto-approve-mode`
        case updateAutoApproveMode(novelId: String)
        /// 获取小说统计 — `GET /novels/{novel_id}/statistics`
        case statistics(novelId: String)
    }

    // MARK: - Chapters（章节管理，挂载于 NOVELS_API_PREFIX）
    enum Chapters {
        /// 列出章节 — `GET /novels/{novel_id}/chapters`
        case list(novelId: String)
        /// 创建章节 — `POST /novels/{novel_id}/chapters`
        case create(novelId: String)
        /// 获取章节 — `GET /novels/{novel_id}/chapters/{chapter_number}`
        case get(novelId: String, chapterNumber: Int)
        /// 更新章节内容 — `PUT /novels/{novel_id}/chapters/{chapter_number}`
        case update(novelId: String, chapterNumber: Int)
        /// 更新章节生成约束 — `PATCH /novels/{novel_id}/chapters/{chapter_number}/hint`
        case updateHint(novelId: String, chapterNumber: Int)
        /// 确保章节存在 — `POST /novels/{novel_id}/chapters/{chapter_number}/ensure`
        case ensure(novelId: String, chapterNumber: Int)
        /// 获取章节审阅 — `GET /novels/{novel_id}/chapters/{chapter_number}/review`
        case getReview(novelId: String, chapterNumber: Int)
        /// 保存章节审阅 — `PUT /novels/{novel_id}/chapters/{chapter_number}/review`
        case saveReview(novelId: String, chapterNumber: Int)
        /// AI 审阅章节 — `POST /novels/{novel_id}/chapters/{chapter_number}/review-ai`
        case aiReview(novelId: String, chapterNumber: Int)
        /// 获取章节结构 — `GET /novels/{novel_id}/chapters/{chapter_number}/structure`
        case structure(novelId: String, chapterNumber: Int)
        /// 获取护栏快照 — `GET /novels/{novel_id}/chapters/{chapter_number}/guardrail-snapshot`
        case guardrailSnapshot(novelId: String, chapterNumber: Int)
        /// 更新微观节拍 — `PUT /novels/{novel_id}/chapters/{chapter_number}/micro-beats`
        case updateMicroBeats(novelId: String, chapterNumber: Int)
        /// 保存章节草稿 — `POST /novels/{novel_id}/chapters/{chapter_number}/drafts`
        case saveDraft(novelId: String, chapterNumber: Int)
        /// 列出章节草稿 — `GET /novels/{novel_id}/chapters/{chapter_number}/drafts`
        case listDrafts(novelId: String, chapterNumber: Int)
    }

    // MARK: - Autopilot（自动驾驶）
    enum Autopilot {
        /// 启动自动驾驶 — `POST /autopilot/{novel_id}/start`
        case start(novelId: String)
        /// 停止自动驾驶 — `POST /autopilot/{novel_id}/stop`
        case stop(novelId: String)
        /// 恢复自动驾驶 — `POST /autopilot/{novel_id}/resume`
        case resume(novelId: String)
        /// 获取自动驾驶状态 — `GET /autopilot/{novel_id}/status`
        case status(novelId: String)
        /// 获取熔断器状态 — `GET /autopilot/{novel_id}/circuit-breaker`
        case circuitBreaker(novelId: String)
        /// 重置熔断器 — `POST /autopilot/{novel_id}/circuit-breaker/reset`
        case resetCircuitBreaker(novelId: String)
        /// 获取自动驾驶事件流 — `GET /autopilot/{novel_id}/stream`
        case stream(novelId: String, afterSeq: Int? = nil)
        /// 获取自动驾驶日志流 — `GET /autopilot/{novel_id}/log-stream`
        case logStream(novelId: String, afterSeq: Int? = nil)
        /// 获取章节生成流 — `GET /autopilot/{novel_id}/chapter-stream`
        case chapterStream(novelId: String)
        /// 系统资源 — `GET /autopilot/system/resources`
        case systemResources
        /// 缓存统计 — `GET /autopilot/system/cache/stats`
        case cacheStats
    }

    // MARK: - Bible（设定集）
    enum Bible {
        /// 触发 Bible 生成 — `POST /bible/novels/{novel_id}/generate`
        case generate(novelId: String, stage: String)
        /// Bible 流式生成 — `POST /bible/novels/{novel_id}/generate-stream`
        case generateStream(novelId: String, stage: String)
        /// 创建 Bible — `POST /bible/novels/{novel_id}/bible`
        case create(novelId: String)
        /// 获取 Bible — `GET /bible/novels/{novel_id}/bible`
        case get(novelId: String)
        /// 更新 Bible — `PUT /bible/novels/{novel_id}/bible`
        case update(novelId: String)
        /// Bible 生成状态 — `GET /bible/novels/{novel_id}/bible/status`
        case status(novelId: String)
        /// Bible 生成反馈 — `GET /bible/novels/{novel_id}/bible/generation-feedback`
        case generationFeedback(novelId: String)
        /// 获取角色列表 — `GET /bible/novels/{novel_id}/bible/characters`
        case characters(novelId: String)
        /// 添加角色 — `POST /bible/novels/{novel_id}/bible/characters`
        case addCharacter(novelId: String)
        /// 添加世界观设定 — `POST /bible/novels/{novel_id}/bible/world-settings`
        case addWorldSetting(novelId: String)
        /// 添加地点 — `POST /bible/novels/{novel_id}/bible/locations`
        case addLocation(novelId: String)
        /// 添加时间线笔记 — `POST /bible/novels/{novel_id}/bible/timeline-notes`
        case addTimelineNote(novelId: String)
        /// 添加文风笔记 — `POST /bible/novels/{novel_id}/bible/style-notes`
        case addStyleNote(novelId: String)
    }

    // MARK: - DAG（工作流）
    enum DAG {
        /// DAG 健康检查 — `GET /dag/health/dag`
        case health
        /// 节点类型注册表 — `GET /dag/registry/types`
        case registryTypes
        /// 注册表联动 — `GET /dag/registry/linkage`
        case registryLinkage
        /// DAG 事件流 — `GET /dag/events`
        case events(novelId: String)
        /// 获取 DAG 定义 — `GET /dag/{novel_id}`
        case get(novelId: String)
        /// 获取节点详情 — `GET /dag/{novel_id}/nodes/{node_id}`
        case node(novelId: String, nodeId: String)
        /// 切换节点启禁用 — `POST /dag/{novel_id}/nodes/{node_id}/toggle`
        case toggleNode(novelId: String, nodeId: String)
        /// 获取 DAG 运行状态 — `GET /dag/{novel_id}/status`
        case status(novelId: String)
        /// 获取实时提示词 — `GET /dag/{novel_id}/nodes/{node_id}/prompt-live`
        case nodePromptLive(novelId: String, nodeId: String)
        /// 获取提示词 — `GET /dag/{novel_id}/nodes/{node_id}/prompt`
        case nodePrompt(novelId: String, nodeId: String)
        /// 更新节点 — `PUT /dag/{novel_id}/nodes/{node_id}`
        case updateNode(novelId: String, nodeId: String)
        /// 运行 DAG — `POST /dag/{novel_id}/run`
        case run(novelId: String)
        /// 停止 DAG — `POST /dag/{novel_id}/stop`
        case stop(novelId: String)
    }

    // MARK: - KnowledgeGraph（知识图谱）
    enum KnowledgeGraph {
        /// 获取三元组 — `GET /knowledge-graph/novels/{novel_id}/triples`
        case triples(novelId: String)
        /// 推断三元组 — `POST /knowledge-graph/novels/{novel_id}/infer`
        case infer(novelId: String)
        /// 获取推断证据 — `GET /knowledge-graph/novels/{novel_id}/chapters/by-number/{chapter_number}/inference-evidence`
        case inferenceEvidence(novelId: String, chapterNumber: Int)
        /// 删除章节推断 — `DELETE /knowledge-graph/novels/{novel_id}/chapters/by-number/{chapter_number}/inference`
        case deleteChapterInference(novelId: String, chapterNumber: Int)
        /// 删除推断三元组 — `DELETE /knowledge-graph/novels/{novel_id}/inferred-triples/{triple_id}`
        case deleteInferredTriple(novelId: String, tripleId: String)
        /// 确认三元组 — `POST /knowledge-graph/triples/{triple_id}/confirm`
        case confirmTriple(tripleId: String)
        /// 标星三元组 — `PATCH /knowledge-graph/novels/{novel_id}/triples/{triple_id}/star`
        case starTriple(novelId: String, tripleId: String)
        /// 删除三元组 — `DELETE /knowledge-graph/triples/{triple_id}`
        case deleteTriple(tripleId: String)
        /// 获取元素关系 — `GET /knowledge-graph/elements/{element_type}/{element_id}/relations`
        case elementRelations(elementType: String, elementId: String)
        /// 统计 — `GET /knowledge-graph/novels/{novel_id}/statistics`
        case statistics(novelId: String)
        /// 索引 — `POST /knowledge-graph/novels/{novel_id}/index`
        case index(novelId: String)
        /// 搜索 — `POST /knowledge-graph/novels/{novel_id}/search`
        case search(novelId: String)
    }

    // MARK: - LLM Control（LLM 控制面板）
    enum LLMControl {
        /// 获取面板数据 — `GET /llm-control`
        case panel
        /// 更新配置 — `PUT /llm-control`
        case update
        /// 测试连通性 — `POST /llm-control/test`
        case test
        /// 拉取模型列表 — `POST /llm-control/models`
        case models
        /// 提示词广场初始化 — `GET /llm-control/prompts/plaza-init`
        case promptsPlazaInit
        /// 提示词统计 — `GET /llm-control/prompts/stats`
        case promptsStats
        /// 提示词分类信息 — `GET /llm-control/prompts/categories-info`
        case promptsCategoriesInfo
        /// 提示词模板列表 — `GET /llm-control/prompts/templates`
        case promptsTemplates
        /// 创建模板包 — `POST /llm-control/prompts/templates`（与 .promptsTemplates GET 不冲突，独立 case）
        case createTemplate
        /// 提示词列表 — `GET /llm-control/prompts`
        case prompts
        /// 按分类获取提示词 — `GET /llm-control/prompts/by-category`
        case promptsByCategory
        /// 获取提示词节点 — `GET /llm-control/prompts/{node_key}`
        case promptNode(nodeKey: String)
        /// 创建提示词节点 — `POST /llm-control/prompts/nodes`
        case createPromptNode
        /// 删除提示词节点 — `DELETE /llm-control/prompts/nodes/{node_id}`
        case deletePromptNode(nodeId: String)
        /// 获取提示词版本 — `GET /llm-control/prompts/{node_key}/versions`
        case promptVersions(nodeKey: String)
        /// 获取版本详情 — `GET /llm-control/prompts/versions/{version_id}`
        case promptVersion(versionId: String)
        /// 更新提示词 — `PUT /llm-control/prompts/{node_key}`
        case updatePrompt(nodeKey: String)
        /// 回滚提示词 — `POST /llm-control/prompts/{node_key}/rollback/{version_id}`
        case rollbackPrompt(nodeKey: String, versionId: String)
        /// 版本对比 — `GET /llm-control/prompts/compare/{v1_id}/{v2_id}`
        case comparePrompts(v1Id: String, v2Id: String)
        /// 渲染提示词 — `POST /llm-control/prompts/{node_key}/render`
        case renderPrompt(nodeKey: String)
        /// 调试提示词 — `POST /llm-control/prompts/{node_key}/debug`
        case debugPrompt(nodeKey: String)
        /// 提示词链 — `GET /llm-control/prompts/{node_key}/chain`
        case promptChain(nodeKey: String)
        /// 提示词沙盒 — `POST /llm-control/prompts/{node_key}/sandbox`
        case promptSandbox(nodeKey: String)
        /// 提示词变量 — `GET /llm-control/prompts/variables`
        case promptVariables
        /// 提示词绑定 — `GET /llm-control/prompts/{node_key}/bindings`
        case promptBindings(nodeKey: String)
        /// 导出提示词 — `GET /llm-control/prompts/export`
        case exportPrompts
        /// 导入提示词 — `POST /llm-control/prompts/import`
        case importPrompts
    }

    // MARK: - Planning（连续规划）
    enum Planning {
        /// 宏观规划流 — `GET /planning/novels/{novel_id}/macro/stream`
        case macroStream(novelId: String)
        /// 宏观规划进度流 — `GET /planning/novels/{novel_id}/macro/progress/stream`
        case macroProgressStream(novelId: String)
        /// 触发宏观规划生成 — `POST /planning/novels/{novel_id}/macro/generate`
        case macroGenerate(novelId: String)
        /// 宏观规划进度 — `GET /planning/novels/{novel_id}/macro/progress`
        case macroProgress(novelId: String)
        /// 宏观规划结果 — `GET /planning/novels/{novel_id}/macro/result`
        case macroResult(novelId: String)
        /// 确认宏观规划 — `POST /planning/novels/{novel_id}/macro/confirm`
        case macroConfirm(novelId: String)
        /// 继续规划 — `POST /planning/novels/{novel_id}/continue`
        case continuePlanning(novelId: String)
        /// 获取结构 — `GET /planning/novels/{novel_id}/structure`
        case structure(novelId: String)
        /// 幕级章节生成流 — `GET /planning/acts/{act_id}/chapters/stream`
        case actChaptersStream(actId: String)
        /// 幕级章节生成 — `POST /planning/acts/{act_id}/chapters/generate`
        case actChaptersGenerate(actId: String)
        /// 幕级章节确认 — `POST /planning/acts/{act_id}/chapters/confirm`
        case actChaptersConfirm(actId: String)
        /// 创建下一幕 — `POST /planning/acts/{act_id}/create-next`
        case createNextAct(actId: String)
    }

    // MARK: - Story Structure（故事结构）
    enum StoryStructure {
        /// 获取结构树 — `GET /novels/{novel_id}/structure`
        case get(novelId: String)
        /// 获取子节点 — `GET /novels/{novel_id}/structure/children`
        case children(novelId: String)
        /// 创建节点 — `POST /novels/{novel_id}/structure/nodes`
        case createNode(novelId: String)
        /// 更新节点 — `PUT /novels/{novel_id}/structure/nodes/{node_id}`
        case updateNode(novelId: String, nodeId: String)
        /// 删除节点 — `DELETE /novels/{novel_id}/structure/nodes/{node_id}`
        case deleteNode(novelId: String, nodeId: String)
        /// 重排序 — `POST /novels/{novel_id}/structure/reorder`
        case reorder(novelId: String)
        /// 更新范围 — `POST /novels/{novel_id}/structure/update-ranges`
        case updateRanges(novelId: String)
        /// 创建默认结构 — `POST /novels/{novel_id}/structure/create-default`
        case createDefault(novelId: String)
    }

    // MARK: - Cast（角色关系）
    enum Cast {
        /// 获取角色关系图 — `GET /novels/{novel_id}/cast`
        case graph(novelId: String)
        /// 搜索角色 — `GET /novels/{novel_id}/cast/search`
        case search(novelId: String)
        /// 角色覆盖 — `GET /novels/{novel_id}/cast/coverage`
        case coverage(novelId: String)
        /// 角色调度 — `POST /novels/{novel_id}/cast/schedule`
        case schedule(novelId: String)
        /// 角色叙事画像 — `GET /novels/{novel_id}/characters/{character_id}/narrative-profile`
        case narrativeProfile(novelId: String, characterId: String)
        /// 实体记忆 — `GET /novels/{novel_id}/entities/{entity_id}/memory`
        case entityMemory(novelId: String, entityId: String)
        /// 角色投影 — `GET /novels/{novel_id}/characters/{character_id}/projection`
        case projection(novelId: String, characterId: String)
    }

    // MARK: - Foreshadow Ledger（伏笔手账）
    enum Foreshadow {
        /// 创建伏笔 — `POST /novels/{novel_id}/foreshadow-ledger`
        case create(novelId: String)
        /// 列出伏笔 — `GET /novels/{novel_id}/foreshadow-ledger`
        case list(novelId: String)
        /// 获取伏笔 — `GET /novels/{novel_id}/foreshadow-ledger/{entry_id}`
        case get(novelId: String, entryId: String)
        /// 更新伏笔 — `PUT /novels/{novel_id}/foreshadow-ledger/{entry_id}`
        case update(novelId: String, entryId: String)
        /// 删除伏笔 — `DELETE /novels/{novel_id}/foreshadow-ledger/{entry_id}`
        case delete(novelId: String, entryId: String)
    }

    // MARK: - Monitor（监控）
    enum Monitor {
        /// 张力曲线 — `GET /novels/{novel_id}/monitor/tension-curve`
        case tensionCurve(novelId: String)
        /// 文风漂移 — `GET /novels/{novel_id}/monitor/voice-drift`
        case voiceDrift(novelId: String)
        /// 伏笔统计 — `GET /novels/{novel_id}/monitor/foreshadow-stats`
        case foreshadowStats(novelId: String)
    }

    // MARK: - Settings（设置）
    enum Settings {
        /// 列出 LLM 配置 — `GET /settings/llm-configs/`
        case listLLMConfigs
        /// 创建 LLM 配置 — `POST /settings/llm-configs/`
        case createLLMConfig
        /// 更新 LLM 配置 — `PUT /settings/llm-configs/{config_id}`
        case updateLLMConfig(configId: String)
        /// 删除 LLM 配置 — `DELETE /settings/llm-configs/{config_id}`
        case deleteLLMConfig(configId: String)
        /// 激活 LLM 配置 — `POST /settings/llm-configs/{config_id}/activate`
        case activateLLMConfig(configId: String)
        /// 拉取模型列表 — `POST /settings/llm-configs/fetch-models`
        case fetchModels
        /// 嵌入配置 — `GET /settings/embedding/`
        case embeddingConfig
    }

    // MARK: - System（系统）
    enum System {
        /// 扩展包状态 — `GET /system/extensions-status`
        case extensionsStatus
        /// 安装扩展包 — `POST /system/install-extensions`
        case installExtensions
        /// 反馈日志快照 — `GET /system/feedback-log-snapshot`
        case feedbackLogSnapshot
    }

    // MARK: - Export（导出）
    enum Export {
        /// 导出小说 — `GET /export/novel/{novel_id}`
        case novel(novelId: String)
        /// 导出章节 — `GET /export/chapter/{chapter_id}`
        case chapter(chapterId: String)
    }

    // MARK: - Checkpoints（检查点）
    enum Checkpoints {
        /// 列出检查点 — `GET /novels/{novel_id}/checkpoints`
        case list(novelId: String)
        /// 创建检查点 — `POST /novels/{novel_id}/checkpoints`
        case create(novelId: String)
        /// 回滚检查点 — `POST /novels/{novel_id}/checkpoints/{checkpoint_id}/rollback`
        case rollback(novelId: String, checkpointId: String)
        /// 分支列表 — `GET /novels/{novel_id}/checkpoints/branches`
        case branches(novelId: String)
        /// HEAD 检查点 — `GET /novels/{novel_id}/checkpoints/head`
        case head(novelId: String)
        /// 护栏检查 — `POST /novels/{novel_id}/guardrail/check`
        case guardrailCheck(novelId: String)
        /// 故事阶段 — `GET /novels/{novel_id}/story-phase`
        case storyPhase(novelId: String)
        /// 更新故事阶段 — `PUT /novels/{novel_id}/story-phase`
        case updateStoryPhase(novelId: String)
        /// 角色心理列表 — `GET /novels/{novel_id}/character-psyches`
        case characterPsyches(novelId: String)
        /// 角色心理详情 — `GET /novels/{novel_id}/character-psyches/{character_name}`
        case characterPsycheDetail(novelId: String, characterName: String)
    }

    // MARK: - Snapshots（快照）
    enum Snapshots {
        /// 列出快照 — `GET /novels/{novel_id}/snapshots`
        case list(novelId: String)
        /// 获取快照 — `GET /novels/{novel_id}/snapshots/{snapshot_id}`
        case get(novelId: String, snapshotId: String)
        /// 创建快照 — `POST /novels/{novel_id}/snapshots`
        case create(novelId: String)
        /// 删除快照 — `DELETE /novels/{novel_id}/snapshots/{snapshot_id}`
        case delete(novelId: String, snapshotId: String)
    }

    // MARK: - Worldline（世界线）— worldline.ts:52-115
    enum Worldline {
        /// 世界线图 — `GET /novels/{novel_id}/worldline/graph` — worldline.ts:53-54
        case graph(novelId: String)
        /// 检查点列表 — `GET /novels/{novel_id}/worldline/checkpoints` — worldline.ts:56-57
        case checkpoints(novelId: String)
        /// 创建检查点 — `POST /novels/{novel_id}/worldline/checkpoints` — worldline.ts:59-65
        case createCheckpoint(novelId: String)
        /// 分支列表 — `GET /novels/{novel_id}/worldline/branches` — worldline.ts:67-68
        case branches(novelId: String)
        /// 创建分支 — `POST /novels/{novel_id}/worldline/branches` — worldline.ts:70-74
        case createBranch(novelId: String)
        /// 切换检查点 — `POST /novels/{novel_id}/worldline/checkpoints/{checkpoint_id}/checkout` — worldline.ts:76-80
        case checkout(novelId: String, checkpointId: String)
        /// 硬重置 — `POST /novels/{novel_id}/worldline/checkpoints/{checkpoint_id}/hard-reset` — worldline.ts:82-86
        case hardReset(novelId: String, checkpointId: String)
        /// 删除检查点 — `DELETE /novels/{novel_id}/worldline/checkpoints/{checkpoint_id}` — worldline.ts:88-89
        case deleteCheckpoint(novelId: String, checkpointId: String)
        /// 按故事线获取分支 — `GET /novels/{novel_id}/worldline/branches/by-storyline/{storyline_id}` — worldline.ts:91-94
        case branchByStoryline(novelId: String, storylineId: String)
        /// 更新分支 — `PUT /novels/{novel_id}/worldline/branches/{branch_id}` — worldline.ts:96-104
        case updateBranch(novelId: String, branchId: String)
        /// 合并分支 — `POST /novels/{novel_id}/worldline/branches/{branch_id}/merge` — worldline.ts:106-114
        case mergeBranch(novelId: String, branchId: String)
        /// 汇流点列表 — `GET /novels/{novel_id}/confluence-points` — confluence.ts:16-18
        case confluenceList(novelId: String)
        /// P1 新增：创建汇流点 — `POST /novels/{novel_id}/confluence-points` — workflow.ts
        case createConfluence(novelId: String)
        /// P1 新增：更新汇流点 — `PATCH /novels/{novel_id}/confluence-points/{cpId}` — workflow.ts
        case updateConfluence(novelId: String, cpId: String)
        /// P1 新增：删除汇流点 — `DELETE /novels/{novel_id}/confluence-points/{cpId}` — workflow.ts
        case deleteConfluence(novelId: String, cpId: String)
    }

    // MARK: - Governance（叙事治理）
    enum Governance {
        /// 治理状态 — `GET /novels/{novel_id}/governance/state`
        case state(novelId: String)
        /// 叙事契约 — `POST /novels/{novel_id}/governance/contract`
        case contract(novelId: String)
        /// 合并故事线 — `POST /novels/{novel_id}/governance/storylines/merge`
        case mergeStorylines(novelId: String)
        /// 章节预算预览 — `POST /novels/{novel_id}/governance/chapter-budget/preview`
        case chapterBudgetPreview(novelId: String)
        /// 审阅动作 — `POST /novels/{novel_id}/governance/review-action`
        case reviewAction(novelId: String)
    }

    // MARK: - Evolution（故事演化）
    enum Evolution {
        /// 演化快照 — `GET /novels/{novel_id}/evolution/snapshots`
        case snapshots(novelId: String)
        /// 指定章节快照 — `GET /novels/{novel_id}/evolution/snapshots/{chapter_number}`
        case snapshotAtChapter(novelId: String, chapterNumber: Int)
        /// 闸门 — `POST /novels/{novel_id}/evolution/gate`
        case gate(novelId: String)
        /// 快照覆盖 — `POST /novels/{novel_id}/evolution/snapshots/{chapter_number}/overrides`
        case snapshotOverrides(novelId: String, chapterNumber: Int)
        /// 回放 — `POST /novels/{novel_id}/evolution/replay-from/{chapter_number}`
        case replay(novelId: String, chapterNumber: Int)
    }

    // MARK: - Chronicles（编年史）
    enum Chronicles {
        /// 获取编年史 — `GET /novels/{novel_id}/chronicles`
        case get(novelId: String)
        /// 快照回滚 — `POST /novels/{novel_id}/snapshots/{snapshot_id}/rollback` — chronicles.ts:46-49
        case rollback(novelId: String, snapshotId: String)
    }

    // MARK: - Trace（AI Trace 溯源）
    enum Trace {
        /// Trace 列表 — `GET /novels/{novel_id}/traces`
        case list(novelId: String)
        /// Trace 统计 — `GET /novels/{novel_id}/traces/stats`
        case stats(novelId: String)
        /// AI Trace 列表 — `GET /novels/{novel_id}/ai-traces`
        case aiTraces(novelId: String)
        /// Trace 时间线 — `GET /novels/{novel_id}/traces/{trace_id}/timeline`
        case timeline(novelId: String, traceId: String)
        /// AI Trace 阶段 — `GET /novels/{novel_id}/ai-traces/stages`
        case aiStages(novelId: String)
        /// 按阶段查询 — `GET /novels/{novel_id}/ai-traces/by-stage/{stage}`
        case aiByStage(novelId: String, stage: String)
    }

    // MARK: - Props（道具）
    enum Props {
        /// 列出道具 — `GET /novels/{novel_id}/props`
        case list(novelId: String)
        /// 创建道具 — `POST /novels/{novel_id}/props`
        case create(novelId: String)
        /// 获取道具 — `GET /novels/{novel_id}/props/{prop_id}`
        case get(novelId: String, propId: String)
        /// 更新道具 — `PATCH /novels/{novel_id}/props/{prop_id}`
        case update(novelId: String, propId: String)
        /// 删除道具 — `DELETE /novels/{novel_id}/props/{prop_id}`
        case delete(novelId: String, propId: String)
        /// 道具事件列表 — `GET /novels/{novel_id}/props/{prop_id}/events`
        case events(novelId: String, propId: String)
        /// 创建道具事件 — `POST /novels/{novel_id}/props/{prop_id}/events`
        case createEvent(novelId: String, propId: String)
    }

    // MARK: - AntiAI（Anti-AI 防御）
    enum AntiAI {
        /// 扫描 — `POST /anti-ai/scan`
        case scan
        /// 分类列表 — `GET /anti-ai/categories`
        case categories
        /// 规则列表 — `GET /anti-ai/rules`
        case rules
        /// 允许列表 — `POST /anti-ai/allowlist`
        case allowlist
        /// 场景允许列表 — `GET /anti-ai/allowlist/scenes`
        case allowlistScenes
        /// 统计 — `GET /anti-ai/stats`
        case stats
        /// 审计列表 — `GET /anti-ai/audits/{novel_id}`
        case audits(novelId: String)
        /// 章节审计 — `GET /anti-ai/audits/{novel_id}/{chapter_number}`
        case chapterAudit(novelId: String, chapterNumber: Int)
        /// 趋势 — `GET /anti-ai/trend/{novel_id}`
        case trend(novelId: String)
    }

    // MARK: - Sandbox（对话沙盒）
    enum Sandbox {
        /// 对话白名单 — `GET /novels/{novel_id}/sandbox/dialogue-whitelist`
        case dialogueWhitelist(novelId: String)
        /// 角色锚点 — `GET /novels/{novel_id}/sandbox/character/{character_id}/anchor`
        case characterAnchor(novelId: String, characterId: String)
        /// 更新角色锚点 — `PATCH /novels/{novel_id}/sandbox/character/{character_id}/anchor` — sandbox.ts:63-72
        case patchCharacterAnchor(novelId: String, characterId: String)
        /// 生成对话 — `POST /novels/sandbox/generate-dialogue`（novel_id 在 body 中，无路径参数）
        /// 对齐原项目 sandbox.ts:74-77
        case generateDialogue
    }

    // MARK: - BeatSheets（节拍表）
    enum BeatSheets {
        /// 获取节拍表 — `GET /beat-sheets/novels/{novel_id}`
        case get(novelId: String)
        /// 更新节拍表 — `PUT /beat-sheets/novels/{novel_id}`
        case update(novelId: String)
    }

    // MARK: - Manuscript（手稿实体索引）— manuscript.ts:25-46
    enum Manuscript {
        /// 章节实体提及列表 — `GET /novels/{novel_id}/chapters/{chapter_number}/entity-mentions`
        case chapterMentions(novelId: String, chapterNumber: Int)
        /// 重建章节实体索引 — `POST /novels/{novel_id}/chapters/{chapter_number}/entity-mentions/reindex`
        case reindexMentions(novelId: String, chapterNumber: Int)
    }

    // MARK: - NarrativeEngine（叙事引擎只读聚合）— narrativeEngine.ts:79-95
    enum NarrativeEngine {
        /// 故事演化聚合 — `GET /novels/{novel_id}/narrative-engine/story-evolution`
        case storyEvolution(novelId: String)
    }

    // MARK: - Taxonomy（分类法）
    enum Taxonomy {
        /// 内置分类包 — `GET /taxonomy/bundles/builtin_cn_v1`
        case builtinBundle
        /// 开篇画像 — `GET /taxonomy/opening-profiles/cn_v1`
        case openingProfiles
    }

    // MARK: - AI Invocation（AI 审批系统）
    enum AIInvocation {
        /// 创建 session — `POST /ai-invocations` — aiInvocation.ts:221-223
        case create
        /// 获取 session 详情 — `GET /ai-invocations/{sessionId}` — aiInvocation.ts:224-226
        case get(sessionId: String)
        /// 采纳 — `POST /ai-invocations/{sessionId}/accept` — aiInvocation.ts:227-229
        case accept(sessionId: String)
        /// 拒绝 — `POST /ai-invocations/{sessionId}/reject` — aiInvocation.ts:230-232
        case reject(sessionId: String)
        /// 恢复（批准生成）— `POST /ai-invocations/{sessionId}/resume` — aiInvocation.ts:233-235
        case resume(sessionId: String)
        /// 重新生成 — `POST /ai-invocations/{sessionId}/retry` — aiInvocation.ts:236-238
        case retry(sessionId: String)
        /// 预览提示词草稿 — `POST /ai-invocations/{sessionId}/prompt-draft/preview` — aiInvocation.ts:239-244
        case previewPromptDraft(sessionId: String)
        /// 保存提示词草稿 — `PUT /ai-invocations/{sessionId}/prompt-draft` — aiInvocation.ts:245-247
        case savePromptDraft(sessionId: String)
        /// 更新变量 — `PUT /ai-invocations/{sessionId}/variables` — aiInvocation.ts:248-250
        case updateVariables(sessionId: String)
        /// 提交 — `POST /ai-invocations/{sessionId}/commits` — aiInvocation.ts:251-255
        case commit(sessionId: String)
    }

    // MARK: - Workflow（向导工作流）
    enum Workflow {
        /// 获取剧情总纲 — `GET /novels/{novelId}/setup/plot-outline` — workflow.ts:790-793
        case getPlotOutline(novelId: String)
        /// 保存剧情总纲 — `PUT /novels/{novelId}/setup/plot-outline` — workflow.ts:795-799
        case savePlotOutline(novelId: String)
        /// 剧情总纲生成（POST 降级）— `POST /novels/{novelId}/setup/generate-plot-outline` — workflow.ts:801-806
        case generatePlotOutline(novelId: String)
        /// 获取故事线列表 — `GET /novels/{novelId}/storylines` — workflow.ts:774-776
        case getStorylines(novelId: String)
        /// 获取故事线 Git Graph 数据 — `GET /novels/{novelId}/storylines/graph-data` — workflow.ts:778-780
        case getStorylineGraphData(novelId: String)
        // P0-2 新增端点
        /// 场记分析 — `POST /novels/{novelId}/scene-director/analyze` — workflow.ts:226-235
        case analyzeScene(novelId: String)
        /// 上下文检索 — `POST /novels/{novelId}/context/retrieve` — workflow.ts:880-895
        case retrieveContext(novelId: String)
        /// 主线推荐（非流式降级）— `POST /novels/{novelId}/setup/suggest-main-plot-options` — workflow.ts:830-835
        case suggestMainPlotOptions(novelId: String)
        // P1 新增端点
        /// 创建故事线 — `POST /novels/{novelId}/storylines` — workflow.ts
        case createStoryline(novelId: String)
        /// 更新故事线 — `PUT /novels/{novelId}/storylines/{storylineId}` — workflow.ts
        case updateStoryline(novelId: String, storylineId: String)
        /// 删除故事线 — `DELETE /novels/{novelId}/storylines/{storylineId}` — workflow.ts
        case deleteStoryline(novelId: String, storylineId: String)
        /// 获取剧情弧 — `GET /novels/{novelId}/plot-arc` — workflow.ts
        case getPlotArc(novelId: String)
        /// 创建剧情弧 — `POST /novels/{novelId}/plot-arc` — workflow.ts
        case createPlotArc(novelId: String)
        /// 规划小说 — `POST /novels/{novelId}/plan` — workflow.ts
        case planNovel(novelId: String)
        /// 章节审阅 — `POST /novels/{novelId}/chapters/{chapterNumber}/review` — workflow.ts
        case reviewChapter(novelId: String, chapterNumber: Int)
        /// 续写大纲 — `POST /novels/{novelId}/outline/extend` — workflow.ts
        case extendOutline(novelId: String)
        /// 获取任务状态 — `GET /jobs/{jobId}` — workflow.ts
        case getJobStatus(jobId: String)
        /// 取消任务 — `POST /jobs/{jobId}/cancel` — workflow.ts
        case cancelJob(jobId: String)
    }

    // MARK: - Tools（创作工具）
    enum Tools {
        /// 张力弹弓诊断 — `POST /novels/{novelId}/writer-block/tension-slingshot` — tools.ts:24-28
        case tensionSlingshot(novelId: String)
        // P1 新增：宏观重构 + 实体状态
        /// 扫描断点 — `GET /novels/{novelId}/macro-refactor/breakpoints` — tools.ts:85-89
        case scanBreakpoints(novelId: String, trait: String, conflictTags: String?)
        /// 生成重构提案 — `POST /novels/{novelId}/macro-refactor/proposals` — tools.ts:92-96
        case generateProposal(novelId: String)
        /// 应用变异 — `POST /novels/{novelId}/macro-refactor/apply` — tools.ts:99-103
        case applyMutations(novelId: String)
        /// 获取最新诊断 — `GET /novels/{novelId}/macro-refactor/diagnosis/latest` — tools.ts:106-109
        case getLatestDiagnosis(novelId: String)
        /// 诊断历史 — `GET /novels/{novelId}/macro-refactor/diagnosis/history` — tools.ts:112-116
        case getDiagnosisHistory(novelId: String, limit: Int)
        /// 运行诊断 — `POST /novels/{novelId}/macro-refactor/diagnosis/run` — tools.ts:119-124
        case runDiagnosis(novelId: String, traits: String?)
        /// 解决诊断 — `POST /novels/{novelId}/macro-refactor/diagnosis/{diagId}/resolve` — tools.ts:127-130
        case resolveDiagnosis(novelId: String, diagId: String)
        /// 实体状态 — `GET /novels/{novelId}/entities/{entityId}/state` — tools.ts:142-146
        case getEntityState(novelId: String, entityId: String, chapter: Int)
    }

    // MARK: - ChapterElement（章节元素）
    enum ChapterElement {
        /// 获取章节元素列表 — `GET /chapters/{chapterId}/elements` — chapterElement.ts:38-44
        case list(chapterId: String)
        /// 添加章节元素 — `POST /chapters/{chapterId}/elements` — chapterElement.ts:46-52
        case create(chapterId: String)
        /// 批量更新 — `PUT /chapters/{chapterId}/elements` — chapterElement.ts:54-60
        case batchUpdate(chapterId: String)
        /// 删除章节元素 — `DELETE /chapters/{chapterId}/elements/{elementId}` — chapterElement.ts:62-66
        case delete(chapterId: String, elementId: String)
        /// 反查元素出现章节 — `GET /chapters/elements/{elementType}/{elementId}/chapters` — chapterElement.ts:69-74
        case chaptersByElement(elementType: String, elementId: String)
    }

    // MARK: - Stats（统计 API，前缀 /api/stats）
    // 对齐原项目 stats.ts：legacyStatsHttp baseURL=/api，路径 /stats/global、/stats/book/{slug}/chapter/{id}、/stats/book/{slug}/progress
    // 仓颉 statsPrefix=/api/stats，端点 path 不含 /stats 前缀
    enum Stats {
        /// 全局统计 — `GET /global`（prefix=`/api/stats`，完整路径 `/api/stats/global`）
        case global
        /// 章节统计 — `GET /book/{slug}/chapter/{chapterId}`（prefix=`/api/stats`）
        case chapter(slug: String, chapterId: Int)
        /// 进度统计 — `GET /book/{slug}/progress?days={days}`（prefix=`/api/stats`）
        case progress(slug: String, days: Int)
    }

    // MARK: - Voice（文风金库，挂载于 NOVELS_API_PREFIX）
    // 对齐原版 api/voice.ts:26-40 — 后端路由 /api/v1/novels/{novel_id}/voice/...
    enum Voice {
        /// 提交文风样本对 — `POST /novels/{novel_id}/voice/samples` — voice.ts:28-32
        case createSample(novelId: String)
        /// 查看文风指纹统计 — `GET /novels/{novel_id}/voice/fingerprint` — voice.ts:35-39
        case getFingerprint(novelId: String, povCharacterId: String?)
    }

    // MARK: - Knowledge（叙事知识，挂载于 NOVELS_API_PREFIX）
    // 对齐原版 api/knowledge.ts:71-106 — 后端路由 /api/v1/novels/{novel_id}/knowledge
    enum Knowledge {
        /// 获取叙事知识 — `GET /novels/{novel_id}/knowledge` — knowledge.ts:75-76
        case get(novelId: String)
        /// 更新叙事知识 — `PUT /novels/{novel_id}/knowledge` — knowledge.ts:81-82
        case update(novelId: String)
        /// 搜索叙事知识 — `GET /novels/{novel_id}/knowledge/search` — knowledge.ts:91-94
        case search(novelId: String, query: String, k: Int)
        /// AI 生成叙事知识 — `POST /novels/{novel_id}/knowledge/generate` — knowledge.ts:100-105
        case generate(novelId: String)
    }

    // MARK: - 端点协议

    /// 端点信息协议，提供路径、方法、前缀、查询参数
    protocol EndpointInfo {
        /// 路径（不含前缀）
        var path: String { get }
        /// HTTP 方法
        var method: HTTPMethod { get }
        /// 前缀（默认 /api/v1）
        var prefix: String { get }
        /// 查询参数
        var queryItems: [URLQueryItem] { get }
    }

    /// 默认前缀
    static let defaultPrefix = APIConfig.apiV1Prefix
    static let statsPrefix = APIConfig.statsPrefix

    // MARK: - Memory（记忆系统）— P1 新增，U4 决策
    // 对齐原版 memory.ts:37-65 — 路径挂载于 NOVELS_API_PREFIX（/api/v1/novels/{id}/...）
    enum Memory {
        /// 角色投影 — `GET /novels/{novelId}/characters/{characterId}/projection` — memory.ts:38-41
        /// E-5：P1 遗漏端点，P2 补注册（对齐 CharacterProfile.vue L540）
        case getCharacterProjection(novelId: String, characterId: String)

        /// 章节记忆候选 — `GET /novels/{novelId}/chapters/{chapterNumber}/memory-candidates` — memory.ts:43-46
        case getChapterCandidates(novelId: String, chapterNumber: Int)
        /// 确认记忆原子 — `POST /novels/{novelId}/memory-atoms/{atomId}/confirm` — memory.ts:48-52
        case confirmAtom(novelId: String, atomId: String)
        /// 拒绝记忆原子 — `POST /novels/{novelId}/memory-atoms/{atomId}/reject` — memory.ts:54-58
        case rejectAtom(novelId: String, atomId: String)
        /// 提升记忆原子 — `POST /novels/{novelId}/memory-atoms/{atomId}/promote` — memory.ts:60-64
        case promoteAtom(novelId: String, atomId: String)
    }

    // MARK: - Worldbuilding（世界观）— P1 新增
    // 对齐原版 worldbuilding.ts:48-56 — 路径挂载于 NOVELS_API_PREFIX
    enum Worldbuilding {
        /// 获取世界观 — `GET /novels/{novelId}/worldbuilding` — worldbuilding.ts:49-52
        case get(novelId: String)
        /// 更新世界观 — `PUT /novels/{novelId}/worldbuilding` — worldbuilding.ts:54-55
        case update(novelId: String)
    }
}

// MARK: - 默认实现

extension APIEndpoint.EndpointInfo {

    /// 默认前缀
    var prefix: String { APIEndpoint.defaultPrefix }

    /// 默认无查询参数
    var queryItems: [URLQueryItem] { [] }

    /// 构建完整 URL
    ///
    /// - Parameter config: APIConfig 实例
    /// - Returns: 完整 URL
    func url(config: APIConfig = .shared) -> URL? {
        guard let url = config.fullURL(path: path, prefix: prefix) else {
            return nil
        }

        if queryItems.isEmpty {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - Health 端点

extension APIEndpoint {

    /// 健康检查端点信息
    struct HealthEndpoint: EndpointInfo {
        let path = APIConfig.healthEndpoint
        let method: HTTPMethod = .get
        var prefix: String { "" }  // 无前缀，根路径
    }

    /// 健康检查端点
    static var health: HealthEndpoint { HealthEndpoint() }
}

// MARK: - Novels 端点信息

extension APIEndpoint.Novels: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list:
            return "/novels/"
        case .get(let novelId):
            return "/novels/\(novelId)"
        case .create:
            return "/novels/"
        case .update(let novelId):
            return "/novels/\(novelId)"
        case .updateStage(let novelId):
            return "/novels/\(novelId)/stage"
        case .delete(let novelId):
            return "/novels/\(novelId)"
        case .generateBibleAlias(let novelId, _):
            return "/novels/\(novelId)/bible/generate"
        case .updateAutoApproveMode(let novelId):
            return "/novels/\(novelId)/auto-approve-mode"
        case .statistics(let novelId):
            return "/novels/\(novelId)/statistics"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .get, .statistics:
            return .get
        case .create:
            return .post
        case .update, .updateStage:
            return .put
        case .delete:
            return .delete
        case .generateBibleAlias:
            return .post
        case .updateAutoApproveMode:
            return .patch
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .generateBibleAlias(_, let stage):
            return [URLQueryItem(name: "stage", value: stage)]
        default:
            return []
        }
    }
}

// MARK: - Chapters 端点信息

extension APIEndpoint.Chapters: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let novelId):
            return "/\(novelId)/chapters"
        case .create(let novelId):
            return "/\(novelId)/chapters"
        case .get(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)"
        case .update(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)"
        case .updateHint(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/hint"
        case .ensure(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/ensure"
        case .getReview(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/review"
        case .saveReview(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/review"
        case .aiReview(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/review-ai"
        case .structure(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/structure"
        case .guardrailSnapshot(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/guardrail-snapshot"
        case .updateMicroBeats(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/micro-beats"
        case .saveDraft(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/drafts"
        case .listDrafts(let novelId, let chapterNumber):
            return "/\(novelId)/chapters/\(chapterNumber)/drafts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .get, .getReview, .structure, .guardrailSnapshot, .listDrafts:
            return .get
        case .create, .ensure, .aiReview, .saveDraft:
            return .post
        case .update, .saveReview, .updateMicroBeats:
            return .put
        case .updateHint:
            return .patch
        }
    }

    var prefix: String { APIConfig.apiV1Prefix + "/novels" }
}

// MARK: - Autopilot 端点信息

extension APIEndpoint.Autopilot: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .start(let novelId):
            return "/autopilot/\(novelId)/start"
        case .stop(let novelId):
            return "/autopilot/\(novelId)/stop"
        case .resume(let novelId):
            return "/autopilot/\(novelId)/resume"
        case .status(let novelId):
            return "/autopilot/\(novelId)/status"
        case .circuitBreaker(let novelId):
            return "/autopilot/\(novelId)/circuit-breaker"
        case .resetCircuitBreaker(let novelId):
            return "/autopilot/\(novelId)/circuit-breaker/reset"
        case .stream(let novelId, _):
            return "/autopilot/\(novelId)/stream"
        case .logStream(let novelId, _):
            return "/autopilot/\(novelId)/log-stream"
        case .chapterStream(let novelId):
            return "/autopilot/\(novelId)/chapter-stream"
        case .systemResources:
            return "/autopilot/system/resources"
        case .cacheStats:
            return "/autopilot/system/cache/stats"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .status, .circuitBreaker, .stream, .logStream, .chapterStream,
             .systemResources, .cacheStats:
            return .get
        case .start, .stop, .resume, .resetCircuitBreaker:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .stream(_, let afterSeq), .logStream(_, let afterSeq):
            if let seq = afterSeq {
                return [URLQueryItem(name: "after_seq", value: String(seq))]
            }
            return []
        default:
            return []
        }
    }
}

// MARK: - Bible 端点信息

extension APIEndpoint.Bible: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .generate(let novelId, _):
            return "/bible/novels/\(novelId)/generate"
        case .generateStream(let novelId, _):
            return "/bible/novels/\(novelId)/generate-stream"
        case .create(let novelId):
            return "/bible/novels/\(novelId)/bible"
        case .get(let novelId):
            return "/bible/novels/\(novelId)/bible"
        case .update(let novelId):
            return "/bible/novels/\(novelId)/bible"
        case .status(let novelId):
            return "/bible/novels/\(novelId)/bible/status"
        case .generationFeedback(let novelId):
            return "/bible/novels/\(novelId)/bible/generation-feedback"
        case .characters(let novelId):
            return "/bible/novels/\(novelId)/bible/characters"
        case .addCharacter(let novelId):
            return "/bible/novels/\(novelId)/bible/characters"
        case .addWorldSetting(let novelId):
            return "/bible/novels/\(novelId)/bible/world-settings"
        case .addLocation(let novelId):
            return "/bible/novels/\(novelId)/bible/locations"
        case .addTimelineNote(let novelId):
            return "/bible/novels/\(novelId)/bible/timeline-notes"
        case .addStyleNote(let novelId):
            return "/bible/novels/\(novelId)/bible/style-notes"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get, .status, .generationFeedback, .characters:
            return .get
        case .generate, .generateStream, .create, .addCharacter,
             .addWorldSetting, .addLocation, .addTimelineNote, .addStyleNote:
            return .post
        case .update:
            return .put
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .generate(_, let stage), .generateStream(_, let stage):
            return [URLQueryItem(name: "stage", value: stage)]
        default:
            return []
        }
    }
}

// MARK: - DAG 端点信息

extension APIEndpoint.DAG: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .health:
            return "/dag/health/dag"
        case .registryTypes:
            return "/dag/registry/types"
        case .registryLinkage:
            return "/dag/registry/linkage"
        case .events(let novelId):
            return "/dag/events"
        case .get(let novelId):
            return "/dag/\(novelId)"
        case .node(let novelId, let nodeId):
            return "/dag/\(novelId)/nodes/\(nodeId)"
        case .toggleNode(let novelId, let nodeId):
            return "/dag/\(novelId)/nodes/\(nodeId)/toggle"
        case .status(let novelId):
            return "/dag/\(novelId)/status"
        case .nodePromptLive(let novelId, let nodeId):
            return "/dag/\(novelId)/nodes/\(nodeId)/prompt-live"
        case .nodePrompt(let novelId, let nodeId):
            return "/dag/\(novelId)/nodes/\(nodeId)/prompt"
        case .updateNode(let novelId, let nodeId):
            return "/dag/\(novelId)/nodes/\(nodeId)"
        case .run(let novelId):
            return "/dag/\(novelId)/run"
        case .stop(let novelId):
            return "/dag/\(novelId)/stop"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .health, .registryTypes, .registryLinkage, .events,
             .get, .node, .status, .nodePromptLive, .nodePrompt:
            return .get
        case .toggleNode, .run, .stop:
            return .post
        case .updateNode:
            return .put
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .events(let novelId):
            return [URLQueryItem(name: "novel_id", value: novelId)]
        default:
            return []
        }
    }
}

// MARK: - LLMControl 端点信息

extension APIEndpoint.LLMControl: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .panel:
            return "/llm-control"
        case .update:
            return "/llm-control"
        case .test:
            return "/llm-control/test"
        case .models:
            return "/llm-control/models"
        case .promptsPlazaInit:
            return "/llm-control/prompts/plaza-init"
        case .promptsStats:
            return "/llm-control/prompts/stats"
        case .promptsCategoriesInfo:
            return "/llm-control/prompts/categories-info"
        case .promptsTemplates:
            return "/llm-control/prompts/templates"
        case .createTemplate:
            return "/llm-control/prompts/templates"
        case .prompts:
            return "/llm-control/prompts"
        case .promptsByCategory:
            return "/llm-control/prompts/by-category"
        case .promptNode(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)"
        case .createPromptNode:
            return "/llm-control/prompts/nodes"
        case .deletePromptNode(let nodeId):
            return "/llm-control/prompts/nodes/\(nodeId)"
        case .promptVersions(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/versions"
        case .promptVersion(let versionId):
            return "/llm-control/prompts/versions/\(versionId)"
        case .updatePrompt(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)"
        case .rollbackPrompt(let nodeKey, let versionId):
            return "/llm-control/prompts/\(nodeKey)/rollback/\(versionId)"
        case .comparePrompts(let v1Id, let v2Id):
            return "/llm-control/prompts/compare/\(v1Id)/\(v2Id)"
        case .renderPrompt(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/render"
        case .debugPrompt(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/debug"
        case .promptChain(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/chain"
        case .promptSandbox(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/sandbox"
        case .promptVariables:
            return "/llm-control/prompts/variables"
        case .promptBindings(let nodeKey):
            return "/llm-control/prompts/\(nodeKey)/bindings"
        case .exportPrompts:
            return "/llm-control/prompts/export"
        case .importPrompts:
            return "/llm-control/prompts/import"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .panel, .promptsPlazaInit, .promptsStats, .promptsCategoriesInfo,
             .promptsTemplates, .prompts, .promptsByCategory, .promptNode,
             .promptVersions, .promptVersion, .promptChain, .promptVariables,
             .promptBindings, .exportPrompts, .comparePrompts:
            return .get
        case .createPromptNode, .test, .models, .rollbackPrompt,
             .renderPrompt, .debugPrompt, .promptSandbox, .importPrompts,
             .createTemplate:
            return .post
        case .update, .updatePrompt:
            return .put
        case .deletePromptNode:
            return .delete
        }
    }
}

// MARK: - Planning 端点信息

extension APIEndpoint.Planning: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .macroStream(let novelId):
            return "/planning/novels/\(novelId)/macro/stream"
        case .macroProgressStream(let novelId):
            return "/planning/novels/\(novelId)/macro/progress/stream"
        case .macroGenerate(let novelId):
            return "/planning/novels/\(novelId)/macro/generate"
        case .macroProgress(let novelId):
            return "/planning/novels/\(novelId)/macro/progress"
        case .macroResult(let novelId):
            return "/planning/novels/\(novelId)/macro/result"
        case .macroConfirm(let novelId):
            return "/planning/novels/\(novelId)/macro/confirm"
        case .continuePlanning(let novelId):
            return "/planning/novels/\(novelId)/continue"
        case .structure(let novelId):
            return "/planning/novels/\(novelId)/structure"
        case .actChaptersStream(let actId):
            return "/planning/acts/\(actId)/chapters/stream"
        case .actChaptersGenerate(let actId):
            return "/planning/acts/\(actId)/chapters/generate"
        case .actChaptersConfirm(let actId):
            return "/planning/acts/\(actId)/chapters/confirm"
        case .createNextAct(let actId):
            return "/planning/acts/\(actId)/create-next"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .macroStream, .macroProgressStream, .macroProgress,
             .macroResult, .structure, .actChaptersStream:
            return .get
        case .macroGenerate, .macroConfirm, .continuePlanning,
             .actChaptersGenerate, .actChaptersConfirm, .createNextAct:
            return .post
        }
    }
}

// MARK: - Stats 端点信息（前缀 /api/stats）
// 对齐原项目 stats.ts：路径 /stats/global、/stats/book/{slug}/chapter/{id}、/stats/book/{slug}/progress
// 仓颉 statsPrefix=/api/stats，端点 path 不含 /stats 前缀

extension APIEndpoint.Stats: APIEndpoint.EndpointInfo {
    var prefix: String { APIConfig.statsPrefix }

    var path: String {
        switch self {
        case .global:
            // stats.ts:16 — GET /stats/global → 仓颉 path=/global（prefix=/api/stats）
            return "/global"
        case .chapter(let slug, let chapterId):
            // stats.ts:23 — GET /stats/book/{slug}/chapter/{chapterId} → 仓颉 path=/book/{slug}/chapter/{chapterId}
            return "/book/\(slug)/chapter/\(chapterId)"
        case .progress(let slug, _):
            // stats.ts:30 — GET /stats/book/{slug}/progress → 仓颉 path=/book/{slug}/progress
            return "/book/\(slug)/progress"
        }
    }

    var method: HTTPMethod { .get }

    var queryItems: [URLQueryItem] {
        switch self {
        case .progress(_, let days):
            // stats.ts:31 — params: { days }
            return [URLQueryItem(name: "days", value: String(days))]
        default:
            return []
        }
    }
}

// MARK: - StoryStructure 端点信息

extension APIEndpoint.StoryStructure: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .get(let novelId):
            return "/novels/\(novelId)/structure"
        case .children(let novelId):
            return "/novels/\(novelId)/structure/children"
        case .createNode(let novelId):
            return "/novels/\(novelId)/structure/nodes"
        case .updateNode(let novelId, let nodeId):
            return "/novels/\(novelId)/structure/nodes/\(nodeId)"
        case .deleteNode(let novelId, let nodeId):
            return "/novels/\(novelId)/structure/nodes/\(nodeId)"
        case .reorder(let novelId):
            return "/novels/\(novelId)/structure/reorder"
        case .updateRanges(let novelId):
            return "/novels/\(novelId)/structure/update-ranges"
        case .createDefault(let novelId):
            return "/novels/\(novelId)/structure/create-default"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get, .children:
            return .get
        case .createNode, .reorder, .updateRanges, .createDefault:
            return .post
        case .updateNode:
            return .put
        case .deleteNode:
            return .delete
        }
    }
}

// MARK: - Cast 端点信息

extension APIEndpoint.Cast: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .graph(let novelId):
            return "/novels/\(novelId)/cast"
        case .search(let novelId):
            return "/novels/\(novelId)/cast/search"
        case .coverage(let novelId):
            return "/novels/\(novelId)/cast/coverage"
        case .schedule(let novelId):
            return "/novels/\(novelId)/cast/schedule"
        case .narrativeProfile(let novelId, let characterId):
            return "/novels/\(novelId)/characters/\(characterId)/narrative-profile"
        case .entityMemory(let novelId, let entityId):
            return "/novels/\(novelId)/entities/\(entityId)/memory"
        case .projection(let novelId, let characterId):
            return "/novels/\(novelId)/characters/\(characterId)/projection"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .graph, .search, .coverage, .narrativeProfile, .entityMemory, .projection:
            return .get
        case .schedule:
            return .post
        }
    }
}

// MARK: - Foreshadow 端点信息

extension APIEndpoint.Foreshadow: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .create(let novelId):
            return "/novels/\(novelId)/foreshadow-ledger"
        case .list(let novelId):
            return "/novels/\(novelId)/foreshadow-ledger"
        case .get(let novelId, let entryId):
            return "/novels/\(novelId)/foreshadow-ledger/\(entryId)"
        case .update(let novelId, let entryId):
            return "/novels/\(novelId)/foreshadow-ledger/\(entryId)"
        case .delete(let novelId, let entryId):
            return "/novels/\(novelId)/foreshadow-ledger/\(entryId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .get:
            return .get
        case .create:
            return .post
        case .update:
            return .put
        case .delete:
            return .delete
        }
    }
}

// MARK: - Monitor 端点信息

extension APIEndpoint.Monitor: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .tensionCurve(let novelId):
            return "/novels/\(novelId)/monitor/tension-curve"
        case .voiceDrift(let novelId):
            return "/novels/\(novelId)/monitor/voice-drift"
        case .foreshadowStats(let novelId):
            return "/novels/\(novelId)/monitor/foreshadow-stats"
        }
    }

    var method: HTTPMethod { .get }
}

// MARK: - Export 端点信息

extension APIEndpoint.Export: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .novel(let novelId):
            return "/export/novel/\(novelId)"
        case .chapter(let chapterId):
            return "/export/chapter/\(chapterId)"
        }
    }

    var method: HTTPMethod { .get }
}

// MARK: - Checkpoints 端点信息

extension APIEndpoint.Checkpoints: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let novelId):
            return "/novels/\(novelId)/checkpoints"
        case .create(let novelId):
            return "/novels/\(novelId)/checkpoints"
        case .rollback(let novelId, let checkpointId):
            return "/novels/\(novelId)/checkpoints/\(checkpointId)/rollback"
        case .branches(let novelId):
            return "/novels/\(novelId)/checkpoints/branches"
        case .head(let novelId):
            return "/novels/\(novelId)/checkpoints/head"
        case .guardrailCheck(let novelId):
            return "/novels/\(novelId)/guardrail/check"
        case .storyPhase(let novelId):
            return "/novels/\(novelId)/story-phase"
        case .updateStoryPhase(let novelId):
            return "/novels/\(novelId)/story-phase"
        case .characterPsyches(let novelId):
            return "/novels/\(novelId)/character-psyches"
        case .characterPsycheDetail(let novelId, let characterName):
            return "/novels/\(novelId)/character-psyches/\(characterName)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .branches, .head, .storyPhase, .characterPsyches, .characterPsycheDetail:
            return .get
        case .create, .rollback, .guardrailCheck:
            return .post
        case .updateStoryPhase:
            return .put
        }
    }
}

// MARK: - Snapshots 端点信息

extension APIEndpoint.Snapshots: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let novelId):
            return "/novels/\(novelId)/snapshots"
        case .get(let novelId, let snapshotId):
            return "/novels/\(novelId)/snapshots/\(snapshotId)"
        case .create(let novelId):
            return "/novels/\(novelId)/snapshots"
        case .delete(let novelId, let snapshotId):
            return "/novels/\(novelId)/snapshots/\(snapshotId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .get:
            return .get
        case .create:
            return .post
        case .delete:
            return .delete
        }
    }
}

// MARK: - Governance 端点信息

extension APIEndpoint.Governance: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .state(let novelId):
            return "/novels/\(novelId)/governance/state"
        case .contract(let novelId):
            return "/novels/\(novelId)/governance/contract"
        case .mergeStorylines(let novelId):
            return "/novels/\(novelId)/governance/storylines/merge"
        case .chapterBudgetPreview(let novelId):
            return "/novels/\(novelId)/governance/chapter-budget/preview"
        case .reviewAction(let novelId):
            return "/novels/\(novelId)/governance/review-action"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .state:
            return .get
        case .contract, .mergeStorylines, .chapterBudgetPreview, .reviewAction:
            return .post
        }
    }
}

// MARK: - Evolution 端点信息

extension APIEndpoint.Evolution: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .snapshots(let novelId):
            return "/novels/\(novelId)/evolution/snapshots"
        case .snapshotAtChapter(let novelId, let chapterNumber):
            return "/novels/\(novelId)/evolution/snapshots/\(chapterNumber)"
        case .gate(let novelId):
            return "/novels/\(novelId)/evolution/gate"
        case .snapshotOverrides(let novelId, let chapterNumber):
            return "/novels/\(novelId)/evolution/snapshots/\(chapterNumber)/overrides"
        case .replay(let novelId, let chapterNumber):
            return "/novels/\(novelId)/evolution/replay-from/\(chapterNumber)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .snapshots, .snapshotAtChapter:
            return .get
        case .gate, .snapshotOverrides, .replay:
            return .post
        }
    }
}

// MARK: - Chronicles 端点信息

extension APIEndpoint.Chronicles: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .get(let novelId):
            return "/novels/\(novelId)/chronicles"
        case .rollback(let novelId, let snapshotId):
            return "/novels/\(novelId)/snapshots/\(snapshotId)/rollback"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get:
            return .get
        case .rollback:
            return .post
        }
    }
}

// MARK: - Trace 端点信息

extension APIEndpoint.Trace: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let novelId):
            return "/novels/\(novelId)/traces"
        case .stats(let novelId):
            return "/novels/\(novelId)/traces/stats"
        case .aiTraces(let novelId):
            return "/novels/\(novelId)/ai-traces"
        case .timeline(let novelId, let traceId):
            return "/novels/\(novelId)/traces/\(traceId)/timeline"
        case .aiStages(let novelId):
            return "/novels/\(novelId)/ai-traces/stages"
        case .aiByStage(let novelId, let stage):
            return "/novels/\(novelId)/ai-traces/by-stage/\(stage)"
        }
    }

    var method: HTTPMethod { .get }
}

// MARK: - Props 端点信息

extension APIEndpoint.Props: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let novelId):
            return "/novels/\(novelId)/props"
        case .create(let novelId):
            return "/novels/\(novelId)/props"
        case .get(let novelId, let propId):
            return "/novels/\(novelId)/props/\(propId)"
        case .update(let novelId, let propId):
            return "/novels/\(novelId)/props/\(propId)"
        case .delete(let novelId, let propId):
            return "/novels/\(novelId)/props/\(propId)"
        case .events(let novelId, let propId):
            return "/novels/\(novelId)/props/\(propId)/events"
        case .createEvent(let novelId, let propId):
            return "/novels/\(novelId)/props/\(propId)/events"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .get, .events:
            return .get
        case .create, .createEvent:
            return .post
        case .update:
            return .patch
        case .delete:
            return .delete
        }
    }
}

// MARK: - AntiAI 端点信息

extension APIEndpoint.AntiAI: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .scan:
            return "/anti-ai/scan"
        case .categories:
            return "/anti-ai/categories"
        case .rules:
            return "/anti-ai/rules"
        case .allowlist:
            return "/anti-ai/allowlist"
        case .allowlistScenes:
            return "/anti-ai/allowlist/scenes"
        case .stats:
            return "/anti-ai/stats"
        case .audits(let novelId):
            return "/anti-ai/audits/\(novelId)"
        case .chapterAudit(let novelId, let chapterNumber):
            return "/anti-ai/audits/\(novelId)/\(chapterNumber)"
        case .trend(let novelId):
            return "/anti-ai/trend/\(novelId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .categories, .rules, .allowlistScenes, .stats, .audits, .chapterAudit, .trend:
            return .get
        case .scan, .allowlist:
            return .post
        }
    }
}

// MARK: - Sandbox 端点信息

extension APIEndpoint.Sandbox: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .dialogueWhitelist(let novelId):
            return "/novels/\(novelId)/sandbox/dialogue-whitelist"
        case .characterAnchor(let novelId, let characterId):
            return "/novels/\(novelId)/sandbox/character/\(characterId)/anchor"
        case .patchCharacterAnchor(let novelId, let characterId):
            return "/novels/\(novelId)/sandbox/character/\(characterId)/anchor"
        case .generateDialogue:
            // sandbox.ts:76 — POST /novels/sandbox/generate-dialogue（novel_id 在 body 中，无路径参数）
            return "/novels/sandbox/generate-dialogue"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .dialogueWhitelist, .characterAnchor:
            return .get
        case .patchCharacterAnchor:
            return .patch
        case .generateDialogue:
            return .post
        }
    }
}

// MARK: - KnowledgeGraph 端点信息

extension APIEndpoint.KnowledgeGraph: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .triples(let novelId):
            return "/knowledge-graph/novels/\(novelId)/triples"
        case .infer(let novelId):
            return "/knowledge-graph/novels/\(novelId)/infer"
        case .inferenceEvidence(let novelId, let chapterNumber):
            return "/knowledge-graph/novels/\(novelId)/chapters/by-number/\(chapterNumber)/inference-evidence"
        case .deleteChapterInference(let novelId, let chapterNumber):
            return "/knowledge-graph/novels/\(novelId)/chapters/by-number/\(chapterNumber)/inference"
        case .deleteInferredTriple(let novelId, let tripleId):
            return "/knowledge-graph/novels/\(novelId)/inferred-triples/\(tripleId)"
        case .confirmTriple(let tripleId):
            return "/knowledge-graph/triples/\(tripleId)/confirm"
        case .starTriple(let novelId, let tripleId):
            return "/knowledge-graph/novels/\(novelId)/triples/\(tripleId)/star"
        case .deleteTriple(let tripleId):
            return "/knowledge-graph/triples/\(tripleId)"
        case .elementRelations(let elementType, let elementId):
            return "/knowledge-graph/elements/\(elementType)/\(elementId)/relations"
        case .statistics(let novelId):
            return "/knowledge-graph/novels/\(novelId)/statistics"
        case .index(let novelId):
            return "/knowledge-graph/novels/\(novelId)/index"
        case .search(let novelId):
            return "/knowledge-graph/novels/\(novelId)/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .triples, .inferenceEvidence, .elementRelations, .statistics:
            return .get
        case .infer, .index, .search, .confirmTriple:
            return .post
        case .deleteChapterInference, .deleteInferredTriple, .deleteTriple:
            return .delete
        case .starTriple:
            return .patch
        }
    }
}

// MARK: - Voice 端点信息 — voice.ts:26-40

extension APIEndpoint.Voice: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .createSample(let novelId):
            // voice.ts:30 — `/novels/${novelId}/voice/samples`
            return "/novels/\(novelId)/voice/samples"
        case .getFingerprint(let novelId, _):
            // voice.ts:37 — `/novels/${novelId}/voice/fingerprint`
            return "/novels/\(novelId)/voice/fingerprint"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .createSample:
            // voice.ts:29 — POST
            return .post
        case .getFingerprint:
            // voice.ts:36 — GET
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .createSample:
            return []
        case .getFingerprint(_, let povCharacterId):
            // voice.ts:38 — params: povCharacterId ? { pov_character_id: povCharacterId } : {}
            if let povCharacterId = povCharacterId, !povCharacterId.isEmpty {
                return [URLQueryItem(name: "pov_character_id", value: povCharacterId)]
            }
            return []
        }
    }
}

// MARK: - AIInvocation 端点信息 — aiInvocation.ts:221-255

extension APIEndpoint.AIInvocation: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .create:
            return "/ai-invocations"
        case .get(let sessionId):
            return "/ai-invocations/\(sessionId)"
        case .accept(let sessionId):
            return "/ai-invocations/\(sessionId)/accept"
        case .reject(let sessionId):
            return "/ai-invocations/\(sessionId)/reject"
        case .resume(let sessionId):
            return "/ai-invocations/\(sessionId)/resume"
        case .retry(let sessionId):
            return "/ai-invocations/\(sessionId)/retry"
        case .previewPromptDraft(let sessionId):
            return "/ai-invocations/\(sessionId)/prompt-draft/preview"
        case .savePromptDraft(let sessionId):
            return "/ai-invocations/\(sessionId)/prompt-draft"
        case .updateVariables(let sessionId):
            return "/ai-invocations/\(sessionId)/variables"
        case .commit(let sessionId):
            return "/ai-invocations/\(sessionId)/commits"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get:
            return .get
        case .create, .accept, .reject, .resume, .retry,
             .previewPromptDraft, .commit:
            return .post
        case .savePromptDraft, .updateVariables:
            return .put
        }
    }
}

// MARK: - Workflow 端点信息 — workflow.ts:790-806

extension APIEndpoint.Workflow: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .getPlotOutline(let novelId):
            return "/novels/\(novelId)/setup/plot-outline"
        case .savePlotOutline(let novelId):
            return "/novels/\(novelId)/setup/plot-outline"
        case .generatePlotOutline(let novelId):
            return "/novels/\(novelId)/setup/generate-plot-outline"
        case .getStorylines(let novelId):
            // workflow.ts:775 — /novels/${novelId}/storylines
            return "/novels/\(novelId)/storylines"
        case .getStorylineGraphData(let novelId):
            // workflow.ts:779 — /novels/${novelId}/storylines/graph-data
            return "/novels/\(novelId)/storylines/graph-data"
        case .analyzeScene(let novelId):
            // workflow.ts:230 — /novels/${novelId}/scene-director/analyze
            return "/novels/\(novelId)/scene-director/analyze"
        case .retrieveContext(let novelId):
            // workflow.ts:885 — /novels/${novelId}/context/retrieve
            return "/novels/\(novelId)/context/retrieve"
        case .suggestMainPlotOptions(let novelId):
            // workflow.ts:832 — /novels/${novelId}/setup/suggest-main-plot-options
            return "/novels/\(novelId)/setup/suggest-main-plot-options"
        // P1 新增
        case .createStoryline(let novelId):
            // workflow.ts — POST /novels/${novelId}/storylines
            return "/novels/\(novelId)/storylines"
        case .updateStoryline(let novelId, let storylineId):
            // workflow.ts — PUT /novels/${novelId}/storylines/${storylineId}
            return "/novels/\(novelId)/storylines/\(storylineId)"
        case .deleteStoryline(let novelId, let storylineId):
            // workflow.ts — DELETE /novels/${novelId}/storylines/${storylineId}
            return "/novels/\(novelId)/storylines/\(storylineId)"
        case .getPlotArc(let novelId):
            // workflow.ts — GET /novels/${novelId}/plot-arc
            return "/novels/\(novelId)/plot-arc"
        case .createPlotArc(let novelId):
            // workflow.ts — POST /novels/${novelId}/plot-arc
            return "/novels/\(novelId)/plot-arc"
        case .planNovel(let novelId):
            // workflow.ts — POST /novels/${novelId}/plan
            return "/novels/\(novelId)/plan"
        case .reviewChapter(let novelId, let chapterNumber):
            // workflow.ts — POST /novels/${novelId}/chapters/${chapterNumber}/review
            return "/novels/\(novelId)/chapters/\(chapterNumber)/review"
        case .extendOutline(let novelId):
            // workflow.ts — POST /novels/${novelId}/outline/extend
            return "/novels/\(novelId)/outline/extend"
        case .getJobStatus(let jobId):
            // workflow.ts — GET /jobs/${jobId}
            return "/jobs/\(jobId)"
        case .cancelJob(let jobId):
            // workflow.ts — POST /jobs/${jobId}/cancel
            return "/jobs/\(jobId)/cancel"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getPlotOutline:
            return .get
        case .savePlotOutline:
            return .put
        case .generatePlotOutline:
            return .post
        case .getStorylines, .getStorylineGraphData:
            // workflow.ts:775/779 — GET
            return .get
        case .analyzeScene, .retrieveContext, .suggestMainPlotOptions:
            // workflow.ts:229/881/831 — POST
            return .post
        // P1 新增
        case .createStoryline, .createPlotArc, .planNovel, .reviewChapter, .extendOutline, .cancelJob:
            return .post
        case .updateStoryline:
            return .put
        case .deleteStoryline:
            return .delete
        case .getPlotArc, .getJobStatus:
            return .get
        }
    }
}

// MARK: - Tools 端点信息 — tools.ts:24-28

extension APIEndpoint.Tools: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .tensionSlingshot(let novelId):
            // tools.ts:25 — /novels/${novelId}/writer-block/tension-slingshot
            return "/novels/\(novelId)/writer-block/tension-slingshot"
        // P1 新增：宏观重构 + 实体状态
        case .scanBreakpoints(let novelId, _, _):
            // tools.ts:87 — /novels/${novelId}/macro-refactor/breakpoints
            return "/novels/\(novelId)/macro-refactor/breakpoints"
        case .generateProposal(let novelId):
            // tools.ts:93 — /novels/${novelId}/macro-refactor/proposals
            return "/novels/\(novelId)/macro-refactor/proposals"
        case .applyMutations(let novelId):
            // tools.ts:100 — /novels/${novelId}/macro-refactor/apply
            return "/novels/\(novelId)/macro-refactor/apply"
        case .getLatestDiagnosis(let novelId):
            // tools.ts:107 — /novels/${novelId}/macro-refactor/diagnosis/latest
            return "/novels/\(novelId)/macro-refactor/diagnosis/latest"
        case .getDiagnosisHistory(let novelId, _):
            // tools.ts:113 — /novels/${novelId}/macro-refactor/diagnosis/history
            return "/novels/\(novelId)/macro-refactor/diagnosis/history"
        case .runDiagnosis(let novelId, _):
            // tools.ts:121 — /novels/${novelId}/macro-refactor/diagnosis/run
            return "/novels/\(novelId)/macro-refactor/diagnosis/run"
        case .resolveDiagnosis(let novelId, let diagId):
            // tools.ts:128 — /novels/${novelId}/macro-refactor/diagnosis/${diagnosisId}/resolve
            return "/novels/\(novelId)/macro-refactor/diagnosis/\(diagId)/resolve"
        case .getEntityState(let novelId, let entityId, _):
            // tools.ts:143 — /novels/${novelId}/entities/${entityId}/state
            return "/novels/\(novelId)/entities/\(entityId)/state"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .tensionSlingshot:
            // tools.ts:24 — POST
            return .post
        // P1 新增
        case .scanBreakpoints, .getLatestDiagnosis, .getDiagnosisHistory, .getEntityState:
            return .get
        case .generateProposal, .applyMutations, .runDiagnosis, .resolveDiagnosis:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .tensionSlingshot:
            return []
        case .scanBreakpoints(_, let trait, let conflictTags):
            // tools.ts:88 — params: { trait, ...(conflictTags ? { conflict_tags: conflictTags } : {}) }
            var items = [URLQueryItem(name: "trait", value: trait)]
            if let tags = conflictTags, !tags.isEmpty {
                items.append(URLQueryItem(name: "conflict_tags", value: tags))
            }
            return items
        case .getDiagnosisHistory(_, let limit):
            // tools.ts:115 — params: { limit }
            return [URLQueryItem(name: "limit", value: String(limit))]
        case .runDiagnosis(_, let traits):
            // tools.ts:123 — params: traits ? { traits } : {}
            if let t = traits, !t.isEmpty {
                return [URLQueryItem(name: "traits", value: t)]
            }
            return []
        case .getEntityState(_, _, let chapter):
            // tools.ts:145 — params: { chapter }
            return [URLQueryItem(name: "chapter", value: String(chapter))]
        default:
            return []
        }
    }
}

// MARK: - ChapterElement 端点信息 — chapterElement.ts:38-74

extension APIEndpoint.ChapterElement: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .list(let chapterId):
            return "/chapters/\(chapterId)/elements"
        case .create(let chapterId):
            return "/chapters/\(chapterId)/elements"
        case .batchUpdate(let chapterId):
            return "/chapters/\(chapterId)/elements"
        case .delete(let chapterId, let elementId):
            return "/chapters/\(chapterId)/elements/\(elementId)"
        case .chaptersByElement(let elementType, let elementId):
            return "/chapters/elements/\(elementType)/\(elementId)/chapters"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .chaptersByElement:
            return .get
        case .create:
            return .post
        case .batchUpdate:
            return .put
        case .delete:
            return .delete
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list:
            // element_type 可选查询参数，由调用方通过 URL 注入
            return []
        default:
            return []
        }
    }
}

// MARK: - Manuscript 端点信息 — manuscript.ts:25-46

extension APIEndpoint.Manuscript: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .chapterMentions(let novelId, let chapterNumber):
            return "/novels/\(novelId)/chapters/\(chapterNumber)/entity-mentions"
        case .reindexMentions(let novelId, let chapterNumber):
            return "/novels/\(novelId)/chapters/\(chapterNumber)/entity-mentions/reindex"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .chapterMentions:
            return .get
        case .reindexMentions:
            return .post
        }
    }
}

// MARK: - NarrativeEngine 端点信息 — narrativeEngine.ts:84-88

extension APIEndpoint.NarrativeEngine: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .storyEvolution(let novelId):
            return "/novels/\(novelId)/narrative-engine/story-evolution"
        }
    }

    var method: HTTPMethod { .get }
}

// MARK: - BeatSheets 端点信息

extension APIEndpoint.BeatSheets: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .get(let novelId):
            return "/beat-sheets/novels/\(novelId)"
        case .update(let novelId):
            return "/beat-sheets/novels/\(novelId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get:
            return .get
        case .update:
            return .put
        }
    }
}

// MARK: - Worldline 端点信息 — worldline.ts:52-115 + confluence.ts:16-18

extension APIEndpoint.Worldline: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .graph(let novelId):
            return "/novels/\(novelId)/worldline/graph"
        case .checkpoints(let novelId):
            return "/novels/\(novelId)/worldline/checkpoints"
        case .createCheckpoint(let novelId):
            return "/novels/\(novelId)/worldline/checkpoints"
        case .branches(let novelId):
            return "/novels/\(novelId)/worldline/branches"
        case .createBranch(let novelId):
            return "/novels/\(novelId)/worldline/branches"
        case .checkout(let novelId, let checkpointId):
            return "/novels/\(novelId)/worldline/checkpoints/\(checkpointId)/checkout"
        case .hardReset(let novelId, let checkpointId):
            return "/novels/\(novelId)/worldline/checkpoints/\(checkpointId)/hard-reset"
        case .deleteCheckpoint(let novelId, let checkpointId):
            return "/novels/\(novelId)/worldline/checkpoints/\(checkpointId)"
        case .branchByStoryline(let novelId, let storylineId):
            return "/novels/\(novelId)/worldline/branches/by-storyline/\(storylineId)"
        case .updateBranch(let novelId, let branchId):
            return "/novels/\(novelId)/worldline/branches/\(branchId)"
        case .mergeBranch(let novelId, let branchId):
            return "/novels/\(novelId)/worldline/branches/\(branchId)/merge"
        case .confluenceList(let novelId):
            return "/novels/\(novelId)/confluence-points"
        case .createConfluence(let novelId):
            // workflow.ts — POST /novels/${novelId}/confluence-points
            return "/novels/\(novelId)/confluence-points"
        case .updateConfluence(let novelId, let cpId):
            // workflow.ts — PATCH /novels/${novelId}/confluence-points/${cpId}
            return "/novels/\(novelId)/confluence-points/\(cpId)"
        case .deleteConfluence(let novelId, let cpId):
            // workflow.ts — DELETE /novels/${novelId}/confluence-points/${cpId}
            return "/novels/\(novelId)/confluence-points/\(cpId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .graph, .checkpoints, .branches, .branchByStoryline, .confluenceList:
            return .get
        case .createCheckpoint, .createBranch, .checkout, .hardReset, .mergeBranch:
            return .post
        case .deleteCheckpoint:
            return .delete
        case .updateBranch:
            return .put
        // P1 新增
        case .createConfluence:
            return .post
        case .updateConfluence:
            return .patch
        case .deleteConfluence:
            return .delete
        }
    }
}

// MARK: - Knowledge 端点信息 — knowledge.ts:71-106

extension APIEndpoint.Knowledge: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .get(let novelId):
            // knowledge.ts:76 — `/novels/${novelId}/knowledge`
            return "/novels/\(novelId)/knowledge"
        case .update(let novelId):
            // knowledge.ts:82 — `/novels/${novelId}/knowledge`
            return "/novels/\(novelId)/knowledge"
        case .search(let novelId, _, _):
            // knowledge.ts:93 — `/novels/${novelId}/knowledge/search`
            return "/novels/\(novelId)/knowledge/search"
        case .generate(let novelId):
            // knowledge.ts:104 — `/novels/${novelId}/knowledge/generate`
            return "/novels/\(novelId)/knowledge/generate"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get, .search:
            // knowledge.ts:75 GET, knowledge.ts:91 GET
            return .get
        case .update:
            // knowledge.ts:81 PUT
            return .put
        case .generate:
            // knowledge.ts:100 POST
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .search(_, let query, let k):
            // knowledge.ts:93 — params: { q: query, k }
            return [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "k", value: String(k)),
            ]
        default:
            return []
        }
    }
}

// MARK: - Memory 端点信息 — memory.ts:37-65（P1 新增，U4 决策）

extension APIEndpoint.Memory: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .getCharacterProjection(let novelId, let characterId):
            // memory.ts:39 — /novels/${novelId}/characters/${characterId}/projection
            return "/novels/\(novelId)/characters/\(characterId)/projection"
        case .getChapterCandidates(let novelId, let chapterNumber):
            // memory.ts:45 — /novels/${novelId}/chapters/${chapterNumber}/memory-candidates
            return "/novels/\(novelId)/chapters/\(chapterNumber)/memory-candidates"
        case .confirmAtom(let novelId, let atomId):
            // memory.ts:50 — /novels/${novelId}/memory-atoms/${atomId}/confirm
            return "/novels/\(novelId)/memory-atoms/\(atomId)/confirm"
        case .rejectAtom(let novelId, let atomId):
            // memory.ts:55 — /novels/${novelId}/memory-atoms/${atomId}/reject
            return "/novels/\(novelId)/memory-atoms/\(atomId)/reject"
        case .promoteAtom(let novelId, let atomId):
            // memory.ts:61 — /novels/${novelId}/memory-atoms/${atomId}/promote
            return "/novels/\(novelId)/memory-atoms/\(atomId)/promote"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getCharacterProjection, .getChapterCandidates:
            // memory.ts:38/43 — GET
            return .get
        case .confirmAtom, .rejectAtom, .promoteAtom:
            // memory.ts:48/54/60 — POST
            return .post
        }
    }
}

// MARK: - Worldbuilding 端点信息 — worldbuilding.ts:48-56（P1 新增）

extension APIEndpoint.Worldbuilding: APIEndpoint.EndpointInfo {
    var path: String {
        switch self {
        case .get(let novelId):
            // worldbuilding.ts:52 — /novels/${novelId}/worldbuilding
            return "/novels/\(novelId)/worldbuilding"
        case .update(let novelId):
            // worldbuilding.ts:55 — /novels/${novelId}/worldbuilding
            return "/novels/\(novelId)/worldbuilding"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .get:
            // worldbuilding.ts:49 — GET
            return .get
        case .update:
            // worldbuilding.ts:54 — PUT
            return .put
        }
    }
}
