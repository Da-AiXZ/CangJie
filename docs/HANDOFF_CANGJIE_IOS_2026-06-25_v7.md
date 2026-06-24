# 仓颉 iOS 移植项目交接文档 v7（T04完成版，下一任AI读完即可接手T05）

> **交接日期**：2026-06-25 03:00（v6 → v7 升级，T04完成后写交接防中断）
> **交接人**：齐活林（Qi）· 交付总监（第五任主理人，本会话接手第四任的v6）
> **状态**：阶段1+2+3(P0+T03+T04)已完成编译通过（CI#27 success），**仅剩T05一个任务**
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜瞎改。本文件是唯一权威交接，读完即可接手。**用户特别交代：所有东西都要写清楚，防止下一个AI一知半解瞎几把改。**
> **v6 → v7 变更**：T04完成（CI#27 success，commit 7ca6d98）；补充T04全部决策+新教训+T05详细启动指令

---

## ⚡ 下一任AI接手速查（先读这段）

### 你要做什么
推进阶段3的最后一个任务 **T05（六面板全CRUD）**，P2优先级。完成后阶段3全部结束，覆盖度~93%。

### 你要做之前先读（按顺序）
1. **本交接文档v7**（你现在在读）
2. `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`（防砍6道机制，铁律）
3. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md`（阶段3的T05范围）
4. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md`（157条功能清单，T05在3.6部分）
5. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md`（157条契约表+5任务分解，T05的契约表在3.6部分）
6. `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_t04.md`（参考T04事实表格式，T05照此格式输出）

### 工作流（标准SOP，严格按防砍6道机制）
```
T05走：工程师读原版输出事实表(机制1) → 主理人确认 → 工程师实现标注原版行号(机制4)+6铁律(机制6) → QA独立验收(机制5) → 主理人push+盯CI
```
PRD和系统设计已经完成（许清楚+高见远做过了），不用重做。直接从工程师读原版开始。

### 团队已存在
团队名 `software-cangjie-stage3`（会话重启可能需重新TeamCreate）。4个成员：
- 许清楚（software-product-manager）— PRD已完成，T05不用再派
- 高见远（software-architect）— 系统设计已完成，T05不用再派
- 寇豆码（software-engineer）— P0+T03+T04已完成，可继续派T05
- 严过关（software-qa-engineer）— P0+T03+T04验收完成，可继续派T05验收

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
| **当前会话工作目录** | `D:/111/2026-06-25-02-09-21`（空目录，实际代码不在） |
| **防砍约束方法** | `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md` |
| **阶段补齐核验清单** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md` |
| **阶段3 PRD（157条）** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md` |
| **阶段3系统设计（157契约表+5任务）** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md` |
| **P0事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_p0.md` |
| **P0 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_p0.md` |
| **T03事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_t03.md` |
| **T03 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_t03.md` |
| **T04事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_t04.md` |
| **T04 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_t04.md` |
| **历史交接文档v3-v6** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/HANDOFF_CANGJIE_IOS_2026-06-2X_vX.md` |
| **审计报告1（差异）** | `C:/Users/netease/Desktop/仓颉iOS移植版差异审计报告.md` |
| **审计报告2（深度）** | `C:/Users/netease/Desktop/仓颉iOS已实现功能对齐深度审计.md` |
| **项目记忆** | `D:/111/2026-06-25-02-09-21/.workbuddy/memory/2026-06-25.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-25-02-09-21`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：已存在 git remote URL 中（用 `git remote get-url origin` 提取，Python脚本里用re.search提取，不输出明文）。**不要写进交接文档明文**，GitHub secret scanning会拦截push
- remote URL 格式：`https://x-access-token:<TOKEN>@github.com/Da-AiXZ/CangJie.git`
- **教训**：交接文档v3/v4曾把token明文写入，导致push被GitHub secret scanning拦截，已用sed替换为占位符并amend commit。**下一任绝对不要在文档里写token明文。**

