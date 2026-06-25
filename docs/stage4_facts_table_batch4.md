# 阶段4 批次4 事实表（4.7其他收尾）

> 事实表产出人：寇豆码（Kou, software-engineer-2）
> 产出时间：阶段4批次4
> 原则：逐条对齐原版，有疑问上报，不许自作主张简化

---

## 4.7.1 Autopilot章节流改纯SSE（判断是否需要做）

### 原版事实表 - Autopilot轮询+SSE协同设计

原版Vue前端采用 **SSE + 轮询 双轨协同设计**，非"纯SSE"。SSE负责实时章节正文流推送（仅写作阶段），轮询负责全局状态刷新（全阶段）。

| 原版轮询/流 | 原版文件:行号 | 间隔/触发 | 与SSE关系 | 是否合理设计 |
|---|---|---|---|---|
| 状态轮询 fetchStatus() | AutopilotPanel.vue:780-845 | 自适应间隔 getAdaptivePollInterval() | 独立于SSE，全阶段运行 | 是，SSE不覆盖非写作阶段状态 |
| 自适应轮询间隔 getAdaptivePollInterval() | AutopilotPanel.vue:1133-1142 | SSE已连接→pollSseConnectedMs(降频)；运行无SSE→pollRunningMs(高频补偿)；空闲→pollIdleMs；审阅→pollManualReviewMs；AI审阅→pollRequiresAiReviewMs | SSE连接时降低轮询频率，未连接时提高 | 是，SSE+轮询协同退避 |
| useAssistedAutopilotStatus 状态轮询 | useAssistedAutopilotStatus.ts:12-90 | assistedAutopilotPollDelayMs(failureCount) | 独立composable，与chapter SSE分离 | 是，专门处理 /status 轮询退避 |
| assistedAutopilotPollDelayMs 退避算法 | autopilotStatus.ts:112-120 | base=4000ms, max=60000ms, mult=2^min(fc,8) cap 128 | N/A（退避算法本身） | 是，失败退避 |
| 章节SSE流 chapterStream | AutopilotPanel.vue:976-1111 startChapterStream() | 仅写作阶段运行 shouldMaintainChapterStream():930-936 | SSE是事件推送通道 | 是，仅写作阶段需要 |
| statusPollTimer 管理 | AutopilotPanel.vue:424-432, 903-927 | maybeRestartStatusPollTimer() 间隔变化时重置timer | 与SSE独立管理 | 是，轮询和SSE各自生命周期管理 |
| 连接失败退避 statusConnectivityFailures | AutopilotPanel.vue:432, 835, 1140 | 倍增轮询间隔 2^min(fc,8) | 网络断连时轮询退避 | 是，兜底机制 |

**原版设计核心逻辑（AutopilotPanel.vue:1127-1142注释）**：
```
// SSE 已连接时：降频兜底（SSE 已实时驱动刷新，轮询仅防断连漏检）
// SSE 未连接但运行中：较高频补偿 SSE 缺失
// 非运行中：用户可能刚操作，需要快速看到状态变化
// 审阅等待中：用户在看大纲，不需要高频刷新
```

### iOS现状

| iOS轮询/流 | iOS文件:行号 | 间隔/触发 | 对齐原版 | 判断:残留/对齐 |
|---|---|---|---|---|
| Autopilot状态轮询 startStatusPolling | AutopilotStore.swift:278-299 | assistedAutopilotPollDelay(failureCount) 4s-60s自适应退避 | 对齐 useAssistedAutopilotStatus.ts:12-90 + autopilotStatus.ts:112-120 | **对齐** |
| 退避算法 assistedAutopilotPollDelay | AutopilotStore.swift:521-546 | base=4000ms, max=60000ms, mult=2^min(fc,8) cap 128 | 对齐 autopilotStatus.ts:112-120 完全一致 | **对齐** |
| SSE启动后启动轮询 | AutopilotStore.swift:265-266 | SSE启动后立即 startStatusPolling(novelId:) | 对齐 AutopilotPanel.vue:1144-1170 watch→同时管理SSE+轮询 | **对齐** |
| 404停止轮询 stoppedForNotFound | AutopilotStore.swift:311-315 | 404→stoppedForNotFound=true, 停止轮询 | 对齐 useAssistedAutopilotStatus.ts:28-32 | **对齐** |
| AI Invocation轮询 | AIInvocationStore.swift:541-617 | 2000ms硬编码，status==generating时持续 | 对齐 aiInvocationStore.ts:392-461 | **对齐** |
| 写作遥测轮询 | NodeDetailPanel.swift:505-527 | 2500ms，showWritingTelemetry时启动 | 对齐 NodeDetailPanel.vue:216-227 | **对齐** |
| 管线UI tick | StoryPipelineObservabilityView.swift:23-26 | 1.0s Timer，仅刷新停留时间显示 | 对齐 StoryPipelineObservability.vue:132-135 usePolling 1s | **对齐**（UI tick非数据轮询） |
| 伏笔雷达轮询 | ForeshadowRadarView.swift:34-36 | 15.0s Timer，刷新伏笔数据 | 对齐 ForeshadowLedger.vue:271-274 usePolling | **对齐** |

