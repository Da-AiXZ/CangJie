# 仓颉 iOS 移植项目交接文档 v5

> **交接日期**：2026-06-25 00:40（v4 → v5 升级）
> **交接人**：齐活林（Qi）· 交付总监（第四任主理人）
> **状态**：阶段1+2已完成，**阶段3 P0批次已完成并编译通过**，T03/T04/T05 待推进
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜瞎改。本文件是唯一权威交接，读完即可接手。
> **v4 → v5 变更**：阶段3 P0批次完成（AI Invocation审批系统+向导第4步），CI#24 success；补充所有决策记录+新教训+剩余任务详细说明

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
| **阶段3 PRD** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_prd.md` |
| **阶段3系统设计** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_system_design.md` |
| **阶段3 P0事实表** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_facts_table_p0.md` |
| **阶段3 P0 QA验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/stage3_qa_report_p0.md` |
| **项目记忆** | `D:/111/2026-06-24-22-39-38/.workbuddy/memory/2026-06-24.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-24-22-39-38`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：见项目memory或环境变量（**不要写进交接文档明文**，GitHub secret scanning会拦截push）
- remote URL 格式：`https://x-access-token:<TOKEN>@github.com/Da-AiXZ/CangJie.git`
- **教训**：交接文档v3/v4曾把token明文写入，导致push被GitHub secret scanning拦截，已用sed替换为占位符并amend commit

---

## 四、当前状态（2026-06-25 00:40）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）

73项功能点全实现+QA返工通过。Bible SSE分3步stage+13类SSE事件+Autopilot chapter-stream 9类事件+workbench单章生成SSE+onStreamEnd回调+approval_required/error/done显式cancel SSE。

### ✅ 阶段2已完成（commit 043b402，CI #22编译通过）

6项全PASS，164/164=100%对齐度。CircuitBreaker字段+BibleStatus/Feedback字段+提示词广场17模型23API+Autopilot启动参数+轮询退避+主题anchor黑金。

### ✅ 阶段3 P0批次已完成（commit aa49a07，CI #24编译通过）

**commit 链（main分支，已push）**：

| commit | 内容 |
|--------|------|
| aa49a07 | CI #23修复（6类编译错误：CodingKeys+catch块+删重复+补参数+if let） |
| 5bd2b44 | **阶段3 P0主体** T01基础层+T02 AI Invocation+向导 (31文件 +10388/-57行) |
| 043b402 | 阶段2最终状态（CI#22 success） |

**P0批次做了什么**（严格按防砍6道机制，108/108 QA PASS）：

| 模块 | 内容 | 对齐度 |
|------|------|--------|
| 3.1 AI Invocation 审批系统 | 4层全量新建：API层(20模型+10端点+6Payload+2枚举14状态) + Store层(18方法+16计算属性含title+2000ms轮询+监听) + Utils层(9函数+parseAttemptContent+recoverTruncatedArrayObject) + View层(15UI区块+350ms防抖) | 100% |
| 3.1 SSE approval_required接线 | 3处：Bible生成流 + 单章生成流 + 剧情总纲流 | 100% |
| 3.2 向导补第4步剧情总纲 | OnboardingStep改5步(plotOutline=4) + SSE流式生成 + 审批面板 + UserDefaults缓存(8字段) + PUT保存 + maxVisitedStep跳转 | 100% |
| 补充: plotOutlineModel | 15个工具函数/类型全移植（系统设计遗漏，寇豆码事实表阶段抓出） | 100% |
| 补充: wizardStageCache | 8字段+8函数 | 100% |

**P0批次16代码文件**（总8640行）：
- 新建9文件：AIInvocationModels/PlotOutlineModels/ChapterElementModels/TaxonomyModels/InvocationOutput/AIInvocationStore/AIInvocationReviewPanel/PlotOutlineStep + WorkbenchView额外+6行
- 修改7文件：MonitorModels/ForeshadowModels/PropModels/APIEndpoint/OnboardingStore/OnboardingWizardView/SSEStreamRegistry/WorkbenchStore

**CI#23编译错误6类（已修复）**：
1. AIInvocationModels.swift:300 — InvocationVariableSnapshotGroup的CodingKeys需显式映射id→groupId
2. AIInvocationStore.swift 7处catch块 — catch块内error是常量不可赋值，用self.error引用@Published var；open()补throws；if let绑定非Optional改为!isEmpty
3. NovelModels.swift — 删除重复的ChapterElementCreate声明
4. ChapterElementModels.swift — 错误3修复后自动解决
5. ForeshadowStore.swift:87 — 补suggestedResolveChapter/resolveChapterWindow/importance参数(传nil)
6. PlotOutlineStep.swift:94 — if let绑定非Optional PlotOutlineDTO改为!isEmpty判断

