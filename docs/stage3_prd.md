# 仓颉 iOS 移植项目 — 阶段3 PRD（补缺失核心功能）

> **产品经理**：许清楚（Xu）
> **文档用途**：阶段3功能定义 + 原子功能清单（机制2核心产出，QA验收基准）
> **约束方法**：防砍功能约束方法 — 机制2：PRD阶段固化功能清单
> **原版前端根目录**：`D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`
> **iOS 代码根目录**：`D:/111/2026-06-24-01-37-19/cangjie/cangjie-ios/Cangjie/`

---

## 一、产品目标

阶段3交付：补齐用户核心使用路径上6大模块的缺失功能，使 iOS 端从"能跑通基本流程"升级到"核心功能完整可用"，预期覆盖度从 ~78% 提升至 ~93%。

具体：AI审批系统全量新建 → 向导补第4步剧情总纲+第5步 → DAG节点交互 → 三个Mock面板接真实API → 题材包接API → 六个面板全CRUD。

---

## 二、用户故事

1. **作为小说作者**，我想在Bible生成/章节生成时看到AI审批面板，这样我可以在生成前修改提示词、在生成后审阅采纳结果，而不是只能被动等待。
2. **作为小说作者**，我想向导走完5步（世界观→人物→地点→剧情总纲→进工作台），这样我能拿到完整的故事主轴再开始写作。
3. **作为小说作者**，我想在DAG画布上长按节点弹出菜单、编辑节点运行参数、启禁用节点，这样我能精细控制生成流程。
4. **作为小说作者**，我想质量护栏/一致性报告/章节元素面板显示真实后端数据，而不是硬编码假数据。
5. **作为小说作者**，我想建书时从后端题材包选择大类和主题，而不是从硬编码列表选。

---

## 三、需求池（P0/P1/P2）

### P0 — 必须完成（阻断核心路径）

| # | 模块 | 描述 |
|---|------|------|
| 3.1 | AI Invocation 审批系统 | 4层全量新建（View+Store+API+Utils），9个API端点，审批状态机完整 |
| 3.2 | 向导补第4步+第5步 | 剧情总纲SSE+审批+保存，向导5步完整 |

### P1 — 应该完成（假功能消除）

| # | 模块 | 描述 |
|---|------|------|
| 3.4 | 三个Mock面板接真实API | QualityGuardrail/ConsistencyReport/ChapterElement 消除硬编码 |

### P2 — 可以完成（交互增强）

| # | 模块 | 描述 |
|---|------|------|
| 3.3 | DAG节点交互 | 右键菜单+编辑抽屉+toggle+提示词广场跳转 |
| 3.5 | CreateNovelSheet题材包接API | 替代硬编码题材列表 |
| 3.6 | 六个面板全CRUD | 伏笔/道具/演化/编年史/AntiAI/对话沙盒 |

---

## 四、推荐分批策略

| 批次 | 范围 | 依赖 |
|------|------|------|
| **批次A（P0）** | 3.1 AI Invocation → 3.2 向导补步 | 3.2依赖3.1的审批系统 |
| **批次B（P1）** | 3.4 三个Mock面板接API | 独立，可与批次A并行 |
| **批次C（P2）** | 3.3 DAG交互 + 3.5 题材包 + 3.6 面板CRUD | 独立，批次A/B完成后推进 |

---

## 五、功能清单 Checklist（CRITICAL — 机制2核心产出）

> 以下每项为原子条目，标原版文件:行号。QA逐条验收，缺一不可。

---

### 3.1 AI Invocation 审批系统全量新建（P0）

原版4层结构，iOS 0实现，必须全建。

#### 3.1.1 API层 — 新建 AIInvocation APIEndpoint + 数据模型

原版：`api/aiInvocation.ts:1-256`

- [ ] 步骤1：定义 `InvocationPolicy` 枚举（6种策略）
  - [ ] DIRECT / REVIEW_BEFORE_CALL / REVIEW_AFTER_CALL / FULL_INTERACTIVE / INTERACTIVE_WHEN_AVAILABLE / AUTOPILOT_PAUSE
  - 原版：aiInvocation.ts:5-11
- [ ] 步骤2：定义 `InvocationSessionStatus` 枚举（13种状态）
  - [ ] requested / spec_resolved / context_resolved / variables_resolved / prompt_compiled / awaiting_pre_call_review / generating / awaiting_acceptance / awaiting_commit / committing / completed / blocked / failed / cancelled
  - 原版：aiInvocation.ts:13-27
- [ ] 步骤3：定义 `InvocationPromptSnapshot` 模型（15字段）
  - [ ] prompt{system?,user?} / template_prompt{system?,user?} / draft_prompt{system?,user?} / node_key / node_version_id / asset_link_set_id / input_binding_set_id / output_binding_set_id / variable_snapshot_hash / template_hash / composition_hash / rendered_prompt_hash / missing_variables[] / diagnostics[] / asset_version_ids[]
  - 原版：aiInvocation.ts:29-54
- [ ] 步骤4：定义 `InvocationVariablePlan` 模型
  - [ ] aliases{} / resolution_items[] / required_missing[] / diagnostics[] / lineage{} / snapshot_hash / snapshot_items[] / snapshot_groups[] / bindings[]
  - 原版：aiInvocation.ts:56-66
- [ ] 步骤5：定义 `InvocationVariableResolutionItem` 模型（10字段）
  - 原版：aiInvocation.ts:68-79
- [ ] 步骤6：定义 `InvocationVariableBinding` 模型（15字段）
  - [ ] alias / variable_key / required / default / source / enabled / value_type / scope / stage / display_name / target_display_name / source_path / projection_key / render_mode / preview_source
  - 原版：aiInvocation.ts:81-97
- [ ] 步骤7：定义 `InvocationVariableSnapshotItem` 模型（11字段）
  - 原版：aiInvocation.ts:99-112
- [ ] 步骤8：定义 `InvocationVariableSnapshotGroup` 模型（5字段）
  - [ ] id / scope / stage / title / items[]
  - 原版：aiInvocation.ts:114-120
- [ ] 步骤9：定义 `InvocationSessionDTO` 模型（9字段）
  - [ ] id / operation / node_key / policy / status / context / metadata / attempts[] / prompt_snapshot / variable_plan / output_bindings[]
  - 原版：aiInvocation.ts:122-134
- [ ] 步骤10：定义 `InvocationAttemptDTO` 模型（5字段）
  - [ ] id / session_id / status / content / error?
  - 原版：aiInvocation.ts:136-142
