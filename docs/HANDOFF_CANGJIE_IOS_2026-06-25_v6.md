# 仓颉 iOS 移植项目交接文档 v6（终极版，下一任AI读完即可接手）

> **交接日期**：2026-06-25 01:20（v5 → v6 升级，因积分耗尽提前交接）
> **交接人**：齐活林（Qi）· 交付总监（第四任主理人）
> **状态**：阶段1+2+3(P0+T03)已完成并编译通过，**T04+T05待推进**
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜瞎改。本文件是唯一权威交接，读完即可接手。**用户特别交代：所有东西都要写清楚，防止下一个AI一知半解瞎几把改。**
> **v5 → v6 变更**：T03完成（CI#25 success）；补充所有最新状态+完整启动指令+所有决策+所有教训

---

## ⚡ 下一任AI接手速查（先读这段）

### 你要做什么
继续推进阶段3的 **T04（DAG节点交互+题材包接API）** 和 **T05（六面板全CRUD）**。都是P2优先级。

### 你要做之前先读（按顺序）
1. **本交接文档v6**（你现在在读）
2. `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`（防砍6道机制，铁律）
3. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md`（阶段3的T04/T05范围）
4. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md`（157条功能清单，T04/T05在3.3+3.5+3.6部分）
5. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md`（157条契约表+5任务分解，T04/T05的契约表在3.3+3.5+3.6部分）

### 工作流（标准SOP，严格按防砍6道机制）
```
T04/T05各走：工程师读原版输出事实表(机制1) → 主理人确认 → 工程师实现标注原版行号(机制4)+6铁律(机制6) → QA独立验收(机制5) → 主理人push+盯CI
```
PRD和系统设计已经完成（许清楚+高见远做过了），不用重做。直接从工程师读原版开始。

### 团队已存在
团队名 `software-cangjie-stage3`，4个成员都spawn过（idle状态）：
- 许清楚（software-product-manager）— PRD已完成
- 高见远（software-architect）— 系统设计已完成
- 寇豆码（software-engineer）— P0+T03已完成，可继续派T04/T05
- 严过关（software-qa-engineer）— P0+T03验收完成，可继续派T04/T05验收

**如果团队已不存在（会话重启），主理人重新TeamCreate(team_name: "software-cangjie-stage3")再spawn成员。**

---

## 一、项目身份

- **名称**：仓颉（CangJie），PlotPilot v4.6.0 的 iOS SwiftUI 移植客户端
- **仓库**：https://github.com/Da-AiXZ/CangJie
- **架构**：云端后端（PlotPilot Python/FastAPI 原项目零改动，已部署）+ SwiftUI 原生瘦客户端 + TrollStore 侧载 + GitHub Actions 编译
- **技术栈**：SwiftUI（iOS 16+，ObservableObject + @Published）、URLSession async、自实现 SSE、Swift Charts、纯 Swift Canvas 图形、仅 KeychainAccess 4.2.2 SPM 依赖
- **用户设备**：iPad Pro 2021 (M1), iOS 16.6.1, TrollStore 侧载

---

## 二、关键路径（CRITICAL — 所有代码操作都在这些路径下）

| 项目 | 路径 |
|------|------|
| **仓颉代码** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/Cangjie/` |
| **原版 Vue 前端（移植基准）** | `D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/` |
| **当前会话工作目录** | `D:/111/2026-06-24-22-39-38`（空目录，实际代码不在） |
| **防砍约束方法** | `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md` |
| **阶段补齐核验清单** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md` |
| **阶段3 PRD（157条）** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md` |
| **阶段3系统设计（157契约表+5任务）** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md` |
| **P0事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_p0.md` |
| **P0 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_p0.md` |
| **T03事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_t03.md` |
| **T03 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_t03.md` |
| **历史交接文档v3** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/HANDOFF_CANGJIE_IOS_2026-06-24_v3.md` |
| **历史交接文档v4** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/HANDOFF_CANGJIE_IOS_2026-06-24_v4.md` |
| **历史交接文档v5** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/HANDOFF_CANGJIE_IOS_2026-06-25_v5.md` |
| **阶段2系统设计** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage2_system_design.md` |
| **阶段2 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段2QA独立验收报告_2026-06-24.md` |
| **审计报告1（差异）** | `C:/Users/netease/Desktop/仓颉iOS移植版差异审计报告.md` |
| **审计报告2（深度）** | `C:/Users/netease/Desktop/仓颉iOS已实现功能对齐深度审计.md` |
| **项目记忆** | `D:/111/2026-06-24-22-39-38/.workbuddy/memory/2026-06-24.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-24-22-39-38`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：见项目memory或环境变量（**不要写进交接文档明文**，GitHub secret scanning会拦截push）
- remote URL 格式：`https://x-access-token:<TOKEN>@github.com/Da-AiXZ/CangJie.git`
- **教训**：交接文档v3/v4曾把token明文写入，导致push被GitHub secret scanning拦截，已用sed替换为占位符并amend commit。**下一任绝对不要在文档里写token明文。**

