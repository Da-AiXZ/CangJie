# 仓颉 Agent Harness 工程架构基线

- 状态：`CONFIRMED ARCHITECTURE BASELINE`
- 决策日期：2026-07-18
- 适用范围：Context、Prompt、Agent Loop、Typed Tools、任务恢复、多 Agent、治理与可观测性
- 状态声明：**工程架构基线已确认，具体接口随 TDD 细化。本文不是已实现能力清单。**
- 关联文档：`docs/IMPLEMENTATION_PLAN.md`、`docs/PRODUCT_EXPERIENCE_BLUEPRINT.md`、`docs/MILESTONE_VISUAL_ACCEPTANCE.md`

> **CJ-AH-001 \u00b7 FROZEN \u00b7 2026-07-18**
>
> 仓颉宿主掌握主循环、真实状态、权限、预算、事务、恢复和完成判定；模型只负责判断下一步并请求工具，不能自行判定软件操作成功。
>
> 实现边界：架构决定已冻结；H0–H5 尚未完成实现与验收，不得表述为现有能力。

---

## 1. Clean-room 与公开证据边界

1. Anthropic 官方公开仓库 `anthropics/claude-code` 不包含完整生产核心源码。仓颉不得声称拿到了完整 Claude Code 官方源码或复刻了其生产核心。
2. 官方 Claude Agent SDK Python/TypeScript 及公开文档只用于核验公开接口、宿主控制、会话、工具、Hooks 和 Subagent 模式。
3. `cc.zip` 自称 leaked/private/UNLICENSED，只允许做不具表达性的高层架构对照；严禁复制或近似改写源码、Prompt、Schema、字符串、测试、目录结构和命名组合。
4. 仓颉采用“公开工程原则 + 仓颉产品合同 + 独立接口设计 + TDD 证据”的 clean-room 原创实现。

官方公开参考：

- `https://github.com/anthropics/claude-code`
- `https://github.com/anthropics/claude-agent-sdk-python`
- `https://github.com/anthropics/claude-agent-sdk-typescript`
- `https://platform.claude.com/docs/en/agent-sdk/overview`
- `https://platform.claude.com/docs/en/agent-sdk/sessions`
- `https://platform.claude.com/docs/en/agent-sdk/hooks`
- `https://platform.claude.com/docs/en/agent-sdk/subagents`
- `https://platform.claude.com/docs/en/agent-sdk/custom-tools`
### 1.1 可证明的来源隔离流程

- 实现规范、代码、测试和注释只允许引用官方公开资料、仓颉原创产品合同和本仓库 ADR；
- `cc.zip` 不进入仓颉仓库、构建缓存、测试夹具或 Prompt 资产，后续实现 Agent 不再读取该包；
- 私有包研究只留下不具表达性的风险/模块清单，不能留下源码片段、字符串、接口签名、目录映射或近似 Prompt；
- 每个 Harness ADR 记录公开来源、仓颉需求、原创决定和禁止复制边界；
- 提交前扫描私有包名称、独特字符串、Prompt、Schema 和结构相似性；
- 由于同一项目早期研究曾接触该包，本文只能称为 **clean-room-inspired risk control**，不得对外宣称获得法律意义上的独立 clean-room 认证。

正式来源登记见 `docs/ARCHITECTURE_SOURCE_REGISTER.md`。

---

## 2. 宿主控制模型

仓颉运行显式宿主循环：

```text
Observe
→ Decide
→ Act
→ Verify
→ checkpoint / continue / wait / pause / finish
```

- **Observe**：从真实状态源读取任务、故事状态、权限、预算、用户消息和待处理回执；
- **Decide**：Harness 编译最小 Prompt/Context，模型只提出回复或 `ToolProposal`；
- **Act**：Harness 校验 Schema、权限、授权、预算、版本、Writer Lease 和幂等键后执行工具；
- **Verify**：以事务、Repository 后置条件和 `ToolReceipt` 验证是否真的完成；
- Tool result 必须回灌模型，禁止工具执行后继续基于旧上下文猜测。

不可破坏的不变量：

- 模型文本不是授权、事实、回执或完成证明；
- 所有副作用只经过注册的 Typed Tool；
- 外部网页、文档、参考小说和模型输出永远只是数据，不能改写权限、系统 Prompt 或工具策略；
- 同一书籍分支同一时刻只有一个 Writer owner；
- PreferenceProxy 只能预测、排序、预审、弃权和建议暂停，不能替用户批准；
- unknown outcome 必须先对账，禁止盲目重试；
- 下一章只能在当前章完成安全 checkpoint 后开始。

---

## 3. 九个正式 Runtime

