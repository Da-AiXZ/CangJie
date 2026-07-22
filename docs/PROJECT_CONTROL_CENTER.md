# CangJie Project Control Center

- Authority: current operational truth
- Updated: 2026-07-21
- Repository: `F:\project\CangJie`
- Remote: `https://github.com/Da-AiXZ/CangJie`, branch `main`
## Agent Harness architecture decision

- Decision ID: `CJ-AH-001`
- Decision Status: `FROZEN`
- Confirmed: 2026-07-18
- Canonical specification: `docs/AGENT_HARNESS_ARCHITECTURE.md`
- Implementation status: architecture frozen; H0-H5 not yet implemented or accepted.

仓颉的工程主体不是某个 LLM，也不是“聊天 + Prompt + 工具列表”。权威工程基线见 `docs/AGENT_HARNESS_ARCHITECTURE.md`：

```text
LLM：可替换驾驶员，只提出下一步或 ToolProposal
CangJie Harness：掌握主循环、真实状态、权限、预算、事务、恢复和完成判定
Typed Tool：唯一副作用入口，返回可验证 ToolReceipt
```

正式 Runtime 为 Driver、Prompt、Context、Loop、Tool、Task、AgentTeam、Governance 和 Observability。Context/Prompt 必须版本化和可重现；任务恢复不能只恢复聊天；unknown outcome 必须先对账；子 Agent 必须隔离上下文、工具、权限和预算；正文写入使用单 Writer Lease。

状态声明：**工程架构基线已建立，具体 Swift 接口随 TDD 细化；当前不代表 H0–H5 已实现。** 下一工程顺序是 H0 数据边界与可重放夹具，再推进 H1 Driver/Prompt、H2 Context、H3 Loop/Tool、H4 Task/恢复、H5 多 Agent/治理/可观测性。

Clean-room 边界：只参考 Anthropic 官方公开文档与 Agent SDK 的公开接口和行为；`cc.zip` 为 private/unlicensed 非官方材料，只允许高层架构对照，严禁复制源码、Prompt、Schema、字符串、测试、注释、目录结构或接口签名。
2026-07-18 独立架构审查曾发现三项实现阻断风险：Checkpoint 非原子、ProviderRequest 无持久生命周期、审批 proposal 无可恢复等待协议。权威文档现已改为：章节/故事状态/Usage/回执/Checkpoint 原子提交；请求发送前持久化并对账 unknown outcome；proposal 绑定精确输入/版本、可拒绝/过期/延期并在执行前重新校验。并补齐流式残缺输出、多工具 ActionBatch、ToolCatalogManifest、Writer Lease fencing token、分支/叙事时间隔离、Subagent Task DAG、会话 compaction 和外部 taint 传播。以上仍是架构修正，不是已实现能力。

来源和使用边界登记：`docs/ARCHITECTURE_SOURCE_REGISTER.md`。

## Product decision granularity rule

Provider connection, model choice, saved credentials, multiple connections, retry, and connection failure handling are one user-facing product area: **Provider and model connection lifecycle**. `CJ-PX-001` through `CJ-PX-003` remain implementation trace IDs under this single area, not separate approval questions.

## Provider and model connection lifecycle (FROZEN)

- Decision status: `FROZEN`; Provider/model lifecycle confirmed 2026-07-18, no-key/deferred-setup behavior confirmed 2026-07-19.
- A clean install with no saved or current connection still opens the central CangJie conversation. Real local actions remain available: save thoughts/drafts, browse local novels and history, read saved prose/materials, inspect local versions/task history, and manage connections. No model analysis, generation, revision, review, research, or deep material understanding may be claimed without a usable connection.
- The first connection is requested only when the user first asks for AI-dependent work, or explicitly opens connection management. CangJie persists the triggering request and continuation point before setup. After explicit Provider/model selection it returns to the same conversation and continues that request without asking the user to repeat it.
- The first connection starts in the central CangJie conversation. The user chooses a concrete service before entering a key. The first-release choices are `DeepSeek`, `Claude / Anthropic`, `GPT / OpenAI`, `Gemini`, `OpenRouter`, and `Custom service`; the catalog may add another explicit connector later without changing this contract.
- After a service is chosen, its connector supplies the current official Base URL and model-list endpoint. The user enters the key, CangJie connects, retrieves every model that key can access, and the user explicitly selects the model to use. CangJie never guesses a model from a key prefix or silently picks a different model.
- One saved model connection is exactly: `Provider + Base URL + API Key + user-selected model`. Each connection is independent and is tested, refreshed, and saved on its own.
- Users may save multiple connections, including multiple keys for the same service. Only one connection is current at a time. The user manually chooses which saved connection is current; a change affects new work and is visible in the connection status.
- There is no automatic task routing, quality/cost mode, Provider switching, key rotation, load balancing, or failure takeover. A request already sent remains bound to the connection and model it used. A failure offers only honest recovery actions: reconnect, refresh the model list, re-enter the key, or manually select another saved connection and retry when appropriate.
- A custom service asks for a connection name, OpenAI-compatible Base URL, and key. CangJie requests `/models` from that Base URL when supported; if the service cannot list models, the user may enter a model name manually. Discovery failure is shown plainly and never causes probing of other hosts.
- Keys are stored only in Keychain and shown only as a masked suffix. Logs, exports, diagnostics, error messages, and model records never contain the full key or authorization headers. Deleting a connection never deletes novels, chapters, conversations, artifacts, or results. If the connection is current or needed by an unfinished request, CangJie first requires an explicit switch or cancellation before deletion.

Default official connector values maintained by the connector registry:

| Service | Default Base URL | Model discovery |
|---|---|---|
| DeepSeek | `https://api.deepseek.com` | `GET /models` |
| Claude / Anthropic | `https://api.anthropic.com` | `GET /v1/models` |
| GPT / OpenAI | `https://api.openai.com/v1` | `GET /models` |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | `GET /models` |
| OpenRouter | `https://openrouter.ai/api/v1` | `GET /models` |

These are connector defaults, not credentials or a promise that every model supports every Agent capability. The runtime still records the selected connection's capability result and reports unsupported operations honestly. The connection UI, Keychain integration, model discovery, and real request vertical slice belong to S2 and are not claimed complete merely because this product contract is frozen.

## File intake, novel export, and project backup lifecycle (FROZEN)

- Decision status: `FROZEN`, confirmed 2026-07-19.
- The front end presents three separate actions: `添加资料`, `导出小说`, and `备份项目`. They are not alternate labels for one generic file operation.
- Add materials accepts TXT, Markdown, DOCX, PDF, scanned PDF, and ZIP. It safely persists the original before classification, OCR, indexing, or external analysis; applies the frozen material-purpose and isolation rules; checkpoints large parsing/OCR/indexing jobs; allows the user to leave; suggests OCR only when needed; and treats ZIP entries as inert untrusted data, never executable scripts or instructions.
- Export novel produces clean TXT, DOCX, or Markdown from the current mainline. Unconfirmed chapters do not silently become formal prose. Conversations, approvals, receipts, Story Memory, cost/task records, credentials, internal IDs, and diagnostics are excluded.
- Project backup preserves complete creative state and recovery information but excludes API keys, Keychain plaintext, authorization headers, and login credentials. Restore creates a copy by default. Replacement requires a pre-replacement recovery snapshot, an impact preview, and explicit approval. Optional password protection is permitted only with an upfront warning that lost passwords cannot be recovered.
- The product warns that deleting the App may delete local projects and prompts users to back up before moving devices. Overwrite-install and force-quit persistence claims remain candidate-specific acceptance facts, not general promises.
- Implementation remains staged; this frozen product contract is not evidence that S3/S6 import, export, backup, OCR, or restore is already complete.

## Background, offline, recovery, and notification lifecycle (FROZEN)

- Decision status: `FROZEN`, confirmed 2026-07-19 as `CJ-PX-006`; this contract did not by itself advance the then-current S1 milestone. The authoritative current stage is tracked below under `Current milestone`.
- Before backgrounding, screen lock, or detected network loss, persist the draft, real task stage, Provider request identity/state, received stream fragments, recorded cost, and latest safe continuation point. This recovery contract never promises unlimited background execution on iPadOS 16.6.1.
- Recovery must distinguish completed, safely paused, definitely failed, outcome unknown, and invalid connection. Unknown outcome first performs non-creative reconciliation against the original request and local receipts/usage; it must not issue a new creative request or charge, and cannot be directly retried while still unknown.
- Offline use includes local projects, prose, materials, drafts, novel export, and project backup. New AI requests created offline remain unsent and require user confirmation after connectivity returns. Requests already sent may automatically reconcile their original identity.
- Interrupted streaming is only an incomplete temporary artifact and cannot enter formal chapters, canon, character state, foreshadowing/promise settlement, or completed-ahead counts.
- Notifications are optional and limited to completion, waiting for confirmation, pause/failure, cost limits, and major-story gates. Do not request permission on first launch; explain and ask at the first long task. Refusal changes only notification delivery, not product function.
- Ordinary task UI uses `正在做 / 接下来 / 需要你`. One novel has one prose Writer. Immediate pause and pause-after-chapter remain different operations.
- Provider failure may reconnect the current named connection or wait for a user-selected saved connection only. Automatic Provider, model, or key switching remains forbidden.

## Product stages and evidence-bound acceptance (FROZEN)

- Decision status: `CJ-PX-007 / FROZEN`, confirmed 2026-07-19.
- CangJie uses S0–S6 as user-visible product stages and H0–H5 as sequential Harness engineering gates. Exact Run-31 automation and physical-device evidence accepted S1 on 2026-07-21; the current real milestone is **S2 真正可操作软件的 Agent**. S0 is only the completed technical-feasibility baseline.
- Historical candidate-hardening M1 labels and Builds 26–28 are engineering-prototype/hardening evidence, not the current complete-product milestone. Build 28 is not accepted.
- S2 proves the first real Provider and the no-key → Provider/Key/Endpoint → model discovery → user-selected model → central Agent Typed Tool project/status → ToolReceipt → force-quit recovery loop, passes the applicable H0–H3 gates, and contains no formal prose generation.
- S3 adds dynamic intent discovery, one high-value question at a time, authorized reference abstraction, preference evidence, work direction and opening preparation. It uses ordinary-scale materials only and advances the H4 main path without claiming complete million-character understanding.
- S4 adds real prose, selection conversation, ambiguous-rejection diagnosis, impact preview, version diff, first-three-chapter calibration and separate continuous-creation authorization; it completes H4 and enters H5.
- S5 formally accepts rolling serial generation, at most five unread chapters, major-decision/budget pauses, both pause semantics, branch impact, the million-character narrative index, phased large-reference-novel analysis, and complete H5.
- S6 completes TXT/Markdown/DOCX/PDF/OCR/ZIP/million-character material handling, quality review, clean TXT/Markdown/DOCX prose export, credential-free backup/restore, accessibility, performance, migration and security audit, and a formal release candidate.
- Every stage report states candidate nature, included and excluded scope, automation evidence and exact device evidence. Device acceptance binds version, Build, commit, SHA-256 and candidate identity to the entry path, control location, action, result location, failure signal and recovery method. Unchanged behavior uses differential acceptance, but security contracts are re-proved on the exact candidate. Green CI, static UI, documentation or code completion never passes a product stage. H0–H5 advance in order and are never packaged as empty Harness IPAs.

## Product and UI decision

仓颉已经完成产品重新定调。第一核心用户不是职业作者，而是爱看小说、不会写作、不懂专业术语、只能表达模糊念头或读者感受的普通小说爱好者。

默认产品体验遵循：

```text
普通用户说人话、看故事、表达感觉，决定重大事项或明确授权仓颉代决策
→ 统一人格“仓颉”主动理解、追问、建议和执行
→ Typed Tools 真实操作项目、设定、正文、任务和导出
→ 多 Agent 小说团队与长篇治理在后台工作
```

已确认的响应式工作区合同：

- 打开 App 直接进入仓颉对话；
- 横屏最左侧保留只显示图标的 Activity Bar，长按显示名称和用途；
- 点击“我的小说”等入口后，在左侧自己的导航栈中进入独立页面，不能原地展开树或重建对话；
- 有正文时横屏正文约占 2/3、右侧约占 1/3；右侧只有一个区域，用“仓颉 / 这次结果”标签切换，不增加第四列；
- 阅读器、右侧区域和左侧页面都可开关，阅读器可最大化；
- 竖屏一次只显示“阅读 / 仓颉 / 这次结果”中的一个主要区域；
- 旋转、切换标签和开关面板不能丢失草稿、滚动、流式输出、章节、选区引用或任务状态。

已确认的正文反馈合同：

```text
自由选中文字
→ 问仓颉
→ 自动带章节、版本、精确选区和前后文
→ 能直接理解则给修改影响范围预览
→ 不清楚才动态追问
```

第一层菜单冻结为 `复制 | 问仓颉 | 更多`。“原样保留”已从第一层主路径删除。选区只表示当前讨论焦点和修改分析起点，不自动表示喜欢、不喜欢、问题或锁定，也不能替用户确认喜欢原因。“更多”提供“这段我喜欢 / 这个感觉别丢 / 只讨论这段 / 标记为问题”等软反馈；只有明确点击“锁定文字不变”或说“这句一个字都不要动”等无歧义命令，才建立精确硬锁定。AI 对喜欢原因只能提出可纠正推测。

已确认的修改影响范围与依赖重连合同：

- 选区是修改起点，不是最终影响边界；
- 修改前用人话预览句子、场景、章节、后文、已通过正文、用户人工改稿和硬锁定的影响；
- 需要扩大范围时提供“连带改顺后面 / 只改这里但可能不连贯 / 另建版本试试 / 先别改”；
- 尚未通过的工作内容可以选择性重生成；已通过正文不得直接覆盖，必须保留旧版本、建立分支并由用户裁决；
- 用户人工改稿优先作为当前依据，不能被旧 AI 稿覆盖；
- 修改按依赖顺序重连，完成后重新检查人物知识、时间、因果、线索/读者承诺和题材规则，禁止中间改了而后文继续沿用旧逻辑。

所有修改仍必须经过精确版本绑定、权限、审批、预算、幂等、依赖证据和真实工具回执。

已确认的视觉方向是接近 Claude Code 设计理念的克制、安静、现代、中性暖色与少量暖橙强调，但必须是仓颉自有设计系统，不得声称使用 Claude 官方色值、组件或品牌资产。旧纸墨朱红、卷轴、毛笔和印章方向已废弃。

已确认的默认自主模式是**“关键事情问我”**：

- 创建、保存、整理未确认内容、查询、检查、checkpoint、安全暂停/恢复和未提交草稿等安全可逆日常操作直接执行，完成后告知；
- 正文、用户已看内容的修改和重要创作方向先展示可审阅结果，再由用户确认；
- 普通、可逆且不改变整书方向的创作决定直接执行并告知；
- 主角核心目标、重要人物生死/永久背叛/彻底黑化、核心关系、世界/能力硬规则、主线/卷纲/结局承诺等重大变化，只有在有效授权覆盖相应类别和小说/卷/章节范围时才可代决策；未覆盖必须在安全 checkpoint 前暂停；
- 前三章逐章校准，三章通过后才提高自动化程度；
- 可提供“少打扰我 / 关键事情问我 / 每一步都让我确认”，但任何模式和创作授权都不得绕过费用硬上限、任务完整性、安全、权限、版本/幂等/checkpoint、外部数据披露和不可逆删除边界。

已确认的自动连载分级创作授权合同：

- 连续创作授权只允许任务持续推进，不等于把所有重大决定永久交给仓颉；
- 用户可以用自然语言按决定类别、某一卷、某些章节或其他明确范围授权，授权必须可查看、撤销、版本化并记录来源与生效范围；
- 一次具体选择不得静默扩大成永久授权；撤销后尚未执行的重大决定重新进入暂停门；
- 未授权重大变化的暂停卡必须说明为什么暂停、影响哪些内容、给出 2–3 个具体方向和仓颉推荐，并一次只问一个容易回答的问题；
- 已授权重大决定执行后必须醒目标记实际选择、影响范围和所用授权；
- 费用、任务完整性、权限、安全、外部数据披露和版本治理属于不可委托硬边界。

已确认的动态意图合同：

```text
理解一点
→ 做一点
→ 让用户看见
→ 再继续理解
```

- 不是固定问卷；一次只问一个会改变下一步创作决定且容易回答的主问题；
- 正常约 2–4 个高价值问题后给画面、小样或候选，但该数字只是节奏指导，不得硬编码；
- 用户不知道时使用具体画面、差异对比、阅读经历、反向排除或可撤销临时决定；
- 内部区分用户原话、用户已确认、AI 推测和关键未知；推测不得静默升级；
- 达到可行动阈值、继续追问收益低、用户疲劳/要求直接做或当前决定低风险可撤销时停止提问。

已确认的对话与小说合同：

- 所有对话自动持久化，但不能每聊一句就创建空书；
- 用户明确继续、出现首个长期正式成果、需要故事记忆或开始正文时，由 Typed Tool 无表单建立小说并用大白话告知；
- 一本小说可关联多次对话，一次对话同一时刻只有一个主要小说上下文；
- 明显出现另一本书的念头时先建议单独保存，未经确认不得污染当前书；
- 普通用户不看到临时项目、对象、实体绑定等技术词。

已确认的“这次结果”合同：

- 不是聊天记录或技术日志，只收集当前对话产生的、可阅读、采用、修改、继续执行或长期保存的真实产物；
- 产物包括故事念头、候选方向、试写、人物成果、章节正文、修改影响范围预览与局部结果、研究结论、任务结果和重要分歧；普通追问闲聊不生成卡片；
- 前台状态限定为“供你看看、等你决定、已经放进小说、刚刚修改、正在进行、已经暂停、已被新版本替代”；
- 普通界面不暴露 Artifact、CanonFact、Revision Hash、Tool Receipt；
- 用户可直接在对话中命令采用、打开、移除或总结；采用后由 Typed Tool 写入章节、故事记忆、资料、AI 任务或创作记录，且本次结果继续保留来源和版本。

已确认的“我的小说”书架合同：

- 最左侧小说图标打开左侧书架；横屏只改变左侧区域，竖屏以覆盖层出现，不得替换或重建中央仓颉对话、清空草稿、中断流式或重置阅读位置；
- 书架条目只显示标题、当前大白话进度和最近时间；临时无名灵感可使用仓颉临时标题；
- 点击书籍只 push 到左侧独立详情页并可返回；详情提供继续创作、打开正文、当前做到哪、最近成果、相关对话，以及故事记忆、资料、AI 任务、导出与备份、本书设置入口，不显示项目技术字段；
- “聊一个新念头”只开启新对话，不弹创建表格；
- 浏览或阅读另一本书不得偷换当前创作上下文；只有点击继续创作、从该书正文问仓颉、继续该书历史对话或明确要求切换时才绑定，并由仓颉用大白话提示已切到哪本书。

已确认的“故事记忆”合同：

- 故事记忆不是用户填写的设定表，主要由仓颉从对话、已采用结果、已通过正文、用户改稿、研究资料和章节结算自动维护；
- 普通用户从左侧入口查看、纠正并用人话修改；前台固定分为“这本书现在讲什么、主要人物、世界规矩、现在写到哪里、后面不能忘的事、还没有决定”；
- 条目状态只显示“已经确定、暂时这样写、还没决定、已被新内容替代”；人物知识只显示“现在知道、还不知道、错误地以为”；
- “后面不能忘的事”覆盖线索、用户期待画面、人物承诺、读者承诺、当前卷目标和待回归人物；
- 每条重要记忆可查看大白话来源；AI 推测必须标明未确认，不能静默升级；
- 局部无冲突小改动可由 Typed Tool 直接执行并告知；与已通过正文或大量后续冲突时，先展示影响和受治理修改方案；
- 后台 Canon、TruthScope、CharacterKnowledge、PromiseLedger、版本和证据链完整保留，但默认不暴露。

已确认的“AI 任务”合同：

- 中央对话是主要控制面；AI 任务页只负责状态透明、安全兜底、恢复和诊断，不成为第二套手动调度工作台；
- 用户直接问仓颉“现在到哪了、花了多少、为什么停了、还能恢复吗”时，必须调用真实任务状态源和 Typed Tool，不能从聊天、旧缓存或模型文字猜测；
- 普通任务页只用“正在做 / 接下来 / 需要你”组织前台信息；关联书名、上次安全保存、有依据的费用估计、已用费用、暂停原因和可恢复动作可以继续显示；内部当前步骤与已完成步骤只能进入脱敏高级详情，不显示虚假百分比和思维链；
- 安全暂停必须先保存 checkpoint 且可恢复；结束并保留成果只停止后续步骤，不删除或批准未采用成果；放弃成果是单独谨慎操作，不得删除已采用、已通过或已冻结正文；
- 网络断开、App 挂起、模型繁忙、预算硬上限、重大故事分歧、等待用户、可恢复错误和未知结果对账均使用大白话显示原因、保存位置和下一步；
- 同一时间只运行一个主要创作任务，其他生成进入队列或在方向冲突时先询问；正文仍只有一个 Writer owner；
- 中央对话、右侧“这次结果”和左侧“AI 任务”页共享同一任务状态投影，完成、暂停、恢复、失败和采用后必须一致；
- 高级详情可折叠查看模型/Provider、实际用量、重试、checkpoint、来源、真实工具结果、错误码和脱敏诊断；不得显示完整提示词、API Key、Authorization、Cookie 或思维链。

已确认的“自动研究”合同：

- 研究默认由仓颉在立项、章节规划、正文生成前和审校阶段自动判断触发；用户主动说“查一下”只是额外入口；
- 固定知识顺序是“本书故事记忆→内置/本地题材知识包→有效缓存研究→必要时自动联网→来源质量与冲突检查→仍不能确认则诚实说明”；
- 不能只靠 LLM 自报置信度，必须独立检查内容类型、当前覆盖、写错影响、时效性、来源可靠度、冲突和题材污染风险；
- 题材包带来源、版本和更新时间，区分传统/公开事实、网文约定、不同流派、冲突说法和本书选定规则；题材包不是正典，不得复制其他小说完整版权正文；
- 用户只说“想写洪荒”时就自动建立或加载题材包，只把真正改变方向的少数冲突交给用户；
- 用户可关闭联网、限定只用本地资料和设置研究预算；关闭联网后不得偷偷联网；
- 外部网页、搜索结果、文档和题材包均为不可信参考，不能修改 Agent 权限、系统提示、工具策略或自动获得故事记忆确认写入权。

已确认的“仓颉叙事索引 / 小说版 CodeGraph”合同：

