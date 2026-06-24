# 仓颉 iOS 阶段1 — 接口契约表 + 任务分解

> 架构师：高见远  
> 基于：PlotPilot v4.6.0 原版 Vue 前端源码 + 仓颉 iOS 现有实现  
> 遵守主理人6项决策（Q1-Q6）

---

## 1. 实现方案概述

| # | 模块 | 实现思路 |
|---|------|---------|
| M1 | 向导Bible生成SSE事件处理重写 | 重写 `OnboardingStore.handleBibleSSEEvent`，按原版 `bible.ts:consumeBibleGenerateStream` 的5类SSE事件（phase/data/done/approval_required/error）完整解析；新增 `BibleSSEEventModel` 结构化模型替代裸字典解析；新增分阶段状态字段（styleText/worldbuildingData/streamingCharacters/streamingLocations/phaseMessage） |
| M2 | 向导stage分步调用重写 | 重写 `OnboardingStore.startBibleGeneration`，改为接受 `stage` 参数（worldbuilding/characters/locations），分别调 `SSEStreamRegistry.startBibleGenerateStream(stage:)`；向导改为3步（世界观→人物→地点），每步完成后自动调 `loadBibleData()` 刷新 |
| M3 | 向导角色步骤SSE流式生成重写 | 重写 `CharacterSetupStep.swift`，SSE `onCharacter` 事件到达时调 `mapGeneratedCharacterToEditable` 映射为可编辑角色并追加到流式列表；`onCharacterChunk` 更新进度提示；`onDone` 后加载完整Bible并切换到可编辑模式 |
| M4 | Autopilot chapter-stream事件解析重写 | 重写 `ChapterStreamEvent` 模型，按原版 `config.ts:subscribeChapterStream` 的9类事件（connected/outline_planning/beats_planned/chapter_start/chapter_chunk/chapter_content/autopilot_stopped/paused_for_review/heartbeat）完整解析；重写 `AutopilotStore.handleChapterEvent` 用 metadata 字段分发回调 |
| M5 | workbench单章生成SSE新建 | 新增 `WorkbenchStore.consumeGenerateChapterStream`，按原版 `workflow.ts:consumeGenerateChapterStream` 的7类事件（phase/llm_chunk/beats_generated/approval_required/chunk/done/error）解析；新增 `GenerateChapterStreamEvent` 模型；`ChapterToolbar` 加生成按钮，`ChapterContentPanel` 加phase进度+正文流式+done后一致性报告 |

---

## 2. 接口契约表

### 2.1 模块M1+M2+M3：向导Bible生成SSE

#### 2.1.1 HTTP接口契约

| 功能 | HTTP方法 | 端点 | 请求体 | 响应/SSE事件 | 数据模型 | 对齐原版文件:行号 |
|------|---------|------|--------|-------------|---------|-----------------|
| Bible流式生成（世界观） | POST | `/api/v1/bible/novels/{novelId}/generate-stream?stage=worldbuilding` | `{}`（空JSON） | SSE事件流 | BibleStreamEvent | bible.ts:339-363 |
| Bible流式生成（角色） | POST | `/api/v1/bible/novels/{novelId}/generate-stream?stage=characters` | `{}` | SSE事件流 | BibleStreamEvent | bible.ts:339-363, NovelSetupGuide.vue:1579 |
| Bible流式生成（地点） | POST | `/api/v1/bible/novels/{novelId}/generate-stream?stage=locations` | `{}` | SSE事件流 | BibleStreamEvent | bible.ts:339-363, NovelSetupGuide.vue:1638 |
| 加载Bible数据 | GET | `/api/v1/bible/novels/{novelId}/bible` | — | BibleDTO | BibleDTO | bible.ts:194-195, NovelSetupGuide.vue:1681 |
| 更新Bible（保存编辑） | PUT | `/api/v1/bible/novels/{novelId}/bible` | `{characters, world_settings, locations, timeline_notes, style_notes}` | BibleDTO | BibleDTO | bible.ts:225-234, NovelSetupGuide.vue:1912-1931 |