### 结论

- [x] **对齐原版合理设计，不需要改纯SSE（事实表说明）**
- [ ] 有残留，需改（列出残留点）

**判断依据**：
1. 原版Vue前端 AutopilotPanel.vue 本身就是 SSE + 轮询 双轨协同设计，不是"纯SSE"
2. SSE（chapterStream）仅覆盖写作阶段的实时章节正文推送，不覆盖规划/审计/审阅等阶段
3. 轮询（/status）覆盖全阶段状态刷新，含阶段切换、错误状态、审阅闸门等SSE不推送的信息
4. iOS AutopilotStore.swift 的轮询实现有明确注释标注对齐原版文件和行号
5. iOS的退避算法 `assistedAutopilotPollDelay` 与原版 `assistedAutopilotPollDelayMs` 参数完全一致
6. 交接文档v8第6.7节原文"如仍有轮询残留"——经事实表确认，iOS轮询不是残留，是对齐原版的合理设计

**4.7.1 不需要做任何改动。**

---

## 4.7.2 CharacterSchedulerSimulator（Debug工具）

### 原版事实表

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 路由注册 | router/index.ts:9-10, 21-25 | `/debug/scheduler` → lazy import CharacterSchedulerSimulator.vue | 独立路由页面 | N/A |
| ⚠️路由路径修正 | router/index.ts:22 | 实际路径是 `/debug/scheduler`，**非** `/debug/character-scheduler` | — | — |
| 组件标题 | CharacterSchedulerSimulator.vue:3-11 | 无API，纯前端 | "🎯 角色上下文调度模拟器" + 描述（基于 AppearanceScheduler 和 CharacterRegistry） | N/A |
| 控制面板-大纲提及开关 | :22-36 | 无API | 两个toggle: mentionedAda(默认true), mentionedSuQing(默认false) | `ref<boolean>` |
| 控制面板-最大角色数滑块 | :38-55 | 无API | range slider min=1 max=3, 默认2 | `ref<number>` |
| 角色库数据(硬编码) | :222-250 | 无API，纯前端mock | 3个角色卡片grid | `Character[]` interface |
| 角色: 林羽 | :223-231 | — | id=char-001, name=林羽, importance=主角, importanceLevel=protagonist, activityCount=50, mentalState=NORMAL, idleBehavior=摸剑柄 | Character |
| 角色: 艾达 | :232-240 | — | id=char-002, name=艾达, importance=次要角色, importanceLevel=minor, activityCount=1, mentalState=冷漠, idleBehavior=擦拭机械臂 | Character |
| 角色: 苏晴 | :241-249 | — | id=char-003, name=苏晴, importance=主要配角, importanceLevel=major, activityCount=30, mentalState=担忧, idleBehavior=咬嘴唇 | Character |
| 角色卡片渲染 | :66-113 | — | 名称+重要性badge(importanceLevel着色)+活动度+心理状态+待机动作+badges(mentioned/selected/excluded) | — |
| 重要性优先级映射 | :258-262 | — | protagonist=0, major=1, minor=2 | `Record<string, number>` |
| isMentioned判断 | :265-269 | — | 艾达→mentionedAda, 苏晴→mentionedSuQing, 其他→false | — |
| 排序算法 sortedQueue | :272-311 | 无API，computed | 1.分类mentioned/notMentioned 2.notMentioned按importancePriority排序 3.同优先级按activityCount降序 4.合并mentioned+sorted notMentioned | `ComputedRef<(Character & {reason: string})[]>` |
| selectedCharacters | :314-316 | — | sortedQueue.slice(0, maxCharacters) | computed |
| isSelected判断 | :319-321 | — | selectedCharacters.some(c => c.id === char.id) | — |
| isInQueue判断 | :324-326 | — | sortedQueue.some(c => c.id === char.id) | — |
| 调度队列渲染 | :117-144 | — | 每项: rank序号+name+reason+status(入选/超出配额) | — |
| 生成上下文Prompt | :329-347 | 无API，computed | "【角色设定约束】\n\n" + 每角色: 角色/描述/心理状态/待机动作 + activityCount<=1时加连续性约束 | computed string |
| 上下文输出渲染 | :147-161 | — | `<pre>` 显示generatedContext + 统计(选中角色数, 预计Token) | — |
| Token估算 | :350-353 | — | Math.ceil(generatedContext.length / 4) | computed number |
| 算法说明面板 | :164-203 | — | 4步: 1.大纲提及最高优先 2.角色重要性 3.活动度 4.截断策略 | 静态UI |
| Character接口定义 | :212-220 | — | id, name, importance, importanceLevel('protagonist'\|'major'\|'minor'), activityCount, mentalState, idleBehavior | interface |