- 建立不可变原文层：导入资料、章节正文、人工改稿、研究资料和授权参考资料保留原始版本、来源、章节/场景/段落、时间和精确证据位置；摘要、向量、抽取、故事记忆和后续修改不得覆盖原文；
- 首版组合 SQLite FTS5 中文全文检索、轻量向量检索、章节顺序优先层级索引，以及事件、人物状态、人物认知、时间、关系、资源/能力、伏笔/读者承诺和场景/章节结构关系；不能只靠关键词或向量；
- 查询按任务自适应规划：先当前场景/章节，再相邻章节和当前卷，再相关人物/事件/认知/伏笔/状态，再全书和必要研究资料，并受 token、延迟、费用、风险与覆盖约束；不得固定单一路线或每次全书扫描；
- 证据不足时自动扩大范围并记录原因；扩大后仍不足就标记“暂时无法确认”，不得用摘要、相似文本或 AI 推测冒充事实；
- 人物认知、事件、时间因果、能力/物品/数量/资源、伏笔、已通过正文、人工改稿和研究支持等重要结论必须回到不可变原文闭环；LLM 只能提出候选；
- 索引渐进建立：先原文和基础 FTS5，再后台/按需增量建立章节、场景、人物、事件、认知、状态、伏笔、向量和关系；支持 checkpoint、幂等恢复、覆盖范围与新鲜度显示，不得伪装全书已理解；
- 上传参考小说只抽取带原文证据的结构、节奏、视角、叙事距离、人物塑造和信息顺序等抽象写法；上传/阅读不等于喜欢，用户确认后才进入本书或跨项目偏好；不得复刻具体表达、长段落、独特桥段、版权正文，不得直接进入故事记忆/正典或改变 Agent 权限；
- 首版不引入 Neo4j、Qdrant、完整 GraphRAG/LightRAG 服务、重型外部图数据库或云端知识图谱硬依赖。方向已经冻结，代码能力仍按 S3–S6 与 P0/P1 阶段实施，不能写成当前已经完成。

已确认的“上传材料本地优先与联网深度理解授权”合同：

- 上传后自动先做免费、本地、快速基础索引：安全清点、格式识别、不可变原文、基础文本、FTS5、章节/页码/段落定位、文件哈希、重复识别和可用性状态；这个阶段不调用付费模型、不外发材料，原文保存后即可阅读和搜索；
- 任何联网 LLM、Embedding、OCR、搜索或其他外部 Provider 深度理解，首次必须在执行前显示发送范围、明确不发送什么、Provider/模型、用途、预计费用/区间、预算上限、后续增量许可和外部数据披露，并获得明确授权；
- 授权只覆盖声明的资料、范围、用途、Provider/模型和预算；任一项实质变化都要重新说明和授权，用户可暂停、撤销或选择只用本地；
- 授权后按当前任务需要增量处理并保存 cursor、来源版本、发送范围、实际用量、费用和 checkpoint；新增或修改只重算受影响部分；
- 暂停、断网、App 挂起、未知结果和失败后先对账再幂等恢复，不重复发送、不重复分析整本书、不重复写入或扣费。

已确认的“统一 Evidence Index + 资料类型专用理解器”合同：

- 所有资料共享不可变原文、来源/版本、精确定位、哈希、FTS5/语义候选、增量更新、checkpoint、覆盖状态和证据回链；共享的是证据协议，不是单一理解器；
- 小说与章节正文进入 `NarrativeIndex`，处理章节顺序、场景、人物状态/认知、事件因果、关系、能力/资源和伏笔承诺；
- 历史、制度、神话、地理等事实参考进入 `ResearchIndex`，处理来源质量、时间、冲突说法、适用范围和事实证据；
- 用户自己的设定、笔记、世界观、人物表和项目附件进入 `ProjectMaterialIndex`，区分用户原话、候选设定、已确认约束和未决事项；
- 用户有权使用的正反样本、个人作品和偏好材料进入 `PreferenceIndex`，只抽取带证据的抽象偏好候选，不能复刻版权表达；
- 默认自动分类；无法可靠分类且错误会明显影响结果时才问用户。混合 ZIP 按文件分类，同一文件混合用途时按片段分类，同时保持共同原文与定位；同一授权参考小说可按明确用途建立互相隔离的 `NarrativeIndex` 结构分析视图与 `PreferenceIndex` 抽象偏好视图；
- 所有检索受项目、资料类型、用途、确认状态、工具权限和外发授权共同隔离；参考资料不能自动成为本书设定，参考小说不能进入 `ResearchIndex` 作为事实来源，也不能跨项目、跨用途或越权召回。

已确认的“第一章启动门槛”合同：

- 探索期可随时生成 100–300 字画面、微型试写、候选开场、能力代价和章节结尾，无需先完成完整策划；
- 完整第一章前只展示一张大白话“我准备这样写”，概括故事感觉、主角处境、本章事件、结尾所得、明确避免和尚未定死内容，不展示制作圣经、`CreativeContract` 或逐字段表单；
- 点击“就这样开始”，或说“开始写第一章”“你替我决定”“直接写”等语义明确指令都构成授权；未定内容保持可撤销临时假设；
- 后台总编剧仍形成生产级开篇基础、题材研究、前三章承诺、规则、偏好和未知，并运行计划→研究覆盖→写作→人物知识/连续性/题材纯度/AI 味检查→有限修正→checkpoint；
- 第一章生成后只标“供你看看”，不自动进入故事记忆“已经确定”；用户通过后才冻结正文并结算人物、世界、线索和下一章。

已确认的 Agent 主导校准与手动编辑合同：

- 普通用户和熟练作者默认都通过“选区/引用 + 大白话 + 仓颉追问或执行”完成校准，不把产品做成编辑器优先；
- 手动编辑只作为可发现但不打扰的高级/兜底能力，不手改也不能阻塞流程；
- 一次手动编辑会话自动保存新版本并保留旧 AI 稿，人工文字是当前最高优先级依据，但不自动等于章节通过；
- 编辑过程中不逐字弹窗；离开编辑、继续修改/生成、审批或启动后续任务前集中做影响分析；已通过正文仍走分支和用户裁决。

已确认的用户偏好代理 / 影子用户与非模型训练合同：

- 对外只称“用户偏好代理 / 影子用户”，内部可使用 `UserPreferenceProxy + BookReaderProxy`；不得承诺“完全像用户的数字分身”、人格复制或永远正确的替身；
- 首版采用非参数化、基于证据的偏好记忆、检索、候选比较、影子用户预审、真实反馈校准和主动弃权，不训练、微调或蒸馏用户专属模型权重，不做 LoRA；未来只有独立留出集与真实用户抽样证明有效后才评估轻量排序器/偏好模型；
- 偏好严格分为长期跨项目、本书、当前卷/章节临时意图三层；每条保存原始证据、来源、范围、支持/反证、置信度、版本、可撤销性和“AI 推测 / 用户确认”状态；
- 学习来源包括明确表达、选择、拒绝诊断、最终通过版本、用户授权参考资料的抽象特征和交互习惯；上传不等于喜欢，阅读不等于喜欢，AI 自己生成的判断或作品不能反向强化成用户金标准；
- 授权资料只抽取带来源、可解释、可确认/撤销的风格、结构、节奏、人物和叙事特征；禁止复刻具体表达、长段落、独特桥段或版权正文；
- 用户偏好代理只能预测、排序、预审、建议暂停和在证据不足时弃权，不能替用户正式通过章节、合并故事记忆/正典、覆盖人工文字或决定未授权重大剧情；
- 连续生成加入章节前计划门、章后独立硬规则/连续性审校、影子用户盲读预审和累计漂移检测；全局故事审校器与影子用户必须隔离；黄色信号缩小领先和生成窗口并提前要反馈，红色信号在安全 checkpoint 暂停；
- 该架构已经冻结但尚未实现。P0–P5 顺序为事件/证据数据基础→被动画像→影子预审→连续生成防偏→真实反馈校准→留出集有效后评估轻量模型；不得跳过 P0 直接做数字分身演示；
- 验收必须覆盖接受/拒绝预测、候选排序、校准、合理弃权、漂移漏报/误报、自动化覆盖和真实用户抽样；论文研究只作方法参考，其实验数字不得成为产品承诺。

已确认的模糊拒绝诊断合同：

```text
这章不对劲 / 我说不上来
→ 基于对话、已确认偏好、故事记忆和正文内部诊断
→ 给 2–3 个具体大白话候选原因或画面对比
→ 一次只问一个最有信息增益、最容易回答的问题
→ 必要时用 100–300 字可撤销小样验证
→ 达到可行动清晰度
→ 先反映理解并展示修改影响范围
→ 授权后执行完整修改
```

禁止不满意原因表格、专业分类和未诊断的盲目整章重抽。候选原因始终是可纠正的 AI 推测，只有用户确认后才可成为正式修改依据，不能静默进入确认偏好或故事记忆。

已确认的前三章批准与连续创作授权合同：

- 前三章逐章明确确认；章节结果页以正文阅读器和仓颉对话为主，只保留“就按这版继续 / 和仓颉聊聊”等轻量操作，不做复杂审批表；
- “可以 / 继续下一章 / 按这个感觉往下写”等明确自然语言与按钮等价；“还行 / 差不多”等含糊肯定不得冻结，只追问一次继续校准还是按此继续；
- 每章明确通过后按“冻结精确版本→结算故事记忆/人物知识/线索→checkpoint→下一章”执行，任一步没有真实回执都不能显示通过；
- 第三章通过只获得连续创作申请资格，不自动开始第四章；仓颉先用大白话解释自动推进、费用/预算和分级创作授权机制，只申请一次连续创作授权；
- 获得授权后默认连续准备 3 章，用户可用人话或设置调整为 1–5 章，首版最多保持 5 章尚未阅读的领先版本；普通章节不再机械逐章询问；
- 正文严格逐章且同一时间只有一个 Writer owner，每章完成审校、临时故事记忆结算和 checkpoint 后才开始下一章；研究/审校可并行但不能争夺正文写权限；
- 未读自动章节只标“仓颉准备的版本，等你看”，可作工作上下文但不等于用户确认；前章修改保留旧分支、做影响分析并只重生成受影响内容；
- “写完这一章暂停”在当前章安全收尾后停；“现在暂停”立即取消当前请求，残缺输出仅作临时内容；恢复必须幂等且不重复扣费；
- 普通可逆决定直接执行告知，重大变化按类别与范围检查授权，未覆盖时安全暂停，已覆盖时执行后醒目标记；费用、完整性、权限、安全和外部披露硬边界始终优先。

工作台、版本、已确定设定、人物知识、审批、Receipt、Hash、预算、checkpoint、分支和诊断能力继续完整存在，但默认下沉。普通用户只需要说人话、看正文和决定重大事项。

## Authority order

- 产品与架构规范权威：`IMPLEMENTATION_PLAN.md` -> `PRODUCT_EXPERIENCE_BLUEPRINT.md` -> `MILESTONE_VISUAL_ACCEPTANCE.md`；
- 当前执行状态权威：本文件 `PROJECT_CONTROL_CENTER.md`；
- 历史经验与防重复踩坑：`COMPOUNDING_AND_PITFALLS.md`；
- 补充决策与历史证据：ADRs -> `M0_VALIDATION.md`。

旧路线文档已退役；历史检查点中的旧阶段名称不能覆盖当前 S1–S6 规范。

## Current milestone

**S2 真正可操作软件的 Agent。** S1 Agent 驾驶舱定调与重构已由精确 Run-31 候选完成自动化和真机验收。当前按冻结路线接入真实 Provider、用户手选模型、中央 Agent Typed Tools / ToolReceipt，以及不生成正式正文的最小恢复闭环；不得把历史 Runtime 演示或模型文字当作 S2 通过证据。

S1 已验收基线：

- 首屏直接进入仓颉对话；
- 全中文、大白话，不要求用户理解写作或工程术语；
- 左侧独立页面和中心对话状态隔离；
- 横屏单一右侧区域用“仓颉 / 这次结果”标签切换，竖屏使用同名单焦点切换；
- 横屏 Activity Bar 只显示图标并支持长按说明；
- 小说图标打开左侧书架，书籍详情只在左侧 push；浏览不自动切换创作上下文；
- 正文出现后横屏保持约 2/3 阅读器 + 约 1/3 右侧，阅读器可最大化；
- 普通消息持久化但不制造空书；“这次结果”只呈现真实产物，不复制闲聊；
- 技术诊断从普通路径移到开发者/高级详情；
- 现有项目、对话、草稿、数据库、工具回执和恢复能力继续兼容；
- 横屏、竖屏、键盘、滚动和长内容显示符合 iPad 体验。

当前产品里程碑不是 Build 28。candidate-hardening 的历史 M1 与 Builds 26–28 只保留为工程原型和硬化证据；Build 28 未通过完整真机验收。其项目持久化、审批、第一章版本、恢复、安全和 CI 证据只作为后续重构的回归护栏，当前固定访谈、审批详情、段落锁定和 Keychain/Candidate Set 诊断页不作为视觉参考。

用户偏好代理路线当前状态：产品合同与 P0–P5 架构已经冻结，代码尚未进入 P0。近期只能先建设可追溯的事件/证据数据基础和范围治理；不得把未来轻量模型评估写成首版已实现能力，也不得用演示性“数字分身”绕开真实反馈和权限验证。

Run-31 证明 TrollStore **一次覆盖**后无需第二次覆盖即可激活新候选：首次打开出现红色 fail-closed 提示并要求结束后台后重开，用户按提示强退重开后身份、运行态、配对 Probe、Keychain 隔离和 S1 smoke 全部通过。用户未记录首次红色提示的精确文字，因此不能宣称已定位其底层原因；后续候选仍须保留运行身份验证，并在该提示复现时记录精确文案。第二次覆盖或卸载仍不得写成正常恢复步骤。

本轮新增权威设计文档：

- `docs/PRODUCT_EXPERIENCE_BLUEPRINT.md`：最终产品长什么样、关键页面、完整用户旅程和禁止设计；
- `docs/MILESTONE_VISUAL_ACCEPTANCE.md`：S0–S6 每阶段用户能看到什么、能做什么、暂时不能做什么和真机验收脚本。

## Validated baseline

Device-accepted S1 Agent-cockpit candidate:

```text
commit f93d43beb1459f4cf10ec3b7dcf3030d9b48e7fe
Core CI 29786055647: success
iPadOS CI 29786055674: success (197 App XCTest, 20 main App UI, 13 Probe unit, Probe UI)
Build TrollStore Candidate Set 29787116654 | run number 31
Candidate Set ID 46471b8cbd5cf8dec6ff6c3878ca77f9e37127462c13daea29c453869e221e70
Version 1.0 | build 31001
Main SHA-256 355c05669610cecfeaaf00c8ff4104575af69115da8ba9e191391f80c4507818
Probe SHA-256 3a6f67395fb68c96b129efdffaa4197d3ca4cf611e03ac9db88dab8463830e15
Local verified copy F:\project\CangJie\artifacts\CangJie-S1-advanced-diagnostics-run-29787116654-verified
```

The user completed one Main overwrite plus Probe installation on the target iPad. The first launch showed a red fail-closed relaunch instruction; one force-quit and relaunch, without a second overwrite or uninstall, activated the expected candidate. The user then confirmed all requested identity/runtime checks, Main canary creation, paired Probe isolation PASS conditions including `errSecMissingEntitlement`, unchanged Main digest, canary deletion to Absent, and the S1 navigation/draft/conversation smoke checks with no remaining issue. This exact candidate therefore passes the S1 physical-device gate. The unknown first-launch warning text remains an observation to capture if it recurs, not an unproven root-cause claim.

Device-accepted M0 baseline:

```text
commit 7b2658caf78fa21d4cbf28e0b8851eb3bcfec23b
Build IPA 29500269591 | iPadOS CI 29500271632 | Core CI 29500273381
IPA F:\project\CangJie\artifacts\CangJie-M0-run-20\CangJie-M0.ipa
SHA-256 2092cfb5fe94b463c453ca25e6107a12de1d77e8be8309c85ee027f8863d62ef
```

User confirmed TrollStore install, launch, immediate restart persistence, and no immediate crash for that M0 artifact.

Run-29 paired device candidate (physical-device validation executed; single-overwrite activation gate failed):

```text
commit b059a1e33a7a3d578cf15cd66ae11521400159bd
Core CI 29620872829: success
iPadOS CI 29620872813: success, including main App and Keychain Isolation Probe Simulator tests
Build TrollStore Candidate Set 29621391195: success | run number 29 | run attempt 1
Artifact CangJie-paired-device-validation-required-29-1-b059a1e33a7a3d578cf15cd66ae11521400159bd
Candidate Set ID b48f3c38c590034277d702970bced3086a826afc0cc74c3dcba2076b41e91d48
Version 1.0 | build 29001 | deployment target 16.6 | commit b059a1e33a7a
Main SHA-256 3b8bb83f068b821a6e1e0949ff6f4b3d09f7fad6f629e53a945b26cd0c98b91d
Probe SHA-256 c3443b242f28b0d913c98fda60eaf0972b782797425fa7f11cdc1aa6e6614435
Main Bundle ID and Keychain group com.juyang.CangJie
Probe Bundle ID and Keychain group com.juyang.CangJie.KeychainIsolationProbe
No embedded.mobileprovision | no unreviewed framework, dylib, plugin, Watch, or XPC payload
Signed executable hashes differ from unsigned executable hashes for both roles
Packaged pre-test manifest field: blocked-pending-trollstore-device-keychain-isolation-validation (historical fail-closed value, not current device status)
Local artifact directory F:\project\CangJieBuilds\run-29621391195
```

Physical-device validation was completed on the user's M1 iPad Pro running iPadOS 16.6.1. The first Main IPA overwrite did **not** activate the new executable; a second overwrite was required before the new page and identity appeared, so the single-overwrite activation requirement failed and this candidate is not fully accepted. After activation, running executable, installed bundle, Candidate Set, runtime/bundle match, Main Canary digest, paired Probe identity, own/default/explicit access-group isolation checks, unchanged Canary verification, deletion to Absent, state preservation, and no-crash/no-dead-control observations all passed. The activation risk is temporarily deferred, not closed; product work continues, but the next formal candidate must retest one-overwrite activation and retain fail-closed runtime identity diagnostics. A second overwrite must never be documented as the normal fix.

The preceding device-accepted recoverable-runtime candidate remains:

```text
commit a0fa83be8980825651a798d7de9a9c1b083ed55c
Core CI 29527519632: success
iPadOS CI 29527519653: success
Build TrollStore IPA 29528048015: success
SHA-256 6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78
```

The user confirmed on the target iPad that overwrite installation retained prior composer text; the app launched without a crash; a project did not appear before the actual `project.create` action; `Untitled Novel` appeared after that action; navigation and draft retention behaved correctly; all three visible interview exchanges survived force-quit; opening-plan generation and approval completed; `artifact.openingPlan.approve` appeared as the expected durable tool receipt; the approval result survived restart; and the post-approval planning guard behaved correctly. Automated database/runtime tests separately prove that all three structured interview answers, rather than only the last visible message, survive restore and are compiled into the plan.

The same device run confirmed the two presentation defects described above: Refresh appeared inert when the list was unchanged, and `Saved checkpoint #5 (sceneInactive)` could temporarily replace the business stage. These are fixed in the new candidate and require only differential retesting.

New exact-approval candidate artifact:

```text
GitHub artifact CangJie-M0-device-validation-required-22-874f73d1aa1336e6f7fbae9ed503d5096e1e2759
IPA CangJie-M0.ipa (legacy filename; identity is manifest + commit + run + hash)
Build run 29539149285 | run number 22
Commit 874f73d1aa1336e6f7fbae9ed503d5096e1e2759
SHA-256 fb8da1d86c0ebfb475161c38b7381083f49bc63c4a11588d229a270020e7f109
Bundle ID com.juyang.CangJie | arm64 | deployment target 16.6
Xcode 16.4 | iPhoneOS SDK 18.5 | GRDB 6.29.3
Local verified copy F:\project\CangJie\artifacts\CangJie-M1B-exact-approval-run-29539149285-verified\CangJie-M0-device-validation-required-22-874f73d1aa1336e6f7fbae9ed503d5096e1e2759\CangJie-M0.ipa
```

The downloaded checksum matches the manifest and local SHA-256; the archive contains `Payload/CangJie.app`; the repository verifier passed; the manifest is correctly fail-closed at `blocked-pending-trollstore-device-keychain-validation`. That acceptance status is expected and is not a build failure.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Device acceptance instruction contract

Every physical-device test request must be self-contained and state all of the following. Do not name an action without explaining how the user reaches the state in which that action exists.

```text
Entry path: exact navigation route from App launch
Control location: page region and nearby heading
Control type: text field, secure field, button, card, drawer, or status label
Action: exact tap/type/scroll sequence
Expected result location: where the result appears, not only what it says
Failure signal: visible text, missing state change, crash, or disabled control
Reset/recovery: how to return to the required starting state
```

## Immediate queue

1. 将本地完成的 Keychain/SQLite 命名连接设置编排提交到真实 App XCTest：只有 Keychain 精确回读和绑定复验成功后才能保存/激活 metadata；任何失败必须补偿或显式进入补偿失败，迟到重放不得改写较新 Key 或 current selection。
2. 在该编排远端通过后，完成显式命名连接的 Key/Endpoint 设置、真实连接测试、模型发现和用户手选模型；Key 只进入 Keychain，普通数据库、日志、回执和备份不得出现凭证。
3. 将通过 Keychain 绑定复验、连接测试和用户选模的真实模型接回原 Conversation 与原始 pending intent，支持流式输出、取消、用量记录、断网/未知结果对账和明确的人工恢复；不做自动 Provider 识别或隐藏路由。
4. 用中央对话中的结构化 Tool Call 证明至少 `project.create` 和 `project.status` 的真实执行、ToolReceipt、幂等与强退恢复；模型文字不能成为执行证据，S2 不生成正式正文。
5. 为一个真实受治理任务验证暂停、恢复、失败对账、队列和“正在做 / 接下来 / 需要你”三处同源投影，并按顺序通过适用 H0–H3。
6. 保持 Run-31 的 S1 导航、草稿、书架、普通术语、诊断高级入口和 Keychain 隔离回归；若覆盖安装首启红色提示复现，记录精确文案和身份状态，不进行第二次覆盖。
7. S2 自动化和精确候选证据齐备后，才构建下一份设备候选；S3 及正式正文、动态意图挖掘、资料深度理解和偏好代理不得提前混入该候选。

## Change log

### 2026-07-19 stage and acceptance map freeze

The user froze `CJ-PX-007`: S0–S6 are the user-visible product stages, H0–H5 are sequential Harness gates, and the real milestone remains **S1 Agent 驾驶舱定调与重构**. Historical candidate-hardening M1/Builds 26–28 remain engineering evidence only; Build 28 is not accepted. S2–S6 now have explicit capability and million-character boundaries, exact Harness mappings, and evidence-bound candidate acceptance. This documentation update does not implement a later stage, create an IPA, or change `ARCHITECTURE_SOURCE_REGISTER.md`.

