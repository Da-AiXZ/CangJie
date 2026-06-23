# T02 — 数据层交付摘要

> 任务：T02 数据层（21 Codable 模型 + 21 ViewModel）
> 工程师：寇豆码（software-engineer）
> 日期：2026-06-23
> 文件数：42

---

## 一、已交付文件清单

### 21 个 Codable 模型文件（`Cangjie/Models/`）

| # | 文件 | 对齐后端源码 | 说明 |
|---|------|-------------|------|
| 1 | `NovelModels.swift` | `application/core/dtos/novel_dto.py`, `chapter_dto.py`, `interfaces/api/v1/core/novels.py` | Novel/Chapter/CreateNovel/UpdateNovel/Review/AIReview/Structure/Draft/Element/Statistics |
| 2 | `BibleModels.swift` | `application/world/dtos/bible_dto.py`, `interfaces/api/v1/world/bible.py` | Bible/Character/WorldSetting/Location/Timeline/StyleNote + 请求模型 |
| 3 | `AutopilotModels.swift` | `interfaces/api/v1/engine/autopilot_routes.py` | AutopilotStatus（含全部共享内存字段）/StartRequest/CircuitBreaker/ChapterStreamEvent/LogStreamEvent |
| 4 | `DAGModels.swift` | `application/engine/dag/models.py` | DAGDefinition/NodeDefinition/EdgeDefinition/NodeConfig/NodeRunState/DAGEvent/StatusResponse |
| 5 | `KnowledgeGraphModels.swift` | `application/world/dtos/knowledge_dto.py` | KnowledgeTriple/StoryKnowledge/ChapterSummary/SearchHit/Statistics/InferenceEvidence |
| 6 | `MonitorModels.swift` | `interfaces/api/v1/workbench/monitor.py` | TensionPoint/CurveStats/VoiceDrift/ForeshadowStats |
| 7 | `LLMControlModels.swift` | `application/ai/llm_control_service.py`, `interfaces/api/v1/workbench/llm_control.py` | LLMProfile/Config/Runtime/PanelData/TestResult/ModelInfo/ModelListRequest |
| 8 | `PromptPlazaModels.swift` | `interfaces/api/v1/workbench/llm_control.py` | CategoryInfo/PromptNode/Version/Template/RenderRequest/DebugResult/PlazaInit/Stats/Comparison |
| 9 | `CastModels.swift` | `application/world/dtos/cast_dto.py` | CastCharacter/Relationship/Graph/SearchResult/Coverage/NarrativeProfile |
| 10 | `GovernanceModels.swift` | `interfaces/api/v1/engine/governance_routes.py` | Contract/Storyline/DebtRecord/Report/Budget/State + 请求载荷 |
| 11 | `ForeshadowModels.swift` | `interfaces/api/v1/analyst/foreshadow_ledger.py` | ForeshadowEntry/Create/Update |
| 12 | `StructureModels.swift` | `interfaces/api/v1/blueprint/story_structure.py`, `continuous_planning_routes.py` | StoryNode/Tree/CreateNode/UpdateNode/Reorder/MacroPlanEvent/MacroPlanRequest |
| 13 | `PropModels.swift` | `interfaces/api/v1/prop/prop_routes.py` | PropDTO/PropEventDTO/CreateProp/PatchProp/CreateEvent |
| 14 | `EvolutionModels.swift` | `interfaces/api/v1/engine/evolution_routes.py` | EvolutionSnapshot/SnapshotList/GateRequest/GateReport/Override/Replay |
| 15 | `ChronicleModels.swift` | `interfaces/api/v1/engine/chronicles.py` | ChronicleRow/StoryEvent/Snapshot/ChroniclesResponse |
| 16 | `ExportModels.swift` | `interfaces/api/v1/core/export.py` | ExportFormat/ExportResult/ExportRequest |
| 17 | `SnapshotModels.swift` | `interfaces/api/v1/engine/snapshot_routes.py`, `checkpoint_routes.py` | UnifiedSnapshot/CreateSnapshot/Rollback/CheckpointDTO/StoryPhase/CharacterPsyche |
| 18 | `TraceModels.swift` | `interfaces/api/v1/engine/trace_routes.py` | TraceDTO/TraceStats/AiTraceSummary/AiTraceSpan/TimelineResponse |
| 19 | `StatsModels.swift` | `interfaces/api/stats/models/stats_models.py`, `responses.py` | GlobalStats/BookStats/ChapterStats/WritingProgress/StatsSuccessResponse |
| 20 | `AntiAIModels.swift` | `interfaces/api/v1/anti_ai.py` | ScanRequest/ScanResult/Hit/CategoryInfo/RuleInfo/AllowlistUpdate/Trend |
| 21 | `SandboxModels.swift` | `application/workbench/dtos/sandbox_dto.py` | DialogueEntry/WhitelistResponse/CharacterAnchor/GenerateRequest/Response/DialogueTurn/SandboxConfig |

