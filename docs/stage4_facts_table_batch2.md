# Stage 4 批次2 事实表

## 4.4-1 StoryPipelineObservability

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 十步管线轨道渲染（10个step卡） | StoryPipelineObservability.vue:11-24 | props.status.story_pipeline_wave_index → STORY_PIPELINE_WAVES 常量 | 水平轨道，stepClass()分current/done/pending/muted | StatusLike（松散类型，含story_pipeline_wave_index/wave_entered_at/events等） |
| 停留时间显示 | :8,148-157 | props.status.story_pipeline_wave_entered_at + usePolling(1s) tick | "本步已停留 X 秒/分" | number (unix timestamp) |
| 节点卡（wave3剧本/wave4正文） | :27-37,182-196 | props.status.chapter_target_words / writing_substep_label | genCard computed → label/detail/wordHint | chapter_target_words:number, writing_substep_label:string |
| 章后管线8步网格 | :39-61,245-280 | props.status.aftermath_live_status / last_chapter_audit | aftermathSteps computed, 8步(摘要/节拍/向量/伏笔/KG/因果/角色/债务), stepState()分done/current/pending/fail | aftermath_live_status, narrative_sync_ok, vector_stored, foreshadow_stored, triples_extracted, causal_edges_stored, character_mutations_stored, debt_updated, evolution_snapshot_ok, character_reconcile_ok |
| aftermathRunning判断 | :231-234 | currentIx===8 \|\| writing_substep包含audit_aftermath | 控制showAftermathCard和activeAftermathIndex | writing_substep:string |
| 事件轨迹折叠列表 | :63-76,172-180 | props.status.story_pipeline_events | displayEvents取最后12条倒序，fmtRel()相对时间 | Array<{t,wave,wave_id,substep,label}> |
| aftermathOnly模式 | :2,130,282-286 | prop aftermathOnly=true | 仅显示章后管线卡，隐藏header/轨道/节点卡/事件 | boolean prop |

### iOS现状
- 无同名struct（Grep零命中）
- AutopilotConsoleView.swift / AutopilotControlPanel.swift 已存在但不渲染管线轨道
- AutopilotStatus模型可能已有story_pipeline相关字段需确认

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| StoryPipelineObservabilityView.swift（新建） | StoryPipelineObservability.vue:1-308 |
| STORY_PIPELINE_WAVES常量（10步定义） | constants/storyPipelineWaves |
| AutopilotStatus模型补字段: story_pipeline_wave_index/wave_entered_at/story_pipeline_events/aftermath_live_status/last_chapter_audit等 | :86-123 StatusLike接口 |
| usePolling等价：Timer.publish(1s)驱动dwellLine重算 | :133-135 |
| aftermathOnly模式支持 | :130 |

---

## 4.4-2 DAGToolbar

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"🧭 DAG 可视化" | DAGToolbar.vue:4 | 静态文本 | n-text strong | — |
| 节点统计Tag（total/enabled/running/error） | :7-15 | props.dagStats | n-tag round, 条件显示running/error | dagStats:{total,enabled,running,success,error,bypassed,version?} |
| 托管模式状态指示（4种） | :18-56 | props.autopilotStatus | n-tag: running(info+spin)/paused(warning)/completed(success)/error(error) | autopilotStatus:'idle'\|'running'\|'paused'\|'completed'\|'error' |
| SSE连接状态灯 | :59-64 | props.sseConnected | div.sse-indicator, connected=绿+脉冲动画 | boolean |
| 注册表缺口提示 | :66-77 | dagStore.registryGaps.length / registryLinkageFailed | n-tooltip + n-tag error/warning | registryGaps:Array, registryLinkageFailed:boolean |
| 版本号 | :82-84 | props.dagStats.version | n-text depth=3 | dagStats.version?:number |
| emit switch-to-card | :114-116 | defineEmits | — | — |

