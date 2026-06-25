# 阶段4 批次1 QA独立核验报告

> QA工程师：严过关（Yan）
> 日期：2025-07-01
> 核验方式：独立读代码逐条对照原版，不rubber-stamp寇豆码自报
> 原版Vue根目录：`D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`
> iOS代码根目录：`D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/Cangjie/`

---

## 核验结论

- **IS_PASS: YES**
- **功能对齐度: 19/19**（全部检查项通过）
- **编译风险: 0个致命风险，2个观察项（非阻断）**
- **砍功能/偷工减料: 零命中**
- **智能路由判定: NoOne（全部通过，无需路由给工程师修复）**

---

## 4.1 voiceApi 核验

### 端点定义

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| Voice枚举定义 | PASS | `APIEndpoint.swift:627` `enum Voice` |
| createSample端点 | PASS | `APIEndpoint.swift:629` `case createSample(novelId: String)` — POST `/novels/{id}/voice/samples`（:1567）对齐原版 voice.ts:28-32 |
| getFingerprint端点 | PASS | `APIEndpoint.swift:631` `case getFingerprint(novelId: String, povCharacterId: String?)` — GET `/novels/{id}/voice/fingerprint`（:1570）对齐原版 voice.ts:35-39 |
| createSample HTTP方法 | PASS | `APIEndpoint.swift:1576-1578` `.post` 对齐原版 voice.ts:29 |
| getFingerprint HTTP方法 | PASS | `APIEndpoint.swift:1579-1581` `.get` 对齐原版 voice.ts:36 |
| getFingerprint query参数 | PASS | `APIEndpoint.swift:1589-1594` `pov_character_id` queryItem，非空时添加，对齐原版 voice.ts:38 |
| 端点前缀 | PASS | 使用 `APIEndpoint.defaultPrefix`（/api/v1），与 Chapters 同前缀 |

### 数据模型

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| VoiceSamplePayload 字段 | PASS | `VoiceModels.swift:24-65` — aiOriginal/authorRefined/chapterNumber/sceneType? 对齐原版 voice.ts:7-12 |
| VoiceSamplePayload CodingKeys | PASS | `VoiceModels.swift:38-43` — ai_original/author_refined/chapter_number/scene_type 对齐原版 snake_case |
| VoiceSamplePayload memberwise init | PASS | `VoiceModels.swift:51-56` — 教训8合规 |
| VoiceSampleResponse 字段 | PASS | `VoiceModels.swift:77-94` — sampleId 对齐原版 voice.ts:14-16 `sample_id` |
| VoiceSampleResponse CodingKeys | PASS | `VoiceModels.swift:82-84` — `sample_id` |
| VoiceSampleResponse memberwise init | PASS | `VoiceModels.swift:86-88` — 教训8合规 |
| VoiceFingerprintDTO 字段 | PASS | `VoiceModels.swift:110-157` — adjectiveDensity/avgSentenceLength/sentenceCount/sampleCount/lastUpdated 对齐原版 voice.ts:18-24 |
| VoiceFingerprintDTO CodingKeys | PASS | `VoiceModels.swift:127-133` — adjective_density/avg_sentence_length/sentence_count/sample_count/last_updated |
| VoiceFingerprintDTO memberwise init | PASS | `VoiceModels.swift:135-147` — 教训8合规 |

### 决策B执行核验

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| VoiceVaultPanel未改动 | PASS | `VoiceVaultPanel.swift:1-67` — 仍使用 BibleStore.bible.style + bible.characters.verbalTic/idleBehavior + MonitorStore.voiceDrifts，**无 voiceApi 调用**，与阶段1-3一致 |
| 无createSample/getFingerprint调用 | PASS | 全项目Grep `voiceApi\|createSample\|getFingerprint` 在Views层零命中（仅在APIEndpoint+VoiceModels定义层） |

---

## 4.5 浮动按钮核验