**查CI/拉日志的Python脚本模板**（token从git remote提取，不写明文）：
```python
import urllib.request, json, re, subprocess
url = subprocess.check_output(['git','remote','get-url','origin'], text=True).strip()
m = re.search(r'x-access-token:([^@]+)@', url)
token = m.group(1) if m else ''
# 然后用token调GitHub API
```

---

## 四、当前完成状态（2026-06-25 03:00）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）

73项功能点全实现+QA返工通过。Bible SSE分3步stage+13类SSE事件+Autopilot chapter-stream 9类事件+workbench单章生成SSE+onStreamEnd回调+approval_required/error/done显式cancel SSE。

### ✅ 阶段2已完成（commit 043b402，CI #22编译通过）

6项全PASS，164/164=100%对齐度。CircuitBreaker字段+BibleStatus/Feedback字段+提示词广场17模型23API+Autopilot启动参数+轮询退避+主题anchor黑金。

### ✅ 阶段3 P0批次已完成（commit aa49a07，CI #24编译通过）

AI Invocation审批系统4层全量新建+向导补第4步剧情总纲。16文件8640行，QA独立验收108/108 PASS。

### ✅ 阶段3 T03已完成（commit 723ddc6，CI #25编译通过）

三个Mock面板接真实API，硬编码全部清除。4文件1388行，QA独立验收84项0 FAIL。

### ✅ 阶段3 T04已完成（commit 7ca6d98，CI #27编译通过）

DAG节点交互+题材包接API。新增6文件+修改7文件，共1648行新代码+337KB资源。QA独立验收119/119 PASS，12条决策全执行。

### 📋 阶段3剩余任务（仅T05）

| 任务 | 优先级 | 内容 | 状态 |
|------|--------|------|------|
| T05 | P2 | 六面板全CRUD（3.6 伏笔/道具/演化/编年史/AntiAI/对话沙盒） | **待推进（阶段3最后一个任务）** |

**完整 commit 链（main分支，已push，从T04起）**：

| commit | 阶段 | 内容 |
|--------|------|------|
| 7ca6d98 | 阶段3 T04 | CI#26编译错误修复（2处：DagRegistryGapItem补memberwise init + hitTest返回类型） |
| 92481bf | 阶段3 T04 | T04主体（15文件 +4816/-97行） |
| 4d6edc0 | 交接 | 交接文档v6终极版 |
| 723ddc6 | 阶段3 T03 | 三个Mock面板接真实API |
| aa49a07 | 阶段3 P0 | CI#23修复 |
| 5bd2b44 | 阶段3 P0 | T01基础层+T02 AI Invocation+向导 |
| 043b402 | 阶段2 | CI#21修复 |
| b130b0c | 阶段2 | 主体 |
| 39282d4 | 阶段1 | CI#18修复 |

**CI 历史（#25-#27，T04相关）**：

| CI# | sha | 结论 | 说明 |
|-----|-----|------|------|
| #27 | 7ca6d98 | ✅ success | T04最终状态（最新成功CI） |
| #26 | 92481bf | ❌ failure | T04首次2编译错误 |
| #25 | 723ddc6 | ✅ success | T03最终 |

**最新成功CI**：#27（commit 7ca6d98，success）

**IPA artifact**：CI#27有artifact可TrollStore侧载实测（在GitHub Actions页面下载）。

**预期T05完成后覆盖度**：~93%

---

## 五、阶段3全部决策记录（下一任必读，不可推翻）

### 5.1 主理人8项决策（许清楚PRD阶段产出，v6已记录）

