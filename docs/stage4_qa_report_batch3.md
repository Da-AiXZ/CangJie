# 阶段4 批次3 QA独立验收报告

**核验人**: 严过关（Yan, QA Engineer）  
**核验日期**: 2026-06-25  
**核验方式**: 独立读代码逐条核验，不轻信寇豆码自报  
**核验范围**: 3个组件（WorldlineDAGView / ActPlanningModalView / NarrativeDashboardPanelView）+ 3个修改文件（APIEndpoint / EvolutionModels / 配套Models/Store/Utils）  
**防砍机制**: 5（独立核验，不信自报）

---

## 核验结论

- **IS_PASS: YES**（有1处源码Bug需工程师修复，非阻断；核心功能全部对齐）
- **功能对齐度: 46/49**（3项偏差：1处Bug + 2处轻微偏差，均非阻断）
- **编译风险: 0项致命，1项警告**（部分Worldline模型缺显式memberwise init，教训8未完全执行；不影响当前编译）
- **砍功能痕迹: 0**（10个文件"简化版/TODO/暂不实现/后续优化/stub/placeholder"零命中；"占位"4处命中均为合法骨架卡，对齐Vue原版n-skeleton）
- **智能路由判定: Engineer**（NarrativeDashboardStore.hasCriticalPromise/urgentCount使用currentChapterNumber=0导致紧急度分级偏差，需寇豆码修复）

---

## 一、3组件逐条核验

### 组件1: WorldlineDAGView.swift（最高复杂度，重点核验）

**iOS文件**: `Cangjie/Views/Snapshot/WorldlineDAGView.swift`（960行）  
**原版文件**: `frontend/src/components/workbench/WorldlineDAG.vue`（1033行）  
**对齐度: 18/20**

| # | 检查项 | 结果 | 证据(iOS文件:行号) | 对齐原版(Vue文件:行号) |
|---|---|---|---|---|
| 1 | Header(标题+存档/分支/汇流统计+创建存档+刷新) | PASS | :107-152 (headerBar: 标题+统计+plus.circle+arrow.clockwise) | Vue:4-15 一致 |
| 2 | 加载态(ProgressView) | PASS | :156-162 (loadingView: ProgressView("加载世界线…")) | Vue:17 n-spin 一致 |
| 3 | 空状态("暂无世界线记录，章节完成后将自动生成") | PASS | :166-180 (emptyView: git.branch图标+两行文字) | Vue:19-24 一致 |
| 4 | DAG+Detail分栏布局(HStack) | PASS | :184-213 (dagContent: ScrollView+ZStack+detailPanel) | Vue:27-154 wl-body 一致 |
| 5 | Canvas 4层绘制(边/时间线/汇流/分支标签) | PASS | :191-196 (drawEdges+drawTimeMarkers+drawConfluenceCurves+drawBranchLabels) | Vue SVG 4层一致 |
| 6 | 节点卡片用SwiftUI View叠加(非Canvas) | PASS | :200-203 (ForEach layout.nodePositions { nodeCard }) | Vue:97-152 g+rect+text 一致 |
| 7 | 节点accent条(4px色条) | PASS | :517-519 (Rectangle().fill(pos.color).frame(width:nodeW,height:4)) | Vue:118-126 一致 |
| 8 | 节点chapterLabel+triggerShort+name+slice+asset+rollback | PASS | :522-561 (6行Text: chapterLabel/triggerShort/name/sliceLabel/assetLabel/rollbackLabel) | Vue:127-151 一致 |
| 9 | HEAD标记(isHead→"HEAD"badge+bold) | PASS | :530-538 (if pos.isHead: "HEAD" badge) | Vue:103-105,136-138 一致 |
| 10 | 选中高亮(strokeWidth 2.5 + opacity 0.1) | PASS | :570-575 (isSelected?2.5:1 + opacity 0.1) | Vue:102-105,883-886 一致 |
| 11 | onTapGesture节点选择(toggle) | PASS | :576-578 (.onTapGesture { store.selectNode(pos.id) }) | Vue:106 @click="selectNode" 一致；决策#5确认用onTapGesture非SpatialTapGesture |
| 12 | Detail面板-选中节点(trigger标签+name+time+chapter+branch) | PASS | :594-626 (triggerLabel badge + name + formatTime + 第N章 + 分支名) | Vue:157-174 一致 |
| 13 | Detail面板-world_slice网格(time/location/emotional/characters/items) | PASS | :695-724 (worldSliceGrid: time/location/emotionalResidue/characters count+preview/items count) | Vue:175-202 一致 |
| 14 | Detail面板-5个操作按钮(merge/checkout/createBranch/hardReset/delete) | PASS | :636-688 (actionButton×5: 汇入主线+切换+分叉+回滚+删除) | Vue:206-260 一致 |
| 15 | 汇入主线仅非main分支显示 | PASS | :637 (if node.branchName != "main", let branch = branchInfo) | Vue:207 v-if="selectedNode.branch_name !== 'main'" 一致 |
| 16 | hardReset确认弹窗(alert) | PASS | :80-89 (.alert("硬重置确认") + Button("确认重置",role:.destructive)) | Vue:698-718 dialog.warning 一致 |
| 17 | delete确认弹窗(alert) | PASS | :90-99 (.alert("删除存档确认") + Button("删除",role:.destructive)) | Vue无单独确认（直接删除），iOS增加确认是合理增强 |
| 18 | 分支命名Sheet(name输入+storyline Picker+创建) | PASS | :780-831 (branchNamingSheet: TextField+Picker+Button+presentationDetents) | Vue:278-293 n-modal 一致 |
| 19 | 布局算法(branchOrder+sorted+nodeY+viewW/viewH+branchCols) | PASS | :277-432 (computeLayout: branchOrder去重+main置首+sorted by chapter+nodeY+viewW/viewH) | Vue:428-564 一致 |
| 20 | 汇流贝塞尔曲线绘制 | 轻微偏差 | :392-422 (drawConfluenceCurves有绘制，但: ①始终用"main"分支列而非source/target storyline映射; ②固定偏移curve(cx→cx+40,cy→cy-20)而非source→target连接; ③label缺"Ch.X"前缀; ④缺(index%3)*10重叠偏移) | Vue:546-561 用storylineBranchName(cp.source/target_storyline_id)查找分支列+source→target贝塞尔+"Ch.${cp.target_chapter} ${confluenceLabel}"+(index%3)*10 |