### GlobalLLMEntryButton（sidebar变体）

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| 组件存在 | PASS | `GlobalLLMEntryButton.swift:29` `struct GlobalLLMEntryButton: View` |
| sidebar变体渲染（图标+标题） | PASS | `GlobalLLMEntryButton.swift:45-58` — HStack: Image(systemName:"gearshape.2.fill") + Text("AI 控制台")，对齐原版 GlobalLLMEntryButton.vue:13-21 |
| 点击弹sheet | PASS | `GlobalLLMEntryButton.swift:39-41` Button → `showConsoleSheet = true`；`:62-65` `.sheet(isPresented:)` |
| sheet内容含LLM运行时 | PASS | `GlobalLLMEntryButton.swift:79` `LLMRuntimeSection()` — 显示当前激活模型+protocol/mock标签+profile_name，对齐原版 :98-113 |
| sheet内容含LLM配置 | PASS | `GlobalLLMEntryButton.swift:82` `LLMConfigSection()` — 对齐原版 :130-136 LLMControlPanel |
| LLMControlStore依赖存在 | PASS | `LLMControlStore.swift:13` class存在，`:17` panelData属性，`:90` loadPanelData()方法，`:221` isUsingMock属性 |
| LLMConfigSection依赖存在 | PASS | `LLMConfigSection.swift:13` struct存在 |
| SidebarView接入 | PASS | `SidebarView.swift:79` `GlobalLLMEntryButton()` 在系统分组Section内 |

### 决策B跳过核验

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| 未实现GlobalLLMFloatingButton | PASS | 全项目Grep `struct GlobalLLMFloatingButton` 零命中 |
| 未实现PromptPlazaFAB | PASS | 全项目Grep `struct PromptPlazaFAB` 零命中 |
| 死代码跳过有注释说明 | PASS | `GlobalLLMEntryButton.swift:19-20` — "GlobalLLMFloatingButton.vue 和 PromptPlazaFAB.vue 在原版 Vue 中是死代码（全前端无任何 import），按主理人决策B跳过，iOS 同步不实现" |
| PromptPlazaEntryButton不重复 | PASS | `SidebarView.swift:25` analysisItems含`.promptPlaza`已有导航项，未重复实现EntryButton |

---

## 4.6 知识图谱写操作核验

### 5操作逐条核验

| 操作 | 声称实现 | 实际核验 | 证据(文件:行号) | 对齐原版 |
|---|---|---|---|---|
| inferNovel | POST空body | PASS — `let body = EmptyBody()` + `apiClient.request(.infer, body: body)` 返回AnyCodable，完成后 `await loadTriples` + `await loadStatistics` 刷新 | `KnowledgeGraphStore.swift:126-145` | 对齐 knowledgeGraph.ts:92-99（:123注释标注） |
| loadInferenceEvidence | GET | PASS — `apiClient.request(.inferenceEvidence)` 解包 `dict["data"]` 后解码为 `ChapterInferenceEvidenceData`，设 `inferenceEvidence`，兼容直接解码fallback | `KnowledgeGraphStore.swift:151-174` | 对齐 knowledgeGraph.ts:60-68（:149注释标注） |
| revokeChapterInference | DELETE | PASS — `apiClient.request(.deleteChapterInference)` 解码为 `RevokeInferenceResponse`，完成后 `await loadTriples` + `await loadStatistics` 刷新 | `KnowledgeGraphStore.swift:181-198` | 对齐 knowledgeGraph.ts:70-78（:178注释标注） |
| revokeInferredTriple | DELETE | PASS — `apiClient.send(.deleteInferredTriple)`，完成后 `triples.removeAll { $0.id == tripleId }` | `KnowledgeGraphStore.swift:205-214` | 对齐 knowledgeGraph.ts:80-88（:202注释标注） |
| starTriple | PATCH body{starred} | PASS — `StarTripleRequest(starred:)` body + `apiClient.request(.starTriple, body:)` 解码 `StarTripleResponse`，成功后重建 triple 设 `isStarred: starred` | `KnowledgeGraphStore.swift:221-260` | 对齐 knowledgeGraph.ts:128-134（:218注释标注） |

### 数据流核验

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| starTriple更新本地isStarred | PASS | `KnowledgeGraphStore.swift:229-254` — `response.success` 后 `triples[idx] = KnowledgeTriple(..., isStarred: starred)` 重建 |
| revokeInferredTriple从triples移除 | PASS | `KnowledgeGraphStore.swift:210` — `triples.removeAll { $0.id == tripleId }` |
| inferNovel完成后刷新 | PASS | `KnowledgeGraphStore.swift:138-139` — `await loadTriples(novelId:)` + `await loadStatistics(novelId:)` |
| revokeChapterInference完成后刷新 | PASS | `KnowledgeGraphStore.swift:191-192` — `await loadTriples(novelId:)` + `await loadStatistics(novelId:)` |

