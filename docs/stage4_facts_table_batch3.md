# 阶段4 批次3 事实表（4.2世界线DAG重写 + ActPlanningModal + NarrativeDashboardPanel）

> 工程师：寇豆码（Kou）  
> 日期：2026-06-26  
> 状态：待主理人确认（防砍机制1）

---

## 4.2 世界线DAG重写（伪造→真实，最高复杂度）

### 原版事实表 - worldline.ts API

| # | 端点方法 | HTTP方法 | 路径 | 请求体 | 响应 | 对齐原版文件:行号 |
|---|---|---|---|---|---|---|
| W1 | `getGraph` | GET | `/novels/${novelId}/worldline/graph` | — | `WorldlineGraph` | worldline.ts:53-54 |
| W2 | `listCheckpoints` | GET | `/novels/${novelId}/worldline/checkpoints` | — | `CheckpointNode[]` | worldline.ts:56-57 |
| W3 | `createCheckpoint` | POST | `/novels/${novelId}/worldline/checkpoints` | `{trigger_type?, name, description?, branch_name?}` | `{checkpoint_id: string}` | worldline.ts:59-65 |
| W4 | `listBranches` | GET | `/novels/${novelId}/worldline/branches` | — | `BranchInfo[]` | worldline.ts:67-68 |
| W5 | `createBranch` | POST | `/novels/${novelId}/worldline/branches` | `{name, from_checkpoint_id, storyline_id?}` | `{branch_id: string}` | worldline.ts:70-74 |
| W6 | `checkout` | POST | `/novels/${novelId}/worldline/checkpoints/${checkpointId}/checkout` | `{}` | `CheckoutResult` | worldline.ts:76-80 |
| W7 | `hardReset` | POST | `/novels/${novelId}/worldline/checkpoints/${checkpointId}/hard-reset` | `{}` | `CheckoutResult` | worldline.ts:82-86 |
| W8 | `deleteCheckpoint` | DELETE | `/novels/${novelId}/worldline/checkpoints/${checkpointId}` | — | void | worldline.ts:88-89 |
| W9 | `getBranchByStoryline` | GET | `/novels/${novelId}/worldline/branches/by-storyline/${storylineId}` | — | `BranchInfo \| null` | worldline.ts:91-94 |
| W10 | `updateBranch` | PUT | `/novels/${novelId}/worldline/branches/${branchId}` | `{name?, storyline_id?}` | `BranchInfo` | worldline.ts:96-104 |
| W11 | `mergeBranch` | POST | `/novels/${novelId}/worldline/branches/${branchId}/merge` | `{target_branch_name?, name?, description?}` | `{checkpoint_id, message}` | worldline.ts:106-114 |

#### 原版数据模型 - worldline.ts

| 模型 | 字段 | 对齐原版文件:行号 |
|---|---|---|
| `CheckpointNode` | id, name, trigger_type, branch_name, created_at, anchor_chapter(number\|null), world_slice?(chapter_number?, time_anchor?, location?, emotional_residue?, characters?[{id,name,status,location?}], items?[{id,name,holder?}], actions_count?, conflicts_count?), rollback_slice?({to_checkpoint_id, to_chapter, branch_name}) | worldline.ts:6-28 |
| `BranchInfo` | id, name, head_id, is_default(number), storyline_id(string\|null) | worldline.ts:30-36 |
| `WorldlineGraph` | nodes: CheckpointNode[], edges: {from, to, kind?}[], branches: BranchInfo[], head_id: string\|null | worldline.ts:38-43 |
| `CheckoutResult` | stash_id, restored_chapters, deleted_chapters, message | worldline.ts:45-50 |

### 原版事实表 - WorldlineDAG.vue 组件

#### Props / Emits
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| Props: `slug: string` | :305-308 | — | — | — |
| Emit: `checkpoint-restored` | :309 | checkout/hardReset成功后触发 | 通知父组件刷新 | — |

#### Header 区域
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"世界线版本图" | :6 | 静态文本 | n-text strong 14px | — |
| 统计摘要（存档数·分支数·汇流点数） | :7 | nodes.length + graphData.branches.length + confluencePoints.length | span 11px | number |
| 创建存档按钮 | :10-12 | `worldlineApi.createCheckpoint(slug, {trigger_type:'MANUAL', name:'手动存档 '+时间})` | n-button small, loading=saving | :639-654 handleManualCheckpoint |
| 刷新按钮 | :13-14 | `load()` → `worldlineApi.getGraph(slug)` | n-button small, loading=loading | :568-578 |

#### 空状态 / 加载态
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 加载中 Spin | :17 | loading ref | n-spin show=loading | boolean |
| 空状态 | :19-24 | `!loading && nodes.length === 0` | n-empty "暂无世界线记录，章节完成后将自动生成" | — |
| DAG+Detail 分栏布局 | :27 | `nodes.length > 0` | div.wl-body flex-row | — |