| # | 决策 | 执行方式 |
|---|------|---------|
| Q1 | AI Invocation headless自动推进 | **不实现** advanceHeadlessSession/scheduleHeadlessAdvance |
| Q2 | 生成轮询间隔 | 硬编码 `generationPollMs = 2000` |
| Q3 | 向导第4步本地缓存 | UserDefaults，key=`wizard_ui_cache_{novelId}` |
| Q4 | 步骤跳转权限 | maxVisitedStep模式 |
| Q5 | 3.6六面板CRUD原版行号 | 架构师已补标 |
| Q6 | DAG提示词广场跳转 | 阶段2已建PromptPlazaStore，用NavigationLink跳转 |
| Q7 | QualityGuardrailPanel五维度来源 | guardrailApi.check() POST /novels/{id}/guardrail/check |
| Q8 | featureFlags | iOS不设flag，aiInvocationDebug=false，variableCenterDebugPanels=true |

### 5.2 主理人7项疑问决策（寇豆码P0事实表阶段产出，v6已记录）

| # | 疑问 | 决策 |
|---|------|------|
| 疑问1 | showDebugPanel行为 | 无条件设visible=true |
| 疑问2 | title计算属性 | 包含 |
| 疑问3 | plotOutlineModel工具函数归属 | 放入PlotOutlineModels.swift，15个全移植 |
| 疑问4 | WizardUiCachePayload字段 | 保留8字段 |
| 疑问5 | 重复JSON解析函数 | 通用复用InvocationOutput.swift |
| 疑问6 | Bible SSE接线点 | 已接线 |
| 疑问7 | 章节SSE终止消费 | Task.cancel()或标志位 |

### 5.3 主理人6项疑问决策（寇豆码T03事实表阶段产出，v6已记录）

| # | 疑问 | 决策 |
|---|------|------|
| T03疑问1 | era硬编码'ancient' | iOS也硬编码 |
| T03疑问2 | scene_type硬编码'auto' | 保持 |
| T03疑问3 | chapterId来源 | 用NovelStore.currentChapter?.id |
| T03疑问4 | ConsistencyReportPanel内嵌 | 保持iOS分开独立面板 |
| T03疑问5 | ForeshadowChapterSuggestionsPanel内嵌 | T03只做元素CRUD，伏笔建议保持独立 |
| T03疑问6 | guardrailSnapshot novelId=slug | 照做 |

### 5.4 架构师校正的3.6原版文件名（重要，T05别搞错）

| PRD名称 | 实际原版文件名 | 路径 |
|---------|--------------|------|
| ForeshadowLedger.vue | ForeshadowLedgerPanel.vue | components/workbench/ |
| PropManagerPanel.vue | ManuscriptPropsPanel.vue | components/workbench/ |
| ChroniclesPanel.vue | HolographicChroniclesPanel.vue | components/workbench/ |
| AntiAIPanel.vue | AntiAIDashboard.vue | components/workbench/promptPlaza/ |
| DialogueSandboxPanel.vue | DialogueCorpus.vue | components/workbench/ |

### 5.5 T04主理人12项决策（寇豆码T04事实表阶段产出，本版新增）

**这12条决策已执行完毕，T05不涉及，但作为决策记录保留：**