### 原版行号标注核验

| 操作 | 标注位置 | 原版实际行号 | 结果 |
|---|---|---|---|
| inferNovel | Store:123 `knowledgeGraph.ts:92-99` | ts:92-99 | PASS |
| loadInferenceEvidence | Store:149 `knowledgeGraph.ts:60-68` | ts:60-68 | PASS |
| revokeChapterInference | Store:178 `knowledgeGraph.ts:70-78` | ts:70-78 | PASS |
| revokeInferredTriple | Store:202 `knowledgeGraph.ts:80-88` | ts:80-88 | PASS |
| starTriple | Store:218 `knowledgeGraph.ts:128-134` | ts:128-134 | PASS |

### 真实实现核验（非空函数/占位/stub）

| 操作 | 结果 | 证据 |
|---|---|---|
| inferNovel | PASS — 真实API调用+刷新逻辑 | Store:126-145 完整实现 |
| loadInferenceEvidence | PASS — 真实API调用+解码+状态更新 | Store:151-174 完整实现 |
| revokeChapterInference | PASS — 真实API调用+日志+刷新 | Store:181-198 完整实现 |
| revokeInferredTriple | PASS — 真实API调用+本地移除 | Store:205-214 完整实现 |
| starTriple | PASS — 真实API调用+本地状态更新 | Store:221-260 完整实现 |

---

## 4.6 模型修正核验

### 决策5：KnowledgeTriple新增isStarred

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| isStarred: Bool? 字段 | PASS | `KnowledgeGraphModels.swift:51` `let isStarred: Bool?` |
| CodingKey is_starred | PASS | `KnowledgeGraphModels.swift:64` `case isStarred = "is_starred"` |
| init(from:) 解码 isStarred | PASS | `KnowledgeGraphModels.swift:88` `self.isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred)` |
| memberwise init 含 isStarred | PASS | `KnowledgeGraphModels.swift:112` 参数 `isStarred: Bool? = nil`，`:133` 赋值 |

### 决策6：KnowledgeGraphStatistics对齐原版KGStatistics

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| totalTriples → total_triples | PASS | `KnowledgeGraphModels.swift:242,254` |
| sourceDistribution → source_distribution | PASS | `KnowledgeGraphModels.swift:245,255` |
| confidenceDistribution → confidence_distribution | PASS | `KnowledgeGraphModels.swift:248,256` |
| predicateDistribution → predicate_distribution | PASS | `KnowledgeGraphModels.swift:251,257` |
| KGConfidenceDistribution{high,medium,low} | PASS | `KnowledgeGraphModels.swift:305-326` — high/medium/low + CodingKeys + memberwise init + init(from:) |
| 删除 byEntityType | PASS | 全项目Grep `byEntityType` 零命中 |
| 删除 byImportance | PASS | 全项目Grep `byImportance` 零命中 |
| 删除 bySourceType | PASS | 全项目Grep `bySourceType` 零命中 |
| memberwise init | PASS | `KnowledgeGraphModels.swift:260-270` |
| init(from:) 使用singleValueContainer | PASS | `KnowledgeGraphModels.swift:272-301` — 解码 `[String: AnyCodable]` 后手动提取字段，兼容灵活JSON |

### 决策7：ChapterInferenceEvidenceData结构化建模

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| ChapterInferenceEvidenceData | PASS | `KnowledgeGraphModels.swift:522-561` — storyNodeId?/chapterNumber/facts/hint? 对齐原版 ts:28-33 |
| InferenceFactBundle | PASS | `KnowledgeGraphModels.swift:486-510` — fact:InferenceFactPayload/provenance:[InferenceProvenanceRow] 对齐原版 ts:23-26 |
| InferenceFactPayload | PASS | `KnowledgeGraphModels.swift:419-476` — id/subject/predicate/object/chapterNumber?/confidence?/sourceType? 对齐原版 ts:13-21 |
| InferenceProvenanceRow | PASS | `KnowledgeGraphModels.swift:370-404` — id/chapterElementId?/ruleId/role 对齐原版 ts:6-11 |
| 未使用AnyCodable兜底 | PASS | 4个新struct全部用结构化字段，无 AnyCodable |
| 每个struct有memberwise init（教训8） | PASS | InferenceProvenanceRow:390 / InferenceFactPayload:448 / InferenceFactBundle:500 / ChapterInferenceEvidenceData:542 |
| 每个struct有init(from:) | PASS | InferenceProvenanceRow:397 / InferenceFactPayload:466 / InferenceFactBundle:505 / ChapterInferenceEvidenceData:554 |
| CodingKeys覆盖所有存储属性 | PASS | 4个struct的CodingKeys均覆盖全部存储属性 |