### iOS现状
- 无同名struct（Grep零命中）
- DAGCanvasView.swift已存在（T04建的DAG画布）
- 需确认DAGStore是否有registryGaps/registryLinkageFailed字段

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| DAGToolbarView.swift（新建） | DAGToolbar.vue:1-117 |
| DAGStore补字段: registryGaps/registryLinkageFailed（如有） | :95-96 |
| 接入DAGCanvasView顶部 | — |

---

## 4.4-3 ChapterWriterStream

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 流式头部（脉冲点+章节号+stageLabel+字数） | ChapterWriterStream.vue:3-10 | chapterNumber/beatIndex/displayContent computed | pulse-dot动画 + beat-badge + word-count | — |
| SSE流式内容显示 | :11-14,54-97 | chapterApi.subscribeStream(novelId, callbacks) | pre.content-text + cursor闪烁，自动滚动到底 | onChapterStart/onChapterChunk/onChapterContent/onAutopilotStopped/onError |
| 增量chunk追加 | :61-75 | onChapterChunk payload | isSnapshot→覆盖, chunk→追加, beatIndex更新 | {isSnapshot?,content?,chunk?,beatIndex} |
| 完整内容兜底 | :76-90 | onChapterContent data | 如果data.content更长则覆盖 | {chapterNumber,content,beatIndex} |
| emit content-update | :84-89,27-29 | emit('content-update',{chapterNumber,content,wordCount}) | — | — |
| watch isWriting启停流 | :107-117 | isWriting=true→startStream, false→stopStream | abortCtrl.abort()取消 | — |
| onUnmounted清理 | :119-121 | stopStream() | — | — |

### iOS现状
- 无同名struct（Grep零命中）
- AutopilotLogStream.swift已存在但功能不同（日志流非章节内容流）
- SSEClient已存在（技术约定6）
- APIEndpoint.Chapters可能有chapter-stream端点需确认

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| ChapterWriterStreamView.swift（新建） | ChapterWriterStream.vue:1-122 |
| SSEClient接入chapter-stream | chapterApi.subscribeStream → SSEStreamType.chapterStream |
| chapterApi.subscribeStream等价方法（SSEClient封装） | :54-97 |

---

## 4.4-4 ForeshadowLedger（autopilot版）

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"📖 伏笔雷达"+副标题 | ForeshadowLedger.vue:5-9 | 静态 | "只读摘要 · 编辑见侧栏伏笔账本" | — |
| 已回收/待回收计数Tag | :12-17 | collectedCount/pendingCount computed | n-tag success/warning | — |
| 查看全部按钮 | :18-20 | showFullLedger()→showLedgerModal=true | n-button tiny | — |
| 统计卡片3列（总计/回收率/平均间隔） | :27-40 | totalCount/collectionRate/avgInterval computed | stats-grid 3列 | — |
| 空状态 | :43-48 | foreshadows.length===0 | n-empty | — |
| 全部伏笔弹窗（3 Tab: 全部/待回收/已回收） | :52-150 | showLedgerModal | n-modal + n-tabs, 每Tab列表 | Foreshadow:{id,description,importance,planted_chapter,is_collected,collected_chapter?,created_at} |
| 重要性标签 | :220-221 | getForeshadowImportanceLabel/getForeshadowImportanceTagType | n-tag type/label | importance:'low'\|'medium'\|'high'\|'critical' |
| 轮询加载 | :271-274,300-307 | usePolling(loadForeshadows, foreshadowPollMs) | onMounted→startPolling, onUnmounted→stopPolling | — |
| 请求取消 | :186,226-263 | loadAbortController.abort() | 防并发堆积 | — |
| refreshKey监听 | :296-298 | watch(props.refreshKey)→polling.execute() | SSE事件驱动刷新 | refreshKey:number |

### iOS现状
- **ForeshadowLedgerPanel.swift已存在**（T05建的workbench版，CRUD+星标+消费弹窗+筛选+Tab）
- autopilot版是**只读摘要**（无CRUD），与workbench版功能不同
- ForeshadowEntry模型已存在（ForeshadowModels.swift）
- APIEndpoint.Foreshadow.list已存在

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| ForeshadowRadarView.swift（新建，autopilot只读摘要版，**不与ForeshadowLedgerPanel重名**） | ForeshadowLedger.vue:1-308 |
| 复用ForeshadowEntry模型 + APIEndpoint.Foreshadow.list | :236-251 |
| 轮询（Timer.publish） | :271-274 |
| 3 Tab弹窗（全部/待回收/已回收） | :58-149 |