| Runtime | 主要职责 | 明确禁止 |
|---|---|---|
| `DriverRuntime` | Provider 能力探测；流式、结构化输出、Tool Call、取消、用量、错误与结果对账归一化 | 按厂商名决定业务权限；直接写故事状态 |
| `PromptRuntime` | 分层、版本化、可审计地装配 Prompt；生成 Prompt manifest/hash | 让外部内容进入系统安全层；暴露完整 Prompt |
| `ContextRuntime` | 按证据、权限、外发范围和 token 预算编译最小上下文；生成可重现 manifest | 默认发送全书、全聊天、全部工具或全部故事记忆 |
| `LoopRuntime` | 驱动 Observe/Decide/Act/Verify 状态机、硬限制、no-progress、暂停与完成 | 无限追问、无限工具、无限修订；跳过 Tool result 回灌 |
| `ToolRuntime` | `proposal → validate → commit → verify → receipt`；Schema、权限、预算、幂等和事务 | 把模型 Tool Call 直接当已执行操作 |
| `TaskRuntime` | Session、TaskRun、ToolCall、Artifact、Checkpoint、UsageRecord 生命周期、队列与恢复 | 把聊天、任务、工具和成果混成一个对象；用 UI 猜状态 |
| `AgentTeamRuntime` | Subagent 独立上下文、工具、预算、权限和生命周期；只读并行 | 复制全部主上下文；多个 Writer 争夺正文；多人格直接打扰用户 |
| `GovernanceRuntime` | 章节、故事记忆、分支、重大剧情、授权、Writer Lease 和合并裁决 | 静默覆盖已通过正文；允许代理替用户批准 |
| `ObservabilityRuntime` | 强类型事件、脱敏日志、状态投影、费用、重试、checkpoint 和诊断 | 记录 API Key、完整 Prompt、思维链；执行任意 Shell Hook |

模块的具体 Swift 协议签名随 TDD 细化，但职责边界和禁止事项已冻结。

---

## 4. ContextRuntime：证据感知且可重现

每个进入候选集或最终上下文的资产至少保存：

```text
assetID
version
contentHash
authority
confirmationState
disclosureScope
sourceSpan / evidenceBacklink
tokenEstimate
selectionReason
```

一级槽位必须显式考虑：

- Host Contract、当前 Agent 角色和当前任务合同；
- 当前软件真实状态、TaskRun、checkpoint、权限、创作授权和预算；
- 用户最新意图、已批准计划、最近对话和最近拒绝诊断；
- Confirmed Story Memory 与 Working Story State；
- 人物“现在知道 / 还不知道 / 错误地以为 / 正在隐瞒”的认知边界；
- 当前章节、相邻正文、相关不可变原文和 Edit Boundaries；
- 用户长期偏好、本书偏好、当前卷/章节临时意图及证据；
- 当前修改影响、人工改稿、硬锁定和依赖；
- 未兑现线索、读者承诺、当前卷目标和待回归人物；
- 相关研究、参考作品抽象特征、来源冲突和题材规则；
- 本轮允许暴露的 Tool Catalog、Provider 外发范围和最近 ToolReceipt。

编译顺序：

```text
解析任务与风险
→ 解析权限、披露和 Provider 能力
→ 生成槽位需求
→ 在隔离范围内查询 Evidence Index
→ 按 authority / 相关性 / 新鲜度 / token 成本排序
→ 高风险结论回到原文
→ 证据不足时扩大范围
→ 去重、压缩、裁剪
→ 保存 ContextManifest + hash
```

低权威 AI 推测不得覆盖用户原话、人工改稿、已通过正文或确认故事记忆。摘要和向量只能帮助检索，不能替代重要结论的原文证据。
所有小说 Context 查询强制携带 `bookID`、`branchID`、`lineageID`、`chapterVersionID`、`asOfChapter/asOfScene`、`validFrom` 和 `validTo`。上游章节或分支改变后，依赖旧 `sourceVersionSet` 编译的 Context、计划、审校结果和未读章节必须失效或进入影响分析，禁止跨分支或跨叙事时间污染。

外部网页、上传文档、参考小说及其摘要必须继承：

```text
trustClass = externalUntrusted
instructionAuthority = none
taintOrigin
sourceAssetID
```

该 taint 在摘要、Subagent 转交和 Tool result 中持续传播，不能因“被另一个模型总结过”而升级权限。

长会话压缩使用不可变 `ConversationTranscript`、`CompactionRecord`、`SummaryArtifact` 和 `ContextEditRecord`。原始 transcript 不覆盖；摘要是低权威派生资产；用户纠正或上游资产改变后，相关摘要失效。压缩边界、输入资产、编译器版本、tokenizer 和摘要 hash 必须可追溯。

