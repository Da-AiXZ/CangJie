# 仓颉 iOS 移植项目交接文档 v8（T05完成版，下一任AI读完即可接手阶段4）

> **交接日期**：2026-06-25 12:10（v7 → v8 升级，T05核验完成+编译错误修复后写交接防中断）
> **交接人**：齐活林（Qi）· 交付总监（第六任主理人，本会话接手第五任的v7）
> **状态**：阶段1+2+3全部完成（T05功能305/305核验通过+编译错误已修复），**T05代码在本地未push**（用户选择和阶段4一起干），**下一步推进阶段4**
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜瞎改。本文件是唯一权威交接，读完即可接手。**用户特别交代：所有东西都要写清楚，防止下一个AI一知半解瞎几把改。**
> **v7 → v8 变更**：T05完成（305/305 QA两轮核验通过，编译错误StoryNavigatorView重复声明已修复为EvolutionNavigatorView）；新增阶段4详细启动指令；新增T05决策记录；新增教训10

---

## ⚡ 下一任AI接手速查（先读这段）

### 你要做什么
推进 **阶段4（锦上添花，7项33个组件/操作）**。阶段3已全部完成（含T05），覆盖度~93%。阶段4完成后覆盖度~98%。

### 你要做之前先读（按顺序）
1. **本交接文档v8**（你现在在读）
2. `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`（防砍6道机制，铁律）
3. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md`（阶段4范围在第334-446行）
4. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/全项目核验报告_2026-06-25.md`（第六任主理人核验报告，确认前序阶段无偷工减料）
5. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_t05_round2.md`（T05 QA第2轮报告，305/305 PASS）

### ⚠️ 当前工作区状态（CRITICAL）
**T05代码在本地未commit/push**（用户选择"T05和阶段4一起干"）。
- 16个modified文件 + 7个untracked文件（含T05返工+编译错误修复）
- git最新commit仍是 `97dcbac`（交接文档v7，T04完成版）
- 阶段4的改动会叠加在T05之上，最终一起commit/push
- **不要单独commit T05**——用户明确要求一起干

### 工作流（标准SOP，严格按防砍6道机制）
```
阶段4按子项推进，每个子项走：
工程师读原版输出事实表(机制1) → 主理人确认 → 工程师实现标注原版行号(机制4)+6铁律(机制6) → QA独立验收(机制5) → 主理人push+盯CI
```
PRD和系统设计已有阶段3基础，阶段4按子项做增量事实表即可。

### 团队
团队名 `software-cangjie-stage3`（会话重启可能需重新TeamCreate）。4个成员：
- 许清楚（software-product-manager）— 阶段4需求已在核验清单，按需做增量PRD
- 高见远（software-architect）— 阶段4按子项做任务分解
- 寇豆码（software-engineer）— T05已完成，可继续派阶段4
- 严过关（software-qa-engineer）— T05验收完成，可继续派阶段4验收

**如果团队已不存在（会话重启），主理人重新TeamCreate(team_name: "software-cangjie-stage4")再spawn成员。**

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
| **当前会话工作目录** | `D:/111/2026-06-25-11-41-30`（空目录，实际代码不在） |
| **防砍约束方法** | `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md` |
| **阶段补齐核验清单** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md` |
| **全项目核验报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/全项目核验报告_2026-06-25.md` |
| **T05 QA第2轮报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_t05_round2.md` |
| **T05事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_t05.md` |
| **阶段3 PRD（157条）** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md` |
| **阶段3系统设计** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md` |
| **历史交接文档v3-v7** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/HANDOFF_CANGJIE_IOS_2026-06-2X_vX.md` |
| **审计报告1（差异）** | `C:/Users/netease/Desktop/仓颉iOS移植版差异审计报告.md` |
| **审计报告2（深度）** | `C:/Users/netease/Desktop/仓颉iOS已实现功能对齐深度审计.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-25-11-41-30`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：已存在 git remote URL 中（用 `git remote get-url origin` 提取，Python脚本里用re.search提取，不输出明文）。**不要写进交接文档明文**，GitHub secret scanning会拦截push
- remote URL 格式：`https://x-access-token:<TOKEN>@github.com/Da-AiXZ/CangJie.git`
- **教训**：交接文档v3/v4曾把token明文写入，导致push被GitHub secret scanning拦截。**下一任绝对不要在文档里写token明文。**