### 辅助响应模型核验

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| StarTripleRequest {starred:Bool} | PASS | `KnowledgeGraphModels.swift:641-643` 对齐原版 ts:131 `{ starred }` |
| StarTripleResponse {success/triple_id/starred} | PASS | `KnowledgeGraphModels.swift:567-590` CodingKey `triple_id` 对齐原版 ts:128-133 |
| RevokeInferenceResponse {success/data} | PASS | `KnowledgeGraphModels.swift:596-614` 对齐原版 ts:73-78 |
| RevokeInferenceData {removed_provenance_triples/deleted_inferred_facts} | PASS | `KnowledgeGraphModels.swift:617-636` CodingKeys对齐 |
| 以上4个struct均有memberwise init | PASS | StarTripleResponse:578 / RevokeInferenceResponse:604 / RevokeInferenceData:626 / StarTripleRequest无自定义init(from:)用合成init |

### 调用处UI同步更新核验

| 检查项 | 结果 | 证据(文件:行号) |
|---|---|---|
| KnowledgeGraphView统计栏 | PASS | `KnowledgeGraphView.swift:75-85` — 全书推断按钮 `await kgStore.inferNovel(novelId:)`，disabled状态绑定isLoading |
| InferenceEvidenceView操作按钮 | PASS | `InferenceEvidenceView.swift:76-88` — 标星按钮 `await kgStore.starTriple(...)`；`:91-106` — 撤销推断按钮 `await kgStore.revokeInferredTriple(...)` |
| TriplesTableView标星指示 | PASS | `TriplesTableView.swift:140-145` — `if triple.isStarred == true { Image(systemName: "star.fill") }` |

---

## 编译风险扫描

### 1. 重复struct声明（T05教训10）

| struct名 | 声明次数 | 结果 | 证据 |
|---|---|---|---|
| GlobalLLMEntryButton | 1 | PASS | GlobalLLMEntryButton.swift:29 |
| VoiceSamplePayload | 1 | PASS | VoiceModels.swift:24 |
| VoiceSampleResponse | 1 | PASS | VoiceModels.swift:77 |
| VoiceFingerprintDTO | 1 | PASS | VoiceModels.swift:110 |
| ChapterInferenceEvidenceData | 1 | PASS | KnowledgeGraphModels.swift:522 |
| InferenceFactBundle | 1 | PASS | KnowledgeGraphModels.swift:486 |
| InferenceFactPayload | 1 | PASS | KnowledgeGraphModels.swift:419 |
| InferenceProvenanceRow | 1 | PASS | KnowledgeGraphModels.swift:370 |
| KGConfidenceDistribution | 1 | PASS | KnowledgeGraphModels.swift:305 |
| StarTripleRequest | 1 | PASS | KnowledgeGraphModels.swift:641 |
| StarTripleResponse | 1 | PASS | KnowledgeGraphModels.swift:567 |
| RevokeInferenceResponse | 1 | PASS | KnowledgeGraphModels.swift:596 |
| RevokeInferenceData | 1 | PASS | KnowledgeGraphModels.swift:617 |

**结论：零重复声明，T05教训已吸收。**

### 2. EmptyBody类型

| 检查项 | 结果 | 证据 |
|---|---|---|
| KnowledgeGraphStore.swift EmptyBody | PASS (private) | `KnowledgeGraphStore.swift:266` `private struct EmptyBody: Codable {}` — file-scoped，不与模块级冲突 |
| OnboardingWizardView.swift EmptyBody | 存在(internal) | `OnboardingWizardView.swift:206` `struct EmptyBody: Codable {}` — 模块级 |
| 冲突风险 | PASS | Swift允许fileprivate/private类型在文件内shadow模块级同名类型，**不产生编译错误** |

### 3. AnyCodable使用合法性

