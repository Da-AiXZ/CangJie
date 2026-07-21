# 仓颉（CangJie）网络小说 AI Agent 权威实施方案

- 状态：`ACTIVE AND AUTHORITATIVE`
- 新基线：2026-07-18
- 仓库：`F:\project\CangJie`
- 产品口号：**你只管有念头，仓颉负责把它写成小说。**
- 本文取代 2026-07-16 版本中所有“专业写作工作台优先”“固定表单访谈”“用户先解释专业原因”的产品解释。
- 旧版中已经验证的运行时治理、持久化、版本、审批、恢复、安全和 CI 能力继续保留，但降到后台，不再决定普通用户的默认体验。
- Agent Harness 工程基线：`docs/AGENT_HARNESS_ARCHITECTURE.md`。该文档定义 Context、Prompt、Loop、Typed Tools、任务恢复、多 Agent、治理和可观测性的宿主级边界。
- 架构来源登记：`docs/ARCHITECTURE_SOURCE_REGISTER.md`；实现只依据官方公开来源、仓颉原创需求和独立 ADR。
- 状态边界：**工程架构基线已建立，具体 Swift 接口随 TDD 细化；H0–H5 未验收前不得写成已实现。**

---

## 1. 产品定义

### 1.1 一句话定位

仓颉是一款给**不会写小说、不会说写作术语、但有阅读品味或故事念头的普通人**使用的网络小说创作 Agent。

用户可以只给出一句话、一个画面、一种情绪、一段吐槽，甚至只说“我想写一本书，但不知道写什么”。仓颉负责主动理解、连续追问、提供灵感、试写验证、整理决定，并通过真实工具完成建书、保存设定、规划、写作、修改、检查、暂停、恢复、查询和导出。

### 1.2 第一核心用户

默认体验首先服务以下人群：

- 爱看网络小说，但没有写作经验；
- 脑中有片段、画面、设定或情绪，却无法完整表达；
- 知道“喜欢/不喜欢”，但说不出“人物弧、叙事视角、爽点密度、信息顺序”等专业原因；
- 不愿先学习复杂软件，也不愿填写密密麻麻的创作表格；
- 有时有灵感，有时完全没有灵感，希望 AI 能给出贴合个人口味的建议；
- 希望 AI 主动推进，而不是每一步都等用户找到正确按钮。

职业作者和高级用户可以打开详情、版本、设定、任务和模型连接，但他们不是默认界面的设计中心。

### 1.3 用户真正购买的结果

用户购买的不是“更多生成按钮”，而是以下结果：

1. **把说不清的念头挖成一个可持续的故事。**
2. **只在一个对话窗口里，就能指挥整套小说工程。**
3. **像普通读者一样表达感觉，也能让 AI 准确修改。**
4. **不用理解后台术语，仍然得到生产级长篇一致性。**
5. **中断、断网、崩溃和切后台后，不丢稿、不重复扣费。**

### 1.4 首版边界

- 简体中文优先；
- 个人使用优先；
- 男频升级成长类网络小说为首轮深度优化题材；
- 支持 100–200 万字长篇所需的数据和治理结构；
- iPadOS 16.6+、11 英寸 iPad Pro 优先；
- SwiftUI 原生 App + 独立 `CangJieCore`；
- GitHub Actions 构建无 Apple 开发证书的 TrollStore 可安装 IPA；
- 不以自动登录小说平台、自动发布、第三方代码插件、多端同步作为首版阻塞项。

---

## 2. 不可动摇的产品原则

### 2.1 Agent 是前台主体，工作台是后台能力

打开 App 后首先看到仓颉，而不是创建项目表单、设定字段、小说术语或功能仪表盘。

```text
用户说人话
→ 仓颉理解当前意图
→ 仓颉决定下一步最有价值的问题或动作
→ 需要操作软件时调用真实 Typed Tool
→ App 验证权限、范围、预算、版本和幂等性
→ 结果回到对话，并以大白话说明
```

所有专业工作台仍然存在，但属于“需要时查看”和“高级用户手动接管”，不能成为完成主流程的必经入口。

### 2.2 普通用户不负责专业诊断

用户可以只说：

- “不对味”；
- “这个人说话不像他”；
- “前面挺好，后面我不喜欢”；
- “我不知道为什么，就是没感觉”；
- “保留这几句，其他重来”；
- “这个方向不要”。

仓颉必须根据选区、上下文、历史偏好和对话，通过反映式总结、对比选择、具体画面、微型试写等方式，把模糊感觉转成可执行规则。禁止先要求用户填写专业原因。

### 2.3 “不知道”是信息，不是失败

用户回答“不知道”“说不上来”“都可以”时，Agent 不得机械进入下一道固定问题，也不得重复换一种措辞再问同一件事。它应在以下方式中选择信息增益最高的一种：

- 给出两个或三个明显不同的具体选项；
- 描述两个短场景让用户选更接近的；
- 先写 100–300 字微型试片；
- 从用户喜欢或讨厌的作品体验反推；
- 缩小到人物、氛围、冲突或结局中的一个维度；
- 暂时标记为未决定，先推进可逆部分。

### 2.4 动态意图循环：理解一点，做一点，再继续理解

仓颉不是用固定问卷把用户审问完再开始创作，而是持续运行一个可见、可撤销的动态循环：

```text
理解一点
→ 做一点
→ 让用户看见
→ 根据用户反应再继续理解
```

- 一次只问一个真正会改变下一步创作决定、而且普通用户容易回答的主问题；
- 通常在约 2–4 个高价值问题后给出一个具体画面、微型试写或差异明显的候选，让用户通过“看到东西”继续表达；2–4 只是节奏指导，禁止写成硬编码题数；
- 用户说“不知道”时，优先使用具体画面、对比、用户阅读经历、反向排除，或由仓颉做一个明确标注且可撤销的临时决定；
- 内部必须分开记录“用户原话 / 用户已确认 / AI 推测 / 关键未知”，AI 推测不得静默升级成用户决定或已确定设定；
- 达到可行动阈值、继续追问的信息收益已经很低、用户表现疲劳或明确要求直接做、当前决定低风险且可撤销时，立即停止追问并产出可看的下一步。

### 2.5 默认自主模式：关键事情问我

仓颉默认使用**“关键事情问我”**：不把用户拖进权限表单；普通、可逆且不改变整书方向的决定直接做并告知，重大创作变化则先检查用户是否已经按类别和范围授权。

- **安全、可逆的日常操作直接执行**：创建项目、保存念头、整理尚未确认的资料、查询状态和费用、运行检查、保存 checkpoint、暂停或恢复任务、生成未提交草稿。执行后用一句人话说明结果，不再反问“是否确认”。
- **正文和重要创作方向先展示结果，再由用户确认**：完整章节、用户已经看过的正文修改、作品核心方向、重要人物与世界规则、从旧章建立的新分支，都必须让用户看到真正关心的内容和影响，再选择“就按这个来 / 再试一个 / 先别改”。
- **重大创作变化使用分级授权**：主角核心目标改变，重要人物死亡、永久背叛、彻底黑化或核心关系根本改变，世界/能力硬规则改写，主线、结局承诺或当前卷换轨，以及会让大量已确认内容失去依据的决定，只有在有效授权覆盖相应类别和小说/卷/章节范围时才可由仓颉代决策；未覆盖时必须在安全 checkpoint 前暂停。

设置中可以提供“少打扰我 / 关键事情问我 / 每一步都让我确认”，但普通用户默认不需要理解风险等级。创作授权和自主模式都不能绕过费用硬上限、任务完整性、权限与安全边界、版本/幂等/checkpoint、外部数据披露授权和不可逆删除保护。

前三章属于校准期，必须逐章展示并明确确认。章节结果以正文阅读器和仓颉对话中的轻量“就按这版继续 / 和仓颉聊聊”为主，并接受“可以 / 继续下一章 / 按这个感觉往下写”等明确自然语言批准；“还行 / 差不多”等含糊肯定只允许追问一次是继续校准还是按此继续，不能擅自冻结。第三章通过只获得连续创作申请资格，不自动开始；仓颉说明连续创作、费用和重大事件暂停机制后，只申请一次授权。获得授权后最多领先生成 5 章工作内容，不再机械逐章询问。“写完这一章暂停”和“现在暂停”必须分别走对应的真实动作：前者在安全 checkpoint 后停止，后者立即取消当前请求并保留最近完整 checkpoint；两者都不应再弹一次确认。
### 2.6 每次“已完成”都必须有真实证据

模型说“我已经创建”“我已经暂停”不算完成。创建项目、保存设定、生成章节、暂停任务、恢复任务、确认版本和导出文件都必须由真实工具执行，并产生可核验回执。普通用户默认只看到人话结果；技术详情可展开查看。

### 2.7 选区只是讨论焦点和修改起点

正文反馈的默认路径不是让用户先做“喜欢 / 不喜欢”的专业分类，而是：

```text
自由选中文字
→ 问仓颉
→ 自动带章节、版本、精确选区和前后文
→ 能直接理解则给修改影响范围预览
→ 不清楚才动态追问
```

第一层菜单固定优先为：

```text
复制 | 问仓颉 | 更多
```

选区本身只表示“现在讨论这里”以及“从这里开始分析修改”，不能自动创建喜欢、不喜欢、问题或锁定，也不能替用户推断喜欢原因。“更多”提供互不混淆的软反馈：

- **这段我喜欢**：保存正向偏好证据，但不逐字锁死；
- **这个感觉别丢**：保留氛围、作用或阅读效果，具体原因可由仓颉提出可纠正推测；
- **只讨论这段**：限制当前沟通焦点，不隐藏真实修改依赖，也不把选区变成最终修改边界；
- **标记为问题**：保存待诊断的负向证据，原因可以为空；
- **锁定文字不变**：极少使用的精确硬保护。

只有用户明确点击“锁定文字不变”，或明确说“这句一个字都不要动”等无歧义命令，才建立绑定章节版本和精确字节范围的硬锁定。普通选区、喜欢和“感觉别丢”都不能静默升级为硬锁定。仓颉可以推测“你可能喜欢的是这种克制感”，但必须标记为可纠正推测，允许用户否定和改写，不能冒充已确认偏好。用户只说“这里不对”或“我说不清”也必须能继续；能理解时不要多问，只有存在多种合理解释时才追问。

### 2.8 对话先持久化，到需要时再建立小说

- 所有对话从第一句话起自动持久化，但不能每聊一句就创建一本空书；
- 当用户明确说继续、创建或开始做，产生首个值得长期保存的正式成果，需要人物/设定/章节/故事记忆，或要求开始正文时，仓颉直接调用 Typed Tool 建立小说并用大白话告知，不展示创建表单；
- 一本小说可以关联多次对话；一次对话同一时刻只能有一个主要小说上下文；
- 浏览书架、打开书籍详情或只阅读另一本书都不能偷偷切换当前创作上下文；只有点击“继续创作”、从该书正文“问仓颉”、继续该书历史对话或明确要求切换时才绑定，并由仓颉用大白话提示当前切到了哪本书；
- 当前对话明显出现另一本书的念头时，仓颉先建议单独保存，未经确认不得写进当前小说；
- 普通用户只看到“这段对话已经保存”“我已经为这个故事建好小说”等人话，不看到“临时项目、对象、实体绑定”等内部词。

### 2.9 “这次结果”只收集真实产物

“这次结果”不是聊天记录、技术日志或每条模型消息的卡片化副本。只有当前对话产生的、能够被阅读、采用、修改、继续执行或长期保存的真实产物才能进入，例如故事念头、候选方向、试写、人物成果、章节正文、修改影响范围预览与局部结果、研究结论、任务结果和重要分歧。普通追问和闲聊不生成结果卡片。

- 前台只使用少量稳定的大白话状态：`供你看看 / 等你决定 / 已经放进小说 / 刚刚修改 / 正在进行 / 已经暂停 / 已被新版本替代`；
- 普通路径不得暴露 `Artifact`、`CanonFact`、`Revision Hash`、`Tool Receipt` 等内部名词；
- 用户可以直接在对话里说“采用刚才那个”“打开第二个”“把这个移除”“总结一下这次结果”，不需要手工搬运；
- 只有重要方向、正文和大修改显示最少量操作，例如“就按这个做 / 再聊聊”；
- 采用后由 Typed Tool 自动写入章节、故事记忆、资料、AI 任务或创作记录中的正确位置，并保留来源、版本和当前对话关联；结果写入后仍可追溯，不得凭空消失。

### 2.10 故事记忆由仓颉维护，用户只需查看和纠正

故事记忆不是新建小说时要求用户填写的设定表。仓颉应从对话、已采用结果、已通过正文、用户改稿、研究资料和章节结算中自动提取、核对、版本化并更新，普通用户只需通过左侧入口查看，或用人话说“这条不对”“他现在还不知道”“把这个规矩改掉”。

- 前台只分为“这本书现在讲什么 / 主要人物 / 世界规矩 / 现在写到哪里 / 后面不能忘的事 / 还没有决定”；
- 故事记忆条目状态只显示“已经确定 / 暂时这样写 / 还没决定 / 已被新内容替代”；
- 人物知识用“现在知道 / 还不知道 / 错误地以为”表达；
- “后面不能忘的事”覆盖线索、用户期待画面、人物承诺、读者承诺、当前卷目标和待回归人物，不得退化成单一伏笔列表；
- 每条重要记忆可查看大白话来源；AI 推测必须明确未确认，不得静默升级；
- 安全、局部且不冲突的小改动可以直接执行并告知；与已通过正文或大量后续冲突时，先给影响说明和受治理修改方案，再由用户决定是否建立新版本或分支；
- 后台 `CanonFact / TruthScope / CharacterKnowledge / PromiseLedger / 版本证据` 完整保留，但默认不暴露。

### 2.11 研究默认由仓颉主动判断，而不是用户操作搜索框

仓颉在立项、章节规划、正文生成前和审校阶段运行独立知识缺口判断。用户主动要求研究只是额外入口；不能等用户知道要查什么，也不能每遇到一个名词就盲目搜索。

```text
本书故事记忆
→ 内置 / 本地题材知识包
→ 有效缓存研究
→ 必要时自动联网
→ 来源质量与冲突检查
→ 仍不能确认则诚实说明
```

触发依据至少包含内容类型、当前覆盖、写错影响、时效性、来源可靠度、冲突和题材污染风险，不能只依赖 LLM 自报置信度。题材知识包必须区分公开事实、网文约定、不同流派、冲突说法和本书已选择规则；知识包和外部资料都不是本书已确定事实。用户关闭联网、限定本地资料或设置研究预算后，所有 Agent 必须遵守。

### 2.12 探索小样和完整第一章使用不同门槛

探索期可随时生成 100–300 字画面、微型试写、候选开场、能力代价和章节结尾候选，无需先完成完整策划。完整第一章前，普通界面只展示一张大白话“我准备这样写”，概括故事感觉、主角处境、本章事件、结尾所得、明确避免和尚未定死内容，不展示制作圣经、`CreativeContract` 或逐字段表单。

点击“就这样开始”，或在对话中说“开始写第一章”“你替我决定”“直接写”等语义明确指令，都构成启动授权。未定内容保留为可撤销临时假设。后台总编剧仍形成生产级开篇基础并运行计划、研究覆盖、写作、人物知识、连续性、题材纯度、AI 味、有限修正和 checkpoint 流水线。生成后的第一章只处于“供你看看”，用户通过后才冻结正文并结算人物、世界、线索和下一章。