**查CI/拉日志的Python脚本模板**（token从git remote提取，不写明文）：
```python
import urllib.request, json, re, subprocess
url = subprocess.check_output(['git','remote','get-url','origin'], text=True).strip()
m = re.search(r'x-access-token:([^@]+)@', url)
token = m.group(1) if m else ''
# 然后用token调GitHub API
```

---

## 四、当前完成状态（2026-06-25 12:10）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）
73项功能点全实现+QA返工通过。Bible SSE分3步stage+13类SSE事件+Autopilot chapter-stream 9类事件。

### ✅ 阶段2已完成（commit 043b402，CI #22编译通过）
6项全PASS，164/164=100%对齐度。

### ✅ 阶段3 P0批次已完成（commit aa49a07，CI #24编译通过）
AI Invocation审批系统4层全量新建+向导补第4步剧情总纲。

### ✅ 阶段3 T03已完成（commit 723ddc6，CI #25编译通过）
三个Mock面板接真实API，硬编码全部清除。

### ✅ 阶段3 T04已完成（commit 7ca6d98，CI #27编译通过）
DAG节点交互+题材包接API。

### ✅ 阶段3 T05已完成（本地未commit，功能305/305核验通过）

**T05是阶段3最后一个任务，已由第六任主理人完成核验：**

| 维度 | 结果 |
|------|------|
| 功能对齐度 | **305/305**（QA两轮独立核验确认） |
| 19项返工 | **19/19全部真实完成** |
| 砍功能 | **0**（grep扫描"简化版/TODO/暂不实现"零命中） |
| 编译错误 | **已修复**（StoryNavigatorView重复声明→EvolutionNavigatorView改名） |
| commit/push | ❌ 未commit（用户选择和阶段4一起干） |
| CI | ❌ 未跑（T05从未进CI） |

**T05改动文件清单（22文件，约5000行新代码）**：

模型层6文件（改）：
- AntiAIModels.swift / EvolutionModels.swift / GovernanceModels.swift / SandboxModels.swift / BibleModels.swift（+memberwise init）
- ManuscriptModels.swift（新）

APIEndpoint.swift：+5端点（NarrativeEngine.storyEvolution + Chronicles.rollback + Manuscript×2 + Sandbox.patchAnchor）

Store层5文件：
- ForeshadowStore.swift / PropStore.swift / EvolutionStore.swift / WorkbenchStore.swift（改）
- AntiAIStore.swift（新）

View层11文件：
- 6 Panel改：ForeshadowLedgerPanel / PropManagerPanel / StoryEvolutionPanel / ChroniclesPanel / AntiAIPanel / DialogueSandboxPanel
- PropDetailDrawer.swift（新）
- TimelinePanel.swift（新）
- StoryNavigatorView.swift → **EvolutionNavigatorView.swift**（新，原名导致重复声明已改名）
- StoryTimelineView.swift（新）
- StoryDetailPanelView.swift（新）

### 📋 阶段4待推进（7项33个组件/操作）

| 子项 | 内容 | 组件数 | 优先级 | 预计复杂度 |
|------|------|--------|--------|-----------|
| 4.1 | 文风voiceApi对接 | 2端点+1面板 | P3 | 低 |
| 4.2 | 世界线DAG重写（伪造→真实） | 1重写 | P3 | **高** |
| 4.3 | 工作台组件补齐 | ~9个（12个减去已做3个） | 高2+中4+低3 | **高** |
| 4.4 | Autopilot组件补齐 | ~4个（6个减去已做2个） | 中 | 中 |
| 4.5 | 全局浮动按钮 | 4个 | 中 | 低 |
| 4.6 | 知识图谱写操作 | 5操作接线 | P3 | 中 |
| 4.7 | 其他 | Debug/KnowledgeJsonView/单元测试 | 低 | 低 |

**完整 commit 链（main分支，已push）**：

| commit | 阶段 | 内容 |
|--------|------|------|
| 97dcbac | 交接 | 交接文档v7（T04完成版）— **最新push的commit** |
| 7ca6d98 | 阶段3 T04 | CI#27 success（最新成功CI） |
| 92481bf | 阶段3 T04 | T04主体 |
| 723ddc6 | 阶段3 T03 | 三个Mock面板 |
| aa49a07 | 阶段3 P0 | CI#24 |
| 043b402 | 阶段2 | |
| 39282d4 | 阶段1 | |