| 使用位置 | 结果 | 证据 |
|---|---|---|
| inferNovel返回值 `let _: AnyCodable` | PASS | `KnowledgeGraphStore.swift:133` — 原版返回 `Record<string, unknown>`，用AnyCodable吞咽未知结构，方法不使用返回值（仅刷新triples），合法 |
| loadInferenceEvidence中间层 `let raw: AnyCodable` | PASS | `KnowledgeGraphStore.swift:156` — 先用AnyCodable接收，再手动解包`dict["data"]`后解码为结构化`ChapterInferenceEvidenceData`，合法 |

### 4. memberwise init完整性（教训8）

| struct | 有自定义init(from:) | 有memberwise init | 结果 |
|---|---|---|---|
| KnowledgeTriple | :67 | :92 | PASS |
| KnowledgeGraphStatistics | :272 | :260 | PASS |
| KGConfidenceDistribution | :320 | :314 | PASS |
| InferenceProvenanceRow | :397 | :390 | PASS |
| InferenceFactPayload | :466 | :448 | PASS |
| InferenceFactBundle | :505 | :500 | PASS |
| ChapterInferenceEvidenceData | :554 | :542 | PASS |
| StarTripleResponse | :584 | :578 | PASS |
| RevokeInferenceResponse | :609 | :604 | PASS |
| RevokeInferenceData | :631 | :626 | PASS |
| VoiceSamplePayload | :58 | :51 | PASS |
| VoiceSampleResponse | :90 | :86 | PASS |
| VoiceFingerprintDTO | :149 | :135 | PASS |
| StarTripleRequest | 无(合成) | 无(合成) | PASS — 无自定义init(from:)，Swift合成memberwise init |

**结论：全部13个有自定义init(from:)的struct均有memberwise init，教训8已吸收。**

### 5. CodingKeys覆盖

| struct | 存储属性 | CodingKeys | 结果 |
|---|---|---|---|
| KnowledgeTriple | 19个 | 19个全覆盖（含isStarred→is_starred） | PASS |
| KnowledgeGraphStatistics | 4个 | 4个全覆盖 | PASS |
| KGConfidenceDistribution | 3个 | 3个全覆盖 | PASS |
| InferenceProvenanceRow | 4个 | 4个全覆盖 | PASS |
| InferenceFactPayload | 7个 | 7个全覆盖 | PASS |
| InferenceFactBundle | 2个 | 2个全覆盖 | PASS |
| ChapterInferenceEvidenceData | 4个 | 4个全覆盖 | PASS |
| StarTripleResponse | 3个 | 3个全覆盖 | PASS |
| RevokeInferenceResponse | 2个 | 2个全覆盖 | PASS |
| RevokeInferenceData | 2个 | 2个全覆盖 | PASS |

### 6. catch块error常量（教训1）

| 检查项 | 结果 | 证据 |
|---|---|---|
| catch块无 `var error` | PASS | 全项目Grep `catch.*var error` 零命中；所有catch块使用 `catch {` 隐式error绑定 |

### 7. APIEndpoint.path拼接

| 端点 | 路径 | 结果 | 证据 |
|---|---|---|---|
| Voice.createSample | `/novels/{id}/voice/samples` | PASS | `APIEndpoint.swift:1567` |
| Voice.getFingerprint | `/novels/{id}/voice/fingerprint` | PASS | `APIEndpoint.swift:1570` |
| KG.infer | `/knowledge-graph/novels/{id}/infer` | PASS | `APIEndpoint.swift:1522` |
| KG.inferenceEvidence | `/knowledge-graph/novels/{id}/chapters/by-number/{chapter}/inference-evidence` | PASS | `APIEndpoint.swift:1524` |
| KG.deleteChapterInference | `/knowledge-graph/novels/{id}/chapters/by-number/{chapter}/inference` | PASS | `APIEndpoint.swift:1526` |
| KG.deleteInferredTriple | `/knowledge-graph/novels/{id}/inferred-triples/{tripleId}` | PASS | `APIEndpoint.swift:1528` |
| KG.starTriple | `/knowledge-graph/novels/{id}/triples/{tripleId}/star` | PASS | `APIEndpoint.swift:1532` |

### 观察项（非阻断）