---

## 四、当前完成状态（2026-06-25 01:20）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）

73项功能点全实现+QA返工通过。Bible SSE分3步stage+13类SSE事件+Autopilot chapter-stream 9类事件+workbench单章生成SSE+onStreamEnd回调+approval_required/error/done显式cancel SSE。

### ✅ 阶段2已完成（commit 043b402，CI #22编译通过）

6项全PASS，164/164=100%对齐度。CircuitBreaker字段+BibleStatus/Feedback字段+提示词广场17模型23API+Autopilot启动参数+轮询退避+主题anchor黑金。

### ✅ 阶段3 P0批次已完成（commit aa49a07，CI #24编译通过）

AI Invocation审批系统4层全量新建+向导补第4步剧情总纲。16文件8640行，QA独立验收108/108 PASS。

### ✅ 阶段3 T03已完成（commit 723ddc6，CI #25编译通过）

三个Mock面板接真实API，硬编码全部清除。4文件1388行，QA独立验收84项0 FAIL。

### 📋 阶段3剩余任务（T04+T05）

| 任务 | 优先级 | 内容 | 状态 |
|------|--------|------|------|
| T04 | P2 | DAG节点交互 + 题材包接API（3.3+3.5） | **待推进** |
| T05 | P2 | 六面板全CRUD（3.6 伏笔/道具/演化/编年史/AntiAI/对话沙盒） | **待推进** |

**完整 commit 链（main分支，已push，从阶段1起）**：

| commit | 阶段 | 内容 |
|--------|------|------|
| 85faf62 | 交接 | 交接文档v6终极版 |
| 723ddc6 | 阶段3 T03 | 三个Mock面板接真实API（7文件 +2144/-116行） |
| aa49a07 | 阶段3 P0 | CI#23修复（6类编译错误） |
| 5bd2b44 | 阶段3 P0 | T01基础层+T02 AI Invocation+向导（31文件 +10388/-57行） |
| 043b402 | 阶段2 | CI#21修复 PromptNode Hashable |
| bd753aa | 阶段2 | CI#20修复 default关键字+Hashable+exportData |
| b130b0c | 阶段2 | 主体 T01-T05（15文件 +2098/-420行） |
| 39282d4 | 阶段1 | CI#18修复 BibleModels类型转换 |
| 52762d5 | 阶段1 | 返工 onStreamEnd+approval_required/error/done显式cancel SSE |
| b1cada9 | 阶段1 | 主体 T01-T06 Bible SSE+Autopilot+workbench（18文件 +3020/-299行） |
| 64d77d6 | 阶段1 | autopilot 409卡点修复 macro触发位置 |
| 4e5ceca | 阶段1 | 宏观规划REST化+补confirm调用 |
| ad33ace | 阶段1 | MacroPlanEvent便利构造器 |
| f6ec43f | 阶段1 | RootView NavigationSplitView→HStack+NavigationStack |
| 381674e | 阶段1 | 嵌套NavigationSplitView崩溃+精简entitlements |
| 81ce290 | 阶段1 | 建书/打开书闪退+删除粘贴按钮 |
| 855f3c4 | 阶段1 | APIConfig init self属性访问顺序 |
| 5d5aaea | 阶段1 | 6 bug修复 |
| 50a469a | 阶段1 | LLM配置点击无响应+粘贴/键盘 |
| 93df767 | 阶段1 | 全面bug审计修复+plotpilot对比补全（23文件33问题） |

**CI 历史（#17-#25）**：

| CI# | sha | 结论 | 说明 |
|-----|-----|------|------|
| #25 | 723ddc6 | ✅ success | T03最终状态 |
| #24 | aa49a07 | ✅ success | P0修复后 |
| #23 | 5bd2b44 | ❌ failure | P0首次编译失败6类错误 |
| #22 | 043b402 | ✅ success | 阶段2最终 |
| #21 | bd753aa | ❌ failure | 阶段2修复1 |
| #20 | b130b0c | ❌ failure | 阶段2首次编译失败 |
| #19 | 39282d4 | ✅ success | 阶段1最终（IPA artifact id=7848226612, 1.6MB, 可TrollStore侧载） |
| #18 | 52762d5 | ❌ failure | 阶段1返工编译失败 |
| #17 | 64d77d6 | ✅ success | 阶段1 409修复 |

**最新成功CI**：#25（commit 723ddc6，success）

**IPA artifact**：CI#19有artifact可TrollStore侧载实测（artifact id=7848226612, run_id=28095424522, 1.6MB）。后续CI#22/#24/#25也有artifact，可在GitHub Actions页面下载。