⚠️ **疑问1**：autopilot版ForeshadowLedger将后端ForeshadowEntry映射为本地Foreshadow接口（:242-251），其中`importance`硬编码为`'medium'`，`description`映射自`entry.question`，`is_collected`映射自`status==='consumed'`。iOS是否直接复用ForeshadowEntry原模型，还是建一个映射后的本地模型？建议直接复用ForeshadowEntry（已有question/status/consumedAtChapter字段），在View层做映射计算。

---

## 4.3-1 StoryTimeline

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 头部（标题+创建快照+刷新） | StoryTimeline.vue:3-11 | — | n-button创建快照/刷新 | — |
| 章节行列表 | :16-66 | chroniclesApi.get(slug)→rows | 每行chapter_index, story_events[], snapshots[] | ChronicleRow:{chapter_index,story_events,snapshots} |
| 剧情事件卡片 | :32-41 | emit('select-event', event) | n-tag time + title + description | ChronicleStoryEvent:{note_id,time,title,description?} |
| 版本快照卡片 | :43-59 | emit('select-snapshot', snapshot) | n-tag kind(MANUAL/AUTO) + name + formatTime | ChronicleSnapshot:{id,kind,name,created_at,anchor_chapter?} |
| 高亮范围 | :22-24,113-116 | props.highlightRange | isHighlighted()判断start/end范围 | {start:number,end:number}\|null |
| bundledChronicleRows模式 | :88-92,150-155 | props.chroniclesFromBundledParent + bundledChronicleRows | 父组件注入数据, applyBundledChronicleRows() | ChronicleRow[] |
| 创建快照 | :185-213 | snapshotApi.create(slug,{trigger_type,name,description}) | dialog确认→创建→刷新 | — |
| 错误提示 | :13 | loadError | n-alert error closable | — |

### iOS现状
- **StoryTimelineView.swift已存在**（Autopilot目录下，已实现章节行列表+创建快照+高亮范围+bundledChronicleRows）
- ChronicleRow/ChronicleStoryEvent/ChronicleSnapshot模型已存在
- APIEndpoint.Chronicles.get/rollback已存在

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| **无需新建**（StoryTimelineView.swift已存在且功能对齐） | — |
| 需确认：snapshotApi.create端点是否已存在 | StoryTimeline.vue:194 |

⚠️ **疑问2**：StoryTimelineView.swift已存在于Autopilot目录，结构与原版StoryTimeline.vue高度对齐。需确认：(a) 是否只需补snapshotApi.create端点（如缺失）？(b) 还是需要新增一个workbench版StoryTimeline（与autopilot版区分）？原版StoryTimeline.vue在workbench目录下，但iOS已建在Autopilot目录。

---