- [ ] 步骤11：定义 `AdoptionDecisionDTO` 模型（8字段）
  - [ ] id / session_id / attempt_id / decision / accept_content / commit_prompt_version / commit_variable_outputs / commit_variable_bindings
  - 原版：aiInvocation.ts:144-153
- [ ] 步骤12：定义 `AdoptionCommitStepDTO` + `AdoptionCommitDTO` 模型
  - 原版：aiInvocation.ts:155-170
- [ ] 步骤13：定义 `InvocationResponseDTO` 模型（5字段）
  - [ ] session / attempt? / decision? / commit? / next_action?
  - 原版：aiInvocation.ts:172-178
- [ ] 步骤14：定义请求Payload模型（6个）
  - [ ] InvocationCreatePayload / InvocationAcceptPayload / InvocationResumePayload / InvocationPromptDraftPayload / InvocationVariableUpdatePayload / InvocationPromptDraftPreviewDTO
  - 原版：aiInvocation.ts:180-218
- [ ] 步骤15：定义9个API端点
  - [ ] `POST /ai-invocations` — 创建session
  - [ ] `GET /ai-invocations/{sessionId}` — 获取session详情
  - [ ] `POST /ai-invocations/{sessionId}/accept` — 采纳
  - [ ] `POST /ai-invocations/{sessionId}/reject` — 拒绝
  - [ ] `POST /ai-invocations/{sessionId}/resume` — 恢复（批准生成）
  - [ ] `POST /ai-invocations/{sessionId}/retry` — 重新生成
  - [ ] `POST /ai-invocations/{sessionId}/prompt-draft/preview` — 预览提示词草稿
  - [ ] `PUT /ai-invocations/{sessionId}/prompt-draft` — 保存提示词草稿
  - [ ] `PUT /ai-invocations/{sessionId}/variables` — 更新变量
  - [ ] `POST /ai-invocations/{sessionId}/commits` — 提交（body: {decision_id}）
  - 原版：aiInvocation.ts:220-256

#### 3.1.2 Store层 — 新建 AIInvocationStore

原版：`stores/aiInvocationStore.ts:1-527`

- [ ] 步骤1：定义Store状态字段
  - [ ] visible / loading / actionLoading / error / session / attempt / decision / commit / nextAction
  - [ ] promptDraftSystem / promptDraftUser / promptDraftSavedSystem / promptDraftSavedUser
  - [ ] promptDraftPreview / promptDraftLoading
  - [ ] liveAttemptContent / liveAttemptLoading
  - 原版：aiInvocationStore.ts:29-45
- [ ] 步骤2：定义计算属性
  - [ ] hasAttempt：attempt有id
  - [ ] canAccept：session=awaiting_acceptance && attempt.status=succeeded && 无decision
  - [ ] canCommit：session有id && decision有id && 无commit
  - [ ] canRetry：session有id && attempt有id && status在[awaiting_pre_call_review/awaiting_acceptance/awaiting_commit/cancelled/failed]中
  - [ ] isGenerating：session.status=generating
  - [ ] liveAttemptDisplay：liveAttemptContent || attempt.content
  - [ ] draftSystemTemplate / draftSystemEdited / draftUserTemplate / draftUserEdited
  - [ ] draftRuntimeSystem / draftRuntimeUser / draftDiagnostics / draftMissingVariables
  - [ ] variableSnapshotGroups
  - 原版：aiInvocationStore.ts:47-102
- [ ] 步骤3：实现 `applyResponse(payload)` — 统一响应处理
  - [ ] 更新 session/attempt/decision/commit/nextAction
  - [ ] 同session保留旧attempt/decision/commit，不同session清空
  - [ ] 更新 promptDraftSavedSystem/User
  - [ ] 清空 promptDraftPreview
  - [ ] 更新 liveAttemptContent
  - [ ] 调用 syncGenerationPolling()
  - [ ] 通知 sessionListeners
  - 原版：aiInvocationStore.ts:131-163
- [ ] 步骤4：实现 `open(sessionId)` — 打开审批面板
  - [ ] 清空所有状态
  - [ ] 调 GET /ai-invocations/{sessionId}
  - [ ] 设置 promptDraftSavedSystem/User
  - [ ] 调 applyResponse
  - 原版：aiInvocationStore.ts:204-240
- [ ] 步骤5：实现 `openFromResponse(payload)` — 从响应直接打开
  - [ ] 不同session清空attempt/decision/commit
  - [ ] 调 applyResponse
  - 原版：aiInvocationStore.ts:185-198
- [ ] 步骤6：实现 `accept()` — 采纳
  - [ ] POST /ai-invocations/{sessionId}/accept
  - [ ] body: {attempt_id, accepted_by:'user', commit_prompt_version: shouldCommitPromptVersion()}
  - 原版：aiInvocationStore.ts:242-259
- [ ] 步骤7：实现 `reject()` — 拒绝
  - [ ] POST /ai-invocations/{sessionId}/reject
  - [ ] body: {attempt_id, accepted_by:'user'}
  - 原版：aiInvocationStore.ts:261-277
- [ ] 步骤8：实现 `retry()` — 重新生成
  - [ ] POST /ai-invocations/{sessionId}/retry
  - [ ] body: {resumed_by:'user'}
  - [ ] 清空 decision/commit
  - 原版：aiInvocationStore.ts:279-300
- [ ] 步骤9：实现 `resume()` — 批准生成（从 awaiting_pre_call_review 推进）
  - [ ] POST /ai-invocations/{sessionId}/resume
  - [ ] body: {resumed_by:'user'}
  - 原版：aiInvocationStore.ts:302-321
- [ ] 步骤10：实现 `previewPromptDraft(system, user)` — 预览提示词草稿
  - [ ] POST /ai-invocations/{sessionId}/prompt-draft/preview
  - [ ] body: {system_template, user_template}
  - 原版：aiInvocationStore.ts:323-335
- [ ] 步骤11：实现 `savePromptDraft(system, user)` — 保存提示词草稿
  - [ ] PUT /ai-invocations/{sessionId}/prompt-draft
  - [ ] body: {system_template, user_template}
  - 原版：aiInvocationStore.ts:337-352
- [ ] 步骤12：实现 `updateVariables(values)` — 更新缺失变量
  - [ ] PUT /ai-invocations/{sessionId}/variables
  - [ ] body: {values, updated_by:'user'}
  - 原版：aiInvocationStore.ts:354-370