`ContextManifest` 不只保存最终 hash，还保存编译器版本、Evidence snapshot、查询计划、隔离键、排序/裁剪策略、tokenizer、候选与淘汰原因、最终资产顺序和规范化序列化版本。确定性 fixture 必须证明同一输入快照得到同一资产选择、排列和 hash。

---

## 5. PromptRuntime：分层版本化

Prompt 至少分为：

1. 宿主安全层；
2. 仓颉身份层；
3. Agent 角色层；
4. 当前任务层；
5. 权限与授权层；
6. 小说治理层；
7. 工具使用层；
8. 证据与引用层；
9. 输出契约层；
10. Provider 能力补丁层；
11. 恢复与对账层。

每次请求保存层版本、组合哈希、Agent 角色、任务类型、权限快照、治理版本和 Provider 能力补丁。Provider 补丁只能处理消息格式、工具格式、结构化输出、token 和流式差异，不能改变用户批准、Writer Lease、预算、外发或故事治理。
`PromptManifest` 还必须记录 Prompt 编译器版本、各层资产 ID/版本、规范化消息排列、输出契约、Provider 参数和 canonical serialization 版本。诊断日志不保存完整秘密 Prompt；需要重放时由本地受权限保护的资产和 manifest 重建。

工具不会全量塞入每次请求。`ToolCatalogManifest` 根据任务、Agent 角色、权限、风险和 Provider 能力加载最小工具集，并保存候选、加载原因、工具版本和 Schema hash。受控元工具 `capability.lookup` 只能发现当前白名单内的能力，不能扩大权限或外发范围。

---

## 6. LoopRuntime 状态机与硬限制

核心状态：

```text
queued
→ preparingTurn
→ compilingContext
→ awaitingModel
→ interpretingOutput
→ validatingAction
→ awaitingPermission / awaitingApproval
→ reservingBudget
→ executingTool
→ recordingObservation
→ decidingNextStep
→ checkpointing
→ preparingTurn / waitingUser / completed
```

暂停、恢复和失败状态必须显式区分：`waitingNetworkUserConfirmation`、`waitingNetworkSentRequest`、`pausedSafe`、`pausedImmediate`、`reconcilingUnknownOutcome`、`completed`、`failedRecoverable`、`failedTerminal`、`connectionInvalid`、`cancelling`、`cancelled`。UI 的恢复卡必须至少区分已完成、安全暂停、明确失败、结果未知和连接失效；数据库和状态机不能把它们压成一个 `paused` 或 `failed`。

每个 TaskRun 必须配置：

```text
maxTurns
maxToolCalls
maxCost
maxWallTime
maxNoProgressTurns
maxRevisions
maxSubagents
maxParallelReadOnlyWork
```

重复提出同一工具、反复生成同义候选、重复追问却不改变下一步、同一质量问题无限修订都算 no-progress。达到阈值后必须缩小目标、询问一个容易回答的问题、保存 checkpoint 或暂停。
模型请求内部必须继续区分 `preparingRequest`、`awaitingModel`、`streamingResponse`、`assemblingMessage`、`cancellingProvider`、`interrupted` 和 `partialOutputPersisted`。流式片段先写临时资产；收到完整终止原因并完成解析后才提交 `AgentTurn`。残缺正文不得进入故事状态、章节完成状态或领先章节计数。

结构化输出失败进入 `invalidModelOutput → boundedRepair → fallback / failedTerminal`。修复次数、token、费用和时间都受当前 TaskRun 硬限制，不允许隐藏无限重试。

Provider stop reason 只表示本轮模型停止。TaskRun 只有在任务级 postcondition 成立时才能 `completed`；例如章节任务必须同时满足正文候选、必要审校、故事状态、UsageRecord、幂等结果和原子 checkpoint 已提交。

---

## 7. Typed Tools：proposal / commit

```text
LLM Tool Call
→ ToolProposal
→ schema validation
→ permission / scope validation
→ approval / creative delegation validation
→ budget / disclosure / version / Writer Lease validation
→ idempotency lookup
→ transactional commit
→ postcondition verification
→ ToolReceipt
→ result ingested into next model turn
```

每个工具至少声明：输入/输出 Schema、允许角色、项目/书籍/章节范围、风险、审批、分级授权、预算、外发、幂等、事务、前置条件、后置条件和回执脱敏策略。
一次模型回合可以产生 `ActionBatch`。其中每个调用拥有独立 tool-use identity，组成 `ToolCallSet` 和 `ToolDependencyDAG`：无依赖只读调用可并行；写操作和有依赖调用严格串行；全部调用完成、拒绝、取消或失败后，按原始 identity 统一回灌模型。

