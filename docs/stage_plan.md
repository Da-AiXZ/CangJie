# 仓颉 iOS 移植项目 — 阶段规划（阶段2-4）

> 制定人：主理人 齐活林（Qi）
> 基准：《仓颉iOS移植版差异审计报告.md》+《仓颉iOS已实现功能对齐深度审计报告.md》
> 约束：《AI移植项目防砍功能约束方法》6道机制全程套用
> 阶段1（核心流程修复）已完成，本文件覆盖阶段2-4

---

## 阶段总览

| 阶段 | 主题 | 目标 | 来源 |
|------|------|------|------|
| 1（已完成） | 核心流程修复 | 向导Bible SSE分stage + Autopilot chapter-stream事件 + workbench单章生成SSE | 深度审计5.7 |
| 2 | 数据模型修正 + 提示词广场重写 | 修CircuitBreaker/BibleStatus/PromptNode等字段 + 提示词广场重写 + Autopilot参数补全 + 主题补anchor | 深度审计2.6-2.8/3.2/3.3/3.9 |
| 3 | 补缺失核心功能 | AI Invocation审批系统 + 向导补步 + DAG节点交互 + Mock面板接API + 各面板CRUD | 差异审计P0/P1/P2 + 深度审计5.4 |
| 4 | 锦上添花 | 文风voiceApi + 世界线DAG重写 + 工作台组件补齐 + 全局浮动按钮 + 单元测试 | 差异审计P3 + 深度审计3.6/3.7/5.4 |

---

## 阶段2：数据模型修正 + 提示词广场重写

**目标**：修复与后端字段不一致的数据模型，消除运行时解码失败风险。

### 2.1 CircuitBreaker 字段重写（深度审计2.7，高风险）

| 原版字段（AutopilotCircuitBreakerData） | iOS现状（CircuitBreakerStatus） | 修复 |
|----------------------------------------|-------------------------------|------|
| status | state | 改字段名 |
| error_count | failure_count | 改字段名 |
| max_errors | threshold | 改字段名 |
| last_error{message,timestamp,context} | last_failure_at（仅时间戳） | 补message/context |
| error_history[] | 缺失 | 新增数组 |

**对齐原版**：`frontend/src/api/autopilot.ts` 的 AutopilotCircuitBreakerData 类型定义

### 2.2 BibleGenerationStatus/Feedback 字段重写（深度审计2.8，对错接口）

| 接口 | 原版返回 | iOS现状 | 修复 |
|------|---------|---------|------|
| getBibleStatus | {exists, ready, novel_id} | {status, stage?, progress?, message?} | 字段全错，重写 |
| getBibleGenerationFeedback | {novel_id, error, stage, at} | {feedback?, suggestions?} | 字段全错，重写 |

**对齐原版**：`frontend/src/api/bible.ts` 的 getBibleStatus/getBibleGenerationFeedback

### 2.3 提示词广场数据模型重写（深度审计2.6，严重）

| 模型 | 原版字段 | iOS现状 | 修复 |
|------|---------|---------|------|
| 首屏聚合 | nodes_by_category（分组） | nodes（flat） | 改字段名+结构 |
| PromptNode | 17字段 | 11字段，字段名大量不一致 | 补6+字段，改字段名 |
| PromptVersion | system_preview+user_preview | content | 改字段结构 |
| RenderResult | {system, user} | {rendered, variablesUsed} | 改字段名 |
| DebugResult | {success,system,user,diagnostics,node_key,node_name,variables_provided,elapsed_ms,error} | {nodeKey,renderedPrompt,variables,modelResponse,tokenInput,tokenOutput,latencyMs,error} | 字段名/结构完全不同，重写 |

**对齐原版**：`frontend/src/api/llmControl.ts` 的 PromptNode/PromptVersion/RenderResult/DebugResult 类型定义
**同时补**：沙盒/链路/绑定/变量/导入导出功能（原版有，iOS缺）

### 2.4 Autopilot 启动参数补全（深度审计3.2）

| 参数 | 原版 | iOS现状 | 修复 |
|------|------|---------|------|
| max_auto_chapters | AutopilotStartRequest 字段 | UI Stepper有@State但未传入，固定9999 | 接线到start端点 |
| autoApproveMode | Toggle | 未发往start端点 | 接线到start端点 |

**对齐原版**：`frontend/src/components/autopilot/AutopilotControlPanel.vue` + `frontend/src/api/autopilot.ts`

### 2.5 Autopilot 状态轮询改自适应退避（深度审计3.3）

| 策略 | 原版 | iOS现状 | 修复 |
|------|------|---------|------|
| 间隔 | base 4000ms，指数退避至60s | 固定3s | 改自适应退避 |
| 404处理 | 即停 | 无404停止逻辑 | 补404停止 |