### iOS现状
- Grep `struct CharacterScheduler|CharacterSchedulerSimulator` → **无匹配，确认缺失**
- Grep `DebugView|debug.*View|/debug` → iOS无debug路由/视图
- iOS导航：SidebarDestination 枚举（AppState.swift:40-89）无debug项；RootView.swift:99-198 switch无debug case
- SidebarView.swift 分组：创作/设定/分析/工具/系统，无debug分组

### 待补内容

1. **CharacterSchedulerSimulatorView.swift** — 纯SwiftUI视图，硬编码3个角色mock数据，实现排序算法+上下文生成+Token估算
2. **导航入口** — 需在 SidebarDestination 增加 `.debug` case + RootView switch case + SidebarView 分组
   - 建议放"工具"分组或新增"调试"分组
3. **数据模型** — Character struct（id, name, importance, importanceLevel, activityCount, mentalState, idleBehavior）
4. **排序算法** — mentioned优先 → importance优先级 → activityCount降序 → 截断
5. **上下文生成** — 格式化字符串 + 连续性约束
6. **Token估算** — ceil(context.count / 4)

**注意**：原版是**纯前端模拟器**，无任何API调用，所有数据硬编码。iOS实现同样纯前端，不需要API端点。

---

## 4.7.3 KnowledgeJsonView（JSON查看mode）

### 原版事实表

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 组件定义 | KnowledgeJsonView.vue:23-30 | props: { slug: string }, emit: ['reload'] | 子组件，被KnowledgePanel.vue:113引用 | — |
| 宿主引用 | KnowledgePanel.vue:113 | `<KnowledgeJsonView v-if="knowledgeView === 'json'" :slug="slug" @reload="reloadKnowledge" />` | knowledgeView === 'json' 时显示 | — |
| knowledgeView切换 | KnowledgePanel.vue:99-108 | 3个按钮: graph/json/triples | n-button-group 切换 knowledgeView ref | `ref<'graph'\|'json'\|'triples'>('graph')` |
| 工具栏-保存按钮 | KnowledgeJsonView.vue:5 | @click="saveJson", :loading="saving" | "保存 JSON" primary button | `ref<boolean>` saving |
| 工具栏-格式化按钮 | KnowledgeJsonView.vue:6 | @click="formatJson" | "格式化" button | — |
| JSON编辑器 | :9-16 | n-input type=textarea, v-model=jsonText, autosize minRows=10 maxRows=20 | placeholder="JSON 数组：与 GET /knowledge 返回的 facts 格式一致" | `ref<string>` jsonText |
| 错误显示 | :17-19 | v-if=jsonError, type=error | 红色错误文本 | `ref<string>` jsonError |
| 数据加载 reload() | :40-51 | `knowledgeApi.getKnowledge(slug)` → 提取 version, premise_lock, chapters, facts | jsonText = JSON.stringify(data.facts \|\| [], null, 2) | storyVersion, premiseLock, chaptersSnapshot |
| 格式化 formatJson() | :53-61 | JSON.parse(jsonText) → JSON.stringify(parsed, null, 2) | 成功→更新jsonText; 失败→jsonError | — |
| 保存 saveJson() | :63-91 | 1.JSON.parse校验 2.校验Array.isArray 3.`knowledgeApi.putKnowledge(slug, {version, premise_lock, chapters, facts: parsed})` 4.emit('reload') 5.reload() | 成功→message.success; 失败→jsonError或message.error | — |
| 事件监听 | :93-104 | window 'plotpilot:knowledge:reload' → reload() | onMounted注册, onUnmounted注销 | — |
| storyVersion | :36 | 从getKnowledge响应提取 data.version ?? 1 | 保存时回传 | `ref<number>` |
| premiseLock | :37 | 从getKnowledge响应提取 data.premise_lock ?? '' | 保存时回传 | `ref<string>` |
| chaptersSnapshot | :38 | 从getKnowledge响应提取 [...data.chapters] | 保存时回传 | `ref<ChapterSummary[]>` |