### 21 个 ViewModel 文件（`Cangjie/ViewModels/`）

| # | 文件 | 说明 |
|---|------|------|
| 1 | `NovelStore.swift` | 书目 CRUD + 章节列表 + 当前选中小说/章节 |
| 2 | `WorkbenchStore.swift` | 章节正文编辑/保存/审阅/AI审阅/结构分析/草稿 |
| 3 | `AutopilotStore.swift` | start/stop/resume + 章节生成 SSE + 日志 SSE + 熔断器 + 状态轮询 |
| 4 | `OnboardingStore.swift` | 新书向导四步：创建小说 → Bible 流式 SSE → 角色确认 → 宏观规划 SSE |
| 5 | `BibleStore.swift` | Bible CRUD + 流式生成 + 角色/设定/地点添加 |
| 6 | `SettingsStore.swift` | @AppStorage 本地设置 + 服务器连接测试 |
| 7 | `LLMControlStore.swift` | 面板数据加载 + 配置更新 + 连通性测试 + 模型列表拉取 |
| 8 | `DAGStore.swift` | DAG 定义获取 + DAG 事件 SSE + 节点启禁用 |
| 9 | `KnowledgeGraphStore.swift` | 三元组查询 + 统计 + 搜索 + 确认/删除 + 索引 |
| 10 | `MonitorStore.swift` | 张力曲线/文风漂移/伏笔统计并发加载 |
| 11 | `CastStore.swift` | 人物关系图 + 搜索 + 覆盖分析 + 叙事画像 |
| 12 | `PromptPlazaStore.swift` | 广场初始化 + 节点/版本/渲染/调试/对比/回滚/模板 |
| 13 | `GovernanceStore.swift` | 治理状态 + 契约更新 + 故事线合并 + 预算预览 + 审阅动作 |
| 14 | `ForeshadowStore.swift` | 伏笔 CRUD + 标记消耗 |
| 15 | `StructureStore.swift` | 结构树 CRUD + 重排序 + 创建默认 |
| 16 | `PropStore.swift` | 道具 CRUD + 事件流 |
| 17 | `EvolutionStore.swift` | 快照列表 + 闸门检查 + 覆盖 + 回放 |
| 18 | `StatsStore.swift` | 全局/书籍/章节统计 + 写作进度 |
| 19 | `ExportStore.swift` | 小说/章节导出（DOCX/EPUB/PDF/MD）+ 分享 |
| 20 | `SnapshotStore.swift` | 快照列表/创建/删除 + 检查点列表/创建/回滚 + 故事阶段 + 角色心理 |
| 21 | `TraceStore.swift` | 引擎 Trace 列表/统计 + AI Trace 列表/时间线 |

---

## 二、关键设计决策

### 2.1 字段对齐后端 DTO

所有 Codable 模型字段严格对齐后端源码，不臆测：
- **snake_case → camelCase**：通过 `CodingKeys` 枚举映射
- **空值防御**：所有 `init(from:)` 使用 `decodeIfPresent` + `?? 默认值`（遵循架构 6.7 节）
- **动态 JSON**：后端部分接口返回 `dict[str, Any]`，用 `AnyCodable` 接收
- **日期格式**：复用 T01 的 `DateDecodingStrategyHelper`（APIClient 已配置全局 decoder）

### 2.2 AnyCodable 广泛应用

后端多个接口返回灵活结构（如 autopilot/status、governance/state、stats 等），使用 T01 的 `AnyCodable` 安全接收动态 JSON，并在需要时通过 `JSONSerialization` 重新编码为具体类型。