**对齐原版**：`frontend/src/api/autopilot.ts` 的轮询逻辑
**注**：阶段1已重写chapter-stream事件解析，但状态轮询策略未改，本项补上

### 2.6 主题补 anchor 模式 + xlarge 字号（深度审计3.9）

| 维度 | 原版 | iOS现状 | 修复 |
|------|------|---------|------|
| 模式 | light/dark/anchor/auto 4种 | light/dark/system 3种 | 补anchor黑金模式 |
| 字号 | 0.875/1/1.125/1.25 4档 | 0.85/1.0/1.2 3档 | 补xlarge，改scale数值 |

**对齐原版**：`frontend/src/stores/themeStore.ts` + `frontend/src/components/settings/ThemeAppearanceSection.vue`

---

## 阶段3：补缺失核心功能

**目标**：补齐用户核心使用路径上的缺失功能。

### 3.1 AI Invocation 审批系统全量新建（差异审计2.1，P0最严重缺失）

| 层 | 原版文件 | iOS状态 | 工作量 |
|----|---------|---------|--------|
| 组件 | AIInvocationReviewPanel.vue | 完全没有 | 大 |
| Store | aiInvocationStore.ts | 完全没有 | 大 |
| API | aiInvocation.ts | 完全没有 | 中 |
| 工具 | invocationOutput.ts | 完全没有 | 小 |

**对齐原版**：`frontend/src/components/ai-invocation/` + `frontend/src/stores/aiInvocationStore.ts` + `frontend/src/api/aiInvocation.ts`
**解锁**：向导第4步剧情总纲（依赖审批系统）

### 3.2 向导补步（差异审计2.2，P0）

| 步骤 | 原版API | iOS状态 | 依赖 |
|------|---------|---------|------|
| 第4步 剧情总纲 | POST setup/generate-plot-outline-stream (SSE) + PUT setup/plot-outline | 缺失 | 3.1 AI Invocation |
| 第5步 完成 | 纯前端跳转 | 已有（onComplete） | 无 |

**对齐原版**：`frontend/src/components/onboarding/NovelSetupGuide.vue` 第4步实现 + `frontend/src/api/workflow.ts` 的 consumePlotOutlineStream/savePlotOutline

### 3.3 DAG 节点交互（深度审计3.4，差异审计P2-9）

| 交互 | 原版 | iOS现状 | 修复 |
|------|------|---------|------|
| 左键详情弹窗 | 有 | 只读详情Sheet | 保留，补编辑能力 |
| 右键/长按菜单 | 查看/启禁用toggle | 缺失 | 新增 |
| 节点配置编辑抽屉 | temperature/maxTokens/timeout/maxRetries/modelOverride + PUT updateNodeConfig | 缺失 | 新增 |
| toggle节点 | Store有toggleNode方法但视图未调用 | 缺UI调用 | 接线 |
| 提示词广场跳转 | 有 | 缺失 | 新增 |

**对齐原版**：`frontend/src/components/autopilot/NodeContextMenu.vue` + `NodeDetailPanel.vue` + `NodeEditorDrawer.vue`

### 3.4 Mock 面板接真实 API（差异审计3.1/3.2/3.3，P1假功能）

| 面板 | 原版API | iOS现状 | 修复 |
|------|---------|---------|------|
| QualityGuardrailPanel | MonitorStore质量评分端点 | 五维度评分硬编码 | 接真实API |
| ConsistencyReportPanel | workflow.ts的ConsistencyReportDTO | issues硬编码2条假数据 | 接章节生成consistency_report |
| ChapterElementPanel | chapterElement.ts真实API | 道具/伏笔空数组，角色/地点文本提取 | 接ChapterElement API |

**对齐原版**：`frontend/src/api/monitor.ts` + `frontend/src/api/workflow.ts` + `frontend/src/api/chapterElement.ts`

### 3.5 CreateNovelSheet 题材包接 API（差异审计2.4）

| 项 | 原版 | iOS现状 | 修复 |
|----|------|---------|------|
| 题材选择 | MarketTaxonomyPicker + /taxonomy/bundles/builtin_cn_v1 | 硬编码 | 接API |

**对齐原版**：`frontend/src/components/taxonomy/MarketTaxonomyPicker.vue` + `frontend/src/domain/taxonomy/cnMarket.ts`

### 3.6 各面板 CRUD 交互（深度审计3.8，只读为主）

| 面板 | 原版交互 | iOS现状 | 修复 |
|------|---------|---------|------|
| 伏笔 | 全CRUD + 优先级星标 + 消费弹窗 + 筛选 + Tab | 仅只读列表 | 补CRUD+交互 |
| 道具 | 全CRUD + 事件创建 + 详情抽屉 | 列表 + 只读事件流 | 补CRUD+交互 |
| 演化 | 演化快照 + 闸门 + 覆盖 + 叙事时间线 | 仅快照列表 | 补交互 |
| 编年史 | 双螺旋 + 时间线编辑 + 回滚 | 简单章节列表 | 重写 |
| AntiAI | 七层防御 + 扫描 + 统计 + 分类 + 规则 + 白名单 | 仅扫描 | 补交互 |
| 对话沙盒 | 语料筛选 + 生成器 + anchor读/写 | 白名单 + 生成表单（字段不同） | 补交互+修字段 |

