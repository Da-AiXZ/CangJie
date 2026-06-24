# T04 事实表：阶段3机制1 — 原版做了什么

> 工程师：寇豆码（Kou）
> 任务：T04 DAG节点交互 + 题材包接API（P2）
> 产出性质：只读原版源码事实表，不含任何实现代码
> 落盘时间：重启恢复后重新输出

---

## A. 3.3 DAG节点交互

### A.1 NodeContextMenu（长按菜单）

原版文件：`components/autopilot/NodeContextMenu.vue`（113行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 1 | Teleport到body + fixed定位浮层 | NodeContextMenu.vue:2-8 | 无API调用 | `<Teleport to="body">` + `position: fixed` + `z-index: 9999` | props: x, y, nodeId, nodeEnabled, nodeType |
| 2 | 节点信息头：显示 `icon + display_name + (category_label)` | NodeContextMenu.vue:10-12, 50-58 | dagStore.nodeTypeRegistry[nodeType] 取 NodeMeta | `<n-text strong>` 13px | NodeMeta.icon, NodeMeta.display_name, CATEGORY_LABELS[meta.category] |
| 3 | 菜单分隔线 | NodeContextMenu.vue:13, 19 | - | `<div class="menu-divider">` 1px灰线 | - |
| 4 | "查看详情"菜单项 | NodeContextMenu.vue:16-18 | emit('detail', nodeId) | `@click` → emit detail事件，📋 emoji | nodeId: string |
| 5 | "启禁用"菜单项（动态文本） | NodeContextMenu.vue:20-22 | emit('toggle', nodeId) | nodeEnabled ? '⛔ 禁用此节点' : '✅ 启用此节点'；warning样式条件 | nodeEnabled: boolean |
| 6 | 菜单不超出视口 | NodeContextMenu.vue:61-68 | - | computed menuStyle: `Math.min(x, innerWidth-200)`, `Math.min(y, innerHeight-150)` | - |
| 7 | 菜单项hover高亮 | NodeContextMenu.vue:97-105 | - | `.menu-item:hover` → background变色；`.menu-item-warning:hover` → warning色 | - |
| 8 | 背景模糊(backdrop-filter) | NodeContextMenu.vue:81 | - | `backdrop-filter: blur(8px)` | - |
| 9 | emit事件定义 | NodeContextMenu.vue:40-44 | - | close: [], detail: [nodeId], toggle: [nodeId] | - |

### A.2 NodeDetailPanel（详情Sheet）

原版文件：`components/autopilot/NodeDetailPanel.vue`（465行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 10 | n-modal弹窗 + card预设 | NodeDetailPanel.vue:1-11 | - | `<n-modal preset="card" :title maxWidth=640px width=90vw>` | props: show, nodeId, novelId |
| 11 | 顶部状态条（Dify风格） | NodeDetailPanel.vue:14-22 | - | 背景色随status变化(STATUS_BAR_BG_MAP)；显示icon + statusLabel + 状态Tag | NodeMeta.icon, statusLabel, nodeEnabled, isRunning |
| 12 | 状态Tag：已禁用/运行中 | NodeDetailPanel.vue:17-21 | - | `!nodeEnabled` → "已禁用" default tag；`isRunning` → "运行中" info tag + n-spin | nodeEnabled, isRunning |
| 13 | 基本信息：节点类型 | NodeDetailPanel.vue:28-29 | dagStore.nodeTypeRegistry | `<code>{{ meta.node_type }}</code>` | NodeMeta.node_type |
| 14 | 基本信息：分类 | NodeDetailPanel.vue:30-31 | CATEGORY_LABELS | `<n-tag>` 颜色按category映射(context=default, execution=info, validation=warning, gateway=error) | NodeMeta.category, categoryTagType |
| 15 | 基本信息：描述 | NodeDetailPanel.vue:32-33 | - | `<n-text>` 显示 meta.description 或 '无' | NodeMeta.description |
| 16 | CPMS提示词来源区 | NodeDetailPanel.vue:38-55 | dagStore.loadNodePromptLive(novelId, nodeId) | 显示CPMS Key(code) + 来源Tag(cpms=success/config=info/meta=default/none=warning) | NodePromptLive.cpms_node_key, NodePromptLive.source |
| 17 | 提示词加载中/空状态 | NodeDetailPanel.vue:53-54 | - | promptLoading → "加载中..."；无promptLive → "点击节点查看提示词来源" | promptLoading: boolean |
| 18 | 提示词内容预览（截断500字符） | NodeDetailPanel.vue:58-63 | - | `<pre>` 显示 promptLive.system 前500字符 + "..." | NodePromptLive.system |
| 19 | 端口信息：输入端口 | NodeDetailPanel.vue:68-73 | meta.input_ports | "输入：" + 遍历input_ports显示tiny tag | NodeMeta.input_ports: NodePort[] |
| 20 | 端口信息：输出端口 | NodeDetailPanel.vue:74-79 | meta.output_ports | "输出：" + 遍历output_ports显示tiny info tag | NodeMeta.output_ports: NodePort[] |
| 21 | 全托管写作遥测（条件显示） | NodeDetailPanel.vue:83-97 | autopilotApi.getStatus(novelId) 轮询 | 仅 exec_writer / exec_beat 节点类型显示；显示阶段/子步骤/章节字数/上下文token | WRITING_TELEMETRY_TYPES = Set(['exec_writer', 'exec_beat']) |
| 22 | 写作遥测字段：阶段 | NodeDetailPanel.vue:88 | - | `writingStatus.current_stage || '—'` | AutopilotStatus.current_stage |
| 23 | 写作遥测字段：子步骤 | NodeDetailPanel.vue:89-90 | - | `writingStatus.writing_substep_label || writingStatus.writing_substep || '—'` | AutopilotStatus.writing_substep_label, writing_substep |
| 24 | 写作遥测字段：章节字数 | NodeDetailPanel.vue:91-92 | - | `writingStatus.accumulated_words ?? 0 / writingStatus.chapter_target_words ?? 0` | accumulated_words, chapter_target_words |
| 25 | 写作遥测字段：上下文token | NodeDetailPanel.vue:93-94 | - | `writingStatus.context_tokens ?? 0` | context_tokens |
| 26 | 写作遥测轮询逻辑 | NodeDetailPanel.vue:191-227 | usePolling(fetchWritingTelemetry, pollMs) | watch [show, novelId, meta.node_type]；open+有telemetry时start({immediate:true})；否则stop() | runtimePerformance.autopilotPanel.nodeWritingTelemetryPollMs = 2500ms |
| 27 | 写作遥测错误处理 | NodeDetailPanel.vue:196-208 | - | 404 → "该书暂无托管状态"；其他HTTP错误 → "状态 {status}"；网络错误 → e.message | isAutopilotNotFoundError, getAutopilotHttpStatus |
| 28 | 写作遥测加载中/空状态 | NodeDetailPanel.vue:85-86, 96 | - | writingPollError → 显示错误文本；无writingStatus → "加载中…" | writingPollError: string |
| 29 | 默认下游连线 | NodeDetailPanel.vue:100-113 | meta.default_edges | 遍历default_edges显示info tag，标签通过getNodeLabel(target)解析 | NodeMeta.default_edges: string[] |
| 30 | getNodeLabel辅助函数 | NodeDetailPanel.vue:333-336 | dagStore.nodeTypeRegistry[type] | 返回 meta.display_name || type | - |
| 31 | 空状态：未找到节点信息 | NodeDetailPanel.vue:116-118 | - | `<div class="detail-empty">` "未找到节点信息" | - |
| 32 | 底部启用/禁用Switch | NodeDetailPanel.vue:123-130 | dagStore.toggleNode(novelId, nodeId) | `v-if="nodeId && meta?.can_disable"` → n-switch :value=nodeEnabled @update=handleToggleNode | NodeMeta.can_disable |
| 33 | 启禁用成功提示 | NodeDetailPanel.vue:340-344 | - | message.success(enabled ? '节点已启用' : '节点已禁用') | - |
| 34 | 关闭按钮 | NodeDetailPanel.vue:132 | emit('update:show', false) | `<n-button size="small">` 关闭 | - |
| 35 | 节点切换时加载promptLive | NodeDetailPanel.vue:308-319 | dagStore.loadNodePromptLive | watch nodeId：清空→加载 promptLive | - |
| 36 | 面板打开时加载promptLive | NodeDetailPanel.vue:322-331 | dagStore.loadNodePromptLive | watch show：打开且有nodeId → 加载 promptLive | - |
| 37 | 面板标题 | NodeDetailPanel.vue:243-246 | - | `meta.display_name || nodeId` | - |
| 38 | status计算（disabled优先） | NodeDetailPanel.vue:234-237 | dagStore.nodeStates | `!nodeEnabled → 'disabled'`；否则 runState?.status || 'idle' | NodeRunState.status |
| 39 | 状态条背景色映射（9种状态） | NodeDetailPanel.vue:250-262 | - | STATUS_BAR_BG_MAP: idle/pending/running/success/warning/error/bypassed/disabled/completed | - |
| 40 | 状态标签映射（9种状态+emoji） | NodeDetailPanel.vue:264-276 | - | STATUS_LABEL_MAP: '⏹ 空闲'/'⏳ 等待中'/'▶️ 运行中'/'成功'/'警告'/'错误'/'⏭ 已旁路'/'已禁用'/'已完成' | - |
| 41 | 来源标签映射 | NodeDetailPanel.vue:297-305 | - | cpms→'CPMS 广场', config→'节点配置', meta→'节点默认', none→'无' | - |

