# 阶段4 批次1 事实表（4.1 voiceApi + 4.5 浮动按钮 + 4.6 知识图谱写操作）

> 工程师：寇豆码（Kou）
> 日期：2025-07-01
> 原版Vue根目录：`D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`
> iOS代码根目录：`D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/Cangjie/`

---

## 4.1 文风 voiceApi 对接

### 原版事实表

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| voiceApi 定义 | `api/voice.ts:26-40` | `voiceApi` 导出对象，含2个方法 | N/A（纯API层） | `VoiceSamplePayload`、`VoiceSampleResponse`、`VoiceFingerprintDTO` |
| createSample — 提交文风样本对 | `api/voice.ts:28-32` | `POST /novels/${novelId}/voice/samples`，body=`VoiceSamplePayload` | N/A | `VoiceSamplePayload{ai_original, author_refined, chapter_number, scene_type?}` → `VoiceSampleResponse{sample_id}` |
| getFingerprint — 查看文风指纹统计 | `api/voice.ts:35-39` | `GET /novels/${novelId}/voice/fingerprint`，query=`pov_character_id?` | N/A | `VoiceFingerprintDTO{adjective_density, avg_sentence_length, sentence_count, sample_count, last_updated}` |
| **voiceApi 调用方** | **全前端src搜索** | **`voiceApi.` 在整个 Vue 前端中未被任何组件调用** | **无渲染** | voice.ts 定义了API但无组件import使用 |

**关键发现**：原版 Vue 前端中 `voiceApi`（`api/voice.ts`）**从未被任何 .vue 组件或 .ts 文件 import 调用**。全量搜索 `voiceApi.` 零命中，`import.*voice` 也仅匹配到 `VoiceDriftIndicator.vue`（无关，是 autopilot 组件）和 `performance.ts` 中的 `voiceDriftPollMs` 配置项。

原版 Vue 前端中不存在 `VoiceVaultPanel.vue` 文件（搜索 `**/VoiceVaultPanel.vue` 和 `**/*Voice*` 均未找到该文件）。与 voice 相关的 Vue 组件是 `components/autopilot/VoiceDriftIndicator.vue`（文风漂移指标，用 monitor API 不是 voiceApi）。

原版中 voice 相关数据实际来自：
- `CharacterProfile.vue` 中的 `voice_profile` / `voice_fingerprint` 字段（来自 Bible/Projection 数据，非 voiceApi）
- `memory.ts` 中的 `voice_fingerprint` 字段（记忆模型，非 voiceApi）

### iOS现状

| iOS文件:行号 | 已实现 | 缺失 |
|---|---|---|
| `Views/Panels/VoiceVaultPanel.swift:10-67` | 文风公约（BibleStore.bible.style）、角色声线（BibleStore.bible.characters 的 verbalTic/idleBehavior）、漂移预警（MonitorStore.voiceDrifts） | 未调用 voiceApi 的 createSample / getFingerprint |
| `Networking/APIEndpoint.swift` | 无 Voice 端点枚举 | Voice 端点完全未定义（createSample/getFingerprint） |
| `Models/MonitorModels.swift:86-110` | `VoiceDrift` 模型（characterId/characterName/driftScore/status/sampleCount） | 无 `VoiceSamplePayload`、`VoiceSampleResponse`、`VoiceFingerprintDTO` 模型 |

### 待补端点

| 端点 | HTTP方法 | 路径 | 请求体 | 响应 | 对齐原版文件:行号 |
|---|---|---|---|---|---|
| createSample | POST | `/novels/{novel_id}/voice/samples` | `{ai_original: String, author_refined: String, chapter_number: Int, scene_type?: String}` | `{sample_id: String}` | `api/voice.ts:28-32` |
| getFingerprint | GET | `/novels/{novel_id}/voice/fingerprint` | 无（query: `pov_character_id?: String`） | `{adjective_density: Double, avg_sentence_length: Double, sentence_count: Int, sample_count: Int, last_updated: String}` | `api/voice.ts:35-39` |

