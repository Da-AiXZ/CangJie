# 仓颉 iOS 移植项目交接文档 v4

> **交接日期**：2026-06-24（v3 → v4 升级）
> **交接人**：齐活林（Qi）· 交付总监（第四任主理人）
> **状态**：阶段1+2已完成并编译通过，阶段3启动中
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜。本文件是唯一权威交接，读完即可接手。
> **v3 → v4 变更**：阶段2验收完成，更新commit链+CI信息；阶段3启动指令细化（严格按防砍约束6道机制）

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
| **阶段1系统设计文档** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/system_design.md` |
| **阶段2-4补齐核验清单** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段补齐核验清单.md` |
| **阶段2 QA独立验收报告** | `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/docs/阶段2QA独立验收报告_2026-06-24.md` |
| **审计报告1（差异）** | `C:/Users/netease/Desktop/仓颉iOS移植版差异审计报告.md` |
| **审计报告2（深度）** | `C:/Users/netease/Desktop/仓颉iOS已实现功能对齐深度审计.md` |
| **防砍约束方法** | `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md` |
| **项目记忆** | `D:/111/2026-06-24-22-39-38/.workbuddy/memory/2026-06-24.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-24-22-39-38`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：`<GITHUB_TOKEN 见项目memory>`
- remote URL 格式：`https://x-access-token:<GITHUB_TOKEN 见项目memory>@github.com/Da-AiXZ/CangJie.git`

---

## 四、当前状态（2026-06-24 23:05）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）

详见v3。73项功能点全实现+QA返工通过。Bible SSE分3步stage+13类SSE事件+Autopilot chapter-stream 9类事件+workbench单章生成SSE+onStreamEnd回调+approval_required/error/done显式cancel SSE。

### ✅ 阶段2已完成（commit 043b402，CI #22编译通过）— QA独立验收PASS

**commit 链（main分支，已push）**：

| commit | 内容 |
|--------|------|
| 043b402 | CI #21 修复 PromptNode 自定义Hashable实现(用id做hash) |
| bd753aa | CI #20 修复 default关键字+PromptNode Hashable+exportData类型 |
| b130b0c | **阶段2主体** T01-T05 (15文件 +2098/-420行) |
| 39282d4 | CI #18 编译错误修复（BibleModels 类型转换） |

**阶段2做了什么**（6项全PASS，QA独立验收报告见 docs/阶段2QA独立验收报告_2026-06-24.md）：

| 模块 | 对齐度 | 关键实现 |
|------|--------|---------|
| 2.1 CircuitBreaker | 10/10 | AutopilotErrorRecord + AutopilotCircuitBreakerData（status/errorCount/maxErrors/lastError/errorHistory）+ 删resetTimeoutSeconds |
| 2.2 BibleStatus | 8/8 | exists/ready/novelId + novelId/error/stage/at，删自造字段 |
| 2.3 提示词广场 | 115/115 | 17模型全字段对齐 + 23个API全实现 + 沙盒/链路/绑定/变量/导入导出5功能补齐 |
| 2.4 启动参数 | 6/6 | maxAutoChapters传参 + autoApproveMode PATCH并行 + 保护上限联动 |
| 2.5 轮询退避 | 8/8 | assistedAutopilotPollDelay 4s→60s指数退避 + 404停止 + resetBackoff |
| 2.6 主题 | 17/17 | anchor黑金模式 + xlarge 1.25 + small=0.875/large=1.125 + 4档选择器 |
| **总计** | **164/164 = 100%** | QA独立验收确认 |

**阶段2小瑕疵（非砍功能，阶段3顺手修）**：
- listNodes/loadVariables 的 query 参数未真正传给 APIEndpoint（APIEndpoint设计限制），因 plazaInit 能拿全量节点，UI可本地过滤替代

### 🚀 阶段3启动中（2026-06-24 23:05 启动）

阶段3范围（6大项，详见 docs/阶段补齐核验清单.md）：

| # | 主题 | 优先级 | 依赖 |
|---|------|--------|------|
| 3.1 | AI Invocation 审批系统全量新建（4层：View+Store+API+Utils） | P0 | 无（解锁3.2） |
| 3.2 | 向导补第4步剧情总纲（SSE+审批+保存）+ 第5步进工作台 | P0 | 3.1 |
| 3.3 | DAG节点交互（右键菜单+编辑抽屉+toggle+提示词广场跳转） | P2 | 无 |
| 3.4 | 三个Mock面板接真实API（QualityGuardrail/ConsistencyReport/ChapterElement） | P1 | 无 |
| 3.5 | CreateNovelSheet 题材包接 /taxonomy/bundles/builtin_cn_v1 | P2 | 无 |
| 3.6 | 六个面板全CRUD（伏笔/道具/演化/编年史/AntiAI/对话沙盒） | P2 | 无 |