## 4.3-2 StorylineGitGraph

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| Git Graph SVG图谱 | StorylineGitGraph.vue:49-315 | workflowApi.getStorylineGraphData(slug) | SVG: 轨道横线+章节竖线+直线段+Branch曲线+Merge曲线+Commit节点+HEAD标记 | StorylineGraphDataDTO:{storylines,merge_points,total_chapters} |
| 轨道（TrackDef） | :520-528 | rawStorylines→tracks computed | 每条故事线一条轨道, color/label/isMain/storylineType | TrackDef:{id,color,label,isMain,storylineType} |
| Commit节点（CommitDef） | :531-559 | rawStorylines→commits computed | 每线每章一个commit, detectBranches/detectMerges标注关系 | CommitDef:{id,chapterIndex,trackId,label,branchFrom?,mergeFrom?,description?} |
| Branch曲线生成 | :757-776 | branchCurves computed, 三次贝塞尔 | source→target, 虚线+箭头 | — |
| Merge曲线生成 | :779-806 | mergeCurves computed, 三次贝塞尔 | sources→merge点 | — |
| Tooltip悬浮 | :334-374 | onCommitHover/hideTooltip | commit hash/label/章节/轨道/Branch/Merge/HEAD信息 | — |
| 选中Commit详情面板 | :378-411 | selectCommit/activeCommitData | badge+hash+label+章节+轨道+Branch/Merge信息+回滚按钮 | — |
| 回滚到Commit | :839-873 | chroniclesApi.get→找快照→chroniclesApi.rollbackToSnapshot | dialog.warning确认→回滚→emit('rollback') | SnapshotRollbackResponse:{deleted_count} |
| 底部状态栏 | :414-424 | tracks/commits统计 | 总章数/Branch次数/Merge次数/Tracks数 + HEAD位置 | — |
| 刷新/缩放切换 | :13-25 | loadData/toggleZoom | n-button刷新 + n-button放大/收起 | — |
| 降级加载 | :887-895 | getStorylineGraphData失败→getStorylines(slug) | 无merge_points | StorylineDTO[] |

### iOS现状
- 无同名struct（Grep零命中）
- StorylineDTO模型已存在（EvolutionModels.swift）
- StorylineGraphDataDTO/StorylineMergePointDTO **不存在**，需新建
- APIEndpoint无storylines/graph-data端点，需新建
- chroniclesApi.rollback已存在（APIEndpoint.Chronicles.rollback）

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| StorylineGitGraphView.swift（新建） | StorylineGitGraph.vue:1-902 |
| APIEndpoint.Workflow补: getStorylines(novelId) + getStorylineGraphData(novelId) | workflow.ts getStorylines/getStorylineGraphData |
| StorylineGraphDataDTO + StorylineMergePointDTO模型（新建） | workflow.ts StorylineGraphDataDTO/StorylineMergePointDTO |
| SVG Git Graph渲染（SwiftUI Canvas/Path） | :49-315 |
| Branch/Merge曲线算法 | :757-806 |
| 回滚逻辑（复用APIEndpoint.Chronicles.rollback） | :839-873 |

---

## 4.3-3 ChapterCastManager

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"本章角色锁"+章节Tag | ChapterCastManager.vue:5-7 | props.chapterNumber | n-text + ccm-chapter-tag | — |
| 刷新内核按钮 | :9-11 | runSchedule()→castApi.analyzeOutline(slug,chapterNumber,outline) | n-button tiny quaternary | — |
| 落库对齐按钮 | :12-22 | applyAll()→castApi.scheduleAndPersist(slug,{chapter_number,outline,mode:'apply'}) | n-button tiny primary, disabled=suggestions为空 | CastScheduleRequest:{chapter_number,outline,mode} |
| 统计4列（T0锚定/T1参与/T2过场/需校准） | :27-44 | tierCounts/reviewCount computed | ccm-stat grid 4列 | — |
| 选角合同列表 | :46-78 | suggestions | ccm-item, importance分major/normal/minor, 点击emit('select-character') | ScheduledCharacterItem:{character_id,name,importance,scene_function?,needs_review?} |
| 新角色准入列表 | :80-101 | newCharacterCandidates | ccm-candidate, recommendation分create/ephemeral | {name?,recommendation?,reason?,confidence?} |
| 上下文锁预览 | :103-112 | generatedContext/schedulingLog | pre.ccm-context + log行 | — |
| 空状态 | :114-119 | !scheduling && suggestions为空 && candidates为空 | n-empty | — |
| watch自动调度 | :236-240 | watch([slug,chapterNumber,outline])→runSchedule() | immediate | — |
| 重要性/场景函数标签 | :171-185 | getCastImportanceTierLabel/getSceneFunctionLabel/getCastRecommendationLabel | domain/chapterWriting辅助函数 | — |