### A.3 NodeEditorDrawer（配置抽屉）

原版文件：`components/autopilot/NodeEditorDrawer.vue`（296行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 42 | n-drawer右侧抽屉(width=480) | NodeEditorDrawer.vue:3-8 | - | `<n-drawer :show=isOpen :width=480 placement="right">` | isOpen: ref(false) |
| 43 | 提示词关联信息区（CPMS） | NodeEditorDrawer.vue:11-25 | plazaBridge.getCpmsKey(node.type) | `v-if="cpmsNodeKey"`：🏪图标 + "关联提示词" + cpms_key(code) + "在广场编辑"按钮 | cpmsNodeKey: string \| null |
| 44 | "在广场编辑"按钮 | NodeEditorDrawer.vue:18-24 | plazaBridge.openPromptInPlaza(cpmsNodeKey) | `<n-button type="primary" secondary>` → handleOpenPlaza | - |
| 45 | 广场编辑提示文案 | NodeEditorDrawer.vue:22-24 | - | "点击「在广场编辑」打开提示词广场，支持编辑、版本管理、回滚。" | - |
| 46 | 温度参数（slider + input） | NodeEditorDrawer.vue:29-45 | - | n-slider(min=0, max=2, step=0.1) + n-input-number(min=0, max=2, step=0.1, width=80px) | localConfig.temperature: number (默认0.7) |
| 47 | 最大Tokens参数 | NodeEditorDrawer.vue:47-57 | - | n-input-number(min=100, step=100, clearable, placeholder="默认", width=160px) | localConfig.maxTokens: number \| null (默认null) |
| 48 | 超时时间参数 | NodeEditorDrawer.vue:59-69 | - | n-input-number(min=10, max=600, step=10) + "秒"标签 | localConfig.timeoutSeconds: number (默认60) |
| 49 | 最大重试参数 | NodeEditorDrawer.vue:71-79 | - | n-input-number(min=0, max=5, width=160px) | localConfig.maxRetries: number (默认1) |
| 50 | 模型覆盖参数 | NodeEditorDrawer.vue:81-89 | - | n-input(placeholder="留空使用默认模型", clearable, width=240px) | localConfig.modelOverride: string (默认'') |
| 51 | 保存参数按钮（条件禁用） | NodeEditorDrawer.vue:97-104 | dagStore.updateNodeConfig(dagId, nodeId, config) | `:disabled="!hasConfigChanges"` → handleSaveConfig | hasConfigChanges: computed |
| 52 | hasConfigChanges计算 | NodeEditorDrawer.vue:145-153 | - | 任一参数偏离默认值 → true | - |
| 53 | 保存时构造config对象 | NodeEditorDrawer.vue:187-198 | - | 必传: temperature, timeout_seconds, max_retries；条件传: max_tokens(非null), model_override(非空) | config: Record<string, unknown> |
| 54 | 保存成功/失败提示 | NodeEditorDrawer.vue:200-203 | - | message.success('节点参数保存成功') / message.error('节点参数保存失败') | - |
| 55 | 打开抽屉(external open) | NodeEditorDrawer.vue:157-168 | defineExpose({ open }) | open(nodeId, dagId)：查node → 设editingNodeId → getCpmsKey → loadLocalConfig → isOpen=true | - |
| 56 | loadLocalConfig初始化 | NodeEditorDrawer.vue:172-179 | - | 从node.config读取: temperature(??0.7), max_tokens(??null), timeout_seconds(??60), max_retries(??1), model_override(??'') | NodeConfig |
| 57 | 关闭按钮 | NodeEditorDrawer.vue:95 | handleClose(false) | `<n-button>关闭` | - |
| 58 | 抽屉标题 | NodeEditorDrawer.vue:138-143 | - | cpmsNodeKey ? `节点配置 — ${cpmsNodeKey}` : '节点配置' | - |
| 59 | handleOpenPlaza逻辑 | NodeEditorDrawer.vue:206-212 | plazaBridge.openPromptInPlaza | 有cpmsNodeKey → openPromptInPlaza(key)；无 → openPromptInPlaza('', false) | - |