需要审批的 `ToolProposal` 必须持久化：`proposalID`、输入/参数 hash、目标版本、前置状态 hash、权限/授权范围、创建时间、过期条件和风险摘要。审批状态至少区分 `awaitingPermission`、`awaitingUserApproval`、`approvalGranted`、`approvalDenied`、`approvalExpired` 和 `deferred`。批准后执行前重新校验权限、预算、目标版本、Writer Lease 和前置条件；拒绝、过期和延期同样生成结构化 Tool result 回灌模型，禁止重启后执行陈旧 proposal。

模型说“已经保存”不算完成。只有事务成功、后置条件可读取、UsageRecord 已记录且必要 checkpoint 已持久化，前台才能显示完成。

---

## 8. 运行时对象与 unknown outcome

以下对象必须分离，并使用不可变版本或追加式事件产生当前状态投影：

- `ConversationSession`：持续对话、当前主要小说上下文和恢复入口；
- `AgentTurn`：一次模型决策周期及其 Context/Prompt manifest；
- `TaskRun`：有目标、预算、状态机、限制和恢复点的任务；
- `ToolCall`：一次工具提议、验证、执行、验证和回执；
- `Artifact`：可阅读、采用、修改、继续执行或保存的真实产物；
- `Checkpoint`：可幂等恢复的安全边界；
- `ProviderRequest`：请求身份、发送/流式/结果状态和对账依据；
- `UsageRecord`：模型、搜索、OCR、索引和工具的真实用量/费用；
- `ChapterVersion`：正文、人工改稿、锁定范围、分支和审批状态；
- `CanonTransaction`：故事记忆、人物认知、时间线和承诺账本的提议与提交。

Provider 请求至少区分：`prepared → sent → streaming → responseComplete → committed`；中断后进入 `outcomeUnknown`，再对账为 `reconciledCompleted` 或 `reconciledNotCompleted`。
网络发送前必须先持久化 Provider request identity、Prompt/Context/ToolCatalog manifest、模型参数、TaskRun 关联、幂等身份、预算预留、数据披露范围和流式游标。每个可恢复流式片段保存内容 hash 与顺序；不能可靠拼接时只作为残缺资产保留，不提交为完成回复。

unknown outcome 对账：

```text
标记 unknownOutcome
→ 禁止自动重试副作用
→ 查询 Provider request identity / 本地事务 / ToolReceipt / Repository 后置条件
→ 判定 committed / notCommitted / stillUnknown
→ committed：补齐回执
→ notCommitted：记录已确认未提交；之后只能按正常连接、网络和用户确认策略决定是否复用幂等键重试
→ stillUnknown：暂停并说明风险，禁止直接重试
```

---

### 8.1 File intake, prose export, and backup are separate governed operations

The Tool catalog and persistence layer keep three contracts separate:

- `material.import` accepts TXT, Markdown, DOCX, PDF, scanned PDF, and ZIP as untrusted data. Persist the immutable source before derived work. Parsing, OCR, classification, and indexing use TaskRun/Checkpoint/UsageRecord and can continue after navigation, suspension, crash, or cancellation. OCR is conditional on extraction evidence. ZIP processing validates paths, type, count, compression ratio, and size, and exposes no script/macro/command execution surface; embedded text cannot become instructions or permissions.
- `export.create` for `导出小说` reads a pinned current-mainline version set and emits only the selected prose projection as TXT, DOCX, or Markdown. Confirmation state is explicit; unconfirmed chapters cannot silently enter the formal manuscript. Internal conversations, approvals, receipts, Story Memory, costs/tasks, credentials, IDs, and diagnostics are outside the export schema.
- `backup.create` serializes the recoverable creative-state graph and required recovery metadata but applies a hard credential denylist: API keys, Keychain plaintext, authorization headers, login credentials, and credential-recovery material are impossible fields. `backup.restoreAsCopy` creates a new project identity by default. `backup.proposeReplacementRestore` is a separate high-risk proposal requiring an atomic pre-replacement recovery snapshot, impact diff, exact target binding, and explicit approval.

Password protection wraps the backup artifact but does not create a recovery channel; the manifest records that forgotten passwords are unrecoverable. Device/install persistence claims remain acceptance receipts bound to an exact build and scenario.

### 8.2 Host lifecycle, offline queue, stream quarantine, and notifications

A host lifecycle barrier runs before backgrounding, screen lock, or detected connectivity loss as far as the OS allows. It durably records the composer draft, `TaskRun` stage/version, `ProviderRequest` identity/state, received stream cursor/fragments/hashes, `UsageRecord` and reserved/settled cost, and the latest safe `Checkpoint`. The barrier provides recoverability only; it is not evidence that iPadOS 16.6.1 will grant unlimited background execution.