### iOS现状
- 无同名struct（Grep零命中）
- CastStore已存在但**无analyzeOutline/scheduleAndPersist方法**
- APIEndpoint.Cast.schedule已存在但未确认是否对应scheduleAndPersist
- ScheduledCharacterItem/CastScheduleRequest/CastScheduleResponse **不存在**，需新建

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| ChapterCastManagerView.swift（新建） | ChapterCastManager.vue:1-241 |
| CastStore补方法: analyzeOutline/scheduleAndPersist | :191-234 |
| APIEndpoint.Cast补: analyzeOutline（如schedule端点不等价） | cast.ts analyzeOutline |
| ScheduledCharacterItem/CastScheduleRequest/CastScheduleResponse模型（新建） | cast.ts |
| domain/chapterWriting标签辅助函数等价 | :129-185 |

⚠️ **疑问3**：原版castApi.analyzeOutline内部实际调用scheduleAndPersist(mode:'suggest')（cast.ts:analyzeOutline实现），两个方法底层是同一个端点POST /novels/{id}/cast/schedule，区别仅在mode字段。iOS现有APIEndpoint.Cast.schedule(novelId:)是否已对应此端点？如果是，CastStore只需一个方法通过mode参数区分即可。

---

## 4.3-4 DialogueGeneratorModal

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| Modal容器 | DialogueGeneratorModal.vue:2 | v-model:show | n-modal preset=card title="💬 对话沙盒" | — |
| 角色选择下拉 | :5-13 | bibleApi.listCharacters(novelId)→characterOptions | n-select, @update→loadCharacterAnchor | CharacterDTO[] |
| 角色锚点展示 | :16-30 | sandboxApi.getCharacterAnchor(novelId,charId) | n-descriptions: 心理状态/口头禅/待机动作 | CharacterAnchor:{mental_state,verbal_tic,idle_behavior,...} |
| 场景描述输入 | :33-40 | v-model scenePrompt | n-input textarea autosize | — |
| 生成对话按钮 | :43-54 | sandboxApi.generateDialogue({novel_id,character_id,scene_prompt,mental_state,verbal_tic,idle_behavior}) | n-button primary, disabled=!charId\|\|!scenePrompt | — |
| 生成结果展示 | :57-80 | generatedDialogue | n-input textarea editable + 重新生成/复制按钮 | {dialogue,character_name} |
| 重新生成 | :66-71 | regenerate()→generateDialogue() | — | — |
| 复制到剪贴板 | :72-78 | navigator.clipboard.writeText | — | — |
| 心理状态颜色 | :193-199 | getMentalStateColor(state) | 平静→success, 焦虑→warning, 愤怒→error, 其他→info | — |
| watch show加载角色 | :202-206 | show=true && characters为空→loadCharacters() | — | — |

### iOS现状
- 无同名struct（Grep零命中）
- CharacterAnchor模型已存在（SandboxModels.swift）
- GenerateDialogueRequest/GenerateDialogueResponse已存在
- APIEndpoint.Sandbox.characterAnchor/generateDialogue已存在
- APIEndpoint.Bible角色列表端点需确认

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| DialogueGeneratorModalView.swift（新建，sheet呈现） | DialogueGeneratorModal.vue:1-207 |
| 复用CharacterAnchor/GenerateDialogueRequest/GenerateDialogueResponse | — |
| 复用APIEndpoint.Sandbox.characterAnchor/generateDialogue | — |
| bibleApi.listCharacters等价（APIEndpoint.Bible角色列表） | :121 |
| UIPasteBoard复制功能 | :180-189 |

---