**iOS端点前缀**：`/api/v1`（APIEndpoint.defaultPrefix），完整路径为 `/api/v1/novels/{novel_id}/voice/samples` 和 `/api/v1/novels/{novel_id}/voice/fingerprint`。与 Chapters 同前缀（`/api/v1/novels`）。

---

## 4.5 全局浮动按钮（4个）

### 原版事实表

#### 按钮1：GlobalLLMEntryButton（侧栏/顶栏入口按钮）

| 属性 | 原版文件:行号 | 详情 |
|---|---|---|
| 组件文件 | `components/global/GlobalLLMEntryButton.vue:1-1104` | |
| 功能 | 点击打开 AI 控制台 Modal | Modal 含两个 Tab：LLM 设置 / 嵌入模型 |
| appearance 属性 | `:326-332` | `'sidebar'` 或 `'topbar'`，默认 `'sidebar'` |
| 渲染（sidebar 变体） | `:13-21` | 简洁行内按钮：SVG图标 + "AI 控制台" 文字 |
| 渲染（topbar 变体） | `:22-39` | 卡片式：图标核心 + 标题行 + 副标题（"LLM Gateway · OpenAI / Claude / Gemini"） |
| 点击行为 | `:8` `@click="openPanel"` → `:494-499` | `openPanel()` → 设 `showPanel=true`，首次初始化 `llmPanelInitialized=true` |
| Modal 内容 | `:43-306` | LLM Tab：渲染 `LLMControlPanel`（`:131-136`）；嵌入 Tab：本地/云端模型切换 + 扩展包安装（`:141-292`） |
| Runtime 状态 | `:348-358` | `refreshRuntimeSummary()` 调 `llmControlApi.getPanel()` 获取 `LLMRuntimeSummary` |
| 嵌入模型配置 | `:451-476` | `loadEmbeddingConfig()` / `handleSaveEmbedding()` 调 `settingsApi` |
| 扩展包安装 | `:399-440` | `startInstallExtensions()` 调 `settingsApi.installExtensions()` SSE流 |
| Modal 样式 | `:341-346` | `width: 92vw, maxWidth: 1100px, height: 85vh, marginTop: 5vh` |
| **使用位置** | `components/stats/StatsSidebar.vue` | `<GlobalLLMEntryButton appearance="sidebar" />` |
| | `components/stats/StatsTopBar.vue` | `<GlobalLLMEntryButton ref="llmRef" appearance="topbar" />`（hidden, aria-hidden） |

#### 按钮2：GlobalLLMFloatingButton（可拖拽浮动按钮）

| 属性 | 原版文件:行号 | 详情 |
|---|---|---|
| 组件文件 | `components/global/GlobalLLMFloatingButton.vue:1-825` | |
| 功能 | 全屏浮动可拖拽按钮，点击打开 AI 控制台 Modal | |
| 定位 | `:3-11` + `:207-210` | `position: fixed`，通过 `left/top` 定位 |
| 拖拽 | `:413-424` `onPointerDown` | pointer 事件拖拽，阈值6px判定拖拽 vs 点击 |
| 吸附边缘 | `:390-396` `snapToEdge` | 松手后根据中心X吸附到左/右边缘 |
| 位置持久化 | `:269-277` `saveState` | `writeStorageJson(storageKeys.globalLlmFabState, {version:4, dock, yRatio, mode})` |
| 恢复位置 | `:294-309` `restoreState` | `readStorageJson` 恢复 dock/yRatio/mode |
| 展开/最小化 | `:360-362` `toggleMinimize` | `mode: 'expanded'`（248x70圆角矩形）/ `'minimized'`（62x62圆形） |
| 悬浮操作栏 | `:18-29` | hover 时显示最小化/展开按钮 |
| Modal 内容 | `:63-128` | 仅 LLM Tab（无嵌入模型 Tab），渲染 `LLMControlPanel` |
| Modal 样式 | `:200-205` | 同 EntryButton：`width: 92vw, maxWidth: 1100px, height: 85vh, marginTop: 5vh` |
| **使用位置** | **全前端src搜索** | **未找到任何 .vue 文件 import 此组件**。该组件文件存在但属于死代码，Vue 前端未挂载。 |

