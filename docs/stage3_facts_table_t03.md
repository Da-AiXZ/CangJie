# 仓颉 iOS 阶段3 T03 — Mock面板接API 原版事实表

> **工程师**：寇豆码（Alex）
> **基于**：T03 三个Mock面板接真实API（3.4.1/3.4.2/3.4.3）
> **遵守**：防砍功能约束方法 — 机制1：工程师读原版输出事实表
> **原版前端根目录**：`D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`

---

## 3.4.1 QualityGuardrailPanel（质量护栏面板）

### 原版API事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 1 | guardrailApi.check() — 质量检查 | engineCore.ts:133-139 | `POST /novels/{novelId}/guardrail/check` body=GuardrailCheckRequest | 按钮点击 runCheck() | GuardrailCheckResponse |
| 2 | guardrailApi.enforce() — 强制模式检查 | engineCore.ts:141-146 | `POST /novels/{novelId}/guardrail/check` body={...body,mode:'enforce'} | 复用同端点，mode=enforce | GuardrailCheckResponse |
| 3 | chapterApi.getGuardrailSnapshot() — 获取自动快照 | chapter.ts:159-167 | `GET /novels/{novelId}/chapters/{chapterNumber}/guardrail-snapshot` | 切换章节时 hydrateFromSnapshot() | GuardrailCheckResponse \| null |
| 4 | GuardrailCheckRequest 请求体 | engineCore.ts:100-107 | — | — | {text, character_names?, chapter_goal?, era?, scene_type?, mode?} |
| 5 | GuardrailCheckResponse 响应体 | engineCore.ts:126-131 | — | — | {overall_score: number, passed: boolean, dimensions: GuardrailDimensionScore[], violations: GuardrailViolationDTO[]} |
| 6 | GuardrailDimensionScore 维度评分 | engineCore.ts:109-114 | — | 雷达图/条形图 | {name: string, key: string, score: number, weight: number} |
| 7 | GuardrailViolationDTO 违规项 | engineCore.ts:116-124 | — | 违规列表折叠项 | {dimension, type, severity, description, original, suggestion, character} |

### 原版面板UI事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 8 | 无章节时显示空状态 | QualityGuardrailPanel.vue:3 | — | n-empty "请从左侧选择一个章节" | — |
| 9 | 顶部操作栏（章节号+通过标签+模式选择+重新检查按钮） | QualityGuardrailPanel.vue:7-31 | guardrailApi.check() | n-select(advise/enforce) + n-button(loading) | checkMode: GuardrailMode |
| 10 | info提示（保存后自动运行护栏说明） | QualityGuardrailPanel.vue:33-38 | — | n-alert type=info | — |
| 11 | 总分圆形进度条 | QualityGuardrailPanel.vue:44-61 | — | n-progress type=circle percentage=Math.round(overall_score*100) color=scoreColor(score) | lastReport.overall_score |
| 12 | 六维度条形图 | QualityGuardrailPanel.vue:63-87 | — | v-for dim in dimensions: n-progress type=line percentage=Math.round(score*100) + weight×100% | lastReport.dimensions[] |
| 13 | 违规详情折叠列表 | QualityGuardrailPanel.vue:89-120 | — | n-collapse: severity标签+维度标签+角色 → 描述+原文+建议 | lastReport.violations[] |
| 14 | 无违规时显示成功提示 | QualityGuardrailPanel.vue:122-125 | — | n-alert type=success "所有维度检查通过" | — |
| 15 | 无报告且未检查中显示空状态 | QualityGuardrailPanel.vue:128-134 | — | n-empty "尚无自动快照" | — |
| 16 | runCheck() — 手动检查流程 | QualityGuardrailPanel.vue:200-225 | chapterApi.getChapter(slug, chapter.number) → text → guardrailApi.check(slug, {text, mode, chapter_goal, character_names:[], era:'ancient', scene_type:'auto'}) | 先获取章节正文，再调API | — |
| 17 | hydrateFromSnapshot() — 快照恢复 | QualityGuardrailPanel.vue:227-238 | chapterApi.getGuardrailSnapshot(slug, chapter.number) | 切换章节时自动调用 | lastReport = snap |
| 18 | watch slug+chapter.number → hydrateFromSnapshot | QualityGuardrailPanel.vue:240-246 | — | immediate=true | — |
| 19 | watch deskTick → hydrateFromSnapshot | QualityGuardrailPanel.vue:248-250 | — | 工作台刷新tick触发 | — |
| 20 | scoreColor() — 分数着色 | chapterWriting.ts:139-143 | — | score≥0.75→绿, ≥0.5→橙, <0.5→红 | — |
| 21 | 六维度中文标签映射 | chapterWriting.ts:80-87 | — | language_style→语言风格, character_consistency→角色一致性, plot_density→情节密度, naming→命名, viewpoint→视角, rhythm→节奏 | GUARDRAIL_DIMENSION_LABELS |
| 22 | 严重程度标签映射 | chapterWriting.ts:71-78 | — | critical/error→严重(error), important/warning→重要(warning), minor/info→轻微(info) | GUARDRAIL_SEVERITY_META |
| 23 | 模式选项 | chapterWriting.ts:89-92 | — | advise→建议模式, enforce→强制模式 | GUARDRAIL_MODE_OPTIONS |