### A.4 DAG节点API端点（从dagStore.ts + dag.ts提取）

原版文件：`stores/dagStore.ts`（355行）+ `api/dag.ts`（88行）

| 方法 | HTTP方法 | 端点路径 | 请求体 | 响应 | 对齐原版行号 |
|------|---------|---------|--------|------|-------------|
| loadNodePromptLive | GET | `/dag/{novel_id}/nodes/{node_id}/prompt-live` | 无 | NodePromptLive | dagStore.ts:312-320, dag.ts:62-63 |
| toggleNode | POST | `/dag/{novel_id}/nodes/{node_id}/toggle` | `{}` | DAGDefinition | dagStore.ts:201-208, dag.ts:32-33 |
| updateNodeConfig | **不走API**（内存更新） | — | — | — | dagStore.ts:290-305（注释：★ 暂时直接更新内存中的 DAG 定义（不走数据库）） |
| (API层定义但Store未调用) updateNodeConfig | PUT | `/dag/{novel_id}/nodes/{node_id}` | config: Record<string, unknown> | DAGDefinition | dag.ts:82-83（API层有定义，但dagStore.ts未调用） |
| getDAG | GET | `/dag/{novel_id}` | 无 | DAGDefinition | dagStore.ts:168-179, dag.ts:24-25 |
| getStatus | GET | `/dag/{novel_id}/status` | 无 | DAGStatusResponse | dag.ts:36-37 |
| listNodeTypes | GET | `/dag/registry/types` | 无 | `{ types: Record<string, NodeMeta> }` | dagStore.ts:181-199, dag.ts:42-43 |
| getRegistryLinkage | GET | `/dag/registry/linkage` | 无 | DagRegistryLinkageResponse | dagStore.ts:149-161, dag.ts:50-51 |
| getNode | GET | `/dag/{novel_id}/nodes/{node_id}` | 无 | Record<string, unknown> | dag.ts:28-29 |
| getRenderedPrompt | GET | `/dag/{novel_id}/nodes/{node_id}/prompt` | 无 | `{ node_id, template, variables, rendered }` | dag.ts:66-67 |
| healthCheck | GET | `/dag/health/dag` | 无 | Record<string, unknown> | dag.ts:56-57 |
| runDAG | POST | `/dag/{novel_id}/run` | `{}` | `{ status, novel_id }` | dag.ts:72-73 |
| stopDAG | POST | `/dag/{novel_id}/stop` | `{}` | `{ status, novel_id }` | dag.ts:76-77 |
| eventsUrl(SSE) | GET | `/dag/events?novel_id=...` | 无 | SSE流 | dag.ts:86 |

#### 补充：dagStore.ts 其他关键方法

| 方法 | 原版行号 | 功能 | 调用API |
|------|---------|------|---------|
| hydrateDagForNovel | dagStore.ts:128-166 | 并行加载 DAG + 注册表 + linkage（Promise.allSettled） | getDAG + listNodeTypes + getRegistryLinkage |
| loadDAG | dagStore.ts:168-179 | 加载DAG定义 | getDAG |
| loadNodeTypeRegistry | dagStore.ts:181-199 | 加载节点类型注册表+linkage | listNodeTypes + getRegistryLinkage |
| handleSSEEvent | dagStore.ts:221-279 | SSE事件分发：node_status_change/node_output/edge_data_flow | 无（更新内存状态） |
| computeRegistryGapsLocal | dagStore.ts:115-125 | 本地推断注册表缺口 | 无 |
| selectNode | dagStore.ts:281-283 | 设置selectedNodeId | 无 |
| resetNodeStates | dagStore.ts:307-310 | 清空nodeStates + edgeFlows | 无 |

#### 补充：NodePromptLive 数据模型（types/dag.ts:165-173）

```typescript
interface NodePromptLive {
  node_id: string
  node_type: string
  cpms_node_key: string
  system: string           // 提示词正文
  user_template: string
  source: 'cpms' | 'config' | 'meta' | 'none'
  variables: string[]
}
```

#### 补充：NodeMeta 数据模型（types/dag.ts:32-50）

```typescript
interface NodeMeta {
  node_type: string
  display_name: string
  category: 'context' | 'execution' | 'validation' | 'gateway'
  icon: string
  color: string
  input_ports: NodePort[]
  output_ports: NodePort[]
  prompt_template: string
  prompt_variables: string[]
  is_configurable: boolean
  can_disable: boolean
  default_timeout_seconds: number
  default_max_retries: number
  cpms_node_key: string
  description: string
  default_edges: string[]
}
```

#### 补充：NodePort 数据模型（types/dag.ts:22-28）

```typescript
interface NodePort {
  name: string
  data_type: 'text' | 'json' | 'score' | 'boolean' | 'list' | 'prompt'
  required: boolean
  default?: unknown
  description?: string
}
```

#### 补充：NodeConfig 数据模型（types/dag.ts:54-63）

```typescript
interface NodeConfig {
  prompt_template?: string | null
  prompt_variables?: Record<string, string>
  thresholds?: Record<string, number>
  model_override?: string | null
  max_retries?: number
  timeout_seconds?: number
  temperature?: number
  max_tokens?: number | null
}
```

#### 补充：CATEGORY_LABELS 映射（types/dag.ts:226-231）

```typescript
context: '上下文注入'
execution: '执行与生成'
validation: '校验与监控'
gateway: '网关与熔断'
```

---

## B. 3.5 题材包接API

### B.1 数据模型 + API