**预期阶段3全部完成后覆盖度**：~93%

---

## 五、阶段3全部决策记录（下一任必读，不可推翻）

### 5.1 主理人8项决策（许清楚PRD阶段产出）

| # | 决策 | 执行方式 |
|---|------|---------|
| Q1 | AI Invocation headless自动推进 | **不实现** advanceHeadlessSession/scheduleHeadlessAdvance |
| Q2 | 生成轮询间隔 | 硬编码 `generationPollMs = 2000` |
| Q3 | 向导第4步本地缓存 | UserDefaults，key=`wizard_ui_cache_{novelId}` |
| Q4 | 步骤跳转权限 | maxVisitedStep模式（顺序前进+后退到已到步骤） |
| Q5 | 3.6六面板CRUD原版行号 | 架构师已补标 |
| Q6 | DAG提示词广场跳转 | 阶段2已建PromptPlazaStore，用NavigationLink跳转 |
| Q7 | QualityGuardrailPanel五维度来源 | **guardrailApi.check()** POST /novels/{id}/guardrail/check（不是monitor.ts拼装） |
| Q8 | featureFlags | iOS不设flag，aiInvocationDebug=false，variableCenterDebugPanels=true |

### 5.2 主理人7项疑问决策（寇豆码P0事实表阶段产出）

| # | 疑问 | 决策 |
|---|------|------|
| 疑问1 | showDebugPanel行为 | **无条件设visible=true**，shouldKeepPanelVisible()无条件返回true |
| 疑问2 | title计算属性 | **包含**（View层标题需要） |
| 疑问3 | plotOutlineModel工具函数归属 | **放入PlotOutlineModels.swift**，15个全移植 |
| 疑问4 | WizardUiCachePayload字段 | **保留8字段**，worldbuildingFieldLabels不移植 |
| 疑问5 | 重复JSON解析函数 | 通用复用InvocationOutput.swift，parseAttemptContent+recoverTruncatedArrayObject作扩展 |
| 疑问6 | Bible SSE接线点 | 实现时补读NovelSetupGuide.vue:1548-1550确认（已接线） |
| 疑问7 | 章节SSE终止消费 | Task.cancel()或标志位，对齐原版return true（已实现） |

### 5.3 主理人6项疑问决策（寇豆码T03事实表阶段产出）

| # | 疑问 | 决策 |
|---|------|------|
| T03疑问1 | era硬编码'ancient' | ✅ iOS也硬编码 |
| T03疑问2 | scene_type硬编码'auto' | ✅ 保持 |
| T03疑问3 | chapterId来源 | ✅ 用NovelStore.currentChapter?.id（ChapterDTO.id，不走StructureStore） |
| T03疑问4 | ConsistencyReportPanel内嵌 | ✅ 保持iOS现有架构分开独立面板（功能不砍，UI适配iOS） |
| T03疑问5 | ForeshadowChapterSuggestionsPanel内嵌 | ✅ T03只做元素CRUD，伏笔建议保持独立 |
| T03疑问6 | guardrailSnapshot novelId=slug | ✅ 照做 |

### 5.4 架构师校正的3.6原版文件名（重要，别搞错）

| PRD名称 | 实际原版文件名 | 路径 |
|---------|--------------|------|
| ForeshadowLedger.vue | ForeshadowLedgerPanel.vue | components/workbench/ |
| PropManagerPanel.vue | ManuscriptPropsPanel.vue | components/workbench/ |
| ChroniclesPanel.vue | HolographicChroniclesPanel.vue | components/workbench/ |
| AntiAIPanel.vue | AntiAIDashboard.vue | components/workbench/promptPlaza/ |
| DialogueSandboxPanel.vue | DialogueCorpus.vue | components/workbench/ |

### 5.5 架构师标注的待明确事项（T04/T05实现时注意）

1. **题材包API端点**：原版直接import JSON不走API。iOS先试GET /taxonomy/bundles/builtin_cn_v1，404则降级Bundle本地加载
2. **DAG节点API端点路径**：需实现者读dagStore.ts确认loadNodePromptLive/toggleNode/updateNodeConfig的具体端点
3. **3.6演化/AntiAI/对话沙盒API端点**：T05实现者开工前必须先Read原版完整源码输出事实表（机制1）
4. **PropDetailDrawer独立组件**：iOS当前未拆分，T05需新建

---

## 六、T04+T05详细启动指令（下一任AI直接执行）

### T04 DAG节点交互+题材包接API（P2）

**范围（2个模块）**：

