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

    // MARK: - Worldline（世界线）
    enum Worldline {
        /// 世界线图 — `GET /novels/{novel_id}/worldline/graph`
        case graph(novelId: String)
        /// 检查点列表 — `GET /novels/{novel_id}/worldline/checkpoints`
        case checkpoints(novelId: String)
        /// 分支列表 — `GET /novels/{novel_id}/worldline/branches`
        case branches(novelId: String)
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
        /// 生成对话 — `POST /novels/{novel_id}/sandbox/generate-dialogue`
        case generateDialogue(novelId: String)
    }

    // MARK: - BeatSheets（节拍表）
    enum BeatSheets {
        /// 获取节拍表 — `GET /beat-sheets/novels/{novel_id}`
        case get(novelId: String)
        /// 更新节拍表 — `PUT /beat-sheets/novels/{novel_id}`
        case update(novelId: String)
    }

    // MARK: - Taxonomy（分类法）
    enum Taxonomy {
        /// 内置分类包 — `GET /taxonomy/bundles/builtin_cn_v1`
        case builtinBundle
        /// 开篇画像 — `GET /taxonomy/opening-profiles/cn_v1`
        case openingProfiles
    }

    // MARK: - Stats（统计 API，前缀 /api/stats）
    enum Stats {
        /// 全局统计 — `GET /`
        case global
        /// 章节统计 — `GET /chapters/{novel_id}`
        case chapters(novelId: String)
        /// 进度统计 — `GET /progress/{novel_id}`
        case progress(novelId: String)
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
        case .generateBibleAlias(let novelId, let stage):
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
             .renderPrompt, .debugPrompt, .promptSandbox, .importPrompts:
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

extension APIEndpoint.Stats: APIEndpoint.EndpointInfo {
    var prefix: String { APIConfig.statsPrefix }

    var path: String {
        switch self {
        case .global:
            return "/"
        case .chapters(let novelId):
            return "/chapters/\(novelId)"
        case .progress(let novelId):
            return "/progress/\(novelId)"
        }
    }

    var method: HTTPMethod { .get }
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
        }
    }

    var method: HTTPMethod { .get }
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
        case .generateDialogue(let novelId):
            return "/novels/\(novelId)/sandbox/generate-dialogue"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .dialogueWhitelist, .characterAnchor:
            return .get
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