> **Q3决策**：`loadBibleData` 只调 `bibleApi.getBible`，用返回的 `world_settings` 字段，不调 `worldbuildingApi.getWorldbuilding`。原版 NovelSetupGuide.vue:1686 调了 worldbuildingApi，iOS阶段1不移植该调用。

#### 2.1.2 SSE事件契约 — Bible生成流

| 事件名（event行） | data载荷字段 | 回调签名（Swift） | 对齐原版文件:行号 |
|-------------------|-------------|-------------------|-----------------|
| `phase` | `phase: String`, `message: String` | `onPhase(phase: String, message: String)` | bible.ts:293-294, 433-434 |
| `data` (type=style) | `type: "style"`, `content: String` | `onStyle(content: String)` | bible.ts:296-298, 437-438 |
| `data` (type=style_chunk) | `type: "style_chunk"`, `chunk: String` | `onStyleChunk(chunk: String)` | bible.ts:439-440 |
| `data` (type=worldbuilding_chunk) | `type: "worldbuilding_chunk"`, `chunk: String` | `onWorldbuildingChunk(chunk: String)` | bible.ts:441-442 |
| `data` (type=worldbuilding_field) | `type: "worldbuilding_field"`, `dimension: String`, `field: String`, `value: String` | `onWorldbuildingField(dimension: String, field: String, value: String)` | bible.ts:443-448 |
| `data` (type=worldbuilding_dimension) | `type: "worldbuilding_dimension"`, `dimension: String`, `label: String`, `content: {String: String}` | `onWorldbuildingDimension(data: WorldbuildingDimensionData)` | bible.ts:449-454 |
| `data` (type=character) | `type: "character"`, `content: {String: Any}`, `index: Int` | `onCharacter(char: [String: Any], index: Int)` | bible.ts:455-456 |
| `data` (type=character_chunk) | `type: "character_chunk"`, `chunk: String` | `onCharacterChunk(chunk: String)` | bible.ts:457-458 |
| `data` (type=location) | `type: "location"`, `content: {String: Any}`, `index: Int` | `onLocation(loc: [String: Any], index: Int)` | bible.ts:459-460 |
| `data` (type=location_chunk) | `type: "location_chunk"`, `chunk: String` | `onLocationChunk(chunk: String)` | bible.ts:461-462 |
| `data` (type=approval_required) | `type: "approval_required"`, `session_id: String`, `status?: String`, `next_action?: String`, `stage?: String` | `onApprovalRequired(sessionId: String, status: String?, nextAction: String?, stage: String?)` | bible.ts:315-321, 463-474 |
| `done` | `message: String`, `novel_id: String`, `invocation_session_id?: String` | `onDone(novelId: String)` | bible.ts:308-313, 475-477 |
| `error` | `message: String` | `onError(message: String)` | bible.ts:323-326, 478-481 |

> **SSE事件解析约定**：原版 `bible.ts:consumeBibleGenerateStream` 同时解析 `event:` 行和 `data:` JSON 中的 `type` 字段。Bible生成流的 `event:` 行值为 `phase`/`data`/`done`/`error`，而具体子类型在 `data` JSON 的 `type` 字段中。iOS 的 `SSEClient` 已支持 `event:` 行解析（`SSEEvent.event` 属性）和 `data:` JSON 解析（`SSEEvent.decodeAsDictionary()`），无需改动 SSEClient。

> **Q1/Q2决策**：`approval_required` 事件 — 阶段1正确解析事件+留 `onApprovalRequired` 回调入口，UI显示"需要AI审批（审批面板后续实现）"提示，不阻塞流程。完整审批UI留阶段3。

#### 2.1.3 数据模型契约 — Bible SSE