- [ ] 步骤13：实现 `runCommit()` — 提交
  - [ ] POST /ai-invocations/{sessionId}/commits
  - [ ] body: {decision_id}
  - 原版：aiInvocationStore.ts:372-385
- [ ] 步骤14：实现 `shouldCommitPromptVersion()` — 判断是否需要提交提示词版本
  - [ ] draft_prompt存在 && (draft.system != template.system || draft.user != template.user)
  - 原版：aiInvocationStore.ts:122-129
- [ ] 步骤15：实现生成轮询 `syncGenerationPolling()` / `scheduleGenerationPoll()`
  - [ ] session.status=generating时启动轮询
  - [ ] 轮询间隔：runtimePerformance.aiInvocation.generationPollMs
  - [ ] 非generating时停止轮询
  - 原版：aiInvocationStore.ts:423-461
- [ ] 步骤16：实现 `refreshSession(sessionId)` — 轮询刷新session
  - [ ] GET /ai-invocations/{sessionId}（silentGlobalFeedback: true）
  - [ ] 调 applyResponse
  - 原版：aiInvocationStore.ts:416-421
- [ ] 步骤17：实现 `onSessionUpdate(sessionId, listener)` — 注册session更新监听
  - [ ] 返回取消订阅函数
  - 原版：aiInvocationStore.ts:463-475
- [ ] 步骤18：实现 `close()` — 关闭面板+停止轮询
  - 原版：aiInvocationStore.ts:387-390
- [ ] 步骤19：实现 `clearPromptDraftPreview()` — 清空预览
  - 原版：aiInvocationStore.ts:200-202

#### 3.1.3 Utils层 — 新建 InvocationOutput 工具

原版：`utils/invocationOutput.ts:1-165`

- [ ] 步骤1：实现 `parseJsonLikeRecord(raw)` — 从LLM输出解析JSON对象
  - [ ] 尝试：直接parse → markdown代码块提取 → 外层花括号提取
  - [ ] 只接受object类型（非array）
  - 原版：invocationOutput.ts:3-22
- [ ] 步骤2：实现 `extractJsonFromMarkdown(raw)` — 从markdown代码块提取JSON
  - [ ] 匹配 ```json ... ``` 或 ``` ... ```
  - 原版：invocationOutput.ts:24-27
- [ ] 步骤3：实现 `extractOuterJson(raw)` — 提取最外层花括号内容
  - 原版：invocationOutput.ts:29-34
- [ ] 步骤4：实现 `pickPath(source, path)` — JSONPath式取值
  - [ ] 支持 $. 开头
  - [ ] 支持 . 分隔
  - [ ] 支持 [] 数组索引
  - [ ] 支持 [*] 数组遍历
  - 原版：invocationOutput.ts:36-52
- [ ] 步骤5：实现 `pickPathSegment(source, segment)` — 路径段解析
  - 原版：invocationOutput.ts:54-99
- [ ] 步骤6：实现 `pickListIndex(values, selector)` — 数组索引取值
  - [ ] 支持负索引
  - 原版：invocationOutput.ts:101-107
- [ ] 步骤7：实现 `pickExactOrDottedChildren(source, key)` — 精确key或点号子键提取
  - 原版：invocationOutput.ts:109-133
- [ ] 步骤8：实现 `resolveBoundOutputValue(source, binding)` — 按绑定解析输出值
  - [ ] 候选路径：source_path → alias → variable_key
  - [ ] 先试 pickExactOrDottedChildren，再试 pickPath
  - 原版：invocationOutput.ts:135-149
- [ ] 步骤9：实现 `extractBoundOutputMaps(source, bindings)` — 批量提取绑定输出
  - [ ] 返回 {byAlias, byVariableKey}
  - 原版：invocationOutput.ts:151-164

#### 3.1.4 View层 — 新建 AIInvocationReviewPanel

原版：`components/ai-invocation/AIInvocationReviewPanel.vue:1-901`

- [ ] 步骤1：实现审批面板容器（Drawer/Sheet，右侧弹出）
  - [ ] 标题：`AI 生成审阅：{operation/node_key}`
  - [ ] loading状态遮罩
  - [ ] 错误提示Alert
  - 原版：AIInvocationReviewPanel.vue:480-486
- [ ] 步骤2：实现会话状态卡片
  - [ ] 显示 status 标签（completed=success / blocked/failed=error / awaiting_acceptance/awaiting_commit=warning / 其他=info）
  - [ ] 显示 policy
  - [ ] 显示 nextAction
  - 原版：AIInvocationReviewPanel.vue:488-496
- [ ] 步骤3：实现 awaiting_pre_call_review 状态提示
  - [ ] Alert提示"当前会话等待生成前审阅，可修改CPMS系统词草稿"
  - 原版：AIInvocationReviewPanel.vue:498-504
- [ ] 步骤4：实现 awaiting_acceptance 状态提示
  - [ ] Alert提示"当前会话已完成生成，等待确认是否采纳"
  - 原版：AIInvocationReviewPanel.vue:516-522
- [ ] 步骤5：实现缺失变量提示 + 补齐表单
  - [ ] Warning Alert列出缺失变量名
  - [ ] canEditVariables时显示textarea输入框
  - [ ] "保存变量"按钮调 store.updateVariables
  - 原版：AIInvocationReviewPanel.vue:524-554
- [ ] 步骤6：实现诊断信息列表
  - [ ] 合并：promptDraftValidationErrors + variable_plan.diagnostics + draftDiagnostics
  - [ ] 去重显示
  - 原版：AIInvocationReviewPanel.vue:556-562
- [ ] 步骤7：实现提示词对照面板（系统词+用户词各一组）
  - [ ] 左侧：CPMS模板（可编辑，isDraftEditable时）
  - [ ] 右侧：运行时渲染预览（实时调previewPromptDraft，350ms防抖）
  - [ ] 修改标记（"已修改"标签）
  - [ ] 空值校验（系统词/用户词不能为空）
  - 原版：AIInvocationReviewPanel.vue:564-640
- [ ] 步骤8：实现变量快照分组展示
  - [ ] 按 scope+stage 分组
  - [ ] 每项显示：display_name/key/类型/必填/来源/source_path/projection_key/render_mode
  - [ ] 值用JSON格式化显示
  - 原版：AIInvocationReviewPanel.vue:642-693
- [ ] 步骤9：实现AI实时输出区
  - [ ] showLiveAttempt时显示
  - [ ] 生成中显示"生成中，内容会逐步刷新"
  - [ ] 显示 attempt.error 或 liveAttemptDisplay
  - 原版：AIInvocationReviewPanel.vue:695-710