**WorldlineDAGView小结**: 18/20 PASS。汇流曲线绘制功能存在（非砍功能），但source→target分支映射简化为固定main列+固定偏移曲线，视觉上不能准确表达跨分支汇流关系。label缺"Ch.X"前缀。非阻断，建议工程师修复。

### 组件2: ActPlanningModalView.swift

**iOS文件**: `Cangjie/Views/Workbench/ActPlanningModalView.swift`（589行）  
**原版文件**: `frontend/src/components/workbench/ActPlanningModal.vue`（428行）  
**对齐度: 15/15**

| # | 检查项 | 结果 | 证据(iOS文件:行号) | 对齐原版(Vue文件:行号) |
|---|---|---|---|---|
| 1 | 4阶段状态机(form/stream/edit/error) | PASS | :23-25 (enum UiPhase: form/stream/edit/error) + :72-81 (switch uiPhase) | Vue:188-189 type UiPhase 一致 |
| 2 | Form阶段(info提示+章节数Stepper+生成按钮) | PASS | :100-138 (formPhase: info.circle.fill提示+Stepper(2...20)+"AI 生成章节规划") | Vue:24-44 一致 |
| 3 | Stream阶段进度条(progressPct% + statusMessage) | PASS | :145-171 (GeometryReader进度条+statusMessage+百分比) | Vue:48-50,240-250 一致 |
| 4 | Stream阶段LLM原始输出预览(llmStreamPreview) | PASS | :174-193 (if !llmStreamPreview.isEmpty: ScrollView+monospaced Text) | Vue:52-59 一致 |
| 5 | Stream阶段流式章节卡(title+outline+bible_elements tags) | PASS | :198-207 (ForEach streamPreview: streamChapterCard) + :223-251 (title/outline/bibleElements) | Vue:61-79 一致 |
| 6 | Stream阶段骨架占位卡(skeletonCount) | PASS | :202-204 (ForEach 0..<skeletonCount: skeletonCard()) + :254-270 (RoundedRectangle占位) | Vue:81-93 n-skeleton 一致 |
| 7 | skeletonCount计算(exp==0→min(6,max(2,got+2)); else→min(20,max(0,exp-got))) | PASS | :59-67 (skeletonCount: if exp==0 return min(6,max(2,got+2)); return min(20,max(0,exp-got))) | Vue:207-213 完全一致 |
| 8 | Edit阶段(成功提示+章节编辑卡+重新生成/确认按钮) | PASS | :274-312 (editPhase: checkmark提示+ForEach chapters编辑卡+"重新生成"+"确认并保存") | Vue:101-144 一致 |
| 9 | 章节编辑卡(TextField标题+TextEditor大纲+bible_elements tags) | PASS | :315-364 (chapterEditCard: TextField+TextEditor+ScrollView tags) | Vue:109-135 一致 |
| 10 | Error阶段(错误消息+关闭/返回按钮) | PASS | :368-395 (errorPhase: xmark.circle+streamError+"关闭"+"返回") | Vue:146-153 一致 |
| 11 | SSE 5种事件分发(status/chunk/chapter/done/error) | PASS | :444-463 (switch eventName: "status"→handleStatus / "chunk"→handleChunk / "chapter"→handleChapter / "done"→handleDone / "error"→错误处理) | Vue:240-283 onStatus/onChunk/onChapter/onDone/onError 一致 |
| 12 | SSE URL query param(chapter_count via URLComponents) | PASS | :427-434 (URLComponents+queryItems:[URLQueryItem(name:"chapter_count",value:"\(chapterCount)")]) | Vue:237 streamActChapterPlan + 决策#8确认在调用处拼URL |
| 13 | mapRawToDraft(title/outline或description回退/bible_elements) | PASS | :530-535 (title=c["title"]??""; outline=c["outline"]??c["description"]??""; bibleElements=c["bible_elements"]??[]) | Vue:215-225 一致 |
| 14 | abortStream/backToForm/close/confirm生命周期 | PASS | :540-588 (abortStream:cancel+reset; backToForm:cancel+reset; close:cancel+isPresented=false; confirm:API call+isPresented=false) | Vue:289-349 一致 |
| 15 | onDisappear→abortStream | PASS | :93-95 (.onDisappear { abortStream() }) | Vue:333-335 onUnmounted→abort 一致 |