### 🚀 阶段3剩余任务（T03/T04/T05）

| 任务 | 优先级 | 内容 | 状态 |
|------|--------|------|------|
| T03 | P1 | 三个Mock面板接真实API（QualityGuardrail/ConsistencyReport/ChapterElement） | **正在推进** |
| T04 | P2 | DAG节点交互 + 题材包接API | 待启动 |
| T05 | P2 | 六面板全CRUD（伏笔/道具/演化/编年史/AntiAI/对话沙盒） | 待启动 |

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

### 5.2 主理人7项疑问决策（寇豆码事实表阶段产出）

| # | 疑问 | 决策 |
|---|------|------|
| 疑问1 | showDebugPanel行为 | **无条件设visible=true**，shouldKeepPanelVisible()无条件返回true |
| 疑问2 | title计算属性 | **包含**（View层标题需要） |
| 疑问3 | plotOutlineModel工具函数归属 | **放入PlotOutlineModels.swift**，15个全移植 |
| 疑问4 | WizardUiCachePayload字段 | **保留8字段**，worldbuildingFieldLabels不移植 |
| 疑问5 | 重复JSON解析函数 | 通用复用InvocationOutput.swift，parseAttemptContent+recoverTruncatedArrayObject作扩展 |
| 疑问6 | Bible SSE接线点 | 实现时补读NovelSetupGuide.vue:1548-1550确认（已接线） |
| 疑问7 | 章节SSE终止消费 | Task.cancel()或标志位，对齐原版return true（已实现） |

### 5.3 架构师校正的3.6原版文件名（重要，别搞错）

| PRD名称 | 实际原版文件名 | 路径 |
|---------|--------------|------|
| ForeshadowLedger.vue | ForeshadowLedgerPanel.vue | components/workbench/ |
| PropManagerPanel.vue | ManuscriptPropsPanel.vue | components/workbench/ |
| ChroniclesPanel.vue | HolographicChroniclesPanel.vue | components/workbench/ |
| AntiAIPanel.vue | AntiAIDashboard.vue | components/workbench/promptPlaza/ |
| DialogueSandboxPanel.vue | DialogueCorpus.vue | components/workbench/ |

### 5.4 架构师标注的待明确事项（T04/T05实现时注意）

1. **题材包API端点**：原版直接import JSON不走API。iOS先试GET /taxonomy/bundles/builtin_cn_v1，404则降级Bundle本地加载
2. **DAG节点API端点路径**：需实现者读dagStore.ts确认loadNodePromptLive/toggleNode/updateNodeConfig的具体端点
3. **3.6演化/AntiAI/对话沙盒API端点**：T05实现者开工前必须先Read原版完整源码输出事实表（机制1）
4. **PropDetailDrawer独立组件**：iOS当前未拆分，T05需新建

---

## 六、防砍功能约束 6 道机制（铁律，每阶段必须套用）

详见 `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`。简表：

1. **强制先读原版再动手**：工程师动手前必须Read原版文件，输出"原版做了什么"事实表，主理人确认才进实现
2. **PRD固化功能清单checklist**：产品经理出PRD时列功能清单，每项标原版文件+行号
3. **架构师出接口契约表**：每个API/SSE事件/数据模型都标原版文件+行号
4. **实现者逐条标注原版行号**：代码注释里写对应的原版文件:行号
5. **QA按原版清单逐项验收**：QA独立读代码验证，不rubber-stamp工程师自报，缺一条即FAIL
6. **派工prompt写死6条铁律**：禁止砍功能/简化流程/跳过原版步骤/自创API/凭猜测简化/不自报对齐度

**阶段3 P0批次执行情况**：6道机制全程套用，QA独立验收108/108 PASS，0砍功能。事实表阶段抓出系统设计2处遗漏（plotOutlineModel + WizardUiCachePayload），体现机制1价值。

---

## 七、团队协作机制（铁律）

### SOP 工作流
```
用户需求 → 产品经理(PRD) → 架构师(系统设计+任务分解) → 工程师(代码实现) → QA工程师(测试验证)
```

### 成员
| 成员 | 姓名 | Agent ID | 职责 |
|------|------|----------|------|
| 主理人 | 齐活林（Qi） | （你自己） | 协调+中转+汇总，不代写成员产出 |
| 产品经理 | 许清楚（Xu） | `software-product-manager` | PRD/市场调研 |
| 架构师 | 高见远（Gao） | `software-architect` | 系统设计+任务分解 |
| 工程师 | 寇豆码（Kou） | `software-engineer` | 批量编写代码 |
| QA工程师 | 严过关（Yan） | `software-qa-engineer` | 测试+智能路由判定 |