**API调用链**：
- 加载: `GET /api/v1/novels/{slug}/knowledge` → StoryKnowledge { version, premise_lock, chapters, facts }
- 保存: `PUT /api/v1/novels/{slug}/knowledge` ← { version, premise_lock, chapters, facts }

### iOS现状

| 检查项 | 结果 |
|---|---|
| Grep `KnowledgePanel\|knowledgeView\|knowledgeViewMode` | **无匹配** — iOS无KnowledgePanel宿主，无knowledgeView模式切换 |
| Grep `struct KnowledgeJsonView\|KnowledgeJsonView` | **无匹配** — 确认缺失 |
| Grep `getKnowledge\|putKnowledge\|knowledgeApi` | **无匹配** — iOS无叙事知识API封装 |
| Grep `KnowledgeGraph` (iOS已有) | iOS有 KnowledgeGraphView.swift（图谱视图）、KnowledgeGraphStore.swift、TriplesTableView.swift、InferenceEvidenceView.swift — 但这些是知识图谱(triples)相关，非叙事知识(narrative knowledge) |
| iOS APIEndpoint 查 `/novels/{id}/knowledge` | **无此端点** — iOS仅有 `/knowledge-graph/novels/{id}/triples` 等知识图谱端点，缺少 `GET/PUT /novels/{id}/knowledge` 叙事知识端点 |
| iOS StoryKnowledge 模型 | **已存在** — KnowledgeGraphModels.swift:177-195, 含 version/premiseLock/chapters/facts 字段，与原版 StoryKnowledge 接口对齐 |
| iOS ChapterSummaryDTO 模型 | **已存在** — KnowledgeGraphModels.swift:140-172 |

### 待补内容

1. **KnowledgeJsonView.swift** — JSON编辑子组件
   - 工具栏：保存按钮(loading状态) + 格式化按钮
   - TextEditor/TextField：JSON文本编辑
   - 错误提示
   - 加载逻辑：调用叙事知识API获取 → 提取facts → JSON序列化显示
   - 格式化：JSON解析 → 重新序列化
   - 保存：校验数组 → 调用PUT API → 回调reload

2. **⚠️ 前置依赖缺失（需主理人决策）**：
   - iOS缺少 `GET/PUT /novels/{id}/knowledge` 叙事知识API端点（APIEndpoint.swift 无此端点）
   - iOS缺少 KnowledgePanel 宿主视图（原版 KnowledgePanel.vue 有 search/narrative/graph 三Tab + knowledgeView graph/json/triples 切换）
   - KnowledgeJsonView 是 KnowledgePanel 的子组件，单独建出后无宿主嵌入

---

## 4.7.4 单元测试

### iOS现状

| 检查项 | 结果 |
|---|---|
| Grep `XCTestCase\|XCTest\|@Test\|import XCTest` | **无匹配** — 全项目零测试代码 |
| Glob `**/*Test*` | **无匹配** — 无测试文件 |
| Glob `**/*test*` | **无匹配** — 无测试文件 |
| project.yml 测试target | **无测试target** — 仅有 `Cangjie` application target，无 `CangjieTests` test target |
| 测试基础设施 | **完全空白** — 无测试target、无测试文件、无测试工具配置 |

### 建议

**当前状态：零测试覆盖，无测试target。**