### iOS现状事实表

| # | iOS文件:行号 | 现状 | 硬编码位置 |
|---|-------------|------|-----------|
| 24 | QualityGuardrailPanel.swift:14-16 | dimensions硬编码5条模拟数据 | `@State private var dimensions: [(String, Double)]` |
| 25 | QualityGuardrailPanel.swift:17-20 | violations硬编码2条模拟数据 | `@State private var violations: [(String, String, String)]` |
| 26 | QualityGuardrailPanel.swift:26-29 | Canvas雷达图绘制 | drawRadar() — 从dimensions取值 |
| 27 | QualityGuardrailPanel.swift:33-46 | 违规列表渲染 | 从violations数组取值 |
| 28 | MonitorModels.swift:140-195 | T01已建GuardrailCheck模型 | GuardrailCheckRequest/DimensionScore/ViolationDTO/Response ✅ |
| 29 | APIEndpoint.swift:399-400 | T01已建guardrailCheck端点 | `case guardrailCheck(novelId: String)` POST ✅ |
| 30 | APIEndpoint.swift:79-80 | 阶段1已建guardrailSnapshot端点 | `case guardrailSnapshot(novelId: String, chapterNumber: Int)` GET ✅ |

---

## 3.4.2 ConsistencyReportPanel（一致性报告面板）

### 原版API事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 1 | ConsistencyIssueDTO 模型 | workflow.ts:242-247 | — | — | {type: string, severity: string, description: string, location: number} |
| 2 | ConsistencyReportDTO 模型 | workflow.ts:249-253 | — | — | {issues: ConsistencyIssueDTO[], warnings: ConsistencyIssueDTO[], suggestions: string[]} |
| 3 | done事件解析consistency_report | workflow.ts:453-463 | SSE done事件 | rawReport是object则直接用，否则空{issues:[],warnings:[],suggestions:[]} | ConsistencyReportDTO |
| 4 | style_warnings解析 | workflow.ts:468-470 | SSE done事件 | Array.isArray → StyleWarning[] | StyleWarning |
| 5 | ghost_annotations解析 | workflow.ts:471-473 | SSE done事件 | o.ghost_annotations != null → unknown[] | unknown[] |