- [ ] 步骤10：实现变量中心写入预览
  - [ ] 展示output_bindings的提取结果
  - [ ] 每行：target/jsonPath/targetDisplayName + 解析值
  - [ ] continuation类型显示"采纳后派生"
  - 原版：AIInvocationReviewPanel.vue:712-732
- [ ] 步骤11：实现采纳决策卡片
  - [ ] 显示 decision.decision + decision.id
  - 原版：AIInvocationReviewPanel.vue:734-739
- [ ] 步骤12：实现提交步骤时间线
  - [ ] 显示 commit.steps[]
  - [ ] 每步：name + status（succeeded=success / failed=error / 其他=info）
  - 原版：AIInvocationReviewPanel.vue:741-751
- [ ] 步骤13：实现底部操作按钮区
  - [ ] "关闭"按钮 → store.close
  - [ ] awaiting_pre_call_review 或 blocked 时："批准生成"/"保存并继续" → handleResume
  - [ ] canRetry 时："重新生成" → handleRetry
  - [ ] canAccept 时："采纳" → store.accept
  - [ ] canCommit 时："提交" → store.runCommit
  - 原版：AIInvocationReviewPanel.vue:755-785
- [ ] 步骤14：实现 handleResume 逻辑
  - [ ] 校验提示词非空
  - [ ] isDraftEditable时先 savePromptDraft
  - [ ] 有缺失变量时先 handleSaveMissingVariables
  - [ ] blocked状态return
  - [ ] 调 store.resume()
  - 原版：AIInvocationReviewPanel.vue:227-240
- [ ] 步骤15：实现提示词草稿编辑防抖预览
  - [ ] watch promptDraftSystem/User 变化
  - [ ] 350ms防抖调 previewPromptDraft
  - [ ] 空值时 clearPromptDraftPreview
  - 原版：AIInvocationReviewPanel.vue:149-161

#### 3.1.5 接入现有SSE的 approval_required 事件

- [ ] 步骤1：Bible SSE 的 approval_required 事件接入审批面板
  - [ ] 阶段1已留 onApprovalRequired 回调入口
  - [ ] 收到 sessionId 后调 aiInvocationStore.openFromResponse 或 open
  - 原版：NovelSetupGuide.vue:1548-1550（Bible）, aiInvocationStore.ts:185-198
- [ ] 步骤2：Workbench 单章生成 SSE 的 approval_required 事件接入审批面板
  - [ ] 阶段1已实现 done 事件解析，approval_required 需接线
  - 原版：workflow.ts:437-446
- [ ] 步骤3：向导第4步剧情总纲 SSE 的 approval_required 事件接入审批面板
  - [ ] consumePlotOutlineStream 的 onApprovalRequired 回调
  - 原版：workflow.ts:686-687, NovelSetupGuide.vue:1370-1373

---

### 3.2 向导补第4步剧情总纲 + 第5步进工作台（P0）

依赖：3.1 AI Invocation 审批系统必须先完成。

#### 3.2.1 API层 — 新建 PlotOutline 相关端点

原版：`api/workflow.ts:682-806`

- [ ] 步骤1：定义 `PlotOutlineStageDTO` 模型
  - [ ] phase: 'opening'|'development'|'deepening'|'climax'|'ending'
  - [ ] label / range_percent / chapter_start? / chapter_end? / summary / key_goals?[]
  - 原版：workflow.ts:109-117
- [ ] 步骤2：定义 `PlotOutlineDTO` 模型
  - [ ] main_story_overview / stage_plan[] / expected_ending / core_conflict
  - 原版：workflow.ts:119-124
- [ ] 步骤3：定义 `PlotOutlineStreamEvent` 联合类型（4种事件）
  - [ ] phase / approval_required / done / error
  - 原版：workflow.ts:140-144
- [ ] 步骤4：实现 `consumePlotOutlineStream(novelId, handlers)` SSE消费函数
  - [ ] POST /api/v1/novels/{novelId}/setup/generate-plot-outline-stream
  - [ ] body: '{}'
  - [ ] 解析SSE帧：data: {type, ...}
  - [ ] phase事件 → onPhase(message)
  - [ ] approval_required事件 → onApprovalRequired(session_id, status, next_action)
  - [ ] done事件 → onDone(plot_outline) — plot_outline可能为null
  - [ ] error事件 → onError(message)
  - [ ] AbortSignal支持
  - 原版：workflow.ts:682-771
- [ ] 步骤5：实现 `savePlotOutline(novelId, plotOutline)` PUT端点
  - [ ] PUT /api/v1/novels/{novelId}/setup/plot-outline
  - [ ] body: {plot_outline: PlotOutlineDTO}
  - 原版：workflow.ts:795-799
- [ ] 步骤6：实现 `getPlotOutline(novelId)` GET端点
  - [ ] GET /api/v1/novels/{novelId}/setup/plot-outline
  - 原版：workflow.ts:790-793
- [ ] 步骤7：实现 `generatePlotOutline(novelId)` POST端点（SSE降级备用）
  - [ ] POST /api/v1/novels/{novelId}/setup/generate-plot-outline
  - 原版：workflow.ts:801-806

#### 3.2.2 Store层 — OnboardingStore 补第4步

- [ ] 步骤1：OnboardingStep 枚举新增 `plotOutline` case（rawValue=4），completed改为5
  - [ ] 现状：novelInfo=0, bibleGeneration=1, characterSetup=2, locationSetup=3, macroPlanning=4, completed=5
  - [ ] 目标：novelInfo=0, bibleGeneration=1, characterSetup=2, locationSetup=3, plotOutline=4, completed=5
  - 原版：NovelSetupGuide.vue:16-17
- [ ] 步骤2：新增剧情总纲状态字段
  - [ ] plotOutline: PlotOutlineDTO?
  - [ ] plotOutlineGenerating: Bool
  - [ ] plotOutlineError: String
  - [ ] plotOutlineCommitted: Bool
  - [ ] plotOutlineSessionId: String
  - [ ] plotOutlineStatus: PlotOutlineStatus (idle/creating/reviewing/generating/committing/done/error)
  - 原版：NovelSetupGuide.vue:1068-1076
