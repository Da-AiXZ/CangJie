# 阶段3 P0批次 — 原版事实表（机制1：强制先读原版再动手）

> **工程师**：寇豆码（Kou）
> **范围**：P0批次 = T01基础层 + T02（AI Invocation审批系统 3.1 + 向导补第4步 3.2）
> **原版前端根目录**：`D:/111/2026-06-24-01-37-19/cangjie/_inspect/plotpilot/PlotPilot-master/frontend/src/`
> **已读原版文件**：6个必读文件 + 1个补充文件（wizardStageCache.ts）
> **对齐基准**：PRD 157条原子功能清单 + 系统设计接口契约表

---

## 文件1：`api/aiInvocation.ts`（256行，全量已读）

### 1.1 枚举定义

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| InvocationPolicy 枚举（6种策略） | aiInvocation.ts:5-11 | — | — | `DIRECT` / `REVIEW_BEFORE_CALL` / `REVIEW_AFTER_CALL` / `FULL_INTERACTIVE` / `INTERACTIVE_WHEN_AVAILABLE` / `AUTOPILOT_PAUSE` |
| InvocationSessionStatus 枚举（14种状态） | aiInvocation.ts:13-27 | — | — | requested / spec_resolved / context_resolved / variables_resolved / prompt_compiled / awaiting_pre_call_review / generating / awaiting_acceptance / awaiting_commit / committing / completed / blocked / failed / cancelled |

> **注意**：PRD步骤2写"13种状态"，实际原版有**14种**（含 `cancelled`）。契约表也已标注14种。以原版为准。

### 1.2 数据模型定义

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| InvocationPromptSnapshot（15字段） | aiInvocation.ts:29-54 | — | — | prompt?{system?,user?} / template_prompt?{system?,user?} / draft_prompt?{system?,user?} / node_key? / node_version_id? / asset_link_set_id? / input_binding_set_id? / output_binding_set_id? / variable_snapshot_hash? / template_hash? / composition_hash? / rendered_prompt_hash? / missing_variables?[String] / diagnostics?[String] / asset_version_ids?[String] |
| InvocationVariablePlan（9字段） | aiInvocation.ts:56-66 | — | — | aliases?{String:Any} / resolution_items?[InvocationVariableResolutionItem] / required_missing?[String] / diagnostics?[String] / lineage?{String:String} / snapshot_hash? / snapshot_items?[InvocationVariableSnapshotItem] / snapshot_groups?[InvocationVariableSnapshotGroup] / bindings?[InvocationVariableBinding] |
| InvocationVariableResolutionItem（10字段） | aiInvocation.ts:68-79 | — | — | alias? / variable_key? / display_name? / status? / current_value?(Any) / value_type? / version_number?(Int) / source? / context_key? / required?(Bool) |
| InvocationVariableBinding（16字段） | aiInvocation.ts:81-97 | — | — | alias(String) / variable_key? / required?(Bool) / default?(Any) / source? / enabled?(Bool) / value_type? / scope? / stage? / display_name? / target_display_name? / source_path? / projection_key? / render_mode? / preview_source? |
| InvocationVariableSnapshotItem（12字段） | aiInvocation.ts:99-112 | — | — | key? / display_name? / value?(Any) / type? / scope? / stage? / source? / variable_key? / required?(Bool) / source_path? / projection_key? / render_mode? |
| InvocationVariableSnapshotGroup（5字段） | aiInvocation.ts:114-120 | — | — | id? / scope? / stage? / title? / items?[InvocationVariableSnapshotItem] |
| InvocationSessionDTO（11字段） | aiInvocation.ts:122-134 | — | — | id(String) / operation(String) / node_key(String) / policy(String) / status(String) / context?{String:Any} / metadata?{String:Any} / attempts?[String] / prompt_snapshot? / variable_plan? / output_bindings?[InvocationVariableBinding] |
| InvocationAttemptDTO（5字段） | aiInvocation.ts:136-142 | — | — | id(String) / session_id(String) / status(String) / content(String) / error?(String) |
| AdoptionDecisionDTO（8字段） | aiInvocation.ts:144-153 | — | — | id / session_id / attempt_id / decision / accept_content(Bool) / commit_prompt_version(Bool) / commit_variable_outputs(Bool) / commit_variable_bindings(Bool) |
| AdoptionCommitStepDTO（4字段） | aiInvocation.ts:155-160 | — | — | name(String) / status(String) / result?{String:Any} / error?(String) |
| AdoptionCommitDTO（8字段） | aiInvocation.ts:162-170 | — | — | id / session_id / decision_id / status(String) / steps[AdoptionCommitStepDTO] / result?{String:Any} / error?(String) |
| InvocationResponseDTO（5字段） | aiInvocation.ts:172-178 | — | — | session(InvocationSessionDTO) / attempt?(InvocationAttemptDTO?) / decision?(AdoptionDecisionDTO?) / commit?(AdoptionCommitDTO?) / next_action?(String) |

### 1.3 请求Payload定义

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| InvocationCreatePayload（7字段） | aiInvocation.ts:180-188 | — | — | operation(String) / node_key(String) / variables?{String:Any} / context?{String:Any} / policy?(String) / config?{String:Any} / metadata?{String:Any} |
| InvocationAcceptPayload（6字段） | aiInvocation.ts:190-197 | — | — | attempt_id(String) / accepted_by? / commit_prompt_version?(Bool) / commit_variable_outputs?(Bool) / commit_variable_bindings?(Bool) / metadata?{String:Any} |
| InvocationResumePayload（3字段） | aiInvocation.ts:199-203 | — | — | resumed_by? / config?{String:Any} / metadata?{String:Any} |
| InvocationPromptDraftPayload（2字段） | aiInvocation.ts:205-208 | — | — | system_template(String) / user_template?(String?) |
| InvocationVariableUpdatePayload（2字段） | aiInvocation.ts:210-213 | — | — | values{String:Any} / updated_by? |
| InvocationPromptDraftPreviewDTO（2字段） | aiInvocation.ts:215-218 | — | — | prompt_snapshot(InvocationPromptSnapshot) / variable_plan?(InvocationVariablePlan) |

### 1.4 API端点定义（9个端点+1个commit=共10个方法）

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| 创建session | aiInvocation.ts:221-223 | POST `/ai-invocations`，body: InvocationCreatePayload → InvocationResponseDTO | — | — |
| 获取session详情 | aiInvocation.ts:224-226 | GET `/ai-invocations/{sessionId}`，可选AxiosRequestConfig → InvocationResponseDTO | — | — |
| 采纳 | aiInvocation.ts:227-229 | POST `/ai-invocations/{sessionId}/accept`，body: InvocationAcceptPayload → InvocationResponseDTO | — | — |
| 拒绝 | aiInvocation.ts:230-232 | POST `/ai-invocations/{sessionId}/reject`，body: InvocationAcceptPayload → InvocationResponseDTO | — | — |
| 恢复（批准生成） | aiInvocation.ts:233-235 | POST `/ai-invocations/{sessionId}/resume`，body: InvocationResumePayload → InvocationResponseDTO | — | — |
| 重新生成 | aiInvocation.ts:236-238 | POST `/ai-invocations/{sessionId}/retry`，body: InvocationResumePayload(默认`{}`) → InvocationResponseDTO | — | — |
| 预览提示词草稿 | aiInvocation.ts:239-244 | POST `/ai-invocations/{sessionId}/prompt-draft/preview`，body: InvocationPromptDraftPayload → InvocationPromptDraftPreviewDTO | — | — |
| 保存提示词草稿 | aiInvocation.ts:245-247 | PUT `/ai-invocations/{sessionId}/prompt-draft`，body: InvocationPromptDraftPayload → InvocationResponseDTO | — | — |
| 更新变量 | aiInvocation.ts:248-250 | PUT `/ai-invocations/{sessionId}/variables`，body: InvocationVariableUpdatePayload → InvocationResponseDTO | — | — |
| 提交 | aiInvocation.ts:251-255 | POST `/ai-invocations/{sessionId}/commits`，body: `{decision_id: String}` → InvocationResponseDTO | — | — |

> **注意**：retry的默认payload是`{}`（空对象），不是`{resumed_by:'user'}`。Store层调用retry时传`{resumed_by:'user'}`，但API层默认是`{}`。

---

## 文件2：`stores/aiInvocationStore.ts`（527行，全量已读）