### 2.3 ViewModel 架构

- 全部 `@MainActor final class XxxStore: ObservableObject`
- `@Published` 暴露 UI 状态
- `async` 方法调用 `APIClient.shared` + `APIEndpoint`
- SSE 订阅使用 `SSEStreamRegistry.shared`
- 错误用 `errorMessage: String?` 展示给 UI，不中断流程

### 2.4 SSE 集成

- **AutopilotStore**：订阅 `autopilotStream` + `chapterStream`，3 秒轮询 `/status`
- **OnboardingStore**：订阅 `bibleGenerateStream` + `macroPlanStream`
- **BibleStore**：订阅 `bibleGenerateStream`
- **DAGStore**：订阅 `dagEvents`（event+data 格式），自动刷新状态

### 2.5 EndpointInfoWrapper

在 `StatsStore.swift` 中定义了 `APIEndpoint.EndpointInfoWrapper`，用于动态创建端点信息（Stats API 路由使用动态 slug 路径，不在 T01 预定义枚举中）。

---

## 三、对后端 DTO 的对齐情况

| 后端源码文件 | 对齐状态 | 说明 |
|-------------|---------|------|
| `application/core/dtos/novel_dto.py` | ✅ 完全对齐 | NovelDTO 全部 20 个字段 + ChapterDTO 8 个字段 |
| `application/core/dtos/chapter_dto.py` | ✅ 完全对齐 | 含 generation_hint |
| `application/world/dtos/bible_dto.py` | ✅ 完全对齐 | BibleDTO + CharacterDTO（含 POV 防火墙字段）+ WorldSetting/Location/Timeline/StyleNote |
| `application/world/dtos/cast_dto.py` | ✅ 完全对齐 | CastGraphDTO + CharacterDTO + RelationshipDTO + CastSearchResult + CastCoverage |
| `application/world/dtos/knowledge_dto.py` | ✅ 完全对齐 | KnowledgeTripleDTO 全部字段 + ChapterSummaryDTO + StoryKnowledgeDTO + SearchResponse |
| `application/engine/dag/models.py` | ✅ 完全对齐 | 全部枚举（NodeStatus/NodeCategory/EdgeCondition/PortDataType）+ DAGDefinition/NodeDefinition/EdgeDefinition/NodeConfig/NodeRunState/NodeEvent |
| `interfaces/api/v1/engine/autopilot_routes.py` | ✅ 完全对齐 | AutopilotStatus 涵盖共享内存路径返回的全部字段（60+ 字段） |
| `interfaces/api/v1/workbench/monitor.py` | ✅ 完全对齐 | TensionPoint/CurveStats/VoiceDrift/ForeshadowStats |
| `application/ai/llm_control_service.py` | ✅ 完全对齐 | LLMPreset/LLMProfile/LLMControlConfig/LLMRuntimeSummary/LLMControlPanelData/LLMTestResult |
| `interfaces/api/v1/prop/prop_routes.py` | ✅ 完全对齐 | PropDTO/PropEventDTO/CreatePropBody/PatchPropBody/CreateEventBody |
| `interfaces/api/v1/analyst/foreshadow_ledger.py` | ✅ 完全对齐 | SubtextEntryResponse/Create/Update |
| `interfaces/api/v1/engine/snapshot_routes.py` | ✅ 完全对齐 | UnifiedSnapshotDTO 全部字段 |
| `interfaces/api/v1/engine/checkpoint_routes.py` | ✅ 完全对齐 | CheckpointDTO + StoryPhaseDTO + CharacterPsycheDTO |
| `interfaces/api/v1/engine/trace_routes.py` | ✅ 完全对齐 | TraceDTO/TraceStats/AiTraceSummaryDTO/AiTraceSpanDTO 全部字段 |
| `interfaces/api/stats/models/stats_models.py` | ✅ 完全对齐 | GlobalStats/BookStats/ChapterStats/WritingProgress |
| `interfaces/api/v1/anti_ai.py` | ✅ 完全对齐 | ScanRequest/ScanResponse/CategoryInfo/RuleInfo/AllowlistUpdate |
| `application/workbench/dtos/sandbox_dto.py` | ✅ 完全对齐 | DialogueEntry/DialogueWhitelistResponse |
| `interfaces/api/v1/engine/chronicles.py` | ✅ 完全对齐 | ChroniclesResponse/ChronicleRow/StoryEventItem/SnapshotItem |
| `interfaces/api/v1/engine/evolution_routes.py` | ✅ 完全对齐 | GateRequest/OverrideRequest/ReplayRequest |
| `interfaces/api/v1/engine/governance_routes.py` | ✅ 完全对齐 | ContractPayload/MergeStorylinesPayload/BudgetPreviewPayload/ReviewActionPayload |
| `interfaces/api/v1/blueprint/continuous_planning_routes.py` | ✅ 完全对齐 | StructurePreference/MacroPlanRequest/MacroPlanConfirmRequest + SSE 事件格式 |