| 模型名 | 字段 | 类型 | 对齐原版文件:行号 |
|--------|------|------|-----------------|
| `BibleStreamPhaseEvent` | `phase: String`, `message: String` | struct | bible.ts:290-294 |
| `BibleStreamDataEvent` | `type: String`（style/style_chunk/worldbuilding_chunk/worldbuilding_field/worldbuilding_dimension/character/character_chunk/location/location_chunk/approval_required）, `content: AnyCodable`, `dimension?: String`, `label?: String`, `index?: Int`, `chunk?: String`, `field?: String`, `value?: String`, `sessionId?: String`, `status?: String`, `nextAction?: String`, `stage?: String` | struct | bible.ts:296-306 |
| `BibleStreamDoneEvent` | `message: String`, `novelId: String`, `invocationSessionId?: String` | struct | bible.ts:308-313 |
| `BibleStreamErrorEvent` | `message: String` | struct | bible.ts:323-326 |
| `WorldbuildingDimensionData` | `dimension: String`, `label: String`, `content: [String: String]` | struct | bible.ts:283-287 |
| `GeneratedCharacterPayload` | `id?: String`, `name?: String`, `description?: String`, `role?: String`, `gender?: String`, `age?: String`, `appearance?: String`, `personality?: String`, `background?: String`, `coreMotivation?: String`, `innerLack?: String`, `mentalState?: String`, `mentalStateReason?: String`, `verbalTic?: String`, `idleBehavior?: String`, `relationships?: [AnyCodable]`, `publicProfile?: String`, `hiddenProfile?: String`, `revealChapter?: Int`, `coreBelief?: String`, `moralTaboos?: [String]`, `voiceProfile?: AnyCodable`, `activeWounds?: [AnyCodable]` | struct | characterSetupModel.ts:51-64, bible.ts:12-40 |

### 2.2 模块M4：Autopilot chapter-stream事件解析

#### 2.2.1 HTTP接口契约

| 功能 | HTTP方法 | 端点 | 请求体 | 响应/SSE事件 | 数据模型 | 对齐原版文件:行号 |
|------|---------|------|--------|-------------|---------|-----------------|
| 章节生成流 | GET | `/api/v1/autopilot/{novelId}/chapter-stream` | — | SSE事件流（data-only格式） | ChapterStreamEvent | config.ts:328-355, endpoints.ts:53 |

#### 2.2.2 SSE事件契约 — chapter-stream

| 事件类型（data.type） | data载荷字段 | 回调签名（Swift） | 对齐原版文件:行号 |
|----------------------|-------------|-------------------|-----------------|
| `connected` | `type: "connected"`, `message: String`, `timestamp: String` | `onConnected()` | config.ts:304-306, 349, 376 |
| `outline_planning` | `type: "outline_planning"`, `message: String`, `timestamp: String`, `metadata.chapter_number: Int` | `onOutlinePlanning(chapterNumber: Int, message: String)` | config.ts:305, 383-384 |
| `beats_planned` | `type: "beats_planned"`, `message: String`, `timestamp: String`, `metadata.chapter_number: Int`, `metadata.beats: [{String: Any}]`, `metadata.outline_plan_mode: String` | `onBeatsPlanned(chapterNumber: Int, beats: [AnyCodable], outlinePlanMode: String)` | config.ts:306, 385-391 |
| `chapter_start` | `type: "chapter_start"`, `message: String`, `timestamp: String`, `metadata.chapter_number: Int` | `onChapterStart(chapterNumber: Int)` | config.ts:307, 392-393 |
| `chapter_chunk` | `type: "chapter_chunk"`, `message: String`, `timestamp: String`, `metadata.chunk?: String`, `metadata.content?: String`, `metadata.beat_index: Int` | `onChapterChunk(chunk: String?, content: String?, beatIndex: Int, isSnapshot: Bool)` | config.ts:308, 394-408 |
| `chapter_content` | `type: "chapter_content"`, `message: String`, `timestamp: String`, `metadata.chapter_number: Int`, `metadata.content: String`, `metadata.word_count: Int`, `metadata.beat_index: Int` | `onChapterContent(chapterNumber: Int, content: String, wordCount: Int, beatIndex: Int)` | config.ts:309, 409-415 |
| `autopilot_stopped` | `type: "autopilot_stopped"`, `message: String`, `timestamp: String` | `onAutopilotStopped(status: String)` | config.ts:311, 416-418 |
| `paused_for_review` | `type: "paused_for_review"`, `message: String`, `timestamp: String` | `onPausedForReview()` | config.ts:312, 419-421 |
| `heartbeat` | `type: "heartbeat"`, `message: String`, `timestamp: String` | 忽略（不回调） | config.ts:313 |

> **Q5决策**：`connected` 事件需实现 `onConnected` 回调，`heartbeat` 忽略。