### 原版面板UI事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 6 | report为null时不渲染 | ConsistencyReportPanel.vue:2 | — | v-if="report" | — |
| 7 | 头部标题+token数 | ConsistencyReportPanel.vue:3-6 | — | cr-title + cr-meta(约 N tokens) | tokenCount prop |
| 8 | hasAnyContent计算属性 | ConsistencyReportPanel.vue:89-97 | — | issues/warnings/suggestions任一非空 | boolean |
| 9 | 问题(issues)折叠列表 | ConsistencyReportPanel.vue:13-37 | — | v-for it in report.issues: severity标签+type标签+位置按钮+描述 | report.issues[] |
| 10 | 警告(warnings)折叠列表 | ConsistencyReportPanel.vue:39-59 | — | v-for it in report.warnings: 同issues结构 | report.warnings[] |
| 11 | 建议(suggestions)有序列表 | ConsistencyReportPanel.vue:61-65 | — | ol > li v-for s in report.suggestions | report.suggestions[] |
| 12 | 无内容时空状态 | ConsistencyReportPanel.vue:68 | — | n-empty "暂无一致性问题或建议" | — |
| 13 | 位置点击事件 | ConsistencyReportPanel.vue:25-31,49-55 | — | $emit('location-click', it.location) | location: number |
| 14 | 默认展开项 | ConsistencyReportPanel.vue:99-105 | — | 有issues展开issues，有warnings展开warnings，有suggestions展开suggestions | defaultExpanded |
| 15 | severityTag() — 严重程度着色 | ConsistencyReportPanel.vue:111-117 | — | critical→error, important→warning, minor→info, else→default | — |
| 16 | severityLabel() — 严重程度标签 | ConsistencyReportPanel.vue:119-125 | — | critical→严重, important→重要, minor→轻微 | — |
| 17 | 面板被ChapterElementPanel内嵌 | ChapterElementPanel.vue:125-129 | — | `<ConsistencyReportPanel :report="lastWorkflowResult.consistency_report" :token-count="lastWorkflowResult.token_count" @location-click="onLocationClick" />` | props传入 |

### iOS现状事实表

| # | iOS文件:行号 | 现状 | 硬编码位置 |
|---|-------------|------|-----------|
| 18 | ConsistencyReportPanel.swift:13-16 | issues硬编码2条模拟数据 | `@State private var issues: [(String, String, String, String)]` |
| 19 | ConsistencyReportPanel.swift:24-38 | 问题列表渲染 | 从issues数组取值，无warnings/suggestions分组 |
| 20 | GenerateChapterModels.swift:128-148 | ConsistencyIssueDTO+ConsistencyReportDTO已建 ✅ | — |
| 21 | WorkbenchStore.swift:59 | generateChapterConsistencyReport已存在 ✅ | `@Published var generateChapterConsistencyReport: ConsistencyReportDTO?` |
| 22 | WorkbenchStore.swift:425-429 | done事件解析consistency_report已实现 ✅ | parseConsistencyReport(reportDict) |
| 23 | WorkbenchStore.swift:442-444 | style_warnings解析已实现 ✅ | parseStyleWarning() |
| 24 | ChapterGenerationPanel.swift:28 | 章节生成面板已引用consistencyReport ✅ | `if let report = workbenchStore.generateChapterConsistencyReport` |

---

## 3.4.3 ChapterElementPanel（章节元素面板）

### 原版API事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 1 | chapterElementApi.getElements() — 获取元素列表 | chapterElement.ts:38-44 | `GET /chapters/{chapterId}/elements` 可选query: element_type | loadElements()调用 | {success: boolean, data: ChapterElementDTO[]} |
| 2 | chapterElementApi.addElement() — 添加元素 | chapterElement.ts:46-52 | `POST /chapters/{chapterId}/elements` body=ChapterElementCreate | — | {success: boolean, data: ChapterElementDTO} |
| 3 | chapterElementApi.batchUpdate() — 批量替换 | chapterElement.ts:54-60 | `PUT /chapters/{chapterId}/elements` body={elements: ChapterElementCreate[]} | — | {success: boolean, data: {updated_count: number, elements: ChapterElementDTO[]}} |
| 4 | chapterElementApi.deleteElement() — 删除元素 | chapterElement.ts:62-67 | `DELETE /chapters/{chapterId}/elements/{elementId}` | — | {success: boolean, message: string} |
| 5 | chapterElementApi.getElementChapters() — 反查章节 | chapterElement.ts:69-74 | `GET /chapters/elements/{elementType}/{elementId}/chapters` | — | {success: boolean, data: {appearance_count: number, chapters: unknown[]}} |
| 6 | ChapterElementDTO 模型 | chapterElement.ts:14-24 | — | — | {id, chapter_id, element_type, element_id, relation_type, importance, appearance_order, notes, created_at} |
| 7 | ChapterElementCreate 请求体 | chapterElement.ts:26-33 | — | — | {element_type, element_id, relation_type, importance?, appearance_order?, notes?} |
| 8 | ElementType 类型 | chapterElement.ts:10 | — | — | 'character' \| 'location' \| 'item' \| 'organization' \| 'event' |
| 9 | RelationType 类型 | chapterElement.ts:11 | — | — | 'appears' \| 'mentioned' \| 'scene' \| 'uses' \| 'involved' \| 'occurs' |
| 10 | Importance 类型 | chapterElement.ts:12 | — | — | 'major' \| 'normal' \| 'minor' |