### 2.13 正文校准由 Agent 主导，手动编辑不是默认流程

普通用户和熟练作者都默认通过“选中或引用内容 → 用大白话告诉仓颉 → 仓颉必要时追问 → 展示影响 → Agent 执行修改”完成校准。产品不能因为提供编辑器就把逐字改稿变成主流程，也不能因为用户没有手改而阻塞章节审批或后续创作。

手动编辑只作为可发现但不打扰的高级/兜底能力。进入一次手动编辑会话后，系统自动保存新的 `ManualEditVersion`，旧 AI 稿和此前版本继续保留；人工文字是当前分析、上下文编译和后续生成的最高优先级依据，但不自动等于“章节已经通过”。编辑期间不逐字弹影响确认；在离开编辑、请求 Agent 修改、继续生成、审批章节或启动后续任务前，统一运行一次延迟影响分析。

### 2.14 用户偏好代理 / 影子用户是可审阅的证据系统，不是数字分身

仓颉可以逐渐更懂用户，但对外只称“用户偏好代理”或“影子用户”，不得承诺蒸馏出一个完全像用户的人格复制、数字分身或永远正确的替身。内部可拆为 `UserPreferenceProxy`（管理跨项目、本书和临时意图的证据画像）与 `BookReaderProxy`（以普通读者视角盲读计划、候选和章节），二者都只是辅助判断组件。

首版采用非参数化、基于证据的路线：本地偏好记忆、检索、上下文编译、候选比较、影子用户预审、真实反馈校准和主动弃权。首版不训练、微调或蒸馏用户专属模型权重，不做 LoRA，也不会因为上传小说而改变 Provider 模型参数。未来只有在独立留出集和真实用户抽样中证明稳定优于非参数化基线后，才评估轻量排序器或偏好模型；论文实验数字只能提供方法参考，不能成为产品承诺。

偏好必须严格分成三层，禁止互相污染：

1. **长期跨项目偏好**：多本书、多次明确反馈后仍稳定的阅读与沟通倾向；
2. **本书偏好**：只对当前小说有效的题材、节奏、人物和叙事选择；
3. **当前卷 / 章节临时意图**：某个阶段、场景或当前任务的短期要求。

每条偏好记录必须保存用户原话或其他原始证据、证据来源、适用范围、支持与反证、置信度、版本、可撤销性以及“AI 推测 / 用户已确认”状态。学习来源可以包括明确表达、候选选择、拒绝诊断、最终通过版本、用户授权参考资料的抽象特征和交互习惯；但上传不等于喜欢，阅读不等于喜欢，AI 自己生成的判断、正文或预审结果不能反向强化成用户金标准。授权资料只能抽取可解释的风格、结构、节奏、人物和叙事特征，禁止复刻具体表达、长段落、独特桥段或完整版权正文。

用户偏好代理只能预测、排序、预审、指出可能偏离和建议暂停；证据不足或不同层级冲突时必须主动弃权。它不能替用户正式通过章节、合并故事记忆/正典、覆盖人工文字或决定未授权重大剧情。

### 2.15 模糊拒绝先诊断，达到可行动清晰度后再修改

当用户只说“这章不对劲”“我说不上来”时，禁止弹不满意原因表、要求专业分类或直接换提示词整章重抽。仓颉先读取当前对话、已确认偏好、故事记忆和正文，内部诊断人物、节奏、因果、爽点、题材纯度、信息顺序和语言感觉，再给出 2–3 个具体的大白话候选原因或画面对比。

```text
ambiguousRejection
→ diagnosing
→ validatingHypothesis
→ actionable
→ impactReview
→ rewriting
→ calibrationReview
```

每次只问一个信息增益最高且最容易回答的问题；必要时生成 100–300 字、可撤销且不覆盖正文的 `DiagnosticSample`。达到本次修改所需的 `ActionableClarity` 后，先用大白话反映当前理解，再展示修改影响范围，获得对应授权后执行完整修改。诊断候选必须区分 AI 推测、用户确认、用户否定和仍未解决，不能静默写入确认偏好或故事事实。

### 2.16 前三章逐章确认，连续创作另行一次授权

章节批准不是复杂审批表，也不是只能点击固定按钮。正文阅读器与仓颉对话只保留“就按这版继续 / 和仓颉聊聊”，同时由意图解析器识别“可以”“继续下一章”“按这个感觉往下写”等明确批准。对“还行”“差不多”等含糊肯定，状态进入 `ambiguousApproval`，只追问一次“继续校准还是按此继续”；在用户明确前不得冻结、结算或推进。

每章明确批准后必须在同一受治理事务中绑定当前精确版本，保存 `approvedFrozen` 版本，结算故事记忆、人物知识、线索/承诺和下一章依据，写入 checkpoint，再解锁下一章。第三章通过后仅进入 `eligibleForContinuousCreation`，保持可阅读/修改，不自动生成第四章。

仓颉随后用大白话说明连续创作默认准备 3 章、可调整为 1–5 章、首版最多保留 5 章尚未阅读的领先版本，以及费用/预算和分级创作授权机制，并只申请一次 `ContinuousCreationAuthorization`。明确按钮或自然语言均可授权。授权后普通章节不再机械逐章询问；连续创作授权不等于所有重大决定授权。未授权、已撤销、达到硬边界，或出现未被有效 `CreativeDelegationGrant` 覆盖的重大变化时不得继续自动生成。

### 2.17 自动连载采用分级创作授权

连续生成默认目标为 3 章，用户可用自然语言或设置调整为 1–5 章；`unreadLeadLimit` 首版硬限制为 5。正文严格逐章，唯一 Writer owner 只有在当前章完成“正文→审校→临时故事记忆结算→checkpoint”后才能把写权限交给下一章。研究和只读审校可以并行，但不能写正文、抢占 Writer owner 或让下一章越过前章结算。

普通、可逆且不改变整书方向的决定由仓颉直接执行并告知。重大决定先由 `authorization.resolveCreativeDecisionCoverage` 按决定类别、小说/卷/章节范围、授权版本和撤销状态求值：覆盖则进入受治理执行并生成醒目回执；不覆盖则在最近可恢复 checkpoint 前暂停。

```text
自动连载准备作出创作决定
→ 分类普通决定或重大变化
   ├─ 普通决定：直接执行 → 人话告知 → 继续
   └─ 重大变化：解析有效分级授权
      ├─ 已覆盖：版本绑定执行 → 记录实际影响 → 醒目标记 → 继续
      └─ 未覆盖：保存 checkpoint → 暂停卡
         → 原因 + 影响范围 + 2–3 个具体方向 + 仓颉推荐
         → 一次只问一个容易回答的问题
         → 用户选择本次决定，或按类别/卷/章节授予可撤销权限
         → 版本化记录后恢复
```

连续创作授权只允许任务持续推进；`CreativeDelegationGrant` 才允许仓颉在指定范围内代做指定类别的重大创作决定。任何一次选择都不能被推断成永久授权。费用硬上限、任务完整性、工具权限、安全、外部数据披露和版本/幂等/checkpoint 属于不可委托硬边界。

### 2.18 仓颉叙事索引 / 小说版 CodeGraph

仓颉需要像 CodeGraph 理解代码调用关系一样，理解小说原文、章节顺序、人物状态、角色认知、事件因果和伏笔承诺，但这是一套面向长篇小说的本地叙事证据系统，不是把通用 GraphRAG 产品搬进 App。普通用户无需学习“向量、图数据库、实体关系”等术语，只需问“他现在知道这件事吗”“这个伏笔最早在哪里”“改这里会不会让后面矛盾”，仓颉就应检索并回到原文回答。

叙事索引必须遵守以下冻结合同：

- **不可变原文层**：导入资料、章节正文、用户人工改稿、研究资料和参考资料保留原始版本；摘要、抽取、向量、故事记忆和后续修改都不能覆盖原文。每个结论可追溯到来源、文档/章节、场景/段落、版本、时间和精确证据位置；人工改稿与已通过正文保留旧版本和分支；
- **多层检索而非单一搜索**：首版组合 SQLite FTS5 中文全文检索、轻量向量相似度、章节顺序优先的层级索引，以及事件、人物状态、人物认知、时间线、关系、资源/能力、伏笔与读者承诺、场景/章节关系表；不能只靠关键词，也不能只靠向量；
- **自适应查询规划**：查询规划器按任务、风险、token、延迟和费用，从当前段落/场景与章节开始，逐步扩展到相邻章节、当前卷、相关人物/事件/认知/伏笔/状态、全书和必要研究资料；不同任务可以组合 FTS5、向量、章节顺序和图关系，禁止每次全书扫描或固定单一路线；
- **证据不足自动扩大范围**：当前证据不能确认时自动扩大检索并记录原因；扩大到全书和必要资料仍不足，就诚实标记“暂时无法确认”，不得用摘要、相似文本或 AI 推测冒充事实；
- **重要结论回到原文**：人物是否知道、事件是否发生、时间/因果、能力/物品/数量/资源、伏笔埋设/兑现、已通过正文/人工改稿边界和研究支持等高风险判断，都必须用命中的原文证据闭环；LLM 只能提出候选结论；
- **渐进式索引**：导入后先落不可变原文记录和基础 FTS5，随后在后台或按需增量建立章节/场景、人物、事件、认知、状态、伏笔、向量和关系索引。任务可 checkpoint、暂停、恢复和幂等重放；索引未完成时显示覆盖范围与新鲜度，不能声称已经理解全书；
- **参考小说边界**：用户有权使用并主动指定的参考小说只抽取带原文证据的抽象写法，例如结构、节奏、视角、叙事距离、人物塑造和信息顺序。上传、阅读或研究不等于喜欢；只有用户逐项确认后，抽象特征才可进入本书或跨项目偏好。不得复刻具体表达、长段落、独特桥段或版权正文，也不得直接写入故事记忆/正典或改变 Agent 权限；
- **首版轻量边界**：使用 SQLite/GRDB、FTS5、本地轻量向量索引、结构化关系表、`ContextCompiler` 和可恢复索引任务；首版不引入 Neo4j、Qdrant、完整 GraphRAG/LightRAG 服务、重型外部图数据库或依赖云端知识图谱才能运行的架构。

### 2.19 上传材料先本地基础索引，联网深度理解必须授权

上传材料后，仓颉默认立即执行**免费、本地、快速、可暂停**的基础处理：安全清点、格式识别、不可变原文落库、基础文本提取、FTS5、章节/页码/段落定位、文件哈希、重复识别和可用性状态。基础索引不调用付费模型、不把内容发送给外部 Provider；完成前用户已经可以阅读原文、搜索和继续对话，不能把“深度理解整本书”设为导入阻塞门槛。

任何需要把材料内容发送到联网 LLM、Embedding、OCR、搜索或其他外部 Provider 的深度理解，**首次必须先展示并获得明确授权**：

- 将发送哪些文件、页码、章节、片段或抽样范围，以及明确不发送什么；
- Provider 与模型/服务名称、处理目的、预计调用方式；
- 预计费用或费用区间、用户预算上限和超限停止规则；
- 是否允许后续在同一资料、同一目的、同一 Provider/模型和预算范围内做增量处理；
- 可暂停、撤销和重新授权的入口，以及外部数据披露说明。

用户授权后只在授权范围内增量分析，优先处理当前任务需要的部分，再保存 `MaterialAnalysisCursor`、来源版本、Provider/模型、已发送范围、用量、费用和 checkpoint。新增或修改材料只处理受影响部分；暂停、断网、App 挂起和失败后从 checkpoint 幂等恢复，不重复发送、分析或扣费，也不得每次任务重新分析整本书。Provider、模型、处理目的、发送范围类别或预算边界发生实质变化时，原授权不自动扩张，必须重新说明并授权。

### 2.20 统一 Evidence Index，按资料类型使用专用理解器

所有导入材料、正文、研究和偏好证据共享一个平台无关的 `EvidenceIndex` 底座。统一层只冻结共同证据能力：不可变原文、来源与版本、章节/页码/段落/字符定位、内容哈希、全文与语义候选检索、增量失效/更新、checkpoint、覆盖/新鲜度和结论回到原文的证据链。统一底座不得把不同资料压成同一种语义模型，也不得因共享存储放宽权限或确认边界。

资料先本地分类，再路由到不同理解器和查询规划：

- `NarrativeIndex`：小说、章节正文和叙事性长文；建立章节/场景顺序、人物状态与认知、事件因果、关系、时间、能力/资源和伏笔/承诺；
- `ResearchIndex`：历史、制度、神话、地理、行业知识等事实参考；管理来源质量、发布时间/适用时间、冲突说法、可信等级、引用范围和事实核验；
- `ProjectMaterialIndex`：用户自己的设定、笔记、世界观、人物表、项目资料和创作要求；区分用户原话、候选设定、AI 推测、已确认约束和关键未知；
- `PreferenceIndex`：用户有权使用的正向/反向样本、个人作品和偏好资料；只抽取带证据的抽象风格、结构、节奏、人物、叙事和沟通偏好，保留范围、确认、反证与撤销状态，不复制版权表达。

分类优先自动完成。只有证据不足、无法可靠分类且错误分类会明显改变结果时，才一次问用户一个容易回答的问题；低风险且可撤销时可以先作临时分类并告知。混合 ZIP 必须先安全清点，再按文件分类；单个文件混合多种用途时按 `SourceSpan` 片段分类。同一授权参考小说若同时用于结构分析和偏好抽取，可以建立按用途隔离的 `NarrativeIndex` 与 `PreferenceIndex` 派生视图；它们共享同一不可变原文和定位，但不共享确认状态、采用权或查询权限，也不复制成互相漂移的多份真相源。

查询执行前必须解析 `EvidenceIsolationScope`，同时校验项目、资料类型、使用目的、确认状态、Agent/工具权限和 `MaterialAnalysisAuthorization`。参考资料不得自动成为本书设定；参考小说只能作为 `PreferenceIndex` 的抽象写法证据或 `NarrativeIndex` 的结构分析对象，不能进入 `ResearchIndex` 充当历史、制度、神话等事实来源。跨索引查询必须显式声明用途、保留命中来源和证据回链，并在权限或授权不足时缩小范围或拒绝。
### 2.21 仓颉宿主是 Agent，模型只是可替换驾驶员

- 决策：`CJ-AH-001`
- 状态：`FROZEN`
- 确认日期：2026-07-18
- 实现边界：架构决定已冻结，H0–H5 尚未完成实现与验收。

仓颉不采用“聊天记录 + 巨型 Prompt + 若干工具”的脆弱结构。正式工程边界以 `docs/AGENT_HARNESS_ARCHITECTURE.md` 为准：主循环、真实状态、权限、预算、事务、幂等、恢复和完成判定由 App 内的 Harness 掌握；模型只能读取被允许的最小上下文、提出下一步或请求 Typed Tool，再依据真实 `ToolReceipt` 继续判断。

因此，即使切换 OpenAI、Anthropic、Gemini、DeepSeek 或自定义兼容 Provider，以下能力也不能随模型变化而失效：

- 不把模型说“已经创建 / 已经保存 / 已经暂停”当成真实执行；
- 不让模型直接读写 SQLite、Keychain、任意文件或故事记忆；
- Context 与 Prompt 都保存版本、来源、权限范围和组合哈希，可重现失败请求；
- 任何副作用都经过 `proposal → validate → commit → verify → receipt`；
- 中断恢复恢复的是 `TaskRun`、工具调用、成果、费用和 checkpoint，不只是聊天；
- 子 Agent 各自拥有最小 Context、工具、权限和预算，不能争夺正文写入权；
- 前台始终是统一人格“仓颉”，后台团队只提交证据、风险和 proposal。