**3.3 DAG节点交互**（18条PRD）：
- 3.3.1 NodeContextMenu（长按菜单）：查看详情+启禁用toggle
- 3.3.2 NodeDetailPanel（详情Sheet）：状态条+基本信息+提示词来源+预览+端口+写作遥测轮询+默认下游+启禁用Switch
- 3.3.3 NodeEditorDrawer（配置抽屉）：提示词关联+广场跳转+运行参数(temperature/maxTokens/timeout/maxRetries/modelOverride)+保存

**3.5 题材包接API**（10条PRD）：
- 3.5.1 数据模型+API：TaxonomyBundle+TaxonomyNode+TaxonomyWritingProfile + GET /taxonomy/bundles/builtin_cn_v1（或Bundle本地加载）
- 3.5.2 题材选择器：MarketTaxonomyPicker（搜索+大类+主题+分类信息+世界观基调编辑+写作原则编辑）+ CreateNovelSheet替换硬编码

**T01基础层已完成**：TaxonomyModels.swift已建，APIEndpoint.swift已+端点

**T01已建的端点清单（T04/T05实现时直接用，不要重复建）**：
- AIInvocation：10端点（create/get/accept/reject/resume/retry/previewPromptDraft/savePromptDraft/updateVariables/commits）
- Workflow：3端点（plotOutlineStream/getPlotOutline/savePlotOutline/generatePlotOutline）
- ChapterElement：5端点（list/create/batchUpdate/delete/getElementChapters）
- Taxonomy：端点已建（GET /taxonomy/bundles/builtin_cn_v1）
- Guardrail：guardrailCheck(POST) + guardrailSnapshot(GET)
- Foreshadow：foreshadowStats等（ForeshadowStore已存在）
- Prop：get/update/delete/events/createEvent（PropStore已存在）
- Monitor：tensionCurve/voiceDrift

**现有Store清单（22个，T04/T05实现时按需依赖）**：
AIInvocationStore, AutopilotStore, BibleStore, CastStore, DAGStore, EvolutionStore, ExportStore, ForeshadowStore, GovernanceStore, KnowledgeGraphStore, LLMControlStore, MonitorStore, NovelStore, OnboardingStore, PromptPlazaStore, PropStore, SettingsStore, SnapshotStore, StatsStore, StructureStore, TraceStore, WorkbenchStore

**⚠️ T04注意**：DAGStore已存在（不是AutopilotStore）。T04的DAG节点交互方法（toggleNode/updateNodeConfig/loadNodePromptLive）应加到DAGStore，不是AutopilotStore。实现前先Read DAGStore.swift确认现有方法。

**⚠️ T05注意**：ForeshadowStore/PropStore/EvolutionStore已存在。T05实现时先Read这些Store确认现有方法，按需扩展，不要重复建。

**涉及文件（6文件，新建5改1）**：
1. `Views/Autopilot/NodeContextMenu.swift`（新）
2. `Views/Autopilot/NodeDetailPanel.swift`（新）
3. `Views/Autopilot/NodeEditorDrawer.swift`（新）
4. `Views/Taxonomy/MarketTaxonomyPicker.swift`（新）
5. `Views/Home/CreateNovelSheet.swift`（改，替换硬编码）
6. `ViewModels/AutopilotStore.swift`（改，+DAG交互方法）

**原版对照文件**（原版前端根目录 `D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`）：
- `components/autopilot/NodeContextMenu.vue`（1-113行）
- `components/autopilot/NodeDetailPanel.vue`（1-465行）
- `components/autopilot/NodeEditorDrawer.vue`（1-296行）
- `components/taxonomy/MarketTaxonomyPicker.vue`（1-495行）
- `domain/taxonomy/cnMarket.ts`（1-54行）
- `domain/taxonomy/builtin_cn_v1.bundle.json`
- `stores/dagStore.ts`（确认API端点路径）

### T05 六面板全CRUD（P2）

**范围（6个面板，30条PRD）**：

| 面板 | 原版文件（已校正名） | 要补 |
|------|-------------------|------|
| 伏笔 | ForeshadowLedgerPanel.vue | CRUD+优先级星标+消费弹窗+筛选+Tab |
| 道具 | ManuscriptPropsPanel.vue + PropDetailDrawer.vue | CRUD+事件创建+详情抽屉 |
| 演化 | StoryEvolutionPanel.vue | 快照交互+闸门+覆盖+叙事时间线 |
| 编年史 | HolographicChroniclesPanel.vue | 双螺旋布局+时间线编辑+回滚 |
| AntiAI | AntiAIDashboard.vue | 七层防御+扫描+统计+分类+规则+白名单 |
| 对话沙盒 | DialogueCorpus.vue | 语料筛选+生成器+anchor读写 |

**T01基础层已完成**：ForeshadowModels.swift+PropModels.swift已补字段，APIEndpoint.swift已+端点