Recovery projection is derived from durable state and has five user-facing classes:

```text
completed
pausedSafe
failedDefinite
outcomeUnknown
connectionInvalid
```

`reconcilingUnknownOutcome` is a non-creative recovery operation. It may query the original request identity and inspect local transaction state, stream assets, UsageRecord, ToolReceipt, outbox and Repository postconditions. It must not issue a new creative model request, reserve a new creative budget, settle a new creative charge, or silently substitute a connection. While the result remains unknown, retry is forbidden.

Offline intent has two different contracts:

- A new AI request created offline enters `waitingNetworkUserConfirmation`. It persists intent, binding, disclosure scope and continuation point, but does not create a `sent` ProviderRequest. Connectivity restoration emits a user-confirmation event; only explicit confirmation may prepare and send it.
- A request already in `sent` or `streaming` before connectivity loss enters `waitingNetworkSentRequest` / `outcomeUnknown` and may automatically reconcile that original request identity. Reconciliation is not permission to regenerate.

Local project, prose, material, draft, export and backup tools remain available offline when their own prerequisites are satisfied. They must not be routed through DriverRuntime merely to keep the UI consistent.

Interrupted stream assets are marked `partialUncommitted` with request identity, ordering and content hashes. `ToolRuntime` and `GovernanceRuntime` reject them as input to formal ChapterVersion adoption, CanonTransaction, CharacterKnowledge/state, PromiseLedger settlement or completed-ahead counts. They may be displayed only as explicitly incomplete temporary material. A later completed response creates a separate verified artifact; it does not mutate the partial asset into committed truth.

Notification delivery is an `ObservabilityRuntime` projection over durable events, never a TaskRuntime transition or completion condition. Eligible events are result completion, user confirmation required, task pause/failure, cost limit and major-story gate. Permission is requested contextually at the first long task after explanation, not on first launch. Denial, revocation, delivery failure or disabled notifications cannot pause, cancel, retry or otherwise alter a task.

The ordinary task projection exposes only `正在做`, `接下来` and `需要你`, plus concise checkpoint/cost facts. This does not collapse internal states. `WriterLease` still enforces one prose Writer per novel, and `pausedImmediate` remains distinct from pause-after-chapter. Provider failure remains pinned to the current `ModelConnection`; recovery may reconnect it or wait for an explicit user-selected connection, never auto-switch Provider, model or credential.

## 9. Writer Lease、Subagent 与提交治理

每个 Subagent 拥有独立的 ContextManifest、PromptManifest、工具白名单、预算、权限、生命周期和结果合同。普通用户只看到统一人格“仓颉”。
Subagent 使用持久化 Task DAG：`parentTaskRunID`、`spawnToolCallID`、`agentID`、`budgetReservation`、`cancellationPolicy`、`resultContract` 和 `terminalReceipt`。子预算从父预算预留；父任务暂停/取消时按策略级联，孤儿任务不得继续产生费用。所有并行只读 Agent 绑定同一不可变 `sourceVersionSet`，过期结果只能重新验证，不能直接合并。

`WriterLease` 至少包含 `bookID`、`branchID`、`chapterID`、`ownerTaskRunID`、`monotonicFencingToken`、`acquiredAt`、`expiresAt` 和 `leaseState`。每次正文与故事状态提交都在同一事务中校验 fencing token；旧 token 永久失效，防止崩溃恢复后的双 Writer。

可以并行：只读研究、资料解析、互不依赖的文风/连续性/题材纯度/偏好盲读审校。

必须串行：正文正式写入、故事记忆结算、章节批准、分支创建/合并、重大剧情提交和章间推进。

安全 checkpoint 固定顺序：

```text
正文候选与独立审校完成
→ 外部大资产按内容 hash 预写但尚不采用
→ 开始单个 SQLite 事务
→ 校验 WriterLease fencing token、目标版本和幂等键
→ 原子提交 ChapterVersion、Working Story State、人物认知、线索/承诺、UsageRecord、ToolReceipt、资产引用和 Checkpoint 记录/当前指针
→ 提交事务并读取后置条件验证
→ transactional outbox 处理无法纳入 SQLite 的后续副作用
→ 下一章
```

Checkpoint 不是事务之后另写的一张便签；它本身和被它指向的状态必须原子提交。SQLite 已提交但 checkpoint 指针未提交的状态在设计上不得出现。

总编剧组织 proposal 和一般分歧；`GovernanceRuntime` 是正文、故事记忆、分支和重大剧情正式合并的唯一治理入口。

---

## 10. AgentEventBus 与可观测性