### 原版面板UI事实表

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|-------------|-----------|----------|---------|
| 11 | 无章节时显示空状态 | ChapterElementPanel.vue:3 | — | n-empty "请先从左侧选择一个章节" | — |
| 12 | 只读模式提示 | ChapterElementPanel.vue:7-9 | — | n-alert type=warning "托管运行中：仅可查看" | readOnly prop |
| 13 | 人物/地点/道具卡片头部 | ChapterElementPanel.vue:12-32 | — | n-card: 标题 + filterType选择器 + 刷新按钮 | filterType: ElementType \| undefined |
| 14 | 人物分组列表 | ChapterElementPanel.vue:36-50 | — | v-for elem in groupedCharacters: getElementDisplayName(element_id, 'character') + relation标签 + importance标签 + notes | elements.filter(e=>e.element_type==='character') |
| 15 | 地点分组列表 | ChapterElementPanel.vue:52-66 | — | v-for elem in groupedLocations: getElementDisplayName(element_id, 'location') + relation标签 + importance标签 + notes | elements.filter(e=>e.element_type==='location') |
| 16 | 其他分组列表（道具/组织/事件） | ChapterElementPanel.vue:68-86 | — | v-for elem in groupedOther: elemType标签 + getElementDisplayName + relation标签 + importance标签 + notes | elements.filter(e=>e.element_type!=='character'&&!=='location') |
| 17 | 空元素列表提示 | ChapterElementPanel.vue:87 | — | n-empty "暂无关联元素" | — |
| 18 | 伏笔回收建议卡片 | ChapterElementPanel.vue:93-105 | — | ForeshadowChapterSuggestionsPanel embedded compact auto-run | — |
| 19 | AI生成质检卡片（内嵌ConsistencyReportPanel） | ChapterElementPanel.vue:108-165 | — | ConsistencyReportPanel :report="lastWorkflowResult.consistency_report" + style_warnings折叠 + ghost_annotations折叠 | lastWorkflowResult prop |
| 20 | loadElements() — 加载元素 | ChapterElementPanel.vue:316-327 | chapterElementApi.getElements(storyNodeId, filterType) | storyNodeId从planningApi.getStructure解析 | elements = res.data |
| 21 | resolveStoryNode() — 解析章节节点ID | ChapterElementPanel.vue:294-314 | planningApi.getStructure(slug) → findChapterNode(roots, chapterNumber) | 从结构树找chapter节点获取node.id作为chapterId | storyNodeId |
| 22 | loadBible() — 加载Bible数据 | ChapterElementPanel.vue:330-339 | bibleApi.getBible(slug) | 获取角色和地点列表用于ID→name映射 | bibleCharacters, bibleLocations |
| 23 | getElementDisplayName() — ID转名称 | ChapterElementPanel.vue:238-248 | — | character: bibleCharacters.find(c=>c.id===elementId)?.name; location: 同理; else: elementId | — |
| 24 | watch slug → loadBible+resolveStoryNode+loadElements | ChapterElementPanel.vue:345-356 | — | 切换小说时重新加载 | — |
| 25 | watch currentChapterNumber → resolveStoryNode+loadElements | ChapterElementPanel.vue:358-361 | — | 切换章节时重新加载 | — |
| 26 | watch deskTick → debounce reload | ChapterElementPanel.vue:363-374 | — | useDebouncedTask(resolveStoryNode+loadElements) | deskTickDebounceMs |
| 27 | onMounted → loadBible+resolveStoryNode+loadElements | ChapterElementPanel.vue:376-380 | — | 初始化加载 | — |
| 28 | 元素类型中文标签 | chapterElement.ts:8-14(domain) | — | character→人物, location→地点, item→道具, organization→组织, event→事件 | ELEMENT_TYPE_META |
| 29 | 关系类型中文标签 | chapterElement.ts:16-23(domain) | — | appears→出场, mentioned→提及, scene→场景, uses→使用, involved→参与, occurs→发生 | RELATION_TYPE_META |
| 30 | 重要度中文标签 | chapterElement.ts:25-29(domain) | — | major→主要, normal→一般, minor→次要 | IMPORTANCE_META |
| 31 | onLocationClick() — 位置点击提示 | ChapterElementPanel.vue:341-343 | — | message.info(`问题位置约在第 ${location} 字附近`) | — |