**T01已建的模型清单（T05实现时直接用）**：
- ForeshadowModels.swift：ForeshadowEntry + CreateRequest(含suggestedResolveChapter/resolveChapterWindow/importance) + UpdateRequest
- PropModels.swift：PropDTO + PropEventDTO + Create/Patch + PropCategory/PropLifecycleState枚举 + isPriorityForChapter字段
- APIEndpoint已+：Foreshadow端点(foreshadowStats等) + Prop端点(get/update/delete/events/createEvent)

**⚠️ T05演化/AntiAI/对话沙盒**：这3个面板的原版API端点T01未建（待明确事项5.5第3条）。T05开工前必须先Read原版完整源码输出事实表，确认API端点后再补建到APIEndpoint.swift。

**涉及文件（6文件全改）**：
1. `Views/Panels/ForeshadowLedgerPanel.swift`（改）
2. `Views/Panels/PropManagerPanel.swift`（改，+PropDetailDrawer新建）
3. `Views/Panels/StoryEvolutionPanel.swift`（改）
4. `Views/Panels/ChroniclesPanel.swift`（改）
5. `Views/Panels/AntiAIPanel.swift`（改）
6. `Views/Panels/DialogueSandboxPanel.swift`（改）

**关键**：演化/AntiAI/对话沙盒API端点待实现者读原版完整源码补全（待明确事项8.3），T05开工前必须先Read原版6个面板源码输出事实表（机制1）。

### T04/T05 执行流程（每个任务都走完整SOP）

1. **主理人确认团队存在**（或重新TeamCreate software-cangjie-stage3）
2. **派寇豆码读原版输出事实表（机制1）**：
   - T04：读NodeContextMenu.vue/NodeDetailPanel.vue/NodeEditorDrawer.vue/MarketTaxonomyPicker.vue/cnMarket.ts/dagStore.ts
   - T05：读6个面板原版Vue源码
   - 落盘 `docs/stage3_facts_table_t04.md` / `docs/stage3_facts_table_t05.md`
3. **主理人确认事实表**，对疑问做决策
4. **派寇豆码实现**（机制4标注原版行号+机制6写死6铁律）
5. **派严过关独立验收**（机制5，落盘 `docs/stage3_qa_report_t04.md` / `docs/stage3_qa_report_t05.md`）
6. **主理人push+盯CI**（见第九节CI排查方法）

### 派工prompt模板（约束方法三，必须复用）

```
你是仓颉iOS移植项目的工程师 寇豆码（Kou）。这是移植任务，不是新开发。

## 任务：T04/T05 [具体任务]

## 第一步：读原版输出事实表（机制1）
[必读原版文件清单]

## 第二步：实现（主理人确认事实表后）
- 每方法标注原版文件+行号（机制4）
- 照接口契约表实现，不许自创接口
- 实现完自报功能对齐度

## 铁律（违反即返工）
1. 禁止砍功能、禁止简化流程、禁止跳过原版任何步骤
2. 必须逐条对齐PRD功能清单，有疑问上报不许自作主张
3. 每个方法/组件必须标注对应的原版文件+行号
4. 不许自创 API 接口或数据模型，必须照接口契约表实现
5. 遇到原版逻辑看不懂，立即停下问主理人，不许凭猜测简化
6. 实现完成后必须自报"功能对齐度"

## 技术约定（项目铁律）
[见第八节]
```

---

## 四-A、后端信息（重要）

- **后端是原项目 PlotPilot 的 Python/FastAPI 后端，已部署云端，零改动**
- 我们只做 iOS 前端移植，对接已部署的后端
- 后端所有接口都已存在（原版 Vue 在用），我们按原版方式调即可
- LLM 端点已配置好（DeepSeek + agnes 等），测试连通性通过
- **不需要碰后端代码，不需要部署后端，后端已经在跑了**
- 用户原话："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变"
- 后端 API base URL：用户在iOS设置页配置（SettingsStore管理，UserDefaults持久化）。下一任如需测试连通性，问用户要后端地址。

---

## 七、防砍功能约束 6 道机制（铁律，每阶段必须套用）

详见 `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`。简表：

1. **强制先读原版再动手**：工程师动手前必须Read原版文件，输出"原版做了什么"事实表，主理人确认才进实现
2. **PRD固化功能清单checklist**：产品经理出PRD时列功能清单，每项标原版文件+行号
3. **架构师出接口契约表**：每个API/SSE事件/数据模型都标原版文件+行号
4. **实现者逐条标注原版行号**：代码注释里写对应的原版文件:行号
5. **QA按原版清单逐项验收**：QA独立读代码验证，不rubber-stamp工程师自报，缺一条即FAIL
6. **派工prompt写死6条铁律**：禁止砍功能/简化流程/跳过原版步骤/自创API/凭猜测简化/不自报对齐度