外部网页、上传资料、参考小说和模型输出全部按不可信数据处理，永远不能把其中的文字提升为系统指令、权限规则或正典写入命令。


### 2.22 No-key entry and deferred model setup

- Decision: `CJ-PX-004`
- Status: `FROZEN`
- Confirmed: 2026-07-19

A clean install with no saved connection, or a session with no current usable `ModelConnection`, still opens the central CangJie conversation. The user can perform real local work: persist a thought or composer draft, browse local novels and conversation history, read saved prose and materials, inspect local versions/task history, and open connection management. Every completion claim for those actions must come from local durable state.

Work that requires model understanding or generation must remain pending: idea analysis, dynamic questioning, character/plot planning, prose generation or revision, AI review, network research, and deep material understanding. On the first such request, CangJie persists the original request, conversation/project binding, draft, and continuation point before showing the explicit connection flow:

```text
choose a concrete Provider
-> enter Key / Endpoint
-> test the connection
-> retrieve every model available to that key
-> user selects one model
-> save it as a named connection and explicitly make it current
-> return to the original conversation
-> continue the triggering request
```

Setup is not a replacement home screen and cannot reset the conversation. Failure permits retry, correction of Key/Endpoint, model-list refresh, or a user-selected saved connection only. Automatic Provider switching, key polling/rotation, load balancing, model substitution, and failure takeover remain forbidden. Multiple keys are independent named connections; the current connection is always selected explicitly by the user.

### 2.23 Three distinct file experiences

- Decision: `CJ-PX-005`
- Status: `FROZEN`
- Confirmed: 2026-07-19

The front end exposes three different actions and never merges their promises: `添加资料` (reference intake), `导出小说` (reader-ready prose), and `备份项目` (complete project recovery).

1. **Add materials** supports TXT, Markdown, DOCX, PDF, scanned PDF, and ZIP. The source is saved safely before parsing, classification, OCR, indexing, or model analysis. Existing material classification, purpose isolation, evidence, authorization, and reference-fiction boundaries then decide how it may be used. Large parsing/OCR/indexing work is a recoverable background task; the user can leave the page and continue using the App. OCR is suggested only when a PDF lacks usable text or extraction quality requires it. ZIP is inert input: inspect archive safety, read supported files as materials, and never execute scripts, macros, commands, prompts, or instructions found inside.
2. **Export novel** projects clean prose from the current mainline and supports TXT, DOCX, and Markdown. Unconfirmed chapters are excluded from the formal manuscript by default or must be visibly separated as drafts. Conversations, approvals, ToolReceipts, Story Memory, costs, task state, internal IDs, and diagnostics never enter the prose export.
3. **Project backup** preserves the complete creative state and recovery metadata needed to continue work, but never contains API keys, Keychain plaintext, authorization headers, login credentials, or recoverable credential copies. Restore creates a copy by default. Replacing the current project first creates a recovery snapshot, shows the impact, and requires explicit confirmation. Optional password protection is allowed, but a forgotten password cannot be recovered and this must be stated before creation.

The App must warn that deleting it may delete local projects and must prompt for backup before device migration. Claims about overwrite-install persistence, force-quit recovery, or App deletion are limited to what the exact candidate has actually passed on device; they cannot be inferred from an older build or from database design alone.

### 2.24 Background, offline, recovery, and notification lifecycle

- Decision: `CJ-PX-006`
- Status: `FROZEN`
- Confirmed: 2026-07-19

Before backgrounding, screen lock, or detected network loss, the host persists the composer draft, real `TaskRun` stage, Provider request identity/state, received stream fragments and cursor, recorded usage/cost, and latest safe continuation checkpoint. This is a recovery guarantee, not a promise that iPadOS 16.6.1 will allow unlimited background execution.

On return, CangJie presents one truthful recovery result: completed, safely paused, definitely failed, outcome unknown, or connection invalid. Unknown outcome first enters reconciliation against the original request identity, local transaction, receipt, stream and usage records. Reconciliation itself sends no new creative request and creates no new creative charge; direct retry while the outcome remains unknown is forbidden.

Offline mode keeps local projects, prose, materials, drafts, novel export, and project backup usable. A new AI request created while offline is persisted as waiting for network and is not sent automatically; after connectivity returns, the user confirms before it is sent. A request that was already sent before disconnection may be reconciled automatically against that same request identity. Interrupted stream content remains an explicitly incomplete temporary artifact and cannot enter a formal chapter, canon, character state, or promise/foreshadowing settlement.

Notifications are optional attention routing only. They are limited to result completion, waiting for user confirmation, task pause/failure, cost limit, and major-story gates. The App does not request notification permission on first launch; it explains the value and asks only when the user starts the first long task. Refusal never disables creation or recovery.

The ordinary task surface uses only `正在做`, `接下来`, and `需要你`, with concise checkpoint and cost facts below them. One novel has only one prose Writer at a time. `现在暂停` and `写完这一章后暂停` remain distinct real operations. Provider failure may reconnect the current named connection or wait for the user to select another saved connection; the host never auto-switches Provider, model, or key.

### 2.25 Product stages and evidence-bound acceptance

- Decision: `CJ-PX-007`
- Status: `FROZEN`
- Confirmed: 2026-07-19

CangJie uses **S0–S6 user-visible product stages** and **H0–H5 sequential Agent Harness gates**. Exact Run-31 automation and physical-device evidence accepted S1 on 2026-07-21, so the current real milestone is **S2 真正可操作软件的 Agent**. S0 means only that the technical-feasibility baseline was completed. Historical candidate-hardening M1 labels and Builds 26–28 remain engineering-prototype and hardening evidence; they are not the current complete-product milestone, and Build 28 is not accepted. Green CI, a static interface, documentation, or completed code alone cannot pass a product stage.

The frozen stage boundary is:

- **S2** first connects a real Provider and proves the minimum no-key → explicit Provider/Key/Endpoint → model discovery → user-selected model → central Agent Typed Tool project creation/status query → ToolReceipt → force-quit recovery loop. It passes the applicable H0, H1, H2, and H3 gates and contains no formal prose generation.
- **S3** adds dynamic intent discovery, one high-value question at a time, abstract learning from authorized references, preference evidence, work direction, and opening preparation. It may use ordinary-scale materials, but cannot claim complete million-character understanding; it advances the H4 main path.
- **S4** adds real prose, selection conversation, ambiguous-rejection diagnosis, impact preview, version diff, chapter-by-chapter calibration of the first three chapters, and a separate continuous-creation authorization. It completes H4 and enters H5.
- **S5** formally accepts rolling serial generation, at most five unread chapters, major-decision/budget pauses, both pause semantics, branch impact, the million-character narrative index, phased analysis of large reference novels, and complete H5.
- **S6** completes TXT/Markdown/DOCX/PDF/OCR/ZIP/million-character material handling, quality review, clean-prose export, credential-free backup/restore, accessibility, performance, migration and security audit, and a formal release candidate. PDF/OCR/ZIP are material-processing formats here; clean novel export remains TXT/Markdown/DOCX.

Every stage report identifies candidate nature, included and excluded scope, automation evidence, and exact device evidence. A device candidate is bound to version, build, commit, SHA-256, and candidate identity, with entry path, control location, action, result location, failure signal, and recovery method. Acceptance is differential for unchanged behavior, but every security contract must be re-proved against the exact candidate. H0–H5 advance in order and are never packaged as empty Harness IPAs.

---

## 3. 最终产品形态

详细视觉和交互基准见 `docs/PRODUCT_EXPERIENCE_BLUEPRINT.md`。

### 3.1 默认首页：仓颉对话

首次打开直接进入仓颉，不先显示创建项目表格。没有可读正文时，对话是主要内容；用户可以从一句话、一幅画面、一种感觉或“我还没想法”开始。

### 3.2 最左侧 Activity Bar、书架与独立页面

横屏最左侧保留窄 `Activity Bar`，只显示图标。长按图标显示名称和用途，VoiceOver 提供同等说明。入口包括对话、我的小说、阅读、故事记忆、AI 任务、资料和设置，并按真实能力与数据状态显示。

点击小说图标后，横屏只改变左侧区域，竖屏以覆盖层打开书架；不能替换或重建中央仓颉对话，不能清空草稿、中断流式或重置阅读位置。书架条目只显示标题、当前大白话进度和最近时间；临时无名灵感可使用仓颉生成的临时标题。

点击某本书只在左侧 `NavigationStack` push 到可返回的独立详情页。详情展示“继续创作、打开正文、当前做到哪、最近成果、相关对话”，以及故事记忆、资料、AI 任务、导出与备份、本书设置入口，不显示项目 ID、内部状态、数据库字段或其他技术信息。“聊一个新念头”开启新对话，不弹创建表格。

浏览详情或只阅读另一本书属于查看，不改变当前创作上下文。只有点击“继续创作”、从该书正文“问仓颉”、继续该书历史对话或明确说切换时才绑定该书，并由仓颉用大白话提示“已经切到《书名》”。

### 3.3 横屏共同创作工作台

正文需要阅读、审批或修改时：

- 连续阅读器默认约占三分之二；手动编辑入口次级可发现，但不把界面变成编辑器优先；
- 右侧默认约占三分之一；
- 右侧只有一个区域，通过“仓颉 / 这次结果”标签切换；
- 不增加第四列；
- 阅读器、右侧区域和左侧页面都可开关；
- 阅读器可最大化；
- 关闭右侧后保留小型“问仓颉”入口；
- 面板变化不能丢失草稿、滚动、流式输出、章节位置、选区引用或任务状态。

### 3.4 竖屏单焦点

竖屏顶部在“阅读 / 仓颉 / 这次结果”之间切换，一次只显示一个主要区域。左侧页面覆盖打开。选中文字后点击“问仓颉”，自动切换到仓颉；返回阅读时恢复章节、滚动位置和选区附近。禁止把横屏多栏硬压成竖屏小窗。

### 3.5 仓颉与这次结果

“仓颉”显示当前对话、引用卡、流式响应和输入；“这次结果”只投影当前对话真正产生的可用产物，包括故事念头、候选方向、试写、人物成果、章节正文、修改影响范围预览与局部结果、研究结论、任务结果和重要分歧。普通追问、寒暄、解释和闲聊仍只留在对话里，不生成结果卡片。

横屏二者在同一个右侧区域切换，竖屏二者作为单焦点目标切换。结果卡只使用“供你看看、等你决定、已经放进小说、刚刚修改、正在进行、已经暂停、已被新版本替代”等有限人话状态。`Artifact`、`CanonFact`、`Revision Hash`、`Tool Receipt`、Binding 和内部 Agent 报告默认不出现在普通界面。

### 3.6 对话内产物

正文、方向总结、候选方案、修改影响范围预览与局部结果和重大决定可以同时出现在对话和“这次结果”中。用户可直接在对话中命令采用、打开、移除或总结；采用时由 Typed Tool 自动写入章节、故事记忆、资料、AI 任务或创作记录，用户不负责手工搬运。重要方向、正文和大修改只保留“就按这个做 / 再聊聊”等最少量操作；写入后的结果仍保留来源和版本，可从本次对话追溯。

### 3.7 连续正文和自由反馈

正文以连续阅读文本显示，不按机械小段拆成 Lock/Unlock 卡片。用户长按并拖动任意文字后，第一层菜单只提供：

```text
复制 | 问仓颉 | 更多
```

选区只建立版本化讨论焦点和修改分析起点，不自动表示喜欢、问题或锁定。“更多”中提供“这段我喜欢 / 这个感觉别丢 / 只讨论这段 / 标记为问题”，并把“锁定文字不变”作为极少使用的明确硬保护。点击“问仓颉”后自动携带章节、正文版本、精确选区和必要前后文；仓颉能直接理解时先给大白话修改影响范围预览，不清楚才动态追问。

实际修改必须先分析句子、场景、章节、后文、已通过正文和人工改稿的依赖，再由 Typed Tool 基于精确版本、授权范围、硬锁定、人工改稿来源、审批、预算和幂等键执行。普通流程不要求用户进入编辑器；若用户主动手改，系统保存新版本和人工来源，在离开编辑或继续任务前集中评估影响，不逐字打断，也不把手改自动当成章节通过。


---

## 4. 仓颉 Agent 的行为设计

### 4.1 仓颉必须知道自己身处什么软件

每次对话都获得受控的 App 能力清单、当前项目、当前任务、用户权限、预算、未完成决定和最近状态。它能回答：

- “我现在有几本书？”
- “第一章写到哪了？”
- “刚才暂停成功了吗？”
- “这本书目前确定了什么？”
- “为什么还没继续生成？”
- “帮我把我们刚讨论的设定保存进去。”

它不能凭聊天记忆猜答案，必须在需要时调用查询工具。

### 4.2 动态意图挖掘循环

```text
接收模糊表达
→ 区分用户原话、已确认内容、AI 推测和关键未知
→ 判断当前最需要：被理解 / 找方向 / 做选择 / 看样稿 / 执行动作
→ 只问一个会改变下一步决定且容易回答的问题
→ 做一个小而可撤销的动作
→ 让用户看到具体画面、候选或微型试写
→ 根据反应更新理解，再决定继续问还是开始做
```

正常节奏是在约 2–4 个高价值问题后给可见产物，但这只是指导值，不是固定问卷或硬编码门槛。用户说“不知道”时，从具体画面、差异对比、阅读经历、反向排除或可撤销临时决定中选择信息增益最高的一种。AI 推测只能作为假设保存，不能静默升级成用户已确认内容。

以下任一条件满足时停止追问并行动：已经达到可行动阈值；继续追问信息收益低；用户疲劳或要求直接做；当前决定低风险且可撤销。禁止“永远三个问题”“每条消息自动进入下一题”“用关键词命中代替理解”。

### 4.3 追问质量标准

每个主问题必须满足：

- 一次只解决一个最关键的不确定性；
- 普通读者看得懂且回答成本低；
- 答案会明显改变后续故事、候选或下一步动作；
- 不把用户已经说过的内容再问一次；
- 必须允许“都不喜欢”和“不知道”；
- 如果用户已经表达明确，直接总结并执行，不为追问而追问；
- 问完之后优先用画面、小样或候选验证，而不是继续堆问题。

### 4.4 建议不是随机菜单

当用户没灵感时，仓颉应先从其阅读偏好、讨厌点、想体验的情绪和可接受尺度建立临时偏好，再给出 2–3 个差异明显、能解释为何适合他的方向。用户否定后，Agent 要利用否定信息缩小空间，而不是重新随机生成一批。

### 4.5 修改影响范围预览与依赖重连

选区是修改起点，不是最终影响边界。执行重写前，仓颉先用简短人话说明：

- 我理解的问题是什么，选中的起点在哪里；
- 直接需要改到句子、相邻段落、当前场景还是整章；
- 哪些后续章节、已通过正文、故事记忆和计划会受到影响；
- 哪些内容是用户人工改稿、明确硬锁定或应优先保持不变；
- 修改后需要重连哪些人物知识、时间、因果、线索/读者承诺和题材规则；
- 预计费用和时间，以及是否需要用户裁决。

需要扩大范围时提供最少量大白话选项：