首版 Hooks 只实现为内部强类型 `AgentEventBus`，事件包括任务状态、Context 编译、Prompt 装配、Driver 请求、工具提议/提交、unknown outcome、Writer Lease、checkpoint、预算、no-progress 和 Subagent 生命周期。

- Event payload 使用版本化 Schema；
- 默认订阅者只读；任何副作用仍走 Typed Tool；
- 不开放任意 Shell、脚本、动态代码或未审计第三方 Hook；
- 不记录 API Key、Authorization、Cookie、完整 Prompt、私密思维链或无关版权正文；
- 对话、“这次结果”和“AI 任务”页从同一个 TaskRuntime/Artifact/ToolReceipt 投影读取。

---

## 11. Provider-neutral 能力 Tier

业务逻辑只检查能力契约，不检查厂商名：

| Tier | 最低能力 | 适用范围 |
|---|---|---|
| `TierText` | 文本、标准错误、取消或超时边界 | 低风险问答和草稿 |
| `TierStructured` | `TierText` + 可靠结构化输出 | 计划、抽取、审校、候选比较 |
| `TierTool` | `TierStructured` + 原生或等价 Tool Call、Tool result 多轮回灌 | 完整受控 Agent Loop |
| `TierRecoverable` | `TierTool` + request identity、用量和可对账恢复能力 | 长时、付费、可恢复生产任务优先路由 |

能力还需独立声明 context window、max output、streaming、cancellation、usage、structured output、tool calling、native search、缓存、错误分类和数据保留。无法满足任务最低能力、披露或恢复要求时必须拒绝路由或明确降级。

---

A `ModelConnection` (Provider, Base URL, credential reference, selected model) is supplied by the user-facing connection layer. The Harness validates its capability snapshot and pins each request to that connection; it does not select Providers, rotate keys, auto-route tasks, or take over after failure. Connection failures become structured recovery state for the user to reconnect or manually choose another saved connection.

### 11.1 No-current-connection host boundary

No current `ModelConnection` is a supported local state, not a Driver error that may be hidden with canned AI text. The host may execute only real local operations with durable receipts: save thoughts/drafts, query local novels/history, read saved prose/materials, inspect local versions/task history, and open connection management.

Before any AI-dependent operation, the Loop enters a structured `modelConnectionRequired` wait state and persists the original request, ConversationSession, project/branch binding, draft, and continuation point. It does not create a sent ProviderRequest, settle model usage, or publish an AI artifact. After explicit Provider, Key/Endpoint, model discovery, model selection, and capability validation, the Harness resumes the same intent. Failure remains recoverable waiting state and exposes only retry, correction, refresh, or user-selected manual connection change.

Multiple keys arrive as independent named ModelConnections. The Harness accepts only the user-selected current connection and never auto-selects Providers, polls keys, load-balances, substitutes models, or takes over after failure.

## 12. H0–H5 实施顺序

- **H0 运行时数据边界与可重放夹具**：分离十类对象，建立不可变版本/追加式事件、当前状态投影、确定性时钟、脱敏和 fixture；
- **H1 DriverRuntime + PromptRuntime**：能力探测、Provider-neutral 事件、错误/用量/取消/对账、11 层 Prompt 和 manifest；
- **H2 ContextRuntime**：一级槽位、authority/disclosure/token reason、Evidence Index 查询、范围扩大和可重现 manifest；
- **H3 LoopRuntime + ToolRuntime**：显式状态机、硬限制、proposal/commit、ToolReceipt、事务和结果回灌；
- **H4 TaskRuntime + checkpoint + unknown outcome**：队列、暂停/恢复、三处同源状态、安全 checkpoint 和费用对账；
- **H5 AgentTeamRuntime + GovernanceRuntime + ObservabilityRuntime**：Subagent 隔离、只读并行、Writer Lease、合并治理、PreferenceProxy 权限拒绝和诊断投影。

决策合同：`CJ-PX-007 / FROZEN / 2026-07-19`。

H0–H5 必须按顺序推进，且不能单独包装成没有用户价值的空壳 IPA。它们与用户可见 S0–S6 的冻结映射是：