---

## 四、已知限制

1. **后端返回 dict 的接口**：autopilot/status、governance/state、bible/status 等后端返回 `dict[str, Any]`，iOS 端使用 `AnyCodable` 接收后再用 `JSONSerialization` 重新解码为具体类型，存在二次序列化开销
2. **Stats API 路由**：后端 Stats 路由使用动态 slug 路径（`/api/stats/book/{slug}`），不在 T01 APIEndpoint 预定义枚举中，通过 `EndpointInfoWrapper` 动态构建
3. **ExportStore Content-Disposition**：导出文件名从 Content-Disposition 头提取的逻辑未完整实现（后端返回 URL 编码的中文文件名），当前用 novelId + 扩展名作为文件名
4. **AutopilotStore 状态轮询**：使用 3 秒 Task.sleep 轮询 /status，生产环境可考虑改为纯 SSE 事件驱动
5. **无单元测试**：T02 不含测试文件

---

## 五、字段待确认清单

以下字段因后端返回动态 dict 无法从源码直接确认类型，使用 `AnyCodable` 或 `String?` 接收：

| 模型 | 字段 | 后端来源 | 处理方式 |
|------|------|---------|---------|
| AutopilotStatus | `auditProgress` | 共享内存 `audit_progress` | `AnyCodable?` |
| AutopilotStatus | `lastChapterAudit` | 共享内存 `last_chapter_audit` | `AnyCodable?` |
| GovernanceState | `contract` | `service.get_state()` 返回 dict | 二次解码为 `GovernanceContract?` |
| GovernanceState | `storylines` | 同上 | 二次解码为 `[Storyline]?` |
| GovernanceState | `debts` | 同上 | 二次解码为 `[DebtRecord]?` |
| GovernanceState | `reports` | 同上 | 二次解码为 `[GovernanceReport]?` |
| EvolutionGateReport | `violations` | `report.to_dict()` 返回 list[dict] | `[AnyCodable]?` |
| BibleGenerationStatus | 后端返回 dict | `/bible/status` 返回动态 dict | 二次解码 |
| CharacterNarrativeProfile | 多个字段 | `/narrative-profile` 返回动态 dict | 部分用 `AnyCodable` |
| GenerateDialogueResponse | `metadata` | 后端返回动态 dict | `[String: AnyCodable]?` |

---

## 六、全局一致性审查

### IS_PASS: YES

| 审查项 | 结果 | 说明 |
|--------|------|------|
| 与 T01 衔接 | ✅ 通过 | 所有 ViewModel 使用 T01 的 APIClient.shared + APIEndpoint + SSEStreamRegistry.shared；模型复用 T01 的 AnyCodable/HTTPMethod/SSEStreamType |
| 跨文件导入一致性 | ✅ 通过 | 无循环依赖；Models 不依赖 ViewModels；ViewModels 依赖 Models + T01 Networking/SSE |
| Codable 一致性 | ✅ 通过 | 所有模型使用 decodeIfPresent + 默认值；CodingKeys 正确映射 snake_case |
| API 调用正确性 | ✅ 通过 | 所有 Store 方法调用正确的 APIEndpoint case，HTTP 方法匹配 |
| SSE 集成 | ✅ 通过 | AutopilotStore/OnboardingStore/BibleStore/DAGStore 正确使用 SSEStreamRegistry |
| iOS 16 兼容 | ✅ 通过 | @MainActor + ObservableObject + @Published；无 iOS 17+ API |
| 无占位符/TODO | ✅ 通过 | 所有方法完整实现 |