| # | 疑问 | 决策 | 执行证据 |
|---|------|------|---------|
| T04-1 | updateNodeConfig走不走API | **照搬原版内存更新，不走PUT API**（原版dagStore.ts:290-305注释明确"不走数据库"） | DAGStore.updateNodeConfig纯内存修改 |
| T04-2 | AutopilotStatus缺3个写作遥测字段 | **新增3个Optional字段**：accumulatedWords/chapterTargetWords/contextTokens | AutopilotModels.swift +3字段 |
| T04-3 | 题材包加载方式 | **本地打包**（对齐原版cnMarket.ts import行为），bundle.json复制到Resources | Resources/builtin_cn_v1.bundle.json + TaxonomyStore.loadBuiltinCNBundle |
| T04-4 | TaxonomyModels schemaVersion类型 | **改为Int**（对齐原版types.ts:31和bundle.json:3），T01遗留bug | TaxonomyBundle + TaxonomyBundleMeta schemaVersion: Int |
| T04-5 | promptPlazaBridge iOS等价物 | **getCpmsKey实现 + "在广场编辑"按钮**（NavigationLink或提示） | NodeEditorDrawer.getCpmsKey + alert提示 |
| T04-6 | NodeDetailPanel用modal还是sheet | **用.sheet**（对齐技术约定） | .sheet呈现 |
| T04-7 | NodeContextMenu实现方式 | **自定义overlay**（不用原生.contextMenu，对齐原版自定义样式） | LongPressGesture + overlay定位 |
| T04-8 | NodeEditorDrawer触发入口 | **原版未接入UI，iOS从NodeDetailPanel底部"配置运行参数"按钮补齐** | NodeDetailPanel底部按钮触发NodeEditorDrawer |
| T04-9 | 写作遥测轮询 | **2500ms独立轮询**（不复用AutopilotStore，对齐原版usePolling） | NodeDetailPanel内部Task轮询 |
| T04-10 | 写作遥测404处理 | **照搬原版不停止轮询**（显示"该书暂无托管状态"但继续） | catch .notFound → 显示提示但不cancel Task |
| T04-11 | CATEGORY_LABELS | **新增到DAGModels.swift** | CATEGORY_LABELS映射 |
| T04-12 | NodePort/NodeConfig是否已存在 | **已存在于DAGModels.swift，直接用**（纠正寇豆码事实表C.2错误），仅新增NodeMeta/NodePromptLive/DagRegistryLinkageResponse | 复用现有NodePort:67/NodeConfig:95/NodeDefinition:132 |

### 5.6 架构师标注的T05待明确事项（T05实现时注意）

1. **题材包API端点**：✅ T04已决策本地打包（决策T04-3），T05不涉及
2. **DAG节点API端点路径**：✅ T04已实现
3. **3.6演化/AntiAI/对话沙盒API端点**：T05实现者开工前必须先Read原版完整源码输出事实表（机制1）。T01未建这3个面板的端点，T05需补建到APIEndpoint.swift
4. **PropDetailDrawer独立组件**：iOS当前未拆分，T05需新建

---

## 六、T05详细启动指令（下一任AI直接执行）

### T05 六面板全CRUD（P2，阶段3最后一个任务）

**范围（6个面板，30条PRD）**：

| 面板 | 原版文件（已校正名5.4） | 要补 |
|------|-------------------|------|
| 伏笔 | ForeshadowLedgerPanel.vue | CRUD+优先级星标+消费弹窗+筛选+Tab |
| 道具 | ManuscriptPropsPanel.vue + PropDetailDrawer.vue | CRUD+事件创建+详情抽屉 |
| 演化 | StoryEvolutionPanel.vue | 快照交互+闸门+覆盖+叙事时间线 |
| 编年史 | HolographicChroniclesPanel.vue | 双螺旋布局+时间线编辑+回滚 |
| AntiAI | AntiAIDashboard.vue | 七层防御+扫描+统计+分类+规则+白名单 |
| 对话沙盒 | DialogueCorpus.vue | 语料筛选+生成器+anchor读写 |

**T01基础层已完成**：ForeshadowModels.swift+PropModels.swift已补字段，APIEndpoint.swift已+端点

**T01已建的模型清单（T05直接用）**：
- ForeshadowModels.swift：ForeshadowEntry + CreateRequest(含suggestedResolveChapter/resolveChapterWindow/importance) + UpdateRequest
- PropModels.swift：PropDTO + PropEventDTO + Create/Patch + PropCategory/PropLifecycleState枚举 + isPriorityForChapter字段
- APIEndpoint已+：Foreshadow端点(foreshadowStats等) + Prop端点(get/update/delete/events/createEvent)

**⚠️ T05演化/AntiAI/对话沙盒**：这3个面板的原版API端点T01未建（待明确事项5.6第3条）。T05开工前必须先Read原版完整源码输出事实表，确认API端点后再补建到APIEndpoint.swift。