#### SVG 图布局算法（核心复杂度）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 常量 NODE_W=154, NODE_H=68, COL_W=170, ROW_H=88, TOP_PAD=42, LEFT_PAD=66 | :358-363 | — | 布局尺寸常量 | — |
| 分支列分配算法 | :428-440 | branches.forEach → branchOrder[], nodes.forEach补充 | 按branch.name分配列索引 | branchOrder: string[] |
| 节点排序（按章节时间） | :443-448 | sorted = [...ns].sort((a,b) => anchor_chapter \|\| world_slice.chapter_number 比较, 再 created_at) | — | sorted: CheckpointNode[] |
| 节点Y坐标计算 | :451-454 | `nodeY[id] = TOP_PAD + i * ROW_H` | — | Record<string, number> |
| ViewBox尺寸计算 | :457-458 | `viewW = LEFT_PAD + totalCols * COL_W + 18; viewH = TOP_PAD + sorted.length * ROW_H + 28` | — | {w, h} |
| 分支列标签渲染 | :460-464, :37-45 | branchCols.map → {cx, name, color} | SVG text, main→"主线", 颜色branchColor(i) | ColInfo |
| 分支颜色映射 BRANCH_COLORS | :381-388 | 6色: 0=#1890ff, 1=#52c41a, 2=#fa8c16, 3=#722ed1, 4=#eb2f96, 5=#13c2c2 | branchColor(idx) 取模 | Record<number,string> |
| 触发器颜色映射 TRIGGER_COLORS | :393-402 | CHAPTER=#1890ff, MANUAL=#fa8c16, STASH=#8c8c8c, PRE_RESET=#f5222d, ACT=#52c41a, MILESTONE=#722ed1, AUTO=#1890ff, MERGE=#16a34a | nodeColor(triggerType, branchIdx): STASH/PRE_RESET用trigger色, 其余用branch色 | Record<string,string> |
| 节点位置计算 | :467-501 | sorted.map → NodePos{x, y, cx, cy, name, isHead, color, trigger_type, created_at, anchor_chapter, branch_name, world_slice, chapterLabel, triggerShort, sliceLabel, assetLabel, rollbackLabel} | SVG g rect+text | NodePos |
| 节点卡片渲染（rect+accent条+4行文字+回滚标签） | :97-152 | layout.nodePositions | rect(NODE_W×NODE_H rx7 stroke=color), rect accent(4px width), text chapterLabel/triggerShort/name/sliceLabel/assetLabel/rollbackLabel | NodePos |
| HEAD节点标记 | :103-106, :115-117 | `n.isHead` (n.id === head) | class wl-node-g--head, wl-node-card--head, title加粗 | boolean |
| 选中节点标记 | :102-104 | `selectedId === n.id` | class wl-node-g--selected, stroke加粗 | string|null |
| 节点点击选择 | :106 | `@click="selectNode(n.id)"` | selectNode: toggle selectedId | — |
| 边（edges）渲染 | :65-73, :503-516 | edges.map → EdgePos{x1,y1,x2,y2,kind}, from.cx→to.cx, from.y+NODE_H→to.y | SVG line, kind=merge时class wl-edge--merge(绿色加粗) | EdgePos |
| 时间标记线（time markers） | :48-63, :518-535 | sorted.forEach → 按chapter去重, 水平虚线+标签"第N章·时间" | SVG line(dash) + text | TimeMarker |
| 汇流点（confluence positions） | :75-95, :537-561 | confluencePoints.map → ConfluencePos{cx, cy, d(path), label, resolved}, 贝塞尔曲线M...C... | SVG path(dash) + rect(18×18 rx5) + text | ConfluencePos |
| 汇流点Y坐标映射 chapterToY | :542-545 | `ratio = (chapter-1)/(maxChapter-1); y = TOP_PAD + ratio * max(ROW_H, sorted.length*ROW_H-ROW_H)` | — | — |
| maxChapter计算 | :537-541 | Math.max(1, ...nodes anchor_chapter, ...confluencePoints target_chapter) | — | number |
| storylineBranchName查找 | :620-623 | `graphData.branches.find(b => b.storyline_id === storylineId)?.name \|\| 'main'` | — | string |

#### Detail 面板
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 选中节点详情面板 | :157-262 | selectedNode computed | div.wl-detail 230px | CheckpointNode |
| 触发类型标签 | :159-161 | triggerTagType(trigger_type) → info/warning/default/error/success | n-tag round | — |
| 节点名称 | :162-164 | selectedNode.name | n-text strong 13px ellipsis | — |
| 时间+章节+分支 | :166-174 | formatTime(created_at) + anchor_chapter + branch_name | n-text depth3 11px | — |
| world_slice网格 | :175-202 | time_anchor/location/characters.length/items.length/characters前4名+status/items前4名 | div.wl-slice grid | CheckpointNode.world_slice |
| 汇入主线按钮（非main分支） | :206-216 | `handleMergeBranch()` → `worldlineApi.mergeBranch(slug, branch.id, {target_branch_name:'main', name:branch.name+' 汇入主线'})` | n-button primary secondary, loading=actionLoading==='merge' | :672-694 |
| 切换到此切片（checkout） | :218-227 | `handleCheckout()` → `worldlineApi.checkout(slug, selectedId)` | n-button primary ghost, loading==='checkout' | :656-670, CheckoutResult |
| 从此分叉（createBranch） | :229-237 | `showBranchDialog = true` → 打开分支命名Dialog | n-button ghost | :737-758 |
| 回滚到此切片（hardReset） | :239-249 | `handleHardReset()` → dialog.warning确认 → `worldlineApi.hardReset(slug, selectedId)` | n-button error ghost, loading==='hard-reset' | :696-719 |
| 删除存档 | :251-260 | `handleDelete()` → `worldlineApi.deleteCheckpoint(slug, selectedId)` | n-button ghost, loading==='delete' | :721-735 |
| 空详情面板（未选中） | :263-274 | "点击存档查看操作" + 计划汇流列表(前5条) | div.wl-detail--empty | ConfluencePointDTO[] |

#### 分支命名 Dialog
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 分支命名弹窗 | :278-293 | showBranchDialog | n-modal preset=dialog "从此节点分叉新支线" | — |
| 支线名称输入 | :281-283 | newBranchName | n-input | string |
| 绑定故事线选择 | :284-291 | newBranchStorylineId + storylineOptions(storylines.map) | n-select clearable | string\|null |
| 创建分支确认 | :279, :737-758 | `handleCreateBranch()` → `worldlineApi.createBranch(slug, {name, from_checkpoint_id: selectedId, storyline_id?})` | @positive-click | {branch_id} |

#### 数据加载
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 加载世界线图 | :568-578 | `worldlineApi.getGraph(slug)` → graphData | async load() | WorldlineGraph |
| 加载故事线列表 | :331-338 | `workflowApi.getStorylines(slug)` → storylines | async loadStorylines() | StorylineDTO[] |
| 加载汇流点 | :340-346 | `confluenceApi.list(slug)` → confluencePoints | async loadConfluencePoints() | ConfluencePointDTO[] |
| slug变化自动加载 | :580-585 | `watch(() => props.slug, ...)` immediate | load() + loadStorylines() + loadConfluencePoints() | — |

#### 辅助函数
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| formatTime（相对时间） | :589-603 | 刚刚/X分钟前/X小时前/X天前/日期 | — | string |
| triggerLabel（触发类型中文） | :605-611 | CHAPTER→章节, MANUAL→手动, STASH→暂存, PRE_RESET→重置前, ACT→幕, MILESTONE→里程碑, AUTO→自动, MERGE→汇流 | — | string |
| triggerTagType（标签颜色映射） | :625-631 | CHAPTER→info, MANUAL→warning, STASH→default, PRE_RESET→error, ACT→success, MILESTONE→warning, AUTO→info, MERGE→success | — | NaiveTagType |
| confluenceLabel（汇流类型中文） | :613 | getConfluenceLabel: intersect→交叉, absorb→并入, reveal→显影 | — | string |
| storylineName（故事线名称） | :615-618 | storylines.find(id) → name \|\| id.slice(0,6) | — | string |
| compact（文本截断） | :408-411 | value.length > max → slice(0, max-1) + '…' | — | string |