> **SSE事件解析约定**：chapter-stream 是 data-only 格式（无 `event:` 行），事件类型在 JSON `data` 的 `type` 字段中。原版 `config.ts:subscribeChapterStream` 只解析 `data:` 行，不做 `event:` 行解析。iOS 的 `SSEClient` 已支持 data-only 格式（`SSEEvent.event` 为 nil，`SSEEvent.typeFromData` 从 JSON 取 `type` 字段）。

#### 2.2.3 数据模型契约 — chapter-stream

| 模型名 | 字段 | 类型 | 对齐原版文件:行号 |
|--------|------|------|-----------------|
| `ChapterStreamEvent`（重写） | `type: String`, `message: String`, `timestamp: String`, `metadata: ChapterStreamMetadata?` | struct | config.ts:303-326 |
| `ChapterStreamMetadata` | `chapterNumber?: Int`, `chunk?: String`, `beatIndex?: Int`, `content?: String`, `wordCount?: Int`, `beats?: [AnyCodable]`, `outlinePlanMode?: String`, `totalBeats?: Int` | struct | config.ts:316-325 |

### 2.3 模块M5：workbench单章生成SSE

#### 2.3.1 HTTP接口契约

| 功能 | HTTP方法 | 端点 | 请求体 | 响应/SSE事件 | 数据模型 | 对齐原版文件:行号 |
|------|---------|------|--------|-------------|---------|-----------------|
| 单章流式生成 | POST | `/api/v1/novels/{novelId}/generate-chapter-stream` | `GenerateChapterWithContextPayload` | SSE事件流 | GenerateChapterStreamEvent | workflow.ts:375-391 |

#### 2.3.2 SSE事件契约 — generate-chapter-stream

| 事件类型（data.type） | data载荷字段 | 回调签名（Swift） | 对齐原版文件:行号 |
|----------------------|-------------|-------------------|-----------------|
| `phase` | `type: "phase"`, `phase: String`（planning/context/script/prose/outline_planning/llm/post） | `onPhase(phase: String)` | workflow.ts:354, 418-425 |
| `llm_chunk` | `type: "llm_chunk"`, `stage: String`, `text: String` | `onLLMChunk(stage: String, text: String)` | workflow.ts:355, 431-436 |
| `beats_generated` | `type: "beats_generated"`, `beats: [StreamGeneratedBeat]` | `onBeatsGenerated(beats: [StreamGeneratedBeat])` | workflow.ts:356, 426-430 |
| `approval_required` | `type: "approval_required"`, `session_id: String`, `status?: String`, `next_action?: String` | `onApprovalRequired(sessionId: String, status: String?, nextAction: String?)` | workflow.ts:357, 437-446 |
| `chunk` | `type: "chunk"`, `text: String`, `stats: ChunkStats` | `onChunk(text: String, stats: ChunkStats)` | workflow.ts:358, 447-452 |
| `done` | `type: "done"`, `content: String`, `consistency_report: ConsistencyReportDTO`, `token_count: Int`, `output_tokens: Int`, `total_tokens: Int`, `chars: Int`, `style_warnings?: [StyleWarning]`, `ghost_annotations?: [AnyCodable]`, `beats?: [StreamGeneratedBeat]` | `onDone(result: GenerateChapterWorkflowResponse)` | workflow.ts:359, 453-483 |
| `error` | `type: "error"`, `message: String` | `onError(message: String)` | workflow.ts:360, 484-490 |

> **SSE事件解析约定**：generate-chapter-stream 也是 data-only 格式（无 `event:` 行），事件类型在 JSON `data` 的 `type` 字段中。原版 `workflow.ts:consumeGenerateChapterStream` 只解析 `data:` 行。

#### 2.3.3 数据模型契约 — generate-chapter-stream