**预期阶段3完成后覆盖度**：~93%

---

## 五、后端说明（重要）

- **后端是原项目 PlotPilot 的 Python/FastAPI 后端，已部署云端，零改动**
- 我们只做 iOS 前端移植，对接已部署的后端
- 后端所有接口都已存在（原版 Vue 在用），我们按原版方式调即可
- LLM 端点已配置好（DeepSeek + agnes 等），测试连通性通过
- 用户原话："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变"
- **不需要碰后端代码，不需要部署后端，后端已经在跑了**

---

## 六、防砍功能约束 6 道机制（铁律，每阶段必须套用）

详见 `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`。简表：

1. **强制先读原版再动手**：工程师动手前必须Read原版文件，输出"原版做了什么"事实表，主理人确认才进实现
2. **PRD固化功能清单checklist**：产品经理出PRD时列功能清单，每项标原版文件+行号
3. **架构师出接口契约表**：每个API/SSE事件/数据模型都标原版文件+行号
4. **实现者逐条标注原版行号**：代码注释里写对应的原版文件:行号
5. **QA按原版清单逐项验收**：QA独立读代码验证，不rubber-stamp工程师自报，缺一条即FAIL
6. **派工prompt写死6条铁律**：禁止砍功能/简化流程/跳过原版步骤/自创API/凭猜测简化/不自报对齐度

**阶段3执行规范**：
- 主理人自查清单（每轮交接前过一遍，见约束方法五）必须齐
- 派工prompt模板（约束方法三）必须复用
- QA验收清单模板（约束方法四）必须复用
- 常见砍功能套路（约束方法六）QA重点识别

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

### 主理人职责边界
- ✅ TeamCreate（必须主理人亲自执行，严禁委派）
- ✅ 消息中转（成员产出回传主理人，主理人转交下一阶段，成员不直连）
- ✅ 汇编+编排（不代写成员的专业产出）
- ✅ 前台盯CI编译（push后用python脚本轮询CI状态，失败就拉日志找错误修复）
- ❌ 不代写PRD/架构设计/代码/测试

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

---

## 九、CI 信息

- **仓库**：https://github.com/Da-AiXZ/CangJie
- **编译环境**：macos-14, Xcode 15.4, XcodeGen, ldid
- **CI 脚本**：`.github/workflows/build.yml` / `scripts/build-ipa.sh` / `scripts/verify-ipa.sh`
- **触发**：push 到 main 自动触发
- **编译耗时**：约60-110秒
- **最新成功CI**：#22（commit 043b402，阶段2最终状态，success）

### CI 失败排查方法（前台盯CI）
```bash
# push后查CI状态
python -c "
import urllib.request, json
token = '<GITHUB_TOKEN 见项目memory>'
req = urllib.request.Request('https://api.github.com/repos/Da-AiXZ/CangJie/actions/runs?per_page=2', headers={'Authorization':'token '+token,'Accept':'application/vnd.github+json','User-Agent':'ci-check'})
data = json.load(urllib.request.urlopen(req))
for r in data['workflow_runs'][:2]:
    print(f\"#{r['run_number']} | sha={r['head_sha'][:7]} | status={r['status']} | conclusion={r['conclusion']} | run_id={r['id']}\")
"

# 盯CI直到完成
python -c "
import urllib.request, json, time
token = '<GITHUB_TOKEN 见项目memory>'
run_id = <RUN_ID>
last=''
for i in range(24):
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
token = '<GITHUB_TOKEN 见项目memory>'
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
                print(f'{name}:{i+1}: {line.strip()[:300]}')
"
```

---

## 十、项目结构