**阶段3执行情况**：P0+T03全程套用6道机制，QA独立验收全部PASS，0砍功能。事实表阶段多次抓出系统设计遗漏，体现机制1价值。

---

## 八、技术约定（铁律，违反编译失败）

1. **iOS 16+ 兼容**：禁用 @Observable/@Bindable宏、NavigationSplitView、.scrollContentMargins 等 iOS 17+ API
2. **零 C 依赖、零新 SPM 依赖**（仅 KeychainAccess 4.2.2）
3. **日期解码**：必须用 `CangjieDecoder.shared`（定义在 `Cangjie/Utils/DateFormatter+ISO.swift`，处理Python datetime.isoformat微秒6位）
4. **APIEndpoint.defaultPrefix** = `/api/v1`；导出端点 prefix 需追加 `/export`
5. **NavigationSplitView 禁用**：全项目用 HStack + NavigationStack（iOS16嵌套会AttributeGraph崩溃）
6. **配置持久化**：用 UserDefaults（不用 Keychain，TrollStore杀后台会丢）
7. **输入框**：全用 TextField（不用 SecureField，系统级禁第三方键盘）
8. **entitlements 最小化**：只有 network.client + UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace
9. **JSON 解析**：SSE 事件用 SSEEvent.decodeAsDictionary() 手动字典取值，不用 Codable 直接解码（字段可能缺失）
10. **Store**：用 ObservableObject + @Published（不用 @Observable 宏）
11. **Drawer/Sheet**：用 SwiftUI 原生 .sheet / .fullScreenCover（不用 NavigationSplitView）
12. **SSE**：用 SSEClient（阶段1已建基础设施）

---

## 九、CI 信息与排查方法

- **仓库**：https://github.com/Da-AiXZ/CangJie
- **编译环境**：macos-14, Xcode 15.4, XcodeGen, ldid
- **CI 脚本**：`.github/workflows/build.yml` / `scripts/build-ipa.sh` / `scripts/verify-ipa.sh`
- **触发**：push 到 main 自动触发
- **编译耗时**：约60-120秒
- **最新成功CI**：#25（commit 723ddc6，T03最终状态，success）

### CI 失败排查方法（前台盯CI）
```bash
# 工作目录先切到代码目录
cd "D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios"

# push后查CI状态
python -c "
import urllib.request, json
token = '<TOKEN>'
req = urllib.request.Request('https://api.github.com/repos/Da-AiXZ/CangJie/actions/runs?per_page=3', headers={'Authorization':'token '+token,'Accept':'application/vnd.github+json','User-Agent':'ci-check'})
data = json.load(urllib.request.urlopen(req))
for r in data['workflow_runs'][:3]:
    print(f\"#{r['run_number']} | sha={r['head_sha'][:7]} | status={r['status']} | conclusion={r['conclusion']} | run_id={r['id']}\")
"

# 盯CI直到完成
python -c "
import urllib.request, json, time
token = '<TOKEN>'
run_id = <RUN_ID>
last=''
for i in range(40):
    req = urllib.request.Request(f'https://api.github.com/repos/Da-AiXZ/CangJie/actions/runs/{run_id}', headers={'Authorization':'token '+token,'Accept':'application/vnd.github+json','User-Agent':'ci-check'})
    d = json.load(urllib.request.urlopen(req))
    s, c = d['status'], d['conclusion']
    if s != last:
        print(f'[{i*15}s] status={s} conclusion={c}', flush=True); last=s
    if s == 'completed':
        print(f'CI完成！conclusion={c}', flush=True)
        break
    time.sleep(15)
"

# 拉日志找编译错误
python -c "
import urllib.request, json, zipfile, io
token = '<TOKEN>'
run_id = <RUN_ID>
req = urllib.request.Request(f'https://api.github.com/repos/Da-AiXZ/CangJie/actions/runs/{run_id}/logs', headers={'Authorization':'token '+token,'Accept':'application/vnd.github+json','User-Agent':'ci-check'})
data = urllib.request.urlopen(req).read()
z = zipfile.ZipFile(io.BytesIO(data))
for name in z.namelist():
    if 'Build' in name or 'build' in name:
        content = z.read(name).decode('utf-8', errors='replace')
        for i, line in enumerate(content.splitlines()):
            low = line.lower()
            if 'error:' in low or '❌' in line or 'failed' in low:
                print(f'{name}:{i+1}: {line.strip()[:400]}')
"
```

---

## 十、阶段3新教训（血泪，下一任必读）

### 1. Swift catch块 error 是常量
- catch块内 `error` 是隐式常量，不可赋值
- 错误写法：`catch { error = errorText(error) }` → 编译失败
- 正确写法：`catch { self.errorMessage = errorText(error) }`（用self.error引用@Published var）
- 函数没声明throws时，catch块不能re-throw