| 模型名 | 字段 | 类型 | 对齐原版文件:行号 |
|--------|------|------|-----------------|
| `GenerateChapterWithContextPayload` | `chapterNumber: Int`, `outline: String`, `sceneDirectorResult?: AnyCodable`, `invocationPolicy?: String`, `regenerationGuidance?: String`, `profileId?: String`, `scriptPromptTemplate?: String`, `prosePromptTemplate?: String`, `promptVariables?: [String: String]` | struct | workflow.ts:159-174 |
| `ChunkStats` | `chars: Int`, `chunks: Int`, `estimatedTokens: Int` | struct | workflow.ts:273-277 |
| `StreamGeneratedBeat` | `description: String`, `targetWords: Int`, `focus: String`, `locationId?: String`, `function?: String`, `pov?: String`, `castRefs?: [String]`, `locationRefs?: [String]`, `propRefs?: [String]`, `knowledgeRefs?: [String]`, `visibleAction?: String`, `conflict?: String`, `delta?: String`, `handoffToNext?: String`, `mustInclude?: [String]`, `mustNotInclude?: [String]`, `activeAction?: String`, `emotionGap?: String`, `forbiddenDrift?: String` | struct | workflow.ts:280-300 |
| `ConsistencyIssueDTO` | `type: String`, `severity: String`, `description: String`, `location: Int` | struct | workflow.ts:242-247 |
| `ConsistencyReportDTO` | `issues: [ConsistencyIssueDTO]`, `warnings: [ConsistencyIssueDTO]`, `suggestions: [String]` | struct | workflow.ts:249-253 |
| `StyleWarning` | `pattern: String`, `text: String`, `start: Int`, `end: Int`, `severity: String` | struct | workflow.ts:255-261 |
| `GenerateChapterWorkflowResponse` | `content: String`, `consistencyReport: ConsistencyReportDTO`, `tokenCount: Int`, `styleWarnings?: [StyleWarning]`, `ghostAnnotations?: [AnyCodable]`, `beats?: [StreamGeneratedBeat]` | struct | workflow.ts:263-271 |

---

## 3. 文件清单及相对路径

### 3.1 需修改的文件

| # | 文件路径（相对Cangjie/） | 改动类型 | 改动内容摘要 | 对齐原版文件 |
|---|------------------------|---------|-------------|-------------|
| 1 | `Models/BibleModels.swift` | 修改 | 新增 `BibleStreamEvent` 解析模型（phase/data/done/approval_required/error）、`WorldbuildingDimensionData`、`GeneratedCharacterPayload`；新增 `mapGeneratedCharacterToEditable` 函数 | bible.ts:283-334, characterSetupModel.ts:147-174 |
| 2 | `ViewModels/OnboardingStore.swift` | 修改 | 重写 `handleBibleSSEEvent` 按5类事件完整解析；重写 `startBibleGeneration(stage:)` 分3步调用；新增 `styleText`/`worldbuildingData`/`streamingCharacters`/`streamingLocations`/`phaseMessage`/`activeDimension`/`completedDimensions` 状态字段；新增 `loadBibleData()` 只调 `bibleApi.getBible`（Q3）；新增 `approvalMessage` 字段（Q1/Q2） | NovelSetupGuide.vue:1480-1619, bible.ts:339-500 |
| 3 | `SSE/SSEStreamRegistry.swift` | 修改 | 确认 `startBibleGenerateStream(stage:)` 已正确传 stage 参数（当前已实现，确认无需改动）；新增 `startGenerateChapterStream` 便捷方法用于M5 | NovelSetupGuide.vue:1496, workflow.ts:392 |
| 4 | `SSE/SSEEvent.swift` | 修改 | 新增 `bibleEventType` 计算属性（从 event 行或 data.type 获取 Bible 事件类型）；新增 `generateChapterEventType` 计算属性 | — |
| 5 | `Models/AutopilotModels.swift` | 修改 | 重写 `ChapterStreamEvent` 模型，新增 `message`/`timestamp`/`metadata` 字段；新增 `ChapterStreamMetadata` 模型 | config.ts:303-326 |
| 6 | `ViewModels/AutopilotStore.swift` | 修改 | 重写 `handleChapterEvent` 按9类事件分发回调；新增 `onConnected`/`onOutlinePlanning`/`onBeatsPlanned`/`onChapterStart`/`onChapterChunk`/`onChapterContent`/`onAutopilotStopped`/`onPausedForReview` 回调入口 | config.ts:382-423 |
| 7 | `ViewModels/WorkbenchStore.swift` | 修改 | 新增 `consumeGenerateChapterStream` 方法；新增 `generateChapterPhase`/`generateChapterContent`/`generateChapterConsistencyReport`/`isGeneratingChapter` 状态字段 | workflow.ts:375-511 |
| 8 | `Views/Onboarding/BibleStreamingStep.swift` | 修改 | 适配新状态字段，展示 phaseMessage/文风公约实时预览/世界观维度流式卡片/角色流式卡片 | NovelSetupGuide.vue:26-176 |
| 9 | `Views/Onboarding/CharacterSetupStep.swift` | 修改 | 重写为SSE流式角色生成步骤：生成中显示流式角色卡片，生成完成后显示可编辑列表 | NovelSetupGuide.vue:178-425 |
| 10 | `Views/Onboarding/OnboardingWizardView.swift` | 修改 | 向导步骤改为3步（世界观→人物→地点），去掉宏观规划步骤（Q4）；底部导航适配 | NovelSetupGuide.vue:12-18 |
| 11 | `Views/Workbench/ChapterToolbar.swift` | 修改 | 新增"生成"按钮，触发 `WorkbenchStore.consumeGenerateChapterStream` | workflow.ts:375 |
| 12 | `Views/Workbench/ChapterContentPanel.swift` | 修改 | 新增生成中phase进度条+正文流式渲染区+done后一致性报告展示 | workflow.ts:375-511 |