**现有Store清单（22个，T05实现时按需依赖，先Read确认现有方法）**：
AIInvocationStore, AutopilotStore, BibleStore, CastStore, DAGStore, EvolutionStore, ExportStore, ForeshadowStore, GovernanceStore, KnowledgeGraphStore, LLMControlStore, MonitorStore, NovelStore, OnboardingStore, PromptPlazaStore, PropStore, SettingsStore, SnapshotStore, StatsStore, StructureStore, TraceStore, WorkbenchStore

**⚠️ T05注意**：ForeshadowStore/PropStore/EvolutionStore已存在。T05实现时先Read这些Store确认现有方法，按需扩展，不要重复建。

**涉及文件（6文件全改+1新组件）**：
1. `Views/Panels/ForeshadowLedgerPanel.swift`（改）
2. `Views/Panels/PropManagerPanel.swift`（改，+PropDetailDrawer新建）
3. `Views/Panels/StoryEvolutionPanel.swift`（改）
4. `Views/Panels/ChroniclesPanel.swift`（改）
5. `Views/Panels/AntiAIPanel.swift`（改）
6. `Views/Panels/DialogueSandboxPanel.swift`（改）
7. `Views/Panels/PropDetailDrawer.swift`（新，待明确事项5.6第4条）

**原版对照文件**（原版前端根目录 `D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`）：
- `components/workbench/ForeshadowLedgerPanel.vue`
- `components/workbench/ManuscriptPropsPanel.vue`
- `components/workbench/PropDetailDrawer.vue`（独立组件）
- `components/workbench/StoryEvolutionPanel.vue`
- `components/workbench/HolographicChroniclesPanel.vue`
- `components/workbench/promptPlaza/AntiAIDashboard.vue`（注意在promptPlaza子目录）
- `components/workbench/DialogueCorpus.vue`

### T05 执行流程（完整SOP）

1. **主理人确认团队存在**（或重新TeamCreate software-cangjie-stage3）
2. **派寇豆码读原版输出事实表（机制1）**：
   - Read原版7个Vue源码（ForeshadowLedgerPanel/ManuscriptPropsPanel/PropDetailDrawer/StoryEvolutionPanel/HolographicChroniclesPanel/AntiAIDashboard/DialogueCorpus）
   - Read iOS现有6个Panel + 相关Store（ForeshadowStore/PropStore/EvolutionStore）
   - 落盘 `docs/stage3_facts_table_t05.md`
   - 事实表格式参考 `docs/stage3_facts_table_t04.md`
3. **主理人确认事实表**，对疑问做决策（参考T04的12条决策模式）
4. **派寇豆码实现**（机制4标注原版行号+机制6写死6铁律）
5. **派严过关独立验收**（机制5，落盘 `docs/stage3_qa_report_t05.md`）
6. **主理人push+盯CI**（见第九节CI排查方法）

### 派工prompt模板（T05，复用T04模式）

```
你是仓颉iOS移植项目的工程师 寇豆码（Kou）。这是移植任务，不是新开发。

## 任务：T05 六面板全CRUD

## 第一步：读原版输出事实表（机制1）
[必读原版文件清单：7个Vue源码]
[必读iOS现有文件：6个Panel + ForeshadowStore/PropStore/EvolutionStore]

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

**阶段3执行情况**：P0+T03+T04全程套用6道机制，QA独立验收全部PASS，0砍功能。事实表阶段多次抓出系统设计遗漏，体现机制1价值（T04事实表抓出NodePort已存在的错误）。

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

### CI 失败排查方法（前台盯CI）
```bash
# 工作目录先切到代码目录
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