#### 按钮3：PromptPlazaEntryButton（侧栏/顶栏入口按钮）

| 属性 | 原版文件:行号 | 详情 |
|---|---|---|
| 组件文件 | `components/global/PromptPlazaEntryButton.vue:1-595` | |
| 功能 | 点击打开提示词广场 Modal | |
| appearance 属性 | `:148-152` | `'sidebar'` 或 `'topbar'`，默认 `'sidebar'` |
| 渲染（sidebar 变体） | `:15-21` | SVG图标 + "提示词广场" 文字 |
| 渲染（topbar 变体） | `:23-39` | 卡片式：图标核心 + 标题行（含数量角标）+ 副标题（"浏览 · 编辑 · 版本管理"） |
| 点击行为 | `:10` `@click="openModal"` → `:164-166` | `openModal()` → `showModal=true` |
| Modal 内容 | `:45-93` | 异步加载 `PromptPlaza.vue`，传入 `seed-stats`，监听 `refresh-stats` |
| Modal 头部 | `:57-74` | 标题"提示词广场" + 统计 Tag + 导出/导入按钮 |
| 导出 | `:184-199` `handleExport` | `promptPlazaApi.exportAll()` → Blob 下载 |
| 导入 | `:202-240` `triggerImport`/`handleImport` | 文件选择 → `promptPlazaApi.importData(data)` |
| 统计加载 | `:172-181` `loadStats` | `promptPlazaApi.getStats()` → `PromptStats{total_nodes, total_versions}` |
| 鼠标悬浮预加载 | `:9` `@mouseenter="prefetchPromptPlaza"` | 异步预加载 PromptPlaza chunk |
| Modal 样式 | `:49` | `{ width: '92vw', maxWidth: '1100px', height: '85vh', marginTop: '5vh' }` |
| **使用位置** | `components/stats/StatsSidebar.vue` | `<PromptPlazaEntryButton appearance="sidebar" />` |
| | `components/stats/StatsTopBar.vue` | `<PromptPlazaEntryButton ref="plazaRef" appearance="topbar" />`（hidden） |

#### 按钮4：PromptPlazaFAB（浮动按钮+抽屉）

| 属性 | 原版文件:行号 | 详情 |
|---|---|---|
| 组件文件 | `components/global/PromptPlazaFAB.vue:1-309` | |
| 功能 | 固定浮动按钮，点击打开右侧抽屉显示 PromptPlaza | |
| 定位 | `:169-172` | `position: fixed; z-index: 890; bottom: 24px; right: 80px` |
| 按钮渲染 | `:5-20` | 52x52 圆角矩形，渐变背景，🏪图标，数量角标 |
| 点击行为 | `:11` `@click="toggleDrawer"` → `:118-120` | 切换 `showDrawer` |
| 抽屉 | `:23-59` | `n-drawer` placement="right" width=720，内含 `PromptPlaza` |
| 抽屉头部 | `:37-49` | 🏪图标 + "提示词广场" + 统计 Tag + 副标题 |
| DAG联动 | `:106-114` | 监听 `plazaBridge.shouldOpenPlaza`，消费 `consumeOpenRequest()` 获取 `nodeKey`，打开抽屉并选中节点 |
| 暴露方法 | `:151-158` `defineExpose` | `open()`, `close()`, `selectNode(nodeKey)` |
| 统计加载 | `:126-135` `loadStats` | `promptPlazaApi.getStats()` |
| **使用位置** | **全前端src搜索** | **未找到任何 .vue 文件 import 此组件**。`promptPlazaBridge.ts` 注释提到 PromptPlazaFAB 但无实际 import。该组件文件存在但属于死代码。 |