## 4.3-5 ChapterStatusPanel

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 章节基本信息卡 | ChapterStatusPanel.vue:7-20 | props.chapter | 章节号+标题+收稿状态Tag+字数 | Chapter:{id,number,title,word_count} |
| 只读警告 | :22-24 | props.readOnly | n-alert warning | — |
| 正文结构卡 | :27-54 | chapterApi.getChapterStructure(slug,chapter.number) | 4列: 分段/场景/对白比例/节奏 | ChapterStructureDTO:{paragraph_count,scene_count,dialogue_ratio,pacing} |
| 自动审阅卡 | :57-178 | props.autopilotChapterReview | 张力进度条+章后8步+文风检测+质量评分+问题摘要+审阅时间 | AutopilotChapterAudit:{chapter_number,tension,drift_alert,similarity_score,narrative_sync_ok,...,quality_scores?,issues?,at} |
| 章后8步网格 | :90-108,330-359 | aftermathSteps computed | 8步: 摘要/节拍/向量/伏笔/KG/因果/角色/债务, done/fail/pending状态 | boolStep()函数 |
| aftermathSummary | :361-369 | computed | Tag: 失败数/全部完成/部分确认/等待结果 | — |
| 张力进度条 | :73-80 | autopilotChapterReview.tension | tension*10%宽度, 渐变色 | number 0-10 |
| 文风检测 | :111-134 | similarity_score/drift_alert | 相似度数值 + 漂移告警Tag | — |
| 质量评分网格 | :137-152 | quality_scores Record<string,number> | n-progress line, 颜色按分数分 | — |
| 问题摘要 | :155-170 | issues Array | n-alert, 最多3条 | {severity,message} |
| 生成质检卡 | :181-239 | props.lastWorkflowResult + qcChapterNumber | ConsistencyReportPanel + 俗套句式折叠 + 冲突批注折叠 + 打开编辑/清除按钮 | GenerateChapterWorkflowResponse |
| ghostAnnotation解析 | :297-318 | computed ghostAnnotationLines | string/object→lines | — |

### iOS现状
- 无同名struct（Grep零命中）
- GenerateChapterWorkflowResponse模型已存在
- ChapterStructureDTO **不存在**，需新建
- AutopilotChapterAudit **不存在**，需新建
- ConsistencyReportPanel **不存在**，需新建（或简化内联）
- APIEndpoint.Chapters.structure已存在

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| ChapterStatusPanelView.swift（新建） | ChapterStatusPanel.vue:1-417 |
| ChapterStructureDTO模型（新建） | :250 chapterApi.ChapterStructureDTO |
| AutopilotChapterAudit模型（新建） | :259-276 |
| ConsistencyReportPanelView.swift（新建或内联） | :194-198 |
| 复用GenerateChapterWorkflowResponse | — |
| 复用APIEndpoint.Chapters.structure | :397 |

---

## 4.3-6 CharacterNavigator

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"角色导航"+计数 | CharacterNavigator.vue:4-6 | characters.length | cn-header | — |
| 角色列表 | :9-34 | bibleApi.getBible(slug)→bible.characters | cn-item, 头像+名字+心理状态点+角色Tag | CharacterDTO:{id,name,role?,mental_state?} |
| 选中高亮 | :14,221-226 | selectedCharacterId===char.id | cn-item--active, 左边框3px | — |
| 头像（首字母+角色色） | :17-19,77-79 | getCharacterRoleColor(role) | cn-avatar 圆形 | — |
| 心理状态点 | :24-27,86-91 | classifyCharacterMentalState(mental) | cn-dot--danger/warning/无 | — |
| 角色Tag | :29-32,81-83 | getCharacterRoleLabel/getCharacterRoleCssKey | cn-role-tag--protagonist/supporting/minor | — |
| 点击选中 | :16 | emit('select-character', char.id) | — | — |
| 空状态+前往世界观 | :36-48 | characters为空 | n-empty + n-button→dispatchEvent | — |
| 加载角色 | :105-117 | bibleApi.getBible(slug) | loading状态 | — |
| watch slug + onMounted | :119-121 | — | immediate | — |
| useWorkbenchDeskTickReload | :121 | tick变化→loadCharacters() | — | — |
| defineExpose({loadCharacters}) | :123 | 父组件可调用刷新 | — | — |

### iOS现状
- 无同名struct（Grep零命中）
- CharacterDTO模型需确认（bibleApi.getBible返回）
- APIEndpoint.Bible.getBible需确认
- domain/character标签函数需新建等价

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| CharacterNavigatorView.swift（新建） | CharacterNavigator.vue:1-124 |
| 复用BibleStore/Bible模型（如已有characters字段） | :109-111 |
| domain/character标签函数等价: getCharacterRoleColor/getCharacterRoleLabel/classifyCharacterMentalState | :58-91 |
| 前往世界观导航 | :98-102 |