# 盯CI直到完成
python -c "
import urllib.request, json, re, subprocess, time
url = subprocess.check_output(['git','remote','get-url','origin'], text=True).strip()
m = re.search(r'x-access-token:([^@]+)@', url)
token = m.group(1) if m else ''
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
import urllib.request, json, re, subprocess, zipfile, io
url = subprocess.check_output(['git','remote','get-url','origin'], text=True).strip()
m = re.search(r'x-access-token:([^@]+)@', url)
token = m.group(1) if m else ''
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

## 十、阶段3全部教训（血泪，下一任必读）

### 阶段3早期教训（v6已记录，1-7条）

1. **Swift catch块 error 是常量**：catch块内 `error` 是隐式常量，不可赋值。错误写法：`catch { error = errorText(error) }` → 编译失败。正确：`catch { self.errorMessage = errorText(error) }`
2. **Codable CodingKeys 必须覆盖所有存储属性**：存储属性名≠JSON key时必须显式映射
3. **if let 绑定要求 Optional 类型**：非Optional的判断用 `if !someString.isEmpty`
4. **类型不能重复声明**：ChapterElementCreate 在两个文件都声明 → 删掉旧声明
5. **补字段要同步调用处**：ForeshadowModels.swift 补字段但 ForeshadowStore.swift 调用处没更新 → missing arguments
6. **交接文档不能写token明文**：GitHub secret scanning 会拦截含 ghp_xxx 的push
7. **原版文件名可能与PRD不同**：3.6六面板的原版文件名架构师已校正（见5.4）

### T04新教训（本版新增，8-9条）

8. **自定义 init(from decoder:) 会抑制 memberwise init 合成**
   - Swift 规则：一旦为 struct 写了自定义 `init(from decoder: Decoder) throws`，编译器不再合成默认 memberwise init `init(field1:field2:)`
   - 症状：调用处报 `extra arguments` + `missing argument for parameter 'from'`
   - 修复：显式补一个 memberwise init
   - 案例：DagRegistryGapItem（DAGModels.swift:570）有自定义 decoder init，DAGStore.swift:222 调用 `DagRegistryGapItem(nodeId:nodeType:)` 失败 → CI#26编译错误
   - **T05注意**：所有有自定义 init(from:) 的 Codable struct，如果代码里需要用 memberwise init 构造（非从JSON解码），必须显式补 memberwise init

9. **SugiyamaLayout.LayoutNode(输入) vs PositionedNode(输出) 类型区分**
   - `LayoutNode` 是布局**输入**（只有 id/width/height，无坐标）
   - `PositionedNode` 是布局**输出**（有 id/x/y/layer 坐标）
   - `LayoutResult.nodes: [PositionedNode]`（不是LayoutNode）
   - 症状：hitTest 函数返回类型声明为 `LayoutNode?` 但 return 的是 `PositionedNode` → 类型不匹配编译错误
   - 案例：DAGCanvasView.swift:365 hitTest → CI#26编译错误
   - **T05注意**：如果T05涉及布局相关代码，注意区分输入/输出类型

---

## 十一、项目结构