原版文件：`domain/taxonomy/types.ts`（49行）+ `domain/taxonomy/cnMarket.ts`（55行）+ `domain/taxonomy/builtin_cn_v1.bundle.json`（~0.3MB, 14大类）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 60 | TaxonomyBundle结构定义 | types.ts:39-41 | - | - | schema_kind, schema_version(number), id, locale, domain, title?, description?, facet_keys_semantics?, roots: TaxonomyNode[] |
| 61 | TaxonomyBundleMeta结构 | types.ts:28-37 | - | - | schema_kind, schema_version, id, locale, domain, title?, description?, facet_keys_semantics? |
| 62 | TaxonomyNode结构 | types.ts:21-26 | - | - | id, labels: LocalizedLabels, facets?: TaxonomyFacets, children?: TaxonomyNode[] |
| 63 | LocalizedLabels结构 | types.ts:6-8 | - | - | `[locale: string]: string` |
| 64 | TaxonomyFacets结构 | types.ts:17-19 | - | - | `Record<string, TaxonomyFacetValue>` 其中 TaxonomyFacetValue = string \| TaxonomyWritingProfile \| Record<string, unknown> \| undefined |
| 65 | TaxonomyWritingProfile结构 | types.ts:10-15 | - | - | story_structure?, pacing_control?, writing_style?, special_requirements? (全部string?) |
| 66 | CN_LOCALE常量 | types.ts:43 | - | - | `'zh-CN'` |
| 67 | pickLocaleLabel函数 | types.ts:45-48 | - | - | 优先取 labels[locale] → labels['zh-CN'] → labels['zh'] → 第一个值 → node.id |
| 68 | BUILTIN_CN_MARKET_V1导入 | cnMarket.ts:1-6 | `import raw from './builtin_cn_v1.bundle.json'` | 直接import JSON，不走API | `raw as TaxonomyBundle` |
| 69 | marketMajorThemeGenre函数 | cnMarket.ts:8-10 | - | 返回 `${pickLocaleLabel(root)} / ${pickLocaleLabel(leaf)}` | - |
| 70 | facetTextForSelection（内部） | cnMarket.ts:12-15 | - | 优先取leaf.facets[key]，回退root.facets[key] | - |
| 71 | worldToneForSelection函数 | cnMarket.ts:17-20 | facetTextForSelection(root, leaf, 'world_tone') | 返回世界观基调正文 | - |
| 72 | writingProfileFacet（内部） | cnMarket.ts:22-28 | - | 合并 root.facets.writing_profile + leaf.facets.writing_profile（leaf覆盖root） | TaxonomyWritingProfile |
| 73 | writingProfileForSelection函数 | cnMarket.ts:30-32 | writingProfileFacet(root, leaf) | 返回合并后的写作原则 | - |
| 74 | themeAgentKeyForSelection函数 | cnMarket.ts:34-36 | facetTextForSelection(root, undefined, 'theme_agent_key') | 返回体裁键 | - |
| 75 | FlatSearchHit接口 | cnMarket.ts:38-41 | - | `{ root: TaxonomyNode, scoreAid: string }` | - |
| 76 | flattenRootsForSearch函数 | cnMarket.ts:43-54 | - | 遍历roots，合成scoreAid = `${major} ${search_blob} ${market_track} ${writing_profile各字段} ${childLabels}`.toLowerCase() | FlatSearchHit[] |
| 77 | bundle.json facet_keys_semantics | bundle.json:9-15 | - | 定义5个facet key语义: market_track, world_tone, writing_profile, theme_agent_key, search_blob | - |
| 78 | bundle.json 14个大类 | bundle.json:16-1256+ | - | roots数组包含14个根节点 | xuanhuan/qihuan/wuxia/xianxia/dushi/lishi/youxi/wangyou/kehuan/moshi/tiyu/tianyuan_zhong/xuanyi/lingyi |
| 79 | 每个大类的children | bundle.json各root | - | 每个root有3-7个children，每个child有自己的facets(world_tone + writing_profile四字段) | - |

#### 补充：bundle.json 根节点清单（14大类）

| 序号 | id | zh-CN标签 | children数量 |
|------|-----|----------|-------------|
| 1 | xuanhuan | 玄幻 | 4 (东方玄幻/异世大陆/高武世界/玄幻脑洞) |
| 2 | qihuan | 奇幻 | 5 (历史神话/另类奇幻/现代魔法/剑与魔法/蒸汽朋克) |
| 3 | wuxia | 武侠 | 4 (传统武侠/高武武侠/国术/天源) |
| 4 | xianxia | 仙侠 | 4 (古典仙侠/修真/脑洞/天源) |
| 5 | dushi | 都市 | 6 (高武/天源/脑洞/生活/异能/校园) |
| 6 | lishi | 历史 | 4 (脑洞/古代/架空/争霸) |
| 7 | youxi | 游戏 | 5 (竞技/异界/系统/主播/模拟器) |
| 8 | wangyou | 网游 | 5 (VR/竞技/异界/天源/玩家) |
| 9 | kehuan | 科幻 | 5 (星际/异能/末世/赛博/时空) |
| 10 | moshi | 末日 | 5 (求生/天源/囤货/废土/重建) |
| 11 | tiyu | 体育 | 5 (篮球/足球/格斗/田径/重生) |
| 12 | tianyuan_zhong | 田园种田 | 5 (古代/农家/穿越/基建/养老) |
| 13 | xuanyi | 悬疑 | 5 (侦探/惊悚/罪案/民间/脑洞) |
| 14 | lingyi | 灵异 | 3+ (民间/风水/鬼怪...) |

### B.2 MarketTaxonomyPicker（题材选择器）