**对齐原版**：`frontend/src/components/workbench/` 对应面板组件

---

## 阶段4：锦上添花

**目标**：完整性补齐，非核心但影响体验。

### 4.1 文风 voiceApi 对接（深度审计3.7）

| 项 | 原版 | iOS现状 | 修复 |
|----|------|---------|------|
| voiceApi | samples/fingerprint | 未定义 | 新增API端点 |
| VoiceVaultPanel | 调voiceApi | 用BibleStore+MonitorStore.voiceDrift | 改调voiceApi |

**对齐原版**：`frontend/src/api/voice.ts` + `frontend/src/components/workbench/VoiceVaultPanel.vue`

### 4.2 世界线 DAG 重写（深度审计3.6，伪造）

| 项 | 原版 | iOS现状 | 修复 |
|----|------|---------|------|
| 数据源 | /worldline/graph + confluence + storylines | 用checkpoints伪造 | 改调真实API |
| 布局 | 手写SVG分支泳道+汇流点+时间切片 | hash泳道伪造 | 重写布局 |
| 交互 | 分支/汇流/checkout/merge/createBranch/hardReset | 缺失 | 新增 |

**对齐原版**：`frontend/src/components/workbench/WorldlineDAG.vue` + `frontend/src/api/worldline.ts`

### 4.3 工作台组件补齐（差异审计4.1，10+缺失）

| 组件 | 功能 | 优先级 |
|------|------|--------|
| ActPlanningModal | 幕规划弹窗 | 高 |
| NarrativeDashboardPanel | 叙事仪表盘 | 高 |
| StoryTimeline | 故事时间线 | 中 |
| StorylineGitGraph | 故事线Git图 | 中 |
| ChapterCastManager | 章节人物管理 | 中 |
| DialogueGeneratorModal | 对话生成器 | 中 |
| PropDetailDrawer | 道具详情抽屉 | 低 |
| StoryDetailPanel | 故事详情 | 低 |

**对齐原版**：`frontend/src/components/workbench/` 对应组件

### 4.4 Autopilot 缺失组件补齐（差异审计4.2）

| 组件 | 功能 |
|------|------|
| NodeDetailPanel | 节点详情面板（与3.3 DAG交互关联） |
| NodeEditorDrawer | 节点编辑抽屉（与3.3 DAG交互关联） |
| StoryPipelineObservability | 故事管道可观测性 |
| DAGToolbar | DAG工具栏 |

**对齐原版**：`frontend/src/components/autopilot/` 对应组件

### 4.5 全局浮动按钮（差异审计2.3，P3非核心）

| 组件 | 功能 |
|------|------|
| GlobalLLMEntryButton | 全局LLM控制台入口 |
| GlobalLLMFloatingButton | 全局LLM浮动按钮 |
| PromptPlazaEntryButton | 提示词广场入口 |
| PromptPlazaFAB | 提示词广场浮动按钮 |

**对齐原版**：`frontend/src/components/` 对应组件

### 4.6 知识图谱补写操作（深度审计3.5）

| 操作 | 原版 | iOS现状 |
|------|------|---------|
| PUT保存 | 有 | 缺 |
| generate | 有 | 缺 |
| starTriple | 有 | 端点已定义但Store未接线 |
| inferNovel | 有 | 缺 |
| revokeInference | 有 | 缺 |

**对齐原版**：`frontend/src/api/knowledgeGraph.ts`

### 4.7 其他

- Autopilot章节流改纯SSE（如阶段1后仍有轮询残留）
- Debug工具（CharacterSchedulerSimulator）
- KnowledgeJsonView（JSON查看mode）
- 单元测试

---

## 执行约束（每阶段必须遵守）

1. **防砍6道机制全程套用**：先读原版→功能清单→接口契约表→标原版行号→QA逐项验收→派工铁律
2. **每阶段独立可交付**：阶段N完成后核心功能可用，不依赖阶段N+1
3. **阶段内按模块推进**：每个模块走完整SOP（PRD→架构→工程→QA），模块间可并行
4. **审计报告作为验收基准**：QA验收时对照审计报告列出的每个问题点
5. **不推倒重写**：保留对齐良好的14个模块（网络层/SSE基础设施/主题骨架/数据模型基础/LLM控制/导出/DAG布局等）

---

*规划制定完毕。阶段1返工完成后，按阶段2→3→4顺序推进。每阶段启动前由主理人确认优先级和范围。*