### 2.1 内部数据结构（非响应式）

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| sessionListeners | aiInvocationStore.ts:24 | Map<String, Array<(InvocationResponseDTO)->Void>> | — | session更新监听器字典 |
| sessionPollTimer | aiInvocationStore.ts:25 | Map<String, setTimeout返回值> | — | 轮询定时器字典 |
| activeGenerationPollSessions | aiInvocationStore.ts:26 | Set<String> | — | 活跃轮询session集合 |
| sessionPollInFlight | aiInvocationStore.ts:27 | Set<String> | — | 正在请求中的session集合 |
| headlessAdvancingSessions | aiInvocationStore.ts:28 | Set<String> | — | **iOS不实现**（Q1决策） |

### 2.2 状态字段（@Published）

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| visible | aiInvocationStore.ts:29 | 控制Drawer/Sheet显示 | — | Bool，初始false |
| loading | aiInvocationStore.ts:30 | 全局加载遮罩 | — | Bool，初始false |
| actionLoading | aiInvocationStore.ts:31 | 操作按钮loading | — | Bool，初始false |
| error | aiInvocationStore.ts:32 | 错误提示 | — | String，初始'' |
| session | aiInvocationStore.ts:33 | 当前会话 | — | InvocationSessionDTO? |
| attempt | aiInvocationStore.ts:34 | 当前尝试 | — | InvocationAttemptDTO? |
| decision | aiInvocationStore.ts:35 | 当前决策 | — | AdoptionDecisionDTO? |
| commit | aiInvocationStore.ts:36 | 当前提交 | — | AdoptionCommitDTO? |
| nextAction | aiInvocationStore.ts:37 | 下一步提示 | — | String，初始'' |
| promptDraftSystem | aiInvocationStore.ts:38 | 系统词草稿（编辑中） | — | String，初始'' |
| promptDraftUser | aiInvocationStore.ts:39 | 用户词草稿（编辑中） | — | String，初始'' |
| promptDraftSavedSystem | aiInvocationStore.ts:40 | 已保存系统词 | — | String，初始'' |
| promptDraftSavedUser | aiInvocationStore.ts:41 | 已保存用户词 | — | String，初始'' |
| promptDraftPreview | aiInvocationStore.ts:42 | 预览结果 | — | InvocationPromptDraftPreviewDTO? |
| promptDraftLoading | aiInvocationStore.ts:43 | 预览loading | — | Bool，初始false |
| liveAttemptContent | aiInvocationStore.ts:44 | 实时输出内容 | — | String，初始'' |
| liveAttemptLoading | aiInvocationStore.ts:45 | 轮询loading | — | Bool，初始false |

### 2.3 计算属性（16个，PRD列15个+title）

| 原版功能点 | 原版文件:行号 | 逻辑 | — | — |
|-----------|--------------|-----------|-----------|----------|
| hasAttempt | aiInvocationStore.ts:47 | attempt.id 非空 | — | — |
| canAccept | aiInvocationStore.ts:48-54 | session.id非空 && status=awaiting_acceptance && attempt.id非空 && attempt.status=succeeded && decision.id为空 | — | — |
| canCommit | aiInvocationStore.ts:55 | session.id非空 && decision.id非空 && commit.id为空 | — | — |
| canRetry | aiInvocationStore.ts:56-60 | session.id非空 && attempt.id非空 && status在[awaiting_pre_call_review, awaiting_acceptance, awaiting_commit, cancelled, failed]中 | — | — |
| isGenerating | aiInvocationStore.ts:61 | session.status = generating | — | — |
| liveAttemptDisplay | aiInvocationStore.ts:62 | liveAttemptContent ‖ attempt.content ‖ '' | — | — |
| title | aiInvocationStore.ts:63-66 | session存在时 `${operation} / ${node_key}`，否则 'AI 生成审阅' | — | **PRD未列，原版有** |
| draftSystemTemplate | aiInvocationStore.ts:67-69 | session.prompt_snapshot.template_prompt.system ‖ '' | — | — |
| draftSystemEdited | aiInvocationStore.ts:70-72 | promptDraftSystem ‖ promptDraftSavedSystem ‖ draftSystemTemplate | — | — |
| draftUserTemplate | aiInvocationStore.ts:73-75 | session.prompt_snapshot.template_prompt.user ‖ '' | — | — |
| draftUserEdited | aiInvocationStore.ts:76-78 | promptDraftUser ‖ promptDraftSavedUser ‖ draftUserTemplate | — | — |
| draftRuntimeSystem | aiInvocationStore.ts:79-83 | promptDraftPreview.prompt_snapshot.prompt.system ‖ session.prompt_snapshot.prompt.system ‖ '' | — | — |
| draftRuntimeUser | aiInvocationStore.ts:84-88 | promptDraftPreview.prompt_snapshot.prompt.user ‖ session.prompt_snapshot.prompt.user ‖ '' | — | — |
| draftDiagnostics | aiInvocationStore.ts:89-93 | promptDraftPreview.prompt_snapshot.diagnostics ‖ session.prompt_snapshot.diagnostics ‖ [] | — | — |
| draftMissingVariables | aiInvocationStore.ts:94-98 | promptDraftPreview.prompt_snapshot.missing_variables ‖ session.prompt_snapshot.missing_variables ‖ [] | — | — |
| variableSnapshotGroups | aiInvocationStore.ts:99-102 | promptDraftPreview.variable_plan.snapshot_groups ‖ session.variable_plan.snapshot_groups ‖ [] | — | — |

> **注意**：PRD步骤2说"15个计算属性"，实际原版有**16个**（多一个`title`，line 63-66）。契约表也漏列了title。iOS应实现title。

### 2.4 featureFlag相关（iOS按Q8决策处理）

| 原版功能点 | 原版文件:行号 | 原版逻辑 | iOS处理（Q8决策） |
|-----------|--------------|-----------|-----------|
| debugPanelEnabled | aiInvocationStore.ts:103 | computed → featureFlags.aiInvocationDebug | **iOS硬编码=false** |
| showDebugPanel() | aiInvocationStore.ts:105-109 | debugPanelEnabled为true时设visible=true | **iOS改为直接设visible=true**（Q8：审批面板始终可见） |
| shouldKeepPanelVisible() | aiInvocationStore.ts:111-113 | visible ‖ debugPanelEnabled | **iOS改为直接返回true**（面板始终可见） |
| scheduleHeadlessAdvance() | aiInvocationStore.ts:115-120 | debugPanelEnabled为false时启动自动推进 | **iOS不实现**（Q1决策） |
| advanceHeadlessSession() | aiInvocationStore.ts:165-183 | 自动推进4步：pre_call_review→resume→accept→commit | **iOS不实现**（Q1决策） |

> **⚠️ 关键实现差异**：原版中 `aiInvocationDebug=false` 时，`showDebugPanel()` 不设visible=true，面板不显示，改由headless自动推进。iOS决策是 `aiInvocationDebug=false` + 不实现headless + **面板始终可见**。因此iOS的 `showDebugPanel()` 必须改为**无条件设visible=true**，`shouldKeepPanelVisible()` 必须**无条件返回true**。否则面板永远不会显示。