- [ ] 步骤3：实现 `loadPlotOutline(opts?)` — 加载/生成剧情总纲
  - [ ] 优先读本地缓存
  - [ ] 缓存有效：恢复plotOutline + sessionId，有未完成session则openPlotOutlineReviewPanel
  - [ ] 无缓存：调 consumePlotOutlineStream SSE
  - [ ] SSE onApprovalRequired → openPlotOutlineReviewPanel
  - [ ] SSE onDone → 设置plotOutline
  - [ ] SSE onError → 降级调 generatePlotOutline POST
  - [ ] POST失败 → 设置plotOutlineError
  - 原版：NovelSetupGuide.vue:1328-1422
- [ ] 步骤4：实现 `openPlotOutlineReviewPanel(sessionId)` — 打开审批面板
  - [ ] 设置 plotOutlineSessionId
  - [ ] 注册 onSessionUpdate 监听
  - [ ] 调 aiInvocationStore.open(sessionId)
  - [ ] 初始状态处理
  - 原版：NovelSetupGuide.vue:1296-1326
- [ ] 步骤5：实现 `handlePlotOutlineInvocationUpdate(payload)` — 审批更新处理
  - [ ] 更新 plotOutlineStatus
  - [ ] commit.result 有值 → 从result提取plotOutline
  - [ ] commit.status=succeeded / session.status=completed → refreshPlotOutlineFromApi
  - [ ] failed/blocked → failPlotOutlineInvocation
  - 原版：NovelSetupGuide.vue:1271-1294
- [ ] 步骤6：实现 `updatePlotOutlineStatusFromInvocation(payload)` — 状态映射
  - [ ] commit.succeeded/completed → committing
  - [ ] generating → generating
  - [ ] awaiting_acceptance → reviewing (debug) / generating
  - [ ] awaiting_pre_call_review → reviewing (debug) / creating
  - 原版：NovelSetupGuide.vue:1205-1238
- [ ] 步骤7：实现 `refreshPlotOutlineFromApi()` — 从API刷新
  - [ ] 调 getPlotOutline
  - [ ] 有值 → normalize + syncEditable + commit=true
  - 原版：NovelSetupGuide.vue:1240-1254
- [ ] 步骤8：实现 `applyPlotOutlineFromResult(result, bindings)` — 从审批结果提取
  - [ ] 用 extractBoundOutputMaps 解析
  - 原版：NovelSetupGuide.vue:1256-1269
- [ ] 步骤9：实现 `savePlotOutline()` — 保存剧情总纲
  - [ ] 调 PUT /novels/{id}/setup/plot-outline
  - [ ] body: {plot_outline: editablePlotOutline}
  - 原版：NovelSetupGuide.vue:2040-2052
- [ ] 步骤10：实现 `refreshPlotOutline()` — 重新生成
  - [ ] 调 loadPlotOutline(forceNew: true)
  - 原版：NovelSetupGuide.vue:1424-1426
- [ ] 步骤11：实现可编辑剧情总纲同步
  - [ ] syncEditablePlotOutline(outline) — 从原始DTO同步到编辑副本
  - [ ] buildEditablePlotOutlinePayload() — 从编辑副本构建提交payload
  - 原版：NovelSetupGuide.vue:1134-1162

#### 3.2.3 View层 — 新建 PlotOutlineStep + OnboardingWizardView 改5步

- [ ] 步骤1：新建 PlotOutlineStep View
  - [ ] 初始状态：显示"准备生成剧情总纲"说明 + "开始生成"按钮
  - [ ] 生成中：进度指示（汇总设定→推演主线→审阅确认→写入）+ 骨架屏 + 实时预览
  - [ ] 生成完成：可编辑卡片（主线概述/核心冲突/预期结局 + 阶段规划列表）
  - [ ] "重新生成"按钮
  - [ ] "确认修改并继续"按钮（disabled when !plotOutline || plotOutlineBusy）
  - 原版：NovelSetupGuide.vue:522-675
- [ ] 步骤2：OnboardingWizardView wizardSteps 改为5步
  - [ ] 现状：[.bibleGeneration, .characterSetup, .locationSetup]（3步）
  - [ ] 目标：[.bibleGeneration, .characterSetup, .locationSetup, .plotOutline]（4步内容+第5步完成页）
  - [ ] TabView 新增 PlotOutlineStep tag
  - 原版：NovelSetupGuide.vue:12-18
- [ ] 步骤3：进度指示器改为5步
  - [ ] 文风/世界观 → 人物 → 地图 → 剧情总纲 → 开始
  - 原版：NovelSetupGuide.vue:13-17
- [ ] 步骤4：底部导航按钮适配第4步
  - [ ] 第4步"确认修改并继续"→ savePlotOutline → currentStep = .completed
  - [ ] 第5步（completed）"进入工作台"→ onComplete()
  - 原版：NovelSetupGuide.vue:710-722
- [ ] 步骤5：步骤跳转 goToStep 限制
  - [ ] 只允许跳到已到过的步骤
  - [ ] 生成中不允许切换
  - 原版：NovelSetupGuide.vue:2058-2065

---

### 3.3 DAG节点交互（P2）

原版：`components/autopilot/NodeContextMenu.vue` + `NodeDetailPanel.vue` + `NodeEditorDrawer.vue`

#### 3.3.1 NodeContextMenu（右键/长按菜单）

原版：`components/autopilot/NodeContextMenu.vue:1-113`

- [ ] 步骤1：实现长按节点弹出菜单
  - [ ] 菜单位置：节点坐标，不超出视口
  - [ ] 菜单头：节点类型标签（icon + display_name + category）
  - 原版：NodeContextMenu.vue:1-23, 50-58
- [ ] 步骤2：菜单项"查看详情"
  - [ ] emit detail(nodeId)
  - 原版：NodeContextMenu.vue:16-18
- [ ] 步骤3：菜单项"启禁用"
  - [ ] 当前enabled → 显示"禁用此节点"
  - [ ] 当前disabled → 显示"启用此节点"
  - [ ] emit toggle(nodeId)
  - 原版：NodeContextMenu.vue:20-22

#### 3.3.2 NodeDetailPanel（节点详情弹窗）

原版：`components/autopilot/NodeDetailPanel.vue:1-465`

- [ ] 步骤1：实现详情弹窗容器
  - [ ] Modal/Sheet，标题为节点display_name
  - 原版：NodeDetailPanel.vue:1-11
- [ ] 步骤2：实现状态条
  - [ ] 状态色映射：idle/pending/running/success/warning/error/bypassed/disabled/completed
  - [ ] 显示icon + statusLabel + disabled/running标签
  - 原版：NodeDetailPanel.vue:14-22, 250-276
- [ ] 步骤3：实现基本信息区
  - [ ] 节点类型 / 分类标签 / 描述
  - 原版：NodeDetailPanel.vue:25-35