### iOS现状事实表

| # | iOS文件:行号 | 现状 | 硬编码位置 |
|---|-------------|------|-----------|
| 32 | ChapterElementPanel.swift:17 | 道具硬编码空数组 | `elementSection("道具", icon: "shippingbox.fill", items: [])` |
| 33 | ChapterElementPanel.swift:18 | 伏笔引用硬编码空数组 | `elementSection("伏笔引用", icon: "lightbulb.fill", items: [])` |
| 34 | ChapterElementPanel.swift:45-48 | extractCharacters返回空数组 | `return []` |
| 35 | ChapterElementPanel.swift:50-52 | extractLocations返回空数组 | `return []` |
| 36 | ChapterElementModels.swift:1-198 | T01已建ChapterElement模型 ✅ | ChapterElementDTO + ChapterElementCreate + 5响应类型 + 3枚举 |
| 37 | APIEndpoint.swift:T01新增 | T01已建5个ChapterElement端点 ✅ | list/create/batchUpdate/delete/chaptersByElement |
| 38 | — | 无ChapterElementStore | 需新建Store管理CRUD |

---

## 疑问上报

### 疑问1：QualityGuardrailPanel的era参数硬编码'ancient'
原版 `QualityGuardrailPanel.vue:218` 中 `era: 'ancient'` 是硬编码的。iOS是否需要从小说设定中动态获取era？还是也硬编码'ancient'？

**建议**：iOS也硬编码'ancise'（与原版一致），后续如需动态化再改。

### 疑问2：QualityGuardrailPanel的scene_type硬编码'auto'
原版 `QualityGuardrailPanel.vue:219` 中 `scene_type: 'auto'` 是硬编码的。iOS是否保持一致？

**建议**：iOS保持硬编码'auto'。

### 疑问3：ChapterElementPanel的chapterId来源
原版 `ChapterElementPanel.vue:294-314` 中 chapterId 不是 chapter.number，而是从 `planningApi.getStructure(slug)` 结构树中找到的 `node.id`（StoryNode.id）。iOS的StructureStore是否已有获取结构树节点ID的能力？

**需确认**：iOS StructureStore.loadTree(novelId:) 是否返回包含 node.id 的树结构，以支持按 chapter.number 查找 node.id。

### 疑问4：ChapterElementPanel内嵌ConsistencyReportPanel
原版 `ChapterElementPanel.vue:125-129` 将 ConsistencyReportPanel 内嵌在 ChapterElementPanel 的"AI生成质检"卡片中，数据来自 `lastWorkflowResult` prop。iOS的 ConsistencyReportPanel 目前是独立面板。是否需要：
- A) 在 ChapterElementPanel 内嵌入 ConsistencyReportPanel（对齐原版）
- B) 保持 ConsistencyReportPanel 独立，ChapterElementPanel 只做元素CRUD

**建议**：方案A（对齐原版），但需确认 ContextPanelTabView 中两个面板是否同时展示。

### 疑问5：ChapterElementPanel内嵌ForeshadowChapterSuggestionsPanel
原版 `ChapterElementPanel.vue:97-104` 内嵌了伏笔回收建议面板。iOS是否需要在 ChapterElementPanel 中也嵌入伏笔建议？还是保持 ChapterElementPanel 只做元素CRUD？