**ActPlanningModalView小结**: 15/15 全部PASS。SSE 5事件分发完整，4阶段状态机完整，生命周期管理完整。

### 组件3: NarrativeDashboardPanelView.swift

**iOS文件**: `Cangjie/Views/Workbench/NarrativeDashboardPanelView.swift`（539行）+ `NarrativeDashboardStore.swift`（224行）  
**原版文件**: `frontend/src/components/workbench/NarrativeDashboardPanel.vue`（915行）  
**对齐度: 13/14**

| # | 检查项 | 结果 | 证据(iOS文件:行号) | 对齐原版(Vue文件:行号) |
|---|---|---|---|---|
| 1 | Header(标题"叙事简报"+章节tag+"三系统联合感知·实时快照"+刷新) | PASS | :59-96 (header: "叙事简报"+第N章tag+lead text+arrow.clockwise) | Vue:5-30 一致 |
| 2 | Section①叙事时刻(phase badge+进度统计+进度条+阶段轴+阶段提示) | PASS | :100-161 (momentSection: phaseLabel badge+第N/M章+进度%+GeometryReader进度条+phaseAxis+phaseHint) | Vue:36-100 一致 |
| 3 | 阶段轴(点+线+标签, done/active状态) | PASS | :164-203 (phaseAxis: ForEach STORY_PHASE_STAGES: Circle done?success:active?primary + Rectangle line + Text label) | Vue:68-96 一致 |
| 4 | Section②活跃线体(role标签+名称+里程碑进度条+里程碑标签) | PASS | :207-286 (activeStorylinesSection: getStorylineRoleCompactLabel+name+GeometryReader进度条+curr/total) | Vue:102-135 一致 |
| 5 | 活跃故事线过滤(chapter range + not completed/cancelled + slice 5) | PASS | Store:139-153 (activeStorylines: filter start<=ch&&(end==0||ch<=end)&&status!=completed/cancelled, prefix(5)) | Vue:327-340 一致 |
| 6 | Section③未兑承诺(紧急度圆点+来源章节+问题+剩余章数+计数chip) | PASS | :290-389 (pendingPromisesSection+promiseRow: Circle urgencyColor+[ch.N]+question+remaining章) | Vue:137-175 一致 |
| 7 | 紧急伏笔排序(by suggestedResolveChapter, first 5) | PASS | Store:156-165 (urgentForeshadows: sorted by suggestedResolveChapter??9999, prefix(5)) | Vue:342-351 一致 |
| 8 | foreshadowUrgencyClass(critical→danger, remaining≤3→danger, ≤10→warning, high→warning) | PASS | Store:214-224 (foreshadowUrgencyClass: critical→danger; due&ch>0: ≤3→danger,≤10→warning; high→warning; else muted) | Vue:410-421 一致 |
| 9 | Section④角色当下(role icon+name+mental state+core belief+跳转档案) | PASS | :393-475 (characterSection: getCharacterRoleIcon+name+mentalState chip+coreBelief+NotificationCenter post) | Vue:177-211 一致 |
| 10 | Section⑤引擎记忆(折叠, 4行: 锚点/声线/债务/紧急) | PASS | :481-519 (engineMemorySection: DisclosureGroup + engineRow×4: 全书锚点/角色声线/叙事债务/紧急伏笔) | Vue:213-246 一致 |
| 11 | 4路并行加载(storyEvolution+foreshadow+psyches+bible) | PASS | Store:36-54 (load: async let×4 + await(evo,fs,ps,bible)) | Vue:438-451 Promise.allSettled 一致 |
| 12 | characterMentalState(bibleCharMap, skip空/NORMAL) | PASS | Store:198-203 (characterMentalState: bibleCharMap[name], trim, skip空/NORMAL) | Vue:378-384 一致 |
| 13 | hasCriticalPromise/urgentCount紧急度聚合 | **BUG** | Store:168-175 (hasCriticalPromise: foreshadowUrgencyClass($0,currentChapterNumber:**0**); urgentCount: 同样传**0**) | Vue:353-359 foreshadowUrgencyClass(e)使用props.currentChapter?.number??0，此处应传入实际章节号 |
| 14 | 跳角色档案用NotificationCenter(复用StoryEvolutionPanel通知名) | PASS | :402-405 + :431-434 (NotificationCenter.default.post(name: StoryEvolutionPanel.openCharacterAnchorNotification)) | Vue:427-431 window.dispatchEvent(CustomEvent) → 决策#12/#13确认用NotificationCenter |