**最新成功CI**：#27（commit 7ca6d98，success）
**T05+阶段4的commit尚未产生**——下一次push将是T05+阶段4的代码。

---

## 五、阶段3全部决策记录（不可推翻）

### 5.1-5.5 见v7交接文档（8项PRD决策+7项P0疑问+6项T03疑问+T04的12项决策）

### 5.6 T05主理人12项决策（寇豆码T05事实表阶段产出，本版新增）

| # | 疑问 | 决策 |
|---|------|------|
| T05-1 | 演化4子组件是否全移植 | **全部移植**（StoryNavigator/StoryTimeline/StoryDetailPanel/WorldlineDAG），不许简化 |
| T05-2 | StoryEvolutionReadModel结构复杂 | **完整结构化建模**，嵌套unknown用AnyCodable兜底 |
| T05-3 | AntiAIHit字段名不匹配 | **按原版对齐**：text/replacement_hint/start/end |
| T05-4 | CharacterAnchor字段名不匹配 | **按原版对齐**：mental_state/verbal_tic/idle_behavior |
| T05-5 | EvolutionSnapshot字段差异大 | **按原版完整重写**：8个结构化字段+兜底 |
| T05-6 | GovernanceState字段名差异 | **语义对齐**：reports改单条（latest_report） |
| T05-7 | 编年史TimelinePanel | **必须新建**，不占位 |
| T05-8 | workflowApi.getPlotOutline | **核对路径**，不许降级null |
| T05-9 | DialogueCorpus角色选择器 | **新增角色选择器** |
| T05-10 | workbenchRefreshStore tick | **NotificationCenter实现** |
| T05-11 | AntiAI fetchJson | **统一用APIClient** |
| T05-12 | PropDetailDrawer emit | **闭包回调**onUpdated/onClose |

### 5.7 架构师标注的3.6原版文件名（重要，已执行）

| PRD名称 | 实际原版文件名 | 路径 |
|---------|--------------|------|
| ForeshadowLedger.vue | ForeshadowLedgerPanel.vue | components/workbench/ |
| PropManagerPanel.vue | ManuscriptPropsPanel.vue | components/workbench/ |
| ChroniclesPanel.vue | HolographicChroniclesPanel.vue | components/workbench/ |
| AntiAIPanel.vue | AntiAIDashboard.vue | components/workbench/promptPlaza/ |
| DialogueSandboxPanel.vue | DialogueCorpus.vue | components/workbench/ |

---

## 六、阶段4详细启动指令（下一任AI直接执行）

### 阶段4总览（7项，33个组件/操作）

阶段4是"锦上添花"——完整性补齐，非核心但影响体验。**但注意4.3有2个标"高"优先级的组件（ActPlanningModal/NarrativeDashboardPanel）不能当锦上添花糊弄。**

### 6.1 文风 voiceApi 对接（4.1，P3，低复杂度）

| 维度 | 内容 |
|------|------|
| 原版实现 | `api/voice.ts`（samples/fingerprint）+ `components/workbench/VoiceVaultPanel.vue` |
| iOS现状 | `Views/Panels/VoiceVaultPanel.swift` 用 BibleStore+MonitorStore.voiceDrift，不调voiceApi；voice API端点在iOS未定义 |
| 要补 | 1.新增voice API端点定义（samples/fingerprint）2.VoiceVaultPanel改调voiceApi |
| 核验 | voiceApi端点存在；VoiceVaultPanel数据来自voiceApi |

**原版对照文件**：
- `frontend/src/api/voice.ts`
- `frontend/src/components/workbench/VoiceVaultPanel.vue`

### 6.2 世界线 DAG 重写（4.2，P3但高复杂度，伪造→真实）

| 维度 | 内容 |
|------|------|
| 原版实现 | `components/workbench/WorldlineDAG.vue` + `api/worldline.ts` |
| iOS现状 | `Views/Snapshot/WorldlineDAGView.swift` 未调 /worldline/graph，用checkpoints**伪造**布局 |
| 要补 | 1.改调`/worldline/graph`真实API 2.重写布局（分支泳道+汇流点+时间切片）3.补交互（分支/汇流/checkout/merge/createBranch/hardReset） |
| 核验 | WorldlineDAGView数据来自/worldline/graph；能完成checkout/merge/createBranch/hardReset操作 |