### 3.2 需新建的文件

| # | 文件路径（相对Cangjie/） | 改动类型 | 改动内容摘要 | 对齐原版文件 |
|---|------------------------|---------|-------------|-------------|
| 1 | `Models/GenerateChapterModels.swift` | 新建 | `GenerateChapterWithContextPayload`、`GenerateChapterStreamEvent`、`ChunkStats`、`StreamGeneratedBeat`、`ConsistencyIssueDTO`、`ConsistencyReportDTO`、`StyleWarning`、`GenerateChapterWorkflowResponse` | workflow.ts:159-300 |
| 2 | `Views/Onboarding/LocationSetupStep.swift` | 新建 | 向导第3步：地点SSE流式生成（对标角色步骤，但展示地点卡片） | NovelSetupGuide.vue:427-520 |
| 3 | `Views/Workbench/ChapterGenerationPanel.swift` | 新建 | 单章生成面板：phase进度+正文流式+一致性报告（从ChapterContentPanel拆出或内嵌） | workflow.ts:375-511 |

---

## 4. 任务列表（有序，含依赖关系）

| # | 任务 | 文件 | 依赖 | 对齐原版 |
|---|------|------|------|----------|
| T01 | 新增Bible SSE事件模型 + GenerateChapter模型 | `Models/BibleModels.swift`（改）, `Models/GenerateChapterModels.swift`（新）, `Models/AutopilotModels.swift`（改） | 无 | bible.ts:283-334, workflow.ts:159-300, config.ts:303-326, characterSetupModel.ts:147-174 |
| T02 | 重写SSE事件解析层 + SSEStreamRegistry扩展 | `SSE/SSEEvent.swift`（改）, `SSE/SSEStreamRegistry.swift`（改） | T01 | bible.ts:400-413, config.ts:425-441, workflow.ts:362-369 |
| T03 | 重写OnboardingStore Bible生成SSE处理 + 分stage调用 | `ViewModels/OnboardingStore.swift`（改） | T01, T02 | NovelSetupGuide.vue:1480-1619, bible.ts:339-500 |
| T04 | 重写AutopilotStore chapter-stream事件解析 | `ViewModels/AutopilotStore.swift`（改） | T01, T02 | config.ts:328-469 |
| T05 | 新增WorkbenchStore单章生成SSE + UI层（生成按钮+流式渲染+一致性报告） | `ViewModels/WorkbenchStore.swift`（改）, `Views/Workbench/ChapterToolbar.swift`（改）, `Views/Workbench/ChapterContentPanel.swift`（改）, `Views/Workbench/ChapterGenerationPanel.swift`（新） | T01, T02 | workflow.ts:375-511 |
| T06 | 重写向导UI层（世界观步骤+角色步骤+地点步骤+向导结构） | `Views/Onboarding/BibleStreamingStep.swift`（改）, `Views/Onboarding/CharacterSetupStep.swift`（改）, `Views/Onboarding/LocationSetupStep.swift`（新）, `Views/Onboarding/OnboardingWizardView.swift`（改） | T01, T03 | NovelSetupGuide.vue:1-727 |