### iOS现状

| iOS文件 | 已实现 | 缺失 |
|---|---|---|
| `Views/Root/RootView.swift:36-92` | HStack两栏布局（SidebarView + NavigationStack），sheet/fullScreenCover | 无任何浮动按钮overlay |
| `Views/Root/SidebarView.swift:35-82` | List侧边栏导航，含书架/工作台/自动驾驶/设定集/知识图谱等 | 无 AI控制台入口按钮、无提示词广场入口按钮（提示词广场已有 `.promptPlaza` 导航项） |
| `App/AppState.swift` SidebarDestination | `.promptPlaza = "提示词广场"` 已有 | 无 `.llmConsole` 导航项 |
| `Views/Settings/LLMConfigSection.swift` | LLM 配置在设置页内 | 无全局快速入口 |
| `Views/PromptPlaza/PromptPlazaView.swift` | 提示词广场完整视图 | 无全局浮动入口 |
| **Grep搜索** `FloatingButton|FAB|overlay` | 零命中 | 4个浮动按钮全缺失 |

### 待补组件

| 组件 | 对齐原版 | iOS实现方案 |
|---|---|---|
| GlobalLLMEntryButton（sidebar 变体） | `GlobalLLMEntryButton.vue` appearance="sidebar" | SidebarView 底部新增"AI控制台"按钮，点击弹出 sheet 显示 LLMControlPanel 内容 |
| GlobalLLMEntryButton（topbar 变体） | `GlobalLLMEntryButton.vue` appearance="topbar" | iOS 无 topbar 概念，此变体可省略或合并到 sidebar 变体 |
| GlobalLLMFloatingButton | `GlobalLLMFloatingButton.vue` | RootView `.overlay` 上添加可拖拽浮动按钮，点击弹出 sheet |
| PromptPlazaEntryButton（sidebar 变体） | `PromptPlazaEntryButton.vue` appearance="sidebar" | SidebarView 已有 `.promptPlaza` 导航项，功能等价 |
| PromptPlazaEntryButton（topbar 变体） | `PromptPlazaEntryButton.vue` appearance="topbar" | iOS 无 topbar，可省略 |
| PromptPlazaFAB | `PromptPlazaFAB.vue` | RootView `.overlay` 上添加浮动按钮，点击弹出 sheet 显示 PromptPlazaView |

---

## 4.6 知识图谱写操作

### 原版事实表

| 操作 | 原版文件:行号 | HTTP方法 | 路径 | 请求体 | 响应 |
|---|---|---|---|---|---|
| getChapterInferenceEvidence | `api/knowledgeGraph.ts:60-68` | GET | `/knowledge-graph/novels/{novelId}/chapters/by-number/{chapterNumber}/inference-evidence` | 无 | `{success: boolean, data: ChapterInferenceEvidenceData}` |
| revokeChapterInference | `api/knowledgeGraph.ts:70-78` | DELETE | `/knowledge-graph/novels/{novelId}/chapters/by-number/{chapterNumber}/inference` | 无 | `{success: boolean, data: {removed_provenance_triples: number, deleted_inferred_facts: number}}` |
| revokeInferredTriple | `api/knowledgeGraph.ts:80-88` | DELETE | `/knowledge-graph/novels/{novelId}/inferred-triples/{tripleId}` | 无 | `{success: boolean, message: string}` |
| inferNovel | `api/knowledgeGraph.ts:92-99` | POST | `/knowledge-graph/novels/{novelId}/infer` | `{}`（空body） | `{success: boolean, data: Record<string, unknown>}` |
| getTriples | `api/knowledgeGraph.ts:104-116` | GET | `/knowledge-graph/novels/{novelId}/triples` | 无（query: `source_type?`, `min_confidence=0`） | `{success: boolean, data: {total: number, triples: TripleDTO[]}}` |
| confirmTriple | `api/knowledgeGraph.ts:119-125` | POST | `/knowledge-graph/triples/{tripleId}/confirm` | `{}` | `{success: boolean, data: TripleDTO}` |
| starTriple | `api/knowledgeGraph.ts:128-134` | PATCH | `/knowledge-graph/novels/{novelId}/triples/{tripleId}/star` | `{starred: boolean}` | `{success: boolean, triple_id: string, starred: boolean}` |
| deleteTriple | `api/knowledgeGraph.ts:137-142` | DELETE | `/knowledge-graph/triples/{tripleId}` | 无 | `{success: boolean, message: string}` |
| getStatistics | `api/knowledgeGraph.ts:147-152` | GET | `/knowledge-graph/novels/{novelId}/statistics` | 无 | `{success: boolean, data: KGStatistics}` |