### 2.5 核心方法

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| shouldCommitPromptVersion() | aiInvocationStore.ts:122-129 | — (计算) | draft_prompt存在 && (无template → true / draft.system≠template.system ‖ draft.user≠template.user) | — |
| applyResponse(payload) | aiInvocationStore.ts:131-163 | — (内部方法) | ①判断sameSession(prevId===nextId) ②session=payload.session ③attempt: payload.attempt ?? (sameSession ? 保留旧值 : null) ④decision/commit同理 ⑤nextAction=payload.next_action ?? '' ⑥promptDraftSavedSystem = draft.system ?? template.system ?? '' ⑦promptDraftSavedUser同理 ⑧promptDraftSystem/User = Saved值 ⑨promptDraftPreview=null ⑩liveAttemptContent: payload.attempt.content有值则更新，非sameSession则清空 ⑪syncGenerationPolling() ⑫通知sessionListeners ⑬**scheduleHeadlessAdvance()（iOS移除）** | InvocationResponseDTO |
| openFromResponse(payload, options) | aiInvocationStore.ts:185-198 | — (不调API) | ①不同session时清空attempt/decision/commit/nextAction/liveAttemptContent/promptDraftPreview ②applyResponse(payload) ③showPanel≠false时**showDebugPanel()**（iOS改为visible=true） | InvocationResponseDTO |
| clearPromptDraftPreview() | aiInvocationStore.ts:200-202 | — | promptDraftPreview=null | — |
| open(sessionId, options) | aiInvocationStore.ts:204-240 | GET /ai-invocations/{sessionId} | ①showPanel≠false时showDebugPanel() ②loading=true, error='' ③清空所有状态(session/attempt/decision/commit/nextAction/promptDraft*/liveAttemptContent) ④stopGenerationPolling() ⑤调API get(sessionId) ⑥设promptDraftSavedSystem/User = draft.system ?? template.system ?? '' ⑦设promptDraftSystem/User = Saved值 ⑧openFromResponse(payload) ⑨finally loading=false | InvocationResponseDTO |
| accept() | aiInvocationStore.ts:242-259 | POST .../accept | ①session.id/attempt.id为空return ②actionLoading=true ③调API accept(session.id, {attempt_id, accepted_by:'user', commit_prompt_version: shouldCommitPromptVersion()}) ④applyResponse ⑤finally actionLoading=false | InvocationAcceptPayload |
| reject() | aiInvocationStore.ts:261-277 | POST .../reject | ①session.id/attempt.id为空return ②actionLoading=true ③调API reject(session.id, {attempt_id, accepted_by:'user'}) ④applyResponse ⑤finally actionLoading=false | InvocationAcceptPayload |
| retry() | aiInvocationStore.ts:279-300 | POST .../retry | ①session.id为空return ②actionLoading=true ③调API retry(session.id, {resumed_by:'user'}) ④applyResponse ⑤**清空decision/commit** ⑥shouldKeepPanelVisible()时showDebugPanel() ⑦syncGenerationPolling() ⑧finally actionLoading=false | InvocationResumePayload |
| resume() | aiInvocationStore.ts:302-321 | POST .../resume | ①session.id为空return ②actionLoading=true ③调API resume(session.id, {resumed_by:'user'}) ④applyResponse ⑤shouldKeepPanelVisible()时showDebugPanel() ⑥syncGenerationPolling() ⑦finally actionLoading=false | InvocationResumePayload |
| previewPromptDraft(system, user) | aiInvocationStore.ts:323-335 | POST .../prompt-draft/preview | ①session.id为空return ②promptDraftLoading=true ③调API previewPromptDraft(session.id, {system_template, user_template}) ④设promptDraftPreview=payload ⑤finally promptDraftLoading=false（**无error处理，不设actionLoading**） | InvocationPromptDraftPayload |
| savePromptDraft(system, user) | aiInvocationStore.ts:337-352 | PUT .../prompt-draft | ①session.id为空return ②promptDraftLoading=true ③调API savePromptDraft(session.id, {system_template, user_template}) ④设promptDraftSavedSystem/User ⑤promptDraftPreview=null ⑥applyResponse ⑦finally promptDraftLoading=false | InvocationPromptDraftPayload |
| updateVariables(values) | aiInvocationStore.ts:354-370 | PUT .../variables | ①session.id为空return ②actionLoading=true ③调API updateVariables(session.id, {values, updated_by:'user'}) ④applyResponse ⑤finally actionLoading=false | InvocationVariableUpdatePayload |
| runCommit() | aiInvocationStore.ts:372-385 | POST .../commits | ①session.id/decision.id为空return ②actionLoading=true ③调API commit(session.id, decision.id) ④applyResponse ⑤finally actionLoading=false | {decision_id} |
| close() | aiInvocationStore.ts:387-390 | — | visible=false → stopGenerationPolling() | — |

### 2.6 轮询机制

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| clearGenerationPollTimer(sessionId) | aiInvocationStore.ts:392-397 | — | 清除指定session的定时器 | — |
| refreshLiveAttemptLoading() | aiInvocationStore.ts:399-401 | — | liveAttemptLoading = (sessionPollTimer.size>0 ‖ sessionPollInFlight.size>0) | — |
| stopGenerationPolling(sessionId?) | aiInvocationStore.ts:403-414 | — | 有sessionId：从activeSet删除+clearTimer；无sessionId：清空全部activeSet+全部timer | — |
| refreshSession(sessionId) | aiInvocationStore.ts:416-421 | GET /ai-invocations/{sessionId}（silentGlobalFeedback:true） | ①调API get(sessionId, {silentGlobalFeedback:true}) ②session.id不匹配则return ③applyResponse | InvocationResponseDTO |
| scheduleGenerationPoll(sessionId) | aiInvocationStore.ts:423-450 | — | ①不在activeSet则return ②已有timer或inFlight则return ③setTimeout(**runtimePerformance.aiInvocation.generationPollMs**→iOS=2000ms) → ④删timer ⑤不在activeSet则return ⑥加入inFlight ⑦refreshSession(sessionId).catch().finally() ⑧finally: 删inFlight ⑨仍在activeSet && session匹配 && status=generating → scheduleGenerationPoll递归 ⑩refreshLiveAttemptLoading | — |
| syncGenerationPolling() | aiInvocationStore.ts:452-461 | — | ①session.id为空return ②status=generating → activeSet.add + scheduleGenerationPoll ③否则 stopGenerationPolling() | — |

> **iOS轮询间隔**：原版用 `runtimePerformance.aiInvocation.generationPollMs`（Q2决策：iOS硬编码2000ms）。

### 2.7 监听器机制

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| onSessionUpdate(sessionId, listener) | aiInvocationStore.ts:463-475 | — (注册监听) | ①获取/创建listeners数组 ②push listener ③返回取消订阅函数（filter移除） | 返回 () -> Void |

---

## 文件3：`utils/invocationOutput.ts`（165行，全量已读）

| 原版功能点 | 原版文件:行号 | 函数签名 | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| parseJsonLikeRecord(raw) | invocationOutput.ts:3-22 | `(String) -> [String:Any]?` | ①trim空则return null ②候选列表=[trim, extractJsonFromMarkdown(trim), extractOuterJson(trim)].filter(Boolean) ③遍历候选：JSON.parse → 是object且非array则返回 ④全失败return null | — |
| extractJsonFromMarkdown(raw) | invocationOutput.ts:24-27 | `(String) -> String` | 正则匹配 ```` ```(?:json)?\s*([\s\S]*?)``` ````，返回group1.trim()或'' | — |
| extractOuterJson(raw) | invocationOutput.ts:29-34 | `(String) -> String` | 取indexOf('{')到lastIndexOf('}')的子串，start<0或end<=start则return '' | — |
| pickPath(source, path) | invocationOutput.ts:36-52 | `(Any?, String) -> Any?` | ①source/path空则undefined ②规范化路径：去掉`$.`或`$`前缀 ③按`.`分段filter(Boolean) ④逐段调pickPathSegment，null则中断 | — |
| pickPathSegment(source, segment) | invocationOutput.ts:54-99 | `(Any?, String) -> Any?` (内部函数) | ①trim ②`$`返回source ③`[]`/`[*]`/`*`：数组返回自身 ④数组+`[x]`→pickListIndex ⑤数组+其他→map递归filter ⑥非数组：提取key和[]selectors ⑦按key取值 ⑧逐个selector处理数组索引 | — |
| pickListIndex(values, selector) | invocationOutput.ts:101-107 | `([Any], String) -> Any?` (内部函数) | ①parseInt ②NaN→undefined ③负索引：length+index ④越界→undefined | — |
| pickExactOrDottedChildren(source, key) | invocationOutput.ts:109-133 | `(Any?, String) -> Any?` | ①非object/array/空key→undefined ②key直接存在→返回 ③否则找`key.`前缀的子键 ④构建嵌套对象返回 ⑤无匹配→undefined | — |
| resolveBoundOutputValue(source, binding) | invocationOutput.ts:135-149 | `(Any?, {source_path?, alias?, variable_key?}) -> Any?` | ①候选=[source_path, alias, variable_key] ②遍历候选：先pickExactOrDottedChildren，再pickPath ③找到则返回 ④全失败→undefined | — |
| extractBoundOutputMaps(source, bindings) | invocationOutput.ts:151-164 | `(Any?, [InvocationVariableBinding]) -> {byAlias, byVariableKey}` | ①遍历bindings ②调resolveBoundOutputValue ③value≠undefined时：alias非空→byAlias[alias]=value，variable_key非空→byVariableKey[variable_key]=value ④返回{byAlias, byVariableKey} | — |

> **注意**：`pickPathSegment`和`pickListIndex`在原版中是内部函数（非export），但PRD步骤5/6要求实现。iOS应实现为内部函数或fileprivate。

---

## 文件4：`components/ai-invocation/AIInvocationReviewPanel.vue`（901行，全量已读）

### 4.1 组件状态（本地ref）