- S0–S6 的当前验收状态和真实里程碑只由 `PROJECT_CONTROL_CENTER.md` 维护；本文只定义 Harness 架构与阶段关系。S0 只代表技术可行性基线完成，candidate-hardening 历史 M1 与 Builds 26–28 仅为工程原型/硬化证据。
- **S2** 首次接入真实 Provider，完成 no-key → Provider/Key/Endpoint → model discovery → user-selected model → central Agent Typed Tool project/status → ToolReceipt → force-quit recovery 的无正文最小闭环，并通过适用 H0–H3。
- **S3** 以常规规模资料完成动态意图、一次一个高价值问题、参考抽象学习、偏好证据、作品方向和开篇准备，推进 H4 主干，但不宣称百万字完整能力或 H4 完成。
- **S4** 完成真实正文、选区交流、模糊拒绝诊断、影响预览、版本差异、前三章逐章校准和单独连续创作授权，完成 H4 并进入 H5。
- **S5** 正式验收滚动自动连载、最多五章未读、重大决定/预算暂停、两种暂停、分支影响、百万字叙事索引、大型参考小说分阶段分析，并完成 H5。
- **S6** 对全格式/百万字资料、质量、干净正文导出、无凭证备份恢复、无障碍、性能、迁移和安全进行正式候选级回归。

每阶段先写失败测试，再实现最小闭环。不得跳过 H0–H2 直接堆多 Agent 自动连载。

最低验收包括：

- 模型不能直接产生副作用；
- Tool result 未回灌时循环不能继续；
- Context/Prompt manifest 可重现；
- 硬限制和 no-progress 真实暂停；
- unknown outcome 不重复提交或扣费；
- Writer Lease 阻止并发正文写入；
- Subagent 权限、上下文和预算隔离；
- PreferenceProxy 无批准/合并权限；
- EventBus 无 Shell/脚本执行面；
- ProviderRequest 发送前已持久化，unknown outcome 可对账；
- 审批 proposal 绑定精确输入/版本并可拒绝、过期、延期和恢复；
- ActionBatch 的多工具 identity、依赖、并行和回灌顺序正确；
- Writer Lease fencing token 阻止旧任务双写；
- 章节状态、Usage、回执和 Checkpoint 原子提交；
- 分支/版本/叙事时间隔离、compaction 失效和外部 taint 传播有回归测试；
- 前台完成状态来自真实回执而非模型自述。

每个产品阶段报告必须声明版本性质、已包含、未包含、自动化证据和精确真机证据。真机候选把版本、Build、commit、SHA-256 和 candidate identity 绑定到入口、控件位置、动作、结果位置、失败信号和恢复方法。未受影响的旧行为可采用差异验收；权限、凭证隔离、预算、幂等、unknown outcome、Writer Lease、恢复和外部披露等安全合同必须在精确候选上重新证明。绿色 CI、静态 UI、文档或代码完成都不能替代这些门槛。

---

## 13. 明确非目标与状态边界

首版不做：复刻 Claude Code 内部实现、用户专属权重蒸馏/LoRA、任意代码 Hooks、模型直接读写 SQLite/文件/Keychain、多 Writer 并写同一正文、每次发送全书/全聊天/全部工具，或按 Provider 厂商名硬编码业务治理。

**最终状态：工程架构基线已确认，具体接口随 TDD 细化；在 H0–H5 验收通过前，不得把本文内容宣传或记录为已经实现。**
## 14. Additional confirmed Harness contracts from 1.md

This section records previously approved contracts that were not explicit enough in the architecture baseline. It does not reopen product direction.

### 14.1 Driver Cockpit Snapshot

每次模型接手任务时，仓颉会给它一份精简的“驾驶舱状态”，例如：

```text
你是仓颉，一款网络小说创作Agent。
当前用户正在使用iPad版仓颉。

当前所在位置：
仓颉对话

当前项目：
《暂定名》
类型：洪荒流
状态：正在讨论开篇
已经确认：主角是先天人族
尚未确认：主角初始目标
正在运行的任务：无
等待用户确认的结果：1项

你可以使用：
创建和查看小说项目
读取项目资料
整理用户已经确认的想法
搜索资料
创建待审阅设定
生成章节计划
开始、暂停和继续创作
查看任务进度
展示正文和本次结果
导出小说

你不能：
读取API Key原文
绕过用户确认修改已通过正文
把参考小说当成当前书的事实
绕过费用上限
直接删除不可恢复数据
```

它不需要接收整个数据库，只需要接收：

```text
当前任务真正需要的状态
可用工具
当前权限
仍未解决的问题
相关故事记忆
```

这样模型才会知道：

```text
自己是谁
当前在哪
现在正在做什么
已经做到了哪里
接下来能做什么
什么事情不能自己决定
```

---

### 14.2 Semantic Typed Tool surface

模型不模拟点击，也不直接操作 SwiftUI 页面。

它调用稳定的**语义工具**：

```text
project.create
project.list
project.open
project.rename

conversation.search
conversation.bindProject

material.import
material.classify
material.index
material.query

research.search
research.readURL
research.saveEvidence

storyMemory.query
storyMemory.propose
storyMemory.diff

artifact.present
artifact.approve
artifact.reject

chapter.plan
chapter.generate
chapter.status
chapter.open

generation.start
generation.pauseAfterChapter
generation.pauseNow
generation.resume
generation.cancel
generation.status

branch.create
branch.impactAnalysis

export.preview
export.create

backup.create
backup.verify
backup.restoreAsCopy
backup.proposeReplacementRestore

budget.status
task.status
task.checkpoint
```