### 2. Codable CodingKeys 必须覆盖所有存储属性
- InvocationVariableSnapshotGroup 有存储属性 `groupId`，但 CodingKeys 只有 `case id`，导致Encodable合成失败
- 修复：`case id` 改为 `case groupId = "id"`（存储属性名≠JSON key时必须显式映射）

### 3. if let 绑定要求 Optional 类型
- `if let x = someString` 要求 someString 是 Optional
- 非Optional的判断用 `if !someString.isEmpty` 或 `if someString != defaultValue`

### 4. 类型不能重复声明
- ChapterElementCreate 在 NovelModels.swift 和 ChapterElementModels.swift 都声明了
- 修复：删掉旧声明，保留新版本

### 5. 补字段要同步调用处
- ForeshadowModels.swift 补了字段到 CreateRequest，但 ForeshadowStore.swift 调用处没更新 → missing arguments
- 修复：调用处补参数（传nil）

### 6. 交接文档不能写token明文
- GitHub secret scanning 会拦截含 ghp_xxx 的push
- 修复：sed替换为占位符 + amend commit

### 7. 原版文件名可能与PRD不同（T05重点）
- 3.6六面板的原版文件名架构师已校正（见5.4），T05实现时必须按校正后的文件名读原版

---

## 十一、项目结构

```
cangjie-ios/
├── Cangjie/
│   ├── App/                    # CangjieApp.swift, AppState.swift
│   ├── Models/                 # 24+ 数据模型
│   │   ├── AIInvocationModels.swift（阶段3 P0新建，20模型+6Payload+2枚举）
│   │   ├── PlotOutlineModels.swift（阶段3 P0新建，DTO+缓存+15工具函数）
│   │   ├── ChapterElementModels.swift（阶段3 P0新建）
│   │   ├── TaxonomyModels.swift（阶段3 P0新建）
│   │   ├── MonitorModels.swift（阶段3 +GuardrailCheck）
│   │   ├── ForeshadowModels.swift（阶段3 +字段）
│   │   ├── PropModels.swift（阶段3 +字段）
│   │   └── ... 其他模型
│   ├── Networking/             # APIClient, APIEndpoint（阶段3 +AIInvocation/Monitor/ChapterElement/Taxonomy端点）
│   ├── SSE/                    # SSEClient, SSEStreamRegistry（阶段3 +startPlotOutlineStream）
│   ├── Theme/                  # Theme.swift（4模式+4字号含anchor黑金）
│   ├── Utils/
│   │   ├── DateFormatter+ISO.swift（CangjieDecoder.shared）
│   │   ├── InvocationOutput.swift（阶段3 P0新建，9函数+2扩展）
│   │   └── ...
│   ├── ViewModels/
│   │   ├── AIInvocationStore.swift（阶段3 P0新建，18方法+16计算属性+轮询）
│   │   ├── OnboardingStore.swift（阶段3 P0改，5步+plotOutline+审批接线）
│   │   ├── WorkbenchStore.swift（阶段3 P0改，+approval_required接线）
│   │   ├── MonitorStore.swift（阶段3 T03改重写，质量护栏+张力+文风）
│   │   ├── AutopilotStore.swift（阶段3 T04待改，+DAG交互）
│   │   └── ... 其他Store
│   └── Views/
│       ├── AIInvocation/AIInvocationReviewPanel.swift（阶段3 P0新建，15UI区块）
│       ├── Onboarding/
│       │   ├── PlotOutlineStep.swift（阶段3 P0新建，第4步）
│       │   └── OnboardingWizardView.swift（阶段3 P0改，5步）
│       ├── Panels/
│       │   ├── QualityGuardrailPanel.swift（阶段3 T03改重写，接guardrailApi）
│       │   ├── ConsistencyReportPanel.swift（阶段3 T03改重写，接consistency_report）
│       │   ├── ChapterElementPanel.swift（阶段3 T03改重写，接ChapterElement API）
│       │   ├── ForeshadowLedgerPanel.swift（T05待改）
│       │   ├── PropManagerPanel.swift（T05待改）
│       │   ├── StoryEvolutionPanel.swift（T05待改）
│       │   ├── ChroniclesPanel.swift（T05待改）
│       │   ├── AntiAIPanel.swift（T05待改）
│       │   └── DialogueSandboxPanel.swift（T05待改）
│       ├── Autopilot/
│       │   ├── NodeContextMenu.swift（T04待新建）
│       │   ├── NodeDetailPanel.swift（T04待新建）
│       │   └── NodeEditorDrawer.swift（T04待新建）
│       ├── Taxonomy/MarketTaxonomyPicker.swift（T04待新建）
│       ├── Home/CreateNovelSheet.swift（T04待改，替换硬编码）
│       └── ... 其他Views
├── docs/                       # 所有文档（PRD/系统设计/事实表/QA报告/交接文档）
├── Resources/                  # Info.plist, Cangjie.entitlements, Assets.xcassets
├── .github/workflows/build.yml
├── scripts/                    # build-ipa.sh, verify-ipa.sh
└── project.yml                 # XcodeGen 配置
```