| 原版功能点 | 原版文件:行号 | 用途 | 数据模型 |
|-----------|--------------|-----------|----------|
| promptDraftSystem | AIInvocationReviewPanel.vue:10 | 本地系统词编辑副本 | String |
| promptDraftUser | AIInvocationReviewPanel.vue:11 | 本地用户词编辑副本 | String |
| previewTimer | AIInvocationReviewPanel.vue:12 | 防抖定时器 | setTimeout返回值 |
| expandedVariableGroups | AIInvocationReviewPanel.vue:29 | 变量快照展开组 | String[] |
| expandedPromptGroups | AIInvocationReviewPanel.vue:30 | 提示词折叠展开组 | String[] |
| missingVariableDrafts | AIInvocationReviewPanel.vue:51 | 缺失变量输入草稿 | {String: String} |

### 4.2 计算属性

| 原版功能点 | 原版文件:行号 | 逻辑 |
|-----------|--------------|-----------|
| statusType | AIInvocationReviewPanel.vue:14-20 | completed→success / blocked,failed→error / awaiting_acceptance,awaiting_commit→warning / 其他→info |
| variableSnapshotGroups | AIInvocationReviewPanel.vue:22 | store.variableSnapshotGroups ?? [] |
| hasVariableSnapshot | AIInvocationReviewPanel.vue:23-25 | variableSnapshotGroups有items.length>0 |
| visibleVariableSnapshotGroups | AIInvocationReviewPanel.vue:26-28 | filter items.length>0 |
| promptDraftValidationErrors | AIInvocationReviewPanel.vue:31-37 | isDraftEditable时：系统词空→'系统提示词不能为空'，用户词空→'用户提示词不能为空' |
| diagnostics | AIInvocationReviewPanel.vue:38-45 | 合并[validationErrors, session.variable_plan.diagnostics, store.draftDiagnostics]，去重filter(Boolean) |
| missingVariables | AIInvocationReviewPanel.vue:46-50 | promptDraftPreview.variable_plan.required_missing ?? session.variable_plan.required_missing ?? [] |
| canEditVariables | AIInvocationReviewPanel.vue:52 | status在[blocked, awaiting_pre_call_review]中 |
| hasPrompt | AIInvocationReviewPanel.vue:53-58 | draftSystemTemplate ‖ draftUserTemplate ‖ draftRuntimeSystem ‖ draftRuntimeUser |
| isPreCallBlocked | AIInvocationReviewPanel.vue:59 | status=blocked && !attempt.id && !decision.id |
| isDraftEditable | AIInvocationReviewPanel.vue:60 | status=awaiting_pre_call_review ‖ isPreCallBlocked |
| originalSystemTemplate | AIInvocationReviewPanel.vue:61 | session.prompt_snapshot.template_prompt.system ?? '' |
| originalUserTemplate | AIInvocationReviewPanel.vue:62 | session.prompt_snapshot.template_prompt.user ?? '' |
| systemPromptDraftChanged | AIInvocationReviewPanel.vue:63 | promptDraftSystem ≠ originalSystemTemplate |
| userPromptDraftChanged | AIInvocationReviewPanel.vue:64 | promptDraftUser ≠ originalUserTemplate |
| runtimePromptSystem | AIInvocationReviewPanel.vue:65-67 | promptDraftSystem.trim() ? store.draftRuntimeSystem : '' |
| runtimePromptUser | AIInvocationReviewPanel.vue:68-70 | promptDraftUser.trim() ? store.draftRuntimeUser : '' |
| hasCommitSteps | AIInvocationReviewPanel.vue:71 | commit.steps.length > 0 |
| showLiveAttempt | AIInvocationReviewPanel.vue:72 | attempt.id 非空 |
| showOutputPreview | AIInvocationReviewPanel.vue:73 | hasAttempt && !isGenerating && outputPreviewRows.length > 0 |
| showVariableCenterDebug | AIInvocationReviewPanel.vue:74 | featureFlags.variableCenterDebugPanels（**iOS硬编码=true** Q8） |
| drawerTitle | AIInvocationReviewPanel.vue:75-78 | aiInvocationDebug ? `AI 调试面板：{label}` : `AI 生成审阅：{label}`（**iOS=false→固定"AI 生成审阅：{label}"**） |
| outputBindings | AIInvocationReviewPanel.vue:102-112 | session.output_bindings filter(alias非空) → map({targetDisplayName, jsonPath:source_path‖alias, target:variable_key‖alias, alias, previewSource}) |
| outputPreviewRows | AIInvocationReviewPanel.vue:469-476 | outputBindings.map → previewSource='continuation'时value=undefined，否则resolveOutputPreviewValue(parsedAttemptContent, row) |
| parsedAttemptContent | AIInvocationReviewPanel.vue:468 | parseAttemptContent() — 解析attempt.content为JSON |

### 4.3 Watch（响应式监听）

| 原版功能点 | 原版文件:行号 | 触发条件 | 动作 |
|-----------|--------------|-----------|-----------|
| 草稿同步watch | AIInvocationReviewPanel.vue:122-129 | [store.draftSystemEdited, store.draftUserEdited] immediate | promptDraftSystem=draftSystemEdited, promptDraftUser=draftUserEdited |
| 面板重置watch | AIInvocationReviewPanel.vue:131-139 | [store.visible, store.session?.id] immediate | 清空expandedPromptGroups/expandedVariableGroups/missingVariableDrafts |
| 缺失变量watch | AIInvocationReviewPanel.vue:141-147 | missingVariables immediate | 为新出现的alias初始化missingVariableDrafts[alias]='' |
| **防抖预览watch** | AIInvocationReviewPanel.vue:149-161 | [promptDraftSystem, promptDraftUser] | ①session.id空或!isDraftEditable→return ②清旧timer ③系统词或用户词空→clearPromptDraftPreview+return ④**350ms防抖**→previewPromptDraft(system, user).catch() |

### 4.4 方法

| 原版功能点 | 原版文件:行号 | 调用链 | 关键逻辑 |
|-----------|--------------|-----------|-----------|
| formatValue(value) | AIInvocationReviewPanel.vue:167-175 | — | null→'' / string→原值 / 其他→JSON.stringify(null,2) catch→String(value) |
| snapshotGroupName(group) | AIInvocationReviewPanel.vue:177-179 | — | group.id ‖ `${scope:runtime}:${stage:runtime}` |
| formatScope(scope) | AIInvocationReviewPanel.vue:181-191 | — | global→全局变量 / novel→小说变量 / chapter→章节变量 / scene→场景变量 / beat→节拍变量 / runtime→运行时变量 |
| formatStage(stage) | AIInvocationReviewPanel.vue:193-206 | — | setup→设定 / worldbuilding→世界观 / characters→人物 / locations→地点 / planning→规划 / writing→写作 / review→审阅 / postprocess→后处理 / runtime→运行时 |
| snapshotGroupTitle(group) | AIInvocationReviewPanel.vue:208-212 | — | title ‖ `${formatScope}·${formatStage}`，count>0时追加`（{count}项）` |
| formatType(type) | AIInvocationReviewPanel.vue:214-216 | — | type ‖ '文本' |
| formatSource(source) | AIInvocationReviewPanel.vue:218-225 | — | materialized:→派生上下文 / variable_hub→变量中心 / explicit→显式输入 / default→默认值 / 其他→原值 |
| **handleResume()** | AIInvocationReviewPanel.vue:227-240 | — | ①validationErrors.length>0→message.error(return) ②isDraftEditable→savePromptDraft(system, user) ③missingVariables.length>0→handleSaveMissingVariables() ④session.status=blocked→return ⑤store.resume() |
| handleSaveMissingVariables() | AIInvocationReviewPanel.vue:242-252 | store.updateVariables | ①遍历missingVariables取missingVariableDrafts值 ②非空trim→values[alias]=value ③无值return ④store.updateVariables(values) |
| handleRetry() | AIInvocationReviewPanel.vue:254-256 | store.retry | await store.retry() |
| parseAttemptContent() | AIInvocationReviewPanel.vue:258-277 | — | 候选[trim, extractJsonFromMarkdown, extractOuterJson] → JSON.parse → 失败时尝试recoverTruncatedArrayObject(characters/locations) |
| recoverTruncatedArrayObject(raw, arrayKey) | AIInvocationReviewPanel.vue:291-344 | — | 手动解析截断的JSON数组，逐个{}/[]解析，容错处理 |
| **本地pickPath/pickPathSegment/pickListIndex/pickExactOrDottedChildren** | AIInvocationReviewPanel.vue:346-443 | — | **与invocationOutput.ts重复实现**（Vue组件内本地副本） |
| resolveOutputPreviewValue(source, row) | AIInvocationReviewPanel.vue:445-456 | — | 候选[row.jsonPath, row.alias, row.target] → pickExactOrDottedChildren → pickPath |
| safeJsonPreview(value) | AIInvocationReviewPanel.vue:458-466 | — | null→'' / string→原值 / JSON.stringify catch→String |