每个工具都有明确输入和返回结果。

例如：

```json
{
  "tool": "project.create",
  "arguments": {
    "temporaryTitle": "未命名洪荒小说",
    "projectType": "webNovel",
    "language": "zh-Hans"
  },
  "idempotencyKey": "conversation-17-message-42-project-create"
}
```

工具返回：

```json
{
  "success": true,
  "projectID": "project-103",
  "displayName": "未命名洪荒小说",
  "createdAt": "2026-07-18T20:30:00+08:00",
  "wasAlreadyCompleted": false
}
```

然后仓颉才能对用户说：

> 已经帮你建好一本暂定名为《未命名洪荒小说》的新书。名字不用现在决定，等我们把真正的卖点想清楚后再取也不迟。

---

### 14.3 Five-level tool permissions

## 第一级：只读查询

例如：

```text
查看项目
查看章节
查看任务状态
查询人物资料
查询费用
搜索原文
```

默认可以直接执行。

---

## 第二级：安全、可逆操作

例如：

```text
创建临时项目
保存聊天草稿
整理未确认想法
创建候选版本
建立checkpoint
暂停生成
恢复安全任务
```

默认直接执行，完成后告诉用户。

---

## 第三级：产生待审阅内容

例如：

```text
生成故事方向
整理人物设定
创建开篇方案
生成章节计划
生成正文候选
```

可以自动生成，但不能冒充用户已经批准。

结果必须标为：

```text
仓颉准备的版本，等你看
```

---

## 第四级：需要明确确认

例如：

```text
冻结章节
修改已经通过的正文
采用重大故事方向
让重要人物死亡
改变主角核心目标
覆盖用户手写内容
正式导出覆盖已有文件
删除项目
```

必须经过审批或已有明确授权。

---

## 第五级：模型永远不能做

例如：

```text
读取API Key原文
关闭费用硬上限
绕过权限
静默向外部发送整本小说
执行任意Shell
运行第三方Skill代码
隐藏真实费用
伪造工具执行成功
修改安全策略
```

即使用户用自然语言要求，也需要由宿主程序拒绝，而不是依赖模型“自觉”。

---

### 14.4 Provider capability probes and three driving modes

用户可能接入：

```text
OpenAI
Anthropic
Gemini
DeepSeek
(other compatible Provider, only after explicit user configuration)
自定义OpenAI-compatible接口
其他兼容模型
```

不能假定它们能力完全相同。

仓颉连接 Provider 后要自动进行能力探测：

```text
是否支持流式输出
是否支持标准工具调用
是否支持结构化JSON
是否支持取消请求
是否返回Token用量
是否支持系统提示
是否支持长上下文
是否支持原生搜索
是否支持图像
是否支持Embedding
```

然后给模型分级。

## 完整驾驶模式

模型可靠支持：

```text
工具调用
结构化输出
流式输出
取消
用量信息
```

可以作为仓颉主驾驶员。

---

## 受限驾驶模式

模型支持文本和结构化 JSON，但工具调用不够标准。

仓颉可以通过严格验证的适配器支持部分工具，但限制高风险操作。

例如可以：

```text
查询项目
创建草稿
生成正文
提出工具请求
```

但涉及正式修改和复杂连续任务时，需要更严格验证。

---

## 仅创作模式

模型只能稳定生成文本，无法可靠调用工具。

它可以作为：

```text
正文写手
摘要模型
灵感模型
文风编辑
```

但不能作为控制整个软件的主驾驶员。

仓颉要明确告诉用户：

> 这个模型可以参与写作，但暂时不能可靠地操作项目、任务和审批。你可以保留它作为正文写手，再选择一个支持工具调用的模型负责仓颉对话。

不能让一个不支持工具的模型假装执行成功。

---

### 14.5 Structured rejection without project pollution

例如模型错误调用：

```text
generation.start
```

但当前还没有通过前三章，工具层应直接返回：

```text
拒绝执行
原因：前三章校准尚未完成
当前状态：第一章等待用户确认
可以执行：打开第一章、继续讨论、创建新版本
```

模型再向用户解释：

> 现在还不能开始连续创作，因为第一章还在等你确认。我可以先把第一章打开，或者根据你刚才的意见再调整一次。

因此：

> **模型可以提出行动，但最终执行权属于仓颉工具和状态机。**

驾驶员即使操作失误，高达自身的安全系统也会阻止它撞墙。

---