**NarrativeDashboardPanel小结**: 13/14 PASS，1处Bug。

---

## 二、13项决策执行核验

| # | 决策内容 | 执行结果 | 证据 |
|---|---|---|---|
| 1 | Worldline EndpointInfo扩展补全(12 case的path+method) | ✅ PASS | APIEndpoint.swift:1798-1840 (extension APIEndpoint.Worldline: EndpointInfo, path switch 12 case + method switch 12 case 全覆盖) |
| 2 | WorldlineDAGView完全去掉SnapshotStore，纯用WorldlineStore | ✅ PASS | WorldlineDAGView.swift:15 (@StateObject private var store = **WorldlineStore**()); Grep SnapshotStore仅命中注释:6("不再用SnapshotStore伪造") |
| 3 | novelId从appState.currentNovelId获取 | ✅ PASS | WorldlineDAGView.swift:76 (if let novelId = **appState.currentNovelId**); AppState.swift:104 (@Published var currentNovelId: String?) |
| 4 | Canvas画边/时间线/汇流曲线 + SwiftUI View叠加画节点卡片 | ✅ PASS | WorldlineDAGView.swift:191-203 (Canvas { drawEdges+drawTimeMarkers+drawConfluenceCurves+drawBranchLabels } + ForEach nodeCard) |
| 5 | 节点用onTapGesture(非SpatialTapGesture) | ✅ PASS | WorldlineDAGView.swift:576 (**.onTapGesture** { store.selectNode } ); Grep SpatialTapGesture在批次3文件零命中 |
| 6 | 新建WorldlineCheckpointNode模型，不动现有CheckpointDTO | ✅ PASS | WorldlineModels.swift:36 (struct **WorldlineCheckpointNode**); Grep CheckpointDTO未出现在WorldlineModels.swift |
| 7 | Confluence端点放入APIEndpoint.Worldline枚举(case confluenceList) | ✅ PASS | APIEndpoint.swift:448 (case **confluenceList**(novelId: String)); path:1824 ("/novels/\(novelId)/confluence-points") 对齐 confluence.ts:18 |
| 8 | SSE URL query param在调用处拼URL(URLComponents追加?chapter_count=N) | ✅ PASS | ActPlanningModalView.swift:429-431 (var components = **URLComponents**(url:baseURL); components?.queryItems = [URLQueryItem(name:"chapter_count",value:"\(chapterCount)")]) |
| 9 | StorylineDTO补5字段(milestones/currentMilestoneIndex/lastActiveChapter/progressSummary/chapterWeight, 用decodeIfPresent) | ✅ PASS | EvolutionModels.swift:376-384 (5个let字段 + CodingKeys) + :409-413 (5个decodeIfPresent) |
| 10 | domain辅助函数集中在Cangjie/Utils/StorylineDomain.swift | ✅ PASS | StorylineDomain.swift:1-225 (normalizeStoryPhase/getStoryPhaseLabel/getStoryPhaseHint/getStoryPhaseColor/isStoryPhasePast/getConfluenceLabel/getStorylineRoleCompactLabel/getStorylineRoleCssKey/getStorylineRoleColor/isMainStoryline/getCharacterRoleSortOrder/getCharacterRoleIcon/getCharacterRoleLabel/getCharacterRoleColor) |
| 11 | 伏笔filter在Store层(复用pendingEntries或filter status=="pending")，不改端点协议 | ✅ PASS | NarrativeDashboardStore.swift:74-77 (let allEntries = try await apiClient.request(APIEndpoint.Foreshadow.list); return allEntries.filter { $0.status == "pending" }) |
| 12 | 跳角色档案用NotificationCenter.default.post(name: StoryEvolutionPanel.openCharacterAnchorNotification) | ✅ PASS | NarrativeDashboardPanelView.swift:402-404 (NotificationCenter.default.post(name: StoryEvolutionPanel.openCharacterAnchorNotification, object: nil)) |
| 13 | 复用已有通知名，不重新设计路由 | ✅ PASS | Grep确认openCharacterAnchorNotification定义在StoryEvolutionPanel.swift:25 (static let openCharacterAnchorNotification = Notification.Name("OpenCharacterAnchor"))，NarrativeDashboardPanelView复用同一通知名 |

**13项决策全部执行到位。**

---

## 三、编译风险扫描

### 3.1 教训10：struct同名冲突扫描

| struct/class名 | 声明处数 | 结果 |
|---|---|---|
| WorldlineGraph | 1 (WorldlineModels.swift:13) | ✅ PASS |
| WorldlineCheckpointNode | 1 (WorldlineModels.swift:36) | ✅ PASS |
| WorldlineBranchInfo | 1 (WorldlineModels.swift:168) | ✅ PASS |
| WorldlineCheckoutResult | 1 (WorldlineModels.swift:215) | ✅ PASS |
| WorldlineEdge | 1 (WorldlineModels.swift:195) | ✅ PASS |
| WorldSlice | 1 (WorldlineModels.swift:72) | ✅ PASS |
| RollbackSlice | 1 (WorldlineModels.swift:146) | ✅ PASS |
| ConfluencePointDTO | 1 (WorldlineModels.swift:330) | ✅ PASS |
| ChapterDraft | 1 (ChapterDraft.swift:13) | ✅ PASS |
| ActPlanningModalView | 1 (ActPlanningModalView.swift:13) | ✅ PASS |
| NarrativeDashboardPanelView | 1 (NarrativeDashboardPanelView.swift:12) | ✅ PASS |
| WorldlineStore | 1 (WorldlineStore.swift:14) | ✅ PASS |
| NarrativeDashboardStore | 1 (NarrativeDashboardStore.swift:14) | ✅ PASS |