**原版对照文件**：
- `frontend/src/api/worldline.ts`
- `frontend/src/components/workbench/WorldlineDAG.vue`

**⚠️ 这是阶段4最高复杂度任务**：手写SVG分支泳道+6种git式交互。

### 6.3 工作台组件补齐（4.3，~9个，高复杂度）

原版 `components/workbench/` 独有，iOS缺失的关键组件。**注意：部分组件T05已建，不要重复造轮子：**

| 组件 | 功能 | 原版文件 | iOS状态 | 优先级 |
|------|------|---------|---------|--------|
| ActPlanningModal | 幕规划弹窗 | ActPlanningModal.vue | ❌缺失 | **高** |
| NarrativeDashboardPanel | 叙事仪表盘 | NarrativeDashboardPanel.vue | ❌缺失 | **高** |
| StoryTimeline | 故事时间线 | StoryTimeline.vue | ❌缺失 | 中 |
| StorylineGitGraph | 故事线Git图 | StorylineGitGraph.vue | ❌缺失 | 中 |
| ChapterCastManager | 章节人物管理 | ChapterCastManager.vue | ❌缺失 | 中 |
| DialogueGeneratorModal | 对话生成器 | DialogueGeneratorModal.vue | ❌缺失 | 中 |
| ChapterStatusPanel | 章节状态面板 | ChapterStatusPanel.vue | ❌缺失 | 中 |
| CharacterNavigator | 角色导航器 | CharacterNavigator.vue | ❌缺失 | 低 |
| ForeshadowChapterSuggestionsPanel | 伏笔章节建议 | ForeshadowChapterSuggestionsPanel.vue | ❌缺失 | 低 |
| ~~PropDetailDrawer~~ | ~~道具详情抽屉~~ | ~~PropDetailDrawer.vue~~ | ✅ **T05已建** | ~~低~~ |
| ~~StoryDetailPanel~~ | ~~故事详情~~ | ~~StoryDetailPanel.vue~~ | ✅ **T05已建**（StoryDetailPanelView.swift） | ~~低~~ |
| ~~DialogueCorpus~~ | ~~对话语料库~~ | ~~DialogueCorpus.vue~~ | ✅ **T05已做**（DialogueSandboxPanel） | ~~低~~ |

**实际还要做9个**（去掉T05已建的3个）。

### 6.4 Autopilot 缺失组件补齐（4.4，~4个，中复杂度）

原版 `components/autopilot/` 独有，iOS缺失。**注意：NodeDetailPanel/NodeEditorDrawer在T04已建，不要重复：**

| 组件 | 功能 | 原版文件 | iOS状态 |
|------|------|---------|---------|
| ~~NodeDetailPanel~~ | ~~节点详情面板~~ | ~~NodeDetailPanel.vue~~ | ✅ **T04已建** |
| ~~NodeEditorDrawer~~ | ~~节点编辑抽屉~~ | ~~NodeEditorDrawer.vue~~ | ✅ **T04已建** |
| StoryPipelineObservability | 故事管道可观测性 | StoryPipelineObservability.vue | ❌缺失 |
| DAGToolbar | DAG工具栏 | DAGToolbar.vue | ❌缺失 |
| ChapterWriterStream | 章节写作流 | ChapterWriterStream.vue | ❌缺失 |
| ForeshadowLedger(autopilot版) | 伏笔账本 | ForeshadowLedger.vue | ❌缺失 |

**实际还要做4个**（去掉T04已建的2个）。

### 6.5 全局浮动按钮（4.5，4个，低复杂度）

| 组件 | 功能 | 原版文件 | iOS状态 |
|------|------|---------|---------|
| GlobalLLMEntryButton | 全局LLM控制台入口 | components/global/GlobalLLMEntryButton.vue | ❌缺失 |
| GlobalLLMFloatingButton | 全局LLM浮动按钮 | components/global/GlobalLLMFloatingButton.vue | ❌缺失 |
| PromptPlazaEntryButton | 提示词广场入口 | components/global/PromptPlazaEntryButton.vue | ❌缺失 |
| PromptPlazaFAB | 提示词广场浮动按钮 | components/global/PromptPlazaFAB.vue | ❌缺失 |