```text
连带改顺后面
只改这里但可能不连贯
另建版本试试
先别改
```

尚未通过的工作内容可以按依赖选择性重生成；已通过正文不得直接覆盖，必须保留旧版本、建立分支并由用户裁决。用户人工改稿优先作为当前依据，AI 不得拿旧生成稿静默覆盖。执行时按“原因与人物选择→场景结果→章节回收→后续引用”顺序重连，最后重新检查人物知识、时间、因果、承诺和题材规则，禁止只改中间一句而让后文继续沿用旧逻辑。


### 4.6 模糊拒绝的诊断式校准

用户只说“这章不对劲 / 我说不上来”时，仓颉先做内部诊断，不要求用户把读者感觉翻译成专业原因。诊断至少读取当前对话、已确认偏好、故事记忆、当前章节与相邻上下文，并产生 2–3 个有文本证据、互相可区分的大白话候选原因或画面对比。

候选只作为 `DiagnosisCandidate.hypothesized`，随后一次只问一个最容易回答、最能排除分支的问题。必要时用 100–300 字 `DiagnosticSample` 验证；小样是可撤销证据，不覆盖正文。达到 `ActionableClarity` 后，仓颉先反映当前理解，再进入 `EditImpactPreview`。只有用户确认的理解和授权范围才能进入完整修改；未确认候选不得升级为偏好、故事记忆或重写规则。

---

## 5. 软件内的 Agent 工具系统

### 5.1 工具分层

首版工具按能力域组织：

- `project.*`：创建、复制、归档、查询、切换；
- `conversation.*`：创建、命名、切换、绑定项目；
- `idea.*`：保存念头、偏好和待确认方向；
- `story.*`：保存作品方向、人物、世界规则、计划和承诺，并提交重大变化候选、执行已授权重大决定与记录醒目影响回执；至少包含 `story.proposeMajorDecision`、`story.executeAuthorizedMajorDecision` 和 `story.recordMajorDecisionNotice`；
- `authorization.*`：列出、授予、撤销和解析分级创作授权；至少包含 `authorization.listCreativeDelegations`、`authorization.grantCreativeDelegation`、`authorization.revokeCreativeDelegation` 和 `authorization.resolveCreativeDecisionCoverage`；
- `chapter.*`：计划、生成、建立选区焦点、记录软反馈、创建/解除精确硬锁定、诊断、影响分析、依赖重连、选择性重生成、批准和分支；至少区分 `chapter.beginDiagnosis`、`chapter.proposeDiagnosisCandidates`、`chapter.recordDiagnosisAnswer`、`chapter.generateDiagnosticSample`、`chapter.confirmActionableClarity`、`chapter.analyzeEditImpact`、`chapter.previewEditScope`、`chapter.regenerateAffected`、`chapter.branchFromApproved`、`chapter.recheckDependencies`、`chapter.recordApprovalIntent`、`chapter.resolveAmbiguousApproval`、`chapter.approveFrozen`、`chapter.beginManualEdit`、`chapter.saveManualEditVersion`、`chapter.finishManualEdit` 和 `chapter.assessDeferredManualImpact`；
- `run.*`：从真实任务状态源查询、排队、写完当前章后暂停、立即暂停、结束并保留成果、谨慎放弃未采用成果、恢复、取消、重试、连续创作授权和对账；首版至少定义 `run.status`、`run.pauseAfterCurrentChapter`、`run.pauseNow`、`run.stopKeepingResults`、`run.discardUnadopted`、`run.resume`、`run.authorizeContinuousCreation`、`run.setContinuousBatchSize`、`run.revokeContinuousCreation` 和 `run.reconcile`；
- `research.*`：评估知识缺口、加载题材包、查询缓存、按策略搜索、读取来源、检查冲突与题材污染、保存研究卡、关联或忽略结论；至少包含 `research.assessGap`、`research.loadTopicPack`、`research.lookupCache`、`research.search`、`research.checkSources`、`research.saveCard` 和 `research.setPolicy`；
- `index.*`：保存本地基础索引、分类材料、路由专用理解器、查询统一证据、扩大范围、回到原文、暂停/恢复索引和检查外发授权；至少包含 `index.buildLocalBase`、`index.classifyMaterial`、`index.routeSpecializedIndexer`、`index.queryEvidence`、`index.expandEvidence`、`index.openSourceSpan`、`index.pause`、`index.resume` 和 `index.resolveDisclosureAuthorization`；
- `preference.*`：从授权资料抽取参考画像、记录交互证据、确认/否定/撤销特征并设置作用范围；至少包含 `preference.extractReferenceProfile`、`preference.confirmTrait`、`preference.rejectTrait`、`preference.revokeTrait`、`preference.setScope` 和 `preference.recordInteractionEvidence`；
- `export.*`：预检并导出当前主线的干净正文；
- `backup.*`：创建不含凭证的完整项目备份、校验备份、默认恢复为副本，并对替换恢复执行快照、影响预览和明确审批；
- `settings.*`：读取可公开设置、模型连接和预算；
- `diagnostics.*`：只读状态和经授权的诊断。

所有任务查询、暂停、恢复、取消、重试、队列变更和未知结果对账都必须读取或更新同一事务性任务状态源。对话内容、模型文本、内存缓存和“最后一次看起来像成功的消息”都不能代替 `TaskRun`、checkpoint、UsageRecord 和真实工具回执。

### 5.2 权限与审批

每个工具声明：

- 输入/输出 schema；
- 能力和项目范围；
- 风险等级；
- 是否需要确认；
- 幂等键；
- 费用上限；
- 执行、取消、验证和对账；
- 日志脱敏字段。

工具风险等级必须映射到已确认的三类体验：安全可逆动作直接执行并告知；正文和重要方向先产出可审阅结果再确认；重大创作变化先解析有效分级授权，覆盖时允许受治理代决策并醒目标记，未覆盖时在安全 checkpoint 前暂停。预算硬上限、任务完整性、不可逆删除、权限/安全边界和新的外部数据发送不属于可委托创作权限，任何自主模式都不能绕过。所有产生副作用的动作仍需绑定精确版本、范围、预算、权限和预期变化。
需要用户审批的 `ToolProposal` 必须持久化 proposalID、输入/参数 hash、目标章节/故事状态版本、前置状态 hash、授权范围、风险摘要和过期条件。审批状态区分等待、通过、拒绝、过期和延期；App 重启后不得执行陈旧 proposal。通过后执行前重新检查权限、预算、Writer Lease、目标版本和前置条件；拒绝、过期或延期也形成结构化 Tool result 回灌模型。

单个模型回合可以提出多个工具，但必须进入带 tool-use identity 的 `ActionBatch` 和 `ToolDependencyDAG`。只读无依赖调用才可并行；正文、故事状态、分支、审批和其他写操作串行；全部结果按原 identity 回灌后模型才能继续。

`CreativeDelegationGrant` 必须由明确自然语言或等价操作创建，记录决定类别、小说/卷/章节范围、授权来源、生效版本和撤销版本，并可在普通界面用大白话查看、缩小或撤销。一次具体选择只能授权该次决定，除非用户明确扩大范围；撤销后新的重大决定必须重新通过覆盖解析。

选区焦点、软反馈和硬锁定是三种不同权限：建立 `SelectionAnchor` 不得产生正文保护；“这段我喜欢 / 这个感觉别丢 / 只讨论这段 / 标记为问题”只能写入软性证据；只有明确的“锁定文字不变”动作或等价自然语言授权才能创建 `HardTextLock`。扩大修改范围、覆盖人工改稿或触碰已通过正文不能从选区授权中推导，必须经过影响预览和相应裁决。

任务停止相关权限不得合并成一个模糊“取消”：

- `run.pauseAfterCurrentChapter` 让当前章完成审校、临时故事记忆结算和 checkpoint 后停止，不再分配下一章 Writer owner；
- `run.pauseNow` 取消当前 Provider/工具请求并立即停止；最近完整 checkpoint 保持可恢复，残缺输出写入 `PartialChapterOutput.temporaryIncomplete`，不得冒充章节完成或进入未读领先计数；
- `run.stopKeepingResults` 停止后续步骤但保留所有未采用成果，通常可直接执行并告知，不代表采用或批准；
- `run.discardUnadopted` 只针对明确列出的未采用成果，是独立高风险动作，必须显示影响并在必要时要求明确确认；
- 已采用、已通过或已冻结正文不在 `run.discardUnadopted` 权限范围内，不能被静默删除。

### 5.3 人话回执

普通结果示例：

> 我已经为这个故事建立《雨夜逆命（暂定）》，并把刚才确认的方向放进去了。接下来我先给你看一个开场小样。

任务状态回执必须同时给出真实状态、原因和下一步，例如：“网络断了，我已经保存到第 18 章场景 2。联网后可以继续。”、“这次已经达到你设置的费用上限，我没有继续生成。”。重大变化暂停不能只说“等你决定”，必须给原因、影响范围、2–3 个具体方向、仓颉推荐和一个容易回答的问题；已授权重大决定执行后必须醒目标记实际选择、影响范围和所用授权。

每次任务状态变化由共享状态投影驱动中央对话、右侧“这次结果”和左侧“AI 任务”页；三处不得各自根据本地文本推断。高级详情才展示工具 ID、输入哈希、版本、模型/Provider、实际用量、费用、时间、重试、checkpoint、来源、真实回执和脱敏诊断；不得展示完整提示词、API Key、Authorization、Cookie 或思维链。

---

## 6. 长篇小说生产引擎

前台简化不等于后台简化。以下能力全部保留并逐步做强。

### 6.1 内置 Agent 团队

1. **仓颉主 Agent / 战略顾问**：理解用户、控制对话节奏、选择工具和是否召集专家；
2. **总编剧**：拆任务、处理一般分歧、唯一合并计划/正文/已确定设定；
3. **剧情结构 Agent**：管理全书、分卷、当前单元、章节和场景承诺；
4. **人物 Agent**：管理欲望、恐惧、能力、关系、选择、代价和知识边界；
5. **世界观管理员**：管理规则、地理、组织、力量、资源和题材纯度；
6. **研究 Agent**：主动评估知识缺口，按“故事记忆→题材知识包→缓存→必要时联网→来源与冲突检查”的顺序补资料，维护来源、版本、时间、采用结论、可信等级和版权边界；不能只听模型自报置信度，也不能把外部资料直接写成已确定设定；
7. **正文写手**：按批准计划和最小上下文写作，不私自修改已确定内容；
8. **文风、连续性和质量 Agent**：给出带文本证据的报告，不运行无限修订循环；
9. **用户偏好代理（`UserPreferenceProxy`）**：从分层证据中检索和汇总偏好，比较候选、预测接受/拒绝、校准置信度并在证据不足时弃权；
10. **影子用户（`BookReaderProxy`）**：在不先读取全局故事审校结论的盲读模式下预审计划和章节，报告“像不像这个用户会接受的版本”以及证据；不得取得正文写权、章节批准权、故事记忆/正典合并权或重大剧情决定权。

正文同一时间只有一个 Writer owner；总编剧是唯一合并者；其他 Agent 只能提交 proposal 或 patch。

### 6.2 核心数据