**13个struct/class全部仅1处声明，零冲突。**

### 3.2 教训11：EndpointInfo扩展覆盖率扫描

| 子枚举 | EndpointInfo扩展 | 结果 |
|---|---|---|
| **APIEndpoint.Worldline (批次3重点)** | ✅ 有 (APIEndpoint.swift:1798) | 12 case的path+method全覆盖 |
| APIEndpoint.Novels | ✅ 有 (:721) | — |
| APIEndpoint.Chapters | ✅ 有 (:774) | — |
| APIEndpoint.Autopilot | ✅ 有 (:826) | — |
| APIEndpoint.Bible | ✅ 有 (:879) | — |
| APIEndpoint.DAG | ✅ 有 (:935) | — |
| APIEndpoint.LLMControl | ✅ 有 (:991) | — |
| APIEndpoint.Planning | ✅ 有 (:1072) | — |
| APIEndpoint.Stats | ✅ 有 (:1116) | — |
| APIEndpoint.StoryStructure | ✅ 有 (:1135) | — |
| APIEndpoint.Cast | ✅ 有 (:1173) | — |
| APIEndpoint.Foreshadow | ✅ 有 (:1205) | — |
| APIEndpoint.Monitor | ✅ 有 (:1237) | — |
| APIEndpoint.Export | ✅ 有 (:1254) | — |
| APIEndpoint.Checkpoints | ✅ 有 (:1269) | — |
| APIEndpoint.Snapshots | ✅ 有 (:1309) | — |
| APIEndpoint.Governance | ✅ 有 (:1337) | — |
| APIEndpoint.Evolution | ✅ 有 (:1365) | — |
| APIEndpoint.Chronicles | ✅ 有 (:1393) | — |
| APIEndpoint.Trace | ✅ 有 (:1415) | — |
| APIEndpoint.Props | ✅ 有 (:1438) | — |
| APIEndpoint.AntiAI | ✅ 有 (:1474) | — |
| APIEndpoint.Sandbox | ✅ 有 (:1510) | — |
| APIEndpoint.KnowledgeGraph | ✅ 有 (:1538) | — |
| APIEndpoint.Voice | ✅ 有 (:1584) | — |
| APIEndpoint.AIInvocation | ✅ 有 (:1623) | — |
| APIEndpoint.Workflow | ✅ 有 (:1664) | — |
| APIEndpoint.ChapterElement | ✅ 有 (:1699) | — |
| APIEndpoint.Manuscript | ✅ 有 (:1741) | — |
| APIEndpoint.NarrativeEngine | ✅ 有 (:1763) | — |
| APIEndpoint.BeatSheets | ✅ 有 (:1776) | — |
| APIEndpoint.Settings | ⚠️ 无 | 预存问题，非批次3引入；Grep确认Settings枚举未被任何代码调用，不致编译错误 |
| APIEndpoint.System | ⚠️ 无 | 同上，未被调用 |
| APIEndpoint.Taxonomy | ⚠️ 无 | 同上，仅注释提及"保留备用" |

**Worldline枚举12 case EndpointInfo全覆盖（教训11修复确认）。Settings/System/Taxonomy缺扩展为预存问题，不影响编译（未被调用）。**

### 3.3 教训8：memberwise init完整性

| 模型 | 显式memberwise init | 结果 |
|---|---|---|
| ChapterDraft | ✅ 有 (ChapterDraft.swift:24 init(title:outline:bibleElements:)) | PASS |
| CreateWorldlineCheckpointRequest | ✅ 隐式（无自定义init，Swift合成） | PASS |
| CreateWorldlineBranchRequest | ✅ 隐式 | PASS |
| MergeWorldlineBranchRequest | ✅ 隐式 | PASS |
| ConfirmActChaptersRequest | ✅ 隐式 | PASS |
| WorldlineGraph | ❌ 无（仅有init(from decoder:)） | ⚠️ 警告 |
| WorldlineCheckpointNode | ❌ 无 | ⚠️ 警告 |
| WorldSlice | ❌ 无 | ⚠️ 警告 |
| WorldSliceCharacter | ❌ 无 | ⚠️ 警告 |
| WorldSliceItem | ❌ 无 | ⚠️ 警告 |
| RollbackSlice | ❌ 无 | ⚠️ 警告 |
| WorldlineBranchInfo | ❌ 无 | ⚠️ 警告 |
| WorldlineEdge | ❌ 无 | ⚠️ 警告 |
| WorldlineCheckoutResult | ❌ 无 | ⚠️ 警告 |
| ConfluencePointDTO | ❌ 无 | ⚠️ 警告 |
| CreateWorldlineCheckpointResponse | ❌ 无 | ⚠️ 警告 |
| CreateWorldlineBranchResponse | ❌ 无 | ⚠️ 警告 |
| MergeWorldlineBranchResponse | ❌ 无 | ⚠️ 警告 |
| ConfirmActChaptersResponse | ❌ 无（有init(from decoder:)） | ⚠️ 警告 |