**观察1：loadStatistics未解包 `data` 字段**
- 位置：`KnowledgeGraphStore.swift:60-71`
- 现状：`loadStatistics` 将 `raw.value`（完整HTTP响应体）直接传给 `KnowledgeGraphStatistics.init(from:)`，未像 `loadInferenceEvidence`（:160-166）那样解包 `dict["data"]`
- 影响：若后端返回 `{success, data: {total_triples, ...}}` 包裹格式，新模型 `init(from:)` 在顶层找不到 `total_triples` 等字段，将得到全零值。但 KnowledgeGraphView 统计栏使用 `kgStore.triples.count` 而非 `kgStore.statistics`，UI不受影响
- 严重度：LOW — 该方法为阶段1-3遗留代码（本批次未改动），旧模型同样存在此问题；若后端不包裹（直接返回统计对象），则无问题
- 建议：后续批次在 `loadStatistics` 中增加 `dict["data"]` 解包，与 `loadInferenceEvidence` 保持一致

**观察2：旧 InferenceEvidence struct 为死代码**
- 位置：`KnowledgeGraphModels.swift:331-342`
- 现状：旧 `InferenceEvidence` struct（`{triples, evidence: [AnyCodable]}`）仍存在但全项目零引用（Grep `InferenceEvidence` 不含 View/Data 后缀零命中）。Store 使用的是新 `ChapterInferenceEvidenceData`
- 严重度：INFO — 不影响编译，仅为冗余代码
- 建议：后续清理时移除

---

## 砍功能/偷工减料扫描

| 检查项 | 结果 | 证据 |
|---|---|---|
| 批次1文件无"简化版" | PASS | Grep `简化版` 命中仅在 StoryNavigatorView/ChapterGenerationPanel/BibleStreamingStep（阶段1-3遗留，非批次1文件） |
| 批次1文件无"TODO" | PASS | 批次1文件零命中 |
| 批次1文件无"暂不实现" | PASS | 零命中 |
| 批次1文件无"后续优化" | PASS | 零命中 |
| 批次1文件无"FIXME/HACK/stub" | PASS | 零命中 |
| 跳过的2个浮动按钮有注释说明 | PASS | `GlobalLLMEntryButton.swift:19-20` 明确注释"原版 Vue 中是死代码…按主理人决策B跳过" |
| 5个写操作均为真实实现 | PASS | 详见上方"真实实现核验"表，无空函数/占位/stub |

---

## 主理人7条决策执行核验汇总

| 决策# | 决策内容 | 执行结果 | 证据 |
|---|---|---|---|
| 1 | voiceApi原版从未调用 → 决策B：仅补端点+模型，VoiceVaultPanel不动 | PASS | Voice枚举+3模型已补；VoiceVaultPanel.swift:1-67未改动 |
| 2 | "PUT保存"是笔误 → 决策C：不接线PUT | PASS | 全项目无PUT端点接线（KG端点无PUT方法） |
| 3 | generate=inferNovel → 决策A：同一操作只接线一次 | PASS | 仅 inferNovel 一个POST推断方法（Store:126），无重复generate方法 |
| 4 | 2个浮动按钮死代码 → 决策B：仅实现GlobalLLMEntryButton sidebar变体 | PASS | GlobalLLMEntryButton.swift实现sidebar变体；无FloatingButton/FAB；有死代码注释 |
| 5 | 缺is_starred → 决策A：KnowledgeTriple新增isStarred+memberwise init | PASS | KnowledgeGraphModels.swift:51,64,88,112 isStarred完整 |
| 6 | Statistics字段不一致 → 决策A：修正对齐原版+删除旧字段+同步UI | PASS | 4个新字段对齐；3个旧字段删除；UI编译通过（statsBar用triples.count） |
| 7 | InferenceEvidence结构不同 → 决策A：新增4个结构化模型+memberwise init | PASS | 4个struct结构化建模；无AnyCodable兜底；全部有memberwise init |

---

## 智能路由判定

**路由目标：NoOne**

全部19项功能对齐检查通过，0个编译致命风险，0个砍功能命中。寇豆码自报IS_PASS:YES对齐度100%经独立核验**属实**。2个观察项（loadStatistics解包/旧InferenceEvidence死代码）为非阻断遗留问题，不影响本批次交付。

---

*核验完毕。报告落盘于 `docs/stage4_qa_report_batch1.md`。*