原版文件：`components/taxonomy/MarketTaxonomyPicker.vue`（495行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 80 | 搜索框 | MarketTaxonomyPicker.vue:3-16 | - | n-input clearable round, placeholder="搜索大类、主题关键词…"，prefix搜索图标 | searchQuery: ref('') |
| 81 | 搜索过滤逻辑 | MarketTaxonomyPicker.vue:183-193 | flattenRootsForSearch(roots) | norm(query) → 遍历searchTable匹配scoreAid.includes(q) → 返回匹配roots | filteredMajors: computed |
| 82 | 搜索结果计数 | MarketTaxonomyPicker.vue:20 | - | `已过滤 {{ filteredMajors.length }} / {{ rootsCount }}` | rootsCount: computed |
| 83 | ① 大类选择按钮组 | MarketTaxonomyPicker.vue:18-37 | pickMajor(maj) | n-button round strong，选中=primary，未选中=default secondary | pickedMajorId: ref<string\|null> |
| 84 | pickMajor逻辑 | MarketTaxonomyPicker.vue:291-299 | - | 设pickedMajorId → 自动选第一个child → 生成genre/worldPreset/writingProfile | - |
| 85 | ② 主题选择按钮组 | MarketTaxonomyPicker.vue:39-61 | pickTheme(activeMajor, ch) | n-button text tiny，选中=primary | pickedThemeId: ref<string\|null> |
| 86 | pickTheme逻辑 | MarketTaxonomyPicker.vue:301-306 | - | 设pickedThemeId → 生成genre/worldPreset/writingProfile | - |
| 87 | 空主题提示 | MarketTaxonomyPicker.vue:58-60 | - | "该大类暂无细分节点" | - |
| 88 | 分类信息条（4列） | MarketTaxonomyPicker.vue:63-80 | - | 市场大类/细分主题/赛道属性/引擎大类 | activeMajorLabel, activeThemeLabel, activeMarketTrack, themeAgentKeyDisplay |
| 89 | 赛道属性 | MarketTaxonomyPicker.vue:72-75 | activeMajor.facets.market_track | `<strong>{{ activeMarketTrack || '未配置' }}</strong>` | TaxonomyFacets.market_track |
| 90 | 引擎大类显示 | MarketTaxonomyPicker.vue:76-79, 316-321 | themeAgentKeyForSelection(r) | `theme:${k}` 或空 | - |
| 91 | ③ 世界观基调编辑器 | MarketTaxonomyPicker.vue:82-93 | worldToneForSelection(root, leaf) | n-input textarea autosize(minRows=3, maxRows=12) | worldPreset: defineModel('worldPreset') |
| 92 | ④ 写作原则四卡片 | MarketTaxonomyPicker.vue:95-122 | writingProfileForSelection(root, leaf) | 2列网格，每卡片：序号+标题+范围+说明+textarea(minRows=8, maxRows=18) | writingPrincipleCards: computed |
| 93 | 写作原则卡片1：剧情结构 | MarketTaxonomyPicker.vue:222-229 | - | key='story_structure', index='01', scope=`大类/主题 的开篇、发展、高潮、结尾` | storyStructure: defineModel |
| 94 | 写作原则卡片2：节奏把控 | MarketTaxonomyPicker.vue:230-237 | - | key='pacing_control', index='02', scope=`赛道 的小/中/大爽点排布` | pacingControl: defineModel |
| 95 | 写作原则卡片3：写作风格 | MarketTaxonomyPicker.vue:238-245 | - | key='writing_style', index='03', scope=`主题 的叙事、环境描写、人物对话` | writingStyle: defineModel |
| 96 | 写作原则卡片4：特殊要求 | MarketTaxonomyPicker.vue:246-253 | - | key='special_requirements', index='04', scope=`大类/主题 的专属创作细则` | specialRequirements: defineModel |
| 97 | applyWritingProfile | MarketTaxonomyPicker.vue:308-314 | writingProfileForSelection(root, leaf) | 将4个字段trim后赋值给对应model | - |
| 98 | syncFromGenreString反向同步 | MarketTaxonomyPicker.vue:264-279 | - | genre含'/'时：拆分majorLabel/themeLabel → 匹配roots → 设pickedMajorId/pickedThemeId | - |
| 99 | genre变化触发反向同步 | MarketTaxonomyPicker.vue:281-289 | - | watch genre：无pickedMajorId且genre含'/' → syncFromGenreString | - |
| 100 | 搜索结果变化时重置选择 | MarketTaxonomyPicker.vue:256-262 | - | watch filteredMajors：当前pickedMajorId不在结果中 → 选第一个或null | - |
| 101 | 搜索无结果提示 | MarketTaxonomyPicker.vue:124-126 | - | "没有找到匹配的分类，换一个关键词试试" | - |
| 102 | disabled状态（busy半透明） | MarketTaxonomyPicker.vue:2, 331-333 | - | `class="mtp--busy"` opacity=0.72 | props.disabled: boolean |
| 103 | 6个defineModel双向绑定 | MarketTaxonomyPicker.vue:164-169 | - | genre, worldPreset, storyStructure, pacingControl, writingStyle, specialRequirements | 全部string, default='' |
| 104 | locale prop | MarketTaxonomyPicker.vue:153-162 | - | 默认'zh-CN'，传入pickLocaleLabel | props.locale: string |
| 105 | 响应式布局（窄屏1列） | MarketTaxonomyPicker.vue:479-487 | - | @media max-width:900px → classify-strip和writing-grid变1列 | - |

---

## C. iOS现有基础核对

### C.1 DAGStore.swift 现有方法 + T04需新增

原版文件：`ViewModels/DAGStore.swift`（147行）

| 方法/属性 | 现状 | T04需要做的 |
|----------|------|------------|
| loadDAG(novelId:) | ✅ 已有 (DAGStore.swift:38-49) → GET /dag/{novel_id} | 保留 |
| loadDAGStatus(novelId:) | ✅ 已有 (DAGStore.swift:53-59) → GET /dag/{novel_id}/status | 保留 |
| toggleNode(novelId:nodeId:) | ✅ 已有 (DAGStore.swift:67-76) → POST /dag/{novel_id}/nodes/{node_id}/toggle | 保留 |
| startDAGEvents(novelId:) | ✅ 已有 (DAGStore.swift:82-97) → SSE | 保留 |
| stopDAGEvents(novelId:) | ✅ 已有 (DAGStore.swift:101-104) | 保留 |
| handleDAGEvent(_:) | ✅ 已有 (DAGStore.swift:107-129) | 保留 |
| nodes (computed) | ✅ 已有 (DAGStore.swift:134-136) | 保留 |
| edges (computed) | ✅ 已有 (DAGStore.swift:139-141) | 保留 |
| nodeStates (computed) | ✅ 已有 (DAGStore.swift:144-146) | 保留 |
| **loadNodePromptLive** | ❌ 缺失 | **需新增**：GET /dag/{novel_id}/nodes/{node_id}/prompt-live → 返回NodePromptLive |
| **updateNodeConfig** | ❌ 缺失 | **需新增**：原版dagStore.ts:290-305只做内存更新（不走API），iOS需对齐此行为 |
| **loadNodeTypeRegistry** | ❌ 缺失 | **需新增**：GET /dag/registry/types → 返回 { types: Record<string, NodeMeta> } |
| **hydrateDagForNovel** | ❌ 缺失 | **需新增**：并行加载DAG+注册表+linkage（Promise.allSettled等价） |
| **nodeTypeRegistry** | ❌ 缺失 | **需新增**：@Published var nodeTypeRegistry: [String: NodeMeta] |
| **registryLinkage** | ❌ 缺失 | **需新增**：@Published var registryLinkage: DagRegistryLinkageResponse? |
| **selectedNodeId** | ❌ 缺失 | **需新增**：@Published var selectedNodeId: String? |
| **nodePromptLive cache** | ❌ 缺失 | **需新增**：@Published var nodePromptLive: [String: NodePromptLive] |

### C.2 TaxonomyModels.swift 现有 + 是否够用

原版文件：`Models/TaxonomyModels.swift`（111行）