---

## 十二、核心教训（血泪史，下一任必读）

### 移植原则（最重要）
- **直接对照原项目接，不要自己发明流程**
- 原版怎么做，iOS版就怎么做
- 不许砍功能、不许简化、不许跳过原版步骤

### NavigationSplitView 是 iOS 16 的雷区
- 不能嵌套，会触发AttributeGraph assertion崩溃
- 全项目用 HStack + NavigationStack 替代

### TrollStore 侧载环境特殊性
- Keychain 杀后台会被清理 → 用 UserDefaults
- SecureField 系统级禁第三方键盘 → 用 TextField

### 子agent管理教训
- 主agent停下后子agent不会自己继续工作
- 必须主agent主动SendMessage推动或spawn新agent接手
- 返工/小修也要spawn agent执行，不能干等

### 阶段3新教训（见第十节）

---

## 十三、用户信息

- **设备**：iPad Pro 2021 (M1), iOS 16.6.1, TrollStore 侧载
- **后端**：已部署云端（PlotPilot Python/FastAPI），零改动
- **LLM**：已配 DeepSeek + agnes 等端点，测试连通性通过
- **用户期望**：直接按原项目方法接好前端，后端不变，不要自己发明流程
- **用户容忍度**：对砍功能零容忍，前两任因砍功能被叫停做了审计报告
- **用户要求**：阶段3严格按《AI移植项目防砍功能约束方法.md》6道机制执行
- **用户原话**："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变"
- **用户特别交代**：交接文档要把所有东西交代清楚，防止下一个AI看了一知半解瞎改

---

## 十四、阶段3已完成内容详细清单（供下一任参考，避免重复造轮子）

### P0批次已完成的16文件
- AIInvocationModels.swift：20模型+6Payload+2枚举(14状态)
- PlotOutlineModels.swift：DTO+缓存(8字段)+plotOutlineModel 15函数
- ChapterElementModels.swift：DTO+3枚举
- TaxonomyModels.swift：Bundle+Node+WritingProfile
- MonitorModels.swift：+GuardrailCheck模型
- ForeshadowModels.swift：+字段
- PropModels.swift：+字段
- InvocationOutput.swift：9函数+parseAttemptContent+recoverTruncatedArrayObject
- APIEndpoint.swift：+AIInvocation(10)+Workflow(3)+ChapterElement(5)+Taxonomy端点
- AIInvocationStore.swift：18方法+16计算属性(含title)+2000ms轮询+监听
- AIInvocationReviewPanel.swift：15UI区块+350ms防抖
- OnboardingStore.swift：5步枚举+plotOutline全逻辑+3处approval接线
- PlotOutlineStep.swift：向导第4步View
- OnboardingWizardView.swift：5步+AI审批Sheet
- SSEStreamRegistry.swift：+startPlotOutlineStream
- WorkbenchStore.swift：+approval_required接线

### T03已完成的4文件
- MonitorStore.swift：质量护栏+张力曲线+文风漂移（era硬编码ancient, scene_type硬编码auto, mode默认advise）
- QualityGuardrailPanel.swift：六维度条形图(language_style/character_consistency/plot_density/naming/viewpoint/rhythm)+总分圆形+违规折叠+advise/enforce模式+快照恢复
- ConsistencyReportPanel.swift：issues/warnings/suggestions三分组+严重程度着色+空状态
- ChapterElementPanel.swift：5个CRUD端点+人物/地点/其他三分组+Bible ID→name映射+filterType筛选器

### T03 MINOR观察项（6项，不阻断，可后续优化）
1. ConsistencyReportPanel tokenCount返回nil（WorkbenchStore解析了token_count但丢弃）
2. QualityGuardrailPanel维度用guardrailDimensionLabel(dim.key)而非dim.name
3. ConsistencyReportPanel位置显示为Text而非可点击Button
4. QualityGuardrailPanel/ChapterElementPanel缺少deskTick watch
5. ChapterElementPanel缺少readOnly模式提示
6. ChapterElementPanel用currentChapter?.id需运行时验证ID是否匹配

---

## 十五、一句话总结

**阶段1+2+3(P0+T03)已完成编译通过，剩余T04(DAG交互+题材包)+T05(六面板CRUD)按本交接文档第六节执行，严格按防砍6道机制，不许砍功能。**

---

**交接完毕。代码 = SOP(团队)。下一任加油，用户对砍功能零容忍。**