### 2026-07-19 background/offline/recovery/notification decision freeze

The user froze `CJ-PX-006`: lifecycle barriers persist draft/task/request/stream/usage/checkpoint evidence; iPadOS 16.6.1 background limits are stated honestly; recovery distinguishes five outcomes and reconciles unknown requests without new creative cost; offline-local work remains available while new offline AI requests await user confirmation; partial streams stay outside formal story state; notifications are contextual and optional; task UI uses three plain-language labels; Writer, pause, and manual Provider recovery rules remain unchanged. This does not move the project beyond **S1 Agent 驾驶舱定调与重构** and does not claim S2/H4 implementation or device acceptance.

### 2026-07-19 no-key and file-lifecycle decision freeze

The user confirmed two product contracts. First, CangJie remains locally usable without an API key and asks for a concrete Provider only on the first AI-dependent request; the original intent is persisted and resumed after explicit model selection, with manual recovery only. Second, the UI separates `添加资料`, `导出小说`, and `备份项目` with distinct safety, content, credential-exclusion, restore, and device-loss semantics. Both are documentation-level frozen requirements, do not change the real S1 milestone, and do not claim S2/S3/S6 implementation completion.

### 2026-07-18 普通用户优先的产品重新定调

用户明确指出当前技术原型仍然假设使用者具备专业写作表达能力：固定访谈、必填拒绝原因、按段落锁定、审批工程字段和工作台式操作，把后台小说治理错误地暴露给了普通读者。新的权威定位是“给不会写小说的人使用的小说实现 Agent”：用户只提供念头、阅读反馈和重大决定，仓颉负责主动追问、建议、操作软件和调度生产级小说工程。

本次重写 `IMPLEMENTATION_PLAN.md`，新增 `PRODUCT_EXPERIENCE_BLUEPRINT.md` 和 `MILESTONE_VISUAL_ACCEPTANCE.md`。旧技术能力不删除，但重新分层：中心仓颉对话为唯一必经入口；左侧进入独立页面；右侧展示本次对话产物；专业术语和治理详情默认隐藏；正文改为连续阅读和任意选字反馈；选区、软反馈与明确硬锁定分离；无理由拒绝可以直接启动动态诊断。

当前里程碑改为 S1 Agent 驾驶舱定调与重构。Build 28 安装激活风险被记录为暂时搁置而非解决；后续候选仍需运行身份验证，但产品开发不再围绕诊断页面继续扩张。

独立终审进一步补齐了 S2 真实 Provider/Tool Call 边界、S3 基础资料与 S6 增强资料分层、意图证据与候选假设数据模型、左侧对话历史、全屏阅读层，以及 run-29 真机“隔离检查通过但单次覆盖激活失败”的真实状态。SwiftUI 改造必须等本轮产品定调确认后开始。
### 2026-07-17 Build-28 activation and Keychain-isolation worktree checkpoint

The Build 27 physical-device pass completed visible Keychain create/read/update/delete and overwrite-persistence checks, but repeated a previously suspected activation anomaly: after one TrollStore overwrite the App could retain an older UI shape, while a subsequent overwrite or full restart exposed the expected build. The working diagnosis is an old-process/new-disk-bundle identity split. Because an old executable can read the replacement bundle's `Info.plist`, build text sourced only from the bundle is not proof that the newly installed executable is running. Requiring a second overwrite would hide rather than solve the defect and is prohibited.

Build 28 introduces two independent identities: a compile-time executable stamp and an installed-bundle stamp loaded from disk. Version, build, commit, and fingerprint must match exactly. A mismatch or unavailable identity transitions activation to blocked, cancels or refuses Agent execution, and prevents approval, chapter, canon, and paid-generation operations. This checkpoint is implementation-only; authoritative Xcode compilation, CI, dual-IPA packaging, download audit, and real-device behavior have not yet passed.

The Keychain acceptance design now uses an independent companion application with Bundle ID and Keychain access group `com.juyang.CangJie.KeychainIsolationProbe`, separate from the main App's `com.juyang.CangJie` group. Its own-group create/read/delete is the positive control; default-group access to the main canary must return not-found, and an explicit request for the main group must return missing-entitlement. Success, item-not-found on the explicit check, or any ambiguous status fails closed as critical or inconclusive. The Probe never requests or displays the main canary bytes. Its result is meaningful only when the main App and Probe come from the same audited candidate set and their exact SHA-256 values and entitlements are verified. It does not remove the TrollStore platform trust boundary for arbitrary entitlements.

The first upgrade into this protection has a one-time limitation: Build 27 does not contain the new runtime identity guard and cannot retroactively stop its already-running process. Before overwriting Build 27 with the first audited Build 28 candidate, the user must fully remove the old App from the app switcher. From Build 28 onward, an active old process can detect that the installed bundle changed and block governed work instead of silently continuing.

### 2026-07-17 M1-C final device candidate

Commit `d27de88` added the previously missing user-operable `Device Diagnostics` secondary page, exact installed build identity, and a ThisDeviceOnly Keychain create/read/update/delete probe whose UI exposes only a 12-character SHA-256 digest. Its first iPadOS CI run `29559288088` failed only in the real UI Keychain test: the workflow had explicitly set `CODE_SIGNING_ALLOWED=NO`, so `SecItemCopyMatching` and `SecItemAdd` could not use the declared access group. Commit `9a8a9eb` retained the production entitlement contract and changed only the Simulator test invocation to ad-hoc signing with `CODE_SIGN_IDENTITY="-"`; Core CI `29560398690` and iPadOS CI `29560398699` then passed, including the real Simulator Keychain CRUD flow.

Build run `29560810381` produced run number `26` and artifact `CangJie-M0-device-validation-required-26-9a8a9eb45bfc41c5c32e1b78f9f9027d7f61ed92`. The downloaded IPA independently matched manifest and checksum SHA-256 `3aeb88fae96cd3a2ad8a6f74fc4ac629df54a027e9bd0a7fd0c6447511139d27`; final `Info.plist` contains bundle `com.juyang.CangJie`, deployment target `16.6`, build `26`, visible commit `9a8a9eb45bfc`, and iPad-only family `[2]`. Independent Mach-O inspection confirms arm64, an ad-hoc CodeDirectory, XML and DER entitlement slots, prefixless `application-identifier` and Keychain group `com.juyang.CangJie`, no CMS/Apple Developer signature slot, no `embedded.mobileprovision`, and executable hash equality with the manifest. The manifest remains deliberately fail-closed at `blocked-pending-trollstore-device-keychain-validation`. Run-25 is superseded and must not be used for M1-C acceptance because it has no user-operable Keychain diagnostic surface.

### 2026-07-17 M1-C governed Chapter 1 pre-CI checkpoint

Status: implementation prepared for authoritative CI. No Xcode CI result, candidate IPA, or physical-device acceptance exists for this checkpoint yet.

Implemented in the current worktree:

- Refresh acknowledgement now renders `Projects refreshed | <count> <noun> | <time>` and UI coverage asserts exactly two literal pipes, no question-mark substitution, and no change to the durable Agent business status.
- The opening-plan action card is state-projected only for `pending`. A compact `ViewThatFits` summary keeps review reachable in landscape; the exact request, revision, artifact hash, tool/version, targets, budget, expiration, expected diff, binding, status, and full plan live in a scrollable review. After exact success the central card disappears, while the right artifact drawer retains approved status, binding metadata, and the tool receipt.
- Approval review dismissal is fail-closed: `approveOpeningPlan` first verifies the displayed request/binding is still pending, executes the exact tool, reapplies the returned runtime snapshot, and returns success only when the projection contains the same request ID and binding hash with `approved` status. The detail sheet independently checks that projection before dismissing.
- Chapter generation reuses the canonical `requireExactApprovedOpeningPlan` validator, including latest artifact identity/content hash, current approval policy/binding, and completed approval-receipt identity; chapter generation cannot rely on status text or an orphaned `approved` row.
- Added the governed Chapter 1 state machine and UI: immutable V1 plus evidence review; paragraph lock/unlock; exact accept-and-freeze; rejection without reroll; the ordered `root-cause`, `must-preserve`, and `chapter-end` questions asked one at a time; exact rewrite-scope text/hash confirmation; immutable V2; byte-exact lock validation; diff/history review; and exact-version freeze with restart restoration.
- Chapter versions and receipts are scope-bound to conversation/project and exact version/hash inputs. V1 owns the logical ID; later revisions must be contiguous and parent the immediately preceding revision in the same conversation, project, and chapter. Calibration diagnosis and rejection entries must reference a version/hash in that validated lineage.
- Idempotent replay is receipt-bound to a `chapterToolResultSnapshot`. Replay validates receipt tool/version/input/scope/output plus the snapshot hash, then returns the historical version and calibration captured for that receipt rather than silently substituting today's active calibration.
- Chapter boundary inputs now have pre-write UTF-8 hard limits: title `<512` bytes, body `<1,048,576`, evidence `<131,072`, rejection `<32,768`, question `<16,384`, answer and rewrite scope `<65,536`, question ID/hash `<128`, idempotency key `<512`; at most 10,000 paragraphs, each `<262,144` bytes, and at most 2,000 locked indexes.
- Paragraph splitting and lock binding operate on raw UTF-8. A protected paragraph includes its adjacent blank-line separator bytes, and distinguishes LF, CRLF, and CR; trimming or newline normalization cannot make a changed lock pass.
- The final pre-CI review caught App-target-only type errors and mojibake in `ChapterAgentTemplates.swift` that Windows `swift test` could not compile. The template now uses `ChapterContentIntegrity.rewritingParagraphs` so every replacement is a `String`, original LF/CRLF/CR paragraph separators remain byte-exact, locked paragraphs are untouched, and all Chinese intent/template text is valid UTF-8.

Verification state: deterministic tests were added for canonical approval receipt identity, cross-scope rejection, UTF-8 caps, trailing-separator preservation, receipt-to-historical-snapshot replay, raw UTF-8 lock comparison, immutable V1/V2 lineage, exact acceptance, restart recovery, landscape scrolling, central-card removal, and retained right-side history. These tests and all iOS source still require the authoritative Xcode CI run before any IPA is eligible for device testing.

### 2026-07-16 M1-B exact-approval candidate and prior-device acceptance

Recorded the user's detailed acceptance of the `a0fa83b` recoverable-runtime candidate. Classified retained visible interview messages as device evidence for conversation persistence and retained structured answer arrays/plan compilation as automated-test evidence; neither is substituted for the other. Confirmed `artifact.openingPlan.approve` is the expected tool receipt. Recorded silent Refresh and checkpoint/status collision as real non-blocking presentation defects already corrected in `874f73d`. Core CI `29538641046`, iPadOS CI `29538641041`, and TrollStore build `29539149285` are green. Downloaded and verified the run-22 artifact with SHA-256 `fb8da1d86c0ebfb475161c38b7381083f49bc63c4a11588d229a270020e7f109`; the next stop is the focused physical-device differential gate.

### 2026-07-16 Agent-first reset

Retired old roadmap; corrected left navigation; established runtime/tool/canon/clean-room baseline. The first write was corrupted into question marks and repeated blocks, so the documents were rewritten in ASCII-dominant UTF-8 and an encoding gate was added. Documentation baseline commit: `bdf0056`. Post-push Actions are checked separately after this entry.

## 2026-07-16 M1-A implementation checkpoint

Implemented the first real vertical slice in `App/CangJieApp/ContentView.swift`, `AppViewModel.swift`, and `AppDatabase.swift`: persistent center conversation shell, independent left navigation to Novel Projects, collapsed artifact drawer, `novelProject` migration, and project create/list persistence. Added AppDatabase/AppViewModel tests. Windows `swift test` passed all 35 core tests. iOS App compilation and UI tests remain pending GitHub Actions.

## Continuous execution rule

Progress summaries are informational checkpoints, not pauses. After reporting completed work and the next action, continue automatically. Stop only when a major milestone has produced a candidate IPA requiring physical-device installation/acceptance, or when required user input is genuinely unavailable. At a device gate, provide artifact source, hash, install steps, test script, expected results, and rollback notes.


## 2026-07-16 M1-B runtime recovery worktree checkpoint

Version nature: committed as `648c8da`; partial M1-B implementation under CI correction, not a release, candidate IPA, or validated milestone.

Included:

- Added a recoverable `AgentRuntime` that restores a stable conversation snapshot containing messages, projects, session state, the scoped opening plan, the latest receipt, and the latest run.
- Added durable `agentConversation`, `agentMessage`, `agentSession`, and `agentRun` records. Session state carries focused project scope, interview step, current question, and interview answers.
- Scoped artifacts and receipts by conversation and project where available.
- Moved `project.create` and artifact writes behind typed database tool transactions. Each transaction writes the state change and receipt in one SQLite transaction, uses a unique idempotency key, and replays the referenced output and same receipt for an existing key.
- Added `artifact.openingPlan.save` and `artifact.openingPlan.approve` receipts with durable output references.
- Added view-model restart tests for conversation/interview restoration and opening-plan approval/receipt restoration.
- Added approval-run retry/reconciliation coverage so a repeated approval idempotency key updates the existing run instead of failing its unique constraint; an approved artifact can settle an interrupted approval run.
- Adopted legacy unscoped artifacts and receipts into the default conversation so the runtime upgrade does not hide existing opening-plan state.
- Kept an approved opening plan terminal for the interview slice: the next user message reports the next governed step instead of silently reopening approval.
- Replaced the stale last-message assertion and the M0 UI smoke identifiers in the current worktree.

Excluded or still incomplete:

- Exact approval binding to plan revision/hash, tool version, parameters, target versions, cost ceiling, expiration, and expected diff.
- Approval invalidation after a material plan, parameter, target, or budget change.
- General turn-level unknown-outcome reconciliation across message/session/artifact/run transactions, Provider execution, chapter generation, canon settlement, and M1 device acceptance.
- Capability-specific artifact APIs, private database authority, trusted-system message separation, and negation-safe project-creation confirmation remain required before model-driven tool dispatch.

Verification:

- Commit `648c8da`: Core CI `29526906495` succeeded; iPadOS CI `29526906476` found the test-fixture chronology error.
- Corrective commit `a0fa83b`: Core CI `29527519632` and iPadOS CI `29527519653` succeeded, including Agent-first UI smoke.
- TrollStore candidate workflow `29528048015` succeeded for exact commit `a0fa83be8980825651a798d7de9a9c1b083ed55c`; downloaded IPA hash matches the manifest and `.sha256` file.
- Physical-device acceptance passed for exact SHA-256 `6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78`: update install, project creation, navigation/draft retention, interview/plan approval, lifecycle return, force-quit recovery, and crash check behaved as expected. The checkpoint-status projection and silent Refresh observations are tracked as UX defects for the next slice.

## 2026-07-16 M1-B recoverable-runtime device acceptance

The user installed the exact `a0fa83b` candidate over the accepted M0 build. Existing composer text survived the update. No novel project existed before the first governed create action, which is expected because the prior build had no project record; after the natural-language request, `Untitled Novel` and its premise appeared in the dedicated Novel Projects page. Left navigation preserved the center conversation and unsent draft. The three-question interview, plan creation, `artifact.openingPlan.approve` receipt, approved-state guard, background return, force-quit restart, and no-crash checks passed.

Acceptance scope is the recoverable Agent runtime only. Device observations added two next-slice defects: unchanged project refresh has no visible acknowledgement, and `sceneInactive` checkpoint status overwrites the more important Agent workflow status. The three answer values are not separately exposed in the current UI, but device message recovery plus automated session/plan tests provide evidence that all three are durable rather than only the final answer.

## 2026-07-16 M1-B exact-approval governance worktree checkpoint

Status: uncommitted implementation under final review; not yet a candidate IPA.

Implemented:

- Added `CangJieCore.ApprovalBinding` with canonical versioned SHA-256 binding, epoch-millisecond expiration, strict structural validation, Codable tamper rejection, and deterministic test vectors.
- Added immutable Artifact logical identity/revision/content hash/parent adoption, exact `ApprovalRequest` persistence, target-version hashes, expected-diff hashes, current-policy candidate reconstruction, and fail-closed invalidation.
- Bound approval receipts to request, binding, tool/version, scopes, output artifact, and idempotency key; hardened generic Artifact tool replay against changed inputs or scope.
- Restored Artifact and Approval as one focused-project pair; reconciled approved transactions to one idempotent success message and only eligible nonterminal runs.
- Separated `businessStatus`, transient notices, and errors. Added visible Novel Projects Refresh acknowledgement without replacing workflow status.
- Added App database/runtime/UI tests for replay, tampering, stale versions, duplicate targets, legacy schema upgrade, cross-project restore, missing-message reconciliation, terminal-run preservation, and exact metadata presentation.
- Recorded the governing decision in `docs/adr/0003-exact-approval-binding.md` and pitfalls P-031 through P-040.

Local deterministic evidence before remote Xcode validation: `swift test` passed 47 Core tests; App, AppTests, and UITests Swift parse checks passed; `git diff --check` passed apart from a non-blocking CRLF normalization warning in one test working copy. Windows cannot typecheck SwiftUI/GRDB iOS targets, so GitHub Actions remains the build authority.


## 2026-07-16 Exact-approval CI compile correction

GitHub iPadOS CI run `29536878074` reached the Xcode 16.4 simulator compile step and exposed two concrete Swift errors in `AppDatabase+Approval.swift`: a throwing call embedded on the right side of `||` without marking the operator expression as throwing, and a parameter named `approval` shadowing the static relationship predicate. The repair evaluates the receipt lookup in an explicit branch and qualifies the predicate as `Self.approval(...)`; no approval, receipt, budget, or fail-closed behavior was removed.

Local evidence after the repair: all 47 `CangJieCore` tests pass, every App/AppTests/UI test Swift file parses, `git diff --check` passes, and the temporary downloaded Actions log was deleted. The next gate is a direct `main` push followed by inspection of the new Core and iPadOS runs; only a fully green commit may produce the next TrollStore candidate.


## 2026-07-16 Exact-approval CI second compile correction

The first repair commit `73b9d49` made Core CI run `29537449945` pass. iPadOS CI run `29537449881` then progressed to the next first real compiler error: `executeArtifactTool` declared `ArtifactToolResult` but did not return the `queue.write` result. The method now uses `return try queue.write`; no runtime behavior or authorization rule changed.


## 2026-07-16 Exact-approval CI test correction

iPadOS CI run `29537777876` compiled the App and exposed three test-contract issues. The exact replay fixture created a 500-unit approval but executed under the zero-unit default policy; it now supplies the exact matching current policy for both execution and replay. The focused-project fixture used an approval expiration in 1970 while restore correctly evaluates the current wall clock; it now isolates project pairing with a future expiration. The approval-card identifier was attached to the container and masked descendant identifiers in the SwiftUI accessibility hierarchy; it now identifies the visible card title so request, revision, hash, policy, status, and action remain individually inspectable.

## 2026-07-17 M1-B device-feedback repair plus M1-C pre-CI checkpoint

Status: implementation and deterministic Windows gates complete; authoritative Xcode/iPadOS CI and a new identity-verified IPA are still pending.

Included in the current worktree:

- User-reported Refresh feedback renders literal ASCII `|` separators. The same visible separator audit also corrected the draft-save acknowledgement.
- Exact opening-plan approval closes the central pending card only after the durable projection confirms the same request ID and binding hash as `approved`; approved metadata and `artifact.openingPlan.approve` remain visible in the right artifact history.
- Landscape no longer relies on a truncated authorization card: a compact summary opens a scrollable exact review containing the full plan, hook, protagonist, approval binding, budget, expiry, targets, expected diff, and action.
- Chapter 1 calibration is implemented end to end: immutable V1, evidence review, byte-exact paragraph locks, exact accept or diagnostic rejection, three ordered questions, explicit rewrite-scope confirmation, immutable V2 with parent lineage and diff, and exact acceptance/freeze. V2 cannot be rejected into an unbounded V3 loop.
- Chapter receipts now optionally bind `originRunID`. Restore reconciles committed Agent chapter tools to the exact interrupted run, appends a missing result message once, and does not let direct paragraph-lock receipts complete an Agent run.
- Final pre-push review found that `originRunID` was not yet part of replay identity and was stored without durable run-scope proof. Migration `m1c-origin-run-binding-v3` now gives each Agent run an immutable project scope, rejects missing or cross-conversation/project origin runs at the database boundary, fails migration on legacy mismatches, and treats a different run ID under the same chapter idempotency key as a conflict.
- `approvedFrozen` is protected both in Swift and SQLite. Direct frozen inserts are rejected; the transition requires canonical nonblank accept evidence and a matching immutable result snapshot; any final-transition failure rolls receipt and snapshot writes back atomically.
- Agent input is capped at 32,768 UTF-8 bytes before run creation. Chapter tool boundaries enforce field, body, paragraph, lock-index, hash, and idempotency limits before writes.
- Build candidates embed and display marketing version, numeric Actions build number, and the exact short Git commit; CI and packaging verify this identity before upload.

Local evidence on 2026-07-17:

```text
swiftc -parse App/CangJieApp/*.swift: pass
swiftc -parse App/CangJieAppTests/*.swift: pass
swiftc -parse App/CangJieUITests/*.swift: pass
swift test: 60 tests, 0 failures
App database regressions added for origin-run replay identity and missing/cross-project run rejection; authoritative execution remains Xcode CI
python scripts/tests/test-build-identity-contract.py: pass
git diff --check: pass (line-ending warnings only)
secret/private-binary scan: no tracked IPA, ZIP, SQLite, database, key, profile, or private source package
```

This checkpoint is not a device candidate. Next: complete focused review, commit and push `main`, inspect the first causal error of each GitHub run if any, make Core and iPadOS CI green, then build and verify a new TrollStore IPA before requesting physical-device acceptance.

## 2026-07-17 M1-C diagnosis replay repair and green CI checkpoint

Status: Core and iPadOS CI are green for implementation commit `2a5d8de`; the final TrollStore IPA build and real-device acceptance remain pending.

The final three failing Chapter 1 tests had one shared failure boundary. The third diagnosis answer committed its calibration and rewrite scope, then normal execution appended the completion message with curly quotation marks. Immediate restore reconciled the same receipt and attempted to append a textually different completion message with straight quotation marks under the same idempotency key. The message store correctly raised `idempotencyConflict`, so the ViewModel retained the prior two-answer projection even though the third answer was durable. Both execution and recovery now call one canonical `appendDiagnosisCompleteMessage` function, making payload identity and idempotency identity inseparable.