**原版 TripleDTO 数据模型**（`api/knowledgeGraph.ts:37-48`）：
```typescript
interface TripleDTO {
  id: string
  subject: string
  subject_type: string
  predicate: string
  object: string
  object_type: string
  confidence: number
  source_type: string
  chapter_number: number | null
  is_starred?: boolean
}
```

**原版 KGStatistics 数据模型**（`api/knowledgeGraph.ts:50-55`）：
```typescript
interface KGStatistics {
  total_triples: number
  source_distribution: Record<string, number>
  confidence_distribution: { high: number; medium: number; low: number }
  predicate_distribution: Record<string, number>
}
```

**原版 ChapterInferenceEvidenceData 数据模型**（`api/knowledgeGraph.ts:28-33`）：
```typescript
interface ChapterInferenceEvidenceData {
  story_node_id: string | null
  chapter_number: number
  facts: InferenceFactBundle[]
  hint?: string
}
```

### iOS现状

| 操作 | iOS端点(APIEndpoint.swift:行号) | iOSStore(KnowledgeGraphStore.swift:行号) | 已接线 | 缺失 |
|---|---|---|---|---|
| loadTriples | `:177-178` `.triples(novelId:)` GET | `:29-50` `loadTriples(novelId:)` | ✅ | — |
| loadStatistics | `:195-196` `.statistics(novelId:)` GET | `:53-64` `loadStatistics(novelId:)` | ✅ | — |
| search | `:199-200` `.search(novelId:)` POST | `:67-82` `search(novelId:query:topK:)` | ✅ | — |
| confirmTriple | `:187-188` `.confirmTriple(tripleId:)` POST | `:85-91` `confirmTriple(tripleId:)` | ✅ | 未更新本地triple列表（原版返回更新后的TripleDTO） |
| deleteTriple | `:191-192` `.deleteTriple(tripleId:)` DELETE | `:94-101` `deleteTriple(tripleId:)` | ✅ | — |
| index | `:197-198` `.index(novelId:)` POST | `:104-110` `index(novelId:)` | ✅ | — |
| **inferNovel** | `:179-180` `.infer(novelId:)` POST | **无** | ❌ | Store 方法完全缺失 |
| **loadInferenceEvidence** | `:181-182` `.inferenceEvidence(novelId:chapterNumber:)` GET | **无** | ❌ | Store 方法完全缺失 |
| **revokeChapterInference** | `:183-184` `.deleteChapterInference(novelId:chapterNumber:)` DELETE | **无** | ❌ | Store 方法完全缺失 |
| **revokeInferredTriple** | `:185-186` `.deleteInferredTriple(novelId:tripleId:)` DELETE | **无** | ❌ | Store 方法完全缺失 |
| **starTriple** | `:189-190` `.starTriple(novelId:tripleId:)` PATCH | **无** | ❌ | Store 方法完全缺失（端点已定义但缺 `starred` body 参数传递） |
| elementRelations | `:193-194` `.elementRelations(elementType:elementId:)` GET | **无** | ❌ | 不在本次任务范围 |

### iOS端点已定义情况（APIEndpoint.swift:1507-1549）