**要补**：4个浮动按钮，用户可从任意页面快速进入LLM控制台/提示词广场。

### 6.6 知识图谱补写操作（4.6，P3，中复杂度）

| 维度 | 内容 |
|------|------|
| 原版实现 | `api/knowledgeGraph.ts` |
| iOS现状 | 端点已定义但Store未全部接线 |
| 原版操作（必须接线） | PUT保存 / generate / starTriple / inferNovel / revokeInference |
| 核验 | 知识图谱页面能完成保存/生成/星标/推理/撤销操作 |

### 6.7 其他（4.7，低复杂度）

- Autopilot章节流改纯SSE（阶段1后如仍有轮询残留）
- Debug工具（CharacterSchedulerSimulator）
- KnowledgeJsonView（JSON查看mode）
- 单元测试

### 阶段4 执行流程（建议按复杂度分批）

**批次1（低复杂度，先跑通）**：4.1 voiceApi + 4.5 浮动按钮4个 + 4.6 知识图谱写操作
**批次2（中复杂度）**：4.4 Autopilot 4组件 + 4.3 工作台中低优先级组件
**批次3（高复杂度）**：4.2 世界线DAG重写 + 4.3 工作台高优先级（ActPlanningModal/NarrativeDashboardPanel）
**批次4（收尾）**：4.7 其他

每个批次走完整SOP：工程师读原版事实表→主理人确认→实现→QA验收。

### 派工prompt模板（阶段4复用T05模式）

```
你是仓颉iOS移植项目的工程师 寇豆码（Kou）。这是移植任务，不是新开发。

## 任务：阶段4.X [具体子项]

## 第一步：读原版输出事实表（机制1）
[必读原版文件清单]
[必读iOS现有文件]

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
[见第八节12条]

## ⚠️ 新建View前必须Grep全项目查同名struct（教训10）
```

---

## 四-A、后端信息（重要）

- **后端是原项目 PlotPilot 的 Python/FastAPI 后端，已部署云端，零改动**
- 我们只做 iOS 前端移植，对接已部署的后端
- 后端所有接口都已存在（原版 Vue 在用），我们按原版方式调即可
- **不需要碰后端代码，不需要部署后端，后端已经在跑了**
- 后端 API base URL：用户在iOS设置页配置（SettingsStore管理，UserDefaults持久化）
- 用户原话："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变"

---

## 七、防砍功能约束 6 道机制（铁律，每阶段必须套用）

详见 `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`。简表：

1. **强制先读原版再动手**：工程师动手前必须Read原版文件，输出"原版做了什么"事实表，主理人确认才进实现
2. **PRD固化功能清单checklist**：产品经理出PRD时列功能清单，每项标原版文件+行号
3. **架构师出接口契约表**：每个API/SSE事件/数据模型都标原版文件+行号
4. **实现者逐条标注原版行号**：代码注释里写对应的原版文件:行号
5. **QA按原版清单逐项验收**：QA独立读代码验证，不rubber-stamp工程师自报，缺一条即FAIL
6. **派工prompt写死6条铁律**

**阶段3执行情况**：P0+T03+T04+T05全程套用6道机制，QA两轮验收全部PASS，0砍功能。T05 QA第1轮抓出22项砍功能（寇豆码自报305/305实际283/305），返工后第2轮确认305/305。**防砍机制5价值充分体现。**

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
- **最新成功CI**：#27（commit 7ca6d98，T04最终状态，success）
- **T05+阶段4的CI尚未产生**——下一次push将触发新CI

### CI 失败排查方法（前台盯CI）
```bash
cd "D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios"

# push后查CI状态（token从git remote提取，不写明文）
python -c "
import urllib.request, json, re, subprocess
url = subprocess.check_output(['git','remote','get-url','origin'], text=True).strip()
m = re.search(r'x-access-token:([^@]+)@', url)
token = m.group(1) if m else ''
req = urllib.request.Request('https://api.github.com/repos/Da-AiXZ/CangJie/actions/runs?per_page=3', headers={'Authorization':'token '+token,'Accept':'application/vnd.github+json','User-Agent':'ci-check'})
data = json.load(urllib.request.urlopen(req))
for r in data['workflow_runs'][:3]:
    print(f\"#{r['run_number']} | sha={r['head_sha'][:7]} | status={r['status']} | conclusion={r['conclusion']} | run_id={r['id']}\")
"
```