The preceding receipt-validation repair remains intentionally narrow. SQLite Double storage and JSON `Date` coding can recover the same audit timestamp one adjacent floating-point representation apart. `ChapterCalibration.isAuditEquivalent` therefore permits only identical or one-ULP-adjacent `updatedAt` values while every business field, stage, hash, version, diagnosis entry, lock, scope, acceptance binding, and receipt remains strict. A two-ULP timestamp difference and any business-state difference still fail closed.

Durable recovery boundaries now verified by CI include: Agent runs are written before high-risk session decoding; committed chapter tools reconcile only to their exact `originRunID`; receipt replay returns its historical snapshot rather than the live aggregate; direct lock receipts cannot settle Agent runs; normal execution and reconciliation share canonical assistant payloads; and failed/cancelled terminal runs are not overwritten by restore.

Authoritative evidence:

```text
Core CI 29555500013: success
iPadOS CI 29555500055: success
App test suite: 87 tests, 0 failures
UI smoke: Agent-first launch and scrollable opening-plan approval review passed
```

Historical checkpoint: the documentation commit, final-HEAD CI, TrollStore build, identity, entitlement, SHA-256, manifest, and independent audit steps described here were completed by Build 27. The authoritative pending device work is listed in the current Immediate queue.

## 2026-07-17 M1-C final-HEAD CI assertion repair

Final documentation commit `641e30a` preserved the implementation but exposed one nondeterministic audit assertion in iPadOS CI run `29555834009`. Core CI `29555834104` passed. The first real iPadOS error was `testChapterApprovedFrozenRejectsForgedApprovalAndFurtherMutation`: the database correctly rejected the forged mutation, and every visible business field remained identical, but the test compared a SQLite-restored `ChapterCalibration` to the receipt-restored calibration with synthesized `Equatable` instead of the established one-ULP-only audit equivalence.

The test now asserts `isAuditEquivalent(to:)`. This does not change product behavior or weaken the frozen-chapter trigger, exact version/hash binding, receipt validation, lock integrity, diagnosis state, rewrite scope, or canon gates. It applies the same narrowly tested timestamp representation rule already used by production receipt reconciliation. The final candidate must be built only after Core and iPadOS CI are green for the new documentation-inclusive HEAD.

## 2026-07-17 M1-C IPA build-identity packaging repair

TrollStore build run `29556797484` compiled the Release app successfully but failed before signing because the processed app `Info.plist` omitted `CangJieGitCommit` even though Xcode received the custom build setting. The packaging script now stamps the exact 12-character HEAD identity and Actions build number into the built plist atomically after compilation and before any signing. It permits only the declared project baseline build, unresolved placeholders, or already-correct values; rejects malformed identities, unexpected pre-existing values, symlinks, and invalid plists; then reopens and verifies both stamped fields. The existing package verifier still independently checks bundle ID, minimum OS, device family, executable name, build number, and commit.

The same failure also exposed a Bash error-propagation bug: `readonly EXECUTABLE_NAME="$(...)"` can return the status of `readonly` instead of the failed command substitution. The script now captures the verification command in an explicit `if ! ...; then fail` block and marks the variable read-only only after success, so the first causal identity error stops packaging immediately. Contract tests cover successful stamping, refusal to overwrite an unexpected identity, refusal of a mismatched build number, and the absence of the masked-failure pattern.

## 2026-07-17 M1-C identity-verified IPA candidate

Status: Core CI `29557784425`, iPadOS CI `29557784433`, and TrollStore build `29558102714` are green for commit `bb9cc55fa060b8e7098acb51e23f7eec89eda0b1`. The exact candidate is ready for target-iPad acceptance; no physical-device result is claimed yet.

The second packaging failure (`29557446291`) proved that Xcode also left the declared baseline `CFBundleVersion` in the processed plist rather than the Actions run number. The repaired pre-signing stamper now accepts only the exact expected run number, the declared baseline `1`, or the unresolved build placeholder; it atomically writes both commit and build number and refuses any unfamiliar pre-existing value. Commit `bb9cc55` then passed both CI workflows.

Independent post-download audit of the run-25 artifact verified:

```text
Artifact CangJie-M0-device-validation-required-25-bb9cc55fa060b8e7098acb51e23f7eec89eda0b1
IPA SHA-256 ba75a069c3b727b64c179ebf3bbd9e4e7e8cf6442b1934f12664ff9ee52ec641
Bundle ID com.juyang.CangJie
MinimumOSVersion 16.6 | UIDeviceFamily [2] | architecture arm64
CFBundleVersion 25 | CangJieGitCommit bb9cc55fa060
No embedded.mobileprovision | no CMS certificate slot
ldid CodeDirectory and XML/DER entitlement slots present
application-identifier com.juyang.CangJie
keychain-access-groups [com.juyang.CangJie]
Manifest commit, run number, signed executable hash, IPA hash, and acceptance gate all match
Acceptance blocked-pending-trollstore-device-keychain-validation (expected fail-closed state)
```

Historical run-25 next-gate note: superseded by the authoritative Build-27 queue and acceptance instructions above. Opening-plan and Chapter 1 do not need repetition for the diagnostics-only change; the exact Build-27 Keychain contract remains fail-closed until its own required evidence is complete.

## 2026-07-17 Build-26 physical-device feedback and diagnostic UX correction

The target-iPad report confirmed that overwrite installation preserves the database and approved opening-plan state. A pending approval card must not reappear merely because the same App is overwritten; after deleting the App, reinstalling, and rerunning the workflow, the card correctly appears and its full review content scrolls. This is accepted persistence behavior, not a failed presentation fix.

The Keychain screen exposed one secure field followed by a dynamic action button. After a successful write the field was cleared and the button changed from `Create and verify` to `Update and verify`, becoming disabled until a new value was entered. Because neither the page nor the prior test instructions explicitly identified the control types and state transition, the user reasonably interpreted `Update and verify` as a second input that could not be edited. Read, force-quit persistence, overwrite-install persistence, delete, and post-delete absence were observed; create-versus-update was not validly distinguished. The replacement candidate must make that distinction self-evident and must not ask the user to retest the ambiguous build.

## 2026-07-17 Clarified diagnostic first CI correction

Commit `2125fd6` passed Core CI run `29589924030`. iPadOS CI run `29589924300` compiled and ran all App/unit coverage, but its first and only failing test was `CangJieSmokeUITests.testDeviceDiagnosticsVerifiesKeychainCreateReadUpdateAndDelete` at line 67: the custom helper asserted that the Save button must become `isHittable` after six whole-App upward swipes. The following native `save.tap()` immediately succeeded because XCTest itself scrolled the identified button into view and computed a valid hit point. The failure therefore came from the new test helper, not the Keychain implementation, SwiftUI layout, or security contract.

The correction removes the contradictory pre-tap `isHittable` gate and relies on XCTest's native identifier-bound tap auto-scrolling while retaining exact state, visible-label, digest-change, disappearance, and plaintext-leak assertions. No production Keychain or governed novel workflow code is weakened.


## 2026-07-17 Build-27 clarified Keychain diagnostic candidate

Commit `2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca` passed Core CI `29592373178` and iPadOS CI `29592385850`. The latter retains real Simulator Keychain CRUD, state transition, digest-change, plaintext-redaction, and discoverability assertions. TrollStore workflow `29593245829` produced run number `27` and artifact `CangJie-M0-device-validation-required-27-2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca`.

The downloaded IPA was independently parsed rather than accepted from workflow status alone. Audit result:

```text
IPA SHA-256 260478b5cf0b8ab06ea75ce6b231041c9dedf82a6c10d05ba06afb8114e1b8ec
Info.plist build 27 | commit 2c61bc2d1c38 | Bundle ID com.juyang.CangJie
MinimumOSVersion 16.6 | UIDeviceFamily [2] | thin arm64 device Mach-O
No embedded.mobileprovision | no CMS slot or BlobWrapper
Ad-hoc CodeDirectory slots 0 and 4096, both flags 0x00000002
XML entitlement application-identifier com.juyang.CangJie
XML keychain-access-groups [com.juyang.CangJie] | DER entitlement slot present
Signed executable SHA-256 352354110f047ab3c1564c7ec66e288f51a37eb08cb500fca10e4fdc594ffd70
Fail-closed acceptance blocked-pending-trollstore-device-keychain-validation
Audit F:\project\CangJie\artifacts\CangJie-M1C-clarified-run-29593245829-verified\independent-audit.json
```

This candidate does not ask the user to repeat untouched opening-plan or Chapter 1 checks. The first physical-device pass verifies visible build identity, the single input, create/read/update/delete behavior, a 12-character digest that changes after update, and plaintext absence. Passing that focused pass validates the repaired diagnostic UX but does not by itself clear the fail-closed artifact contract; exact Build-27 reinstall persistence and a user-operable isolation check remain required.

## 2026-07-17 Build 28 pre-CI implementation checkpoint

The overwrite-activation repair is implemented locally and remains unaccepted until GitHub Actions, paired-IPA audit, and real-device checks pass. The main App now compares an immutable compiled identity with a fresh disk `Info.plist` identity at launch, lifecycle transitions, and every governed mutation boundary. Missing or mismatched identity prevents database/runtime initialization where possible, revokes the shared runtime authorizer, cancels streaming, and blocks Agent turns, runtime reconciliation, opening-plan approval, paragraph locks, chapter rejection/diagnosis/rewrite/acceptance, canon-adjacent settlement, and paid generation paths.

The same candidate-set pipeline now builds the main App and a separate Keychain Isolation Probe. Both artifacts share commit, run, build, and candidate-set identity but have distinct executable fingerprints, Bundle IDs, Keychain groups, entitlements, IPA hashes, and executable hashes. The Probe performs its own-group CRUD positive control, a default-group canary-status query, and an explicit main-group query without requesting result data. Only exact expected statuses pass; all ambiguous results fail closed.

Pre-push evidence:

```text
Swift parse: 33 files passed
Python build/manifest/verifier contract suites: 4 files, all passed
Property-list parsing: main Info.plist, Probe Info.plist, and both entitlement files passed
git diff --check: passed (line-ending warnings only)
tracked secret-pattern scan: no findings
project.yml accidental BOM removed
Probe user-facing mojibake removed
Probe identity tests moved into the XCTestCase and lifecycle mismatch coverage added
iPadOS CI now generates both identities, runs both schemes, and uploads two xcresult bundles
```

Authoritative Xcode compilation and simulator execution are still pending on `macos-15` with Xcode 16.4. No device acceptance may be requested until Core CI and iPadOS CI are green and the exact paired IPA artifact has been independently audited.

## 2026-07-17 Build 28 candidate-set and runtime authorization hardening

Status: implementation and local static/script validation complete; Core CI, iPadOS CI, paired IPA construction, offline artifact audit, and physical-device acceptance are still pending. No Build 28 real-device success is claimed yet.

Purpose: eliminate the recurring ambiguous state where one TrollStore overwrite can leave old UI/code visible while files on disk report the new build. Build 28 does not normalize a second overwrite. It embeds identity into each final Mach-O, compares the running executable identity with the installed bundle identity, and fails closed when they cannot be proven identical.

Implemented candidate and artifact controls:

- The main App and Keychain Isolation Probe are built as one Candidate Set with fixed roles and Bundle IDs.
- Candidate Set derivation now binds commit, marketing version, run ID, run attempt, run number, derived build number, and both Bundle IDs.
- The manifest stores one top-level `version`; both compiled identities and both packaged plists must match it.
- Build retries derive collision-free build numbers from `runNumber * 1000 + runAttempt`.
- Executable identity is emitted to Swift and C, embedded in each Mach-O, extracted from each IPA, and compared against manifest and plist identity.
- Artifact verification recomputes Candidate Set ID instead of trusting the manifest value.
- Manifest and artifact JSON reject duplicate keys.
- IPA inspection rejects case-folded and NFC/NFD-equivalent path collisions, symlinks, special files, unsafe roots, archive bombs, and unreviewed nested code.
- The artifact directory itself must be a real directory rather than a symlink.

Implemented runtime controls:

- `BuildActivationAgentAuthorizer.performAuthorized` holds an authorization boundary over the current synchronous governed side effect and prevents revocation from interleaving with an admitted mutation.
- Runtime initialization, reconciliation, Agent turns, and opening-plan approval are governed; existing finer-grained durable and chapter mutation checks remain nested.
- Dynamic identity mismatch cancels governed work and clears cached Keychain/canary evidence without repository access.
- A rejected Agent turn preserves the unsent draft and does not append fictitious conversation messages.
- Device Diagnostics exposes running executable, installed bundle, Candidate Set, and an explicit active/mismatch diagnostic.

Local validation completed on 2026-07-17:

```text
Python unittest scripts: 47 passed, 1 platform-dependent symlink test skipped on Windows
Contract scripts: build identity and candidate-set contracts passed
Python py_compile: passed
Swift frontend parse for all modified Swift and XCTest files: passed
Git Bash syntax check for build-candidate-set.sh: passed
git diff --check: passed
```

Historical gate at this checkpoint — superseded:

1. Review the complete diff and remove temporary logs/caches.
2. Commit and push the exact Build 28 HEAD.
3. Require Core CI and iPadOS CI to pass for that HEAD; Xcode type-check and XCTest discovery remain authoritative.
4. Trigger `build-ipa.yml` only after both CI workflows pass.
5. Download the main and Probe IPA from the same artifact directory and run the strict offline verifier.
6. Ask for one-overwrite real-device acceptance only after the paired Candidate Set audit passes.
7. If the first overwrite does not activate the new executable, terminate/relaunch or respring and collect diagnostics; never instruct a second overwrite as the fix.

## 2026-07-17 Build 28 CI repair log

- Commit `02d9e4e` passed Core CI run `29614001984`. iPadOS CI run `29614001983` reached Xcode tests and exposed the first real compiler error: a throwing authorization call was placed directly inside a non-throwing `DispatchQueue.async` closure.
- Commit `4bf6dd1` moved error capture inside the async closure and passed Core CI run `29614715038`. iPadOS CI run `29614715082` then advanced to the next real compiler error: an AppViewModel test referenced `PersistedCheckpoint.reason`, while the persisted model intentionally names the field `stage`.
- The next repair changes only that test access from `.reason` to `.stage`. A failed local PowerShell edit briefly corrupted Chinese test literals because of implicit encoding; Swift parse caught it before staging. The file was restored from HEAD and patched with explicit UTF-8 handling.
- Companion Probe UI assertions also appear later in the failed logs, but they are not being guessed at in parallel. The strict sequence remains: fix the earliest causal compiler/test error, push, and rerun until the App test step reaches a trustworthy result; then diagnose the first remaining Probe failure from its own screenshots and logs.

## 2026-07-17 Build 28 audited paired candidate and device gate

Commit `b059a1e33a7a3d578cf15cd66ae11521400159bd` fixes the final paired-build blocker: `CangJieIsolationProbe.entitlements` contained a UTF-8 BOM that Apple `plutil` and Python `plistlib` accepted but pinned Procursus `ldid` rejected. The build contract now rejects a BOM before signing with the exact error `Entitlements file must be UTF-8 without BOM for ldid compatibility`; the checked-in Probe entitlement is BOM-free, and both entitlement files are contract-tested for exact self-only Keychain groups.

Authoritative automation evidence:

```text
Core CI 29620872829: success
iPadOS CI 29620872813: success
Build TrollStore Candidate Set 29621391195: success
Hermetic build-contract tests: success
Real codesign and ldid entitlement contracts: success
Paired build, independent signing, complete candidate-set re-verification, and artifact upload: success
```

Independent Windows-side audit of the downloaded artifact directory also passed `scripts/verify-build-artifacts.py --metadata-only` and a separate archive/manifest verifier. It confirmed one Candidate Set ID, one version/build/commit, exact manifest SHA-256 values, exact Bundle IDs and self-only Keychain groups, matching packaged `Info.plist` identities, changed signed executable hashes, no provisioning profile, and no unreviewed nested code.

Historical device gate — executed on 2026-07-18 and superseded by the observed result:

1. The intended gate required one Main IPA overwrite, runtime/installed identity equality, active authorization, and the paired Probe isolation checks.
2. The first overwrite did not activate the new executable, so the single-overwrite activation requirement failed.
3. After a second overwrite activated the candidate, runtime/installed identity, Candidate Set, Main Canary, Probe identity, own/default/explicit group isolation, unchanged Canary, deletion, persistence, and stability checks passed.
4. The packaged manifest's `blocked-pending-trollstore-device-keychain-isolation-validation` value is the pre-test fail-closed field embedded in the artifact; it is historical evidence, not the current operational status.
5. Current status: activation defect temporarily deferred but not closed; the candidate is not fully accepted, product work may continue, and the next formal candidate must retest one-overwrite activation without normalizing a second overwrite.

## 2026-07-18 product-experience rebaseline independent-review closure

The ordinary-reader Agent-first rebaseline is now documented in `IMPLEMENTATION_PLAN.md`, `PRODUCT_EXPERIENCE_BLUEPRINT.md`, and `MILESTONE_VISUAL_ACCEPTANCE.md`. An independent read-only review found and this slice closed four contract defects before S1 implementation: a first-install `Continue last time` dead shortcut, inconsistent S3 exit criteria, intermediate-stage navigation entries without capability gates, and a right-drawer state-name mismatch. The S5 visible task example now explains character-information and timeline checks in ordinary language instead of exposing `CharacterKnowledge` terminology. A second ordinary-user review also closed two remaining ambiguities: S1 now persists messages with an explicit interface-preview receipt instead of pretending a real Agent exists, and S6 now carries the first-release non-goal list beside its acceptance contract.

## 2026-07-18 responsive workspace and feedback decision freeze

The user confirmed the product tone and the responsive workspace contract for the next implementation baseline:

1. Landscape uses one right-hand region with “仓颉 / 这次结果” tabs; there is no fourth column.
2. The left Activity Bar is icon-only, and long press explains each icon's name and purpose.
3. Landscape reading uses about two-thirds of the width and the right region about one-third; panels can close and reopen, and the reader can maximize.
4. Portrait uses single-focus “阅读 / 仓颉 / 这次结果” switching.
5. The primary text-feedback path is selection → ask CangJie → automatically bound quote context → local preview when understood → dynamic questioning only when needed.
6. Superseded on 2026-07-18. The current authority is `复制 | 问仓颉 | 更多`; selection is only a discussion focus/edit-analysis start, soft feedback stays under More, and only an explicit command creates a hard text lock.
7. The visual direction is CangJie's own restrained, quiet, modern warm-neutral system with warm-orange accents; the previous paper-ink/vermilion direction is retired.

These decisions are now authoritative for S1/S4 documentation. They simplify the surface only; typed tools, exact version binding, approvals, canon, character knowledge, branches, checkpoints, budgets, idempotency, recovery and security remain mandatory.

## 2026-07-18 Agent autonomy and approval decision freeze

The user approved “关键事情问我” as the default autonomy mode. Safe and reversible daily actions execute without confirmation spam and report afterward; chapter text and important creative direction are shown as reviewable results before commitment; major irreversible changes, destructive deletion, new external data disclosure, and budget overruns pause for a plain-language decision. The first three chapters retain chapter-by-chapter calibration before higher automation is unlocked. Alternative user preferences may change interruption frequency but never bypass security, budget, permission, exact-version, or external-service gates.

This decision is authoritative for later Agent tooling, approval UX, S2, S4 and S5 acceptance, but it does not mean every remaining product question is closed. SwiftUI implementation remains outside this documentation-only slice. Run-29 remains a partially accepted technical candidate with the single-overwrite activation defect deferred but not closed.

## 2026-07-18 dynamic-intent-loop decision freeze

The user confirmed a dynamic visible loop rather than a fixed interview: understand a little, do a little, let the user see something, then update understanding. Ask one easy, decision-changing question at a time; normally show a concrete image, sample or candidate after roughly 2–4 high-value questions without hard-coding the count. Use scenes, contrasts, reading experience, reverse exclusion or a reversible temporary choice when the user does not know. Persist user words, confirmed decisions, AI hypotheses and critical unknowns separately, and stop questioning when action is possible or further questions have low value.

## 2026-07-18 conversation-to-novel decision freeze

All conversations persist from the first message, but ordinary conversation does not create empty novels. CangJie creates and links a novel without a form only when the user clearly continues, a first durable result exists, story memory is needed, or prose generation begins. One novel may link many conversations; one conversation has one primary novel context at a time. A distinct new-book idea must be isolated before it can affect the current novel.

## 2026-07-18 current-results artifact-contract decision freeze

“This time's results” is a projection of useful conversational products, not chat duplication or a technical log. Only readable, adoptable, editable, executable or durable products appear. Ordinary questions do not create cards. A finite plain-language status vocabulary is mandatory, conversation commands can adopt/open/remove/summarize results, and Typed Tools file adopted content into the correct domain location while preserving traceability.

## 2026-07-18 novel-shelf interaction decision freeze

The novel icon opens a left-side shelf: landscape changes only the left region and portrait uses an overlay. Shelf rows contain only title, plain-language progress and recent time; unnamed ideas may receive a temporary CangJie title. Selecting a book pushes a returnable left-side detail page with Continue Creating, Open Prose, progress, recent results, related conversations and book-capability entries, without technical project fields. Browsing or reading another book never silently changes the active creation context; binding occurs only through Continue Creating, asking CangJie from that book's prose, continuing a related conversation, or an explicit switch, followed by a plain-language notice.

## 2026-07-18 story-memory product-contract decision freeze

The user confirmed that Story Memory is an Agent-maintained, plain-language projection rather than a settings form. CangJie derives it from conversations, adopted results, approved prose, user edits, adopted research and chapter settlement. The ordinary surface uses six fixed groups, four plain-language statuses, and “现在知道 / 还不知道 / 错误地以为” for character knowledge; important entries expose a plain-language source and AI hypotheses remain visibly unconfirmed. “后面不能忘的事” covers clues, desired future scenes, character and reader promises, current-volume goals and characters who must return. Safe non-conflicting corrections may execute and report; changes that conflict with approved prose or substantial downstream work require an impact explanation and governed proposal first. Canon, TruthScope, CharacterKnowledge, PromiseLedger, version evidence and impact analysis remain intact backstage and hidden by default.

## 2026-07-18 AI-task transparency and recovery decision freeze

The user confirmed that the center CangJie conversation remains the primary control plane while the AI Tasks page exists for transparent status, safe fallback, recovery and diagnostics. Every status answer must read the transactional task source rather than infer from chat or model text. The ordinary page organizes user-facing progress only as `正在做 / 接下来 / 需要你`, then shows the real book, last safe checkpoint, evidence-based estimated and actual cost, pause reason and available recovery actions; internal current/completed pipeline steps are available only in redacted advanced details, with no fabricated percentage or chain of thought. Safe pause, stop while keeping unadopted results, and discard unadopted results are separate operations with separate permissions and retention state; discard cannot remove adopted or approved prose. Network loss, app suspension, provider load, budget limits, major story decisions, recoverable errors and unknown outcomes use plain-language reasons. One primary creative task runs at a time, other work queues or asks first, and conversation, Current Results and AI Tasks share one status projection. 高级详情 remain folded, truthful and redacted, and never expose prompts, credentials or chain of thought.