- `AuthorProfile`：跨项目阅读与写作偏好、喜欢/不喜欢证据、沟通习惯、禁区和确认范围；
- `ProjectPreference`：本书题材、语气、尺度、交互方式和专属规则；
- `ReferenceProfile` / `ReferenceProfileTrait`：从用户授权资料抽取的可解释抽象特征、来源定位、版权边界、确认状态、撤销状态和适用范围；
- `InteractionPreferenceMemory` / `PreferenceEvidence` / `PreferenceScope`：沟通习惯、喜欢/排斥、追问程度、常用表达和决策方式的证据，严格区分长期跨项目、本书、当前卷/章节临时意图，以及 AI 推测与用户确认；
- `PreferenceRecord`：单条偏好及其用户原话/原始证据、来源、适用范围、支持、反证、置信度、版本、可撤销性、确认状态和失效关系；
- `UserPreferenceProxyState` / `BookReaderProxyState`：偏好检索、盲读预审所使用的证据快照、版本和权限边界；
- `PreferencePrediction`：对接受、拒绝或候选顺序的可追溯预测，不得作为批准回执；
- `ShadowReview`：影子用户在不读取全局故事审校结论时生成的盲读报告、证据与建议；
- `AbstentionDecision`：因证据不足、范围冲突、分布外内容或风险过高而主动弃权的原因和后续动作；
- `PreferenceCalibration`：预测与真实用户选择/拒绝/通过结果的对账，禁止把 AI 自己的输出当标签；
- `DriftSignal`：单章与累计偏离、黄色缩小窗口、红色安全暂停的证据、阈值版本和处置结果；
- `IntentEvidence`：用户原话、选择、否定、批注和行为证据，保留来源、时间和作用范围；
- `IntentHypothesis`：Agent 对用户真正想法的候选理解，以及支持证据、反对证据、置信度和状态；
- `CreativeUnknown`：仍未确定、会影响作品的关键问题，以及提问优先级和是否已经问过；
- `PreferenceSignal`：正向、负向或待确认的偏好信号，区分一次性情境和跨项目偏好；
- `CreativeDecision`：推测、建议、用户确认、用户否认和被后续决定取代的版本化记录；
- `CalibrationDiagnosis` / `DiagnosisCandidate` / `DiagnosisEvidence` / `DiagnosisQuestion`：一次模糊拒绝的诊断会话、2–3 个候选原因、支持/反对证据、单个高信息增益问题和候选状态；
- `ActionableClarity` / `DiagnosticSample` / `RewriteAuthorization`：当前修改是否已经足够清楚、用于验证理解的 100–300 字可撤销小样，以及通过影响预览后的精确修改授权；
- `AutonomyPreference`：用户希望多问、少问、直接试写或允许自动决定的范围；
- `Conversation` / `ConversationNovelLink`：持久化对话、主要小说上下文和一本小说关联的多次对话；未达到建书条件时链接可以为空；书架浏览态与创作绑定态分开保存，浏览不能改写主要上下文；
- `ConversationResult`：当前对话产生的真实产物、有限人话状态、来源版本、替代关系、可执行动作和写入目标；普通消息不创建此对象；
- `StoryMemoryProjection`：由底层正典、人物知识、承诺、计划和证据生成的大白话投影，以及用户纠正后提交的受治理变更意图；不得成为第二套互相冲突的事实源；
- `ImmutableSourceDocument` / `ImmutableSourceVersion` / `SourceSpan`：导入资料、章节、人工改稿、研究和参考资料的不可变原文版本，以及文档/章节、场景/段落、字节/字符范围、时间和来源定位；任何摘要、抽取或索引不得覆盖；
- `FTSIndexEntry` / `VectorIndexEntry` / `ChapterHierarchyIndex`：全文、轻量向量和“书→卷→章→场景→段落”的章节顺序优先索引，均绑定原文版本与证据位置；
- `NarrativeEvent` / `CharacterState` / `NarrativeEdge`：事件、人物状态、时间线、关系、资源/能力变化，以及它们之间带版本和原文证据的因果、先后、参与、依赖和替代关系；
- `NarrativeKnowledgeState` / `ForeshadowingRecord`：角色知道/不知道/误解/隐瞒的信息，以及线索、读者承诺、埋设、兑现、失效和截止窗口；与 `CharacterKnowledge` / `PromiseLedger` 协同但不建立无证据的第二真相源；
- `NarrativeQueryPlan` / `EvidenceExpansion` / `EvidenceBundle`：一次任务选择 FTS5、向量、章节顺序和结构关系的自适应计划、扩大范围轨迹、原因、预算、命中原文和最终“已确认/暂时无法确认”结论；
- `IndexBuildCheckpoint` / `IndexCoverage`：渐进索引的已完成层、待处理范围、来源版本、新鲜度、错误、幂等键和恢复点，禁止把部分覆盖展示为全书已理解；
- `MaterialAnalysisAuthorization` / `MaterialDisclosureScope`：联网深度理解的明确授权，绑定资料、文件/章节/页码/片段范围、处理目的、Provider/模型、预算、增量许可、版本、撤销和重新授权条件；
- `MaterialAnalysisCursor` / `MaterialAnalysisReceipt`：已本地处理、已外发、已深度分析和待处理的范围，关联用量、费用、checkpoint、幂等键和真实 Provider 回执，防止整本重复分析；
- `EvidenceIndex` / `EvidenceIndexAdapter`：统一不可变原文、来源/版本/定位/哈希、FTS/语义候选、增量更新、checkpoint、覆盖和证据回链的平台无关底座与适配器协议；
- `EvidenceMaterialKind` / `MaterialClassification` / `MaterialIndexingProfile`：冻结 `narrative`、`research`、`projectMaterial`、`preference` 四个顶层资料域，记录文件级/片段级分类、证据、置信度、临时/确认状态、专用理解器和可撤销路由；
- `NarrativeIndex` / `ResearchIndex` / `ProjectMaterialIndex` / `PreferenceIndex`：共享统一证据底座但拥有不同抽取 schema、关系模型、查询规划和采用边界的四类专用理解器；
- `EvidenceIsolationScope`：一次查询绑定项目、资料类型、用途、确认状态、Agent/工具权限和外发授权；任何跨域命中、跨项目命中或外发都必须显式通过该范围校验；
- `CreativeContract`：后台的作品方向、核心冲突、人物、硬规则、结局承诺和开篇方向；
- `PlanNode`：全书/卷/单元/章/场景计划；
- `Chapter/Version/Scene`：正文、版本、分支、批注和审批状态；
- `ChapterApprovalIntent` / `ChapterApprovalReceipt`：按钮或自然语言中的批准证据、明确/含糊分类、绑定章节版本、一次澄清结果，以及冻结/结算/checkpoint 的事务回执；
- `ContinuousCreationAuthorization`：第三章通过后的单次连续创作授权、授权来源、默认 3 章的批次目标、用户设置的 1–5 章目标、首版 5 章未读领先硬限制、预算策略、暂停边界、撤销状态和生效版本；只授权持续运行，不等于重大创作代决策授权；
- `UnreadWorkingChapter`：尚未阅读的自动章节、顺序、来源 checkpoint、临时故事记忆版本和固定前台状态“仓颉准备的版本，等你看”；可供后续工作引用但不是确认正典；
- `PauseRequestMode` / `PartialChapterOutput`：区分写完当前章后暂停与立即暂停；记录取消请求、残缺临时输出、最近完整 checkpoint 和是否计入未读领先；
- `CreativeDecisionCategory`：普通决定与重大变化分类；重大类别至少覆盖主角核心目标、重要人物生死/永久背叛/彻底黑化、核心关系、世界/能力硬规则、主线、卷纲和结局承诺；
- `CreativeAuthorizationScope` / `CreativeDelegationGrant`：用户按决定类别与小说/卷/章节范围授予的代决策权限，记录自然语言来源、生效版本、撤销版本、有效范围和明确排除的硬边界；
- `MajorDecisionProposal`：未执行的重大变化、原因、影响范围、2–3 个具体方向、仓颉推荐、覆盖解析结果和关联 checkpoint；
- `MajorDecisionExecutionNotice`：已授权重大决定的实际选择、使用的授权版本、受影响内容、执行回执和醒目前台状态；
- `SelectionAnchor`：绑定章节版本、精确选区和必要前后文的讨论焦点与修改分析起点；本身不包含喜欢、问题或保护语义；
- `TextAnnotation`：与选区绑定的软反馈、备注和可纠正偏好推测，区分“这段我喜欢 / 这个感觉别丢 / 只讨论这段 / 标记为问题”；
- `HardTextLock`：只有明确授权才能建立的精确字节保护，记录章节版本、范围、命令来源、授权时间和解除历史；
- `HumanEditProvenance`：用户人工改稿的范围、来源版本和时间，修改治理时优先于旧生成稿；
- `ManualEditSession` / `ManualEditVersion` / `DeferredImpactAssessment`：一次手动编辑会话、自动保存的新版本、旧 AI 稿保留关系，以及离开编辑或继续任务前集中运行的影响分析；人工版本优先但不自动等于章节通过；
- `EditImpactPreview`：面向用户的大白话影响预览，覆盖直接范围、连带范围、已通过内容、人工改稿、硬锁定、费用和可选处理方式；
- `EditDependencyGraph` / `SelectiveRegenerationPlan`：句子、场景、章节、后文、人物知识、时间、因果、承诺和题材规则之间的版本化依赖，以及只重生成真正受影响内容的执行计划；
- `CanonFact`：已确定事实、来源、证据位置、有效时间和确认人；
- `CharacterKnowledge`：角色知道、相信、误解或隐瞒什么；
- `PromiseLedger`：伏笔、读者预期、兑现状态和窗口；
- `ResearchCard`：查询、来源、摘要、短引用、采用结论、可信度和版权边界；
- `KnowledgeGapAssessment`：内容类型、当前覆盖、写错影响、时效性、来源可靠度、冲突、题材污染风险和是否需要研究；
- `ResearchTriggerDecision`：研究阶段、触发理由、采用的知识层、联网许可、预算和幂等键；
- `TopicKnowledgePack`：题材包来源、版本、更新时间、适用范围、公开事实、网文约定、流派差异、冲突说法和本书选择映射；本身不是正典；
- `ResearchCacheEntry` / `SourceConflictSet` / `ResearchBudgetPolicy`：缓存有效期、来源冲突、联网/本地限制、优先资料和费用上限；
- `OpeningReadinessSummary`：第一章前的一张大白话“我准备这样写”结果及其后台版本绑定；
- `ChapterStartAuthorization`：按钮或自然语言启动授权、作用章节、授权来源、版本和时间；
- `TemporaryCreativeAssumption`：尚未由用户确认、但为可逆推进暂时采用的假设及替换条件；
- `TaskRun/Checkpoint/UsageRecord`：真实任务、关联小说、当前/已完成步骤、队列位置、暂停原因、上下文、工具、模型、实际用量、费用估计与已用费用、错误、幂等键和恢复点；
- `TaskStatusProjection`：由任务日志生成、供中央对话、“这次结果”和“AI 任务”页共同读取的只读投影，包含人话状态、上次安全保存、可恢复动作和最后同步版本；
- `ResultRetentionStatus`：未采用成果是继续保留、等待放弃确认还是已经放弃；与任务是否运行分开建模，避免“停止任务”等于“删除成果”。

聊天记录不是已确定设定。只有经工具保存和确认的内容才具有治理效力。

意图挖掘状态必须独立持久化和版本化：用户否定一个方向时，相关 `IntentHypothesis` 进入已否定状态并保留反对证据；尚未确认的理解不能升级为 `CreativeDecision.confirmed`；`CreativeUnknown` 记录已问问题和答案来源，防止换词重复；短试写产生的是新证据，不会偷偷改成用户决定。

### 6.3 状态模型

```text
FactStatus:
proposed | workingCanon | confirmedCanon | deprecated | contradicted

TruthScope:
objective | rumor | belief(characterID) | secret(audience)

ChapterStatus:
draft | calibrationReview | rejected | approvedFrozen
| workingCanon | invalidated | superseded

CalibrationDiagnosisStatus:
ambiguousRejection | diagnosing | validatingHypothesis | actionable
| impactReview | rewriting | calibrationReview

DiagnosisCandidateStatus:
hypothesized | userConfirmed | userRejected | unresolved

ChapterApprovalIntentStatus:
none | ambiguousApproval | explicitApproved | continueCalibration

ContinuousCreationAuthorizationStatus:
notEligible | eligibleNotAuthorized | authorized | revoked

CreativeDelegationStatus:
notGranted | granted | revoked | expired | superseded

MajorDecisionGateStatus:
notApplicable | coveredByGrant | pauseRequired
| awaitingUser | authorizedForExecution | executedAndReported

TaskStatus:
queued | running | waitingNetwork | waitingUser
| paused | stopped | failed | completed | cancelled | reconciling

ResultRetentionStatus:
notApplicable | retainedUnadopted | discardPending | discarded

PauseRequestMode:
finishCurrentChapter | stopNow

PartialChapterOutputStatus:
none | temporaryIncomplete | discarded | superseded

PauseReason:
networkUnavailable | appSuspended | providerBusy | budgetLimit
| majorStoryDecision | waitingForUser | recoverableError | unknownOutcome
```

用户默认看到的翻译：

| 内部状态 | 默认显示 |
|---|---|
| proposed | 还在讨论 |
| workingCanon | 后续正在按这个写，但你还没最终确认 |
| confirmedCanon | 已经确定 |
| approvedFrozen | 这章确定了 |
| waitingUser | 等你决定 |
| paused | 已经暂停，进度已保存 |
| stopped + retainedUnadopted | 已停止，刚才生成的内容还保留着 |
| discardPending | 准备放弃这些未采用内容，等你确认 |
| reconciling | 正在确认刚才是否真的完成，暂不重复执行 |

故事记忆是上述后台状态面向普通用户的受控投影，不复用这张通用状态表。故事记忆条目只显示“已经确定 / 暂时这样写 / 还没决定 / 已被新内容替代”，人物知识只显示“现在知道 / 还不知道 / 错误地以为”。

### 6.4 上下文与记忆

`ContextCompiler` 为每次任务选择最小必要上下文：

- 当前用户意图和任务；
- 当前章节计划；
- 已确定世界规则、人物状态和知识边界；
- 最近正文和分层摘要；
- 未兑现伏笔和读者承诺；
- 相关研究卡；
- 已确认的参考画像、用户授权来源、本书偏好，以及仍待确认或已撤销的交互偏好证据；
- 软反馈和可纠正偏好推测，并明确一次性、本书、跨项目范围；
- 当前 `SelectionAnchor`、用户原话、明确 `HardTextLock`、最新 `ManualEditVersion`、`HumanEditProvenance` 和待集中处理的 `DeferredImpactAssessment`；
- 当前模糊拒绝、`CalibrationDiagnosis`、候选原因、支持/反对证据、用户确认/否定边界和最近 `DiagnosticSample`；
- 与本次修改相关的 `ActionableClarity`、`RewriteAuthorization`、`EditImpactPreview`、依赖图、已通过版本和选择性重生成计划；
- 当前章节的 `ChapterApprovalIntent`、一次澄清状态、冻结事务回执，以及第三章后的 `ContinuousCreationAuthorization` 生效/撤销边界；
- 与当前决策类别和小说/卷/章节范围相交的 `CreativeDelegationGrant`、撤销历史、`MajorDecisionProposal`、关联 checkpoint 和尚未告知的 `MajorDecisionExecutionNotice`；
- 当前任务的 `NarrativeQueryPlan`、`IndexCoverage`、原文版本、命中 `SourceSpan`、证据扩大轨迹和未确认边界。

`ContextCompiler` 通过叙事索引做自适应查询，而不是固定抓最近若干章或每次扫描全书。默认检索路线为：

```text
当前段落 / 场景
→ 当前章节
→ 相邻章节与当前卷
→ 相关人物 / 事件 / 认知 / 伏笔 / 时间线 / 状态
→ 全书范围
→ 必要时研究资料
→ 仍不足：暂时无法确认
```

查询规划器按任务类型和写错风险组合 FTS5、轻量向量、章节顺序和结构关系，并受 token、延迟、费用及索引覆盖约束。证据不足时自动扩大范围并审计“为什么扩大、扩大到哪里、用了哪些版本”；涉及人物认知、事件发生、时间因果、能力/资源、伏笔、已通过正文、人工改稿或研究依据的重要结论，必须回到不可变原文 `SourceSpan` 复核。摘要、向量相似结果、结构抽取和 LLM 推测只能帮助找候选，不能单独升级为已确定事实。

故事记忆的更新输入必须至少覆盖对话、已采用结果、已通过正文、用户改稿、已采用研究资料和章节结算。投影按“这本书现在讲什么、主要人物、世界规矩、现在写到哪里、后面不能忘的事、还没有决定”组织；每条重要内容保留可展示的人话来源和后台证据链。AI 推测只能进入未确认状态，不能污染已确定事实。

用户纠正故事记忆时，Typed Tool 先做冲突与影响分析：局部无冲突变更可直接提交并告知；触碰已通过正文、人物知识链、承诺窗口或大量后续计划时，生成 proposal、影响范围和受治理修改方案，等待用户决定后再合并。

保存上下文资产 ID、版本和哈希。顺序强制为：

```text
用户明确批准当前精确版本
→ 保存并冻结正文版本
→ 结算故事记忆/时间线/人物知识/线索与承诺
→ checkpoint
→ 下一章
```

### 6.5 自动连载治理

- 前三章逐章由用户明确确认，用于校准；按钮和明确自然语言批准等价，含糊肯定必须一次澄清；
- 第三章通过后只进入“可申请连续创作”，不得自动开始第四章；
- 仓颉说明费用、领先范围和分级创作授权机制后，只申请一次连续创作授权；授权后普通章节不再机械逐章询问，未授权时保持可阅读/修改；
- 获得授权后默认连续准备 3 章，用户可用自然语言或设置调整为 1–5 章；首版最多保持 5 章尚未阅读的领先版本；
- 正文严格按章顺序生成，同一时间只有一个 Writer owner；当前章必须完成审校、临时故事记忆结算和 checkpoint，下一章才能开始正文；研究/只读审校可并行但不得获得正文写权限；
- 每章进入 Writer 前先过“章节前计划门”，确认当前计划、相关故事硬规则、人物知识、本章承诺、研究覆盖和本次偏好证据版本；计划门不能替用户批准重大剧情；
- 每章正文后先由独立的全局故事审校器检查硬规则、人物知识、连续性、因果、时间、承诺和题材纯度，再由影子用户在看不到该审校结论的盲读模式下做用户偏好预审；两个角色必须分离，不能相互提示答案；
- 影子用户只能预测、排序、预审、弃权和建议暂停，不能正式批准章节、合并故事记忆/正典或代替重大剧情授权；其预测必须在用户真实反馈后校准，不能用 AI 自己生成的版本反向强化；
- `DriftSignal` 同时看本章偏离和累计漂移：正常时继续；黄色时减少本轮领先章数、缩小生成窗口并提前请求真实反馈；红色时在安全 checkpoint 暂停并给出证据和恢复动作；黄色/红色阈值必须可版本化、可评测，不能只靠单次 LLM 自报分数；
- 未读自动章节标记为“仓颉准备的版本，等你看”，可以进入工作上下文，但不得升级为 `approvedFrozen` 或 `confirmedCanon`；
- 普通、可逆且不改变整书方向的决定直接执行并告知；
- 重大变化在执行前按类别和小说/卷/章节范围解析 `CreativeDelegationGrant`；已覆盖时绑定授权版本执行并醒目标记，未覆盖时先保存 checkpoint，再展示带原因、影响、2–3 个方向、推荐和单个问题的暂停卡；
- 用户可用自然语言查看、授予、缩小和撤销分级授权；撤销后尚未执行的重大变化重新进入暂停门，已执行决定保留版本和影响记录；
- 单章完整流水线默认目标为 10–20 分钟、5–20 元人民币；用户可设置更低硬上限，预计或实际达到硬上限时必须暂停；
- 费用硬上限、任务完整性、工具权限、安全、外部数据披露、版本/幂等/checkpoint 以及真实硬冲突不能被创作授权绕过；
- 用户退回较早章节或从中间选区发起修改时，选区只作为分析起点；保留旧分支，先检查句子、场景、整章、后续章节、已通过正文和人工改稿的依赖，再生成影响范围预览；只重生成受影响的工作内容；
- 未通过工作内容按依赖选择性重生成；已通过正文保留旧版本并建立分支后由用户裁决；人工改稿优先，不能被旧生成稿覆盖；
- 修改按依赖顺序重连，并重新检查人物知识、时间、因果、线索/读者承诺和题材规则；
- “写完这一章暂停”在当前章完整结算与 checkpoint 后停止；“现在暂停”立即取消当前请求，残缺输出只作临时内容；恢复必须按任务/章节/幂等键/UsageRecord/checkpoint 对账，禁止重复生成或重复扣费；
- 不得因为“爽文公式”自动贬低慢热、悲剧、扁平弧等用户明确选择。