```swift
// 已定义的 KnowledgeGraph 端点（全部 path + method 已实现）：
case .triples(novelId)           // GET  /knowledge-graph/novels/{id}/triples
case .infer(novelId)             // POST /knowledge-graph/novels/{id}/infer
case .inferenceEvidence(novelId, chapterNumber)  // GET  .../inference-evidence
case .deleteChapterInference(novelId, chapterNumber)  // DELETE .../inference
case .deleteInferredTriple(novelId, tripleId)  // DELETE .../inferred-triples/{id}
case .confirmTriple(tripleId)    // POST /knowledge-graph/triples/{id}/confirm
case .starTriple(novelId, tripleId)  // PATCH .../star   ← 注意：缺 starred body 参数
case .deleteTriple(tripleId)     // DELETE /knowledge-graph/triples/{id}
case .elementRelations(elementType, elementId)  // GET
case .statistics(novelId)        // GET
case .index(novelId)             // POST
case .search(novelId)            // POST
```

**端点定义完整度**：所有原版 knowledgeGraph.ts 的端点在 iOS APIEndpoint.swift 中均已定义，path 和 method 均对齐。唯一差异：`starTriple` 的 `starred` 参数需要通过请求体传递（原版 `apiClient.patch(url, {starred})`），iOS 端点枚举不携带 body，需在 Store 方法中传入。

### 待补接线

| 操作 | Store方法名 | 端点 | 请求体 | 需更新本地状态 | 关联模型 |
|---|---|---|---|---|---|
| inferNovel | `inferNovel(novelId:)` | `.infer(novelId:)` POST | `{}` | isLoading + 刷新 triples | 返回 `{success, data}` |
| loadInferenceEvidence | `loadInferenceEvidence(novelId:chapterNumber:)` | `.inferenceEvidence(novelId:chapterNumber:)` GET | 无 | 新增 `@Published var inferenceEvidence: InferenceEvidence?` | `InferenceEvidence`（已定义于 KnowledgeGraphModels.swift:191-202） |
| revokeChapterInference | `revokeChapterInference(novelId:chapterNumber:)` | `.deleteChapterInference(novelId:chapterNumber:)` DELETE | 无 | 刷新 triples + statistics | 返回 `{success, data: {removed_provenance_triples, deleted_inferred_facts}}` |
| revokeInferredTriple | `revokeInferredTriple(novelId:tripleId:)` | `.deleteInferredTriple(novelId:tripleId:)` DELETE | 无 | 从 triples 中移除 | 返回 `{success, message}` |
| starTriple | `starTriple(novelId:tripleId:starred:)` | `.starTriple(novelId:tripleId:)` PATCH | `{starred: Bool}` | 更新 triple 的 isStarred 状态 | 返回 `{success, triple_id, starred}` |

**模型缺口**：iOS `KnowledgeTriple`（KnowledgeGraphModels.swift:14-70）缺少原版 `TripleDTO` 的以下字段：
- `subject_type`（iOS 有 `entityType` 但语义可能不同）
- `object_type`（iOS 无此字段）
- `is_starred`（iOS 无此字段，starTriple 操作必需）

iOS `KnowledgeGraphStatistics`（KnowledgeGraphModels.swift:165-186）字段与原版 `KGStatistics` 不一致：
- iOS: `totalTriples, byEntityType, byImportance, bySourceType`
- 原版: `total_triples, source_distribution, confidence_distribution{high,medium,low}, predicate_distribution`

iOS `InferenceEvidence`（KnowledgeGraphModels.swift:191-202）与原版 `ChapterInferenceEvidenceData` 结构不同：
- iOS: `{triples: [KnowledgeTriple], evidence: [AnyCodable]}`
- 原版: `{story_node_id, chapter_number, facts: [InferenceFactBundle], hint?}`

---

## 疑问清单（需主理人决策）

### 疑问1：voiceApi 在原版 Vue 中从未被调用