> **⚠️ 注意**：AIInvocationReviewPanel.vue 内部（line 258-456）重复实现了 `parseAttemptContent`/`extractJsonFromMarkdown`/`extractOuterJson`/`recoverTruncatedArrayObject`/`pickPath`/`pickPathSegment`/`pickListIndex`/`pickExactOrDottedChildren` 等函数，与 `invocationOutput.ts` 功能重叠。iOS实现时应**统一复用 InvocationOutput.swift**，不重复实现。`recoverTruncatedArrayObject` 是面板独有的截断JSON恢复逻辑，需单独移植。

### 4.5 UI区块（15个，对应PRD 3.1.4 步骤1-15）

| # | 原版功能点 | 原版文件:行号 | UI组件 | 交互 |
|---|-----------|--------------|--------|------|
| 1 | 审批面板容器（Drawer） | AIInvocationReviewPanel.vue:480-486 | n-drawer(v-model:show=store.visible, width=66.666vw, placement=right) + n-drawer-content(title=drawerTitle, closable) + n-spin(show=store.loading) + n-alert(error) | — |
| 2 | 会话状态卡片 | AIInvocationReviewPanel.vue:488-496 | n-card title="会话状态" + n-tag(type=statusType) + 策略 + 下一步 | — |
| 3 | awaiting_pre_call_review提示 | AIInvocationReviewPanel.vue:498-504 | n-alert type=info | — |
| 3a | 本步规则说明（variableCenterDebug） | AIInvocationReviewPanel.vue:505-515 | n-card title="本步规则说明" + outputRuleIntro + outputRuleTips列表 | **iOS: showVariableCenterDebug=true始终显示** |
| 4 | awaiting_acceptance提示 | AIInvocationReviewPanel.vue:516-522 | n-alert type=info | — |
| 5 | 缺失变量提示+补齐表单 | AIInvocationReviewPanel.vue:524-554 | n-alert(warning, missingVariables.join('、')) + n-card(canEditVariables时) + textarea输入 + "保存变量"按钮→handleSaveMissingVariables | store.updateVariables |
| 6 | 诊断信息列表 | AIInvocationReviewPanel.vue:556-562 | n-card title="诊断信息" + n-list + n-list-item × diagnostics | — |
| 7 | 提示词对照面板 | AIInvocationReviewPanel.vue:564-640 | n-card title="提示词对照" + n-collapse(accordion) → 系统提示词对照(CPMS编辑+运行时预览) + 用户提示词对照(CPMS编辑+运行时预览) | 350ms防抖调store.previewPromptDraft；isDraftEditable时可编辑 |
| 8 | 变量快照分组展示 | AIInvocationReviewPanel.vue:642-693 | n-card title="变量快照" + n-collapse → 每组(scope/stage tag + items列表: display_name/key/类型/必填/来源/source_path/projection_key/render_mode + JSON格式化值) | — |
| 9 | AI实时输出区 | AIInvocationReviewPanel.vue:695-710 | n-card title="AI 实时输出" + isGenerating时"生成中，内容会逐步刷新" + attempt.error(alert) ‖ liveAttemptDisplay(pre) | — |
| 10 | 变量中心写入预览 | AIInvocationReviewPanel.vue:712-732 | n-card(showVariableCenterDebug && showOutputPreview) title="变量中心写入预览" + n-list → 每行: target/jsonPath/targetDisplayName + 解析值(continuation→"采纳后派生") | — |
| 11 | 采纳决策卡片 | AIInvocationReviewPanel.vue:734-739 | n-card(store.decision) title="采纳决策" + n-tag(decision) + 决策ID | — |
| 12 | 提交步骤时间线 | AIInvocationReviewPanel.vue:741-751 | n-card(hasCommitSteps) title="提交步骤" + n-timeline → 每步: name + status(succeeded=success/failed=error/其他=info) | — |
| 13 | 底部操作按钮区 | AIInvocationReviewPanel.vue:755-785 | "关闭"→store.close / awaiting_pre_call_review或blocked→"批准生成"或"保存并继续"→handleResume / canRetry→"重新生成"→handleRetry / canAccept→"采纳"→store.accept / canCommit→"提交"→store.runCommit | — |
| 14 | handleResume逻辑 | AIInvocationReviewPanel.vue:227-240 | （见4.4方法表） | — |
| 15 | 防抖预览逻辑 | AIInvocationReviewPanel.vue:149-161 | （见4.3 Watch表） | — |

---

## 文件5：`api/workflow.ts`（PlotOutline相关部分，行109-144 + 682-806，已读）

### 5.1 数据模型

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| PlotOutlineStageDTO | workflow.ts:109-117 | — | — | phase(opening/development/deepening/climax/ending) / label(String) / range_percent(String) / chapter_start?(Int) / chapter_end?(Int) / summary(String) / key_goals?[String] |
| PlotOutlineDTO | workflow.ts:119-124 | — | — | main_story_overview(String) / stage_plan[PlotOutlineStageDTO] / expected_ending(String) / core_conflict(String) |
| GeneratePlotOutlineResponse | workflow.ts:126-130 | — | — | plot_outline?(PlotOutlineDTO?) / invocation_session_id?(String) / invocation_next_action?(String) |
| PlotOutlineStreamEvent（4种事件） | workflow.ts:140-144 | — | — | phase{phase, message} / approval_required{session_id, status?, next_action?} / done{plot_outline: PlotOutlineDTO?} / error{message} |
| ConsistencyIssueDTO | workflow.ts:242-247 | — | — | type(String) / severity(String) / description(String) / location(Int) |
| ConsistencyReportDTO | workflow.ts:249-253 | — | — | issues[ConsistencyIssueDTO] / warnings[ConsistencyIssueDTO] / suggestions[String] |

### 5.2 SSE消费函数

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| consumePlotOutlineStream(novelId, handlers) | workflow.ts:682-771 | POST `/novels/{novelId}/setup/generate-plot-outline-stream`，body:'{}' | ①fetch POST ②!ok/!body→onError ③reader逐帧读取 ④drainFrames: 按`\n\n`分帧 ⑤每行parseSseDataLine ⑥type=phase→onPhase(message) ⑦type=approval_required→onApprovalRequired(session_id, status, next_action) ⑧type=done→onDone(plot_outline ?? null) ⑨type=error→onError(message) ⑩AbortError静默 | PlotOutlineStreamEvent |

### 5.3 API端点

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| getPlotOutline(novelId) | workflow.ts:790-793 | GET `/novels/{novelId}/setup/plot-outline` | — | → GeneratePlotOutlineResponse |
| savePlotOutline(novelId, plotOutline) | workflow.ts:795-799 | PUT `/novels/{novelId}/setup/plot-outline`，body:`{plot_outline: PlotOutlineDTO}` | — | → GeneratePlotOutlineResponse |
| generatePlotOutline(novelId) | workflow.ts:801-806 | POST `/novels/{novelId}/setup/generate-plot-outline`，body:`{}`，timeout:WIZARD_STEP_TIMEOUT_MS | — | → GeneratePlotOutlineResponse |

### 5.4 章节生成SSE的approval_required（3.1.5步骤2接线）

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| consumeGenerateChapterStream的approval_required | workflow.ts:437-446 | POST `/novels/{novelId}/generate-chapter-stream` | type=approval_required → 取session_id/status/next_action → onApprovalRequired(sessionId, status, nextAction) → **return true（终止消费）** | GenerateChapterStreamEvent |

> **注意**：章节生成流中 approval_required 事件会**终止SSE消费**（return true），因为后续走审批面板+轮询。

---

## 文件6：`components/onboarding/NovelSetupGuide.vue`（Step 4相关部分，已读）

### 6.1 步骤定义与导航

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| 5步进度条 | NovelSetupGuide.vue:12-18 | — | n-steps current=currentStep → 1.文风/世界观 2.人物 3.地图 4.剧情总纲 5.开始 | — |
| 步骤可点击导航 | NovelSetupGuide.vue:13-16 | — | @click="goToStep(N)"（1-4步可点击，第5步不可点击） | — |
| goToStep(step) | NovelSetupGuide.vue:2058-2065 | — | ①step<1或>5→return ②step>maxVisitedStep→return ③step===currentStep→return ④isWizardGenerating→return ⑤currentStep=step | — |
| maxVisitedStep | NovelSetupGuide.vue:2055 | — | ref(1)，每完成一步 `maxVisitedStep = max(maxVisitedStep, nextStep)` | — |
| handlePrev() | NovelSetupGuide.vue:2068-2074 | — | currentStep>1 && !isWizardGenerating → currentStep-- | — |
| handleNext() 第4步 | NovelSetupGuide.vue:2102-2106 | — | currentStep===4 → savePlotOutlineEdits() → 成功则 currentStep=5, maxVisitedStep=max(.,5) | — |
| 第4步底部按钮 | NovelSetupGuide.vue:710-718 | — | "确认修改并继续" type=primary :loading=savingStep :disabled="!plotOutline ‖ plotOutlineBusy" @click=handleNext | — |
| 第5步底部按钮 | NovelSetupGuide.vue:720-722 | — | "进入工作台" @click=handleComplete | — |