```
cangjie-ios/
├── Cangjie/
│   ├── App/                    # CangjieApp.swift, AppState.swift
│   ├── Models/                 # 24+ 数据模型
│   │   ├── AIInvocationModels.swift（阶段3 P0新建）
│   │   ├── PlotOutlineModels.swift（阶段3 P0新建）
│   │   ├── ChapterElementModels.swift（阶段3 P0新建）
│   │   ├── TaxonomyModels.swift（阶段3 T04改 schemaVersion Int）
│   │   ├── MonitorModels.swift（阶段3 +GuardrailCheck）
│   │   ├── ForeshadowModels.swift（阶段3 +字段，T05用）
│   │   ├── PropModels.swift（阶段3 +字段，T05用）
│   │   ├── DAGModels.swift（阶段3 T04 +NodeMeta +NodePromptLive +DagRegistryLinkageResponse +CATEGORY_LABELS +DagRegistryGapItem memberwise init）
│   │   ├── AutopilotModels.swift（阶段3 T04 +3写作遥测字段）
│   │   └── ... 其他模型
│   ├── Networking/             # APIClient, APIEndpoint（T05演化/AntiAI/对话沙盒端点待补建）
│   ├── SSE/                    # SSEClient, SSEStreamRegistry
│   ├── Theme/                  # Theme.swift（4模式+4字号含anchor黑金）
│   ├── Utils/
│   │   ├── DateFormatter+ISO.swift（CangjieDecoder.shared）
│   │   ├── InvocationOutput.swift（阶段3 P0新建）
│   │   ├── SugiyamaLayout.swift（LayoutNode输入 vs PositionedNode输出，教训9）
│   │   └── ...
│   ├── Resources/
│   │   ├── builtin_cn_v1.bundle.json（阶段3 T04新增，337KB题材包）
│   │   ├── Info.plist, Cangjie.entitlements, Assets.xcassets
│   ├── ViewModels/
│   │   ├── AIInvocationStore.swift（阶段3 P0新建）
│   │   ├── OnboardingStore.swift（阶段3 P0改）
│   │   ├── WorkbenchStore.swift（阶段3 P0改）
│   │   ├── MonitorStore.swift（阶段3 T03改重写）
│   │   ├── DAGStore.swift（阶段3 T04改 +6方法：loadNodePromptLive/updateNodeConfig内存/loadNodeTypeRegistry/hydrateDagForNovel/selectNode/nodeTypeRegistry state）
│   │   ├── TaxonomyStore.swift（阶段3 T04新建，本地加载bundle.json）
│   │   ├── ForeshadowStore.swift（T05待扩展）
│   │   ├── PropStore.swift（T05待扩展）
│   │   ├── EvolutionStore.swift（T05待扩展）
│   │   └── ... 其他Store
│   └── Views/
│       ├── AIInvocation/AIInvocationReviewPanel.swift（阶段3 P0新建）
│       ├── Onboarding/
│       │   ├── PlotOutlineStep.swift（阶段3 P0新建）
│       │   └── OnboardingWizardView.swift（阶段3 P0改）
│       ├── Panels/
│       │   ├── QualityGuardrailPanel.swift（阶段3 T03改重写）
│       │   ├── ConsistencyReportPanel.swift（阶段3 T03改重写）
│       │   ├── ChapterElementPanel.swift（阶段3 T03改重写）
│       │   ├── ForeshadowLedgerPanel.swift（T05待改）
│       │   ├── PropManagerPanel.swift（T05待改，+PropDetailDrawer新建）
│       │   ├── StoryEvolutionPanel.swift（T05待改）
│       │   ├── ChroniclesPanel.swift（T05待改）
│       │   ├── AntiAIPanel.swift（T05待改）
│       │   ├── DialogueSandboxPanel.swift（T05待改）
│       │   └── PropDetailDrawer.swift（T05待新建）
│       ├── Autopilot/
│       │   ├── DAGCanvasView.swift（阶段3 T04改，集成3新View）
│       │   ├── NodeContextMenu.swift（阶段3 T04新建）
│       │   ├── NodeDetailPanel.swift（阶段3 T04新建）
│       │   ├── NodeEditorDrawer.swift（阶段3 T04新建）
│       │   └── ... 其他Autopilot View
│       ├── Taxonomy/MarketTaxonomyPicker.swift（阶段3 T04新建）
│       ├── Home/CreateNovelSheet.swift（阶段3 T04改，替换硬编码题材）
│       └── ... 其他Views
├── docs/                       # 所有文档（PRD/系统设计/事实表/QA报告/交接文档）
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
- **重启恢复**：WorkBuddy重启后团队可能丢失，需重新TeamCreate+spawn成员，任务清单也丢失需重建

### 阶段3新教训（见第十节，9条）

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
- **token铁律**：token不写进任何文档明文，GitHub secret scanning会拦截push

---

## 十四、阶段3已完成内容详细清单（供下一任参考，避免重复造轮子）

### P0批次已完成的16文件
- AIInvocationModels.swift：20模型+6Payload+2枚举(14状态)
- PlotOutlineModels.swift：DTO+缓存(8字段)+plotOutlineModel 15函数
- ChapterElementModels.swift：DTO+3枚举
- TaxonomyModels.swift：Bundle+Node+WritingProfile（T04改 schemaVersion Int）
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
- MonitorStore.swift：质量护栏+张力曲线+文风漂移
- QualityGuardrailPanel.swift：六维度条形图+总分圆形+违规折叠+advise/enforce模式
- ConsistencyReportPanel.swift：issues/warnings/suggestions三分组+严重程度着色
- ChapterElementPanel.swift：5个CRUD端点+人物/地点/其他三分组+Bible ID→name映射

### T04已完成的13文件（6新+7改）

**新增6文件**：
1. `ViewModels/TaxonomyStore.swift`（139行）— 本地题材包加载 + cnMarket.ts辅助函数（flattenRootsForSearch/pickLocaleLabel等）
2. `Views/Autopilot/NodeContextMenu.swift`（134行）— 自定义overlay右键菜单（header+divider+2菜单项）
3. `Views/Autopilot/NodeDetailPanel.swift`（624行）— 7区块节点详情面板（状态条/基本信息/CPMS提示词/预览/端口/写作遥测/默认下游）+2500ms独立轮询+404不停止
4. `Views/Autopilot/NodeEditorDrawer.swift`（263行）— 5运行参数配置抽屉（temperature/maxTokens/timeout/maxRetries/modelOverride）+CPMS关联+广场跳转
5. `Views/Taxonomy/MarketTaxonomyPicker.swift`（488行）— 题材选择器（搜索+大类+主题+4列分类信息+世界观基调+4卡片写作原则+6双向绑定）
6. `Resources/builtin_cn_v1.bundle.json`（337KB）— 从原版复制的题材包（14大类70+子主题）

**修改7文件**：
7. `Models/DAGModels.swift` — +NodeMeta +NodePromptLive +DagRegistryLinkageResponse +CATEGORY_LABELS +DagRegistryGapItem memberwise init；NodeConfig/DAGDefinition.nodes改var（支持内存更新）
8. `Models/TaxonomyModels.swift` — schemaVersion String→Int；+TaxonomyBundleMeta；+TaxonomyWritingProfile memberwise init
9. `Models/AutopilotModels.swift` — +accumulatedWords/chapterTargetWords/contextTokens（写作遥测3字段）
10. `ViewModels/DAGStore.swift` — +6个@Published（nodeTypeRegistry/registryLinkage/selectedNodeId/nodePromptLive/registryGaps等）+loadNodePromptLive/updateNodeConfig内存/loadNodeTypeRegistry/hydrateDagForNovel/selectNode
11. `Views/Autopilot/DAGCanvasView.swift` — 集成NodeDetailPanel/NodeContextMenu/长按手势，删除旧nodeDetailSheet，hitTest返回类型修复
12. `Views/Home/CreateNovelSheet.swift` — 删除硬编码Picker（8+6项），替换为MarketTaxonomyPicker
13. `Views/Autopilot/AutopilotConsoleView.swift` — 传递novelId给DAGCanvasView + 调用hydrateDagForNovel

### T04 MINOR观察项（如有，QA报告已记录，不阻断）

---

## 十五、一句话总结

**阶段1+2+3(P0+T03+T04)已完成编译通过（CI#27 success），仅剩T05（六面板全CRUD）按本交接文档第六节执行，严格按防砍6道机制，不许砍功能。T05完成后阶段3全部结束，覆盖度~93%。**

---

**交接完毕。代码 = SOP(团队)。下一任加油，用户对砍功能零容忍，token不写明文。**

**T05启动口诀：读原版7个Vue → 输出事实表 → 主理人决策 → 实现 → QA → push → 盯CI**