**警告说明**: 11个API响应模型仅有`init(from decoder:)`无显式memberwise init。当前代码仅从API解码这些模型（不手动构造），不影响编译。但教训8要求显式memberwise init以便测试/预览构造。非阻断，建议后续补全。

### 3.4 其他编译风险扫描

| 检查项 | 结果 | 证据 |
|---|---|---|
| CodingKeys全覆盖存储属性 | ✅ PASS | 逐个核验：WorldlineModels.swift所有Codable模型的CodingKeys覆盖全部let存储属性；ChapterDraft.swift CodingKeys覆盖title/outline/bibleElements |
| catch块error常量(教训1) | ✅ PASS | WorldlineStore/NarrativeDashboardStore/ActPlanningModalView所有catch块均读取error(如error.localizedDescription)，无赋值error= |
| iOS 16兼容(无@Observable/@Bindable/NavigationSplitView/.scrollContentMargins/SpatialTapGesture) | ✅ PASS | Grep批次3的10个文件：@Observable/@Bindable/NavigationSplitView/.scrollContentMargins/SpatialTapGesture 零命中（StorylineGitGraphView的SpatialTapGesture和WorkbenchView的NavigationSplitView为非批次3文件） |
| 日期解码用CangjieDecoder.shared | ✅ PASS | 批次3模型均用decodeIfPresent(String)解码日期字段（ISO字符串），不直接用JSONDecoder；WorldlineStore/NarrativeDashboardStore通过apiClient.request解码（APIClient内部用CangjieDecoder） |
| Store用ObservableObject+@Published | ✅ PASS | WorldlineStore.swift:14 (final class WorldlineStore: **ObservableObject**) + @Published×9; NarrativeDashboardStore.swift:14 (final class NarrativeDashboardStore: **ObservableObject**) + @Published×6 |
| SSE用SSEClient+decodeAsDictionary() | ✅ PASS | ActPlanningModalView.swift:49 (private let sseClient = **SSEClient**()) + :442 (guard let dict = event.**decodeAsDictionary**() else { continue }) |
| @MainActor标注Store | ✅ PASS | WorldlineStore.swift:13 (**@MainActor** final class WorldlineStore); NarrativeDashboardStore.swift:13 (**@MainActor** final class NarrativeDashboardStore) |

---

## 四、砍功能/偷工减料扫描

**扫描范围**: 批次3的10个文件  
**扫描关键词**: "简化版" / "TODO" / "暂不实现" / "后续优化" / "stub" / "placeholder" / "FIXME" / "占位"

| 关键词 | 命中数 | 命中详情 | 判定 |
|---|---|---|---|
| 简化版 | 0 | — | ✅ |
| TODO | 0 | — | ✅ |
| FIXME | 0 | — | ✅ |
| 暂不实现 | 0 | — | ✅ |
| 后续优化 | 0 | — | ✅ |
| stub | 0 | — | ✅ |
| placeholder | 0 | — | ✅ |
| 占位 | 4 | ActPlanningModalView.swift:58 "骨架占位数"(skeletonCount计算属性); :106 "流式骨架与占位"(info提示文案); :201 "骨架占位"(ForEach注释); :253 "骨架占位卡"(skeletonCard函数) | ✅ 合法（对齐Vue:81-93 n-skeleton骨架卡，是真实功能非偷工减料） |

**砍功能痕迹: 0**（"占位"4处均为合法骨架加载卡，对齐Vue原版n-skeleton设计）

---

## 五、真实实现核验（非空函数/stub）

### 5.1 WorldlineDAGView - Canvas 4层绘制 + 6种git交互

| 方法 | 实质实现 | 行号 |
|---|---|---|
| drawEdges | ✅ 贝塞尔曲线连接from.cy→to.cy，merge边绿色实线/普通边灰色虚线 | :437-453 |
| drawTimeMarkers | ✅ 虚线横线+章节标签Text | :456-470 |
| drawConfluenceCurves | ✅ 贝塞尔曲线+圆角矩形标记+标签（简化但非空） | :473-491 |
| drawBranchLabels | ✅ 竖线+分支名Text | :494-510 |
| createManualCheckpoint | ✅ API POST + loadGraph | Store:97-122 |
| checkout | ✅ API POST + loadAll | Store:125-141 |
| mergeBranch | ✅ API POST + loadAll | Store:144-167 |
| hardReset | ✅ API POST + loadAll | Store:170-186 |
| deleteCheckpoint | ✅ API DELETE + loadGraph | Store:189-206 |
| createBranch | ✅ API POST + loadAll | Store:209-233 |

### 5.2 ActPlanningModalView - SSE 5种事件分发

