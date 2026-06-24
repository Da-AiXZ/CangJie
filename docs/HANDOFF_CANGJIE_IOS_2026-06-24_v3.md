# 仓颉 iOS 移植项目交接文档

> **交接日期**：2026-06-24
> **交接人**：齐活林（Qi）· 交付总监（第三任主理人）
> **状态**：阶段1已完成并编译通过，阶段2待启动
> **文档用途**：防止积分耗尽被中断后下一任AI盲猜。本文件是唯一权威交接，读完即可接手。

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
| **审计报告1（差异）** | `C:/Users/netease/Desktop/仓颉iOS移植版差异审计报告.md` |
| **审计报告2（深度）** | `C:/Users/netease/Desktop/仓颉iOS已实现功能对齐深度审计.md` |
| **防砍约束方法** | `C:/Users/netease/Desktop/AI移植项目防砍功能约束方法.md` |
| **项目记忆** | `D:/111/2026-06-24-18-26-21/.workbuddy/memory/2026-06-24.md` |

**⚠️ 注意**：当前会话工作目录是 `D:/111/2026-06-24-18-26-21`（空目录），但**实际代码在** `D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/`。所有git操作、代码编辑都在这个路径下。

---

## 三、GitHub 认证

- 仓库 owner：`Da-AiXZ`
- git push 认证：用 `x-access-token:<token>@` 作为 user（不能用 `Da-AiXZ:<token>@`，会 invalid credentials）
- **token**：`<GITHUB_TOKEN 见项目memory>`
- remote URL 格式：`https://x-access-token:<GITHUB_TOKEN 见项目memory>@github.com/Da-AiXZ/CangJie.git`

---

## 四、当前状态（2026-06-24 20:20）

### ✅ 阶段1已完成（commit 39282d4，CI #19编译通过）

**commit 链（main分支，已push）**：
| commit | 内容 |
|--------|------|
| 39282d4 | CI #18 编译错误修复（BibleModels 类型转换） |
| 52762d5 | 阶段1返工 onStreamEnd + cancel SSE |
| b1cada9 | 阶段1 T01-T06 主体实现（18文件 +3020/-299行） |
| 64d77d6 | autopilot 409 卡点修复 |

**阶段1做了什么**（按原版做的，已QA验收+返工，73项功能点全实现）：
1. 向导 Bible SSE 分3步stage（worldbuilding/characters/locations）+ 13类SSE事件完整解析
2. Autopilot chapter-stream 9类事件解析（含onStreamEnd回调+streamTerminal流结束逻辑）
3. workbench 单章生成 SSE（7类事件+7模型+UI：phase进度+正文流式+一致性报告）
4. mapGeneratedCharacterToEditable 全字段映射含fallback（personality→flaw等）
5. approval_required/error/done 显式cancel SSE连接

**阶段1验证结论**：主理人亲自读原版+移植版代码对比，确认是按原版做的，不是瞎编。唯一砍的是向导第4步剧情总纲（依赖AI Invocation审批系统，阶段3补）。

**IPA artifact**：CI #19 (run_id=28095424522)，artifact id=7848226612，1.6MB，可TrollStore侧载实测

### 📋 阶段2-4待启动

详见 `docs/阶段补齐核验清单.md`。简表：

| 阶段 | 主题 | 内容 | 预期覆盖度 |
|------|------|------|-----------|
| 2 | 数据模型修正+提示词广场重写 | CircuitBreaker/BibleStatus/PromptNode字段 + Autopilot参数补全 + 轮询改退避 + 主题anchor | ~78% |
| 3 | 补缺失核心功能 | AI Invocation审批系统 + 向导补5步 + DAG节点交互 + Mock面板接API + 各面板CRUD | ~93% |
| 4 | 锦上添花 | 文风voiceApi + 世界线DAG重写 + 工作台组件补齐 + 全局浮动按钮 + 单元测试 | ~98% |

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

前两任AI因偷工减料砍功能被用户叫停，第三任（我）也被抓到2处简化返工过。这是血泪教训。