---

## 4.3-7 ForeshadowChapterSuggestionsPanel

### 原版事实表
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 空状态（未选章节） | ForeshadowChapterSuggestionsPanel.vue:3 | !currentChapterNumber | n-empty | — |
| 提示文本 | :7,61-65 | hintText computed | autoRun模式显示说明 | — |
| 待兑现疑问列表 | :9-33 | foreshadowApi.list(slug)→entries→filter(pending)→items computed | n-card列表, checkbox+章节Tag+距离Tag+疑问文本 | ForeshadowEntry |
| 距离排序 | :69-82 | items computed: pending.map→{entry,distance:Math.abs(e.chapter-ch)}→sort | 近者优先 | — |
| compact模式（最多5条） | :12,54 | props.compact | slice(0, compact?5:12) | — |
| checkbox选中 | :18-21,84-89 | picked Set<string> | togglePick | — |
| 加载 | :91-100 | foreshadowApi.list(slug) | loading状态 | — |
| watch slug+chapterNumber | :102-108 | — | immediate | — |

### iOS现状
- 无同名struct（Grep零命中）
- ForeshadowEntry模型已存在
- APIEndpoint.Foreshadow.list已存在

### 待补
| 端点/Store方法/View | 对齐原版文件:行号 |
|---|---|
| ForeshadowChapterSuggestionsPanelView.swift（新建） | ForeshadowChapterSuggestionsPanel.vue:1-113 |
| 复用ForeshadowEntry + APIEndpoint.Foreshadow.list | :95 |
| 距离排序算法 | :69-82 |

---

## 疑问清单（需主理人确认）

### 疑问1：autopilot版ForeshadowLedger模型映射
原版将ForeshadowEntry映射为本地Foreshadow接口（importance硬编码'medium', description=question, is_collected=status==='consumed'）。iOS是否直接复用ForeshadowEntry原模型在View层做映射，还是建映射后模型？
**建议**：直接复用ForeshadowEntry，View层计算映射。

### 疑问2：StoryTimelineView已存在是否重复
iOS已有StoryTimelineView.swift（Autopilot目录），与原版workbench/StoryTimeline.vue功能高度对齐。是否：(a) 认定已实现跳过？(b) 需新建workbench版？(c) 补snapshotApi.create端点？
**建议**：认定已实现跳过，仅补snapshotApi.create端点（如缺失）。

### 疑问3：CastStore analyzeOutline vs scheduleAndPersist
原版两个方法底层都是POST /novels/{id}/cast/schedule，区别在mode字段(suggest/apply)。iOS APIEndpoint.Cast.schedule(novelId:)是否已对应此端点？如是，CastStore一个方法+mode参数即可。
**建议**：一个方法+mode参数。

### 疑问4：StorylineGitGraph SVG复杂度
原版Git Graph是纯SVG + 复杂路径算法（Branch/Merge贝塞尔曲线、Tooltip、选中详情、回滚）。iOS用SwiftUI Canvas/Path实现等价复杂度较高。是否：(a) 完整SVG复刻？(b) 简化为List+分支关系图？
**建议**：完整复刻用SwiftUIGraphicsContext/Path，不做简化（铁律1禁止简化）。

### 疑问5：ChapterStatusPanel依赖的ConsistencyReportPanel
原版ChapterStatusPanel引用了ConsistencyReportPanel子组件（:194-198）。iOS无此组件。是否：(a) 新建ConsistencyReportPanelView？(b) 内联到ChapterStatusPanel中？
**建议**：新建独立View（对齐原版组件拆分）。

### 疑问6：CharacterNavigator的CharacterDTO来源
原版用bibleApi.getBible(slug)→bible.characters。iOS是否有Bible模型含characters数组？或需用APIEndpoint.Bible其他端点？
**需确认**：iOS Bible模型结构。