```
cangjie-ios/
├── Cangjie/
│   ├── App/                    # CangjieApp.swift, AppState.swift
│   ├── Models/                 # 24+ 数据模型（Novel/Bible/Autopilot/GenerateChapter/PromptPlaza*）
│   ├── Networking/             # APIClient, APIConfig, APIEndpoint, APIError, AuthMiddleware
│   ├── SSE/                    # SSEClient, SSEConnection, SSEEvent, SSEStreamRegistry
│   ├── Theme/                  # Theme.swift（4模式+4字号含anchor黑金）, ThemeModifiers.swift
│   ├── Utils/                  # DateFormatter+ISO（CangjieDecoder.shared）, Logger, SugiyamaLayout...
│   ├── ViewModels/             # 21+ Store（NovelStore, BibleStore, AutopilotStore, OnboardingStore, WorkbenchStore, PromptPlazaStore...）
│   └── Views/
│       ├── Root/               # RootView.swift（HStack 两栏）, SidebarView.swift
│       ├── Home/               # HomeView, CreateNovelSheet, NovelCardView
│       ├── Onboarding/         # OnboardingWizardView, BibleStreamingStep, CharacterSetupStep, LocationSetupStep
│       ├── Workbench/          # WorkbenchView, ChapterToolbar, ChapterContentPanel, ChapterGenerationPanel...
│       ├── Autopilot/          # AutopilotConsoleView, AutopilotControlPanel, ChapterStreamView...
│       ├── Bible/              # BiblePanelView, CharacterProfileCard...
│       ├── Settings/           # SettingsView, LLMConfigSection, ServerConnectionSection, AppearanceSection（4模式4字号）
│       ├── Panels/             # 16 业务面板（含QualityGuardrail/ConsistencyReport/ChapterElement/VoiceVault等）
│       ├── KnowledgeGraph/     # 知识图谱
│       ├── Cast/               # 人物关系
│       ├── Monitor/            # 监控
│       ├── PromptPlaza/        # 提示词广场（阶段2全量重写，23 API）
│       ├── Governance/         # 叙事治理
│       ├── Export/             # 导出
│       ├── Snapshot/           # 快照（含WorldlineDAGView，阶段4重写）
│       └── Trace/              # AI Trace
├── docs/                       # system_design.md, 阶段补齐核验清单.md, 阶段2QA验收报告, 本交接文档
├── Resources/                  # Info.plist, Cangjie.entitlements, Assets.xcassets...
├── .github/workflows/build.yml
├── scripts/                    # build-ipa.sh, verify-ipa.sh
└── project.yml                 # XcodeGen 配置
```

---

## 十一、阶段3启动指令（下一任AI直接执行）

### 阶段3范围（6项，详见 docs/阶段补齐核验清单.md）

**严格按防砍约束方法6道机制执行**：

1. **3.1 AI Invocation 审批系统全量新建**（P0，4层全建）
   - 原版4层：`components/ai-invocation/AIInvocationReviewPanel.vue` + `stores/aiInvocationStore.ts` + `api/aiInvocation.ts` + `utils/invocationOutput.ts`
   - iOS现状：0实现（grep "invocation\|approval\|审批" 全项目0命中）
   - 解锁3.2向导第4步

2. **3.2 向导补第4步剧情总纲**（P0，依赖3.1）
   - 原版：`components/onboarding/NovelSetupGuide.vue` 第4步 + `api/workflow.ts` consumePlotOutlineStream/savePlotOutline
   - 原版第4步 API：`POST /api/v1/novels/{id}/setup/generate-plot-outline-stream`（SSE）+ `PUT /api/v1/novels/{id}/setup/plot-outline`
   - iOS现状：向导3步，缺第4步

3. **3.3 DAG节点交互**（P2）
   - 原版：`components/autopilot/NodeContextMenu.vue` + `NodeDetailPanel.vue` + `NodeEditorDrawer.vue`
   - iOS现状：DAG点击只读Sheet，无右键/编辑/toggle/跳转

4. **3.4 三个Mock面板接真实API**（P1）
   - 3.4.1 QualityGuardrailPanel：接 MonitorStore 质量评分端点
   - 3.4.2 ConsistencyReportPanel：接章节生成完成后的 consistency_report
   - 3.4.3 ChapterElementPanel：接 ChapterElement API

5. **3.5 CreateNovelSheet 题材包接 API**（P2）
   - 原版：`components/taxonomy/MarketTaxonomyPicker.vue` + `domain/taxonomy/cnMarket.ts` + `domain/taxonomy/builtin_cn_v1.bundle.json`
   - iOS现状：题材硬编码
   - API：`/taxonomy/bundles/builtin_cn_v1`

6. **3.6 六个面板全CRUD**（P2）
   - 伏笔/道具/演化/编年史/AntiAI/对话沙盒，详见核验清单

### 工作流判断
阶段3是**中大型需求**（6大项，新建+修改30+文件），走**标准 SOP**：
```
PRD(许清楚) → 架构设计(高见远) → 代码实现(寇豆码) → QA验收(严过关)
```