| 模型 | 现状 | 是否够用 | 问题 |
|------|------|---------|------|
| TaxonomyBundle | ✅ 已有 (TaxonomyModels.swift:14-45) | ⚠️ 基本够用 | schemaVersion类型为String，但原版types.ts:31和bundle.json:3均为number(整数1)。**疑似bug**，需确认 |
| TaxonomyNode | ✅ 已有 (TaxonomyModels.swift:48-61) | ✅ 够用 | - |
| TaxonomyFacets | ✅ 已有 (TaxonomyModels.swift:64-87) | ✅ 够用 | - |
| TaxonomyWritingProfile | ✅ 已有 (TaxonomyModels.swift:90-110) | ✅ 够用 | - |
| NodePromptLive | ❌ 缺失 | **需新增** | 对齐types/dag.ts:165-173 |
| NodeMeta | ❌ 缺失 | **需新增** | 对齐types/dag.ts:32-50 |
| NodePort | ❌ 缺失 | **需新增** | 对齐types/dag.ts:22-28 |
| NodeConfig | ❌ 缺失（iOS NodeDefinition已有config但可能不完整）| **需确认** | 需检查iOS现有NodeDefinition模型 |
| DagRegistryLinkageResponse | ❌ 缺失 | **需新增** | 对齐types/dag.ts:209-215 |

### C.3 APIEndpoint.swift 现有端点

原版文件：`Networking/APIEndpoint.swift`（1628行）

| 端点 | 现状 | 是否够用 |
|------|------|---------|
| DAG.get(novelId) | ✅ 已有 (APIEndpoint.swift:156) → GET /dag/{novel_id} | ✅ |
| DAG.toggleNode(novelId, nodeId) | ✅ 已有 (APIEndpoint.swift:160) → POST /dag/{novel_id}/nodes/{node_id}/toggle | ✅ |
| DAG.nodePromptLive(novelId, nodeId) | ✅ 已有 (APIEndpoint.swift:164) → GET /dag/{novel_id}/nodes/{node_id}/prompt-live | ✅（已定义但DAGStore未使用） |
| DAG.updateNode(novelId, nodeId) | ✅ 已有 (APIEndpoint.swift:168) → PUT /dag/{novel_id}/nodes/{node_id} | ✅（已定义，但原版Store不走API） |
| DAG.status(novelId) | ✅ 已有 (APIEndpoint.swift:162) → GET /dag/{novel_id}/status | ✅ |
| DAG.registryTypes | ✅ 已有 (APIEndpoint.swift:150) → GET /dag/registry/types | ✅ |
| DAG.registryLinkage | ✅ 已有 (APIEndpoint.swift:152) → GET /dag/registry/linkage | ✅ |
| DAG.node(novelId, nodeId) | ✅ 已有 (APIEndpoint.swift:158) → GET /dag/{novel_id}/nodes/{node_id} | ✅ |
| DAG.nodePrompt(novelId, nodeId) | ✅ 已有 (APIEndpoint.swift:166) → GET /dag/{novel_id}/nodes/{node_id}/prompt | ✅ |
| DAG.events(novelId) | ✅ 已有 (APIEndpoint.swift:154) → GET /dag/events | ✅ |
| Taxonomy.builtinBundle | ✅ 已有 (APIEndpoint.swift:544) → GET /taxonomy/bundles/builtin_cn_v1 | ✅（但原版cnMarket.ts是本地import JSON，不走API） |
| Taxonomy.openingProfiles | ✅ 已有 (APIEndpoint.swift:546) → GET /taxonomy/opening-profiles/cn_v1 | ✅ |
| Autopilot.status(novelId) | ✅ 已有 (APIEndpoint.swift:98) → GET /autopilot/{novel_id}/status | ✅（NodeDetailPanel写作遥测用） |

**结论：APIEndpoint层面全部就绪，无需新增端点。**

### C.4 CreateNovelSheet.swift 现有结构 + 替换范围

原版文件：`Views/Home/CreateNovelSheet.swift`（207行）

| 项目 | 现状 | T04替换范围 |
|------|------|------------|
| genre选择 | ❌ 硬编码 Picker: `["玄幻", "都市", "科幻", "历史", "悬疑", "言情", "武侠", "游戏"]` (CreateNovelSheet.swift:49, 75-78) | 替换为MarketTaxonomyPicker的大类+主题选择 |
| worldPreset选择 | ❌ 硬编码 Picker: `["东方玄幻", "现代都市", "未来星际", "古代宫廷", "末日废土", "异世界"]` (CreateNovelSheet.swift:50, 80-83) | 替换为MarketTaxonomyPicker的世界观基调编辑器 |
| storyStructure | ⚠️ 硬编码TextField placeholder (CreateNovelSheet.swift:85) | 替换为MarketTaxonomyPicker的写作原则卡片1 |
| pacingControl | ⚠️ 硬编码TextField placeholder (CreateNovelSheet.swift:86) | 替换为MarketTaxonomyPicker的写作原则卡片2 |
| writingStyle | ⚠️ 硬编码TextField placeholder (CreateNovelSheet.swift:87) | 替换为MarketTaxonomyPicker的写作原则卡片3 |
| specialRequirements | ⚠️ 硬编码TextField placeholder (CreateNovelSheet.swift:88) | 替换为MarketTaxonomyPicker的写作原则卡片4 |
| title/premise/篇幅/章数 | ✅ 保留 | 不变 |
| CreateNovelRequest | ✅ 已有完整字段 (CreateNovelSheet.swift:181-195) | 不变 |

### C.5 DAGCanvasView.swift 现有结构 + 3个新View接入位置

原版文件：`Views/Autopilot/DAGCanvasView.swift`（427行）

| 项目 | 现状 | T04需要做的 |
|------|------|------------|
| 画布渲染 | ✅ Canvas + SugiyamaLayout (DAGCanvasView.swift:47-72) | 保留 |
| 缩放/平移手势 | ✅ MagnificationGesture + DragGesture (DAGCanvasView.swift:54-72) | 保留 |
| 点击节点 | ✅ onTapGesture → handleTap → showNodeDetail (DAGCanvasView.swift:73-75, 269-286) | **保留点击打开详情**，但详情Sheet需替换为NodeDetailPanel |
| 节点详情Sheet | ⚠️ 简单Form (DAGCanvasView.swift:113-117, 314-358) | **替换为完整NodeDetailPanel**（对齐原版NodeDetailPanel.vue） |
| 长按菜单 | ❌ 缺失 | **新增**：长按节点弹出NodeContextMenu（对齐原版NodeContextMenu.vue） |
| 配置抽屉 | ❌ 缺失 | **新增**：NodeContextMenu"查看详情"→NodeDetailPanel，NodeDetailPanel底部可进入NodeEditorDrawer（对齐原版NodeEditorDrawer.vue） |
| 控制按钮 | ✅ 放大/缩小/重置 (DAGCanvasView.swift:78-101) | 保留 |
| 背景网格 | ✅ (DAGCanvasView.swift:122-143) | 保留 |
| 脉冲动画 | ✅ (DAGCanvasView.swift:300-310) | 保留 |
| 颜色辅助 | ✅ (DAGCanvasView.swift:362-426) | 保留 |
| Autopilot目录其他文件 | AutopilotLogStream.swift, AutopilotConsoleView.swift, CircuitBreakerCard.swift, AutopilotControlPanel.swift | 不变 |