---

## 7. iPad 技术架构

### 7.1 客户端

- SwiftUI 原生 App；
- `CangJieCore` 使用 Swift Package 和 Swift 5 语言模式；
- iPadOS deployment target 16.6；
- SQLite/GRDB，使用事务、WAL、迁移、FTS5 中文全文检索、章节层级/关系表和本地轻量向量索引；叙事索引通过可恢复任务渐进构建；
- Keychain 保存 API Key；
- PDFKit、Vision、URLSession 和系统文件能力由 App 适配层提供；
- 不依赖 iOS 17 SwiftData 或持续后台运行能力；
- 首版不引入 Neo4j、Qdrant、完整 GraphRAG/LightRAG 服务、重型外部图数据库，也不要求云端知识图谱才能离线阅读、检索和恢复；
- 横屏与竖屏共享同一工作区状态模型，旋转只改变呈现，不重建对话、正文、任务或选区；
- 横屏右侧实现为一个可切换容器，不为“仓颉”和“这次结果”分别创建并排列；
- Activity Bar 图标必须有长按说明、无障碍名称和用途提示；
- 面板显隐、阅读器最大化和竖屏单焦点切换必须持久保存必要 UI 状态。

```text
SwiftUI 对话驾驶舱
→ Application / Agent Orchestrator
→ Typed Tools + Policy + Budget + Approval
→ Novel Domain + Context + Canon + Task Journal
→ SQLite / Keychain / Provider / Search / Import / Export adapters
```

### 7.2 Provider

The platform-neutral `LLMProvider` adapter supports streaming text, structured output, tool calls, cancellation, usage, and standard errors. The product-level connection contract is explicit and simple:

- User-facing connectors: `DeepSeek`, `Claude / Anthropic`, `GPT / OpenAI`, `Gemini`, `OpenRouter`, and `Custom service`.
- Selecting an official connector fills its current official Base URL and model-list endpoint. The user enters a key, CangJie connects, retrieves all models available to that key, and the user selects one model.
- One `ModelConnection` is `Provider + Base URL + Keychain credential reference + selected model`. Multiple connections are allowed, including multiple keys for one Provider. Only one is current, and the user changes it manually.
- No automatic routing, quality/cost/speed modes, model substitution, Provider switching, key rotation, load balancing, or failure takeover. A sent request stays bound to its connection/model. Failure exposes reconnect, refresh models, re-enter key, or manual switch-and-retry only.
- Custom service: user supplies a name and OpenAI-compatible Base URL. Request `/models` when supported; if discovery is unavailable, allow a manually entered model name and show that limitation.
- Credentials are Keychain-only and masked everywhere else. Deleting a connection never deletes story data; when it is current or needed by unfinished work, require an explicit switch or cancellation first.
- No current connection is a supported local state, not an initialization failure. Local thought/draft persistence, local browsing/reading, history, and connection management remain available. The first AI-dependent request is persisted as pending intent and resumes from the same conversation only after explicit connection and model selection; until then no model-backed completion may be claimed.

Default connector registry values:

| Provider | Default Base URL | Model discovery |
|---|---|---|
| DeepSeek | `https://api.deepseek.com` | `GET /models` |
| Claude / Anthropic | `https://api.anthropic.com` | `GET /v1/models` |
| GPT / OpenAI | `https://api.openai.com/v1` | `GET /models` |
| Gemini | `https://generativelanguage.googleapis.com/v1beta` | `GET /models` |
| OpenRouter | `https://openrouter.ai/api/v1` | `GET /models` |

Capability discovery remains runtime evidence, not a reason to create a hidden route. S2 must prove at least one real Provider end to end with Keychain credentials, model discovery, explicit model selection, streaming, cancellation, structured tool calls, tool receipts, usage records, and standard errors. `ProviderRequest` still persists request identity, TaskRun, Prompt/Context/ToolCatalog manifests, selected model, disclosure scope, and stream cursor; unknown outcomes reconcile before any retry.

### 7.3 搜索、研究和导入

- 研究默认由仓颉在立项、章节规划、正文生成前和审校阶段自动判断触发；用户主动搜索是附加入口，不是前置条件；
- 固定知识顺序为本书故事记忆、内置/本地题材知识包、有效缓存、必要时自动联网、来源质量与冲突检查，仍不能确认时诚实说明；
- `KnowledgeGapAssessment` 独立检查内容类型、覆盖、写错影响、时效性、来源可靠度、冲突和题材污染风险，禁止只靠 LLM 自报置信度或每个名词盲搜；
- 题材知识包带来源、版本、更新时间、适用范围和冲突关系，区分传统/公开事实、网文常见约定、不同流派、冲突说法和本书选定规则；题材包不是正典；
- 用户只说想写洪荒等题材时，自动建立题材研究包，只把会真正改变创作方向的少数冲突交给用户；
- 用户可关闭联网、限定只用本地资料、设置研究预算、指定优先资料、忽略来源或要求重新研究；关闭联网后任何 Provider 和 Agent 都不得偷偷联网；
- Tavily、Brave、模型原生搜索和 URL Reader 均通过 `SearchProvider`、预算与来源治理；
- TXT、Markdown、DOCX、PDF、ZIP；文本 PDF 使用 PDFKit，扫描 PDF 使用 Vision 离线 OCR；
- ZIP 先清点，再防路径穿越、符号链接逃逸、压缩炸弹、同名碰撞和异常文件；每个文件明确显示成功、部分成功、需校对、不支持或失败；
- 网页、搜索结果、文档、题材包和模型输出均为不可信输入，不能修改 Agent 权限、系统提示、工具策略或直接写入故事记忆“已经确定”；
- 外部内容先写入不可变原文层，再做提取、FTS5、向量和结构索引；所有抽取、研究结论和故事记忆都保留可回到原文的证据位置；
- 导入后自动先做免费、本地、快速基础索引：安全清点、格式识别、不可变原文、文本提取、FTS5、章节/页码/段落定位、哈希和重复识别；该阶段不调用付费模型、不向外部 Provider 发送材料；
- 任何联网深度理解首次都先展示发送范围、Provider/模型、处理目的、预计费用/预算和后续增量许可，并获得用户明确授权；授权只覆盖声明范围，实质变化必须重新授权；
- 授权后优先分析当前任务需要的部分，并以 `MaterialAnalysisCursor` 增量处理；新增/修改内容只重算受影响范围，暂停/恢复幂等，不重复外发、分析整本书或扣费；
- 所有资料先进入统一 `EvidenceIndex` 的原文/版本/定位/哈希/基础检索层，再按类型进入 `NarrativeIndex`、`ResearchIndex`、`ProjectMaterialIndex` 或 `PreferenceIndex`；自动分类不可靠且错误影响明显时才询问用户；
- 混合 ZIP 按文件分类，混合文件按 `SourceSpan` 片段分类；查询严格受项目、资料类型、用途、确认状态、Agent/工具权限和外发授权隔离；
- 基础索引完成后，后台或按需渐进建立对应类型的场景/人物/事件/认知/状态/伏笔、来源冲突、项目意图或偏好抽象、向量和关系索引；中断后从 `IndexBuildCheckpoint` 恢复，界面显示真实覆盖与新鲜度；
- 外部内容先提取、来源核验、冲突检查，再由采用治理决定是否成为本书参考或规则；参考资料不自动成为本书设定，参考小说不得作为事实来源；
- 用户主动上传且有权使用的参考作品可以保留为受权限约束的原文证据，只用于抽取结构、节奏、视角、叙事距离、人物塑造和信息顺序等抽象特征；每条特征带证据，用户确认后才进入偏好；不得复刻具体表达、长段落、独特桥段或版权正文；
- 对未获授权的版权作品只分析公开简介、评论、结构特征和必要短引用，不抓取、收录或复制完整正文。


### 7.4 中断恢复

- 正文大资产先按内容 hash 预写；随后在单个 SQLite 事务中校验 Writer Lease fencing token 和目标版本，并原子提交 ChapterVersion、故事状态、人物知识、伏笔/承诺、UsageRecord、幂等结果、ToolReceipt、资产引用和 checkpoint 记录/当前指针；事务后不得再补写决定恢复位置的 checkpoint；
- App 切后台、锁屏或检测到断网前，生命周期保存屏障必须持久化输入草稿、`TaskRun` 真实阶段、Provider 请求身份/状态、已收流式片段与游标、已产生用量/费用和最近安全继续位置；这只保证可恢复，不承诺 iPadOS 16.6.1 无限后台运行；
- 返回前台或条件恢复后，只能从真实 `TaskRun` 和最近 checkpoint 恢复，并明确投影为已完成、安全暂停、明确失败、结果未知或连接失效，不能由模型根据聊天内容猜测进度；
- 未知结果先执行不产生新创作请求和费用的 reconciliation，核对原请求身份、本地事务、流式片段、UsageRecord 与 ToolReceipt；结果仍未知时禁止直接重试，相同幂等键只能返回原始历史结果；
- 断网时本地项目、正文、资料、草稿、导出小说和备份项目继续可用；断网期间产生的新 AI 请求只保存为等待网络，网络恢复后必须由用户确认才发送；断网前已经发送的请求可以自动核对原请求状态；
- 中断的流式输出只保存为未完成临时产物，不得进入正式 ChapterVersion、canon、人物状态、伏笔/承诺结算或领先章节计数；
- 安全暂停保留恢复能力；`现在暂停` 立即取消当前请求并隔离残缺输出，`写完这一章后暂停` 在本章完成审校、临时结算和 checkpoint 后停止；结束并保留成果与放弃成果继续走各自受控状态；
- 同一时间只运行一个主要创作任务，后续请求进入持久化队列，或在会改变作品方向时先询问；同一本小说正文同一时间只有一个 Writer owner；
- Provider 失败只允许重连当前命名连接，或等待用户手动选择其他已保存连接；不得自动切换 Provider、模型或 Key；
- 每次状态变化由追加式事件/不可变版本和事务性当前投影共同记录；无法纳入 SQLite 的外部副作用通过 transactional outbox 执行，使任务日志、checkpoint、费用和对话/“这次结果”/“AI 任务”页保持同源；
- 通知只投影结果完成、等待确认、任务暂停/失败、费用上限和重大剧情门；首次启动不索取权限，首次长任务时解释后再请求，拒绝不影响任何功能；
- 不重复扣费、不重复追加正文、不丢未发送输入，也不把未采用成果误标成已批准；高级诊断只暴露脱敏模型/Provider、实际用量、重试、checkpoint、来源、错误码和恢复状态，不暴露提示词、Key 或思维链。

### 7.5 安全与隐私

- API Key 只进 Keychain，不进数据库、日志、导出包或 Git；
- 日志写入前脱敏 Authorization、Key、Cookie 和凭证字段；
- 自定义 Base URL 默认 HTTPS；
- Skill 只能是受验证 Markdown/JSON，只调用白名单内置工具；
- 首版禁止第三方代码、Shell、任意文件操作和直接写入已确定设定；
- `cc.zip` 为 private/unlicensed 非官方材料，不进入仓颉仓库、构建、测试或 Prompt；后续实现仅依据官方公开资料、仓颉原创需求和独立 ADR，禁止复制或近似改写源码、提示词、名称组合、Schema、字符串、注释、目录结构或测试；该流程只能称为 clean-room-inspired 风险控制，不宣称获得法律 clean-room 认证；
- 公开仓库暂不授予开源许可。

---

## 8. 分阶段实施与用户可见成果

详细真机验收地图见 `docs/MILESTONE_VISUAL_ACCEPTANCE.md`。

### S0：技术可行性基线（已完成，仅代表技术证据）

已验证：Windows Core 测试、GitHub Actions iOS 构建、TrollStore 安装、App 启动、本地写入、覆盖保留、基础恢复、受治理审批和第一章技术闭环。

candidate-hardening 历史 M1 与 Build 26–28 只作为工程原型和硬化证据，不是当前完整产品里程碑；Build 28 未通过完整真机验收。固定三问、关键词意图、段落 Lock/Unlock、工程字段和诊断页均不是目标 UX。

### S1：Agent 驾驶舱定调与重构

可见成果：

- 新欢迎页和中心仓颉对话；
- S1 发送内容只验证输入、持久化和消息布局：保存用户原话并显示明确标注的“界面预览版”系统回执，不调用真实 LLM、不解释意图、不执行工具，也不冒充仓颉已经理解；普通消息不得自动创建空小说或伪造“这次结果”卡片；真实模型闭环从 S2 开始；
- 左侧包含“新对话”、历史标题、最近时间、当前高亮和独立功能页面导航；小说图标打开只含标题/大白话进度/最近时间的书架，书籍详情只在左侧 push，浏览不切换当前创作上下文；入口按真实能力和数据状态显示，不放死页面；
- 横屏正文工作台采用约 2/3 阅读器 + 约 1/3 单一右侧区域，右侧用“仓颉 / 这次结果”标签切换，不增加第四列；
- 竖屏采用“阅读 / 仓颉 / 这次结果”单焦点切换；
- 最左侧 Activity Bar 只显示图标，长按显示名称和用途；
- 人话状态和确认；
- 专业字段默认隐藏；
- 现有数据和恢复能力不丢失。

退出标准：一个从未使用过写作软件的人，不看说明也知道可以直接输入一个念头；书架、书籍详情、右侧结果和中央对话互不破坏状态；浏览或阅读其他书不会偷换当前创作上下文。

### S2：真正可操作软件的 Agent

可见成果：