**事实**：`api/voice.ts` 定义了 `voiceApi.createSample` 和 `voiceApi.getFingerprint` 两个方法，但全量搜索 Vue 前端 `src/` 目录，`voiceApi` 从未被任何组件 import 或调用。原版也不存在 `VoiceVaultPanel.vue` 文件。

**问题**：任务要求"VoiceVaultPanel改调voiceApi"，但原版 Vue 既无此组件也无调用方。iOS 现有 `VoiceVaultPanel.swift` 用 BibleStore + MonitorStore 实现了文风公约/角色声线/漂移预警，功能比原版 Vue 的 voiceApi 使用更丰富。

**请决策**：
- A) 仍按任务要求，在 iOS 中新增 voice API 端点定义 + VoiceVaultPanel 增加调 voiceApi 的 createSample/getFingerprint 功能（在现有 Bible/Monitor 展示基础上追加文风指纹统计区域）？
- B) 仅新增 voice API 端点定义（对齐原版 voice.ts），VoiceVaultPanel 保持现状不改动？
- C) 其他方案？

### 疑问2：任务中"PUT保存"操作在原版 knowledgeGraph.ts 中不存在

**事实**：原版 `api/knowledgeGraph.ts` 中没有任何 PUT 方法的操作。所有写操作为：POST（infer, confirmTriple, index, search）、DELETE（revokeChapterInference, revokeInferredTriple, deleteTriple）、PATCH（starTriple）。

**问题**：任务描述的"原版操作（必须接线）：PUT保存 / generate / starTriple / inferNovel / revokeInference"中，"PUT保存"无法对应到原版任何端点。

**请决策**：
- A) "PUT保存"是否指 `confirmTriple`（POST confirm，语义上"确认保存"三元组）？
- B) "PUT保存"是否指 `starTriple`（PATCH star，语义上"标记保存"）？
- C) "PUT保存"是否为笔误，实际不需要接线 PUT 操作？
- D) 其他含义？

### 疑问3：任务中"generate"与"inferNovel"是否为同一操作

**事实**：原版 `knowledgeGraph.ts` 中只有一个 POST 推断操作 `inferNovel`（POST `/knowledge-graph/novels/{id}/infer`）。另有 `index`（POST `/knowledge-graph/novels/{id}/index`）用于构建向量索引。

**问题**：任务列出"generate"和"inferNovel"两个操作，但原版只有 `inferNovel` 一个 POST 推断端点。

**请决策**：
- A) "generate"即 `inferNovel`，两者为同一操作，只需接线一次？
- B) "generate"指 `index`（POST index 构建索引），"inferNovel"指 POST infer，两个都要接线？
- C) 其他含义？

### 疑问4：GlobalLLMFloatingButton 和 PromptPlazaFAB 在原版 Vue 中是死代码

**事实**：`GlobalLLMFloatingButton.vue` 和 `PromptPlazaFAB.vue` 两个组件文件存在于 `components/global/` 目录，但全量搜索 Vue 前端 `src/` 目录（含 .vue 和 .ts 文件），这两个组件**从未被任何文件 import 或使用**。App.vue 不引用它们，StatsSidebar/StatsTopBar 也不引用它们。

**问题**：任务要求补全4个浮动按钮，但其中2个（FloatingButton 和 FAB）在原版 Vue 中本身就是未挂载的死代码。

**请决策**：
- A) 仍按任务要求实现4个浮动按钮（包括原版死代码的2个），在 iOS RootView 上添加 overlay？
- B) 仅实现有实际使用证据的2个 EntryButton（sidebar 变体），跳过死代码的2个浮动按钮？
- C) 其他方案？

### 疑问5：iOS KnowledgeTriple 模型缺 is_starred 字段

**事实**：原版 `TripleDTO` 有 `is_starred?: boolean` 字段，iOS `KnowledgeTriple` 无此字段。`starTriple` 操作需要更新本地三元组的 starred 状态，缺此字段无法在 UI 上反映标星状态。