- [ ] 步骤4：实现提示词来源区
  - [ ] 加载 promptLive（dagStore.loadNodePromptLive）
  - [ ] 显示 CPMS Key / 来源标签（cpms/config/meta/none）
  - 原版：NodeDetailPanel.vue:38-55, 307-319
- [ ] 步骤5：实现提示词预览（前500字）
  - 原版：NodeDetailPanel.vue:58-63
- [ ] 步骤6：实现端口信息
  - [ ] input_ports[] / output_ports[] 标签
  - 原版：NodeDetailPanel.vue:66-80
- [ ] 步骤7：实现全托管写作遥测（exec_writer/exec_beat节点）
  - [ ] 轮询 GET /autopilot/{id}/status
  - [ ] 显示：current_stage / writing_substep_label / accumulated_words/chapter_target_words / context_tokens
  - [ ] 404 → "该书暂无托管状态"
  - 原版：NodeDetailPanel.vue:83-97, 191-227
- [ ] 步骤8：实现默认下游节点标签
  - 原版：NodeDetailPanel.vue:100-113
- [ ] 步骤9：底部启禁用Switch
  - [ ] can_disable时显示
  - [ ] 调 dagStore.toggleNode
  - 原版：NodeDetailPanel.vue:122-130, 340-344

#### 3.3.3 NodeEditorDrawer（节点配置编辑抽屉）

原版：`components/autopilot/NodeEditorDrawer.vue:1-296`

- [ ] 步骤1：实现编辑抽屉容器
  - [ ] 右侧Drawer/Sheet
  - [ ] 标题：`节点配置 — {cpmsNodeKey}` 或 `节点配置`
  - 原版：NodeEditorDrawer.vue:1-9
- [ ] 步骤2：实现提示词关联区
  - [ ] 显示 cpmsNodeKey
  - [ ] "在广场编辑"按钮 → 跳转提示词广场
  - 原版：NodeEditorDrawer.vue:11-25, 206-212
- [ ] 步骤3：实现运行参数表单
  - [ ] 温度 Slider（0-2，step 0.1）+ InputNumber
  - [ ] 最大Tokens InputNumber（min 100, step 100, clearable）
  - [ ] 超时时间 InputNumber（10-600秒, step 10）
  - [ ] 最大重试 InputNumber（0-5）
  - [ ] 模型覆盖 Input（留空用默认）
  - 原版：NodeEditorDrawer.vue:28-90
- [ ] 步骤4：实现加载节点配置
  - [ ] 从 node.config 读取 temperature/max_tokens/timeout_seconds/max_retries/model_override
  - [ ] 默认值：temperature=0.7, maxTokens=nil, timeoutSeconds=60, maxRetries=1, modelOverride=''
  - 原版：NodeEditorDrawer.vue:170-179
- [ ] 步骤5：实现保存配置
  - [ ] 有变更时"保存参数"按钮可点
  - [ ] 调 dagStore.updateNodeConfig(dagId, nodeId, config)
  - [ ] config: {temperature, timeout_seconds, max_retries, max_tokens?, model_override?}
  - 原版：NodeEditorDrawer.vue:183-204
- [ ] 步骤6：DAGCanvasView 长按接线
  - [ ] 现状：点击只读Sheet
  - [ ] 目标：长按弹出NodeContextMenu，点击弹出NodeDetailPanel，编辑入口弹出NodeEditorDrawer

---

### 3.4 三个Mock面板接真实API（P1）

#### 3.4.1 QualityGuardrailPanel 接 MonitorStore

原版：`api/monitor.ts:1-52`

- [ ] 步骤1：定义 TensionCurve 相关模型
  - [ ] TensionPoint: {chapter, tension, title, evaluated?}
  - [ ] TensionCurveStats: {avg_tension, max_tension, min_tension, variance, is_flat, evaluated_count, unevaluated_count, consecutive_low}
  - [ ] TensionCurveResponse: {novel_id, points[], stats?}
  - 原版：monitor.ts:11-33
- [ ] 步骤2：定义 VoiceDriftApiItem 模型
  - [ ] drift_score? / status? / [key: string]
  - 原版：monitor.ts:35-39
- [ ] 步骤3：实现 monitorApi.getTensionCurve(novelId) 端点
  - [ ] GET /novels/{novelId}/monitor/tension-curve
  - 原版：monitor.ts:42-47
- [ ] 步骤4：实现 monitorApi.getVoiceDrift(novelId) 端点
  - [ ] GET /novels/{novelId}/monitor/voice-drift
  - 原版：monitor.ts:49-51
- [ ] 步骤5：QualityGuardrailPanel 替换硬编码
  - [ ] 现状：@State dimensions/violations 硬编码
  - [ ] 目标：从 MonitorStore 加载 tension curve + voice drift 数据
  - [ ] 雷达图五维度来自后端真实评分
  - 原版：QualityGuardrailPanel.swift:14-20（iOS现状硬编码）

#### 3.4.2 ConsistencyReportPanel 接章节生成 consistency_report

原版：`api/workflow.ts:242-271`（ConsistencyReportDTO）, `workflow.ts:453-463`（done事件解析）

- [ ] 步骤1：定义 ConsistencyIssueDTO 模型
  - [ ] type / severity / description / location
  - 原版：workflow.ts:242-247
- [ ] 步骤2：定义 ConsistencyReportDTO 模型
  - [ ] issues[] / warnings[] / suggestions[]
  - 原版：workflow.ts:249-253
- [ ] 步骤3：ConsistencyReportPanel 替换硬编码
  - [ ] 现状：@State issues 硬编码2条假数据
  - [ ] 目标：接收章节生成 done 事件的 consistency_report
  - [ ] 显示真实 issues/warnings/suggestions
  - 原版：ConsistencyReportPanel.swift:13-16（iOS现状硬编码）

#### 3.4.3 ChapterElementPanel 接 ChapterElement API

原版：`api/chapterElement.ts:1-75`

- [ ] 步骤1：定义 ChapterElement 模型
  - [ ] ElementType: 'character'|'location'|'item'|'organization'|'event'
  - [ ] RelationType: 'appears'|'mentioned'|'scene'|'uses'|'involved'|'occurs'
  - [ ] Importance: 'major'|'normal'|'minor'
  - [ ] ChapterElementDTO: {id, chapter_id, element_type, element_id, relation_type, importance, appearance_order?, notes?, created_at}
  - 原版：chapterElement.ts:10-24