### 6.2 Step 4 状态字段

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| plotOutline | NovelSetupGuide.vue:1068 | — | — | PlotOutlineDTO? |
| plotOutlineGenerating | NovelSetupGuide.vue:1069 | — | — | Bool |
| plotOutlineError | NovelSetupGuide.vue:1070 | — | — | String |
| plotOutlineCommitted | NovelSetupGuide.vue:1071 | — | — | Bool |
| plotOutlineSessionId | NovelSetupGuide.vue:1072 | — | — | String |
| step4RestoredFromCache | NovelSetupGuide.vue:1073 | — | — | Bool |
| editablePlotOutline | NovelSetupGuide.vue:1074 | — | — | PlotOutlineDTO（编辑副本） |
| syncingPlotOutlineDraft | NovelSetupGuide.vue:1075 | — | — | Bool |
| plotOutlineStatus | NovelSetupGuide.vue:1076 | — | — | PlotOutlineStatus(idle/creating/reviewing/generating/committing/done/error) |

### 6.3 Step 4 计算属性

| 原版功能点 | 原版文件:行号 | 逻辑 |
|-----------|--------------|-----------|
| plotOutlineTopFieldKeys | NovelSetupGuide.vue:1077-1079 | getPlotOutlineTopFieldKeys(editablePlotOutline) |
| plotOutlineTotalChapters | NovelSetupGuide.vue:1080-1088 | max(1, targetChapters, maxStageEnd) |
| plotOutlineBusy | NovelSetupGuide.vue:1089-1092 | generating ‖ (status≠idle && ≠done && ≠error) |
| isWizardGenerating | NovelSetupGuide.vue:1093-1095 | generatingBible ‖ generatingCharacters ‖ generatingLocations ‖ plotOutlineBusy |
| plotOutlineStatusMessage | NovelSetupGuide.vue:1096-1105 | phaseMessage ‖ 按status返回对应文案 |
| plotOutlineLivePreview | NovelSetupGuide.vue:1106-1112 | sessionId匹配时取aiInvocationStore.liveAttemptDisplay.trim()，截取最后1000字 |
| plotOutlineProgressIndex | NovelSetupGuide.vue:1113-1119 | done→4 / committing→3 / generating,reviewing→2 / creating→1 / busy→1 / else→0 |
| plotOutlineProgressItems | NovelSetupGuide.vue:1120-1132 | 4项进度：汇总设定→推演主线→拆分阶段→写入结果，每项state=done/active/pending |

### 6.4 Step 4 核心方法

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| syncEditablePlotOutline(outline) | NovelSetupGuide.vue:1134-1140 | — | syncingPlotOutlineDraft=true → editablePlotOutline=clonePlotOutline(outline, totalChapters) → queueMicrotask恢复flag | — |
| normalizeIncomingPlotOutline(outline) | NovelSetupGuide.vue:1142-1144 | — | normalizePlotOutlineShape(outline, totalChapters) | — |
| updateStageChapterNumber(index, key, value) | NovelSetupGuide.vue:1146-1154 | — | stage[key] = number类型且Finite ? value : undefined | — |
| stageRangePercentLabel(stage) | NovelSetupGuide.vue:1156-1158 | — | buildStageRangePercentLabel(stage, totalChapters) | — |
| buildEditablePlotOutlinePayload() | NovelSetupGuide.vue:1160-1162 | — | buildPlotOutlinePayload(editablePlotOutline, totalChapters) | — |
| touchPlotOutlineDraft() | NovelSetupGuide.vue:1164-1169 | — | !syncing && plotOutline存在 → plotOutline=buildPayload → committed=false | — |
| persistStepFourUiToCache(opts) | NovelSetupGuide.vue:1171-1180 | writeWizardUiCache | currentStep=4时 → patch={invocationSessionId} → includePlotOutline时加plotOutline → writeWizardUiCache | — |
| finishPlotOutlineInvocation() | NovelSetupGuide.vue:1182-1188 | — | generating=false, status=done, phaseMessage='', mainPlotSessionUnsub?.() | — |
| failPlotOutlineInvocation(msg) | NovelSetupGuide.vue:1190-1197 | — | error=msg, generating=false, status=error, phaseMessage='', mainPlotSessionUnsub?.() | — |
| resetPlotOutlineInvocationState() | NovelSetupGuide.vue:1199-1203 | — | generating=false, status=idle, phaseMessage='' | — |
| **updatePlotOutlineStatusFromInvocation(payload)** | NovelSetupGuide.vue:1205-1238 | — | commit.succeeded/session.completed→committing / commit.failed/session.failed/cancelled/blocked→return(不设状态) / awaiting_commit,committing,commit.running→committing / generating→generating / awaiting_acceptance→reviewing(debug)或generating / awaiting_pre_call_review→reviewing(debug)或creating / else→creating | InvocationResponseDTO |
| **refreshPlotOutlineFromApi()** | NovelSetupGuide.vue:1240-1254 | GET /novels/{id}/setup/plot-outline | ①调getPlotOutline ②!plot_outline→return false ③normalize ④plotOutline=normalized ⑤syncEditablePlotOutline ⑥committed=true ⑦writeWizardUiCache ⑧return true / catch→false | — |
| **applyPlotOutlineFromResult(result, bindings)** | NovelSetupGuide.vue:1256-1269 | — | ①extractPlotOutlineFromResult(result, bindings, totalChapters) ②!outline→return false ③plotOutline=outline ④syncEditablePlotOutline ⑤committed=true ⑥writeWizardUiCache ⑦message.success ⑧finishPlotOutlineInvocation ⑨return true | — |
| **handlePlotOutlineInvocationUpdate(payload)** | NovelSetupGuide.vue:1271-1294 | — | ①updatePlotOutlineStatusFromInvocation(payload) ②commit.result有值→applyPlotOutlineFromResult(result, output_bindings)成功→return ③commit.failed/session.failed/cancelled/blocked→failPlotOutlineInvocation ④commit.succeeded/session.completed→refreshPlotOutlineFromApi成功→finishInvocation / 失败→fail | InvocationResponseDTO |
| **openPlotOutlineReviewPanel(sessionId)** | NovelSetupGuide.vue:1296-1326 | aiInvocationStore.open + onSessionUpdate | ①设plotOutlineSessionId ②generating=true ③status=idle/done/error时设creating ④writeWizardUiCache(invocationSessionId) ⑤mainPlotSessionUnsub?.() ⑥注册onSessionUpdate(sessionId, handlePlotOutlineInvocationUpdate) ⑦await aiInvocationStore.open(sessionId) ⑧session匹配时手动调handlePlotOutlineInvocationUpdate(当前状态) ⑨catch→failPlotOutlineInvocation | — |
| **loadPlotOutline(opts?)** | NovelSetupGuide.vue:1328-1422 | consumePlotOutlineStream + generatePlotOutline(降级) | ①step4RestoredFromCache=false, error='', status=creating ②forceNew?null:readWizardUiCache ③缓存有效(cachedPlotOutline)→恢复plotOutline+sessionId, step4RestoredFromCache=true, resetInvocationState, 有未完成session→openPlotOutlineReviewPanel, return ④generating=true, forceNew时清空plotOutline+committed+sessionId+cache ⑤cached.invocationSessionId存在→openPlotOutlineReviewPanel, return ⑥consumePlotOutlineStream: onApprovalRequired→openPlotOutlineReviewPanel / onPhase→phaseMessage / onDone→设plotOutline+sync / onError→streamError ⑦streamError && !plotOutline→throw ⑧plotOutline有值→writeWizardUiCache ⑨catch: 降级调generatePlotOutline POST → 设plotOutline → res.invocation_session_id→openPlotOutlineReviewPanel / cached.invocationSessionId→openPlotOutlineReviewPanel → writeWizardUiCache / catch: error=格式化消息 ⑩finally: plotOutline/error/!sessionId → resetInvocationState | — |
| refreshPlotOutline() | NovelSetupGuide.vue:1424-1426 | — | loadPlotOutline({forceNew: true}) | — |
| hydrateStepFourFromCache() | NovelSetupGuide.vue:1428-1454 | readWizardUiCache | ①读cache ②isPlotOutlineCacheFresh && plotOutline→恢复+sync+sessionId+step4RestoredFromCache, 有未完成session→openPlotOutlineReviewPanel ③cached.invocationSessionId→设sessionId+generating+creating, openPlotOutlineReviewPanel ④!fresh && plotOutline→清空cache中的plotOutline | — |
| **savePlotOutlineEdits()** | NovelSetupGuide.vue:2033-2052 | PUT /novels/{id}/setup/plot-outline | ①buildEditablePlotOutlinePayload() ②validateEditablePlotOutline(payload)有错→message.error+return false ③workflowApi.savePlotOutline(novelId, payload) ④saved=response.plot_outline ‖ payload ⑤plotOutline=saved ⑥syncEditablePlotOutline ⑦committed=true ⑧writeWizardUiCache ⑨return true / catch→message.error+return false | — |