---

## 5. 共享知识（跨文件约定）

### 5.1 SSE事件解析统一约定

- **Bible生成流**：SSE帧有 `event:` 行（值为 phase/data/done/error），子类型在 `data` JSON 的 `type` 字段中。解析时先取 `event` 行值确定大类，再从 `data.type` 确定子类型。
- **chapter-stream**：data-only 格式（无 `event:` 行），事件类型在 `data` JSON 的 `type` 字段中。用 `SSEEvent.typeFromData` 获取。
- **generate-chapter-stream**：data-only 格式，同 chapter-stream。事件类型在 `data` JSON 的 `type` 字段中。
- **JSON解析**：所有 SSE 事件 data 用 `SSEEvent.decodeAsDictionary()` 解析为 `[String: Any]` 字典，再按字段取值。不用 Codable 直接解码（因为字段可能缺失/类型不一致），改为手动字典取值 + `decodeIfPresent` 模式。
- **日期解码**：统一用 `CangjieDecoder.shared`（配置微秒日期格式）。

### 5.2 stage参数传递约定

- `OnboardingStore.startBibleGeneration(stage:)` 接受 `"worldbuilding"` / `"characters"` / `"locations"` 三个值。
- 传给 `SSEStreamRegistry.startBibleGenerateStream(novelId:stage:onEvent:onError:)`，该方法构建 URL 时附加 `?stage={stage}` 查询参数。
- 当前 `SSEStreamRegistry.startBibleGenerateStream` 已正确实现 stage 参数传递（见 SSEStreamRegistry.swift:428-485），**无需改动该方法本身**，只需确保 `OnboardingStore` 正确传参。

### 5.3 回调闭包签名约定

- SSE 事件回调统一为 `(SSEEvent) -> Void`，在 Store 层的 `handle*Event` 方法中解析具体事件类型并分发。
- 对于需要结构化数据的场景（如 `onCharacter`、`onWorldbuildingDimension`），在 Store 层解析字典后构造对应模型再更新 `@Published` 状态。
- 所有回调在 `@MainActor` 上执行（通过 `Task { @MainActor in ... }` 调度）。

### 5.4 iOS 16兼容

- 不使用 `@Observable` / `@Bindable`（iOS 17+），统一用 `@Published` + `@StateObject` / `@EnvironmentObject`。
- 不使用 `NavigationSplitView`（iOS 16+ 但行为不一致），用 `NavigationStack` + `TabView`。
- 不使用 `ScrollView` 的 `contentMargins` 修饰符（iOS 17+）。

### 5.5 向导步骤约定（Q4决策）

- 阶段1只做向导前3步：worldbuilding / characters / locations。
- 第4步"剧情总纲"留阶段3，当前 `OnboardingStep.macroPlanning` 和相关代码保留但不走。
- 向导 `OnboardingStep` 枚举调整为：`bibleGeneration`(世界观) → `characterSetup`(人物) → `locationSetup`(地点) → `completed`。去掉 `macroPlanning` 步骤的UI入口。

### 5.6 approval_required事件处理约定（Q1/Q2决策）

- 阶段1：正确解析事件，调用 `onApprovalRequired` 回调，UI显示"需要AI审批（审批面板后续实现）"提示文本。
- 不阻塞流程：审批事件到达后，SSE流会继续推送 done 事件，正常完成生成。
- 完整审批UI（AI审阅面板）留阶段3实现。

### 5.7 workbench单章生成约定（Q6决策）

- 必须同时做 Store 层 + UI 层。
- 简化版UI：触发按钮（ChapterToolbar加"生成"按钮）→ phase进度（显示当前阶段 planning/context/script/prose等）→ 正文流式（chunk事件实时追加到编辑器）→ done后一致性报告（显示 issues/warnings/suggestions）。

---

## 6. 待明确事项

### 6.1 worldbuildingData 的5维度结构