### iOS现状

| iOS文件:行号 | 已实现 | 伪造部分 | 缺失 |
|---|---|---|---|
| WorldlineDAGView.swift:1-175 | Canvas绘制基本框架, 缩放手势, 统计条(snapshots/checkpoints/HEAD) | **全部伪造**：用SnapshotStore.loadCheckpoints获取CheckpointDTO[], 用parentId+hashValue伪造泳道分配(computeLanes/laneAssignment), 没调/worldline/graph | 真实WorldlineGraph数据, 分支列布局, 时间标记线, 汇流点, 6种git交互, 详情面板, 分支命名Dialog |
| WorldlineDAGView.swift:44-49 | `.task { store.loadSnapshots + store.loadCheckpoints }` | 调的是Checkpoints端点(/checkpoints)不是Worldline端点(/worldline/graph) | — |
| WorldlineDAGView.swift:74-148 drawWorldline | Canvas绘制圆形节点+曲线连线 | 节点是简单圆形(非卡片), 泳道用hashValue分配(非branch_name), 无分支列标签, 无时间标记, 无汇流点, 无HEAD高亮(除isHead字段), 无选中详情, 无交互按钮 | 完整布局算法 |
| APIEndpoint.swift:424-431 Worldline枚举 | graph/checkpoints/branches 3个case定义 | — | **无EndpointInfo扩展**（path/method未实现, 详见疑问#1）; 缺8个端点(createCheckpoint/checkout/hardReset/deleteCheckpoint/createBranch/mergeBranch/getBranchByStoryline/updateBranch) |
| EvolutionStore.swift:159-170 loadWorldlineGraph | 调APIEndpoint.Worldline.graph → 存AnyCodable? | 只存原始JSON未解析, 未被WorldlineDAGView使用 | WorldlineGraph模型解析 |
| SnapshotStore.swift:69-95 | loadCheckpoints/createCheckpoint/rollbackCheckpoint | 用的是Checkpoints端点(/checkpoints), 字段不匹配Worldline | — |
| SnapshotModels.swift:159-191 CheckpointDTO | id, storyId, triggerType, triggerReason, parentId, chapterNumber, createdAt, isHead | **字段大量缺失**：无name, branch_name, anchor_chapter, world_slice, rollback_slice | CheckpointNode完整模型 |
| EvolutionNavigatorView.swift:214 ConfluencePoint | 本地struct(id, sourceStorylineId, targetStorylineId, targetChapter, mergeType, resolved) | 从evolutionBundle.plotSpine解析, 非独立API | 缺context_summary, pre_reveal_hint, behavior_guards; 无confluence API端点 |
| StoryEvolutionPanel.swift:744-747 | worldlineTab → `WorldlineDAGView()` | 直接嵌入, 无props传递(slug从EnvironmentObject获取) | 需确认slug/novelId传递方式 |

#### iOS缺失的API端点（WorldlineDAG所需）

| 缺失端点 | 原版路径 | iOS状态 |
|---|---|---|
| Worldline EndpointInfo扩展 | — | **完全缺失**（枚举有3 case但无path/method实现） |
| createCheckpoint | POST /novels/{id}/worldline/checkpoints | 缺失（iOS Checkpoints.create是另一个端点 /checkpoints） |
| checkout | POST /novels/{id}/worldline/checkpoints/{cpId}/checkout | 缺失 |
| hardReset | POST /novels/{id}/worldline/checkpoints/{cpId}/hard-reset | 缺失 |
| deleteCheckpoint | DELETE /novels/{id}/worldline/checkpoints/{cpId} | 缺失 |
| createBranch | POST /novels/{id}/worldline/branches | 缺失 |
| mergeBranch | POST /novels/{id}/worldline/branches/{branchId}/merge | 缺失 |
| Confluence.list | GET /novels/{id}/confluence-points | **完全缺失**（iOS无confluence端点） |

#### iOS缺失的数据模型（WorldlineDAG所需）

| 缺失模型 | 原版定义 | iOS状态 |
|---|---|---|
| WorldlineGraph | {nodes, edges, branches, head_id} | 缺失 |
| CheckpointNode（Worldline版） | {id, name, trigger_type, branch_name, created_at, anchor_chapter, world_slice?, rollback_slice?} | 缺失（现有CheckpointDTO字段不匹配） |
| BranchInfo | {id, name, head_id, is_default, storyline_id} | 缺失 |
| CheckoutResult | {stash_id, restored_chapters, deleted_chapters, message} | 缺失 |
| ConfluencePointDTO | {id, novel_id, source_storyline_id, target_storyline_id, target_chapter, merge_type, context_summary, pre_reveal_hint, behavior_guards, resolved} | 缺失（EvolutionNavigatorView的ConfluencePoint是简化版） |
| WorldlineEdge | {from, to, kind?} | 缺失 |
| WorldSlice | {chapter_number?, time_anchor?, location?, emotional_residue?, characters?, items?, actions_count?, conflicts_count?} | 缺失 |
| RollbackSlice | {to_checkpoint_id, to_chapter, branch_name} | 缺失 |

### 待补内容