- 从无 Key 状态在中央对话内完成“选择具体 Provider → 填写 Key/Endpoint → 测试连接 → 获取该 Key 可用模型 → 用户手选模型 → 保存并明确选为当前命名连接 → 回到原对话继续原任务”；API Key 只由 Keychain 保存；
- 至少接通一个真实 LLM Provider；
- 对话支持真实流式输出、取消、用量记录和错误恢复；
- 模型通过结构化 Tool Call 创建小说、查看项目、保存刚才讨论、查询进度和切换项目；对话先持久化，达到明确继续、首个长期正式成果、需要故事记忆或开始正文等条件时才无表单建书；
- 一本小说可关联多次对话，一次对话同一时刻只有一个主要小说上下文；书架浏览和正文阅读不自动绑定，只有继续创作、从该书正文问仓颉、继续相关历史对话或明确切换时才绑定并提示；发现明显的新书念头时先建议单独保存，未经确认不得污染当前书；
- 工具结果回传模型，并以大白话和可展开回执显示；用户可在对话里命令采用、打开、移除或总结真实产物；
- 至少有一个可暂停、恢复和失败对账的真实受治理任务，例如把当前讨论整理为“作品起点”；
- AI 任务页只用“正在做 / 接下来 / 需要你”组织普通步骤，并在下方显示上次安全保存、真实估计/已用费用、暂停原因和恢复动作；对话查询必须来自真实任务状态源；
- 安全暂停、结束并保留成果、谨慎放弃未采用成果语义和权限分离；
- 同一时间一个主要创作任务，同一本小说只有一个正文 Writer，其他请求进入队列或先询问；
- 切后台、锁屏、断网、五类恢复、离线新请求确认发送、已发送请求对账和可选通知必须按 CJ-PX-006 通过真实状态验收，不承诺 iPadOS 16.6.1 无限后台运行；
- 对话、“这次结果”和“AI 任务”页共享状态投影；
- 高级详情折叠且脱敏，不显示虚假百分比、完整提示词、Key 或思维链；
- 固定关键词解析器和预写死回复不得作为验收实现；
- S2 不生成或验收正式正文，只证明最小真实 Agent 软件闭环。

退出标准：关键动作不需要用户进入工作台；真实模型不能凭文字冒充执行或任务状态；状态查询、暂停、保留成果、放弃成果、恢复、队列和三处同步通过真实状态源验收；断网、重复点击、重启和未知结果不产生重复状态或费用；重大不可逆和预算越界仍暂停。

### S3：动态灵感挖掘与作品方向

可见成果：

- 从一句模糊念头或“我没想法”开始；
- 运行“理解一点 → 做一点 → 让用户看见 → 再继续理解”的动态循环，一次只问一个会改变下一步决定且容易回答的问题；
- 通常约 2–4 个高价值问题后给画面、候选或微型试写，但不得硬编码题数；达到可行动阈值、继续追问收益低、用户疲劳/要求直接做或决定低风险可撤销时停止追问；
- “不知道”时换成具体画面、差异对比、阅读经历、反向排除或可撤销临时决定；
- 自动总结“我目前对这个念头的理解”；明确区分用户原话、用户已确认、AI 推测和关键未知；
- 用户可逐项纠正或一句话否定；
- Agent 持久化证据、候选理解、已否定方向、待确定问题和用户自主程度，不靠固定问卷维持状态；
- 基础资料能力可由 Agent 调用：TXT、Markdown、文本型 PDF、URL Reader、基础搜索和来源追踪；本阶段只承诺常规规模资料，不得冒充百万字资料或大型参考小说的完整理解；
- 仓颉在立项阶段自动评估知识缺口并建立或加载题材知识包；用户主动搜索只是额外入口；
- 用户只说“想写洪荒”时也能自动完成题材包、来源与冲突整理，只把真正改变方向的少数分歧交给用户；
- 用户可以关闭联网、限定本地资料和设置研究预算，状态与详细来源分别进入对话轻提示和资料/研究页；
- 上传资料先自动完成免费、本地、快速基础索引；任何联网深度理解首次展示发送范围、Provider/模型和预计费用并明确授权，之后只在授权范围内增量处理，支持暂停/恢复且不重复分析整本书；
- 统一 Evidence Index 保存原文、版本、定位、哈希、基础检索和证据回链，并自动把小说、事实参考、用户项目资料和正反样本/偏好路由到四类专用理解器；混合 ZIP 可按文件/片段分类；
- 检索受项目、资料类型、用途、确认状态、权限和外发授权隔离；资料可作为意图挖掘上下文，但未经确认不能直接进入已确定设定，参考小说不得作为事实来源；
- 探索期可随时生成 100–300 字画面、小样、开场、能力代价或章节结尾候选，不要求先完成完整策划；
- “这次结果”只收集可阅读、采用、修改、继续执行或长期保存的真实产物；普通追问不生成卡片，采用后由 Typed Tool 写入正确位置并保留可追溯来源；
- 用户授权参考资料后形成带来源、可逐项确认/撤销且可设置本书或跨项目范围的抽象参考画像；
- 从多轮交互渐进记录沟通与决策偏好，但一次选择不升级为永久偏好，普通界面明确说明这不是训练或微调模型。

退出标准：真实普通用户无需理解“主线、爽点、制作圣经、正典”，也能形成足以启动第一章、并让前三章不会立刻失去依据的方向；探索小样不受完整策划门槛限制；第一章前只需看懂一张“我准备这样写”，可用按钮或自然语言授权；连续否定后不会重复旧问题；AI 推测不会冒充用户决定；对话持久化但不制造空书；真实产物可从对话直接采用并正确归档；自动研究遵循固定知识顺序、联网/本地/预算策略和来源冲突治理；上传后基础索引无需联网或付费，首次联网深度理解有发送范围/Provider/模型/费用授权，后续增量处理与恢复不重复分析整本书；统一 Evidence Index 与四类专用理解器路由、混合资料分类和六维检索隔离通过固定夹具，参考资料不自动成为本书设定，参考小说不作为事实来源。

### S4：连续正文、自由反馈与前三章校准

可见成果：

- 完整第一章前只展示一张大白话“我准备这样写”，包含故事感觉、主角处境、本章事件、结尾所得、明确避免和未定内容；
- 点击“就这样开始”或说“开始写第一章 / 你替我决定 / 直接写”等明确指令即可授权，未定内容保留为可撤销临时假设；
- 后台运行计划→研究覆盖→写作→人物知识/连续性/题材纯度/AI 味检查→有限修正→checkpoint；
- 第一章直接在对话中交付并进入连续阅读，生成后只标“供你看看”，不自动冻结或进入故事记忆“已经确定”；
- 横屏显示正文约 2/3、右侧约 1/3，右侧在“仓颉 / 这次结果”间切换；竖屏使用单焦点切换；
- 自由选字后的第一层只显示“复制 / 问仓颉 / 更多”；选区只表示讨论焦点和修改起点；
- “更多”中的“这段我喜欢 / 这个感觉别丢 / 只讨论这段 / 标记为问题”是软反馈；只有明确“锁定文字不变”或“这句一个字都不要动”才创建硬锁定；
- AI 对喜欢原因只能提出可纠正推测，用户可以直接否定和改写；
- 修改前展示句子、场景、章节、后文、已通过内容和人工改稿的影响，并提供“连带改顺后面 / 只改这里但可能不连贯 / 另建版本试试 / 先别改”；
- 工作内容可选择性重生成；已通过正文必须分支裁决；人工改稿优先；修改后重查人物知识、时间、因果、承诺和题材规则；
- 默认通过选区/引用、大白话和 Agent 完成校准；手动编辑只是次级兜底，不手改也能完成前三章；
- 手动编辑自动保存新版本并保留旧 AI 稿，人工文字优先但不自动通过章节；编辑中不逐字弹窗，离开编辑或继续任务前集中做影响分析；
- 用户只说“这章不对劲 / 我说不上来”时先给 2–3 个大白话候选原因或画面对比，一次只问一个问题，必要时用 100–300 字可撤销小样验证；达到可行动清晰度后先反映理解、展示影响范围，再执行完整修改；
- 诊断候选保持为 AI 推测，只有用户确认后才成为正式修改依据；禁止原因表格和盲目整章重抽；
- 前三章逐章明确确认；章节结果页以“就按这版继续 / 和仓颉聊聊”和自然语言为主，含糊肯定只澄清一次；
- 每章通过后按“冻结精确版本→结算故事记忆/人物知识/线索→checkpoint→下一章”推进；
- 第三章通过后只显示一次连续创作授权说明，不自动开始。

退出标准：第一章启动只需一张人话准备结果和明确按钮/自然语言授权；完整流水线有研究覆盖、有限修正和 checkpoint 证据；生成后的章节只供查看，用户通过后才冻结正文并结算人物、世界、线索与下一章；前三章均可用轻量按钮或明确自然语言逐章通过，含糊肯定不会误冻结，每章冻结/结算/checkpoint/推进顺序可追溯；第三章通过后仍停在可阅读/修改状态，等待一次连续创作授权；用户只需像读者一样选中文字并说感觉；选区不会静默变成喜欢或硬锁定；软反馈和明确硬保护互不混淆；每次拒绝至少沉淀负向证据，并得到“已确认规则 / 待验证假设 / 仍不确定但将用短试写继续判断”之一，禁止为了过门槛编造确定规则；修改影响预览、选择性重生成、人工改稿优先、已通过正文分支和依赖重查均有真实工具与版本证据；默认界面无复杂章节审批表、机械分段锁定、强制喜欢/不喜欢分类和固定三问。

### S5：滚动自动连载与长篇治理

可见成果：

- 第三章通过后，仓颉先解释连续创作默认 3 章、可调 1–5 章、最多 5 章未读领先、费用和分级创作授权，只申请一次连续创作授权；未授权时不启动，授权后普通章节不再机械逐章确认；
- 单 Writer 严格逐章生成，每章审校、临时故事记忆结算、checkpoint 后才开始下一章；未读章只标“仓颉准备的版本，等你看”；
- 普通可逆决定直接执行并告知；重大变化按类别和小说/卷/章节范围解析授权，未覆盖则 checkpoint 后暂停，已覆盖则执行后醒目标记；
- 暂停卡必须包含原因、影响范围、2–3 个具体方向、仓颉推荐和一次一个容易回答的问题；
- 分级创作授权可用自然语言查看、授予和撤销，完整版本化；费用、安全、权限、任务完整性和外部数据披露永远不可委托；
- 用户说“继续写”“写完这一章暂停”“现在暂停”“到这里就结束，刚才的留着”“这次只准备一章”“现在到哪了”“为什么停了”“还能恢复吗”即可控制；
- 所有状态回答调用真实任务状态源，普通任务页只显示“正在做 / 接下来 / 需要你”，并补充上次安全保存、有依据的费用估计/已用费用、暂停原因和恢复动作；
- 安全暂停、结束并保留成果、放弃未采用成果严格分开；
- 中央对话、“这次结果”和“AI 任务”页始终显示同一真实状态；
- 同一时间只跑一个主要创作任务，其他生成进入队列或先询问；
- 最多领先 5 章；
- 网络、App 挂起、模型繁忙、重大事件和预算越界用大白话暂停并说明 checkpoint；
- 用户可从旧章或中间选区发起修改，查看真实影响范围并保留旧分支；
- 故事记忆由对话、采用结果、通过正文、用户改稿、资料和章节结算自动维护，用户不必填写设定表；
- 故事记忆用六个大白话分组、四个有限状态和“现在知道 / 还不知道 / 错误地以为”展示，可追溯来源并接受人话纠正；
- “后面不能忘的事”同时管理线索、期待画面、人物/读者承诺、当前卷目标和待回归人物；
- 局部无冲突小改动直接执行告知；涉及场景、整章或后文时先展示修改影响范围，允许选择性重生成；触碰人工改稿时以人工文字为当前依据，触碰已通过正文时建立分支并让用户裁决；
- 修改完成后按依赖顺序重连后文，并重新检查人物知识、时间、因果、承诺和题材规则；
- 正式验收百万字叙事索引，以及大型参考小说按范围、阶段、checkpoint 和费用边界渐进分析；未完成覆盖的部分必须明确显示，不得冒充已理解全书。

退出标准：默认连续准备 3 章且可调整为 1–5 章，任何时候不超过 5 章未读领先；单 Writer 严格逐章并按“审校→临时故事记忆→checkpoint→下一章”交接；未读章不冒充确认；两种暂停语义和残缺输出隔离正确；恢复幂等且不重复扣费；连续自动生成至少 5 章；网络、挂起、Provider 繁忙和未知结果中断均可从 checkpoint 恢复且不重复扣费或生成；查询状态绝不靠模型猜测；三处状态一致；单主要任务和队列生效；安全暂停、保留成果和放弃成果语义及权限分离；普通决定无确认骚扰；未授权重大变化在 checkpoint 前暂停并给出完整低负担暂停卡；按类别/卷/章节授权可查看、撤销、版本化，已授权重大决定执行后醒目标记；任何授权都无法越过费用、完整性、权限、安全、外部披露和版本治理硬边界；无已知硬性设定冲突、人物知识越界和题材污染；退回中间章节不会破坏旧分支；选区不会被误当最终边界；工作内容只重生成受影响部分；人工改稿不被旧稿覆盖；触碰已通过正文必须建立分支并裁决；修改后人物知识、时间、因果、承诺和题材规则重新检查通过；故事记忆能随正文和用户改稿自动结算，AI 推测不冒充已确定内容，大范围记忆修正不会静默破坏已通过正文。

### S6：质量、增强资料、导出与候选正式版

可见成果：

- AI 味、重复、人物、时间线、钩子、节奏和题材纯度检查；
- 在 S3 常规规模资料能力和 S5 大型索引/分阶段分析之上，完成 TXT、Markdown、DOCX、文本 PDF、扫描 PDF OCR、ZIP、百万字资料的正式处理验收，以及大文件失败报告、缓存/冲突可视化和完整研究中心；
- `导出小说` exports clean current-mainline TXT/Markdown/DOCX; `备份项目` saves the complete recoverable project state as a separate artifact without credentials;
- Optional backup password protection must warn that forgotten passwords cannot be recovered; Face ID and log cleanup remain separate settings;
- 发布前字数、标题、空行和敏感词提示；
- 性能、存储、电量、横竖屏、键盘和无障碍优化；
- 完成项目迁移、恢复、安全审计，并形成绑定精确身份与证据的正式候选。

退出标准：真实章节中至少 80% 无需整章重写，用户人工润色约 10 分钟以内；自动化覆盖达标；无高危安全问题；真实 iPad 长时间稳定。

### Agent Harness H0–H5 横向工程关卡

H0–H5 是贯穿 S1–S6 的底层验收门，不是额外页面，也不能被“模型效果看起来不错”替代：

- **H0 数据边界与可重放夹具**：分离 ConversationSession、AgentTurn、TaskRun、ToolCall、Artifact、Checkpoint、ProviderRequest、UsageRecord、ChapterVersion 和 CanonTransaction；建立确定性时钟、脱敏事件和 fixture；
- **H1 DriverRuntime + PromptRuntime**：Provider 能力探测、统一流式事件、取消/错误/用量/结果对账、分层 Prompt 和 manifest；
- **H2 ContextRuntime**：小说一级上下文槽位、authority/disclosure/token reason、Evidence Index 检索、证据不足时受控扩大和可重现 manifest；
- **H3 LoopRuntime + ToolRuntime**：显式 Observe/Decide/Act/Verify 状态机、硬限制、no-progress 检测、proposal/commit、事务、ToolReceipt 和结果回灌；
- **H4 TaskRuntime + checkpoint**：队列、两种暂停、恢复、unknown outcome 对账、费用和三处同源状态；
- **H5 AgentTeam/Governance/Observability**：子 Agent 隔离、只读并行、Writer Lease、唯一合并权、PreferenceProxy 权限拒绝和脱敏状态投影。