### 6.5 Step 4 UI区块

| # | 原版功能点 | 原版文件:行号 | UI组件 | 交互 |
|---|-----------|--------------|--------|------|
| 1 | 缓存恢复提示 | NovelSetupGuide.vue:524-533 | n-alert(success, closable) "已恢复上次生成的剧情总纲预览（本地缓存）" | @close→step4RestoredFromCache=false |
| 2 | 初始说明区 | NovelSetupGuide.vue:534-540 | icon + h3"生成剧情总纲" + p说明文字 | — |
| 3 | 错误提示 | NovelSetupGuide.vue:542-544 | n-alert(error) plotOutlineError | — |
| 4 | 已保存提示 | NovelSetupGuide.vue:545-547 | n-alert(success, title="已保存剧情总纲") | — |
| 5 | 生成中状态 | NovelSetupGuide.vue:549-588 | plotOutlineBusy && !plotOutline时：generating-header(icon+h3+p) + plot-outline-progress(4项进度) + WizardSkeleton + plotOutlineLivePreview(实时预览+光标) + debug时"打开AI审阅"按钮 | — |
| 6 | 可编辑卡片 | NovelSetupGuide.vue:590-658 | plotOutline存在时：n-card"剧情总纲" + 顶层字段编辑(main_story_overview/core_conflict/expected_ending textarea) + 阶段规划列表(每阶段: label+range + chapter_start/end InputNumber + summary/key_goals textarea) | updatePlotField / updateStageChapterNumber |
| 7 | 重新生成+AI审阅按钮 | NovelSetupGuide.vue:661-673 | "重新生成"→refreshPlotOutline / debug时"打开AI审阅"→openPlotOutlineReviewPanel | — |

### 6.6 plotOutlineModel 工具函数（从 `@/onboarding/plotOutlineModel` 导入）

| 原版功能点 | 原版文件:行号 | 用途 | iOS处理 |
|-----------|--------------|-----------|----------|
| createEmptyPlotOutline | NovelSetupGuide.vue:770 | 创建空PlotOutlineDTO | **需移植** |
| clonePlotOutline(outline, totalChapters) | NovelSetupGuide.vue:769, 1136 | 深拷贝PlotOutlineDTO | **需移植** |
| normalizePlotOutlineShape(outline, totalChapters) | NovelSetupGuide.vue:773, 1143 | 规范化PlotOutline结构 | **需移植** |
| extractPlotOutlineFromResult(result, bindings, totalChapters) | NovelSetupGuide.vue:771, 1260 | 从审批commit.result提取PlotOutline | **需移植** |
| buildPlotOutlinePayload(editable, totalChapters) | NovelSetupGuide.vue:767, 1161 | 从编辑副本构建提交payload | **需移植** |
| validateEditablePlotOutline(payload) | NovelSetupGuide.vue:778, 2036 | 校验编辑后的PlotOutline | **需移植** |
| getPlotOutlineTopFieldKeys(outline) | NovelSetupGuide.vue:772, 1078 | 获取顶层字段key列表 | **需移植** |
| plotFieldLabel(key) | NovelSetupGuide.vue:774 | 字段中文标签 | **需移植** |
| plotFieldText(obj, key) | NovelSetupGuide.vue:775 | 取字段文本 | **需移植** |
| stageContentFieldKeys(stage) | NovelSetupGuide.vue:776 | 获取阶段内容字段key列表 | **需移植** |
| updatePlotField(obj, key, value) | NovelSetupGuide.vue:777 | 更新字段值 | **需移植** |
| buildStageRangePercentLabel(stage, totalChapters) | NovelSetupGuide.vue:768, 1157 | 构建阶段章节范围百分比标签 | **需移植** |
| PlotOutlineStatus 类型 | NovelSetupGuide.vue:781 | idle/creating/reviewing/generating/committing/done/error | **需移植** |
| PlotOutlineProgressItem 类型 | NovelSetupGuide.vue:779 | {key, label, desc, state} | **需移植** |
| PlotOutlineProgressState 类型 | NovelSetupGuide.vue:780 | done/active/pending | **需移植** |

> **⚠️ 关键发现**：原版有一个独立的 `@/onboarding/plotOutlineModel` 模块，包含大量PlotOutline辅助函数（createEmpty/clone/normalize/extract/build/validate/label等）。系统设计未列出对应的iOS文件。**这些函数必须移植**，建议放入 `Models/PlotOutlineModels.swift` 或单独的 `Utils/PlotOutlineHelper.swift`。

---

## 文件7（补充）：`utils/wizardStageCache.ts`（103行，全量已读）

### 7.1 缓存结构

| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| WIZARD_UI_CACHE_SCHEMA | wizardStageCache.ts:8 | — | — | = 4（版本号） |
| STORAGE_KEY_PREFIX | wizardStageCache.ts:9 | — | — | = 'plotpilot:novel-wizard-ui:' → **iOS: `wizard_ui_cache_{novelId}`**（Q3决策） |
| WIZARD_PLOT_OUTLINE_TTL_MS | wizardStageCache.ts:10 | — | — | = 7天（604800000ms） |
| WizardUiCachePayload | wizardStageCache.ts:12-27 | — | — | v(Int) / novelId(String) / savedAt(Int) / plotOutlineSavedAt?(Int) / plotOutline?(PlotOutlineDTO) / invocationSessionId?(String) / wizardCompleted?(Bool) / lastStep?(Int) / worldbuildingFieldLabels?{String:String} |

> **⚠️ 注意**：原版 `WizardUiCachePayload` 有**9个字段**，系统设计契约表只列了4个（v/novelId/plotOutline?/invocationSessionId?）。漏列了 savedAt / plotOutlineSavedAt / wizardCompleted / lastStep / worldbuildingFieldLabels。其中 `plotOutlineSavedAt` 和 `savedAt` 是 `isPlotOutlineCacheFresh` 判断TTL的关键字段，**必须保留**。`wizardCompleted` 和 `lastStep` 用于向导完成状态和步骤恢复，`worldbuildingFieldLabels` 用于第1步字段自定义标题（第1步相关，非P0必须但建议保留）。

### 7.2 缓存函数

| 原版功能点 | 原版文件:行号 | 调用链/API | 关键逻辑 | 数据模型 |
|-----------|--------------|-----------|-----------|----------|
| readWizardUiCache(novelId) | wizardStageCache.ts:33-39 | localStorage读JSON | ①novelId空→null ②读Storage ③data.novelId≠novelId→null ④return data | WizardUiCachePayload? |
| writeWizardUiCache(novelId, patch) | wizardStageCache.ts:41-69 | localStorage写JSON | ①读旧值(prev) ‖ 创建默认{v, novelId, savedAt} ②合并{...prev, ...patch, v, novelId, savedAt:now} ③patch有plotOutline属性：有值→plotOutlineSavedAt=now，无值→清空plotOutline+plotOutlineSavedAt ④patch有invocationSessionId属性：无值→清空 ⑤写Storage | — |
| clearWizardUiCache(novelId) | wizardStageCache.ts:71-74 | localStorage删key | removeStorageItem | — |
| isPlotOutlineCacheFresh(payload) | wizardStageCache.ts:76-80 | — | ①!plotOutline→false ②base=plotOutlineSavedAt ?? savedAt ③now - base <= TTL(7天) | Bool |
| isWizardCompleted(novelId) | wizardStageCache.ts:83-86 | — | cached.wizardCompleted === true | Bool |
| markWizardCompleted(novelId) | wizardStageCache.ts:89-91 | writeWizardUiCache | {wizardCompleted: true} | — |
| getWizardLastStep(novelId) | wizardStageCache.ts:94-97 | — | cached.lastStep | Int? |
| setWizardLastStep(novelId, step) | wizardStageCache.ts:100-102 | writeWizardUiCache | {lastStep: step} | — |