**建议**：T03范围只做元素CRUD接API，伏笔建议面板保持独立（已有 ForeshadowLedgerPanel）。

### 疑问6：guardrailSnapshot端点的novelId参数
原版 `chapter.ts:159-164` 中 `getGuardrailSnapshot(novelId, chapterNumber)` 的第一个参数是 novelId（slug），但 iOS APIEndpoint 中 `guardrailSnapshot(novelId: String, chapterNumber: Int)` 已有。需确认：iOS的novelId是否等于原版的slug？

**确认**：iOS统一用novelId（即原版slug），APIEndpoint已正确。

---

## 事实表覆盖度自报

| 面板 | 原版功能点 | 事实表条目 | 覆盖度 |
|------|-----------|-----------|--------|
| 3.4.1 QualityGuardrailPanel | API 7 + UI 17 = 24 | 30条（含iOS现状6条） | 100% |
| 3.4.2 ConsistencyReportPanel | API 5 + UI 12 = 17 | 24条（含iOS现状7条） | 100% |
| 3.4.3 ChapterElementPanel | API 10 + UI 21 = 31 | 38条（含iOS现状7条） | 100% |
| **合计** | **72** | **92** | **100%** |

### PRD 3.4功能清单对齐

| PRD条目 | 原版行号 | 事实表覆盖 |
|---------|---------|-----------|
| 3.4.1.1 guardrailApi.check() POST端点 | engineCore.ts:133-139 | ✅ #1 |
| 3.4.1.2 GuardrailCheckRequest请求体 | engineCore.ts:100-107 | ✅ #4 |
| 3.4.1.3 GuardrailCheckResponse五维度 | engineCore.ts:126-131 | ✅ #5-7 |
| 3.4.1.4 总分圆形进度条 | QualityGuardrailPanel.vue:44-61 | ✅ #11 |
| 3.4.1.5 六维度条形图 | QualityGuardrailPanel.vue:63-87 | ✅ #12 |
| 3.4.1.6 违规详情折叠列表 | QualityGuardrailPanel.vue:89-120 | ✅ #13 |
| 3.4.1.7 模式选择(advise/enforce) | QualityGuardrailPanel.vue:15-20 | ✅ #9 |
| 3.4.1.8 快照恢复 | QualityGuardrailPanel.vue:227-238 | ✅ #3,#17 |
| 3.4.2.1 ConsistencyReportDTO模型 | workflow.ts:249-253 | ✅ #2 |
| 3.4.2.2 done事件解析 | workflow.ts:453-463 | ✅ #3 |
| 3.4.2.3 issues折叠列表 | ConsistencyReportPanel.vue:13-37 | ✅ #9 |
| 3.4.2.4 warnings折叠列表 | ConsistencyReportPanel.vue:39-59 | ✅ #10 |
| 3.4.2.5 suggestions有序列表 | ConsistencyReportPanel.vue:61-65 | ✅ #11 |
| 3.4.3.1 getElements GET端点 | chapterElement.ts:38-44 | ✅ #1 |
| 3.4.3.2 addElement POST端点 | chapterElement.ts:46-52 | ✅ #2 |
| 3.4.3.3 batchUpdate PUT端点 | chapterElement.ts:54-60 | ✅ #3 |
| 3.4.3.4 deleteElement DELETE端点 | chapterElement.ts:62-67 | ✅ #4 |
| 3.4.3.5 getElementChapters反查 | chapterElement.ts:69-74 | ✅ #5 |
| 3.4.3.6 人物分组列表 | ChapterElementPanel.vue:36-50 | ✅ #14 |
| 3.4.3.7 地点分组列表 | ChapterElementPanel.vue:52-66 | ✅ #15 |
| 3.4.3.8 其他分组列表 | ChapterElementPanel.vue:68-86 | ✅ #16 |
| 3.4.3.9 Bible ID→name映射 | ChapterElementPanel.vue:238-248 | ✅ #23 |
| 3.4.3.10 类型/关系/重要度标签 | chapterElement.ts(domain):8-29 | ✅ #28-30 |

**事实表覆盖度：100%**（PRD 3.4 全部22条原子功能 + 原版72个功能点全覆盖）