| # | 要补项 | 对齐原版文件:行号 | 实现方案 |
|---|---|---|---|
| 1 | Worldline EndpointInfo扩展（path+method for graph/checkpoints/branches + 8个新端点） | worldline.ts:52-115 | 在APIEndpoint.swift添加extension APIEndpoint.Worldline: EndpointInfo, 补全11个case的path和method |
| 2 | Confluence端点 + EndpointInfo | confluence.ts:16-18, workflow.ts:920-923 | 新增APIEndpoint.Confluence枚举(list case) + EndpointInfo扩展, GET /novels/{id}/confluence-points |
| 3 | WorldlineGraph模型 | worldline.ts:38-43 | 新建WorldlineModels.swift, 含WorldlineGraph/CheckpointNode/BranchInfo/CheckoutResult/WorldlineEdge/WorldSlice/RollbackSlice |
| 4 | ConfluencePointDTO模型 | confluence.ts:3-14, workflow.ts:50-61 | 在WorldlineModels.swift或独立文件添加, 字段完整对齐原版 |
| 5 | WorldlineStore（ObservableObject） | WorldlineDAG.vue:297-758 | 新建, 含loadGraph/loadStorylines/loadConfluencePoints/createCheckpoint/checkout/hardReset/deleteCheckpoint/createBranch/mergeBranch, @Published graphData/storylines/confluencePoints/selectedId/loading/saving/actionLoading |
| 6 | 重写WorldlineDAGView布局算法 | WorldlineDAG.vue:356-564 | 用SwiftUI Canvas重绘：分支列(branchOrder)+节点排序(anchor_chapter)+Y坐标+ViewBox+节点卡片(NODE_W×NODE_H)+边(含mergekind)+时间标记线+汇流点贝塞尔曲线 |
| 7 | 节点卡片渲染 | WorldlineDAG.vue:97-152 | Canvas绘制rect+accent条+5行text(chapterLabel/triggerShort/name/sliceLabel/assetLabel)+rollbackLabel, HEAD高亮, 选中高亮 |
| 8 | 节点点击选择(SpatialTapGesture) | WorldlineDAG.vue:106 | Canvas + SpatialTapGesture iOS16+, 点击节点toggle selectedId |
| 9 | 详情面板 | WorldlineDAG.vue:157-262 | SwiftUI VStack: 触发类型Tag+名称+时间+world_slice网格+5个操作按钮(汇入主线/checkout/分叉/hardReset/删除) |
| 10 | 6种git交互 | WorldlineDAG.vue:639-758 | handleManualCheckpoint/handleCheckout/handleMergeBranch/handleHardReset(含确认Dialog)/handleDelete/handleCreateBranch(含分支命名sheet) |
| 11 | 分支命名Sheet | WorldlineDAG.vue:278-293 | SwiftUI .sheet: TextField支线名称 + 故事线选择Picker + 创建按钮 |
| 12 | 空详情面板+汇流列表 | WorldlineDAG.vue:263-274 | 未选中时显示"点击存档查看操作" + 计划汇流前5条 |
| 13 | 辅助函数 | WorldlineDAG.vue:408-631 | formatTime/triggerLabel/triggerTagType/confluenceLabel/storylineName/compact/nodeColor/branchColor |
| 14 | domain/storyline辅助函数 | storyline.ts:100-256 | STORY_PHASE_STAGES/normalizeStoryPhase/getStoryPhaseLabel/getStoryPhaseHint/getStoryPhaseColor/isStoryPhasePast/getConfluenceLabel/getStorylineRoleCompactLabel/getStorylineRoleCssKey/getStorylineRoleTagType/isMainStoryline — **部分可能在已有代码中存在, 需Grep确认** |

---

## 4.3 ActPlanningModal（幕规划弹窗）

### 原版事实表

#### Props / Emits
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| Props: show(boolean), actId(string), actTitle(string) | :170-174 | — | — | — |
| Emit: update:show(boolean), confirmed | :176-179 | — | — | — |

#### UI阶段（4态机）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| UiPhase = 'form' \| 'stream' \| 'edit' \| 'error' | :188-189 | ref<UiPhase>('form') | — | — |
| modalHeadline = `规划章节 — ${actTitle}` | :205 | computed | — | — |

#### Form 阶段（配置）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 提示Alert | :26-28 | 静态文本 | n-alert info | — |
| 章节数输入 | :30-38 | chapterCount ref (min2 max20) | n-input-number 120px | number\|null |
| 取消按钮 | :41 | `close()` → emit update:show false | n-button | — |
| AI生成按钮 | :42 | `startStream()` | n-button primary | — |

#### Stream 阶段（流式生成）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 进度条 | :48-50 | progressPct ref | div.prog-track + div.prog-fill width% | number 0-100 |
| LLM原始输出预览 | :52-59 | llmStreamPreview ref | div.apm-llm-pre pre, 自动滚到底 | string |
| 流式章节卡片预览 | :61-79 | streamPreview ref (逐章push) | n-scrollbar + n-card: title + outline + bible_elements tags | ChapterDraft[] |
| 骨架占位卡 | :81-93 | skeletonCount computed (expected - got) | n-card + n-skeleton | number |
| 取消生成按钮 | :96-98 | `abortStream()` → abortCtrl.abort() | n-button quaternary | — |
| skeletonCount计算 | :207-213 | expected=0时 min(6,max(2,got+2)); expected>0时 min(20,max(0,exp-got)) | — | — |

#### SSE流式连接
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| streamActChapterPlan | :227-287 | `streamActChapterPlan(actId, handlers, {chapterCount})` | GET /api/v1/planning/acts/${actId}/chapters/stream?chapter_count=N | planning.ts:533-615 |
| SSE事件: status | :240-250 | onStatus → statusMessage/progressPct/expectedChapters; phase='streaming'时progressPct=max(,90), 清空llmStreamPreview | — | ActStreamStatusEvent |
| SSE事件: chunk | :251-258 | onChunk → llmStreamPreview += text, 自动滚动 | — | ActStreamChunkEvent{text} |
| SSE事件: chapter | :259-264 | onChapter → streamPreview.push(mapRawToDraft) | — | ActStreamChapterEvent{index,title?,outline?,description?,bible_elements?} |
| SSE事件: done | :265-278 | onDone → chapters = raw.map(mapRawToDraft), 空则→error, 否则progressPct=100, 清streamPreview, uiPhase='edit' | — | ActStreamDoneEvent{success,act_id,chapters[]} |
| SSE事件: error | :279-283 | onError → streamError, uiPhase='error' | — | string |
| mapRawToDraft | :215-225 | title=String(c.title), outline=String(c.outline\|\|c.description), bible_elements=Array.isArray?c.bible_elements:[] | — | ChapterDraft |
| AbortController | :203, :228 | abortCtrl?.abort() 中止SSE | — | — |

#### Edit 阶段（编辑确认）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 成功Alert | :103-105 | 静态 | n-alert success | — |
| 章节编辑列表 | :107-137 | chapters ref | n-scrollbar + n-card: n-input(title) + n-input(textarea outline) + bible_elements tags | ChapterDraft[] |
| 重新生成按钮 | :140 | `backToForm()` | n-button | — |
| 取消按钮 | :141 | `close()` | n-button | — |
| 确认保存按钮 | :142-143 | `confirm()` → `planningApi.confirmActChapters(actId, {chapters})` | n-button primary loading=confirming | :337-349 |