阶段映射：S1 只冻结驾驶舱和工程合同，不冒充 Harness 关卡通过；S2 至少通过 H0、H1、H2、H3 对应的最小真实闭环；S3 推进 H4 主干；S4 完成 H4 并进入 H5；S5 完成 H5；S6 对全部已通过关卡做正式候选级的跨 Provider、恢复、安全、迁移、费用、性能和长时间回归。H0–H5 必须按顺序推进，不得跳级，也不得把某个 Harness 空壳单独包装成 IPA 里程碑。
### 用户偏好代理 P0–P5 横向里程碑

该路线横跨 S2–S6，不取代产品阶段，也不得跳过证据基础直接制作“数字分身”演示：

- **P0 事件 / 证据数据基础**：建立明确表达、选择、拒绝诊断、最终通过版本、授权参考资料抽象特征和交互习惯的事件模型；完成三层范围、支持/反证、版本、撤销和用户确认字段；
- **P1 被动画像**：实现可查看、可纠正、可撤销的非参数化偏好画像、检索和 `ContextCompiler` 注入，不做自动决策；
- **P2 影子预审**：实现候选比较、接受/拒绝预测、盲读 `BookReaderProxy`、主动弃权和与全局故事审校器隔离；
- **P3 连续生成防偏**：把章节前计划门、章后双审校、累计漂移、黄色缩小窗口和红色 checkpoint 暂停接入连续生成；
- **P4 真实反馈校准**：用用户真实选择、拒绝诊断、最终通过和撤销结果校准预测，监控漏报、误报、过度打扰和错误自信；
- **P5 轻量模型评估**：仅当非参数化基线、独立留出集和真实用户抽样都已建立，且轻量排序器/偏好模型稳定带来净收益时再评估；首版不承诺实现，更不默认采用蒸馏或 LoRA。

---

## 9. 质量与测试

### 9.1 TDD

新状态机、工具、批注、正典变更、Provider 和导入功能先写失败测试，再最小实现，再重构。目标：

- `CangJieCore` ≥ 90%；
- 整体可执行代码 ≥ 80%；
- 单元、集成和关键 UI/E2E 都必须存在。

### 9.2 Agent 专项评测

建立固定普通用户夹具：

- 用户只有一句模糊念头；
- 用户连续说“不知道”；
- 用户否定所有建议；
- 用户只能描述一个画面；
- 用户只圈选文字但不写原因，随后提问、软反馈或要求修改；
- 用户圈选后什么都不做，验证系统不会自动创建喜欢、问题或硬锁定；
- 用户说“这段我喜欢”但纠正 AI 对喜欢原因的推测；
- 用户明确说“这句一个字都不要动”，随后发起会波及该范围的重写；
- 用户从中间一句发起修改，但真实依赖延伸到场景、章节结尾和后续章节；
- 用户选择“只讨论这段”或“只改这里但可能不连贯”；
- 用户人工改过后文，同时存在较旧的 AI 生成版本；
- 用户要求修改已通过章节并比较原分支与新分支；
- 用户要求查询真实状态、安全暂停、结束并保留成果、谨慎放弃成果和恢复；
- 用户在一个主要任务运行时又发起第二个生成任务；
- 用户询问网络断开、App 挂起、模型繁忙、预算硬上限或重大故事分歧后的真实保存位置和恢复办法；
- 用户使用模糊指代，如“把刚才那个保存”；
- 用户改变主意但要求保留前半段；
- 用户用人话纠正一条故事记忆；
- 用户要求修改一条会与已通过正文和大量后续冲突的世界规则。
- 用户只说“我想写洪荒”，没有主动要求搜索；
- 用户关闭联网、限定只用本地资料或设置很低的研究预算；
- 内置题材包、缓存和联网来源对同一设定存在冲突；
- 外部网页试图要求 Agent 修改权限、提示词、工具策略或故事记忆；
- 用户在探索期直接要求 100–300 字画面、小样、能力代价或章节结尾；
- 用户不点击按钮，只说“直接写”“你替我决定”或“开始第一章”；
- 第一章生成后尚未通过，随后查询故事记忆和章节冻结状态；
- 用户完全不进入手动编辑，只靠选区/引用和大白话完成前三章校准；
- 用户手动编辑后离开编辑、继续生成或审批，验证新版本、旧稿保留、人工优先和集中影响分析；
- 用户授权个人作品作为参考，逐项确认/撤销参考画像并切换本书/跨项目范围；
- 用户一次说“少问点，先给样例”，验证不会静默升级为永久偏好；
- 用户问“上传小说是不是训练了模型”，验证明确回答首版只做本地记忆、检索和上下文编译；
- 用户只说“这章不对劲，我说不上来”，验证先诊断、给候选、单问题和必要小样，不弹原因表、不盲目整章重抽；
- 用户用“可以 / 继续下一章 / 按这个感觉往下写”批准章节，以及用“还行 / 差不多”触发一次澄清；
- 第三章通过后拒绝自动开写，分别验证未授权保持静止、明确授权后默认准备 3 章、自然语言/设置调整为 1–5 章、未读领先不超过 5 章，以及授权后不再机械逐章询问；
- 连续生成中验证唯一 Writer owner、逐章顺序、每章审校/临时故事记忆/checkpoint 完成后下一章才开始，以及研究/审校并行不取得正文写权限；
- 分别执行“写完这一章暂停”和“现在暂停”，验证前者完整收尾、后者取消当前请求且残缺输出仅作临时内容，恢复幂等且不重复扣费；
- 连续创作中分别触发普通可逆决定、未授权重大变化、已按人物生死类别授权的重大变化、超出授权卷/章节范围的重大变化和授权撤销后的新重大变化；
- 用户用自然语言查看、授予、缩小和撤销某类/某卷/某些章节的代决策权限，验证来源、版本和覆盖解析；
- 模拟费用硬上限、权限拒绝、安全策略、外部数据披露和任务完整性失败，验证任何创作授权都不能绕过。

评测关注：是否真正理解当前状态、是否问了高信息增益问题、是否避免重复、是否正确调用工具、是否保护已确认内容、是否用大白话解释，以及故事记忆是否自动维护、来源可追溯、推测明确未确认、冲突修改先做影响治理。研究专项验证：自动触发而非等用户主动搜索；严格遵循故事记忆→题材包→缓存→必要联网→来源冲突检查；不只靠 LLM 自信；洪荒题材只上报少数方向性分歧；关闭联网、本地限定和预算真实生效；外部资料没有权限和确认写入权。第一章专项验证：探索小样无需完整策划；只出现一张“我准备这样写”；按钮与自然语言授权等价；未定内容可撤销；后台流水线完整且修正有限；生成后只供看，通过后才冻结结算。正文修改专项验证：第一层只有“复制 / 问仓颉 / 更多”；选区只建立焦点和起点；四类软反馈不升级为硬锁定；明确命令才创建硬锁定；AI 偏好推测可纠正；影响预览覆盖句子、场景、章节、后文、已通过内容和人工改稿；三种范围处理选项真实改变执行计划；工作内容选择性重生成；人工改稿优先；已通过正文走分支；执行后重查人物知识、时间、因果、承诺和题材规则。Agent 校准与学习专项验证：完全不手改也能走完校准；手动编辑只作为次级入口并自动保存新版本、保留旧稿、集中分析影响且不自动审批；授权资料只形成可解释参考画像，不复刻版权表达；交互偏好有证据、范围和确认层级；首版不训练或微调模型。模糊拒绝专项验证：先基于上下文内部诊断并给 2–3 个大白话候选，一次只问一个问题，必要时生成可撤销小样；达到可行动清晰度后先反映理解和展示影响范围；候选原因不冒充用户确认；不得弹原因表或直接盲目整章重抽。任务专项还要验证：仓颉回答“现在到哪了”时确实调用真实状态源；对话、“这次结果”和任务页一致；不伪造百分比；暂停后有 checkpoint；保留成果不等于采用；放弃动作不删除已采用内容；高级详情不泄露提示词、API Key、Cookie 或思维链。分级授权专项验证：普通决定直接执行告知；重大变化先做类别/范围/版本覆盖解析；未覆盖暂停卡包含原因、影响、2–3 方向、推荐和单问题；已覆盖执行后醒目标记；授权可查看、撤销和版本化；一次选择不升级成永久权限；费用、完整性、权限、安全、外部披露及版本治理硬边界始终优先。

### 9.3 用户偏好代理专项评测

- 分别测量明确样本和含糊样本上的接受预测准确率、拒绝预测准确率，不能只报一个混合平均值；
- 使用成对候选和多候选夹具测量排序正确率，并记录与简单检索/规则基线的差异；
- 检查置信度校准：高置信预测是否真的更可靠，低证据场景是否主动弃权；
- 对弃权做单独评测，区分合理弃权、该答却弃权和不该自信却强答；
- 对黄色/红色漂移信号统计漏报、误报、提前量、缩小窗口后是否减少继续偏离，以及错误暂停造成的打扰；
- 验证三层偏好范围完全隔离，上传/阅读不自动产生喜欢标签，AI 生成判断不能自我强化，撤销和反证能真实改变后续预测；
- 验证偏好代理与全局故事审校器输入隔离，`BookReaderProxy` 盲读时不能读取后者结论；
- 验证偏好代理没有章节批准、故事记忆/正典合并、正文写入和未授权重大剧情决定权限；
- 自动化测试覆盖事件摄取、证据检索、范围解析、排序、弃权、校准、漂移分级和权限拒绝；
- 使用独立留出集和真实用户抽样复核自动指标；LLM Judge 只能提供带证据的辅助判断，不能单独成为用户偏好真值；
- 论文和外部研究结论只作为方法参考，不把其实验准确率、胜率或长篇效果数字写成仓颉产品承诺。

### 9.4 小说专项回归

- 修仙文本不得无理由混入公司、实验室、算法、现代管理和科技黑话；
- 人物只能使用当前章节已知信息；
- 能力、物品、数量、地理和时间不得冲突；
- 伏笔兑现可追溯；
- 角色选择符合欲望、认知和代价；
- 检测 AI 套话、重复句式、空洞震惊、虚假钩子和总结式对白；
- LLM Judge 必须给文本证据，不能独立决定通过。

### 9.5 叙事索引与材料处理专项评测

- 固定夹具验证不可变原文、来源/版本/精确位置、FTS5、轻量向量、章节顺序、事件、人物状态/认知、时间因果、资源/能力、伏笔/承诺和关系索引；
- 验证查询规划按任务组合不同层级，证据不足时按场景→章节→卷/相邻章→相关关系→全书→必要资料自动扩大，并记录原因；仍不足时必须弃权；
- 对所有高风险结论验证原文闭环；摘要、向量、抽取和 LLM 判断不能单独成为事实；
- 验证导入后先可读可搜、后台渐进索引、覆盖/新鲜度真实显示、修改后增量失效重建、中断恢复和幂等；
- 验证本地基础索引不产生外发或 Provider 费用；首次联网深度理解没有明确授权时必须被工具权限拒绝；
- 授权页面与回执绑定资料范围、Provider/模型、处理目的、预计/实际费用、预算和增量许可；范围或 Provider 实质变化必须重新授权；
- 验证后续只处理新增、修改或当前任务需要范围，暂停恢复不重复发送、分析整本书、写索引或扣费；
- 参考小说只产生带证据、待用户确认的抽象特征，不复刻版权表达、不自动变成偏好或故事事实；
- 依赖审计确认首版没有 Neo4j、Qdrant、完整 GraphRAG/LightRAG 服务或云端知识图谱硬依赖；
- 验证统一 `EvidenceIndex` 保留不可变原文、来源/版本/精确定位/哈希、FTS/语义候选、增量更新、checkpoint、覆盖和证据回链；重建任一专用索引不覆盖共同证据；
- 分别验证小说→`NarrativeIndex`、事实参考→`ResearchIndex`、用户项目资料→`ProjectMaterialIndex`、正反样本/偏好→`PreferenceIndex` 的抽取 schema、查询规划和采用边界；
- 验证分类默认自动完成，无法可靠分类且错误影响明显时才询问；混合 ZIP 按文件、混合文件按片段分类，所有派生结果仍回到同一原文位置；
- 验证查询受项目、资料类型、用途、确认状态、权限和外发授权隔离；参考资料不能自动成为本书设定，参考小说不能作为事实来源或跨项目越权命中。

### 9.6 真机验收说明契约

每个阶段报告必须先声明：版本性质、已包含、未包含、自动化证据和精确真机证据。绿色 CI、静态界面、文档完成或代码完成都不能单独证明产品阶段通过。

每个真机候选必须绑定同一份候选身份：

```text
版本 / Build / Commit / IPA SHA-256 / 候选身份
入口：从 App 启动后怎样到达
位置：控件在屏幕哪个区域，附近标题是什么
操作：点击、输入、长按或滚动的精确步骤
预期：结果出现在哪里，具体表现是什么
失败：应截图或记录的旧页面、错误文字、无反应、闪退或状态不同步
恢复：怎样回到测试起点或安全状态
本次不测：明确排除尚未实现能力
```

采用差异验收：未受本次改动影响、且已有精确候选证据的旧行为不要求机械重复；但权限、凭证隔离、预算、幂等、unknown outcome、Writer Lease、恢复和外部披露等安全合同，必须绑定本次精确候选重新证明，不能沿用另一 Build 的结论。

中间进度汇报后继续工作。只有一个大阶段完成并需要用户真机验收，或确实缺少无法推断的信息时才停下。

---

## 10. 成功判据

仓颉不是因为“功能很多”而成功，而是因为普通用户可以完成下面这条链路：

```text
我只有一个念头
→ 仓颉让我觉得它真的听懂了
→ 我不需要学术语就能做出选择
→ 仓颉替我把决定保存并执行
→ 我像读小说一样看成品、圈出感觉
→ 仓颉能继续追问并准确修改
→ 我随时可以问进度、暂停、恢复
→ 后台仍能保证长篇一致性、版本、安全和费用
```

最终判断标准：**用户感受到的是一个懂他、会主动推进、能真正操作软件的小说创作伙伴；系统内部运行的是一个受治理、可恢复、可审计的生产级长篇小说工程。**
## Supplementary confirmed implementation contracts

The following implementation requirements are copied from the approved history in 1.md and must be implemented behind tests, not inferred from model text.

- Compile a minimal Driver Cockpit Snapshot per model turn; it must include identity, current UI location, project/branch/chapter version, confirmed and unconfirmed state, TaskRun/checkpoint, approvals, allowed tools, forbidden actions, budget, disclosure scope, provider capability snapshot and relevant evidence.
- Probe streaming, standard Tool Call and multi-turn result return, structured JSON, cancellation, usage, system prompts, context/output limits, search, image, embedding, error classification and request reconciliation before assigning a driving mode.
- Expose three honest modes: complete driving, restricted driving and writing-only. Unsupported capabilities constrain or reject tools; they never trigger hidden model substitution.
- Enforce five tool permission levels in the host/tool registry, including an always-denied Level 5. Prompt wording is explanatory only and is never the security boundary.
- Preserve the approved semantic tool surface: project, conversation, material, research, story memory, artifact, chapter, generation, branch, export, budget and task tools. Concrete Swift names may be grouped differently, but typed inputs, state gates, idempotency and receipts are mandatory.
- If `generation.start` is requested before the first three chapters pass calibration, return a structured prerequisite rejection and prove `projectMutated=false`: no TaskRun, chapter version, story memory, Writer Lease or fee settlement is created.

### Historical acceptance example

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