---

## 十、全部教训（血泪，下一任必读）

### 阶段3早期教训（1-7条，v6已记录）

1. **Swift catch块 error 是常量**：catch块内 `error` 是隐式常量，不可赋值
2. **Codable CodingKeys 必须覆盖所有存储属性**
3. **if let 绑定要求 Optional 类型**
4. **类型不能重复声明**：ChapterElementCreate 在两个文件都声明 → 删掉旧声明
5. **补字段要同步调用处**
6. **交接文档不能写token明文**：GitHub secret scanning 会拦截
7. **原版文件名可能与PRD不同**

### T04教训（8-9条，v7已记录）

8. **自定义 init(from decoder:) 会抑制 memberwise init 合成**
   - 一旦为 struct 写了自定义 `init(from decoder:)`，编译器不再合成默认 memberwise init
   - 修复：显式补一个 memberwise init
9. **SugiyamaLayout.LayoutNode(输入) vs PositionedNode(输出) 类型区分**

### T05教训（本版新增，第10条）

10. **新建View前必须Grep全项目查同名struct**
    - T05在 `Views/Autopilot/` 新建 `StoryNavigatorView`，但 `Views/Workbench/` 已有同名旧版
    - 两个同名struct → Swift报 "Invalid redeclaration" → **整个项目无法编译**
    - 寇豆码自报305/305时没发现这个编译错误，QA第2轮核验才抓出来
    - 修复：Autopilot版重命名为 `EvolutionNavigatorView` + 改1处调用
    - **阶段4铁律**：每新建一个View文件前，必须 `Grep "struct XXXView" Cangjie/` 确认无同名
    - **防砍机制补充**：QA验收必须包含"编译风险扫描"项，不能只查功能对齐度

---

## 十一、项目结构（T05完成后）