#### Error 阶段
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 错误Alert | :147-148 | streamError | n-alert error | — |
| 关闭按钮 | :149 | `close()` | n-button | — |
| 返回按钮 | :150 | `backToForm()` | n-button primary | — |

#### 生命周期
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| show=false时reset | :326-331 | watch(props.show) → reset() | — | — |
| 组件卸载abort | :333-335 | onUnmounted → abortCtrl?.abort() | — | — |
| reset函数 | :311-324 | abort+重置所有ref | — | — |

#### 数据模型
| 模型 | 字段 | 对齐原版文件:行号 |
|---|---|---|
| ChapterDraft | title: string, outline: string, bible_elements: string[], [key]: unknown | ActPlanningModal.vue:163-168 |
| ActStreamStatusEvent | phase, message, percent?, expected_chapters? | planning.ts:504-509 |
| ActStreamChapterEvent | index, title?, outline?, description?, bible_elements? | planning.ts:511-518 |
| ActStreamChunkEvent | text | planning.ts:520-522 |
| ActStreamDoneEvent | success, act_id, chapters: Record<string,unknown>[] | planning.ts:524-528 |

### iOS现状

| iOS文件:行号 | 已实现 | 缺失 |
|---|---|---|
| Grep `struct ActPlanning` | **零命中, 确认缺失** | 整个组件 |
| APIEndpoint.swift:279-283 Planning枚举 | actChaptersStream(GET /planning/acts/{actId}/chapters/stream) ✓, actChaptersConfirm(POST /planning/acts/{actId}/chapters/confirm) ✓ | 端点已定义, 但actChaptersStream需支持query param ?chapter_count=N |
| SSEClient.swift:1-286 | SSEClient.connect(url:) 返回 AsyncThrowingStream<SSEEvent, Error> ✓, SSEEvent.decodeAsDictionary() ✓ | 需确认connect是否支持query param URL; SSEEvent有event字段(event name)和data字段 |
| SSEEvent.swift:27 | struct SSEEvent { event: String?, data: String, id: String?, retry: Int? } | 可用于解析status/chunk/chapter/done/error事件 |

### 待补内容

| # | 要补项 | 对齐原版文件:行号 | 实现方案 |
|---|---|---|---|
| 1 | ActPlanningModalView.swift（新建） | ActPlanningModal.vue:1-428 | SwiftUI .sheet弹窗, 4阶段状态机(form/stream/edit/error) |
| 2 | ChapterDraft模型 | :163-168 | 新建: title/outline/bible_elements |
| 3 | SSE流式连接（streamActChapterPlan等价） | :227-287, planning.ts:533-615 | 用SSEClient.connect(url:) 连接 /planning/acts/{actId}/chapters/stream?chapter_count=N, 按event name分发status/chunk/chapter/done/error |
| 4 | Form阶段UI | :24-44 | Alert + Stepper(min2 max20) + 取消/生成按钮 |
| 5 | Stream阶段UI | :46-99 | ProgressView进度条 + LLM原始输出ScrollView + 流式章节卡ForEach + 骨架占位 + 取消按钮 |
| 6 | Edit阶段UI | :101-144 | 成功Alert + 章节编辑列表(TextField标题 + TextEditor大纲 + bible_elements标签) + 重新生成/取消/确认按钮 |
| 7 | Error阶段UI | :146-153 | 错误Alert + 关闭/返回按钮 |
| 8 | confirm保存 | :337-349 | apiClient.request(Planning.actChaptersConfirm, body: {chapters: [...]}) |
| 9 | abort/reset生命周期 | :289-335 | Task.cancel()中止SSE, onDisappear取消, show=false时reset |
| 10 | query param支持 | planning.ts:545-549 | actChaptersStream端点URL需追加 ?chapter_count=N (当chapterCount != null && > 0) |

---

## 4.3 NarrativeDashboardPanel（叙事仪表盘）

### 原版事实表

#### Props
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| Props: slug(string), currentChapter?({id,number,title,word_count}\|null) | :279-293 | — | — | Chapter interface |

#### Header
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 标题"叙事简报" | :8 | 静态 | h2.pp-panel-title | — |
| 当前章节Tag | :9-18 | currentChapter.number | n-tag info round | number |
| 副标题"三系统联合感知·实时快照" | :20 | 静态 | p.pp-panel-lead | — |
| 刷新按钮 | :22-29 | `load()` | n-button tiny loading=loading | — |

#### ① 叙事时刻
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 阶段徽章 | :40-43 | phaseMeta.label + phaseMeta.color | span.ndp-phase-badge --opening/development/convergence/finale | phase from storyEvolution.life_cycle.phase |
| 进度统计 | :46-54 | currentChapter.number/maxChapter + progressPct% | div.ndp-moment-stats | maxChapter from chronotope.max_chapter_in_book; progressPct from life_cycle.progress |
| 全局进度条 | :56-66 | progressPct | n-progress line height3 | number |
| 阶段轴（4点+3线） | :68-96 | PHASE_STEPS(opening/development/convergence/finale), isLineDone(step) | div.ndp-phase-dots-row + div.ndp-phase-labels-row | STORY_PHASE_STAGES from domain/storyline |
| 阶段提示文字 | :98 | currentPhaseHint = getStoryPhaseHint(phase) | p.ndp-phase-hint italic | string |

#### ② 活跃线体
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 活跃故事线列表 | :103-135 | activeStorylines computed (filter by chapter range + not completed/cancelled, slice 5) | div.ndp-thread-row per storyline | StorylineDTO[] |
| 故事线角色标签 | :113-118 | storylineRoleTagType(storyline) + storylineRoleLabel(storyline) | n-tag tiny round | role/storyline_type → main/sub/dark |
| 故事线名称 | :119-121 | sl.name \|\| '未命名故事线' | span.ndp-thread-name ellipsis | — |
| 里程碑进度条 | :122-129 | storylineMilestoneProgress(sl) = curr/total*100 | div.ndp-thread-bar width% | milestones.length, current_milestone_index |
| 里程碑标签 | :129 | storylineMilestoneLabel(sl) = `${curr}/${total}` | span.ndp-thread-milestone | — |
| 空状态 | :132-134 | activeStorylines.length === 0 | "本章暂无活跃故事线" | — |