### 派工命名（CRITICAL）
调度成员时Agent工具参数：
- `name: "software-engineer", subagent_type: "software-engineer"`
- `name: "software-architect", subagent_type: "software-architect"`
- `name: "software-product-manager", subagent_type: "software-product-manager"`
- `name: "software-qa-engineer", subagent_type: "software-qa-engineer"`

### 当前团队状态
- 团队名：`software-cangjie-stage3`（已创建，4个成员都spawn过）
- 许清楚：已完成阶段3 PRD，idle
- 高见远：已完成阶段3系统设计，idle
- 寇豆码：已完成P0实现+CI修复，idle（可继续派T03）
- 严过关：已完成P0验收，idle（可继续派T03验收）

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

## 九、阶段3新教训（P0批次血泪，下一任必读）

### 1. Swift catch块 error 是常量
- catch块内 `error` 是隐式常量，不可赋值
- 错误写法：`catch { error = errorText(error) }` → 编译失败
- 正确写法：`catch { self.error = errorText(error) }`（用self.error引用@Published var）
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
- ForeshadowModels.swift 补了 suggestedResolveChapter/resolveChapterWindow/importance 到 CreateRequest
- 但 ForeshadowStore.swift:87 的调用处没更新 → missing arguments
- 修复：调用处补参数（传nil）

### 6. 交接文档不能写token明文
- GitHub secret scanning 会拦截含 ghp_xxx 的push
- 修复：sed替换为占位符 + amend commit

---

## 十、CI 信息

- **仓库**：https://github.com/Da-AiXZ/CangJie
- **编译环境**：macos-14, Xcode 15.4, XcodeGen, ldid
- **CI 脚本**：`.github/workflows/build.yml` / `scripts/build-ipa.sh` / `scripts/verify-ipa.sh`
- **触发**：push 到 main 自动触发
- **编译耗时**：约60-110秒
- **最新成功CI**：#24（commit aa49a07，阶段3 P0最终状态，success）

### CI 失败排查方法（前台盯CI）
```bash
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
        print(f'CI完成！conclusion={c}', flush=True); break
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

## 十一、阶段3剩余任务启动指令（下一任AI直接执行）

### T03 Mock面板接真实API（P1，正在推进）

**范围**：3个面板消除硬编码假数据
- 3.4.1 QualityGuardrailPanel：接 `POST /novels/{id}/guardrail/check`（GuardrailCheckResponse，五维度雷达图）
- 3.4.2 ConsistencyReportPanel：接章节生成 done 事件的 consistency_report（ConsistencyReportDTO）
- 3.4.3 ChapterElementPanel：接 ChapterElement API CRUD（5端点）

**PRD已就绪**：stage3_prd.md 的 3.4 部分（15条原子功能清单）
**契约表已就绪**：stage3_system_design.md 的 3.4 部分
**T01基础层已完成**：MonitorModels.swift(已+GuardrailCheck)、ChapterElementModels.swift(已建)、APIEndpoint.swift(已+端点)

**执行流程**（寇豆码+严过关在团队中idle，可直接派工）：
1. 派寇豆码读原版3个面板源码输出事实表（机制1）：engineCore.ts:98-147 + workflow.ts:242-271,453-463 + chapterElement.ts:1-75
2. 主理人确认事实表
3. 派寇豆码实现T03（4文件：MonitorStore新建 + 3个面板改）+ 6铁律
4. 派严过关验收（机制5）
5. 主理人push+盯CI

### T04 DAG节点交互+题材包接API（P2）

**范围**：
- 3.3 DAG节点交互：NodeContextMenu(长按菜单) + NodeDetailPanel(详情Sheet+写作遥测) + NodeEditorDrawer(配置抽屉+广场跳转)
- 3.5 题材包接API：MarketTaxonomyPicker + CreateNovelSheet替换硬编码

**PRD已就绪**：stage3_prd.md 的 3.3+3.5 部分（28条）
**契约表已就绪**：stage3_system_design.md 的 3.3+3.5 部分
**待明确**：DAG节点API端点路径需读dagStore.ts确认；题材包API端点需先试GET /taxonomy/bundles/builtin_cn_v1

### T05 六面板全CRUD（P2）

**范围**：伏笔/道具/演化/编年史/AntiAI/对话沙盒全CRUD
**PRD已就绪**：stage3_prd.md 的 3.6 部分（30条，原版行号架构师已补标）
**契约表已就绪**：stage3_system_design.md 的 3.6 部分
**关键**：演化/AntiAI/对话沙盒API端点待实现者读原版完整源码补全（待明确事项8.3）

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

### 阶段3 P0新教训（见第九节）

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

**交接完毕。代码 = SOP(团队)。阶段3 P0已完成，T03/T04/T05按指令推进。下一任加油。**