**接入点总结：**
1. **NodeContextMenu**：在DAGCanvasView的handleTap中增加长按手势（LongPressGesture），长按节点时弹出上下文菜单浮层
2. **NodeDetailPanel**：替换现有nodeDetailSheet，由NodeContextMenu的"查看详情"或单击节点触发
3. **NodeEditorDrawer**：作为独立的.sheet，由NodeDetailPanel内部或NodeContextMenu触发（原版NodeDetailPanel本身不直接打开Drawer，但NodeContextMenu可扩展——需确认原版中Drawer的触发入口）

---

## D. 疑问清单（上报主理人决策，不许自作主张）

### D.1 高优先级疑问

**疑问1：updateNodeConfig 走不走API？**
- 原版dagStore.ts:290-305的updateNodeConfig**注释明确写了"★ 暂时直接更新内存中的 DAG 定义（不走数据库）"**，只做内存合并，不调用dagApi.updateNodeConfig（PUT /dag/{novel_id}/nodes/{node_id}）。
- 但dag.ts:82-83确实定义了PUT端点。
- iOS APIEndpoint.swift:168也定义了.updateNode（PUT）。
- **问题**：iOS移植应该照搬原版的"内存更新"行为，还是调用PUT API？
- **寇豆码建议**：照搬原版行为（内存更新），因为原版注释明确这是有意为之。

**疑问2：AutopilotStatus缺少写作遥测字段**
- NodeDetailPanel.vue:86-97 显示的写作遥测字段中，`accumulated_words`、`chapter_target_words`、`context_tokens` 三个字段在iOS AutopilotStatus模型（AutopilotModels.swift:17-170）中**不存在**。
- iOS已有字段：`currentStage`、`writingSubstep`、`writingSubstepLabel` — 这三个够用。
- **问题**：iOS需要新增 `accumulatedWords`、`chapterTargetWords`、`contextTokens` 三个字段到AutopilotStatus吗？还是用AnyCodable/raw dict解析？
- **寇豆码建议**：新增三个Optional字段到AutopilotStatus，用decodeIfPresent防御。

**疑问3：题材包加载方式 — 本地JSON还是API？**
- 原版cnMarket.ts:1 `import raw from './builtin_cn_v1.bundle.json'` — **直接import本地JSON**，不走API。
- 但iOS APIEndpoint.swift:544定义了 `Taxonomy.builtinBundle` → GET /taxonomy/bundles/builtin_cn_v1。
- bundle.json约0.3MB，14大类约70+子主题。
- **问题**：iOS应该把bundle.json打包到App Bundle本地加载（对齐原版import），还是通过API GET拉取？
- **寇豆码建议**：两种方案各有优劣：
  - 方案A（本地打包）：对齐原版，离线可用，但JSON更新需发版
  - 方案B（API拉取）：可热更新，但首次需联网
  - 建议方案A（本地打包），因为原版就是本地import，且题材包不常变

**疑问4：TaxonomyModels.swift schemaVersion类型不匹配**
- 原版types.ts:31 `schema_version: number`
- bundle.json:3 `"schema_version": 1`（整数）
- iOS TaxonomyModels.swift:16 `let schemaVersion: String` → 用 `decodeIfPresent(String.self)` 解码
- **问题**：JSON中是数字1，Swift用String解码会失败（JSONDecoder不会自动将Int转String）。这是T01遗留bug还是有意为之？
- **寇豆码建议**：改为Int类型，对齐原版。

**疑问5：promptPlazaBridge iOS等价物**
- NodeEditorDrawer.vue依赖 `usePromptPlazaBridge`（promptPlazaBridge.ts:1-107）实现：
  - `getCpmsKey(dagNodeType)` — 从nodeTypeRegistry或registryLinkage查CPMS key
  - `openPromptInPlaza(nodeKey)` — 打开提示词广场
- iOS目前没有PromptPlaza相关实现。
- **问题**：T04是否需要实现完整的promptPlazaBridge？还是只实现getCpmsKey部分，"在广场编辑"按钮先占位（后续阶段实现）？
- **寇豆码建议**：getCpmsKey可以实现（依赖nodeTypeRegistry），"在广场编辑"按钮先占位或导航到提示词广场页面（如果已有）。

### D.2 中优先级疑问

**疑问6：NodeDetailPanel是modal还是sheet？**
- 原版NodeDetailPanel.vue:1使用 `<n-modal preset="card">`，是居中弹窗（maxWidth=640px, width=90vw）。
- iOS技术约定要求"Drawer/Sheet用SwiftUI原生 .sheet / .fullScreenCover"。
- **问题**：iOS用.sheet呈现NodeDetailPanel？原版是modal不是drawer。
- **寇豆码建议**：用.sheet，iOS没有naive-ui的modal概念，.sheet是自然对应物。

**疑问7：NodeContextMenu长按手势实现方式**
- 原版NodeContextMenu.vue用Teleport+fixed定位实现浮层菜单。
- iOS SwiftUI可用 `.contextMenu` 修饰符，或自定义overlay。
- **问题**：用SwiftUI原生 `.contextMenu` 还是自定义overlay？
- **寇豆码建议**：用自定义overlay（.overlay + GeometryReader），因为原生.contextMenu样式无法自定义，且原版有header/divider/hover等自定义样式。但iOS没有hover，用tap即可。

**疑问8：NodeEditorDrawer触发入口**
- 原版NodeEditorDrawer.vue:157 `defineExpose({ open })` — 供外部调用。
- 但在已读文件中，没有找到谁调用了 `open(nodeId, dagId)`。NodeContextMenu只有"查看详情"和"启禁用"两项，没有"配置"。
- **问题**：NodeEditorDrawer的触发入口在哪？是在NodeDetailPanel内部？还是在DAGCanvasView的其他位置？
- **寇豆码建议**：需Grep搜索原版代码中调用 `editorDrawer.open` 或 `$refs.editorDrawer` 的位置。可能在DAGCanvas.vue或AutopilotDashboard.vue中。