- [ ] 步骤2：实现 chapterElementApi.getElements(chapterId, elementType?)
  - [ ] GET /chapters/{chapterId}/elements
  - [ ] 可选 query: element_type
  - 原版：chapterElement.ts:38-44
- [ ] 步骤3：实现 chapterElementApi.addElement(chapterId, data)
  - [ ] POST /chapters/{chapterId}/elements
  - 原版：chapterElement.ts:46-52
- [ ] 步骤4：实现 chapterElementApi.batchUpdate(chapterId, elements)
  - [ ] PUT /chapters/{chapterId}/elements（批量替换）
  - 原版：chapterElement.ts:54-60
- [ ] 步骤5：实现 chapterElementApi.deleteElement(chapterId, elementId)
  - [ ] DELETE /chapters/{chapterId}/elements/{elementId}
  - 原版：chapterElement.ts:62-66
- [ ] 步骤6：实现 chapterElementApi.getElementChapters(elementType, elementId)
  - [ ] GET /chapters/elements/{elementType}/{elementId}/chapters
  - 原版：chapterElement.ts:69-74
- [ ] 步骤7：ChapterElementPanel 替换空数组和文本提取
  - [ ] 现状：道具/伏笔空数组，角色/地点 extractCharacters/extractLocations 返回[]
  - [ ] 目标：调 getElements 加载真实数据，按 element_type 分组显示
  - 原版：ChapterElementPanel.swift:17-52（iOS现状空/提取）

---

### 3.5 CreateNovelSheet 题材包接 API（P2）

原版：`components/taxonomy/MarketTaxonomyPicker.vue:1-150+` + `domain/taxonomy/cnMarket.ts:1-54` + `domain/taxonomy/builtin_cn_v1.bundle.json`

#### 3.5.1 数据模型 + API

- [ ] 步骤1：定义 TaxonomyBundle 模型
  - [ ] schema_kind / schema_version / id / locale / domain / title / description
  - [ ] facet_keys_semantics{}
  - [ ] roots[]: TaxonomyNode
  - 原版：builtin_cn_v1.bundle.json:1-16
- [ ] 步骤2：定义 TaxonomyNode 模型
  - [ ] id / labels{locale: text} / facets{} / children[]
  - [ ] facets: market_track / world_tone / writing_profile{story_structure/pacing_control/writing_style/special_requirements} / theme_agent_key / search_blob
  - 原版：builtin_cn_v1.bundle.json:17-33, cnMarket.ts:1-2
- [ ] 步骤3：实现 taxonomy API 端点
  - [ ] GET /taxonomy/bundles/builtin_cn_v1
  - [ ] 返回 TaxonomyBundle JSON

#### 3.5.2 题材选择器组件

原版：`components/taxonomy/MarketTaxonomyPicker.vue:1-150+`

- [ ] 步骤4：实现搜索栏
  - [ ] 模糊搜索大类关键词
  - [ ] 使用 flattenRootsForSearch 构建搜索索引
  - 原版：MarketTaxonomyPicker.vue:3-16, cnMarket.ts:43-54
- [ ] 步骤5：实现大类选择（① 大类）
  - [ ] 按钮组展示所有 roots
  - [ ] 选中高亮
  - 原版：MarketTaxonomyPicker.vue:18-37
- [ ] 步骤6：实现主题选择（② 网文主题）
  - [ ] 展示选中大类的 children
  - [ ] 选中高亮
  - 原版：MarketTaxonomyPicker.vue:39-61
- [ ] 步骤7：实现分类信息展示
  - [ ] 市场大类 / 细分主题 / 赛道属性 / 引擎大类
  - 原版：MarketTaxonomyPicker.vue:63-80
- [ ] 步骤8：实现世界观基调编辑（③ 世界观基调）
  - [ ] TextEditor，可修改
  - [ ] 从 worldToneForSelection(root, leaf) 获取初始值
  - 原版：MarketTaxonomyPicker.vue:82-93, cnMarket.ts:18-20
- [ ] 步骤9：实现写作原则编辑（④ 写作原则）
  - [ ] 4个卡片：story_structure / pacing_control / writing_style / special_requirements
  - [ ] 从 writingProfileForSelection(root, leaf) 获取初始值
  - [ ] 可修改
  - 原版：MarketTaxonomyPicker.vue:95-122, cnMarket.ts:30-32
- [ ] 步骤10：CreateNovelSheet 替换硬编码题材
  - [ ] 现状：genreOptions 硬编码8项，worldPresetOptions 硬编码6项
  - [ ] 目标：用 TaxonomyPicker 组件替代
  - [ ] 选中后填充 genre/worldPreset/storyStructure/pacingControl/writingStyle/specialRequirements/themeAgentKey
  - 原版：CreateNovelSheet.swift:47-50（iOS现状硬编码）

---

### 3.6 六个面板全CRUD（P2）

> 原版面板有完整CRUD，iOS现在大多只读。以下逐面板列出需要补齐的交互。

#### 3.6.1 伏笔面板（ForeshadowLedgerPanel）

原版：`components/workbench/ForeshadowLedger.vue`（需架构师读原版补具体行号）

- [ ] 步骤1：补增删改查CRUD
  - [ ] 新建伏笔（POST）
  - [ ] 编辑伏笔（PUT）
  - [ ] 删除伏笔（DELETE）
  - [ ] 列表查询（GET）
- [ ] 步骤2：补优先级星标交互
- [ ] 步骤3：补消费弹窗（伏笔被使用时的确认流程）
- [ ] 步骤4：补筛选功能（按状态/优先级/类型筛选）
- [ ] 步骤5：补Tab分组（按伏笔状态分Tab）

#### 3.6.2 道具面板（PropManagerPanel）

原版：`components/workbench/PropManagerPanel.vue` + `PropDetailDrawer.vue`

- [ ] 步骤1：补增删改查CRUD
- [ ] 步骤2：补事件创建（道具相关事件）
- [ ] 步骤3：补详情抽屉（PropDetailDrawer）
- [ ] 步骤4：现状"列表+只读事件流"→补交互

#### 3.6.3 演化面板（StoryEvolutionPanel）

原版：`components/workbench/StoryEvolutionPanel.vue`

- [ ] 步骤1：补演化快照交互（查看详情/对比）
- [ ] 步骤2：补闸门（gate）操作
- [ ] 步骤3：补覆盖（override）操作
- [ ] 步骤4：补叙事时间线交互

#### 3.6.4 编年史面板（ChroniclesPanel）

原版：`components/workbench/ChroniclesPanel.vue`