#### ③ 未兑承诺
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 承诺计数Tag | :142-147 | pendingForeshadows.length, hasCriticalPromise | pp-chip danger/warning/success("已清") | ForeshadowEntry[] |
| 紧急承诺列表（前5条） | :148-171 | urgentForeshadows computed (sort by suggested_resolve_chapter, slice 5) | div.ndp-promise-row | ForeshadowEntry[] |
| 紧急度圆点 | :154-157 | foreshadowUrgencyClass(entry) → danger/warning/muted | span.ndp-promise-urgency-dot | importance='critical'→danger; due-ch<=3→danger; <=10→warning; importance='high'→warning; else muted |
| 来源章节 | :158 | `[ch.${entry.chapter}]` | span.ndp-promise-origin | entry.chapter |
| 承诺问题 | :159 | entry.question | span.ndp-promise-question 2行截断 | — |
| 剩余章数 | :161-166 | `Math.max(0, entry.suggested_resolve_chapter - currentChapter.number)` + "章" | span.ndp-promise-due | — |
| 更多提示 | :168-170 | pendingForeshadows.length > 5 | "还有 N 条待兑现" | — |
| 空状态 | :172-174 | urgentForeshadows.length === 0 | "暂无待兑现的叙事承诺" | — |

#### ④ 角色当下
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 角色列表（前5） | :178-211 | mainCharacters computed (sort by role sortOrder, slice 5) | div.ndp-cast-row | CharacterPsycheDTO[] |
| 角色Emoji | :195 | roleEmoji(ch.role) = getCharacterRoleIcon(role) → 主/配/群 | span.ndp-cast-avatar | — |
| 角色名 | :198 | ch.name | span.ndp-cast-name | — |
| 心理状态Tag | :199-203 | characterMentalState(name) → bibleCharMap[name].mental_state (非NORMAL) | pp-chip warning | CharacterDTO.mental_state |
| 核心信念 | :204 | ch.core_belief | p.ndp-cast-belief 1行截断 | CharacterPsycheDTO.core_belief |
| 跳转角色档案 | :181, :192 | goToCharacterPanel() → dispatchEvent(WORKBENCH_OPEN_SETTINGS_PANEL_EVENT) | span.pp-jump "档案→" | — |
| 空状态 | :208-210 | mainCharacters.length === 0 | "尚未配置角色心理画像" | — |

#### ⑤ 引擎记忆（折叠）
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 折叠面板 | :214-246 | n-collapse default-expanded=[] | — | — |
| 全书锚点 | :222-225 | hasMainStoryline → "已装载"/"需配置" | pp-chip success/muted | storyEvolution.plot_spine.storylines.some(isMainStoryline) |
| 角色声线 | :226-229 | psyches.length + "位已配置" | pp-chip brand | CharacterPsycheDTO[] |
| 叙事债务 | :230-233 | pendingForeshadows.length + "条待兑" | pp-chip warning/success | — |
| 紧急伏笔 | :234-242 | urgentCount + "条紧急"/"无紧急" | pp-chip danger/muted | foreshadowUrgencyClass==='danger' count |

#### 数据加载
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| 4路并行加载 | :434-451 | Promise.allSettled([getStoryEvolution, foreshadowApi.list(slug,'pending'), characterPsycheApi.list(slug), bibleApi.getBible(slug)]) | — | — |
| narrativeEngineApi.getStoryEvolution | :439 | GET /novels/{slug}/narrative-engine/story-evolution → storyEvolution | — | StoryEvolutionReadModel |
| foreshadowApi.list(slug, 'pending') | :440 | GET /novels/{slug}/foreshadow-ledger?status=pending → pendingForeshadows | — | ForeshadowEntry[] |
| characterPsycheApi.list(slug) | :441 | GET /novels/{slug}/character-psyches → psyches.characters | — | {characters: CharacterPsycheDTO[]} |
| bibleApi.getBible(slug) | :442 | GET /bible/novels/{slug}/bible → bibleChars.characters | — | BibleDTO.characters |
| slug/currentChapter变化自动加载 | :453 | watch([slug, currentChapter?.id]) → load() | — | — |
| onMounted加载 | :455 | onMounted → load() | — | — |

#### 辅助函数
| 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|---|---|---|---|
| foreshadowUrgencyClass | :410-421 | importance='critical'→danger; due-ch<=3→danger; <=10→warning; importance='high'→warning; else muted | — | 'danger'\|'warning'\|'muted' |
| characterMentalState | :378-384 | bibleCharMap[name].mental_state trim, 非NORMAL返回 | — | string |
| storylineMilestoneProgress | :396-401 | curr/total*100, total=0时返回0 | — | number |
| storylineMilestoneLabel | :403-408 | `${curr}/${total}`, total=0时返回'' | — | string |
| roleEmoji | :423-425 | getCharacterRoleIcon(role) | — | string |

### iOS现状

| iOS文件:行号 | 已实现 | 缺失 |
|---|---|---|
| Grep `struct NarrativeDashboard` | **零命中, 确认缺失** | 整个组件 |
| APIEndpoint.NarrativeEngine.storyEvolution | :1745-1754 | GET /novels/{id}/narrative-engine/story-evolution ✓ | — |
| APIEndpoint.Foreshadow.list | :1187-1218 | GET /novels/{id}/foreshadow-ledger ✓ | 需确认是否支持?status=pending query param |
| APIEndpoint.Checkpoints.characterPsyches | :406, :1270 | GET /novels/{id}/character-psyches ✓ | — |
| APIEndpoint.Bible.get | :123, :869 | GET /bible/novels/{id}/bible ✓ | — |
| APIEndpoint.Workflow.getStorylines | :600, :1655 | GET /novels/{id}/storylines ✓ | — |
| StoryEvolutionReadModel | EvolutionModels.swift:295 | ✓ (novelId, schemaVersion, lifeCycle, plotSpine, chronotope, chaptersDigest, subtextSurface, evolutionSurface) | — |
| StoryPhaseDTO | EvolutionModels.swift:330 | ✓ (phase, progress, chapterRange) | — |
| ChronotopeDTO | EvolutionModels.swift:398 | ✓ (rows, maxChapterInBook, note) | — |
| PlotSpineDTO | EvolutionModels.swift:349 | ✓ (storylines, plotArc) | — |
| StorylineDTO | EvolutionModels.swift:366 | ✓ (id, name, role, status, parentId, estimatedChapterStart, estimatedChapterEnd, storylineType) | **缺 milestones, current_milestone_index, last_active_chapter, progress_summary, chapter_weight** |
| ForeshadowEntry | ForeshadowModels.swift:13 | ✓ (id, chapter, characterId, question, status, consumedAtChapter, suggestedResolveChapter, resolveChapterWindow, importance, isPriorityForChapter, createdAt) | — |
| CharacterPsyche | SnapshotModels.swift:285 | ✓ (name, role, coreBelief, taboo, voiceTag, wound, traumaCount) | **缺 mental_state 字段**（Vue CharacterPsycheDTO无此字段, 用Bible CharacterDTO.mental_state代替） |
| CharacterDTO | BibleModels.swift:14 | ✓ (name, mentalState, coreBelief, ...) | — |
| BibleDTO | BibleModels.swift:182 | ✓ (characters: [CharacterDTO]) | — |
| ForeshadowStore | ForeshadowStore.swift:15 | ✓ entries: [ForeshadowEntry], pendingEntries computed | 需确认list是否支持status filter |
| SnapshotStore.characterPsyches | :19, :122-131 | ✓ [CharacterPsyche] | — |
| EvolutionStore.evolutionBundle | :22 | ✓ StoryEvolutionReadModel? | — |
| domain/storyline函数 | — | **需确认iOS是否已有等价函数** | normalizeStoryPhase/getStoryPhaseLabel/getStoryPhaseHint/getStoryPhaseColor/isStoryPhasePast/STORY_PHASE_STAGES/getStorylineRoleCompactLabel/getStorylineRoleCssKey/getStorylineRoleTagType/isMainStoryline |
| domain/character函数 | — | **需确认iOS是否已有等价函数** | getCharacterRoleIcon/getCharacterRoleSortOrder |