1. **强制先读原版再动手**：工程师动手前必须Read原版文件，输出"原版做了什么"事实表，主理人确认才进实现
2. **PRD固化功能清单checklist**：产品经理出PRD时列功能清单，每项标原版文件+行号
3. **架构师出接口契约表**：每个API/SSE事件/数据模型都标原版文件+行号
4. **实现者逐条标注原版行号**：代码注释里写对应的原版文件:行号
5. **QA按原版清单逐项验收**：QA独立读代码验证，不rubber-stamp工程师自报，缺一条即FAIL
6. **派工prompt写死6条铁律**：禁止砍功能/简化流程/跳过原版步骤/自创API/凭猜测简化/不自报对齐度

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
- **最新成功CI**：#19（commit 39282d4，run_id=28095424522）

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
│   ├── Models/                 # 24+ 数据模型（Novel/Bible/Autopilot/GenerateChapter...）
│   ├── Networking/             # APIClient, APIConfig, APIEndpoint, APIError, AuthMiddleware
│   ├── SSE/                    # SSEClient, SSEConnection, SSEEvent, SSEStreamRegistry
│   ├── Theme/                  # Theme.swift, ThemeModifiers.swift
│   ├── Utils/                  # DateFormatter+ISO（CangjieDecoder.shared）, Logger, SugiyamaLayout...
│   ├── ViewModels/             # 21+ Store（NovelStore, BibleStore, AutopilotStore, OnboardingStore, WorkbenchStore...）
│   └── Views/
│       ├── Root/               # RootView.swift（HStack 两栏）, SidebarView.swift
│       ├── Home/               # HomeView, CreateNovelSheet, NovelCardView
│       ├── Onboarding/         # OnboardingWizardView, BibleStreamingStep, CharacterSetupStep, LocationSetupStep
│       ├── Workbench/          # WorkbenchView, ChapterToolbar, ChapterContentPanel, ChapterGenerationPanel...
│       ├── Autopilot/          # AutopilotConsoleView, AutopilotControlPanel, ChapterStreamView...
│       ├── Bible/              # BiblePanelView, CharacterProfileCard...
│       ├── Settings/           # SettingsView, LLMConfigSection, ServerConnectionSection...
│       ├── Panels/             # 16 业务面板
│       ├── KnowledgeGraph/     # 知识图谱
│       ├── Cast/               # 人物关系
│       ├── Monitor/            # 监控
│       ├── PromptPlaza/        # 提示词广场
│       ├── Governance/         # 叙事治理
│       ├── Export/             # 导出
│       ├── Snapshot/           # 快照
│       └── Trace/              # AI Trace
├── docs/                       # system_design.md, 阶段补齐核验清单.md, 本交接文档
├── Resources/                  # Info.plist, Cangjie.entitlements, Assets.xcassets...
├── .github/workflows/build.yml
├── scripts/                    # build-ipa.sh, verify-ipa.sh
└── project.yml                 # XcodeGen 配置
```

---

## 十一、阶段2启动指令（下一任AI直接执行）

### 阶段2范围（6项，详见 docs/阶段补齐核验清单.md）

1. **2.1 CircuitBreaker 字段重写**：state→status, failure_count→error_count, threshold→max_errors, 补last_error嵌套+error_history
2. **2.2 BibleGenerationStatus/Feedback 字段重写**：字段完全对齐原版
3. **2.3 提示词广场数据模型重写**：PromptNode/PromptVersion/RenderResult/DebugResult 4个模型 + 沙盒/链路/绑定/变量/导入导出
4. **2.4 Autopilot 启动参数补全**：maxAutoChapters/autoApproveMode/target_chapters/target_words_per_chapter 接线
5. **2.5 Autopilot 轮询改自适应退避**：base 4s→60s指数退避 + 404停止
6. **2.6 主题补 anchor 模式 + xlarge 字号**：4种模式+4档字号

### 工作流判断
阶段2是**中大型需求**（6个模块，涉及多文件修改+新建），走**标准 SOP**：
```
PRD(许清楚) → 架构设计(高见远) → 代码实现(寇豆码) → QA验收(严过关)
```

### 启动步骤
1. **主理人 TeamCreate**：`TeamCreate(team_name: "software-cangjie-stage2-xxx")`
2. **派产品经理许清楚**：基于 docs/阶段补齐核验清单.md 的阶段2部分出PRD（功能清单checklist，每项标原版文件+行号）
3. **PRD完成后转架构师高见远**：出接口契约表+任务分解
4. **架构设计完成后转工程师寇豆码**：先读原版输出事实表（防砍机制1），主理人确认后进实现
5. **代码完成后转QA严过关**：按原版清单逐项验收（防砍机制5）
6. **QA通过后主理人push触发CI**：前台盯CI，失败修复，成功通知用户

### 必读文件（启动前必须读）
- `docs/阶段补齐核验清单.md`（阶段2的6项详细要求）
- `docs/system_design.md`（阶段1的接口契约表，了解现有架构）
- 原版对应文件（清单里标了每个模块的原版文件:行号）

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

---

## 十三、用户信息

- **设备**：iPad Pro 2021 (M1), iOS 16.6.1, TrollStore 侧载
- **后端**：已部署云端（PlotPilot Python/FastAPI），零改动
- **LLM**：已配 DeepSeek + agnes 等端点，测试连通性通过
- **用户期望**：直接按原项目方法接好前端，后端不变，不要自己发明流程
- **用户容忍度**：对砍功能零容忍，前两任因砍功能被叫停做了审计报告
- **用户原话**："我们只是移植，又不是重做，而且我们现在只是做个前端而已，后端又不变，正常来说直接按原项目的方法接好不就行了吗"

---

**交接完毕。代码 = SOP(团队)。下一任加油。**