**问题**：是否需要在 `KnowledgeTriple` 中新增 `isStarred: Bool?` 字段（CodingKey: `is_starred`）？

**请决策**：
- A) 新增 `isStarred` 字段到 `KnowledgeTriple`，并更新 init(from:) 解码？
- B) 不改模型，starTriple 仅发送请求不在本地维护标星状态？
- C) 其他方案？

### 疑问6：iOS KnowledgeGraphStatistics 与原版 KGStatistics 字段不一致

**事实**：
- iOS `KnowledgeGraphStatistics`: `totalTriples, byEntityType, byImportance, bySourceType`
- 原版 `KGStatistics`: `total_triples, source_distribution, confidence_distribution{high,medium,low}, predicate_distribution`

字段完全不匹配。iOS 的 `byEntityType`/`byImportance`/`bySourceType` 在原版不存在；原版的 `source_distribution`/`confidence_distribution`/`predicate_distribution` 在 iOS 不存在。

**问题**：这是阶段1-3遗留的差异，是否需要在本次4.6任务中修正模型对齐原版？

**请决策**：
- A) 本次修正 `KnowledgeGraphStatistics` 模型字段对齐原版 `KGStatistics`？
- B) 本次不改模型，仅补 Store 接线，模型差异留后续批次处理？
- C) 其他方案？

### 疑问7：iOS InferenceEvidence 与原版 ChapterInferenceEvidenceData 结构不同

**事实**：
- iOS `InferenceEvidence`: `{triples: [KnowledgeTriple], evidence: [AnyCodable]}`
- 原版 `ChapterInferenceEvidenceData`: `{story_node_id, chapter_number, facts: [InferenceFactBundle], hint?}`
  - `InferenceFactBundle`: `{fact: InferenceFactPayload, provenance: [InferenceProvenanceRow]}`
  - `InferenceFactPayload`: `{id, subject, predicate, object, chapter_number, confidence, source_type}`
  - `InferenceProvenanceRow`: `{id, chapter_element_id, rule_id, role}`

**问题**：iOS 模型结构与原版完全不同，loadInferenceEvidence 操作需要正确解码原版返回的 `ChapterInferenceEvidenceData` 结构。是否需要新增/修正 iOS 模型以对齐原版？

**请决策**：
- A) 新增 `ChapterInferenceEvidenceData`、`InferenceFactBundle`、`InferenceFactPayload`、`InferenceProvenanceRow` 等 iOS 模型，对齐原版？
- B) 保留现有 `InferenceEvidence` 模型，用 `AnyCodable` 灵活解码？
- C) 其他方案？

---

## 实现工作量预估（待主理人确认疑问后更新）

### 4.1 voiceApi 对接
- 新增 `APIEndpoint.Voice` 枚举（2个端点）+ EndpointInfo 扩展
- 新增 `VoiceSamplePayload`、`VoiceSampleResponse`、`VoiceFingerprintDTO` 模型
- VoiceVaultPanel.swift 增加文风指纹统计区域（取决于疑问1决策）

### 4.5 全局浮动按钮
- 新增 `GlobalLLMEntryButton` Swift 视图（sidebar 变体）
- 新增 `GlobalLLMFloatingButton` Swift 视图（可拖拽浮动按钮，取决于疑问4决策）
- 新增 `PromptPlazaFAB` Swift 视图（浮动按钮，取决于疑问4决策）
- RootView.swift 添加 overlay 挂载浮动按钮
- SidebarView.swift 底部添加 AI控制台入口按钮

### 4.6 知识图谱写操作
- KnowledgeGraphStore.swift 新增5个方法：`inferNovel`、`loadInferenceEvidence`、`revokeChapterInference`、`revokeInferredTriple`、`starTriple`
- 可能需要新增/修正模型（取决于疑问5/6/7决策）
- KnowledgeGraphView.swift 增加操作按钮（推断/标星/撤销推断）