### 待补内容

| # | 要补项 | 对齐原版文件:行号 | 实现方案 |
|---|---|---|---|
| 1 | NarrativeDashboardPanelView.swift（新建） | NarrativeDashboardPanel.vue:1-915 | SwiftUI VStack 5个section |
| 2 | NarrativeDashboardStore（ObservableObject） | :434-451 | 新建, 4路并行加载(getStoryEvolution + foreshadow.list + characterPsyches + bible.get), @Published storyEvolution/pendingForeshadows/psyches/bibleChars/loading |
| 3 | StorylineDTO补字段 | :366-395 | 补 milestones: [StorylineMilestoneDTO]? + currentMilestoneIndex: Int? （原版workflow.ts:31-46有这些字段, iOS遗漏） |
| 4 | StorylineMilestoneDTO模型 | workflow.ts:8-16 | iOS StorylineGraphModels.swift:13已有StorylineMilestoneDTO ✓, 需确认字段对齐(order, title, description?, target_chapter_start, target_chapter_end, prerequisites, triggers) |
| 5 | ①叙事时刻section | :36-100 | 阶段徽章(4色) + 进度统计 + ProgressView + 4点阶段轴 + 提示文字 |
| 6 | ②活跃线体section | :102-135 | ForEach activeStorylines: 角色Tag + 名称 + 里程碑进度条(GeometryReader) + 里程碑标签 |
| 7 | ③未兑承诺section | :137-175 | 计数Tag + ForEach urgentForeshadows: 紧急度圆点(3色) + 来源章节 + 问题 + 剩余章数 |
| 8 | ④角色当下section | :177-211 | ForEach mainCharacters: Emoji + 名称 + 心理状态Tag + 核心信念 |
| 9 | ⑤引擎记忆section（折叠） | :213-246 | DisclosureGroup: 4行(全书锚点/角色声线/叙事债务/紧急伏笔) |
| 10 | foreshadowUrgencyClass函数 | :410-421 | 实现紧急度分级逻辑 |
| 11 | activeStorylines过滤逻辑 | :327-340 | 按 chapter range + status !== completed/cancelled 过滤, slice 5 |
| 12 | domain/storyline + domain/character辅助函数 | storyline.ts:100-256, character.ts:1-125 | **先Grep确认iOS是否已有, 若无则新建StorylineDomain.swift/CharacterDomain.swift** |
| 13 | foreshadowApi.list的status=pending query param | foreshadow.ts | 需确认iOS Foreshadow端点是否支持?status=pending, 若不支持需在请求时追加 |

---

## 疑问清单（上报主理人决策）