### 启动步骤（严格按防砍约束方法）
1. **主理人 TeamCreate**：`TeamCreate(team_name: "software-cangjie-stage3")`
2. **派产品经理许清楚**（机制2）：基于 docs/阶段补齐核验清单.md 阶段3部分出PRD（功能清单checklist，每项标原版文件+行号）。约束方法二的清单格式必用。
3. **PRD完成后转架构师高见远**（机制3）：出接口契约表+任务分解。约束方法三的契约表格式必用。
4. **架构设计完成后转工程师寇豆码**（机制1+4+6）：
   - 先读原版输出事实表（约束方法一的事实表模板），主理人确认后进实现
   - 每方法标注原版文件+行号（约束方法四）
   - 派工prompt写死6条铁律（约束方法三的模板必用）
5. **代码完成后转QA严过关**（机制5）：按PRD功能清单逐项验收。约束方法四的验收模板必用，智能路由判定（Engineer/QA/NoOne）。
6. **QA通过后主理人push触发CI**：前台盯CI，失败修复，成功更新交接文档

### 必读文件（启动前必须读）
- `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md`（6道机制+派工模板+QA模板）
- `docs/阶段补齐核验清单.md`（阶段3的6项详细要求+原版文件:行号）
- `docs/system_design.md`（阶段1的接口契约表，了解现有架构）
- `docs/阶段2QA独立验收报告_2026-06-24.md`（了解阶段2已完成边界，避免重复造轮子）
- 原版对应文件（清单里标了每个模块的原版文件:行号）

### 推荐分批策略（工程师寇豆码）
阶段3工作量大，建议按优先级分批：
- **批次1（P0，阻断核心路径）**：3.1 AI Invocation + 3.2 向导第4步（强依赖3.1）
- **批次2（P1，假功能修复）**：3.4 三个Mock面板接真实API
- **批次3（P2，功能补齐）**：3.3 DAG节点交互 + 3.5 题材包接API + 3.6 六面板CRUD

每批走完整SOP（PRD→架构→工程→QA），批次间可并行设计。

---

## 十二、核心教训（血泪史，下一任必读）

### 1. NavigationSplitView 是 iOS 16 的雷区
- 不能嵌套，content闭包不能switch不同类型视图，会触发AttributeGraph assertion崩溃
- 全项目用 HStack + NavigationStack 替代

### 2. TrollStore 侧载环境特殊性
- Keychain 杀后台会被清理 → 用 UserDefaults
- SecureField 系统级禁第三方键盘 → 用 TextField
- entitlements 最小化 → 只有 network.client + 文件共享

### 3. Swift init() 规则
- init中所有存储属性初始化完成前不能访问self的任何属性
- 用局部变量承载中间值

### 4. 后端 API 对齐
- 日期用 CangjieDecoder.shared（微秒6位）
- POST /test 期望完整 LLMProfile 对象，不是 profile_id
- POST /macro/confirm 是关键步骤，没调这个结构不存DB

### 5. 移植原则（最重要）
- **直接对照原项目接，不要自己发明流程**
- 原版怎么做，iOS版就怎么做
- 不许砍功能、不许简化、不许跳过原版步骤

### 6. 子agent管理教训
- 主agent停下后子agent不会自己继续工作
- 必须主agent主动SendMessage推动或spawn新agent接手
- 返工/小修也要spawn agent执行，不能干等

### 7. 阶段2教训（新增）
- Swift 关键字（如 default）不能直接当属性名，用 defaultValue + CodingKey 映射规避
- AnyCodable 不符合 Hashable，PromptNode 需自定义 Hashable 实现（用 id 做 hash）
- Swift struct 不支持继承，PromptNodeDetail extends PromptNode 用平铺所有字段实现
- ThemeMode.system 对应原版 auto（iOS地道写法，功能等价，注释标明决策）

---

## 十三、用户信息

- **设备**：iPad Pro 2021 (M1), iOS 16.6.1, TrollStore 侧载
- **后端**：已部署云端（PlotPilot Python/FastAPI），零改动
- **LLM**：已配 DeepSeek + agnes 等端点，测试连通性通过
- **用户期望**：直接按原项目方法接好前端，后端不变，不要自己发明流程
- **用户容忍度**：对砍功能零容忍，前两任因砍功能被叫停做了审计报告
- **用户要求**：阶段3严格按《AI移植项目防砍功能约束方法.md》6道机制执行
- **用户原话**："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变，正常来说直接按原项目的方法接好不就行了吗"

---

**交接完毕。代码 = SOP(团队)。阶段3严格防砍，下一任加油。**