原版 NovelSetupGuide.vue 使用 `WorldbuildingDraftShape` 管理5个维度（core_rules / geography / society / culture / daily_life），每个维度是 `{field: value}` 字典。iOS 阶段1是否需要完整实现5维度结构化展示？

**假设**：阶段1先用简化的字典结构 `[String: [String: String]]`（维度→字段→值）存储 worldbuildingData，UI先做基础展示（phase消息+文风公约+维度卡片列表），不做5维度骨架屏逐字段流式高亮。完整5维度UI留后续迭代。

### 6.2 generate-chapter-stream 的请求体

原版 `GenerateChapterWithContextPayload` 有很多可选字段（sceneDirectorResult / invocationPolicy / regenerationGuidance / profileId / scriptPromptTemplate / prosePromptTemplate / promptVariables）。iOS 阶段1 workbench单章生成时，这些字段如何填充？

**假设**：阶段1只传必填字段 `chapterNumber` 和 `outline`（从当前章节的 generationHint 或 chapter.outline 获取），其余可选字段全部不传（后端用默认值）。

### 6.3 ChapterDTO 是否有 outline 字段

需确认 `ChapterDTO` 模型是否有 `outline` 字段用于传给 `generate-chapter-stream`。如果没有，可能需要先调章节列表API获取大纲，或用 `generationHint` 代替。

**假设**：用 `chapter.generationHint` 作为 outline 传入。如果后端需要正式的 chapter outline 字段，需后续补充。

### 6.4 向导"确认修改并继续"的保存逻辑

原版 NovelSetupGuide.vue 在每步"下一步"时先调 `saveWorldbuildingEdits` / `saveCharactersEdits` / `saveLocationsEdits` 保存到后端。iOS 阶段1是否需要实现保存逻辑？

**假设**：阶段1实现保存逻辑，用 `bibleApi.updateBible` (PUT /bible/novels/{id}/bible) 统一保存。世界观步骤保存 style + world_settings；人物步骤保存 characters；地点步骤保存 locations。不调 `worldbuildingApi.updateWorldbuilding`（该API在iOS端未实现，Q3决策不引入）。

---

## 附录：原版关键代码行号索引

| 功能 | 原版文件 | 关键行号 |
|------|---------|---------|
| consumeBibleGenerateStream 函数签名 | bible.ts | 339-361 |
| Bible SSE phase 事件解析 | bible.ts | 433-434 |
| Bible SSE data 事件子类型分发 | bible.ts | 435-474 |
| Bible SSE done 事件 | bible.ts | 475-477 |
| Bible SSE error 事件 | bible.ts | 478-481 |
| Bible SSE approval_required | bible.ts | 463-474 |
| subscribeChapterStream 函数签名 | config.ts | 328-355 |
| chapter-stream connected 事件 | config.ts | 376 |
| chapter-stream dispatchSseEvent | config.ts | 382-423 |
| chapter-stream flushBlocks | config.ts | 425-441 |
| consumeGenerateChapterStream 函数签名 | workflow.ts | 375-391 |
| generate-chapter phase 事件 | workflow.ts | 418-425 |
| generate-chapter beats_generated | workflow.ts | 426-430 |
| generate-chapter llm_chunk | workflow.ts | 431-436 |
| generate-chapter approval_required | workflow.ts | 437-446 |
| generate-chapter chunk | workflow.ts | 447-452 |
| generate-chapter done | workflow.ts | 453-483 |
| generate-chapter error | workflow.ts | 484-490 |
| mapGeneratedCharacterToEditable | characterSetupModel.ts | 147-174 |
| normalizeCharacterRoleAndDescription | characterSetupModel.ts | 116-134 |
| startBibleGenerationSSE (stage=worldbuilding) | NovelSetupGuide.vue | 1480-1559 |
| startCharactersGenerationSSE (stage=characters) | NovelSetupGuide.vue | 1567-1619 |
| startLocationsGenerationSSE (stage=locations) | NovelSetupGuide.vue | 1627-1676 |
| loadBibleData | NovelSetupGuide.vue | 1679-1708 |
| handleNext (步骤切换+保存) | NovelSetupGuide.vue | 2076-2114 |