| # | 疑问 | 选项 | 我的建议 |
|---|---|---|---|
| 1 | **Worldline EndpointInfo扩展缺失**：APIEndpoint.Worldline枚举(line 424-431)定义了graph/checkpoints/branches 3个case，但全项目无 `extension APIEndpoint.Worldline: APIEndpoint.EndpointInfo`（path/method计算）。而EvolutionStore.swift:164调用了 `apiClient.request(APIEndpoint.Worldline.graph(novelId:))`。这要么是编译错误（项目不可能通过QA），要么是我漏掉了什么。 | A) 扩展确实缺失, 需在批次3补上; B) 扩展在别处定义我未找到, 需主理人指路; C) EvolutionStore.loadWorldlineGraph实际从未被调用(死代码) | A) 假设扩展缺失, 批次3补上Worldline EndpointInfo扩展(含graph/checkpoints/branches + 8个新端点共11个case) |
| 2 | **WorldlineDAGView是否保留现有SnapshotStore调用**：原版WorldlineDAG.vue只调worldline API（不调checkpoints/snapshots端点），但iOS现有WorldlineDAGView调SnapshotStore.loadSnapshots + loadCheckpoints。重写后是否完全去掉SnapshotStore？ | A) 完全去掉, 纯用WorldlineStore; B) 保留SnapshotStore做辅助 | A) 完全去掉SnapshotStore, 改用新建的WorldlineStore, 与原版对齐 |
| 3 | **WorldlineDAGView的slug/novelId来源**：原版用props.slug传入。iOS现有WorldlineDAGView无props, 从`appState.currentNovelId`获取。StoryEvolutionPanel.swift:746直接 `WorldlineDAGView()` 无参数。 | A) 继续从EnvironmentObject AppState获取; B) 改为传参 | A) 继续从appState.currentNovelId获取, 保持与StoryEvolutionPanel嵌入方式兼容 |
| 4 | **Canvas vs SVG映射**：原版用SVG（rect+text+line+path），iOS用Canvas。Canvas中绘制text需用 `context.draw(Text(...), at:)`。节点卡片154×68px含5行文字+accent条+边框，在Canvas中绘制复杂度较高。是否考虑用SwiftUI原生View（ZStack/VStack）替代Canvas绘制节点？ | A) 纯Canvas（与现有代码一致, 但文字布局复杂）; B) Canvas画线/边/汇流曲线 + SwiftUI View叠加画节点卡片; C) 纯SwiftUI View（ZStack定位 + Path画线） | B) Canvas画边/时间线/汇流曲线, SwiftUI View叠加画节点卡片(支持点击/选中/HEAD高亮)。这样节点交互更容易实现 |
| 5 | **节点点击交互**：原版用SVG `@click`。iOS Canvas需用SpatialTapGesture(iOS16+)。如果用方案B(View叠加), 节点点击可直接用Button/onTapGesture。但边的点击不需要。确认方案？ | A) SpatialTapGesture on Canvas; B) View叠加用onTapGesture | B) View叠加, 节点用onTapGesture, 更简单可靠 |
| 6 | **iOS CheckpointDTO vs 原版CheckpointNode字段差异大**：iOS CheckpointDTO有storyId/triggerReason/parentId/isHead, 原版CheckpointNode有name/branch_name/anchor_chapter/world_slice/rollback_slice。完全不同的字段集。是新建CheckpointNode模型还是扩展现有CheckpointDTO？ | A) 新建WorldlineCheckpointNode模型, 不动现有CheckpointDTO; B) 扩展CheckpointDTO加字段 | A) 新建, 不动现有模型, 避免影响其他功能 |
| 7 | **Confluence端点位置**：原版confluenceApi在两个文件中定义（confluence.ts:16-18 和 workflow.ts:920-933），路径相同 `GET /novels/{id}/confluence-points`。iOS完全无此端点。新增到哪个枚举？ | A) 新建APIEndpoint.Confluence枚举; B) 放入APIEndpoint.Worldline枚举; C) 放入APIEndpoint.Workflow枚举 | B) 放入Worldline枚举（因为汇流点是世界线DAG的配套数据, 一并管理） |
| 8 | **ActPlanningModal的SSE URL query param**：原版 `streamActChapterPlan` 在URL后追加 `?chapter_count=N`。iOS SSEClient.connect(url:) 接受完整URL。但APIEndpoint.Planning.actChaptersStream的path不含query param。如何处理？ | A) 在调用处手动拼URL (endpoint.path + "?chapter_count=N"); B) 修改EndpointInfo协议支持query params | A) 在调用处拼接, 不改EndpointInfo协议。用 `APIConfig.baseURL + prefix + path + "?chapter_count=\(count)"` 构建URL |
| 9 | **NarrativeDashboardPanel的StorylineDTO缺字段**：iOS StorylineDTO(EvolutionModels.swift:366)缺milestones/currentMilestoneIndex字段, 但原版workflow.ts:31-46有。补字段会影响PlotSpineDTO解析（storylines数组）。是否安全？ | A) 补字段(decodeIfPresent, 不影响现有解析); B) 新建NarrativeStorylineDTO | A) 补字段, 用decodeIfPresent, 缺失时返回nil, 不影响现有功能 |
| 10 | **domain/storyline和domain/character辅助函数**：NarrativeDashboardPanel大量使用domain/storyline.ts的函数（normalizeStoryPhase/getStoryPhaseLabel等）和domain/character.ts的函数（getCharacterRoleIcon/getCharacterRoleSortOrder）。iOS是否已有等价函数？需Grep确认。如果已有（如StoryEvolutionPanel可能已移植部分），复用；如果缺失，需新建。 | A) 先Grep确认, 复用已有; B) 直接新建独立文件 | A) 实现阶段先Grep, 复用已有函数, 缺失的补到DomainHelper.swift或类似文件 |
| 11 | **foreshadowApi.list的status参数**：原版 `foreshadowApi.list(slug, 'pending')` 传status=pending。iOS APIEndpoint.Foreshadow.list(novelId:) 的path是 `/novels/{id}/foreshadow-ledger`。需确认是否支持?status=pending query param, 以及ForeshadowStore是否已有filter逻辑。 | A) 追加?status=pending到URL; B) 在Store层filter entries by status | A) 追加query param到请求URL, 与原版对齐。若APIClient不支持query param, 则在Store层filter |
| 12 | **NarrativeDashboardPanel跳转角色档案**：原版 `goToCharacterPanel()` 用 `window.dispatchEvent(CustomEvent(WORKBENCH_OPEN_SETTINGS_PANEL_EVENT, {panel:'sandbox'}))`。iOS需等价机制。 | A) 用NotificationCenter.default.post; B) 用@Binding/AppState路由; C) 用NavigationLink | A) 用NotificationCenter, 与项目现有模式(WorkbenchStore.foreshadowTickNotification)一致 |
| 13 | **goToCharacterPanel目标视图**：原版跳到settings panel的sandbox tab。iOS对应的视图是什么？需确认Workbench/Settings中的角色档案面板路由。 | 需主理人指路 | 实现阶段确认路由, 暂用NotificationCenter发通知, 通知名待定 |

---

## 总结

### 工作量评估

| 任务 | 新建文件 | 修改文件 | 新增模型 | 新增端点 | 复杂度 |
|---|---|---|---|---|---|
| 4.2 世界线DAG重写 | WorldlineModels.swift, WorldlineStore.swift | WorldlineDAGView.swift(重写), APIEndpoint.swift(补端点+EndpointInfo) | 8个(WorldlineGraph/CheckpointNode/BranchInfo/CheckoutResult/WorldlineEdge/WorldSlice/RollbackSlice/ConfluencePointDTO) | 9个(Worldline 8新端点 + Confluence 1端点) | **最高** |
| 4.3 ActPlanningModal | ActPlanningModalView.swift, ChapterDraft模型 | APIEndpoint.swift(确认端点已有) | 1个(ChapterDraft) | 0(已有) | 高（SSE流式+4阶段状态机） |
| 4.3 NarrativeDashboardPanel | NarrativeDashboardPanelView.swift, NarrativeDashboardStore.swift | EvolutionModels.swift(StorylineDTO补字段), 可能新建DomainHelper.swift | 0(复用已有) | 0(已有) | 中高（5 section + 4路并行加载） |

### 关键风险
1. WorldlineDAG布局算法是整个阶段4单文件最复杂的部分（原版31KB, Vue computed layout 200+行），Canvas/SwiftUI映射需仔细
2. Worldline EndpointInfo扩展缺失（疑问#1）可能导致编译问题, 需优先解决
3. ActPlanningModal的SSE流式解析需用SSEClient + SSEEvent.decodeAsDictionary()手动字典取值（铁律8）
4. 3个组件共涉及约15+个疑问点, 需主理人确认后方可进入实现阶段