| 事件 | 处理 | 行号 |
|---|---|---|
| status | ✅ handleStatus: message/percent/expected_chapters/phase | :477-493 |
| chunk | ✅ handleChunk: llmStreamPreview += text | :496-502 |
| chapter | ✅ handleChapter: streamPreview.append(mapRawToDraft) | :505-510 |
| done | ✅ handleDone: chapters = rawChapters.map + 转edit阶段 | :514-527 |
| error | ✅ streamError = msg + 转error阶段 | :455-460 |

### 5.3 NarrativeDashboardPanel - 5个section + 4路并行加载

| Section | 实质实现 | 行号 |
|---|---|---|
| ①叙事时刻 | ✅ phase badge + progress bar + phase axis(dots+lines+labels) + hint | :100-161 |
| ②活跃线体 | ✅ storyline rows(role tag+name+milestone bar+label) | :207-286 |
| ③未兑承诺 | ✅ promise rows(urgency dot+origin+question+remaining) + count chip | :290-389 |
| ④角色当下 | ✅ character rows(role icon+name+mental state+belief) + jump button | :393-475 |
| ⑤引擎记忆 | ✅ DisclosureGroup(4 rows: anchor/voice/debt/urgent) | :481-519 |
| 4路并行加载 | ✅ async let×4(evo/foreshadow/psyches/bible) + await | Store:36-54 |

**无空函数/stub/占位实现。**

---

## 六、原版文件+行号标注核验（机制4）

| 文件 | 标注情况 | 结果 |
|---|---|---|
| WorldlineDAGView.swift | 每个方法/计算属性注释标注"对齐原版 WorldlineDAG.vue:行号" (如 :7 "对齐原版 WorldlineDAG.vue:1-770"、:17 "WorldlineDAG.vue:358-363"、:105 "WorldlineDAG.vue:4-15" 等) | ✅ PASS |
| WorldlineModels.swift | 每个模型注释标注"对应原版 worldline.ts:行号" (如 :12 "worldline.ts:38-43"、:35 "worldline.ts:6-28" 等) | ✅ PASS |
| WorldlineStore.swift | 方法注释标注"WorldlineDAG.vue:行号" (如 :47 "WorldlineDAG.vue:568-578"、:96 "WorldlineDAG.vue:639-654" 等) | ✅ PASS |
| ActPlanningModalView.swift | 方法注释标注"ActPlanningModal.vue:行号" (如 :21 "ActPlanningModal.vue:188-189"、:98 "ActPlanningModal.vue:24-44" 等) | ✅ PASS |
| ChapterDraft.swift | 标注"ActPlanningModal.vue:163-168" | ✅ PASS |
| NarrativeDashboardPanelView.swift | 方法注释标注"NarrativeDashboardPanel.vue:行号" (如 :13 "NarrativeDashboardPanel.vue:286-293"、:98 "NarrativeDashboardPanel.vue:36-100" 等) | ✅ PASS |
| NarrativeDashboardStore.swift | 方法注释标注"NarrativeDashboardPanel.vue:行号" (如 :35 "NarrativeDashboardPanel.vue:434-451"、:112 "NarrativeDashboardPanel.vue:306" 等) | ✅ PASS |
| StorylineDomain.swift | 标注"storyline.ts:行号" + "character.ts:行号" | ✅ PASS |
| APIEndpoint.swift (Worldline部分) | 每个case标注"worldline.ts:行号" (如 :425 "worldline.ts:53-54"、:448 "confluence.ts:16-18") | ✅ PASS |
| EvolutionModels.swift (StorylineDTO部分) | 标注"workflow.ts:31-46" + 字段标注行号 | ✅ PASS |

---

## 七、Bug详情（路由至工程师）

### Bug-1: NarrativeDashboardStore.hasCriticalPromise/urgentCount紧急度分级偏差

**严重级别**: 中（影响UI显示，非崩溃）  
**路由至**: 工程师寇豆码（software-engineer）

**问题描述**:  
`NarrativeDashboardStore.swift:168-175` 中 `hasCriticalPromise` 和 `urgentCount` 两个计算属性调用 `foreshadowUrgencyClass($0, currentChapterNumber: 0)`，始终传入 `0` 而非实际当前章节号。

**原版行为** (NarrativeDashboardPanel.vue:353-359 + 410-421):
```javascript
const hasCriticalPromise = computed(() =>
  urgentForeshadows.value.some(e => foreshadowUrgencyClass(e) === 'danger'),
)
function foreshadowUrgencyClass(entry) {
  if (entry.importance === 'critical') return 'danger'
  const due = entry.suggested_resolve_chapter
  const ch = props.currentChapter?.number ?? 0  // ← 使用实际章节号
  if (due && ch > 0) {
    const remaining = due - ch
    if (remaining <= 3) return 'danger'    // ← 距到期≤3章→danger
    if (remaining <= 10) return 'warning'
  }
  if (entry.importance === 'high') return 'warning'
  return 'muted'
}
```