> **iOS实现**：原版用 localStorage，iOS用 UserDefaults（Q3决策）。key格式从 `plotpilot:novel-wizard-ui:{novelId}` 改为 `wizard_ui_cache_{novelId}`。JSON编解码方式不变。

---

## SSE approval_required 接线总表（3.1.5，3处）

| # | SSE源 | 事件类型 | data字段 | iOS接线 | 对齐原版文件:行号 |
|---|-------|---------|---------|---------|-----------------|
| 1 | Bible生成流 | approval_required | session_id, status?, next_action?, stage? | OnboardingStore.handleBibleSSEEvent → aiInvocationStore.openFromResponse | bible.ts SSE事件, NovelSetupGuide.vue:1548-1550 |
| 2 | 单章生成流 | approval_required | session_id, status?, next_action? | WorkbenchStore.consumeGenerateChapterStream → aiInvocationStore.openFromResponse | workflow.ts:437-446 |
| 3 | 剧情总纲流 | approval_required | session_id, status?, next_action? | OnboardingStore.loadPlotOutline → openPlotOutlineReviewPanel | workflow.ts:725-736, NovelSetupGuide.vue:1370-1373 |

> **注意**：Bible生成流的 approval_required 接线点在 NovelSetupGuide.vue 约1548-1550行（本次未读该部分，因为Bible生成属于阶段1已有功能，仅需接线）。如需确认Bible SSE的具体事件解析逻辑，需读 bible.ts 和 NovelSetupGuide.vue 的 startBibleGenerationSSE 部分。

---

## 事实表覆盖度自报

### P0批次契约表条目对照

| 模块 | PRD原子条目数 | 事实表已列条目数 | 覆盖度 | 备注 |
|------|-------------|---------------|--------|------|
| 3.1.1 API层（模型+Payload+端点） | 15步(含20模型+6Payload+10端点) | 20模型+6Payload+10端点=36条 | 100% | 全量逐条列出 |
| 3.1.2 Store层（状态+计算属性+方法+轮询+监听） | 19步 | 17状态+16计算属性+18方法+6轮询+1监听=58条 | 100% | 含title（PRD漏列） |
| 3.1.3 Utils层 | 9步 | 9函数 | 100% | — |
| 3.1.4 View层 | 15步 | 6状态+24计算属性+4watch+16方法+15UI区块=65条 | 100% | — |
| 3.1.5 SSE approval_required接线 | 3步 | 3处 | 100% | — |
| 3.2.1 API层（模型+SSE+端点） | 7步 | 6模型+1SSE函数+3端点=10条 | 100% | — |
| 3.2.2 Store层 | 11步 | 10状态+8计算属性+12方法=30条 | 100% | — |
| 3.2.3 View层 | 5步 | 5步(步骤定义+导航+UI区块+缓存) | 100% | — |
| **补充：wizardStageCache** | — | 1结构+8函数=9条 | — | 系统设计未列但原版必须移植 |
| **补充：plotOutlineModel工具** | — | 15个函数/类型 | — | 系统设计未列但原版必须移植 |
| **合计P0** | **84** | **84+补充24=108+** | **100%** | — |

---

## 发现的疑问与需确认事项

### 疑问1：`showDebugPanel()` / `shouldKeepPanelVisible()` 在iOS的行为

**问题**：原版 `showDebugPanel()` 仅在 `aiInvocationDebug=true` 时设 `visible=true`。iOS决策是 `aiInvocationDebug=false` + 不实现headless + **面板始终可见**（Q8）。如果直接照搬原版 `showDebugPanel()` 逻辑，面板永远不会显示。

**建议**：iOS实现时 `showDebugPanel()` 改为**无条件设 `visible=true`**，`shouldKeepPanelVisible()` 改为**无条件返回 `true`**。`openFromResponse` 和 `open` 调用 `showDebugPanel()` 时即设visible=true。

**影响范围**：AIInvocationStore.swift

### 疑问2：`title` 计算属性未在契约表列出

**问题**：原版 aiInvocationStore.ts:63-66 有 `title` 计算属性（`${operation} / ${node_key}`），PRD步骤2说"15个计算属性"未包含title，契约表3.1.4也未列。

**建议**：iOS实现时包含 `title` 计算属性（View层标题需要用）。

**影响范围**：AIInvocationStore.swift

### 疑问3：`plotOutlineModel` 工具函数未在系统设计文件列表中

**问题**：原版 NovelSetupGuide.vue 从 `@/onboarding/plotOutlineModel` 导入了15个函数/类型（createEmptyPlotOutline / clonePlotOutline / normalizePlotOutlineShape / extractPlotOutlineFromResult / buildPlotOutlinePayload / validateEditablePlotOutline / getPlotOutlineTopFieldKeys / plotFieldLabel / plotFieldText / stageContentFieldKeys / updatePlotField / buildStageRangePercentLabel + 3个类型）。系统设计文件列表中无对应iOS文件。

**建议**：这些函数是PlotOutline数据处理的核心逻辑，**必须移植**。建议放入 `Models/PlotOutlineModels.swift`（与PlotOutlineDTO同文件）或新建 `Utils/PlotOutlineHelper.swift`。需主理人确认文件归属。

**影响范围**：T02 OnboardingStore.swift / PlotOutlineStep.swift

### 疑问4：`WizardUiCachePayload` 字段不完整

**问题**：系统设计契约表3.2.3只列了4个字段（v/novelId/plotOutline?/invocationSessionId?），原版有9个字段。其中 `plotOutlineSavedAt` 和 `savedAt` 是 `isPlotOutlineCacheFresh` TTL判断的必需字段。

**建议**：iOS的 `WizardUiCachePayload` 至少保留：v / novelId / savedAt / plotOutlineSavedAt / plotOutline / invocationSessionId / wizardCompleted / lastStep。`worldbuildingFieldLabels` 可不移植（第1步相关，非P0必须）。

**影响范围**：T02 OnboardingStore.swift

### 疑问5：`AIInvocationReviewPanel.vue` 内的本地JSON解析函数

**问题**：AIInvocationReviewPanel.vue 内部（line 258-456）重复实现了 `parseAttemptContent` / `extractJsonFromMarkdown` / `extractOuterJson` / `recoverTruncatedArrayObject` / `pickPath` / `pickPathSegment` / `pickListIndex` / `pickExactOrDottedChildren`，与 `invocationOutput.ts` 功能重叠。其中 `recoverTruncatedArrayObject` 是面板独有的截断JSON恢复逻辑。

**建议**：iOS实现时，`pickPath` 等通用函数**复用 InvocationOutput.swift**。`parseAttemptContent` 和 `recoverTruncatedArrayObject` 作为面板独有逻辑，放入 `AIInvocationReviewPanel.swift` 或 `InvocationOutput.swift`（作为扩展函数）。

**影响范围**：T02 AIInvocationReviewPanel.swift / InvocationOutput.swift

### 疑问6：Bible SSE 的 approval_required 接线点

**问题**：PRD 3.1.5步骤1要求 Bible SSE 的 approval_required 事件接入审批面板，原版位置在 NovelSetupGuide.vue:1548-1550。本次未读该部分（因Bible生成属于阶段1已有功能）。

**建议**：实现T02时需额外读 NovelSetupGuide.vue:1472-1560 确认 Bible SSE 的 approval_required 事件解析逻辑。或直接在 OnboardingStore 的 Bible SSE handler 中添加 approval_required 分支。

**影响范围**：T02 OnboardingStore.swift

### 疑问7：章节生成SSE的 approval_required 终止消费行为

**问题**：原版 workflow.ts:446 中，章节生成流的 approval_required 事件处理后 `return true`（终止SSE消费）。这意味着收到 approval_required 后不再继续读取SSE流，后续走审批面板+轮询。

**建议**：iOS SSEClient 也应在 approval_required 事件后停止消费。需确认 iOS SSEClient 是否支持"事件回调中停止消费"的机制。

**影响范围**：T02 WorkbenchStore.swift / SSEClient

---

## 结论

事实表已覆盖 P0 批次全部 84 条 PRD 原子条目（3.1 + 3.2），并补充了系统设计遗漏的 24 条关键条目（wizardStageCache 9条 + plotOutlineModel 15条）。

发现 7 个需确认事项，其中疑问1（showDebugPanel行为）和疑问3（plotOutlineModel函数归属）对实现影响最大，需主理人优先确认。

**等待主理人确认事实表无误后，再进入实现阶段。**