**疑问9：写作遥测轮询间隔**
- 原版performance.ts:29 `nodeWritingTelemetryPollMs: numberFromEnv('VITE_AUTOPILOT_NODE_TELEMETRY_POLL_MS', 2500)` — 默认2500ms。
- iOS AutopilotStore.swift已有状态轮询机制（startStatusPolling，自适应退避4s-60s）。
- **问题**：NodeDetailPanel的写作遥测轮询是否复用AutopilotStore的轮询？还是独立轮询？
- **寇豆码建议**：独立轮询，对齐原版（原版NodeDetailPanel有自己的usePolling实例，不复用autopilot状态轮询）。间隔用2500ms硬编码（iOS没有env var机制）。

**疑问10：NodeDetailPanel写作遥测的404处理**
- 原版NodeDetailPanel.vue:197-199：404时 `writingStatus = null; writingPollError = '该书暂无托管状态'`，**不停止轮询**。
- 但AutopilotStore.swift:311-315 的404处理是 `stoppedForNotFound = true`（停止轮询）。
- **问题**：NodeDetailPanel的写作遥测404行为是否应该和AutopilotStore一致（停止轮询）？
- **寇豆码建议**：照搬原版NodeDetailPanel行为（404显示提示但不停止轮询），因为原版是独立轮询实例，有自己的生命周期管理。

### D.3 低优先级疑问

**疑问11：CATEGORY_LABELS 在iOS的对应**
- 原版types/dag.ts:226-231定义了CATEGORY_LABELS映射（context→'上下文注入'等）。
- iOS DAGCanvasView.swift:402-410的categoryColor只做颜色映射，没有label映射。
- **问题**：需要在iOS新增CATEGORY_LABELS等价物？
- **寇豆码建议**：是，T04需要新增。

**疑问12：NodeDetailPanel的端口数据模型**
- 原版NodeMeta.input_ports/output_ports 是 NodePort[] 类型。
- iOS需要新增NodePort模型。
- **问题**：iOS现有NodeDefinition/NodeMeta模型中是否已有ports字段？
- **寇豆码建议**：需检查iOS现有DAGModels.swift，如无则新增。

---

## E. 功能对齐度自报

### 原版功能点统计

| 模块 | 原版功能点数量 | 事实表覆盖数量 | 覆盖率 |
|------|--------------|--------------|--------|
| A.1 NodeContextMenu | 9条 | 9条 | 100% |
| A.2 NodeDetailPanel | 32条 | 32条 | 100% |
| A.3 NodeEditorDrawer | 18条 | 18条 | 100% |
| A.4 DAG节点API端点 | 14条（13个端点+1个内存更新说明） | 14条 | 100% |
| B.1 数据模型+API | 20条 | 20条 | 100% |
| B.2 MarketTaxonomyPicker | 26条 | 26条 | 100% |
| **合计** | **119条** | **119条** | **100%** |

### iOS现有基础覆盖度

| 项目 | 现有就绪 | 需新增 | 备注 |
|------|---------|--------|------|
| API端点 | 13/13 (100%) | 0 | 全部就绪 |
| TaxonomyModels | 4/4 (100%) | 0（模型够用，schemaVersion类型需修复） | 够用 |
| DAGStore方法 | 7/13 (54%) | 6 (loadNodePromptLive, updateNodeConfig, loadNodeTypeRegistry, hydrateDagForNovel, nodeTypeRegistry state, registryLinkage state) | 需新增 |
| DAG数据模型 | 需确认 | NodePromptLive, NodeMeta, NodePort, DagRegistryLinkageResponse | 需检查现有DAGModels.swift |
| CreateNovelSheet | 硬编码需替换 | MarketTaxonomyPicker等价View | 需新建 |
| DAGCanvasView | 基础画布就绪 | NodeContextMenu + NodeDetailPanel(替换) + NodeEditorDrawer | 需新建3个View |

### 待确认疑问数

| 优先级 | 数量 |
|--------|------|
| 高优先级 | 5条 |
| 中优先级 | 5条 |
| 低优先级 | 2条 |
| **合计** | **12条** |

---

## F. 附录：原版文件读取清单

| # | 原版文件 | 路径 | 行数 | 读取状态 |
|---|---------|------|------|---------|
| 1 | NodeContextMenu.vue | components/autopilot/ | 113 | ✅ 完整读取 |
| 2 | NodeDetailPanel.vue | components/autopilot/ | 465 | ✅ 完整读取 |
| 3 | NodeEditorDrawer.vue | components/autopilot/ | 296 | ✅ 完整读取 |
| 4 | MarketTaxonomyPicker.vue | components/taxonomy/ | 495 | ✅ 完整读取 |
| 5 | cnMarket.ts | domain/taxonomy/ | 55 | ✅ 完整读取 |
| 6 | builtin_cn_v1.bundle.json | domain/taxonomy/ | ~1250+ (0.3MB) | ✅ 读取前120行+Grep全部root/child id |
| 7 | types.ts | domain/taxonomy/ | 49 | ✅ 完整读取 |
| 8 | dagStore.ts | stores/ | 355 | ✅ 完整读取 |
| 9 | dag.ts | api/ | 88 | ✅ 完整读取 |
| 10 | types/dag.ts | types/ | 270 | ✅ 完整读取 |
| 11 | promptPlazaBridge.ts | stores/ | 107 | ✅ 完整读取 |
| 12 | performance.ts | config/ | 30+ | ✅ Grep读取相关行 |
| 13 | autopilot.ts | api/ | 96 | ✅ Grep读取相关行 |

### iOS文件读取清单

| # | iOS文件 | 路径 | 行数 | 读取状态 |
|---|---------|------|------|---------|
| 1 | DAGStore.swift | ViewModels/ | 147 | ✅ 完整读取 |
| 2 | AutopilotStore.swift | ViewModels/ | 519 | ✅ 完整读取 |
| 3 | TaxonomyModels.swift | Models/ | 111 | ✅ 完整读取 |
| 4 | APIEndpoint.swift | Networking/ | 1628 | ✅ 完整读取 |
| 5 | CreateNovelSheet.swift | Views/Home/ | 207 | ✅ 完整读取 |
| 6 | DAGCanvasView.swift | Views/Autopilot/ | 427 | ✅ 完整读取 |
| 7 | AutopilotModels.swift | Models/ | 390 | ✅ 完整读取 |

---

*事实表结束。等待主理人确认后进入实现阶段。*