```
cangjie-ios/
├── Cangjie/
│   ├── App/
│   ├── Models/                 # 24+ 数据模型
│   │   ├── ManuscriptModels.swift（T05新建）
│   │   ├── AntiAIModels.swift（T05改）
│   │   ├── EvolutionModels.swift（T05改，+PlotOutlineDTO等）
│   │   ├── GovernanceModels.swift（T05改，+chapterBudgetPreview/promiseHitRate/GovernanceIssueDTO/ChapterNarrativeBudgetDTO）
│   │   ├── SandboxModels.swift（T05改）
│   │   ├── BibleModels.swift（T05改，+TimelineNoteDTO memberwise init）
│   │   └── ... 其他模型
│   ├── Networking/             # APIClient, APIEndpoint（T05已补5端点）
│   ├── SSE/
│   ├── Theme/
│   ├── Utils/
│   ├── Resources/
│   ├── ViewModels/
│   │   ├── AntiAIStore.swift（T05新建）
│   │   ├── EvolutionStore.swift（T05改，+loadSetupAnchors 5路并行）
│   │   ├── ForeshadowStore.swift（T05改）
│   │   ├── PropStore.swift（T05改）
│   │   ├── WorkbenchStore.swift（T05改，+tick NotificationCenter）
│   │   └── ... 其他Store
│   └── Views/
│       ├── Panels/
│       │   ├── ForeshadowLedgerPanel.swift（T05改，+删除确认+帮助tooltip）
│       │   ├── PropManagerPanel.swift（T05改，+用法提示+骨架屏）
│       │   ├── StoryEvolutionPanel.swift（T05改，司令塔10锚点+状态连续性+世界线简要+风险队列+issues）
│       │   ├── ChroniclesPanel.swift（T05改，+Note显示）
│       │   ├── AntiAIPanel.swift（T05改）
│       │   ├── DialogueSandboxPanel.swift（T05改，+currentChapterNumber从NovelStore）
│       │   ├── PropDetailDrawer.swift（T05新建）
│       │   └── TimelinePanel.swift（T05新建，用BibleDTO复用）
│       ├── Autopilot/
│       │   ├── EvolutionNavigatorView.swift（T05新建，原名StoryNavigatorView已改名避重复）
│       │   ├── StoryTimelineView.swift（T05新建）
│       │   ├── StoryDetailPanelView.swift（T05新建）
│       │   └── ... 其他Autopilot View
│       └── ... 其他Views
├── docs/
│   ├── 全项目核验报告_2026-06-25.md（第六任主理人核验报告）
│   ├── stage3_qa_report_t05_round2.md（T05 QA第2轮，305/305 PASS）
│   ├── stage3_facts_table_t05.md（T05事实表305条）
│   └── ... 其他文档
├── .github/workflows/build.yml
├── scripts/
└── project.yml
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
- **重启恢复**：WorkBuddy重启后团队可能丢失，需重新TeamCreate+spawn成员

### 阶段3全部教训（见第十节，10条）

---

## 十三、用户信息

- **设备**：iPad Pro 2021 (M1), iOS 16.6.1, TrollStore 侧载
- **后端**：已部署云端（PlotPilot Python/FastAPI），零改动
- **LLM**：已配 DeepSeek + agnes 等端点，测试连通性通过
- **用户期望**：直接按原项目方法接好前端，后端不变，不要自己发明流程
- **用户容忍度**：对砍功能零容忍，前两任因砍功能被叫停做了审计报告
- **用户要求**：严格按《AI移植项目防砍功能约束方法.md》6道机制执行
- **用户原话**："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变"
- **用户特别交代**：交接文档要把所有东西交代清楚，防止下一个AI看了一知半解瞎改
- **token铁律**：token不写进任何文档明文，GitHub secret scanning会拦截push
- **阶段4决策**：用户确认阶段4和阶段3同量级需写交接文档；T05和阶段4一起干（T05不单独push）

---

## 十四、阶段3已完成内容详细清单（供阶段4参考，避免重复造轮子）

### P0批次（16文件）— 见v7交接文档
### T03批次（4文件）— 见v7交接文档
### T04批次（13文件）— 见v7交接文档

### T05批次（22文件，约5000行新代码）

**模型层6文件**：
- ManuscriptModels.swift（新，86行）
- AntiAIModels.swift（改，+154行）
- EvolutionModels.swift（改，+352行，+PlotOutlineDTO/PlotOutlineStageDTO/GeneratePlotOutlineResponse）
- GovernanceModels.swift（改，+125行，+chapterBudgetPreview/promiseHitRate/GovernanceIssueDTO/ChapterNarrativeBudgetDTO）
- SandboxModels.swift（改，+59行）
- BibleModels.swift（改，+8行，+TimelineNoteDTO memberwise init）

**API层**：
- APIEndpoint.swift（改，+90行，+5端点）

**Store层5文件**：
- AntiAIStore.swift（新，105行）
- EvolutionStore.swift（改，+105行，+loadSetupAnchors 5路并行+applyOverrides传实际chapterNumber）
- ForeshadowStore.swift（改，+15行）
- PropStore.swift（改，+49行）
- WorkbenchStore.swift（改，+22行，+tick NotificationCenter）

**View层11文件**：
- 6 Panel改：ForeshadowLedgerPanel(+620行)/PropManagerPanel(+486行)/StoryEvolutionPanel(+847行)/ChroniclesPanel(+256行)/AntiAIPanel(+518行)/DialogueSandboxPanel(+413行)
- PropDetailDrawer.swift（新，216行）
- TimelinePanel.swift（新，236行，用BibleDTO复用）
- EvolutionNavigatorView.swift（新，220行，原名StoryNavigatorView已改名）
- StoryTimelineView.swift（新，200行）
- StoryDetailPanelView.swift（新，191行）

---

## 十五、一句话总结

**阶段1+2+3全部完成（T05功能305/305 QA两轮核验通过，编译错误已修复），T05代码在本地未push（和阶段4一起干）。下一步推进阶段4（7项33个组件/操作），按本交接文档第六节执行，严格按防砍6道机制，不许砍功能。阶段4完成后覆盖度~98%。**

---

**交接完毕。代码 = SOP(团队)。下一任加油，用户对砍功能零容忍，token不写明文，新建View前必须Grep查同名。**

**阶段4启动口诀：读原版组件 → 输出事实表 → 主理人决策 → 实现（Grep查同名！） → QA（含编译风险扫描） → push → 盯CI**