## 2026-07-18 automatic-research decision freeze

The user confirmed that research is proactive evidence work, not a user-operated search box. CangJie assesses knowledge gaps at project formation, chapter planning, pre-draft and review stages, then follows Story Memory, local topic pack, valid cache, necessary online research, and source/conflict checks in that order. Triggering must independently consider content type, coverage, impact, freshness, source quality, conflict and genre-contamination risk rather than trust model confidence. Topic packs are sourced, versioned references that distinguish public facts, genre conventions, schools, conflicts and book-selected rules; they are not canon and cannot contain complete copyrighted novels. A Honghuang idea automatically receives a topic pack and only direction-changing disputes reach the user. Offline-only, local-only and research-budget controls are binding. External material remains untrusted data with no authority over Agent permissions, prompts, tools or confirmed Story Memory.

## 2026-07-18 first-chapter-start-threshold decision freeze

The user confirmed that reversible 100–300 character scenes, micro-samples, opening candidates, ability costs and chapter-ending candidates may be generated during exploration without complete planning. Before a full Chapter 1, the ordinary surface shows one plain-language “我准备这样写” result covering tone, protagonist situation, chapter event, ending payoff, explicit avoidances and unresolved items. “就这样开始” and clear natural-language commands such as “开始写第一章”, “你替我决定” and “直接写” are equivalent authorization; unresolved choices remain reversible temporary assumptions. The backstage Showrunner still creates a production-grade opening basis and runs plan, research coverage, drafting, character-knowledge, continuity, genre-purity, AI-style, bounded-revision and checkpoint stages. Generated Chapter 1 is only “供你看看”; approval is required before prose freezes and character, world, clue and next-chapter settlement occurs.

## 2026-07-18 selection-semantics and edit-impact decision freeze

The user confirmed that the first-level selection menu is `复制 | 问仓颉 | 更多`; “原样保留” is retired from the first-level path. A selection is only the current discussion focus and the starting point for edit analysis. It does not itself mean like, dislike, problem, preservation or hard lock, and it cannot confirm why the user likes something. More may offer the soft signals “这段我喜欢”, “这个感觉别丢”, “只讨论这段” and “标记为问题”. Only the explicit “锁定文字不变” action or an unambiguous instruction such as “这句一个字都不要动” creates an exact version-bound hard lock. CangJie may propose a correctable hypothesis about the user's preference, but the user can reject or rewrite it and it must never masquerade as confirmed preference.

The user also confirmed that a selection is an edit starting point, not the final impact boundary. Before changing prose, CangJie must show a plain-language impact preview across sentence/paragraph, scene, chapter and ending, downstream chapters, approved prose, user-authored edits, hard locks, Story Memory and plans. When the real dependency scope expands, the ordinary choices are “连带改顺后面 / 只改这里但可能不连贯 / 另建版本试试 / 先别改”. Unapproved working content may be selectively regenerated. Approved prose must keep its old version and move through a user-decided branch; user-authored edits outrank stale generated prose. Execution reconnects dependencies in order and then rechecks character knowledge, time, causality, clues/reader promises and genre rules. “只讨论这段” limits conversation focus only and never hides real dependencies.

## 2026-07-18 agent-first-calibration and secondary-manual-edit decision freeze

The user confirmed that both ordinary users and experienced authors default to selection/reference plus plain-language conversation and Agent-executed revision. Manual editing is discoverable but secondary and never required. A manual-edit session creates a new version, preserves the prior AI draft and makes human text the current highest-priority source without approving the chapter. Impact analysis is deferred until leaving edit mode or starting revision, generation, approval or later work, rather than interrupting every keystroke.

## 2026-07-18 reference-profile and interaction-learning decision freeze

The user confirmed two governed learning paths: sourced, abstract and revocable reference profiles extracted only from material the user is authorized to use; and gradual interaction-preference memory with separate one-time, book and cross-project scopes plus separate AI-hypothesized and user-confirmed states. Neither path trains or fine-tunes Provider model weights. The first release uses local reviewable memory, retrieval and ContextCompiler assembly, and must not reproduce copyrighted expression or imply that uploads train a personal model.

## 2026-07-18 ambiguous-rejection diagnosis decision freeze

The user confirmed that “this chapter feels wrong / I cannot explain why” starts diagnosis rather than a professional reason form or blind full-chapter redraw. CangJie reads the conversation, confirmed preferences, Story Memory and prose, proposes two or three concrete plain-language hypotheses or scene contrasts, asks one highest-information easy question at a time, and may use a reversible 100–300-character sample. Once actionable clarity is reached, it reflects the current understanding, previews the real edit impact and only then performs the authorized revision. Diagnostic candidates remain AI hypotheses until the user confirms them.

## 2026-07-18 three-chapter approval and continuous-creation authorization decision freeze

The user confirmed chapter-by-chapter approval for the first three chapters without making a complex approval form the primary surface. The reader and CangJie conversation expose lightweight “就按这版继续 / 和仓颉聊聊” actions, while explicit natural language such as “可以”, “继续下一章” and “按这个感觉往下写” is equivalent approval. Ambiguous praise such as “还行 / 差不多” requires one clarification and cannot freeze prose. Each approved chapter must bind and freeze the exact version, settle Story Memory, character knowledge, clues/promises, checkpoint, and only then unlock the next chapter. Chapter 3 approval does not start serial generation: CangJie explains automation, cost/budget and graded creative delegation, requests one continuous-creation authorization, and after authorization stops asking mechanically after every ordinary chapter.

## 2026-07-18 graded-creative-delegation decision freeze

The user confirmed graded creative delegation for continuous creation. CangJie directly executes and reports ordinary, reversible decisions that do not change the book's direction. Major changes—including the protagonist's core goal, an important character's death, permanent betrayal or complete corruption, core relationships, hard world or ability rules, main plot, volume plan and ending promises—must first resolve a versioned grant by decision category and novel/volume/chapter scope. A covered decision may execute but requires a conspicuous notice with the actual choice, affected content and grant provenance. An uncovered decision must pause before a safe checkpoint and show a plain-language card with the reason, impact, two or three concrete directions, CangJie's recommendation and one easy question; it cannot throw an empty decision at the user. Users may inspect, grant, narrow and revoke delegation in natural language, and one decision never implies permanent authority. Cost hard limits, task integrity, permissions, safety, external-data disclosure and version/idempotency/checkpoint governance are non-delegable in every autonomy mode.

## 2026-07-18 continuous-generation sequencing decision freeze

The user confirmed that continuous creation defaults to three prepared chapters, is adjustable in plain language or settings from one to five, and may keep at most five unread leading versions in the first release. Prose generation is strictly chapter-ordered with one Writer owner: a chapter must finish review, temporary Story Memory settlement and checkpoint before the next chapter starts; research and read-only review may run in parallel only when they cannot acquire prose-write ownership. Unread chapters are labeled “仓颉准备的版本，等你看”, may serve as working context and never count as user-confirmed truth. Earlier-chapter changes preserve the old branch, run impact analysis and selectively regenerate affected work. “写完这一章暂停” finishes and checkpoints the current chapter before stopping; “现在暂停” cancels the current request and keeps incomplete output only as temporary material. Resume is idempotent and must not duplicate generation, tool effects or charges.

## 2026-07-18 user-preference-proxy and shadow-reader decision freeze

The user confirmed the user-preference-proxy / shadow-user architecture. Public language must not promise a fully distilled digital clone; internal components may be named `UserPreferenceProxy` and `BookReaderProxy`. The first release is non-parametric and evidence-based: scoped preference memory, retrieval, candidate ranking, blind shadow review, calibration from real user feedback and explicit abstention. It does not train, fine-tune, distill or LoRA-adapt user-specific weights. Long-term cross-project preferences, book preferences and current-volume/chapter intent are strictly separated, and each record carries original evidence, support/counterevidence, scope, confidence, version, revocability and confirmation state. Uploading or reading material is not evidence of liking it, AI-generated judgments cannot become self-reinforcing gold labels, and copyrighted expression must not be reproduced.

The proxy may predict, rank, review, abstain and recommend a pause; it cannot approve chapters, merge Story Memory/canon, write prose or decide unauthorized major plot changes. Continuous creation adds a pre-chapter plan gate, independent hard-rule/continuity review, a blind `BookReaderProxy` review, cumulative drift detection, a yellow reduced-window response and a red checkpoint pause. P0–P5 are now frozen as evidence foundation, passive profile, shadow review, continuous-generation integration, calibration, and only then optional lightweight-model evaluation after held-out and real-user evidence. Acceptance covers accept/reject prediction, ranking, calibration, abstention quality, drift false negatives/positives, automation and real-user sampling. Research papers supply methods only; their experimental figures are not product promises.
## 2026-07-18 narrative-index and novel-codegraph decision freeze

The user formally confirmed the “仓颉叙事索引 / 小说版 CodeGraph” direction. This is a local, explainable narrative-evidence architecture rather than a generic GraphRAG product. Its immutable source layer preserves imported material, chapter prose, user edits, research and authorized references with source/version/span provenance; summaries, embeddings, extractions and later revisions may point to that layer but never replace it. The first-release retrieval stack combines SQLite FTS5, lightweight vector similarity, chapter-order-first hierarchy and structured novel relations for events, character state and knowledge, time, relationships, resources/abilities, foreshadowing/promises and scene/chapter dependencies.

Queries are planned adaptively by task, risk, token, latency, cost and index coverage. They start locally, expand through adjacent narrative order and relevant domain relations, then reach the full book and necessary research only when evidence remains insufficient. Every expansion is auditable; unresolved questions must abstain rather than guess. High-impact conclusions return to immutable source spans, and an LLM may propose but cannot close the evidence loop alone. Indexing is progressive and resumable: source plus basic FTS5 first, then incremental structural/vector/relationship extraction with checkpoint, idempotency, coverage and freshness reporting. An incomplete index must never be presented as complete-book understanding.

Authorized reference novels support only sourced abstract traits such as structure, pacing, viewpoint, narrative distance, characterization and information order. Uploading or reading is not liking; a trait enters book or cross-project preference only after user confirmation. Distinctive wording, long passages, unique plot devices and copyrighted prose may not be reproduced, and reference material has no Story Memory/canon or Agent-permission authority. The first release explicitly stays with SQLite/GRDB, FTS5, lightweight local vectors, structured relationship tables and `ContextCompiler`; it does not introduce Neo4j, Qdrant, a complete GraphRAG/LightRAG service, a heavy external graph database or a cloud-knowledge-graph dependency.

Status boundary: the product and architecture contract is frozen; implementation remains staged work, not a completed capability claim.

Still-unfrozen implementation choices: embedding model/provider and offline fallback; Chinese FTS5 tokenizer/segmentation; lightweight vector storage and ANN strategy; exact subtypes and classifier thresholds inside the four frozen material classes; model binding within each specialized indexer; query-plan scoring and budget algorithm; index scheduling and freshness priorities; exact `ReferenceProfileTrait` schema; authorization default lifetime and revocation behavior for already-derived remote results; future criteria for reevaluating external graph/vector components; and whether/when a lightweight preference model earns P5 evaluation.

## 2026-07-18 local-first material indexing, authorization and evidence-index routing decision freeze

The user confirmed that every uploaded material first receives a free, local and fast basic index. This stage preserves immutable source, extracts available text, builds basic FTS5 and chapter/page/paragraph positions, records hashes, duplicates and usability, and never calls a paid model or sends content to an external Provider. Readability and local search must not wait for whole-book deep analysis.

The first networked deep-understanding operation must disclose the exact file/chapter/page/span or sample scope, what is excluded, Provider/model, purpose, expected cost or range, budget ceiling, subsequent incremental permission and external-data exposure, then obtain explicit user authorization. Authorization is purpose-, scope-, Provider/model- and budget-bound; material expansion or a material change to any bound requires new authorization. After authorization, CangJie processes only the current-task or changed range, stores cursor/source version/disclosure scope/usage/cost/checkpoint, and resumes idempotently after pause, disconnect, suspension, crash or unknown result without resending, reanalyzing the whole book or charging twice.

The previously reserved Evidence Index direction is now formally frozen. All material types share immutable source, provenance/version/span location, hash, full-text and semantic candidate retrieval, incremental update, checkpoint, coverage and evidence backlink contracts, while specialized understanding and query planning remain type-specific: novels use `NarrativeIndex`; factual references use `ResearchIndex`; user-owned project notes and settings use `ProjectMaterialIndex`; positive/negative examples and preference evidence use `PreferenceIndex`. Classification is automatic where reliable, asks the user only when uncertainty matters, and splits mixed ZIPs by file or mixed documents by span. The same authorized reference novel may expose purpose-isolated `NarrativeIndex` structure and `PreferenceIndex` abstract-preference views over one immutable source, without sharing confirmation or adoption state. Retrieval is isolated by project, material type, purpose, confirmation state, tool permission and external-disclosure authorization. Reference material never becomes book setting automatically, and reference fiction never enters `ResearchIndex` as factual evidence.

Status boundary: these contracts are frozen architecture and acceptance requirements, but code implementation remains staged work. Do not claim the four indexers, classifier or authorization flow are already present until their milestone evidence passes.
## 2026-07-18 Harness contract supplement

This is a documentation correction based on the complete approved history in 1.md. It is part of the current S1/H0-H5 baseline and is not an implementation-complete claim.

### Driver Cockpit Snapshot

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

The snapshot is compiled by the Harness and is not a second source of truth. Provider/model, capability, permission, budget, disclosure and version bindings remain explicit and auditable.

### Capability modes and permission boundary

The runtime must expose complete driving, restricted driving and writing-only modes based on capability evidence. Typed Tools enforce the five permission levels; a model can propose an action, but only the host can commit it.

### Approved rejection example

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

The real milestone remains **S1: Agent cockpit direction and refactor**. H0-H5 are architecture gates awaiting implementation and acceptance.

## 2026-07-19 S1 multi-conversation workspace slice evidence

Status boundary: this is an **implementation slice inside S1**, not completion of S1. S2 has not started; no Provider, model, Tool Call, Agent Loop, formal prose generation, H0-H5 gate completion, IPA acceptance, or physical-device acceptance is claimed.

Implemented behavior in this slice:

- App initialization and foreground recovery use the read-only `restoreS1ConversationWorkspace()` projection. The durable `s1WorkspaceState.selectedConversationID` is the current selection; `updatedAt` ordering is only history ordering and never silently chooses the active conversation.
- `selectedConversationID == nil` is a real unsent-new-conversation state. Selecting “新对话” preserves its draft in `unboundDraft` and creates no empty `Conversation`, `NovelProject`, Agent run, Artifact, Approval, Chapter, receipt, usage record, or model request.
- Each bound Conversation has an independent `s1ConversationDraft`. Switching among existing Conversations and the unsent new-conversation state restores the matching messages and draft without writing the newly displayed draft back into the previous Conversation.
- First send validates the message and atomically creates the Conversation, inserts the user message and exact fixed receipt, derives the history title, persists the selection, clears only the consumed unbound draft, updates the monotonic Conversation timestamp, and returns the complete Workspace snapshot. A failure rolls all of those effects back together.
- Sending in an existing Conversation clears only that Conversation's draft. It does not clear a separately preserved unsent new-conversation draft.
- Delayed autosave and checkpoint writes carry the expected Conversation selection and fail closed if durable selection changed before the write boundary.
- S1 checkpoints now bind `scopeKey` and optional `conversationID`. The same payload in `s1:new` and `s1:conversation:<UUID>` cannot be mistaken for the same checkpoint, while checkpoint sequence remains monotonic within the durable task.
- The retired `draft(id='m0')` slot remains a compatibility mirror only. Workspace tables are the S1 truth source and UI restoration never reads `m0` to decide the selected Conversation.
- The left rail now shows the real Conversation history, a “新对话” action, title, updated time, durable current-selection highlight, and Conversation switching. `Novel Projects` still pushes inside the left rail's independent `NavigationStack`; it does not replace or recreate the central conversation view.
- The exact honest receipt remains: `界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。` It proves local persistence only and must not be presented as model understanding or Agent execution.
- Draft autosave remains lifecycle- and Build-Activation-governed, rejects content beyond 65,536 UTF-8 bytes at the database boundary, and preserves the last recoverable draft on failure. Sent messages remain limited to 32,768 UTF-8 bytes; unsafe directional controls are rejected and multiline display projection prevents forged role-label presentation.

Post-review integrity closure on 2026-07-19:

- Legacy `saveDraft` and `checkpointDraft` now update only the retired `m0` compatibility surface. They cannot infer the active Conversation or write `s1WorkspaceState` / `s1ConversationDraft`; all S1 writes must enter through the selection-bound scoped APIs.
- Checkpoint decoding rejects malformed non-empty Conversation identifiers, unknown scope keys, and any `s1:conversation:<UUID>` / `conversationID` mismatch instead of silently degrading identity to `nil`.
- The checkpoint-to-Conversation foreign key uses delete restriction rather than `SET NULL`, and an additive retention trigger protects databases that may already have applied the earlier migration shape. A retained checkpoint therefore cannot lose its audit identity when a Conversation deletion is attempted.
- Regression coverage now includes legacy mirror isolation, malformed and mismatched checkpoint identity, restricted Conversation deletion, and ViewModel selection failure preserving the complete visible Workspace state.

Verification recorded on Windows on 2026-07-19:

- `swift test --enable-code-coverage`: 70 tests, 0 failures.
- `S1ConversationPreviewTests`: 10 tests, 0 failures inside the full SwiftPM run.
- Windows `CangJieCore` executable coverage: 2,370 / 2,427 lines = 97.6514%; 500 / 512 functions = 97.6563%; 912 / 956 regions = 95.3975%.
- `swiftc -frontend -parse` passed for the changed App, App XCTest, and XCUITest Swift files.
- `git diff --check` passed. Focused scans of touched files found no BOM, U+FFFD, three-question-mark corruption run, CRLF drift, credential pattern, tracked database, IPA, signing material, or coverage artifact.
- SwiftPM still reports the pre-existing non-test warning that it cannot create `.build\debug` as a symbolic link on this Windows filesystem.
- Windows cannot type-check the iOS/SwiftUI/GRDB app target or execute App XCTest/XCUITest. The new migration, runtime UI behavior, IPA packaging, and physical-device behavior therefore remain unverified until the later exact-candidate Apple build and S1 device gate.

No commit, push, remote CI run or milestone-complete claim was made by this slice.

## 2026-07-19 S1 left-rail novel shelf and checkpoint-retention closure

Status boundary: this closes another implementation slice inside S1 only. It does not start S2 and does not claim Provider/model integration, a Typed Tool model loop, formal prose generation, H0-H5 completion, an IPA candidate, Xcode execution, or physical-device acceptance.

Implemented and reviewed behavior:

- `Novel Projects` pushes a dedicated shelf page inside the left region's independent `NavigationStack`; selecting a persisted novel pushes a left-region detail page and both levels provide an explicit back action. The center Conversation, current selection, visible messages, and scoped draft remain mounted and unchanged.
- For `persisted-novel-shelf` specifically, the empty shelf creates no placeholder project, while the debug-only, explicitly requested non-empty-shelf fixture seeds a real Conversation, exact S1 preview receipt, scoped draft, and `NovelProject` through production persistence APIs.
- `CANGJIE_UI_TEST_FIXTURE=persisted-novel-shelf` is recognized only in `#if DEBUG`; an absent fixture leaves normal startup untouched. An unknown fixture, or any requested fixture with a missing or malformed `CANGJIE_UI_TEST_DATABASE_SCOPE`, fails closed into the unavailable-state ViewModel and cannot fall back to the normal application database.
- Legacy `checkpointDraft` deduplication now compares payloads only inside `legacy:m0`; an identical payload already present in `s1:new` or `s1:conversation:<UUID>` cannot be reused as a legacy checkpoint. Sequence allocation remains monotonic for the task.
- A realistic previous-database fixture proves the incremental retention migration against an already-applied `s1-checkpoint-scope-v1` schema whose foreign key still uses `ON DELETE SET NULL`. Opening the database installs the additive delete-restriction trigger and preserves checkpoint scope and Conversation identity. This is migration-compatibility evidence, not evidence that a production writer created the legacy database state.
- If the old `SET NULL` behavior has already produced `scopeKey=s1:conversation:<UUID>` with `conversationID=NULL`, migration throws `AppDatabaseError.invalidCheckpointScope`. The migration identifier is not committed, the checkpoint is neither repaired nor deleted, and the original damaged record remains available for a later explicit recovery path.
- Review found and corrected accidental ASCII-question-mark corruption in the new Chinese UI fixture before closure. A changed-file corruption scan now guards the slice.

Verification recorded on Windows on 2026-07-19:

- `swiftc -frontend -parse` passed for the combined changed App, App XCTest, and XCUITest Swift set.
- `swift test --enable-code-coverage`: 70 tests, 0 failures.
- `git diff --check`: passed.
- Changed-file scan: no BOM, U+FFFD, CRLF drift, run of four ASCII question marks, credential pattern, or newly modified database/IPA/signing artifact.
- The repository still contains pre-existing mixed-line-ending/BOM files and historical artifacts under `artifacts/`; they were reported but not normalized, overwritten, or deleted by this slice.
- Windows cannot type-check the iOS/SwiftUI/GRDB App target or run App XCTest/XCUITest. The migration and non-empty shelf UI tests still require the later exact Apple/Xcode candidate gate; this is not yet a reason to request physical-device installation.

No commit, push, remote CI run, or milestone-complete claim was made.

## 2026-07-19 S1 Activity Bar and truthful capability projection slice

Status boundary: this closes an additional implementation slice inside **S1 Agent 驾驶舱定调与重构** only. It does not start S2 and does not claim Provider/model integration, a Typed Tool model loop, formal prose generation, H0-H5 completion, an IPA candidate, Xcode execution, or physical-device acceptance.

Implemented behavior:

- A narrow icon-only Activity Bar now projects exactly the S1 capabilities that are real and useful: `仓颉`, `我的小说`, `AI 任务`, and `设置`, in a stable order defined by `S1ActivityBarContract`. `阅读与修改`, `故事记忆`, `资料`, device diagnostics, build identity, and other unavailable or internal surfaces remain hidden.
- Every visible Activity Bar item exposes a Chinese accessibility label, a plain-language purpose hint, a selected/unselected value, and a long-press explanation. Navigation selection belongs to the left navigation surface only; the center Conversation remains mounted as a sibling and retains its selected Conversation, messages, and scoped draft while left pages change.
- `我的小说` and its detail page stay inside the left region's navigation stack. `AI 任务` presents a truthful S1 empty state rather than simulated work. `设置` contains only a real persisted `显示更新时间` setting, and the setting changes both the visible timestamp projection and the VoiceOver label.
- The ordinary right-side control is named `显示这次结果 / 收起这次结果`. Its S1 empty state explains that no real model result exists yet and no longer exposes `Artifact`, `Tool Receipt`, revision hashes, bindings, or internal Agent reports.
- Unimplemented novel-detail actions are hidden instead of being presented as dead `后续阶段接入` entries. The fixed S1 preview receipt remains unchanged and no Activity Bar action creates a project, starts a task, or manufactures a result.

Verification recorded on Windows on 2026-07-19:

- `swiftc -frontend -parse` passed for the combined changed App, App XCTest, XCUITest, Activity Bar contract, and Conversation preview Swift files.
- `swift test --enable-code-coverage`: 73 tests, 0 failures; `S1ActivityBarContractTests`: 3 tests, 0 failures.
- Windows `CangJieCore` executable coverage: 93.32% regions, 95.45% functions, and 95.96% lines; `S1ActivityBarContract.swift` has 100% line and function coverage.
- `git diff --check` passed. Focused scans of the four Activity Bar slice files found no BOM, U+FFFD, CRLF drift, run of four ASCII question marks, or real credential material.
- SwiftPM still reports the pre-existing Windows warning that it cannot create `.build\debug` as a symbolic link.
- Windows cannot type-check the iOS/SwiftUI/GRDB App target or execute App XCTest/XCUITest. The Activity Bar layout, context menu, Toggle behavior, and iPad interaction therefore remain pending the later exact Apple/Xcode candidate gate; this slice alone is not a reason to request physical-device installation.

No commit, push, remote CI run, milestone-complete claim, or physical-device acceptance claim was made.


## 2026-07-19 S1 ordinary-language and accessibility hardening evidence

Status boundary: this is another implementation slice inside **S1: Agent cockpit direction and refactor**. It does not claim S1 completion, S2 start, a real Provider/model connection, a Typed Tool Loop, formal prose generation, H0-H5 completion, IPA acceptance, or physical-device acceptance.

Implemented and checked in this slice:

- Ordinary status text now comes from `S1OrdinarySurfaceContract`; raw approval, chapter, revision and runtime stages are no longer copied directly into the top-level user status.
- `AppViewModel` now keeps engineering diagnostics separately in `diagnosticErrorMessage` and `diagnosticNoticeMessage`, while `errorMessage` and `TransientNotice.message` project plain Chinese recovery guidance. Database, Keychain, checkpoint, stale approval/chapter and network codes remain available for diagnosis but are not displayed on the ordinary surface.
- Non-fixed task/result empty states no longer expose S1/S2 phase names. The exact fixed receipt remains byte-for-byte unchanged: `界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。`.
- `AgentRuntimeOrdinaryCopy` is the tested projection used when the governed runtime appends normal, recovery and replay messages to the ordinary Conversation. It hides revision numbers, binding hashes, Tool Receipts, exact rewrite-scope metadata and V1/V2 diff vocabulary without deleting any underlying governance object.
- Opening-plan approval, chapter version integrity, hashes, receipts, idempotency and state-machine checks remain intact; only their ordinary-language projection changed.
- Landscape independent pages and the portrait navigation overlay now hide covered workspace regions from hit testing and the accessibility tree, establish a modal accessibility boundary, announce `关闭导航` for close actions, and release composer focus before page/result transitions.
- `isLeftPagePresented`, an unused third navigation state source, was removed so left-region selection remains owned by the established Activity Bar/overlay state.

TDD and verification evidence:

- RED evidence was captured for the missing diagnostic/notice projection functions and for the missing `AgentRuntimeOrdinaryCopy` contract before implementation.
- `swift test --enable-code-coverage`: **89 tests, 0 failures**.
- LLVM coverage for `CangJieCore`: regions **88.59%**, functions **93.63%**, lines **94.14%**.
- `swiftc -frontend -parse`: **25 changed/untracked Swift files passed**.
- `git diff --check`: passed.
- Changed/untracked Swift and Markdown scan: **32 files**, UTF-8, no BOM, LF, no U+FFFD and no consecutive corruption marker.
- Changed/untracked credential and generated-artifact scan found no API key, private key, IPA, database, provisioning profile or signing material.
- Windows cannot execute XCUITest or an iPad build, so the new UI assertions are source contracts awaiting the later macOS/IPA gate. This slice is **not** a device-test stop point.
- No commit, push or remote CI action was performed.

## 2026-07-19 S1 persisted Reader and scale-fixture evidence

Status boundary: this is another implementation and local-verification slice inside S1 only. It does not claim S1 completion, S2 start, Provider/model integration, a Typed Tool model loop, formal prose generation, H0-H5 completion, an IPA candidate, Xcode execution, or physical-device acceptance.

Implemented and reviewed behavior:

- A requested DEBUG fixture now requires both an explicit fixture name and a valid UUID `CANGJIE_UI_TEST_DATABASE_SCOPE`. A missing or malformed scope returns the unavailable-state `AppViewModel`; it cannot fall back to the normal application database. No fixture request still leaves ordinary startup untouched.
- `persisted-novel-shelf` uses production persistence APIs for the Conversation, exact S1 preview receipt, scoped draft, and `NovelProject` state it creates. Its multi-call seed remains protected primarily by the unique isolated XCUITest scope rather than being described as one atomic production transaction.
- `persisted-readable-two-books` and `persisted-scale-and-restore` are Debug-only, explicitly requested database-compatibility fixtures. Their constrained direct SQL creates deterministic records inside a fresh isolated scope; the fresh-scope check and complete complex seed now share the same write transaction.
- Those complex fixtures prove database/schema compatibility, ordinary application reopen, Reader and Conversation restoration, the latest-200-message projection window, and UI projection. They do not prove that the production writer can create the same state.
- Formal production-writer reopen evidence remains separate: `AppDatabaseTests.testProductionChapterToolReaderProjectionSurvivesActualDatabaseReopen` creates chapter and Reader state through production APIs before reopening the real SQLite database, while `S1CockpitViewModelTests.testS1PreviewProductionWindowRestoresMessages041Through240AfterDatabaseReopen` creates 240 messages through the production preview path before reopening and restoring messages 041 through 240.
- Complex fixture seeding is fresh-only and insert-once, not idempotent. Fixture-owned business entities are inserted once, while the migration-created `s1WorkspaceState.default` singleton is updated to select the fixture Conversation; the bootstrap as a whole is therefore not described as insert-only.
- The scale UI helper now claims only what it proves: the final projected message is reachable, messages 239 and 240 occupy indices 198 and 199, and the 200-message window exposes no index 200. It no longer claims a physical ScrollView bottom-boundary assertion.

Windows verification completed on 2026-07-19:

- The CI-equivalent strict Core script passed 99 XCTest plus 15 Swift Testing tests, 114 total with zero failures, strict concurrency, warnings-as-errors, and 94.15% `CangJieCore` line coverage against the 90% gate.
- All six Python build/candidate-set contract scripts passed: 47 unittest cases passed, one platform-dependent case was skipped, and both standalone candidate-set and build-identity contract checks reported success.
- `swiftc -frontend -parse` passed for all 41 changed or untracked Swift files, including the three new fixture bootstrap failure-closure tests.
- `git diff --check` passed. All 48 changed or untracked files passed UTF-8, BOM, NUL, U+FFFD, repeated-question-mark, CRLF-drift, credential-pattern, and generated-artifact scans.
- Independent code and documentation reviews found no P0-P2 defect. The code review's single P3 comment-accuracy finding was corrected so the scale fixture distinguishes inserted fixture-owned rows from the updated workspace singleton. The documentation review found no false production-writer, idempotency, or Apple-verification claim; its missing-Control-Center-evidence finding is resolved by this section.

Apple and device boundary:

- Windows cannot type-check the iOS/SwiftUI/GRDB App target or execute App XCTest/XCUITest. The fixture bootstrap tests, Reader and scale UI assertions, Xcode build, simulator execution, signing, IPA packaging, and physical-device behavior remain unverified until an exact Apple CI and Candidate Set run.
- No commit, push, remote CI run, IPA build, or milestone-complete claim was made by this slice. This is not yet a physical-device installation stop point.

## 2026-07-20 S1 App-target semantic compile repair and CI boundary evidence

This slice remains inside S1 and does not claim S1 completion, S2 Provider/model integration, a real Typed Tool loop, formal prose generation, H0-H5 completion, IPA acceptance, or physical-device acceptance.

Remote evidence for commit `86bb9069b9665ecb5a02aa7ae6d7ef267ca570ac`:

- Core CI run `29719583828` passed.
- iPadOS CI run `29719583888` failed in the App target compile step before CangJie UI tests began. The first real error was `App/CangJieApp/AppDatabase.swift:514:37: error: cannot find 'S1ConversationPreview' in scope`.
- The Keychain Isolation Probe simulator test completed successfully after the main App compile failed; this does not waive the main App failure.

Root cause and repair:

- `S1ConversationPreview` is public in the `CangJieCore` package, but Swift imports are file-scoped. `AppDatabase.swift` used `S1ConversationPreview.maximumDraftUTF8Bytes` without importing `CangJieCore`.
- Added the minimal `import CangJieCore` to `App/CangJieApp/AppDatabase.swift`; no limit was duplicated or removed.
- Added `scripts/tests/test-app-module-import-contract.py`, which scans every current App target source root recursively and fails when S1 preview symbols are used without a same-file `CangJieCore` import.
- Wired that contract into `core-ci.yml`, `ios-ci.yml`, and `build-ipa.yml`, so the failure is caught in Windows preflight, before iPadOS simulator execution, and before a manual IPA candidate build.

Windows verification after the repair:

- Strict Core script passed 99 XCTest plus 15 Swift Testing tests, 114 total with zero failures, and 94.15% `CangJieCore` line coverage against the 90% gate. The first invocation was blocked only by the local `SDKROOT` trailing-separator environment shape; rerunning with the same SDK root normalized passed. No project code change was made for that environment detail.
- All Python contract tests passed, including the new App module import contract. The suite reported 48 unittest cases passed with one platform-dependent skip, plus the two standalone candidate-set and build-identity contract checks.
- `swiftc -frontend -parse` passed for the repaired AppDatabase source; `python -m py_compile` and `git diff --check` passed.
- Git Bash ldid and simulator-selector tests passed; the symlink negative case was skipped because the Windows host cannot create symlinks. The entitlement and GRDB resource shell contracts were not counted as Windows evidence because the local Git Bash host could not execute them under the same macOS assumptions; they remain required in Apple CI.

This is not yet a device-test stop point. The next gate is a new push and successful Core CI plus iPadOS CI for the repair commit. Only after both pass may `build-ipa.yml` be manually triggered on `macos-15`; only after the exact Candidate Set manifest, SHA-256, entitlements, signature evidence, and commit binding are verified may the user be asked to install the paired IPA files.


## 2026-07-20 S1 App XCTest actor-isolation semantic repair

This remains an implementation and verification slice inside **S1: Agent cockpit direction and refactor**. It does not claim S1 completion, S2 Provider/model integration, a real Typed Tool loop, formal prose generation, H0-H5 completion, IPA acceptance, or physical-device acceptance.

The previous exact commit `b80c73d5c9503b8759038126017a7f05acad439a` passed Core CI (`29720910079`) but its iPadOS CI (`29720910028`) failed while compiling `CangJieAppTests`. The first real errors were six calls from nonisolated synchronous tests into the `@MainActor` `withDatabase` helper at lines 268, 337, 559, 580, 609, and 625 of `App/CangJieAppTests/S1CockpitViewModelTests.swift`, followed by missing `await` on the async `DatabaseQueue.write` calls at lines 699 and 714. The App target itself had already compiled, and the later Keychain Isolation Probe success did not waive the failed test target.

Repair scope:

- Marked only the six tests that call the MainActor-isolated synchronous helper as `@MainActor`; the production-window reopen test that does not use that helper remains nonisolated.
- Added `await` to the two async `DatabaseQueue.write` calls in `testSuccessfulS1SendPreservesExistingStorageError`; no actor boundary, test, or safety gate was removed.
- Added Pitfall `P-261` to distinguish XCTest actor/async semantic coverage from the file-scoped import gap recorded by P-260.

Windows verification:

- `swiftc -frontend -parse App/CangJieAppTests/S1CockpitViewModelTests.swift` passed; this proves syntax only, not App XCTest actor semantics.
- All Python contract scripts passed, including the standalone candidate-set/build-identity checks and the repository unittest suite; the platform-dependent symlink case remains skipped on Windows.
- `git diff --check` passed and the working tree changes were limited to the test file plus the two evidence documents.

Apple boundary and next gate:

- The authoritative proof is a new `macos-15` iPadOS CI run compiling and executing the actual App XCTest target with zero actor-isolation or missing-`await` errors, while Core CI passes for the same exact commit.
- No IPA workflow has been triggered for this repair, no Candidate Set manifest or IPA hashes exist for it, and there is no physical-device installation stop yet. Only after both CI workflows pass may `build-ipa.yml` be manually triggered; only after its exact Candidate Set manifest, commit binding, SHA-256, signature, entitlements, and validation instructions are verified may the user be asked to install the paired IPAs.


## 2026-07-20 S1 App XCTest chained-comparison compile repair

This remains inside S1 and does not claim S1 completion, S2 start, Provider/model integration, a Typed Tool loop, H0-H5 completion, IPA acceptance, or physical-device acceptance.

Remote evidence for exact commit `2e8e20f9b2566d02384650f4fb23636cb9ebf2cd`:

- Core CI run `29721669526` passed.
- iPadOS CI run `29721669531` progressed beyond the previous actor-isolation errors, then failed compiling `App/CangJieAppTests/AppViewModelTests.swift`.
- The first real errors were the three non-associative chained comparisons at lines 412, 478, and 856: `optional message == expected string == true`.
- Keychain Isolation Probe tests passed again, but they do not waive the main App XCTest target failure.

Repair scope and local evidence:

- Replaced the three chained `XCTAssertTrue` expressions with direct `XCTAssertEqual` comparisons, preserving the expected Chinese notice text and improving failure diagnostics.
- A repository-wide App Swift scan found no remaining `== ... == true` chain.
- `swiftc -frontend -parse`, Python contracts, encoding/credential scans, and `git diff --check` remain required locally; Xcode on `macos-15` remains authoritative for App XCTest compilation and execution.
- Added Pitfall P-262 so this exact Swift precedence error is not repeated.

No IPA workflow may be triggered until Core CI and iPadOS CI pass for the same new exact commit. This is not a physical-device installation stop point.

## 2026-07-20 S1 readable-content SQL boundary repair

This remains an implementation and verification slice inside S1. It does not claim S1 completion, S2 Provider/model integration, a real Typed Tool loop, H0-H5 completion, IPA acceptance, or physical-device acceptance.

Remote evidence for exact commit `df8da6500e6fe50004ee1c3ccf280d855ba60ce0`:

- Core CI run `29722408178` passed.
- iPadOS CI run `29722408085` compiled the targets and started the real App XCTest suite, then failed. The first real failure was `AppDatabaseTests.testProductionChapterToolReaderProjectionSurvivesActualDatabaseReopen` at line 2211 with SQLite error 1.
- The emitted SQL proved the root cause: the shared SELECT ended in `calibration.projectID` and the appended filter began immediately with `WHERE`, producing `calibration.projectIDWHERE calibration.conversationID = ?`. The same boundary defect also appeared in the project-scoped `WHERE calibration.projectID = ?` query.
- Later Tool Receipt, Agent Session, governance-transition, ordinary-copy, workspace, main UI, and Isolation Probe UI failures are not being pre-emptively rewritten in this slice. Some Reader failures are direct SQL cascades, while the remaining first independent error must be taken from the next complete Apple CI run.

Repair and regression coverage:

- Both query compositions now insert an explicit `"\n"` between `s1ReadableContentSelect` and the appended `WHERE` clause. The fix does not rely on invisible trailing whitespace in a Swift multiline literal.
- Added `testS1ReadableContentQueriesKeepWhereClauseSeparatedOnRealSQLite`, which executes both the Conversation-scoped and project-scoped production queries against a real temporary SQLite database and expects an honest `nil` when no chapter calibration exists. SQLite must still parse and execute both complete statements, so token adhesion fails the focused test before higher-level chapter setup can hide the cause.
- A repository scan found no other Swift `SQL constant + multiline literal` composition using the same risky pattern outside the two repaired call sites.
- Added Pitfall P-263 so future shared SQL fragments require an explicit separator and real SQLite execution coverage.

Windows evidence:

- `swiftc -frontend -parse` passed for the repaired production file and the focused XCTest source; this is syntax evidence only.
- The exact Core gate passed locally: 99 XCTest plus 15 Swift Testing tests, 114 total with zero failures, and 94.15% `CangJieCore` line coverage against the 90% minimum.
- All explicit Python candidate-set, build-identity, artifact-verification, and App-import contracts passed; `py_compile` and `git diff --check` passed. The platform-dependent symlink case remained the single expected Windows skip.

Apple boundary and next gate:

- The user does not need a local Mac. App compilation, XCTest/XCUITest, and IPA packaging remain remote responsibilities of GitHub Actions on `macos-15`; the authenticated `gh` CLI is the Windows control and artifact-verification surface.
- No IPA workflow may run until Core CI and iPadOS CI both pass for the same exact repair commit. After that, `build-ipa.yml` may be manually triggered, and the paired Candidate Set must be downloaded and verified for commit binding, manifest, SHA-256, signature, entitlements, and fail-closed acceptance before requesting physical-device installation.

### 2026-07-20 CI turnaround correction

The four Apple verification rounds from `86bb9069b9665ecb5a02aa7ae6d7ef267ca570ac` through `df8da6500e6fe50004ee1c3ccf280d855ba60ce0` consumed about 1 hour 35 minutes end to end. The macOS iPadOS jobs themselves accounted for approximately 28 minutes 45 seconds; most remaining time was local diagnosis, repeated broad verification, overlong evidence writing, Agent coordination, and avoidable PowerShell/environment command retries. The implementation changes were small, so codebase size does not justify that turnaround.

Execution correction for the remaining S1 CI loop:

- App-only repairs use the smallest relevant local proof: focused source/test parsing, directly related contracts, complete diff review, secret/generated-artifact checks, and `git diff --check`. Do not rerun the full Core coverage gate when the exact prior commit already passed Core CI and no Core or package source changed.
- Keep the required control-center and pitfall updates evidence-dense and short; status documentation must not dominate repair time.
- Use parallel Agents only for sidecar scanning or review while the critical-path repair and remote CI continue locally. Agent coordination must not delay a ready commit.
- Repair the first evidenced root cause and all occurrences of that same defect class in one slice. Do not speculate across independent governance or UI failures before a new Apple run identifies the next first real error.
- Treat progress summaries as broadcasts rather than pauses. Push the reviewed repair promptly, monitor GitHub Actions through the authenticated `gh` CLI, and stop only at the paired-IPA physical-device gate or a genuine required-input block.
## 2026-07-20 exact Apple CI receipt-fixture evidence

The user does not need a local Mac: App compilation, XCTest/XCUITest, and IPA packaging run on GitHub Actions `macos-15`, with authenticated `gh` as the Windows control and acceptance surface; lack of a local Mac is not a blocker. For exact commit `194b13b08cc5c88e3611e9ff5741cec8839642d1`, Core CI `29724624126` passed and iPadOS CI `29724624129` failed after the SQL regression passed in Apple XCTest; the first real failure was a historical canonical approval-message fixture using a non-canonical approval `ToolReceipt` key, which Runtime restore correctly rejected fail-closed. The minimal repair changes only the fixture to `artifact.openingPlan.approve.<requestID>.<bindingHash>` and does not relax production governance; iPadOS CI is not green, S1 is not complete, and no IPA is ready for device testing.

## 2026-07-20 S1 governed Runtime restore test-boundary repair

This slice remains inside the frozen S1 cockpit direction. It does not re-enable governed Runtime restoration during ordinary startup, start S2, claim Provider/model integration, produce an IPA, or claim device acceptance.

Remote first-error evidence for parent commit `5af41ff969d8c17f5416d06b458662f1d5e0800a`:

- Core CI run `29725933957` passed.
- iPadOS CI run `29725933980` compiled the App and AppTests targets, then failed in `AppViewModelTests.testActiveAndBackgroundPhasesKeepAgentBusinessStatus` at `App/CangJieAppTests/AppViewModelTests.swift:874`. The first real failure compared the restored ordinary S1 status, `对话和草稿已恢复。当前只验证界面、导航和本地保存，尚未接入真正的模型任务`, with the historical Runtime status, `正在和你一起想清楚`.
- The failing suite still depended on the old initializer side effect that automatically created and restored Runtime state, and several assertions mixed user-visible Chinese copy with internal diagnostic codes.

Minimal repair and preserved boundary:

- Ordinary initialization continues with `runtime == nil` and restores only the S1 preview projection.
- `activateGovernedRuntimeProjection()` is an explicit test/internal opt-in for historical Runtime restore and reconciliation coverage; it now requires an active lifecycle and revalidates build activation before creating Runtime or allowing restore side effects.
- App lifecycle activation restores the S1 preview when Runtime has never been activated, but restores Runtime projection when a real interaction already activated it. Direct regression tests cover both the ordinary first-active branch and refusal of explicit activation while inactive.
- User-visible notices and business status are asserted independently from `diagnosticNoticeMessage` and `diagnosticErrorMessage`. Repeated-restore tests retain named instances and explicitly activate each restore, preventing no-op tests from passing accidentally.
- Existing S1 database, Conversation, shelf, progress, Reader, approval, and accepted-chapter test repairs remain in the same worktree slice. `.tmp-appvm-index.txt` was identified as a UTF-16LE temporary line-number index of `AppViewModelTests.swift` (SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`) and was preserved unchanged and untracked.

Focused Windows evidence completed before replacement CI:

- `swiftc -frontend -parse` passed for `AppViewModel.swift` and all seven changed S1/App test files.
- Every `scripts/tests/test-*.py` contract script passed when executed individually; the artifact suite reported 32 tests with one platform-dependent skip.
- `git diff --check`, UTF-8/U+FFFD/mojibake scans, changed-line credential scans, and generated/signing/private-database path scans passed. The secret-pattern hits were only the existing `StubSecretRepository` test type.
- Full Core coverage was not repeated because the parent Core CI is green and this write set changes no `CangJieCore` or Swift package source, following P-264.

Apple XCTest/XCUITest has not yet been rerun for this replacement commit. No IPA exists at this checkpoint.

## 2026-07-20 App conversation display-prefix assertion repair

Remote evidence for commit `31b0342d4cf03b6e84ef0796d160e4e8c9047eef`:

- Core CI run `29736010384` passed the strict Core tests and 90% line-coverage gate.
- iPadOS CI run `29736010383` compiled the App and AppTests and reached simulator execution. Its first real failure was `AppViewModelTests.swift:539` in `testAgentCreationMessageExecutesProjectToolAndClearsComposer`.
- Complete failed-step logs showed exactly three App XCTest failures at lines 539, 758, and 786 before later UI failures. All three shared one cause: the tests asserted bare/localized assistant content or the old English word `approved`, while `conversationMessages` intentionally exposes `AgentMessage.displayText`, including the `仓颉：` speaker prefix and ordinary Chinese projection.

The minimal repair changes only those three expectations: project creation, restored opening-plan confirmation, and the next-message chapter-ready reminder now assert the exact displayed assistant strings including `仓颉：`. Production message generation, persistence, Runtime behavior, and ordinary startup remain unchanged. Later UI failures are not classified or changed in this slice; the next Apple run must first prove these App XCTest corrections and then expose the next real failure, if any. No IPA was triggered because iPadOS CI was not green.

## 2026-07-20 S1 workspace accessibility containment repair

Remote evidence for exact commit `e3c42cc82de388200833dede159980cdfcafb310`:

- Core CI run `29737163457` passed.
- iPadOS CI run `29737163463` compiled the App and completed the App XCTest suite successfully, then failed in the UI suite. The first real UI failure was `CangJieSmokeUITests.testAgentFirstWorkspaceLaunches` at `App/CangJieUITests/CangJieSmokeUITests.swift:14`, where `agent-control-plane-title` did not exist in the accessibility hierarchy.
- The same run later emitted a concrete hierarchy diagnostic while looking for `agent-composer`: instead of the child TextEditor identifier, XCUITest saw one `TextView` whose identifier was `workspace-landscape-columns` and whose value was the draft. This proves the workspace-level identifier was replacing the accessible representation of its descendants rather than indicating an App launch, database, or build-activation failure.

Minimal repair:

- Added `.accessibilityElement(children: .contain)` before the workspace identifier on both landscape roots and the portrait root. The layout, navigation, visibility, hit testing, model lifecycle, persistence, and frozen S1 product direction are unchanged.
- The existing XCUITests already provide the red regression coverage by requiring both the workspace identifier and nested title, composer, navigation, reader, and result controls. No assertion was weakened and no accessibility identifier was removed.
- Added Pitfall P-268 so future container identifiers preserve descendant accessibility before they are used as XCUITest layout markers.

The Apple simulator run remains the authoritative execution proof. This is not an IPA or device-installation stop point: the repair must be committed and pushed, and Core CI plus iPadOS CI must pass for that same exact commit before the paired IPA workflow may be triggered.

## 2026-07-20 S1 nested accessibility containment follow-up

Remote evidence for exact commit `a54c96e556793cd78d75d443756bb6bba2f434de`:

- Core CI run `29741467149` passed.
- iPadOS CI run `29741467153` compiled the App and executed all 197 App XCTest cases with zero failures, then failed in the UI suite.
- The first real UI failure remained `CangJieSmokeUITests.testAgentFirstWorkspaceLaunches` at `App/CangJieUITests/CangJieSmokeUITests.swift:14`, where `agent-control-plane-title` was absent.
- A later hierarchy diagnostic in the same run showed the next collapse boundary: while the test queried `agent-composer`, XCUITest exposed one `TextView` identified as `reader-companion-region` whose value was the saved draft text.

Minimal follow-up repair:

- The root-only containment repair in `a54c96e` was necessary but incomplete: an outer `.accessibilityElement(children: .contain)` does not prevent a nested composite view with its own identifier from replacing that nested view's descendants.
- Added `.accessibilityElement(children: .contain)` at the 21 remaining queryable composite identifier boundaries in `ContentView.swift`, covering independent left pages, landscape and portrait regions, companion panes, overlays, the activity bar, and the shared Reader region.
- Kept all leaf `Text`, `TextEditor`, `Button`, `Toggle`, and `NavigationLink` identifiers unchanged. Existing XCUITests remain the red regression contract and no assertion, product behavior, navigation rule, lifecycle path, or frozen S1 direction was weakened.
- Added Pitfall P-269 to require containment at every nested queryable composite boundary rather than only at the workspace root.

This section records a pending repair, not a passing Apple result. The authoritative proof requires Core CI and iPadOS CI to pass for the same replacement commit. No IPA workflow may be triggered until that exact dual-CI gate passes.

## 2026-07-20 S1 modal accessibility ordering and stale assertion repair

Remote evidence for exact commit `2362c2f899d0efee4f6171a363a862494fe16a82`:

- Core CI run `29744240231` passed.
- iPadOS CI run `29744240317` executed all 197 App XCTest cases with zero failures, then completed 19 main App UI tests with 9 failures.
- The Isolation Probe's 13 unit tests passed, but its single UI smoke test produced two assertion failures at lines 20 and 21; the run therefore did not establish complete UI success, and that probe evidence remains separate from the first failure in the main App UI suite.
- The first real main App UI failure was `CangJieSmokeUITests.swift:319`: while the landscape independent page modal was open, a stale assertion required the covered `welcome-page` to remain in the accessibility tree. That conflicts with the dedicated modal-boundary test and P-259, which require covered workspace regions to leave the accessibility tree.
- Later failures at lines 69, 100, and 936 exposed the production half of the same contract: eight dynamic landscape and portrait regions applied `.accessibilityElement(children: .contain)` after `.accessibilityHidden(...)`, allowing a containment modifier to re-expose regions that should remain hidden.

Minimal repair:

- Changed only five stale assertions inside independent-page flows so they require covered conversation content to be absent while the modal boundary is active; all tests still verify the draft/state before the transition and the restored content after returning.
- Reordered containment ahead of the dynamic hidden modifier on the eight landscape/portrait regions. This was intended to make `.accessibilityHidden(...)` the outer fail-closed gate, but the replacement-run evidence below showed that `.accessibilityIdentifier(...)` still followed it and therefore remained the actual outer modifier.
- No identifier, layout, navigation, persistence path, runtime lifecycle, or frozen S1 product rule changed.
- Added Pitfall P-270 to keep containment subordinate to dynamic accessibility visibility and to prevent state-preservation tests from contradicting modal accessibility tests.

Replacement evidence for exact commit `7f44fef8c1256b91491ec4691da4e8e9119a6f1a`:

- Core CI run `29748810946` passed.
- iPadOS CI run `29748811204` again passed all 197 App XCTest cases, then completed 19 main App UI tests with 7 failures.
- The first real main App UI failure remained `CangJieSmokeUITests.swift:69`: `agent-composer` was still queryable after the landscape independent-page modal opened. This proves the previous ordering was incomplete: SwiftUI's later `.accessibilityIdentifier(...)` still wrapped `.accessibilityHidden(...)`, so the hidden gate was not outermost.
- The Isolation Probe again passed all 13 unit tests and its one UI smoke test still reported the two existing failures at lines 20 and 21; those remain later evidence and are not the current first-error repair target.

The minimal follow-up keeps the same eight modifier chains as `contain -> identifier -> hidden`, placing `.accessibilityHidden(...)` last as the actual outer fail-closed gate, and additionally applies the same dynamic hidden condition directly to the UIKit-backed `TextEditor` because the composer escaped the parent region boundary. No later UI failure is being repaired in this slice. Apple verification remains pending for the next exact replacement commit.

## 2026-07-20 S1 TextEditor accessibility isolation follow-up

The next minimal repair is currently uncommitted in `App/CangJieApp/ContentView.swift`:

- The composer keeps `.focused($isComposerFocused)` and its existing `agent-composer` identifier, disabled state, and modal hidden condition.
- Before the identifier and dynamic hidden gate, it now applies `.accessibilityElement(children: .ignore)` so the UIKit-backed `TextEditor` is exposed as one leaf accessibility element instead of allowing its UIKit descendants to escape the parent modal boundary.
- The eight composite region chains remain `contain -> identifier -> hidden`; no S1 navigation, persistence, conversation-model, lifecycle, authorization, or test assertion contract was weakened.

Deterministic Windows evidence for this uncommitted slice:

- `swiftc -frontend -parse App/CangJieApp/ContentView.swift` passed.
- All seven `scripts/tests/test-*.py` contracts passed.
- Repository tests passed: 32 tests, 0 failures, 1 skipped.
- `git diff --check`, UTF-8/U+FFFD scan for repository text files, secret scan, generated/signing/private path scan passed.
- Protected `.tmp-appvm-index.txt` remains untracked, length `28868`, SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`.

The latest authoritative iPadOS CI run for parent commit `3300f3d9b965927e5b6152aaeb36c418ea37e655` remains failed (`29757615272`). Its first real Main App UI failure is still `CangJieSmokeUITests.swift:69`, where `agent-composer` is queryable after the landscape result drawer opens; the later seven-failure list and the two Isolation Probe UI failures are not being repaired in this slice. Apple verification for the new modifier is pending on the next exact replacement commit, and no IPA workflow may be triggered before same-commit Core and iPadOS CI pass.


## 2026-07-20 S1 TextEditor isolation experiment rejected by visible-state regression

Replacement evidence for exact commit `a46f507a89e701ec34ee6a1d9bed6cc9c4a2abcf`:

- Core CI run `29759167309` passed.
- iPadOS CI run `29759167294` failed after compiling the App and executing 19 main App UI tests with 16 failures; the Isolation Probe still passed its 13 unit tests and retained its two UI failures at lines 20 and 21.
- The first real main App UI failure moved to `CangJieSmokeUITests.swift:16`: the visible launch-state assertion `XCTAssertTrue(app.textViews["agent-composer"].exists)` failed.
- This rejects `.accessibilityElement(children: .ignore)` as a direct `TextEditor` repair: it hid the visible UIKit-backed editor instead of only hiding it across the modal boundary.

The next minimal repair removes `.ignore` and applies `contain -> hidden` to the composer HStack that owns both the `TextEditor` and send button. The child editor keeps its existing identifier, disabled state, focus binding, and draft binding. This targets the nested composite boundary that escaped the landscape/portrait region gate while preserving the visible composer contract.


## 2026-07-20 S1 composer wrapper hiding rejected by UIKit escape

Replacement evidence for exact commit `44f6bfa4f99bc40bbe6fcc264dbd72e0b12c9e84`:

- Core CI run `29760514114` passed.
- iPadOS CI run `29760513963` passed all 197 App XCTest cases, then completed 19 main App UI tests with 7 failures; the Isolation Probe retained 13 passing unit tests and two UI failures at lines 20 and 21.
- The first real main App UI failure remained `CangJieSmokeUITests.swift:69`: `agent-composer` was still queryable after the landscape independent-page modal opened.
- Moving the dynamic hidden gate to a containing composer HStack did not remove the UIKit-backed editor from XCUITest's live query. The next minimal experiment therefore removes only the composer control subtree while the conversation surface is covered, retaining the `AppViewModel` draft and persistent conversation.

## 2026-07-20 S1 covered composer removal exposes the next covered conversation control

Replacement evidence for exact commit `5bdf1419a51c6601ad23a7b87c1b51f5b1520bff`:

- Core CI run `29762005445` passed.
- iPadOS CI run `29762005383` passed all 197 App XCTest cases, then completed 19 main App UI tests with 7 failures; the Isolation Probe retained 13 passing unit tests and its two UI failures at lines 20 and 21.
- Structurally removing the covered composer succeeded: the previous line 69 assertion for `agent-composer` no longer failed.
- The first real main App UI failure advanced to `CangJieSmokeUITests.swift:70`, where the covered `result-drawer-toggle` remained queryable. This proves the defect applies to the whole covered conversation subtree, not only the UIKit editor.

The next minimal repair moves the structural visibility gate from the composer alone to the complete `conversation` view. The `AppViewModel`, selected conversation, draft, messages, and streaming state remain persistent; only the covered SwiftUI control subtree leaves the accessibility/render tree until the independent page or portrait navigation overlay is dismissed. No test assertion or frozen product direction changes.

## 2026-07-20 S1 covered activity-bar sibling repair pending CI

Local replacement slice after exact commit `9dd360492e67805b811daa51bda8532d315ef8d9`:

- The newest iPadOS CI run is `29763517697`; Core run `29763517678` passed, while iPadOS completed 197 App XCTest cases successfully and failed 8 of 19 main App UI tests.
- The first real failure is `CangJieSmokeUITests.swift:71`: after the landscape Novel Projects surface opens, `activity-bar-conversation` remains queryable even though the enclosing `activityBar` has `.accessibilityHidden(selectedActivity != .conversation)`.
- The minimal local repair keeps the original activity-bar implementation in `activityBarContent` and structurally constructs it only when `selectedActivity == .conversation`. This removes the covered activity-bar subtree rather than adding another leaf-specific accessibility assertion or weakening the test.
- Local evidence: `swiftc -frontend -parse App/CangJieApp/ContentView.swift`, all `scripts/tests/test-*.py` contracts, and `git diff --check` passed. The repository `unittest discover -s tests -p 'test_*.py'` currently discovers zero tests; this is recorded as no discovered tests, not as additional coverage evidence.
- The change is not yet accepted remotely. Do not trigger IPA until the exact replacement commit passes both Core and iPadOS CI. The protected `.tmp-appvm-index.txt` remains untracked and must not be staged.

## 2026-07-20 S1 covered conversation-rail sibling repair pending CI

Replacement evidence for exact commit `0f50983bee1eb7296212510324e6832bc75d6367`:

- Core CI run `29765895872` passed.
- iPadOS CI run `29765896742` still completed with UI failures, but the previous first failure at line 71 disappeared; the first real failure advanced to `CangJieSmokeUITests.swift:72`, where `landscape-conversation-rail` remained queryable after the landscape Novel Projects surface opened.
- The minimal local repair applies the same structural construction rule to `conversationRail`: its original body is preserved as `conversationRailContent`, and the public rail is constructed only for `selectedActivity == .conversation`.
- Local evidence for this next slice: Swift parse, all `scripts/tests/test-*.py` contracts, and `git diff --check` passed. Remote acceptance is pending; no IPA workflow is allowed until the exact replacement commit passes both Core and iPadOS CI.

## 2026-07-20 S1 portrait top-bar modal repair pending CI

Replacement evidence for exact commit `fbad49a4ed5016e646aff5414a61794a0ecb40f9`:

- Core CI run `29767253594` passed.
- iPadOS CI run `29767253552` proved the previous line 72 failure was gone; the first real failure advanced to `CangJieSmokeUITests.swift:101`, where `portrait-navigation-open` remained queryable while the portrait navigation modal was open.
- The minimal local repair preserves the original top-bar body as `portraitTopBarContent` and structurally constructs `portraitTopBar` only when the portrait navigation overlay is not presented and the selected activity is conversation.
- Local evidence: Swift parse, all `scripts/tests/test-*.py` contracts, and `git diff --check` passed. Remote acceptance is pending on the exact replacement commit; IPA remains gated on both Core and iPadOS success.

## 2026-07-20 S1 portrait primary-focus region repair pending CI

Local replacement slice after exact commit `ff3218d5a3bf73670d29d07028f4c4cac6d72787`:

- The authoritative iPadOS CI run is `29768294219`; Core CI `29768294192` passed.
- The first real main App UI failure is `CangJieSmokeUITests.swift:935`: `assertPortraitPrimaryFocus(in: app, selected: "conversation")` found `portrait-reader-region` still queryable although conversation was selected.
- The test helper at `CangJieSmokeUITests.swift:1213-1227` requires exactly one of `portrait-reader-region`, `portrait-conversation-region`, and `portrait-results-region` to exist for the selected focus.
- The production cause was confirmed in `ContentView.swift`: all three portrait regions were always constructed and relied on `.opacity`, `.allowsHitTesting`, and `.accessibilityHidden` to represent focus. The same dynamic composite-accessibility failure already observed in the landscape modal path allowed the nonselected reader region to remain in the XCUITest live query.
- The minimal repair structurally constructs only the selected portrait region, and constructs none while the portrait navigation surface is presented. The `AppViewModel`, draft, selected conversation, messages, reader projection, and focus state remain owned by their existing model/state paths; no test assertion or frozen product direction changed.
- Local evidence: `swiftc -frontend -parse App/CangJieApp/ContentView.swift` passed; all seven `scripts/tests/test-*.py` contracts passed; repository tests passed with 32 tests and 1 skipped; `git diff --check` passed. `python -m unittest discover -s tests -p 'test_*.py'` discovered 0 tests and is not counted as coverage evidence.
- This slice is not remotely accepted yet. Do not trigger IPA until the exact replacement commit passes both Core and iPadOS CI. The protected `.tmp-appvm-index.txt` remains untracked and unchanged.

## 2026-07-20 S1 project refresh assertion boundary repair pending CI

Replacement evidence for exact commit `a76c5f24e6b9353362bb728f4abb5771c1f3b237`:

- Core CI `29770397646` passed. iPadOS CI `29770397526` passed the previous portrait focus test; the first remaining main App UI failure advanced to `CangJieSmokeUITests.swift:296` in `testProjectRefreshShowsVisibleAcknowledgement`.
- The failure was not a mutation of `AppViewModel.businessStatus`: `AppViewModel.reloadProjects()` only reloads projects/progress and publishes a project-refresh notice. The test read `agent-business-status` while the independent Novel Projects surface covered the conversation, but the product/modal accessibility contract requires covered center elements to be absent.
- The minimal test repair asserts `agent-business-status` is absent while the shelf is open, taps the existing `novel-projects-back-button`, then waits for the status to reappear and compares its label with the pre-refresh value. No production behavior, status ownership, or test security gate was weakened.
- Other failures in the same run (message label prefix, settings disappearance wait, and portrait TextView lookup) are separate evidence and are not changed in this slice.
- Local and remote acceptance are pending the exact replacement CI run. IPA remains gated on both Core and iPadOS success; `.tmp-appvm-index.txt` remains untracked and unchanged.

## 2026-07-20 S1 batch repair for complete iPadOS failure log pending CI

Evidence from failed iPadOS run `29770397526` was grouped by contract before editing:

- Covered-center failures at the project refresh and portrait rotation assertions were test-boundary errors. The center conversation is structurally absent while the independent Novel Projects page covers it; tests now assert absence and verify restoration after the real back action.
- The two scale-fixture message failures shared one cause. The persisted fixture contains user messages, whose canonical display projection includes the `??` prefix; the UI expectations now match that existing Core contract.
- The timestamp failure retained the immediate-effect contract. The conversation rail list now receives `.id(showsConversationTimestamps)` so its accessibility subtree is rebuilt when the setting changes; the test also waits for the switch value to become `0` before leaving Settings.
- Isolation Probe evidence rows were present in the completed report but the latter two rows were below the visible lazy Form region. The test now performs bounded scrolling and waits for both identifiers; no probe logic or security gate was weakened.

Local evidence after this batch: `swiftc -frontend -parse` passed for all three changed Swift files; all seven `scripts/tests/test-*.py` contracts passed; `python -m unittest discover -s scripts/tests -p 'test-*.py'` passed with 32 tests and 1 skipped; `swift test` passed. The protected `.tmp-appvm-index.txt` remains untracked with the recorded SHA-256 unchanged. Remote acceptance is still pending a new Core and iPadOS Actions result; do not trigger IPA yet.

## 2026-07-21 S1 Toggle interaction repair accepted

Evidence from the complete iPadOS log for run `29774894603`:

- Core CI `29774895084` passed. The iPadOS run completed all other main-app tests and reported one real failure only: `CangJieSmokeUITests.swift:542`, where the timestamp Toggle remained at value `1` after `XCUIElement.tap()` and the subsequent timestamp projection did not change.
- The previous run had already shown the same interaction failing at the next contract assertion (`conversation-time-0` did not disappear), so the new value assertion was not the cause and was not removed.
- The minimal repair changes the two test-side Toggle activations to tap the trailing normalized coordinate of the native switch exposed inside the SwiftUI List row. The `@AppStorage` binding, `.id(showsConversationTimestamps)` rebuild, immediate-effect checks, and relaunch persistence checks remain unchanged.
- Local evidence after the repair: Swift syntax parse passed; seven Python contract scripts passed (including 32 tests with 1 skipped); `swift test` passed with 99 XCTest cases and 15 Swift Testing cases; `git diff --check` passed. The protected `.tmp-appvm-index.txt` remains untracked and unchanged.

Remote acceptance for exact commit `9b8a4086ace915b057a113a215ea3024c2c0e473`:

- Core CI `29779040424` passed its strict test and 90 percent line-coverage gate.
- iPadOS CI `29779040541` passed 197 App XCTest cases, all 19 main App UI tests, 13 Isolation Probe unit tests, and the Isolation Probe UI test. Both simulator test commands reported `TEST SUCCEEDED`.
- The formerly failing `testTasksAndSettingsPreserveConversationAndTimestampSettingReallyApplies` passed in 50.101 seconds, proving the trailing-coordinate activation reached the Toggle and preserved the immediate and relaunched timestamp contracts.

This S1 CI repair is remotely accepted. IPA packaging remains a separate acceptance gate and has not been triggered by this slice.

## 2026-07-21 S1 run-30 candidate operability gate rejected before installation

TrollStore Candidate Set run `29781764682` succeeded for exact commit `44c6a293e138534eb9eab857e3883849b781bece`. The downloaded paired artifact passed the repository metadata verifier and an independent archive/hash audit:

- Artifact `CangJie-paired-device-validation-required-30-1-44c6a293e138534eb9eab857e3883849b781bece`.
- Candidate Set ID `825b66efda45db0d2f8fa271c5a49e12c552a80938155665bf8ff2c00bea3d02`, version `1.0`, build `30001`.
- Main IPA SHA-256 `a058437ce0db4f0814cbf9b144e9cf5a9322d39281bd5655c29a646f95a6e1ca`.
- Probe IPA SHA-256 `4dbd3d308d43b3171a379857379fe9b131a44cf6e67c988fbd6045d098f422a1`.
- Both archived arm64 executables, bundle identities, compiled identities, signed executable hashes, isolated self-only Keychain groups, entitlement files, and fail-closed manifest status matched.

Run 30 is nevertheless not install-ready. Its manifest requires preparing the main-App isolation canary before running the paired Probe, but the S1 refactor left `DeviceDiagnosticsView` without any production navigation reference. Asking for installation would therefore hand the user a candidate that cannot complete its own security acceptance script.

The minimal repair keeps diagnostics absent from the ordinary Agent surface and adds one real `设置 > 高级 > 设备诊断` navigation path to the existing view. A new UI test requires the link to be absent on the ordinary conversation surface, present only after opening Settings, and able to reach the Candidate Set and isolation-canary controls. Run 30 remains preserved as rejected audit evidence and must be superseded by a new dual-CI and paired-IPA candidate before device installation.

First replacement evidence for exact commit `7be2e5009d6c6d0a95fa7e087532f0eca3961b9e`:

- Core CI `29784927714` passed.
- iPadOS CI `29784927718` proved the ordinary-surface absence, Settings link, navigation action, and `device-diagnostics-list` destination all worked. Its only real failure was the new test at line 296 because the lower `isolation-canary-prepare` row had not yet been instantiated by the lazy SwiftUI List.
- The test now verifies the top Candidate Set identity first, performs at most three upward swipes inside the diagnostics List until the canary control is hittable, and still requires that control to be enabled. No production behavior or security assertion is weakened.

Remote acceptance and a replacement paired IPA remain pending.

Replacement acceptance for exact commit `f93d43beb1459f4cf10ec3b7dcf3030d9b48e7fe`:

- Core CI `29786055647` passed. iPadOS CI `29786055674` passed 197 App XCTest cases, all 20 main App UI tests, 13 Probe unit tests, and the Probe UI test. The advanced diagnostics operability test passed in 15.798 seconds with ordinary-surface absence, Settings navigation, bounded canary reveal, and enabled-control assertions intact.
- TrollStore Candidate Set run `29787116654` succeeded and uploaded artifact `CangJie-paired-device-validation-required-31-1-f93d43beb1459f4cf10ec3b7dcf3030d9b48e7fe`.
- Candidate Set ID `46471b8cbd5cf8dec6ff6c3878ca77f9e37127462c13daea29c453869e221e70`, version `1.0`, build `31001`.
- Main IPA SHA-256 `355c05669610cecfeaaf00c8ff4104575af69115da8ba9e191391f80c4507818`.
- Probe IPA SHA-256 `3a6f67395fb68c96b129efdffaa4197d3ca4cf611e03ac9db88dab8463830e15`.
- The downloaded directory passed `scripts/verify-build-artifacts.py --metadata-only` and an independent archive audit: manifest candidate derivation, IPA checksums, arm64 Mach-O payloads, packaged Info.plist identity, compiled Candidate Set markers, signed executable hashes, absence of `embedded.mobileprovision`, and distinct self-only Keychain groups all matched.
- Local verified copy: `F:\project\CangJie\artifacts\CangJie-S1-advanced-diagnostics-run-29787116654-verified`.
- Independent audit receipt: `independent-audit.json`, SHA-256 `551524ab5baa3cef232439ad976a11454f0b4bf504e077b86a981dbe40f5894a`.

This candidate is ready for the exact paired TrollStore device gate. Acceptance correctly remains `blocked-pending-trollstore-device-keychain-isolation-validation` until the user installs both IPAs, verifies single-overwrite activation and matching candidate identity, prepares the main canary through `设置 > 高级 > 设备诊断`, obtains a PASS from the paired Probe, confirms the main canary digest is unchanged, and deletes the canary back to Absent.

## 2026-07-21 S1 device acceptance and S2 explicit-connection admission slice

Physical-device acceptance for exact Run-31 candidate `f93d43beb1459f4cf10ec3b7dcf3030d9b48e7fe` is complete. The user performed one Main overwrite, saw a red fail-closed instruction on the first launch, force-quit and relaunched without a second overwrite or uninstall, and then completed the requested identity, runtime, paired-Probe isolation, unchanged-canary, deletion-to-Absent and S1 cockpit smoke checks without a remaining issue. Because the exact first-launch warning text was not captured, this record does not invent its root cause; a future recurrence must capture the displayed copy and identity state. S1 is accepted and the current stage is S2.

The first S2 implementation slice remains deliberately platform-neutral and does **not** claim a real Provider connection, model discovery, network request, Keychain persistence, App UI, Tool Call, ToolReceipt, H0-H3 completion, IPA or device acceptance:

- Added an explicit connector registry for DeepSeek, Anthropic, OpenAI, Gemini, OpenRouter and a hostless custom connector using the frozen names, official Base URLs and discovery paths.
- `ModelConnection` is immutable and contains only a credential reference bound to the exact connection ID, Provider and allowed host/port, never API-key plaintext. Official connectors reject unrelated hosts; all endpoints reject non-HTTPS URLs, URL userinfo, query strings and fragments before a credential can be associated with them.
- Custom services require an explicitly supplied HTTPS Base URL and permit a manual model only as the documented discovery fallback. Every connection still requires a user-visible name and explicit selected model.
- Codable restore re-runs the same endpoint and intent validation so a tampered persisted connection or pending intent cannot bypass construction-time checks.
- `ModelRequestAdmission` validates and preserves the exact Conversation/project/branch-bound user intent. No current connection yields only `modelConnectionRequired`; it does not create a Provider request, usage, artifact, ToolReceipt or simulated Agent reply. A validated current connection yields preparation carrying the complete immutable connection snapshot, and `resume(_:with:)` preserves the original persisted intent ID, timestamp and bindings after setup with no automatic Provider/key switching.
- Review hardening rejects oversized connection names/model identifiers, control characters and bidirectional display controls; uses an exhaustive Provider registry switch; and rejects coordinated Codable retargeting that changes a Provider and official endpoint while retaining a credential bound to the original connection.

TDD and deterministic evidence:

- RED: focused SwiftPM compilation failed because the connection registry, immutable connection, pending intent and admission types did not exist.
- GREEN: `ModelConnectionContractTests` passed **16/16** tests, including official-host binding, unsafe endpoint rejection, credential host/port retargeting rejection, Codable tamper rejection, bounded display-safe identifiers, branch/project identity, exact pending-intent resume and no-key admission.
- Full `swift test --enable-code-coverage` passed **115 XCTest cases plus 15 Swift Testing cases**, with zero failures.
- Overall Core line coverage is **4,999/5,127 = 97.50%**; `ModelConnectionContract.swift` line coverage is **260/268 = 97.01%**, with 26/26 functions covered.
- `git diff --check`, changed-file UTF-8/BOM/U+FFFD/CRLF/trailing-whitespace scans and focused secret scans passed. The protected `.tmp-appvm-index.txt` remains unchanged and untracked at 28,868 bytes with SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`.

The next S2 slice is App-side durable storage for named connection metadata and pending intent, with the actual secret mapped into a Keychain item that repeats and verifies the same connection/Provider/host binding. It must remain transactionally separate from Provider send, model usage and ToolReceipt creation. The later custom-endpoint network adapter must resolve and validate every destination address and reject unsafe redirects/private or link-local retargeting before any credential is attached; Core URL syntax validation alone is not SSRF proof.

## 2026-07-21 S2 App-side model-connection persistence hardening

The App persistence slice now has a reviewed local implementation, but it still does **not** claim Keychain storage, credential availability, Provider usability, connection testing, model discovery, network send, App UI, ToolReceipt, H0-H3 completion, IPA or device acceptance.

- Migration `s2-model-connection-v1` adds `modelConnection`, singleton `modelConnectionState`, and `pendingModelIntent`. SQLite stores immutable connection metadata, the Keychain credential reference/binding, explicit current selection and the exact Conversation/project/branch-bound pending intent; it never stores API-key plaintext.
- Connection/current-selection/pending-intent writes are transactional. Conversation, project and current-connection deletion are retained by foreign keys with `ON DELETE RESTRICT`. Exact replay is idempotent; changed connection or intent payloads and credential-ID reuse fail closed.
- A connection-save replay no longer reapplies `makeCurrent`. This prevents a delayed replay of connection A from silently overriding the user's later explicit selection of connection B; a new selection must use the dedicated selection operation.
- Both connection and pending-intent rows now persist a SHA-256 of the exact versioned JSON bytes in addition to identity metadata. Restore verifies the hash before decoding and then cross-checks the duplicated IDs, scope and credential Provider/host/port. This closes valid-but-altered selected-model, custom Base-URL-path and pending-user-request payload changes. The hash is a corruption/tamper check inside the SQLite record, not a substitute for the next Keychain binding verification.
- JSON Date coding and SQLite mirror timestamps both use Unix seconds. The fractional-timestamp regression keeps exact equality without weakening business identity to a broad tolerance.
- `currentModelConnection()` deliberately returns only the explicitly selected metadata record. It does not claim that the referenced Keychain item exists, that its binding matches, or that the Provider is usable; no database method prepares or resumes a Provider request from SQLite metadata alone.

Focused tests now contain 14 App integration cases covering restart recovery, no plaintext credential columns, exact replay/conflict behavior, late-replay selection preservation, credential reuse, Provider/host retargeting, selected-model and custom-path payload alteration, fractional timestamps, pending-intent request/scope alteration, explicit current selection and delete restrictions. Local Swift syntax parsing, Core `swift test --enable-code-coverage` (115 XCTest + 15 Swift Testing), all seven Python contract scripts (32 tests, 1 skipped), migration SQL/foreign-key checks and `git diff --check` pass. Full App XCTest and iPadOS semantic compilation remain pending the next remote CI run.

The protected `.tmp-appvm-index.txt` was identified as a 2026-07-20 UTF-16LE line-number/search index derived from `App/CangJieAppTests/AppViewModelTests.swift`; it is not a product source or build input. It remains untracked and unchanged at 28,868 bytes, SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`.

## 2026-07-21 S2 SQLite remote acceptance and Keychain binding slice

Remote acceptance for exact SQLite/pending-intent commit `f91e9d7250760c0c3ba573b82735801768ec830d` is complete:

- Core CI `29810765822` passed.
- iPadOS CI `29810765816` passed semantic compilation and all simulator gates: 211 App XCTest cases, all 20 main App UI tests, 13 Isolation Probe unit tests and the Probe UI test. `ModelConnectionPersistenceTests` passed 14/14, including the late-replay selection and complete payload-hash regressions. Both simulator test commands reported `TEST SUCCEEDED`.

The next local Keychain slice is implemented and reviewed but still awaits its own remote App XCTest result. It does **not** yet claim connection setup orchestration, Provider connectivity, model discovery, network requests, App UI, ToolReceipt, H0-H3 completion, IPA or device acceptance.

- `KeychainModelCredentialRepository` stores no credential in SQLite or logs. The Keychain credential payload repeats credential ID, connection ID, Provider and allowed host/port together with the secret. A separate Keychain verification marker repeats the same binding and stores the exact credential-payload SHA-256.
- Save/resolve/delete are serialized by one process-wide lock. Saving first writes and verifies a `revoked` marker, then writes and exactly reads back the credential payload, and only then writes an `active` marker. A failed or altered payload therefore remains inactive even if its Keychain item exists.
- Resolve returns a credential only when the marker is `active`, both marker and payload match the requested binding, and the marker hash matches the exact payload bytes. A missing, malformed, cross-bound, revoked or hash-mismatched item fails closed without Provider preparation.
- Delete first writes and verifies a `revoked` marker, then removes and verifies the credential payload, and finally removes the marker. If either cleanup delete fails, the remaining marker is revoked and resolution still returns no credential; retry can finish orphan cleanup without reactivating it.
- New secrets must be nonblank, at most 4,096 UTF-8 bytes and free of control or bidirectional display characters. Re-entering a key for the same exact binding is allowed; a different connection/Provider/host/port cannot overwrite or delete the item even if it reuses the credential ID.
- Eleven focused tests cover exact save/update/resolve, all input boundaries, cross-binding overwrite/delete rejection, malformed and altered payloads, write-read verification, revoked failure states, payload and marker cleanup failures, and a production `KeychainSecretRepository` round trip intended for the signed iPad Simulator test host.

Local evidence: both new Swift files pass syntax parsing; the production repository and tests pass Swift semantic type-checking against minimal local stubs for unavailable Apple/XCTest modules; `git diff --check`, UTF-8/trailing-whitespace scans and focused secret/SQLite/log coupling scans pass. The signed production-Keychain test can only be accepted by the iPadOS CI test host, consistent with P-079. `.tmp-appvm-index.txt` remains untouched with the recorded size and hash.

## 2026-07-21 S2 Keychain remote acceptance and setup-orchestration hardening

Remote acceptance for exact Keychain commit `8c8e3e09bd555f2211ca40502e1a16f1b46580dc` is complete:

- Core CI `29814395127` passed.
- iPadOS CI `29814395026` passed 222 App XCTest cases, all 20 main App UI tests, 13 Isolation Probe unit tests and the Probe UI test. `ModelCredentialRepositoryTests` passed 11/11, including the signed production `KeychainSecretRepository` round trip. Both simulator test commands reported `TEST SUCCEEDED`.

The next setup-orchestration slice is implemented locally and remains pending its own App XCTest run. It still does **not** claim Provider connectivity, model discovery, network send, setup UI, ToolReceipt, H0-H3 completion, IPA or device acceptance.

- `ModelConnectionSetupService` keeps connection creation inside one process-wide credential coordinator shared with direct Keychain repository operations. The coordinator spans prior-credential capture, Keychain save/read-back, SQLite metadata/current-selection commit and any compensation, preventing another process-local save/delete from interleaving with rollback.
- Credential save itself is inside the compensation boundary. A write that mutates Keychain and then throws restores the exact previous active credential; a new credential is deleted when metadata cannot commit. Failure to prove compensation returns `credentialCompensationFailed` instead of claiming a clean rollback.
- Metadata and current selection are committed only after the exact bound credential is read back. A credential-ID collision is rejected before Keychain mutation.
- An immutable connection-save replay first verifies that the currently active credential is exactly the replayed credential, then returns the historical metadata without rewriting Keychain or reapplying `makeCurrent`. A differing active key returns `credentialReplayConflict`; credential replacement must be a separate versioned operation rather than an old create request masquerading as a retry.
- Twelve focused setup tests cover credential-before-metadata ordering, pre-write and post-mutation save failure, read-back failure, credential-ID collision without Keychain mutation, database-failure restoration/deletion, current-selection replay, stale-key replay rejection, shared-coordinator exclusion and explicit compensation failure.

Local verification: all changed production and test Swift files pass syntax parsing; production plus both credential/setup test files pass semantic type-checking against the established minimal Core/CryptoKit/XCTest/AppDatabase stubs without diagnostics; a temporary executable harness passes post-mutation save rollback and stale-key replay scenarios. The independent read-only review's two P1 findings and one P2 finding are addressed by the shared coordinator, enlarged compensation boundary and immutable replay check. Apple/GRDB execution remains authoritative and is pending the replacement CI commit. `.tmp-appvm-index.txt` remains untracked and unchanged at 28,868 bytes with SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`.

## 2026-07-22 S2 model discovery, credential generation and recovery hardening

This is a reviewed local implementation slice inside **S2 真正可操作软件的 Agent**. It does **not** claim a shipping Provider setup UI, a successful real Provider request, central Typed Tool execution, ToolReceipt, H0-H3 completion, formal prose generation, an IPA candidate or physical-device acceptance.

- Core now models bounded Provider catalog discovery as typed request plans bound to one discovery ID, connection ID, Provider, Base URL, credential generation ID and independent opaque 64-hex proof. Model selection remains explicit. OpenRouter must pass its authenticated `/key` probe before its public catalog can create a connection; raw Custom catalog/manual selections cannot cross the public connection factory.
- App discovery uses an ephemeral no-cookie/no-cache transport, rejects redirects, enforces per-response, total-byte, page and monotonic deadline budgets, and validates complete response request identity. Custom destinations must resolve only to accepted public addresses; reserved IPv4/IPv6 ranges including `2001::/23` are rejected. Ordinary pinned `/models` responses do not prove a credential. Only a distinct per-attempt transport authentication result bound to the exact request identity, credential binding, URL and pinned address set can mint the opaque Custom selection capability.
- The shipping `URLSessionModelDiscoveryTransport` deliberately provides neither Custom address pinning nor Custom authentication and therefore remains fail closed. The verified Custom success path is an adapter contract and test seam for a future transport, not a claim that Custom connections work in the current App.
- Keychain v2 credential payloads and verification markers bind the exact credential generation ID, opaque proof and optional non-secret `setupAuthorizationHash`. Legacy v1 upgrade uses an explicit `migrationPending` state, revokes and verifies the v1 marker before activating v2, distinguishes deletion tombstones from resumable migration, and keeps retry/non-resurrection behavior fail closed across every persisted boundary. Neither the API key nor a secret-derived verifier is written to SQLite.
- The published `s2-model-connection-v1` migration remains byte-for-byte unchanged. A new `s2-model-connection-credential-version-v2` migration validates the legacy payload/hash/mirrors through the real historical migrator chain, assigns the stable legacy generation, rewrites the versioned payload, and backfills its mirror. The setup journal records the complete candidate intent; startup may finish metadata/current selection only when Keychain carries the exact same setup authorization hash. A DB-only rewrite of selected model, Custom path, `makeCurrent` or timestamp cannot authorize recovery.
- `AppViewModel` runs setup reconciliation before projecting the ordinary workspace but preserves local conversations, drafts, projects and composer state when recovery remains pending. Ambiguous active credentials and journals are retained for explicit recovery instead of being silently deleted or committed.
- Production Core SPI imports are recursively checked for every non-test source root declared by `project.yml`, including roots outside `App/`. Missing or repository-escaping production roots, split-line `@testable` imports, unexpected SPI names/importers and malformed privileged imports fail the contract. The gate runs in Core CI, iPadOS CI and IPA build workflows.
- New discovery, credential and journal files/tests were split below the 800 physical-line ceiling. The historical migration tests now execute the real migrator through `s2-model-connection-v1` instead of forging `grdb_migrations` or a reduced schema.

Deterministic local evidence after the final fixes:

- All **35** changed Swift files pass `swiftc -frontend -parse`.
- All **8** repository Python contract scripts pass. The SPI contract passes **12/12** cases; build-artifact verification passes **32** cases with one expected Windows platform skip.
- The pinned Swift 6.3.3 strict Core gate passes **139 XCTest cases plus 15 Swift Testing cases**, with strict concurrency and warnings-as-errors enabled. Core line coverage is **94.58%**, above the 90% gate.
- Focused production and App-test semantic type-checks pass for discovery, credential migration, setup journal/reconciliation and their test support. Full GRDB/Keychain App XCTest and iPadOS simulator execution remain authoritative and pending the exact remote CI commit.
- Final independent code, security and test reviews report no remaining P0-P2 findings. `git diff --check`, token/private-key scans, production logging scans, migration-identity checks and sensitive-artifact scans pass.
- `.tmp-appvm-index.txt` remains untracked and unchanged at 28,868 bytes with SHA-256 `4682EEB10DC361950FB0FDE60A8BFF3D16A801542412AAAA5FDA981392011DE8`. `default.profraw` also remains untracked and unchanged at 89,408 bytes with SHA-256 `4D67D60C3A3E36C95EC24625AD4AE89BE663CB36EE5ECF5AD2F36BBBEEA3F74E`; neither is a commit candidate.

The next gate is remote Core and iPadOS CI for the exact commit. Only after both pass may an IPA workflow be considered. Even then, this slice alone does not complete S2: the real Provider setup surface, authenticated production transport, central Agent request/tool loop and ToolReceipt recovery remain outstanding.

## 2026-07-22 SPI scanner canonical-path CI repair pending remote

Exact commit `1944efd7564015a2ffbfbc8264ce518eb87a1f0b` failed before Swift/Xcode execution in both Core CI `29882716106` and iPadOS CI `29882716077`. The complete logs share one first real error: fixture source paths were resolved to canonical filesystem paths, while `Path.relative_to` used the uncanonical temporary-directory spelling. GitHub-hosted Windows exposed `RUNNER~1` versus `runneradmin`; macOS exposed `/var` versus `/private/var`. Eight SPI fixture cases therefore raised `ValueError` even though the policy assertions were not reached.

The scanner now relativizes against `repository_root.resolve()` everywhere. The primary production-target fixture deliberately passes a lexical `alias/..` repository path so the test exercises canonical-root handling on every platform. The script remains below the file ceiling at 797 physical lines, passes 12/12 locally, and `git diff --check` passes. No Swift, credential, migration, product or authorization behavior changed. Replacement Core/iPadOS CI is required before this repair is accepted; IPA remains blocked.

## 2026-07-22 Darwin socket constant compile repair pending remote

Exact canonical-path repair commit `7f5724751c7853b045ef2b8ca97e5898858f327a` passed Core CI `29883112740`, but iPadOS CI `29883112652` failed during App compilation before any simulator test ran. The first real error is `ModelDiscoveryDestinationPolicy.swift:89:47: value of type 'Int32' has no member 'rawValue'` at `Int32(SOCK_STREAM.rawValue)`.

The failing branch is already isolated by `#if canImport(Darwin)`. On the Apple SDK used by Xcode 16.4, `SOCK_STREAM` is imported as `Int32`, so applying the Linux-oriented `.rawValue` conversion is invalid. The minimal repair assigns `SOCK_STREAM` directly to `addrinfo.ai_socktype`. This does not change destination classification, address resolution, credential attachment, Custom fail-closed behavior or any product contract. The focused Swift parse, all eight repository Python contract scripts, SPI 12/12 cases, build-artifact 32-case suite with one expected Windows skip, `git diff --check` and protected-file hash checks pass locally. Replacement exact-SHA Core/iPadOS CI is still required before acceptance; IPA remains blocked.

## 2026-07-22 Apple App XCTest fixture and cancellation-observation repair pending remote

Exact Darwin compile-repair commit `47f9e6fcb81f5f5c5e7e4c4505002ee09043d5a7` passed Core CI `29884171521`. iPadOS CI `29884171560` also passed the previous socket compile point and ran the complete main suites, but finished with three App XCTest failures out of 304 tests; all 20 main App UI tests passed. The complete log identifies two root-cause classes: `ModelConnectionSetupJournalTests.testStartupReconciliationRejectsRehashedModelAndBaseURLPathTamper` used a shared Custom setup fixture that still supplied an unverified raw catalog selection, while the two request-deadline tests observed cancellation only through `catch is CancellationError` and therefore did not record the cancelled task state on Apple.

The local repair is test-only. The shared setup fixture now uses the existing transport-SPI `CredentialProvenCustomModelSelection` seam when it deliberately creates a valid Custom candidate, so the journal test reaches its intended rehashed model/path tamper assertions without weakening the production provenance gate. Both hanging test transports record `Task.isCancelled` in their task-exit `defer`, preserving the original absolute deadline, immediate fail-closed result and zero catalog-send assertions without depending on one platform's concrete sleep error. All three changed Swift test files parse, all eight repository Python contract scripts pass, SPI remains 12/12, the build-artifact suite remains 32 cases with one expected Windows skip, and `git diff --check` passes. Replacement exact-SHA Core/iPadOS CI is required; IPA remains blocked.