**iOS当前行为** (NarrativeDashboardStore.swift:168-175):
```swift
var hasCriticalPromise: Bool {
    urgentForeshadows.contains { foreshadowUrgencyClass($0, currentChapterNumber: 0) == .danger }
    //                                                                              ^ 固定传0
}
var urgentCount: Int {
    pendingForeshadows.filter { foreshadowUrgencyClass($0, currentChapterNumber: 0) == .danger }.count
    //                                                                               ^ 固定传0
}
```

**影响**:  
当 `currentChapterNumber=0` 时，`foreshadowUrgencyClass` 中 `if let due = due, currentChapterNumber > 0` 分支被跳过，导致：
- `importance != "critical"` 但距到期≤3章的伏笔不会被判定为 `.danger`
- `hasCriticalPromise` 可能返回 `false`（本应 `true`）→ 未兑承诺chip显示黄色(warning)而非红色(danger)
- `urgentCount` 低估 → 引擎记忆"紧急伏笔"计数偏低

**注意**: View层的 `promiseRow` (:348) 正确传入 `currentChapterNumber: currentChapterNumber`，单行紧急度显示无误。仅Store层聚合属性受影响。

**建议修复**:  
将 `hasCriticalPromise` 和 `urgentCount` 改为接收 `currentChapterNumber` 参数的方法，或在Store中存储 `currentChapterNumber` 属性：

```swift
// 方案A: 改为方法
func hasCriticalPromise(currentChapterNumber: Int) -> Bool {
    urgentForeshadows.contains { foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber) == .danger }
}
func urgentCount(currentChapterNumber: Int) -> Int {
    pendingForeshadows.filter { foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber) == .danger }.count
}

// View调用处改为:
store.hasCriticalPromise(currentChapterNumber: currentChapterNumber)
store.urgentCount(currentChapterNumber: currentChapterNumber)
```

**涉及文件**:  
- `Cangjie/ViewModels/NarrativeDashboardStore.swift:168-175`
- `Cangjie/Views/Workbench/NarrativeDashboardPanelView.swift:304,506`（调用处需同步修改）

---

## 八、轻微偏差汇总（非阻断）

| # | 偏差描述 | 涉及文件:行号 | 对齐原版:行号 | 影响 |
|---|---|---|---|---|
| 1 | WorldlineDAGView汇流曲线始终用"main"分支列，未实现storylineBranchName(source/target)映射；曲线用固定偏移(cx→cx+40,cy→cy-20)而非source→target连接；label缺"Ch.X"前缀；缺(index%3)*10重叠偏移 | WorldlineDAGView.swift:392-422 | Vue:546-561 | 汇流曲线绘制功能存在但视觉简化，不能准确表达跨分支汇流关系。非砍功能。 |
| 2 | WorldlineDAGView空详情面板汇流列表仅显示"第N章"+mergeType标签，缺"storylineName(source)→storylineName(target)"文本 | WorldlineDAGView.swift:758-770 | Vue:271 "第N章·sourceName→targetName" | 信息略减，非核心功能。 |
| 3 | 11个Worldline API响应模型缺显式memberwise init（仅有init(from decoder:)） | WorldlineModels.swift 全文 | 教训8要求 | 当前不影响编译（仅从API解码），但违反教训8规范，影响测试可构造性。 |
| 4 | APIEndpoint.Settings/System/Taxonomy缺EndpointInfo扩展 | APIEndpoint.swift | 教训11 | 预存问题（非批次3引入），这三个枚举未被任何代码调用，不致编译错误。 |

---

## 九、智能路由判定

### 判定: Engineer（源码有Bug）

**路由对象**: 寇豆码（software-engineer）

**需修复项**:

1. **Bug-1**: `NarrativeDashboardStore.hasCriticalPromise` 和 `urgentCount` 传入 `currentChapterNumber: 0` 而非实际章节号，导致紧急度聚合判断偏差。需改为方法接收参数或Store存储章节号属性。涉及 `NarrativeDashboardStore.swift:168-175` + `NarrativeDashboardPanelView.swift:304,506` 调用处。

**非阻断偏差（建议但不阻断本轮）**:
- 汇流曲线source→target分支映射简化（偏差#1）
- 空详情面板汇流列表缺storylineName（偏差#2）
- 11个模型缺memberwise init（偏差#3，教训8）

---

## 十、总结

| 维度 | 结果 |
|---|---|
| IS_PASS | **YES**（核心功能全部对齐，1处Bug非阻断） |
| 功能对齐度 | **46/49**（3项偏差：1 Bug + 2轻微偏差） |
| 13项决策执行 | **13/13 全部到位** |
| 编译风险 | 0致命，1警告（memberwise init） |
| 砍功能痕迹 | 0 |
| 空函数/stub | 0 |
| 原版行号标注 | 10/10 文件全部标注 |
| 智能路由 | **Engineer**（Bug-1 → 寇豆码修复） |

**寇豆码自报"IS_PASS:YES、对齐度100%"核验结果**: IS_PASS:YES确认，但对齐度100%不准确，实际46/49≈93.9%。存在1处需修复Bug + 2处轻微偏差。历史经验教训再次验证：**不可轻信自报，必须独立逐条核验**。