**分析**：
1. 项目是Vue→iOS移植项目，当前阶段（阶段4批次4）是收尾阶段
2. 前序批次1+2+3已全部QA通过（对齐度100%），均通过人工对齐验证而非自动化测试
3. 添加测试target需要修改 project.yml（xcodegen配置），增加 CangjieTests target
4. 项目铁律：零新SPM依赖（仅KeychainAccess 4.2.2），XCTest是系统框架不需SPM依赖

**建议分两档**：

**档1（推荐，本批次执行）**：不新增测试target，保持现状
- 理由：移植项目以功能对齐为验收标准，前序批次均通过人工QA验证
- 批次4是收尾批次，复杂度低，新增测试target的投入产出比低
- 如需测试，建议作为独立阶段统一规划

**档2（可选，如主理人要求）**：新增最小测试target + 少量关键算法测试
- 修改 project.yml 增加 CangjieTests target
- 测试重点：
  - `assistedAutopilotPollDelay(failureCount:)` 退避算法（AutopilotStore.swift:543-546）
  - CharacterSchedulerSimulator 排序算法（如4.7.2实现）
  - CangjieDecoder 日期解码（微秒6位处理）
  - SSEEvent.decodeAsDictionary() 字典解析
- 预计4-6个测试文件

---

## 疑问清单（上报主理人决策）

| # | 疑问 | 选项 | 我的建议 |
|---|---|---|---|
| Q1 | 4.7.3 KnowledgeJsonView 的宿主和API端点缺失 | A) 仅建KnowledgeJsonView.swift子组件，API端点和宿主面板留待后续批次 B) 本批次同时补建 KnowledgePanel宿主 + API端点 + KnowledgeJsonView C) 跳过4.7.3，标记为"需宿主先行" | **A** — 本批次仅补子组件，API调用用预留接口（后续补端点时接入）。KnowledgeJsonView设计为接收slug参数+reload回调的独立View，内部通过APIClient调用 `/novels/{slug}/knowledge`（端点需补到APIEndpoint.swift）。建议本批次同时补API端点定义（GET/PUT），但不建完整KnowledgePanel宿主 |
| Q2 | 4.7.2 CharacterSchedulerSimulator 的导航入口方式 | A) 在SidebarDestination新增 `.debug` case，加入侧边栏 B) 在某个现有页面（如设置页）加NavigationLink跳转 C) 不加入导航，仅作为独立View文件供后续接入 | **A** — 新增 `.debug` case 放"工具"分组，icon用 "ladybug.fill"。原版有独立路由 `/debug/scheduler`，iOS应对齐为独立侧边栏入口 |
| Q3 | 4.7.2 原版路由路径 `/debug/scheduler` vs 任务描述 `/debug/character-scheduler` | 任务描述写的是 `/debug/character-scheduler`，但原版 router/index.ts:22 实际是 `/debug/scheduler` | 以原版事实为准 `/debug/scheduler`，任务描述有误 |
| Q4 | 4.7.4 单元测试是否本批次执行 | A) 不执行，保持现状 B) 执行，新增测试target+少量测试 | **A** — 移植项目以功能对齐为验收标准，测试建议作为独立阶段统一规划 |
| Q5 | 4.7.3 iOS缺少 `GET/PUT /novels/{id}/knowledge` 端点定义，是否本批次补到APIEndpoint.swift | A) 补端点定义，KnowledgeJsonView可直接调用 B) 不补，KnowledgeJsonView预留接口注释 | **A** — 端点定义是纯静态代码（path字符串+HTTP method），无副作用，补上后KnowledgeJsonView可直接功能完整 |

---

## 总结

| 子项 | 判断 | 行动 |
|---|---|---|
| 4.7.1 Autopilot改纯SSE | **不需要做** — iOS轮询是对齐原版的合理设计，非残留 | 事实表说明即可 |
| 4.7.2 CharacterSchedulerSimulator | **需要做** — iOS确认缺失 | 建CharacterSchedulerSimulatorView.swift + 导航入口 |
| 4.7.3 KnowledgeJsonView | **需要做** — iOS确认缺失 | 建KnowledgeJsonView.swift + 补API端点定义（Q1/Q5待确认） |
| 4.7.4 单元测试 | **建议不做** — 零测试基础设施，建议独立阶段规划 | 评估建议（Q4待确认） |