- [ ] 步骤1：重写为双螺旋布局
- [ ] 步骤2：补时间线编辑
- [ ] 步骤3：补回滚操作
- [ ] 步骤4：现状"简单章节列表"→重写

#### 3.6.5 AntiAI面板（AntiAIPanel）

原版：`components/workbench/AntiAIPanel.vue`

- [ ] 步骤1：补七层防御展示
- [ ] 步骤2：补扫描交互（手动触发扫描）
- [ ] 步骤3：补统计展示
- [ ] 步骤4：补分类展示
- [ ] 步骤5：补规则管理
- [ ] 步骤6：补白名单管理
- [ ] 步骤7：现状"仅扫描"→补全交互

#### 3.6.6 对话沙盒面板（DialogueSandboxPanel）

原版：`components/workbench/DialogueSandboxPanel.vue`

- [ ] 步骤1：补语料筛选交互
- [ ] 步骤2：补生成器（字段对齐原版）
- [ ] 步骤3：补anchor读操作
- [ ] 步骤4：补anchor写操作
- [ ] 步骤5：现状"白名单+生成表单（字段不同）"→补交互+修字段

---

## 六、待确认问题

### 需主理人决策

1. **AI Invocation 审批面板的 headless 自动推进模式**
   - 原版有 `advanceHeadlessSession` 逻辑：当 `featureFlags.aiInvocationDebug` 为 false 时，自动推进审批流程（pre_call_review→resume→accept→commit）
   - iOS是否需要实现此自动推进？还是默认手动审批？
   - 原版：aiInvocationStore.ts:115-183
   - **建议**：iOS默认手动审批（更安全），feature flag 控制是否自动推进

2. **AI Invocation 生成轮询间隔**
   - 原版用 `runtimePerformance.aiInvocation.generationPollMs`
   - iOS应该用多少ms？建议2000ms（与原版接近）
   - 原版：aiInvocationStore.ts:447

3. **向导第4步本地缓存**
   - 原版用 `writeWizardUiCache` / `readWizardUiCache` 在localStorage缓存plotOutline和sessionId
   - iOS用 UserDefaults 缓存？还是不缓存（每次重新生成）？
   - 原版：NovelSetupGuide.vue:1171-1180, 1428-1454
   - **建议**：用 UserDefaults 缓存，key 为 `wizard_ui_cache_{novelId}`

4. **向导步骤跳转权限**
   - 原版 `goToStep` 只允许跳到已到过的步骤（maxVisitedStep），生成中不允许切换
   - iOS是否需要步骤跳转？还是只能顺序前进？
   - 原版：NovelSetupGuide.vue:2054-2065
   - **建议**：iOS只允许顺序前进+后退到已到步骤

5. **3.6 六个面板CRUD 的原版行号**
   - 核验清单中3.6只列了面板名和"原版交互"概述，没有标具体原版文件:行号
   - 需要架构师在出接口契约表时补读原版6个面板源码，标注具体行号
   - **建议**：3.6的checklist在架构师阶段细化

6. **DAG节点交互的提示词广场跳转**
   - 原版 NodeEditorDrawer 用 `plazaBridge.openPromptInPlaza(cpmsNodeKey)` 跳转
   - iOS提示词广场（PromptPlaza）已在阶段2实现Store层，但跳转路由是否已接好？
   - 原版：NodeEditorDrawer.vue:206-212

7. **QualityGuardrailPanel 五维度数据来源**
   - 原版 monitor.ts 只有 tensionCurve 和 voiceDrift 两个端点
   - 五维度（张力/文风/一致性/Anti-AI/节奏）的完整评分从哪个端点获取？
   - 原版是否在 MonitorStore 中聚合多个端点？
   - **需确认**：后端是否有专门的质量评分聚合端点，还是前端从多个端点拼装

8. **featureFlags 在 iOS 的处理**
   - 原版大量使用 `featureFlags.aiInvocationDebug` 和 `featureFlags.variableCenterDebugPanels`
   - iOS是否需要 feature flag 机制？还是全部默认开启/关闭？
   - **建议**：iOS不设 feature flag，aiInvocationDebug=false（手动审批），variableCenterDebugPanels=true（显示变量调试面板）

---

## 七、功能清单覆盖度自报

| 模块 | 已列原子条目数 | 原版功能点数 | 覆盖度 |
|------|--------------|------------|--------|
| 3.1 AI Invocation API层 | 15 | 15 | 100% |
| 3.1 AI Invocation Store层 | 19 | 19 | 100% |
| 3.1 AI Invocation Utils层 | 9 | 9 | 100% |
| 3.1 AI Invocation View层 | 15 | 15 | 100% |
| 3.1 接入SSE approval_required | 3 | 3 | 100% |
| 3.2 向导 API层 | 7 | 7 | 100% |
| 3.2 向导 Store层 | 11 | 11 | 100% |
| 3.2 向导 View层 | 5 | 5 | 100% |
| 3.3 DAG NodeContextMenu | 3 | 3 | 100% |
| 3.3 DAG NodeDetailPanel | 9 | 9 | 100% |
| 3.3 DAG NodeEditorDrawer | 6 | 6 | 100% |
| 3.4 QualityGuardrailPanel | 5 | 5 | 100% |
| 3.4 ConsistencyReportPanel | 3 | 3 | 100% |
| 3.4 ChapterElementPanel | 7 | 7 | 100% |
| 3.5 题材包 | 10 | 10 | 100% |
| 3.6 六面板CRUD | 30 | ~30+ | ~85%（待架构师补行号） |
| **合计** | **157** | **~157+** | **~98%** |

> 注：3.6六面板CRUD的原版行号待架构师读原版面板源码后补齐，当前以功能点概述为主。

---

## 八、技术约定（项目铁律）

- iOS 16+ 兼容，禁用 @Observable/@Bindable宏、NavigationSplitView
- 零新 SPM 依赖（仅 KeychainAccess 4.2.2）
- 日期用 CangjieDecoder.shared（微秒6位）
- APIEndpoint.defaultPrefix = /api/v1
- 配置持久化用 UserDefaults
- 全项目用 HStack + NavigationStack（不用 NavigationSplitView）
- Drawer/Sheet 用 SwiftUI原生 .sheet / .fullScreenCover（不用 NavigationSplitView）
- SSE 用 SSEClient（阶段1已建基础设施）
- Store 用 ObservableObject + @Published（不用 @Observable 宏）

---

*本PRD为阶段3验收基准。QA按功能清单逐条对照，缺一项即FAIL返工。*
