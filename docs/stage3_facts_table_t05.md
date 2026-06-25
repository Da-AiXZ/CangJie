# T05 事实表：阶段3机制1 — 原版做了什么

> 工程师：寇豆码（Kou）
> 任务：T05 六面板全CRUD（P2）
> 产出性质：只读原版源码事实表，不含任何实现代码
> 覆盖面板：伏笔 / 道具 / 演化 / 编年史 / AntiAI / 对话沙盒

---

## A. 伏笔面板（ForeshadowLedgerPanel.vue）

原版文件：`components/workbench/ForeshadowLedgerPanel.vue`（519行）

### A.1 面板头部 + 筛选条 + Tab

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 1 | 面板标题"伏笔账本" | ForeshadowLedgerPanel.vue:8 | - | `<span class="pp-panel-title">` | - |
| 2 | 待兑现计数chip | ForeshadowLedgerPanel.vue:9 | pendingCount computed (entries.filter status==='pending') | `pp-chip--warning`，条件显示 pendingCount>0 | pendingCount: number |
| 3 | 已消费计数chip | ForeshadowLedgerPanel.vue:10 | consumedEntries.length | `pp-chip--muted`，条件显示 | consumedEntries: ForeshadowEntry[] |
| 4 | 帮助tooltip | ForeshadowLedgerPanel.vue:11-18 | - | n-tooltip + fsw-help-icon(?) 圆形按钮 | - |
| 5 | "+ 添加"按钮 | ForeshadowLedgerPanel.vue:22 | openCreateModal() | n-button size=small type=primary | - |
| 6 | 刷新按钮 | ForeshadowLedgerPanel.vue:23-30 | load() | n-button tiny quaternary + RefreshOutline icon + loading | - |
| 7 | 筛选："全部"按钮 | ForeshadowLedgerPanel.vue:36-40 | activeFilter='all'; filterCharacter=null | pp-filter-btn，条件高亮 | activeFilter: 'all'\|'due'\|'char' |
| 8 | 筛选："本章到期 ↑"按钮 | ForeshadowLedgerPanel.vue:41-46 | activeFilter='due'; filterCharacter=null | 条件显示：props.currentChapterNumber != null | - |
| 9 | 筛选：角色下拉 | ForeshadowLedgerPanel.vue:47-56 | filterCharacter + activeFilter='char' | n-select tiny clearable，options来自characterOptions | characterOptions: computed (去重 pendingEntries.character_id) |
| 10 | Tab："待兑现" + badge | ForeshadowLedgerPanel.vue:62-65 | activeTab='pending' | n-tabs type=segment + n-badge (pendingCount, max=99, warning) | activeTab: 'pending'\|'consumed' |
| 11 | Tab："已消费" | ForeshadowLedgerPanel.vue:66 | activeTab='consumed' | n-tab name=consumed | - |

### A.2 内容区 — 待兑现卡片

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 12 | 首次加载骨架屏 | ForeshadowLedgerPanel.vue:74-78 | !dataLoaded && loading | n-skeleton text rows=3 ×3 | dataLoaded: ref(false) |
| 13 | 待兑现空状态 | ForeshadowLedgerPanel.vue:84-88 | filteredPending.length===0 | pp-empty + 🪄 icon + 空文案(按activeFilter区分) + "+ 添加伏笔"按钮(all时) | - |
| 14 | 待兑现卡片容器 | ForeshadowLedgerPanel.vue:89-98 | filteredPending v-for | pp-accent-bar fsw-card，accentColor按importance，背景按is_priority_for_chapter | importanceAccentColor(importance), is_priority_for_chapter |
| 15 | 卡片行1：重要程度chip | ForeshadowLedgerPanel.vue:101-103 | importanceChipClass + importanceLabel | pp-chip + class按importance映射(danger/warning/brand/muted) | importance: 'low'\|'medium'\|'high'\|'critical' |
| 16 | 卡片行1：疑问文本 | ForeshadowLedgerPanel.vue:104 | entry.question | fsw-question，ellipsis省略 | question: string |
| 17 | 卡片行1：优先级星标按钮 | ForeshadowLedgerPanel.vue:105-112 | togglePriority(entry) | n-button tiny text，★(已标warning) / ☆(未标default)，loading=priorityLoadingId | is_priority_for_chapter: boolean |
| 18 | 卡片行2：章节chip | ForeshadowLedgerPanel.vue:116 | entry.chapter | pp-chip--muted "第{chapter}章" | chapter: number |
| 19 | 卡片行2：角色chip | ForeshadowLedgerPanel.vue:117 | entry.character_id | pp-chip--brand，条件显示 | character_id: string |
| 20 | 卡片行2：兑现提示 | ForeshadowLedgerPanel.vue:118-120 | entry.suggested_resolve_chapter | fsw-resolve-hint "→ 第{x}章兑现" | suggested_resolve_chapter: number\|null |
| 21 | 卡片行2：消费按钮(✓) | ForeshadowLedgerPanel.vue:122-127 | markConsumed(entry) | n-button tiny text type=success + tooltip"标记已消费" + loading=consumingId | consumingId: ref |
| 22 | 卡片行2：编辑按钮 | ForeshadowLedgerPanel.vue:128 | openEditModal(entry) | n-button tiny secondary | - |
| 23 | 卡片行2：删除按钮+确认 | ForeshadowLedgerPanel.vue:129-134 | remove(entry.id) | n-popconfirm → n-button tiny error tertiary | - |

### A.3 内容区 — 已消费卡片

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 24 | 已消费空状态 | ForeshadowLedgerPanel.vue:143-146 | consumedEntries.length===0 | pp-empty + ✅ icon + "暂无已消费伏笔" | - |
| 25 | 已消费卡片 | ForeshadowLedgerPanel.vue:147-163 | consumedEntries v-for | fsw-card fsw-card--consumed，opacity=0.82 | - |
| 26 | 已消费卡片：✓已消费chip + 疑问 | ForeshadowLedgerPanel.vue:153-155 | - | pp-chip--success + fsw-question--consumed | - |
| 27 | 已消费卡片：埋/兑现章节 | ForeshadowLedgerPanel.vue:157-161 | entry.chapter + entry.consumed_at_chapter | "第{x}章埋" → "第{y}章兑现" | consumed_at_chapter: number\|null |

### A.4 创建/编辑弹窗 + 消费弹窗

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 28 | 创建/编辑modal | ForeshadowLedgerPanel.vue:169-202 | showModal + editingEntry | n-modal preset=card，标题动态"编辑伏笔"/"添加伏笔" | editingEntry: ForeshadowEntry\|null |
| 29 | 表单：疑问textarea | ForeshadowLedgerPanel.vue:172-178 | form.question | n-input textarea autosize(2-5行) | form.question: string |
| 30 | 表单：关联角色 | ForeshadowLedgerPanel.vue:180-182 | form.character_id | n-input | form.character_id: string |
| 31 | 表单：埋入章节 | ForeshadowLedgerPanel.vue:183-185 | form.chapter | n-input-number min=1 | form.chapter: number |
| 32 | 表单：重要程度 | ForeshadowLedgerPanel.vue:186-188 | form.importance | n-select options=FORESHADOW_IMPORTANCE_OPTIONS | form.importance: ForeshadowImportance |
| 33 | 表单：预计兑现章 | ForeshadowLedgerPanel.vue:189-191 | form.suggested_resolve_chapter | n-input-number min=1 clearable | form.suggested_resolve_chapter: number\|null |
| 34 | 表单校验：疑问必填 | ForeshadowLedgerPanel.vue:340 | handleSubmit | !form.question.trim() → message.warning | - |
| 35 | 表单校验：角色必填 | ForeshadowLedgerPanel.vue:341 | handleSubmit | !form.character_id.trim() → message.warning | - |
| 36 | 提交：编辑→update | ForeshadowLedgerPanel.vue:344-351 | foreshadowApi.update(slug, id, patch) | PUT /novels/{id}/foreshadow-ledger/{entry_id} | UpdateForeshadowPayload |
| 37 | 提交：新建→create | ForeshadowLedgerPanel.vue:353-361 | foreshadowApi.create(slug, payload) | POST /novels/{id}/foreshadow-ledger，entry_id=`fsw-${Date.now()}` | CreateForeshadowPayload |
| 38 | 提交后reload | ForeshadowLedgerPanel.vue:365 | load() | - | - |
| 39 | 消费弹窗 | ForeshadowLedgerPanel.vue:205-217 | showConsumeModal + consumeChapter | n-modal preset=card width=340px，标题"标记已消费" | consumeChapter: ref(1) |
| 40 | 消费弹窗：兑现章节输入 | ForeshadowLedgerPanel.vue:207-209 | consumeChapter | n-input-number min=1 | - |
| 41 | 消费确认→markConsumed | ForeshadowLedgerPanel.vue:384-397 | foreshadowApi.markConsumed(slug, id, chapter) | 内部调update(slug, id, {status:'consumed', consumed_at_chapter}) | - |
| 42 | markConsumed默认章号 | ForeshadowLedgerPanel.vue:380 | (currentChapterNumber ?? entry.chapter) + 1 | - | - |

### A.5 CRUD逻辑 + 排序 + 筛选 + 生命周期

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 43 | load列表 | ForeshadowLedgerPanel.vue:291-308 | foreshadowApi.list(slug) | GET /novels/{id}/foreshadow-ledger，竞态保护(loadSeq) | entries: ForeshadowEntry[] |
| 44 | togglePriority星标 | ForeshadowLedgerPanel.vue:400-412 | foreshadowApi.update(slug, id, {is_priority_for_chapter}) | 局部更新entries[idx] | - |
| 45 | remove删除 | ForeshadowLedgerPanel.vue:414-422 | foreshadowApi.remove(slug, id) | DELETE + 局部过滤 | - |
| 46 | filteredPending排序 | ForeshadowLedgerPanel.vue:268-282 | - | priority优先 → importance降序(compareForeshadowImportanceDesc) | - |
| 47 | due筛选逻辑 | ForeshadowLedgerPanel.vue:270-273 | activeFilter==='due' | suggested_resolve_chapter != null && <= currentChapterNumber + 2 | - |
| 48 | char筛选逻辑 | ForeshadowLedgerPanel.vue:274-276 | activeFilter==='char' | character_id === filterCharacter | - |
| 49 | onMounted→load | ForeshadowLedgerPanel.vue:427 | - | - | - |
| 50 | pendingCount→emit | ForeshadowLedgerPanel.vue:428 | emit('pending-count', n) | watch immediate | - |
| 51 | foreshadowTick→reload | ForeshadowLedgerPanel.vue:429 | storeToRefs(workbenchRefreshStore) | watch foreshadowTick | - |
| 52 | slug→reload | ForeshadowLedgerPanel.vue:430 | - | watch props.slug | - |

### A.6 数据模型（foreshadow.ts + domain/foreshadow.ts）

```typescript
// api/foreshadow.ts:7-20
interface ForeshadowEntry {
  id: string
  chapter: number
  character_id: string
  question: string
  status: 'pending' | 'consumed'
  consumed_at_chapter: number | null
  suggested_resolve_chapter: number | null
  resolve_chapter_window: number | null
  importance: 'low' | 'medium' | 'high' | 'critical'
  is_priority_for_chapter: boolean
  created_at: string
}

// api/foreshadow.ts:22-30
interface CreateForeshadowPayload {
  entry_id: string
  chapter: number
  character_id: string
  question: string
  suggested_resolve_chapter?: number
  resolve_chapter_window?: number
  importance?: 'low' | 'medium' | 'high' | 'critical'
}

// api/foreshadow.ts:32-42
interface UpdateForeshadowPayload {
  chapter?, character_id?, question?, status?, consumed_at_chapter?,
  suggested_resolve_chapter?, resolve_chapter_window?, importance?, is_priority_for_chapter?
}

// domain/foreshadow.ts:9-44 — 重要程度元数据
FORESHADOW_IMPORTANCE_META = {
  critical: { label:'危急', order:4, chipClass:'pp-chip--danger', accentColor:'var(--color-danger)', tagType:'error' },
  high:     { label:'重要', order:3, chipClass:'pp-chip--warning', accentColor:'var(--color-warning)', tagType:'warning' },
  medium:   { label:'一般', order:2, chipClass:'pp-chip--brand', accentColor:'var(--color-brand)', tagType:'info' },
  low:      { label:'次要', order:1, chipClass:'pp-chip--muted', accentColor:'var(--app-border)', tagType:'default' },
}
```

---

## B. 道具面板（ManuscriptPropsPanel.vue + PropDetailDrawer.vue）

### B.1 ManuscriptPropsPanel.vue（567行）— 主面板

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 53 | 面板标题"手稿道具" | ManuscriptPropsPanel.vue:7 | - | pp-panel-title | - |
| 54 | "+ 新建"按钮 | ManuscriptPropsPanel.vue:9 | openCreate() | n-button small primary | - |
| 55 | 用法提示折叠面板 | ManuscriptPropsPanel.vue:13-28 | - | n-collapse + InformationCircleOutline icon，`[[prop:道具ID\|显示名]]` 语法说明 | - |
| 56 | 本章实体索引header | ManuscriptPropsPanel.vue:34-49 | - | wb-icon-badge + "本章实体索引" + "自动"chip + 刷新按钮 + reindex下拉 | - |
| 57 | 实体索引刷新按钮 | ManuscriptPropsPanel.vue:43 | loadMentions() | n-button loading=mentionLoading | - |
| 58 | 实体索引reindex下拉 | ManuscriptPropsPanel.vue:44-47 | handleSyncSelect('reindex') → runReindex() | n-dropdown + n-button ▾ | reindexOptions: [{label:'从正文重建', key:'reindex'}] |
| 59 | 实体标签云 | ManuscriptPropsPanel.vue:54-68 | mentions v-for | n-tag round + kindTagType + display_label + ×count | ChapterEntityMention |
| 60 | 实体kind标签 | ManuscriptPropsPanel.vue:61 | kindTagType(entity_kind) | char→success, faction→warning, prop→info, loc→default | - |
| 61 | 实体kind中文 | ManuscriptPropsPanel.vue:66 | kindLabel(entity_kind) | char→角色, loc→地点, faction→势力, prop→道具 | - |
| 62 | 实体索引空提示 | ManuscriptPropsPanel.vue:51-53 | !mentions.length | "尚无索引，保存章节或「从正文重建」" | - |
| 63 | 道具库header | ManuscriptPropsPanel.vue:73-82 | - | wb-icon-badge + "道具库" + 数量chip | propsRows.length |
| 64 | 道具库骨架屏 | ManuscriptPropsPanel.vue:84-86 | !propsDataLoaded && propsLoading | n-skeleton rows=3 | - |
| 65 | 道具库空状态 | ManuscriptPropsPanel.vue:88-92 | !propsRows.length | pp-empty + 📦 + "+ 新建道具" | - |
| 66 | 道具数据表 | ManuscriptPropsPanel.vue:93-100 | n-data-table | columns + propsRows, pagination=false, maxHeight=300 | - |
| 67 | 表格列：名称 | ManuscriptPropsPanel.vue:398-403 | row.name | width=90, ellipsis tooltip | - |
| 68 | 表格列：简述 | ManuscriptPropsPanel.vue:404-411 | row.description | ellipsis tooltip，空时显示"—" | - |
| 69 | 表格列：持有者 | ManuscriptPropsPanel.vue:412-422 | row.holder_character_id | width=72, charOptions查找label, 空时"—" | - |
| 70 | 表格列：类型(关键/普通) | ManuscriptPropsPanel.vue:423-446 | isKeyProp(row) + togglePropKey(row) | width=58, 可点击chip, tooltip说明 | attributes.key_context: boolean |
| 71 | 表格列：操作(编辑/删) | ManuscriptPropsPanel.vue:447-461 | openEdit(row) + removeRow(row) | width=96, 编辑tiny + 删tiny error tertiary | - |
| 72 | 关键道具切换 | ManuscriptPropsPanel.vue:374-394 | propApi.patch(slug, id, {attributes:{key_context}}) | PATCH + 局部更新 | - |
| 73 | 创建/编辑modal | ManuscriptPropsPanel.vue:108-155 | showModal + editingId | n-modal preset=card width=480px | - |
| 74 | 表单：名称 | ManuscriptPropsPanel.vue:115-117 | form.name | n-input placeholder="如：青铜罗盘" | - |
| 75 | 表单：简述 | ManuscriptPropsPanel.vue:118-124 | form.description | n-input textarea autosize(2-6) | - |
| 76 | 表单：别名(逗号分隔) | ManuscriptPropsPanel.vue:125-127 | form.aliasesText | n-input placeholder="罗盘,司南" | aliases: string[] (split by ,，) |
| 77 | 表单：分类 | ManuscriptPropsPanel.vue:128-130 | form.prop_category | n-select options=CATEGORY_LABELS | prop_category: WEAPON\|ARTIFACT\|TOOL\|CONSUMABLE\|TOKEN\|OTHER |
| 78 | 表单：持有者 | ManuscriptPropsPanel.vue:131-139 | form.holder_character_id | n-select filterable clearable, options=charOptions | - |
| 79 | 表单：登场章 | ManuscriptPropsPanel.vue:140-147 | form.introduced_chapter | n-input-number min=1 clearable | - |
| 80 | 表单校验：名称必填 | ManuscriptPropsPanel.vue:323 | !form.name.trim() | message.warning | - |
| 81 | 提交：编辑→patch | ManuscriptPropsPanel.vue:327-335 | propApi.patch(slug, id, body) | PATCH /novels/{id}/props/{prop_id} | - |
| 82 | 提交：新建→create | ManuscriptPropsPanel.vue:337-345 | propApi.create(slug, body) | POST /novels/{id}/props | - |
| 83 | 提交后reload | ManuscriptPropsPanel.vue:349 | loadProps() | - | - |
| 84 | loadCharOptions | ManuscriptPropsPanel.vue:220-228 | bibleApi.listCharacters(slug) | GET → charOptions | - |
| 85 | loadProps | ManuscriptPropsPanel.vue:230-248 | propApi.list(slug) | GET /novels/{id}/props, 竞态保护 | - |
| 86 | loadMentions | ManuscriptPropsPanel.vue:250-266 | manuscriptApi.listChapterMentions(slug, n) | GET /novels/{id}/chapters/{n}/entity-mentions | - |
| 87 | runReindex | ManuscriptPropsPanel.vue:268-281 | manuscriptApi.reindexChapterMentions(slug, n) | POST /novels/{id}/chapters/{n}/entity-mentions/reindex | - |
| 88 | onMounted→3路加载 | ManuscriptPropsPanel.vue:465-469 | - | loadProps + loadMentions + loadCharOptions | - |
| 89 | slug/chapter/deskTick→reload | ManuscriptPropsPanel.vue:471-477 | - | watch [slug, currentChapter.number, deskTick] | - |
| 90 | slug→reload charOptions | ManuscriptPropsPanel.vue:479 | - | watch slug | - |

### B.2 PropDetailDrawer.vue（146行）— 详情抽屉

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 91 | n-drawer右侧抽屉 | PropDetailDrawer.vue:2-3 | - | n-drawer width=340 placement=right, show=true | props: prop, slug, charOptions |
| 92 | 抽屉标题 | PropDetailDrawer.vue:3 | prop.name | n-drawer-content title=closable | - |
| 93 | 生命周期标签 | PropDetailDrawer.vue:6-8 | LIFECYCLE_TAG_TYPES[prop.lifecycle_state] | n-tag size=small | lifecycle_state: DORMANT\|INTRODUCED\|ACTIVE\|DAMAGED\|RESOLVED |
| 94 | 分类标签+图标 | PropDetailDrawer.vue:9 | CATEGORY_ICONS + CATEGORY_LABELS | n-tag default small | prop_category |
| 95 | 描述文本 | PropDetailDrawer.vue:11 | prop.description \|\| '暂无描述' | n-text depth=3 | - |
| 96 | 持有者名称 | PropDetailDrawer.vue:12-15 | holderName computed | charOptions.find → label \|\| slice(0,8) | holder_character_id |
| 97 | 快速修复按钮(条件) | PropDetailDrawer.vue:17-21 | quickEvent('REPAIRED') | v-if lifecycle_state==='DAMAGED', n-button primary ghost | - |
| 98 | 事件时间线标题 | PropDetailDrawer.vue:23 | - | n-divider "事件时间线" | - |
| 99 | 事件时间线列表 | PropDetailDrawer.vue:24-41 | events v-for | n-timeline + n-timeline-item, type=eventTagType | events: PropEventDTO[] |
| 100 | 事件项：标题 | PropDetailDrawer.vue:31 | `第{chapter_number}章 · {EVENT_LABELS[event_type]}` | - | - |
| 101 | 事件项：描述+来源tag | PropDetailDrawer.vue:33-38 | ev.description + ev.source | MANUAL→warning"手动", AUTO_LLM→"AI", 其他→"标记" | source: AUTO_PATTERN\|AUTO_LLM\|MANUAL |
| 102 | 事件空状态 | PropDetailDrawer.vue:25 | !eventsLoading && events.length===0 | n-empty "暂无事件记录" | - |
| 103 | 添加事件按钮 | PropDetailDrawer.vue:43 | showAddEvent=true | n-button ghost block "＋ 手动记录事件" | - |
| 104 | 添加事件modal | PropDetailDrawer.vue:46-58 | showAddEvent + eventForm | n-modal preset=dialog title="记录事件" | eventForm: {chapter_number, event_type, description} |
| 105 | 事件表单：章节 | PropDetailDrawer.vue:48-50 | eventForm.chapter_number | n-input-number min=1 | - |
| 106 | 事件表单：类型 | PropDetailDrawer.vue:51-53 | eventForm.event_type | n-select options=eventTypeOptions | 7种：INTRODUCED/USED/TRANSFERRED/DAMAGED/REPAIRED/UPGRADED/RESOLVED |
| 107 | 事件表单：描述 | PropDetailDrawer.vue:54-56 | eventForm.description | n-input placeholder="一句话描述" | - |
| 108 | submitEvent | PropDetailDrawer.vue:131-142 | propApi.createEvent(slug, propId, eventForm) | POST /novels/{id}/props/{propId}/events + emit('updated') + reload | - |
| 109 | quickEvent | PropDetailDrawer.vue:113-129 | propApi.createEvent(slug, propId, {chapter_number:1, event_type, description}) | POST + emit('updated') + reload | - |
| 110 | loadEvents | PropDetailDrawer.vue:104-111 | propApi.listEvents(slug, propId) | GET /novels/{id}/props/{propId}/events | - |
| 111 | eventTagType映射 | PropDetailDrawer.vue:97-102 | - | DAMAGED→error, REPAIRED/INTRODUCED→success, TRANSFERRED→warning, 其他→info | - |
| 112 | EVENT_LABELS映射 | PropDetailDrawer.vue:85-88 | - | INTRODUCED→登场, USED→使用, TRANSFERRED→转移, DAMAGED→损毁, REPAIRED→修复, UPGRADED→强化, RESOLVED→结局 | - |
| 113 | onMounted→loadEvents | PropDetailDrawer.vue:144 | - | - | - |

### B.3 数据模型（propApi.ts + manuscript.ts）

```typescript
// api/propApi.ts:3-17
interface PropDTO {
  id: string; novel_id: string; name: string; description: string;
  aliases: string[]; prop_category: 'WEAPON'|'ARTIFACT'|'TOOL'|'CONSUMABLE'|'TOKEN'|'OTHER';
  lifecycle_state: 'DORMANT'|'INTRODUCED'|'ACTIVE'|'DAMAGED'|'RESOLVED';
  introduced_chapter: number|null; resolved_chapter: number|null;
  holder_character_id: string|null; attributes: Record<string, unknown>;
  created_at: string; updated_at: string;
}

// api/propApi.ts:19-30
interface PropEventDTO {
  id: string; prop_id: string; chapter_number: number; event_type: string;
  source: 'AUTO_PATTERN'|'AUTO_LLM'|'MANUAL'; description: string;
  actor_character_id: string|null; from_holder_id: string|null; to_holder_id: string|null;
  created_at: string;
}

// api/manuscript.ts:17-23
interface ChapterEntityMention {
  entity_kind: string; entity_id: string; display_label: string;
  mention_count: number; updated_at: string;
}

// propApi.ts:32-64 — 常量映射
LIFECYCLE_LABELS: DORMANT→未登场, INTRODUCED→已登场, ACTIVE→使用中, DAMAGED→损毁, RESOLVED→已结局
CATEGORY_LABELS: WEAPON→武器, ARTIFACT→法器, TOOL→工具, CONSUMABLE→消耗品, TOKEN→信物, OTHER→其他
CATEGORY_ICONS: WEAPON→🗡, ARTIFACT→🔮, TOOL→🔧, CONSUMABLE→💊, TOKEN→📜, OTHER→📦
```

---

## C. 演化面板（StoryEvolutionPanel.vue）

原版文件：`components/workbench/StoryEvolutionPanel.vue`（1362行）

### C.1 面板头部 + Tab切换

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 114 | Banner头部 | StoryEvolutionPanel.vue:4-17 | - | PulseOutline icon + "故事演进" + 章节tag + subtitle | currentChapter: number\|null |
| 115 | Tab按钮组(4个) | StoryEvolutionPanel.vue:19-48 | activeTab切换 | n-button-group: 司令塔/状态机/时间轴/世界线 | activeTab: 'command'\|'state'\|'timeline'\|'worldline' |
| 116 | "角色档案"按钮 | StoryEvolutionPanel.vue:49 | openCharacterAnchor() | n-button secondary → dispatchEvent(WORKBENCH_OPEN_SETTINGS_PANEL_EVENT, {panel:'sandbox'}) | - |

### C.2 司令塔Tab（command）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 117 | Hero区域：Narrative Ops | StoryEvolutionPanel.vue:63-69 | - | command-kicker + "演进司令塔" + risk tag + 描述 | riskSummaryLabel computed |
| 118 | Hero：承诺命中率 | StoryEvolutionPanel.vue:71-77 | governanceHitRate + governanceHitPercent | command-score + 进度条 | governanceState.latest_report.promise_hit_rate |
| 119 | Hero：状态快照 | StoryEvolutionPanel.vue:78-82 | latestSnapshot | command-score "第{x}章" / "未生成" + snapshotStatusLabel | - |
| 120 | Hero：世界线 | StoryEvolutionPanel.vue:83-87 | worldlineSummary + worldlineHeadName | command-score "{branches}分支/{checkpoints}存档" | - |
| 121 | 引导落点区域 | StoryEvolutionPanel.vue:90-112 | setupAnchorRows computed | setup-anchor-grid, 卡片(title+meta tag+detail) | 最多10条anchor |
| 122 | 引导落点：类型世界基调 | StoryEvolutionPanel.vue:536-544 | novel.locked_genre + locked_world_preset | key='genre-world', type=info | - |
| 123 | 引导落点：初始粗纲 | StoryEvolutionPanel.vue:546-554 | novel.premise | key='premise', type=default | - |
| 124 | 引导落点：故事骨架节奏 | StoryEvolutionPanel.vue:556-564 | novel.locked_story_structure + locked_pacing_control | key='structure', type=success | - |
| 125 | 引导落点：主线总纲 | StoryEvolutionPanel.vue:566-574 | outline.main_story_overview + core_conflict | key='plot-outline', type=info, meta=阶段数 | - |
| 126 | 引导落点：核心冲突 | StoryEvolutionPanel.vue:576-584 | outline.core_conflict | key='core-conflict', type=warning | - |
| 127 | 引导落点：结局走向 | StoryEvolutionPanel.vue:586-594 | outline.expected_ending | key='ending', type=success | - |
| 128 | 引导落点：核心人物 | StoryEvolutionPanel.vue:596-610 | bible.characters.slice(0,5) | key='characters', name+motivation | - |
| 129 | 引导落点：世界观落点 | StoryEvolutionPanel.vue:612-626 | bible.world_settings.slice(0,4) | key='world-settings' | - |
| 130 | 引导落点：关键地点 | StoryEvolutionPanel.vue:628-642 | bible.locations.slice(0,4) | key='locations' | - |
| 131 | 引导落点：文风公约 | StoryEvolutionPanel.vue:644-653 | bible.style/style_notes + novel.locked_writing_style | key='style', type=success | - |
| 132 | 引导落点：特殊要求 | StoryEvolutionPanel.vue:655-663 | novel.locked_special_requirements | key='special-requirements', type=warning | - |
| 133 | 自动写前约束面板 | StoryEvolutionPanel.vue:115-137 | budgetSummary + budgetPromiseTags | 叙事预算/必须服务/连续性描述 | governanceState.chapter_budget_preview |
| 134 | 叙事治理面板 | StoryEvolutionPanel.vue:139-156 | governanceIssues + governanceSeverityType | issues列表(title+detail) | governanceState.latest_report.issues |
| 135 | 状态连续性面板 | StoryEvolutionPanel.vue:158-174 | evidenceRows + snapshotStatusType | evidence列表(label+value) | latestSnapshot |
| 136 | 世界线面板(简要) | StoryEvolutionPanel.vue:176-198 | worldlineGraph | 检查点/分支/HEAD计数 + "打开"按钮 | - |
| 137 | 风险与修复队列 | StoryEvolutionPanel.vue:201-222 | combinedRisks + riskSummaryType | risk-lane, risk-card(按type着色), 最多12条 | combinedRisks: governance issues + conflicts |

### C.3 状态机Tab（state）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 138 | 状态树列 | StoryEvolutionPanel.vue:226-272 | latestSnapshot | evolution-col，空状态n-empty | latestSnapshot: EvolutionSnapshot |
| 139 | 状态摘要网格 | StoryEvolutionPanel.vue:238-255 | sceneState | 4个metric: Schema/状态/时空锚点/情绪余波 | ending_state.scene |
| 140 | 角色状态列表 | StoryEvolutionPanel.vue:256-270 | characterRows (Object.entries, slice 16) | state-row: name + status·location + 状态下拉 | ending_state.characters |
| 141 | 角色状态修改 | StoryEvolutionPanel.vue:262-268 | updateCharacterStatus(id, status) | n-dropdown → applyOverrides with JSON Patch | characterStatusOptions: alive/dead/missing/ambiguous/severely_injured |
| 142 | 状态流列 | StoryEvolutionPanel.vue:274-295 | latestActions + conflicts | action-row(type+action_id) + violation-row(level+message) | delta_actions + conflicts |
| 143 | 证据列 | StoryEvolutionPanel.vue:297-311 | evidenceRows | evidence-row(label+value) | source_refs/conflicts/delta_actions |

### C.4 时间轴Tab（timeline）+ 世界线Tab（worldline）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 144 | 时间轴n-split布局 | StoryEvolutionPanel.vue:315-359 | - | n-split horizontal(0.24) → StoryNavigator + n-split(0.55) → StoryTimeline + StoryDetailPanel | - |
| 145 | StoryNavigator子组件 | StoryEvolutionPanel.vue:324-330 | - | props: slug, currentChapter, evolutionBundle, evolutionLoading; emit select-storyline | StoryEvolutionReadModel |
| 146 | StoryTimeline子组件 | StoryEvolutionPanel.vue:338-346 | - | props: slug, highlightRange, bundledChronicleRows; emit select-event/select-snapshot/request-bundle-refresh | ChronicleRow[] |
| 147 | StoryDetailPanel子组件 | StoryEvolutionPanel.vue:351-355 | - | props: slug, selectedItem; emit refresh | selectedItem: {type, data} |
| 148 | 世界线Tab | StoryEvolutionPanel.vue:54-59 | WorldlineDAG | props: slug; emit checkpoint-restored | - |

### C.5 数据加载 + 交互逻辑

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 149 | loadBundle | StoryEvolutionPanel.vue:419-429 | narrativeEngineApi.getStoryEvolution(slug) | GET /novels/{id}/narrative-engine/story-evolution | StoryEvolutionReadModel |
| 150 | loadEvolutionSnapshots | StoryEvolutionPanel.vue:431-441 | evolutionApi.listSnapshots(slug) | GET /novels/{id}/evolution/snapshots?branch_id=main | EvolutionSnapshotList |
| 151 | loadGovernanceState | StoryEvolutionPanel.vue:443-449 | getGovernanceState(slug) | GET /novels/{id}/governance/state | GovernanceStateDTO |
| 152 | loadWorldlineGraph | StoryEvolutionPanel.vue:451-457 | worldlineApi.getGraph(slug) | GET /novels/{id}/worldline/graph | WorldlineGraph |
| 153 | loadSetupAnchors | StoryEvolutionPanel.vue:459-473 | Promise.allSettled([novelApi.getNovel, bibleApi.getBible, workflowApi.getPlotOutline]) | 3路并行加载 | NovelDTO, BibleDTO, PlotOutlineDTO |
| 154 | updateCharacterStatus | StoryEvolutionPanel.vue:479-495 | evolutionApi.applyOverrides(slug, chapter, [{op:'replace', path, value}]) | POST /novels/{id}/evolution/snapshots/{chapter}/overrides + reload | JSON Patch (RFC 6902) |
| 155 | escapeJsonPointer | StoryEvolutionPanel.vue:475-477 | - | ~/→~0, /→~1 | - |
| 156 | onSelectStoryline | StoryEvolutionPanel.vue:769-774 | - | 设highlightRange {start, end} | - |
| 157 | onSelectEvent | StoryEvolutionPanel.vue:777-779 | - | selectedItem = {type:'event', data} | - |
| 158 | onSelectSnapshot | StoryEvolutionPanel.vue:782-784 | - | selectedItem = {type:'snapshot', data} | - |
| 159 | onCheckpointRestored | StoryEvolutionPanel.vue:787-793 | dispatchEvent(WORKBENCH_CHAPTER_DESK_CHANGE_EVENT) | 清空选择 + reload snapshots + worldline | - |
| 160 | slug watch→5路reload | StoryEvolutionPanel.vue:746-758 | - | watch immediate: loadBundle + loadEvolutionSnapshots + loadGovernanceState + loadWorldlineGraph + loadSetupAnchors | - |
| 161 | useWorkbenchPlotTimelineReload→5路reload | StoryEvolutionPanel.vue:760-766 | - | - | - |

### C.6 关键计算属性

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 162 | bundledChronicleRows | StoryEvolutionPanel.vue:497-501 | bundle.chronotope.rows | 转为ChronicleRow[] | - |
| 163 | latestSnapshot | StoryEvolutionPanel.vue:503 | snapshots[0] | - | - |
| 164 | sceneState | StoryEvolutionPanel.vue:504 | latestSnapshot.ending_state.scene | - | - |
| 165 | characterRows | StoryEvolutionPanel.vue:505 | Object.entries(ending_state.characters).slice(0,16) | - | - |
| 166 | latestActions | StoryEvolutionPanel.vue:506 | latestSnapshot.delta_actions | - | - |
| 167 | conflictCount | StoryEvolutionPanel.vue:508 | latestSnapshot.conflicts.length | - | - |
| 168 | combinedRisks | StoryEvolutionPanel.vue:725-734 | governanceIssues + conflicts | 合并后slice(0,12) | - |
| 169 | riskSummaryType/Label | StoryEvolutionPanel.vue:735-744 | combinedRisks | 有error→'需处理', 有items→'有提醒', 否则→'可推进' | - |
| 170 | snapshotStatusType | StoryEvolutionPanel.vue:713-719 | latestSnapshot.status + conflictCount | blocked/conflicts>0→error, stale→warning, 其他→success | - |

### C.7 数据模型（evolution.ts + narrativeEngine.ts + governance.ts + worldline.ts）

```typescript
// api/evolution.ts:3-19
interface EvolutionSnapshot {
  snapshot_id: string; novel_id: string; branch_id: string; chapter_number: number;
  schema_version: string; status: 'active'|'stale'|'blocked';
  opening_state: Record<string, unknown>; delta_actions: Array<Record<string, any>>;
  machine_state: Record<string, unknown>; human_override_patches: Array<Record<string, unknown>>;
  ending_state: Record<string, any>; source_refs: Array<Record<string, unknown>>;
  conflicts: Array<Record<string, any>>; created_at: string; updated_at: string;
}

// api/narrativeEngine.ts:9-38
interface StoryEvolutionReadModel {
  novel_id: string; schema_version: string; life_cycle: StoryPhaseDTO;
  plot_spine: { storylines: StorylineDTO[]; plot_arc: Record<string, unknown>|null };
  chronotope: { rows: unknown[]; max_chapter_in_book: number; note?: string };
  chapters_digest: unknown[]; subtext_surface: { foreshadow_ledger_count: number };
  evolution_surface?: { active_snapshot: {...}|null; counts: Record<string,number>;
    recent_gate_risks: unknown[]; required_continuations: string[] };
}

// api/governance.ts:61-67
interface GovernanceStateDTO {
  contract: NarrativeContractDTO; canonical_storylines: CanonicalStorylineDTO[];
  open_debts: Array<Record<string, unknown>>; latest_report: GovernanceReportDTO|null;
  chapter_budget_preview: ChapterNarrativeBudgetDTO;
}

// api/worldline.ts:38-43
interface WorldlineGraph {
  nodes: CheckpointNode[]; edges: {from,to,kind?}[];
  branches: BranchInfo[]; head_id: string|null;
}
```

---

## D. 编年史面板（HolographicChroniclesPanel.vue）

原版文件：`components/workbench/HolographicChroniclesPanel.vue`（489行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 171 | 头部：标题+说明+刷新 | HolographicChroniclesPanel.vue:3-12 | - | h3"全息编年史" + lead说明(左里世界/右表世界) + n-button刷新 | - |
| 172 | 说明文案 | HolographicChroniclesPanel.vue:6-9 | - | "中轴为章进度锚点：左里世界剧情时间，右表世界快照（存档）" | - |
| 173 | Note提示条 | HolographicChroniclesPanel.vue:14-16 | noteText | n-alert type=default show-icon | note: string |
| 174 | 视图切换 | HolographicChroniclesPanel.vue:18-21 | hcView | n-radio-group: "双螺旋概览" / "剧情时间线·列表编辑(Bible)" | hcView: 'helix'\|'timeline' |
| 175 | Helix空状态 | HolographicChroniclesPanel.vue:25-31 | rows.length===0 | n-empty 🧬 + 提示切换到timeline或创建snapshots | - |
| 176 | Helix表头 | HolographicChroniclesPanel.vue:34-38 | - | grid 3列: "进度"/"里世界·剧情"/"表世界·快照" | - |
| 177 | Helix行：章节锚点 | HolographicChroniclesPanel.vue:46-49 | row.chapter_index | helix-dot + "第{x}章" (竖排文字) | chapter_index: number |
| 178 | Helix行：剧情事件 | HolographicChroniclesPanel.vue:51-62 | row.story_events v-for | story-node: 绿色背景, n-tag success(time) + title + description | ChronicleStoryEvent[] |
| 179 | Helix行：快照节点 | HolographicChroniclesPanel.vue:64-88 | row.snapshots v-for | snap-node: 紫色背景, n-tag(MANUAL→warning/Auto→info) + name + 回滚按钮 | ChronicleSnapshot[] |
| 180 | Hover高亮 | HolographicChroniclesPanel.vue:44, 70-71 | hoverChapter | mouseenter→hoverChapter=chapter_index, helix-row--hot高亮 | hoverChapter: number\|null |
| 181 | onSnapNodeLeave智能离开 | HologadowedChroniclesPanel.vue:136-141 | - | relatedTarget在同行内时不熄灭 | - |
| 182 | snapTooltip | HolographicChroniclesPanel.vue:130-133 | sn.name+description+created_at | title属性 | - |
| 183 | 回滚按钮 | HolographicChroniclesPanel.vue:77-85 | confirmRollback(sn) | n-button tiny quaternary loading=rollbackId, title="删除快照未收录的章节" | - |
| 184 | 回滚确认对话框 | HolographicChroniclesPanel.vue:143-165 | dialog.warning | "确认回滚到此快照？" + 说明不可撤销, positiveText="回滚" | - |
| 185 | 回滚API调用 | HolographicChroniclesPanel.vue:152-153 | chroniclesApi.rollbackToSnapshot(slug, sn.id) | POST /novels/{id}/snapshots/{snapshot_id}/rollback | SnapshotRollbackResponse |
| 186 | 回滚成功 | HolographicChroniclesPanel.vue:154 | - | message.success(`已回滚，移除 ${deleted_count} 个章节`) | deleted_count: number |
| 187 | 回滚后刷新 | HolographicChroniclesPanel.vue:155-156 | refreshStore.bumpAfterChapterDeskChange() + load() | - | - |
| 188 | 轴底footer | HolographicChroniclesPanel.vue:91-93 | maxChapter | "书目已展开至第 {maxChapter} 章" | max_chapter_in_book: number |
| 189 | Timeline视图 | HolographicChroniclesPanel.vue:97-99 | TimelinePanel | hc-view-embed嵌入TimelinePanel组件, props: slug | - |
| 190 | load | HolographicChroniclesPanel.vue:167-181 | chroniclesApi.get(slug) | GET /novels/{id}/chronicles → rows + maxChapter + note | ChroniclesResponse |
| 191 | slug→load | HolographicChroniclesPanel.vue:183 | - | watch immediate | - |
| 192 | chroniclesTick→load | HolographicChroniclesPanel.vue:185-187 | storeToRefs(workbenchRefreshStore) | watch chroniclesTick | - |

### 数据模型（chronicles.ts）

```typescript
interface ChronicleStoryEvent { note_id: string; time: string; title: string; description: string; source_chapter: number|null; }
interface ChronicleSnapshot { id: string; kind: string; name: string; branch_name: string; created_at: string|null; description: string|null; anchor_chapter: number|null; }
interface ChronicleRow { chapter_index: number; story_events: ChronicleStoryEvent[]; snapshots: ChronicleSnapshot[]; }
interface ChroniclesResponse { rows: ChronicleRow[]; max_chapter_in_book: number; note: string; }
interface SnapshotRollbackResponse { deleted_chapter_ids: string[]; deleted_count: number; }
```

---

## E. AntiAI面板（AntiAIDashboard.vue）

原版文件：`components/workbench/promptPlaza/AntiAIDashboard.vue`（1043行）

### E.1 头部 + 子标签

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 193 | 头部标题+副标题 | AntiAIDashboard.vue:4-8 | - | h3"Anti-AI 防御系统" + p"七层纵深防御体系" | - |
| 194 | 使用教程按钮 | AntiAIDashboard.vue:10-13 | showTutorial=true | n-button small primary secondary | - |
| 195 | 子标签页(4个) | AntiAIDashboard.vue:17-27 | activeSubTab | sub-tab: 概览/快速扫描/规则/白名单 | activeSubTab: 'overview'\|'scan'\|'rules'\|'allowlist' |

### E.2 概览面板

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 196 | 七层防御网格 | AntiAIDashboard.vue:34-53 | defenseLayers computed | layers-grid, layer-card(icon+name+desc+status tag) | defenseLayers: 7 items |
| 197 | L1 正向行为映射 | AntiAIDashboard.vue:427-433 | - | active=true(硬编码), color=#6366f1 | - |
| 198 | L2 核心协议P1-P5 | AntiAIDashboard.vue:434-441 | - | active=true(硬编码), color=#8b5cf6 | - |
| 199 | L3 场景化白名单 | AntiAIDashboard.vue:442-449 | layers.L3_allowlist_scenes > 0 | active动态, color=#a855f7 | antiAIStats.layers.L3_allowlist_scenes |
| 200 | L4 角色状态向量 | AntiAIDashboard.vue:450-457 | layers.L4_state_vector === 'active' | active动态, color=#d946ef | - |
| 201 | L5 上下文配额 | AntiAIDashboard.vue:458-465 | layers.L5_context_quota === 'active' | active动态, color=#ec4899 | - |
| 202 | L6 Token级拦截 | AntiAIDashboard.vue:466-473 | layers.L6_token_guard === 'active' | active动态, color=#f43f5e | - |
| 203 | L7 章后审计 | AntiAIDashboard.vue:474-482 | layers.L7_audit === 'active' | active动态, color=#ef4444 | - |
| 204 | 系统统计区 | AntiAIDashboard.vue:56-76 | antiAIStats | stats-grid, 4个stat-card | AntiAIStats |
| 205 | 统计：总提示词数 | AntiAIDashboard.vue:60-62 | antiAIStats.total_prompts | stat-number | - |
| 206 | 统计：Anti-AI提示词 | AntiAIDashboard.vue:63-65 | antiAIStats.anti_ai_prompts | stat-number.accent | - |
| 207 | 统计：俗套检测模式 | AntiAIDashboard.vue:66-68 | antiAIStats.cliche_patterns | stat-number | - |
| 208 | 统计：分类数 | AntiAIDashboard.vue:69-71 | antiAIStats.categories_count | stat-number | - |

### E.3 快速扫描面板

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 209 | 扫描文本输入 | AntiAIDashboard.vue:85-91 | scanInput | n-input textarea autosize(5-14) | scanInput: string |
| 210 | 扫描按钮 | AntiAIDashboard.vue:93-100 | handleScan() | n-button primary loading=scanning disabled=!trim | - |
| 211 | 清空按钮 | AntiAIDashboard.vue:101-103 | scanInput='' | n-button quaternary, 条件显示 | - |
| 212 | 扫描结果：总评 | AntiAIDashboard.vue:108-111 | scanResult.overall_assessment | result-assessment, 颜色按ASSESSMENT_COLORS映射 | overall_assessment: '纯净'\|'轻微'\|'中等'\|'严重'\|'未检测' |
| 213 | 扫描结果：严重性分数 | AntiAIDashboard.vue:112-114 | scanResult.severity_score | "严重性分数：{x}/100" | severity_score: number |
| 214 | 扫描结果：统计3项 | AntiAIDashboard.vue:117-130 | critical_hits + warning_hits + total_hits | 3个stat-item(严重/警告/总命中) | - |
| 215 | 扫描结果：分类分布 | AntiAIDashboard.vue:133-151 | category_distribution | dist-bars, 每行cat+进度条+count | category_distribution: Record<string, number> |
| 216 | 扫描结果：改进建议 | AntiAIDashboard.vue:154-163 | improvement_suggestions | suggestion-item列表, 左边框绿色 | - |
| 217 | 扫描结果：修改建议 | AntiAIDashboard.vue:166-175 | recommendations | recommendation-item列表, 左边框橙色 | - |
| 218 | 扫描结果：命中详情 | AntiAIDashboard.vue:178-196 | hits.slice(0,30) | hit-item: severity tag + pattern + text(code) + replacement_hint | ClicheHit[] |
| 219 | 命中详情超30条提示 | AntiAIDashboard.vue:193-195 | hits.length > 30 | "还有 {N} 处命中…" | - |
| 220 | handleScan | AntiAIDashboard.vue:492-502 | scanChapter(scanInput) | POST /anti-ai/scan {content, chapter_id:''} | ScanResult |
| 221 | assessmentColor | AntiAIDashboard.vue:486-489 | ASSESSMENT_COLORS[overall_assessment] | computed | - |
| 222 | severityTagType | AntiAIDashboard.vue:504-511 | - | critical→error, warning→warning, info→info | - |

### E.4 规则面板

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 223 | 规则说明文案 | AntiAIDashboard.vue:206-209 | - | "正向行为映射规则：将'禁止X'重构为'当遇到Y时执行Z'" | - |
| 224 | 规则加载中 | AntiAIDashboard.vue:211-213 | rulesLoading | n-spin small | - |
| 225 | 规则卡片列表 | AntiAIDashboard.vue:215-233 | rules v-for | rule-card: severity tag + anti_pattern + category tag + positive_action | AntiAIRule[] |
| 226 | 规则空状态 | AntiAIDashboard.vue:235 | - | n-empty "暂无规则数据" | - |
| 227 | loadRules | AntiAIDashboard.vue:525-534 | getRules() | GET /anti-ai/rules | AntiAIRule[] |

### E.5 白名单面板

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 228 | 白名单说明文案 | AntiAIDashboard.vue:244-247 | - | "在特定场景中部分AI味模式被允许，白名单不等于滥用" | - |
| 229 | 白名单加载中 | AntiAIDashboard.vue:249-251 | allowlistLoading | n-spin small | - |
| 230 | 场景卡片列表 | AntiAIDashboard.vue:253-291 | allowlistScenes v-for | scene-card: type label + key(code) + density tag + desc + categories + patterns | AllowlistScene[] |
| 231 | 场景类型中文 | AntiAIDashboard.vue:260 | getSceneLabel(scene_type) | SCENE_TYPE_LABELS映射 | scene_type: default/battle/suspense/horror/confession/revelation |
| 232 | 密度上限显示 | AntiAIDashboard.vue:262-264 | scene.max_density_per_1000 | n-tag info "密度上限: {x}/千字" | - |
| 233 | 豁免分类标签 | AntiAIDashboard.vue:267-278 | scene.allowed_categories | n-tag success tiny × N | - |
| 234 | 豁免模式标签 | AntiAIDashboard.vue:279-289 | scene.allowed_patterns | n-tag tiny × N | - |
| 235 | 白名单空状态 | AntiAIDashboard.vue:293 | - | n-empty "暂无白名单数据" | - |
| 236 | loadAllowlist | AntiAIDashboard.vue:536-545 | getAllowlistScenes() | GET /anti-ai/allowlist/scenes | AllowlistScene[] |

### E.6 教程弹窗

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 237 | 教程弹窗 | AntiAIDashboard.vue:298-304 | showTutorial | n-modal preset=card maxWidth=720px | - |
| 238 | 教程：这是什么 | AntiAIDashboard.vue:306-316 | - | "Anti-AI防御系统是工程化去AI味治理方案" | - |
| 239 | 教程：七层防御说明 | AntiAIDashboard.vue:318-343 | - | 7个tl-item: L1-L7详细说明 | - |
| 240 | 教程：如何使用 | AntiAIDashboard.vue:345-356 | - | 7步ol列表 | - |
| 241 | 教程：35+模式一览 | AntiAIDashboard.vue:358-371 | - | 8个pc-item分类: 微表情/声线/比喻/生理性/情绪标签/句式/俗套/严禁词 | - |
| 242 | 教程：注意事项 | AntiAIDashboard.vue:373-383 | - | 6条ul注意事项 | - |

### E.7 生命周期

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 243 | onMounted→3路加载 | AntiAIDashboard.vue:547-551 | - | loadStats + loadRules + loadAllowlist | - |
| 244 | loadStats | AntiAIDashboard.vue:517-523 | getAntiAIStats() | GET /anti-ai/stats, 静默失败 | AntiAIStats |

### E.8 数据模型（types/anti-ai.ts）

```typescript
interface ClicheHit { pattern: string; text: string; start: number; end: number; severity: 'critical'|'warning'|'info'; category: string; replacement_hint: string; }
interface ScanResult { total_hits, critical_hits, warning_hits, severity_score, overall_assessment, category_distribution, top_patterns, recommendations, improvement_suggestions, hits: ClicheHit[] }
interface PromptCategory { key, name, icon, description, color, sort_order, prompt_count }
interface AntiAIRule { key, anti_pattern, positive_action, category, severity }
interface AllowlistScene { scene_type, allowed_categories[], allowed_patterns[], max_density_per_1000, description }
interface AntiAIStats { total_prompts, anti_ai_prompts, categories_count, cliche_patterns, layers: {L1_positive_framing, L2_protocol_rules, L3_allowlist_scenes, L4_state_vector, L5_context_quota, L6_token_guard, L7_audit} }
const ASSESSMENT_COLORS: {纯净:#22c55e, 轻微:#84cc16, 中等:#f59e0b, 严重:#dc2626, 未检测:#6b7280}
const SCENE_TYPE_LABELS: {default:默认, battle:战斗, suspense:悬疑, horror:恐怖, confession:告白, revelation:揭秘/反转}
```

---

## F. 对话沙盒面板（DialogueCorpus.vue）

原版文件：`components/workbench/DialogueCorpus.vue`（311行）

| # | 原版功能点 | 原版文件:行号 | 调用链/API | 渲染/交互 | 数据模型 |
|---|-----------|--------------|-----------|-----------|----------|
| 245 | 头部：标题+副标题+刷新 | DialogueCorpus.vue:3-9 | - | n-text"对白语料" + n-text"正文自动抽取" + 刷新按钮 | - |
| 246 | 筛选：章节下拉 | DialogueCorpus.vue:13-20 | filterChapter | n-select clearable, options=chapterOptions | filterChapter: number\|null |
| 247 | 筛选：说话人下拉 | DialogueCorpus.vue:21-29 | filterSpeaker | n-select clearable filterable, options=speakerOptions | filterSpeaker: string |
| 248 | 筛选：搜索框 | DialogueCorpus.vue:30-36 | searchText | n-input clearable | searchText: string |
| 249 | 加载中状态 | DialogueCorpus.vue:41-43 | !result | n-empty "加载中..." | - |
| 250 | 空数据状态 | DialogueCorpus.vue:46-50 | result.total_count===0 | n-empty "暂无对话数据，生成章节后自动提取" | - |
| 251 | 无匹配状态 | DialogueCorpus.vue:51-55 | filteredDialogues.length===0 | n-empty "无匹配对话" | - |
| 252 | 对话列表 | DialogueCorpus.vue:56-71 | filteredDialogues v-for | dialogue-item: meta(章节tag+说话人tag) + content | DialogueEntry |
| 253 | 对话项：章节tag | DialogueCorpus.vue:66 | d.chapter | n-tag tiny round "第{chapter}章" | - |
| 254 | 对话项：说话人tag | DialogueCorpus.vue:67 | d.speaker | n-tag success tiny round | - |
| 255 | 对话项：内容 | DialogueCorpus.vue:69 | d.content | n-text dialogue-content | - |
| 256 | 角色高亮 | DialogueCorpus.vue:61-63, 155-159 | isCharacterDialogue(speaker) | dialogue-item--highlight, 选中角色的对话高亮 | resolvedSelectedCharacterName |
| 257 | 底部统计 | DialogueCorpus.vue:75-79 | filteredDialogues.length + result.total_count | "{filtered} / {total} 条对话" | - |
| 258 | chapterOptions | DialogueCorpus.vue:113-120 | result.dialogues去重chapter | computed | - |
| 259 | speakerOptions | DialogueCorpus.vue:123-130 | result.dialogues去重speaker | computed | - |
| 260 | filteredDialogues | DialogueCorpus.vue:133-153 | 章节筛选 + 说话人筛选 + 关键词搜索 | computed | - |
| 261 | load | DialogueCorpus.vue:183-196 | sandboxApi.getDialogueWhitelist(slug) | GET /novels/{id}/sandbox/dialogue-whitelist | DialogueWhitelistResponse |
| 262 | syncSelectionFromBible | DialogueCorpus.vue:161-181 | bibleApi.getBible(slug) → find character | 解析selectedCharacterId→name, 设filterSpeaker | - |
| 263 | deskChapterNumber→设filterChapter | DialogueCorpus.vue:198-203 | - | watch deskChapterNumber | - |
| 264 | slug→load | DialogueCorpus.vue:205-207 | - | watch immediate | - |
| 265 | [slug, selectedCharacterId]→sync | DialogueCorpus.vue:209-215 | - | watch immediate | - |
| 266 | useWorkbenchDeskTickReload→reload | DialogueCorpus.vue:217-220 | - | load + syncSelectionFromBible | - |
| 267 | defineExpose({load}) | DialogueCorpus.vue:222-224 | - | 供父组件调用 | - |

### ⚠️ 重要说明：DialogueCorpus.vue 只做语料筛选，不含生成器和anchor读写

原版 DialogueCorpus.vue **仅实现对话白名单的加载和筛选**。任务描述中的"生成器+anchor读写"实际由 `sandboxApi` 的其他方法提供（`getCharacterAnchor`/`patchCharacterAnchor`/`generateDialogue`），但这些方法在 DialogueCorpus.vue 中**未被调用**。它们可能在沙盒的父组件或其他子组件中使用。

iOS现有的 `DialogueSandboxPanel.swift` 已实现了对话生成（generateDialogue），但**缺少anchor读写（getCharacterAnchor + patchCharacterAnchor）**。

### 数据模型（sandbox.ts）

```typescript
interface DialogueEntry { dialogue_id: string; chapter: number; speaker: string; content: string; context: string; tags: string[]; }
interface DialogueWhitelistResponse { dialogues: DialogueEntry[]; total_count: number; }
interface CharacterAnchor { character_id: string; character_name: string; mental_state: string; verbal_tic: string; idle_behavior: string; }
interface GenerateDialogueRequest { novel_id: string; character_id: string; scene_prompt: string; mental_state?: string; verbal_tic?: string; idle_behavior?: string; }
interface GenerateDialogueResponse { dialogue: string; character_name: string; }
```

---

## G. API端点汇总（6面板全部）

| # | 面板 | 方法 | HTTP | 端点路径 | 请求体 | 响应 | 对齐原版行号 | iOS现状 |
|---|------|------|------|---------|--------|------|-------------|---------|
| G1 | 伏笔 | foreshadowApi.list | GET | `/novels/{novel_id}/foreshadow-ledger` | 无(?status可选) | ForeshadowEntry[] | foreshadow.ts:51-55 | ✅ 已建 APIEndpoint.Foreshadow.list |
| G2 | 伏笔 | foreshadowApi.get | GET | `/novels/{novel_id}/foreshadow-ledger/{entry_id}` | 无 | ForeshadowEntry | foreshadow.ts:57-58 | ✅ 已建 APIEndpoint.Foreshadow.get |
| G3 | 伏笔 | foreshadowApi.create | POST | `/novels/{novel_id}/foreshadow-ledger` | CreateForeshadowPayload | ForeshadowEntry | foreshadow.ts:60-61 | ✅ 已建 APIEndpoint.Foreshadow.create |
| G4 | 伏笔 | foreshadowApi.update | PUT | `/novels/{novel_id}/foreshadow-ledger/{entry_id}` | UpdateForeshadowPayload | ForeshadowEntry | foreshadow.ts:63-64 | ✅ 已建 APIEndpoint.Foreshadow.update |
| G5 | 伏笔 | foreshadowApi.remove | DELETE | `/novels/{novel_id}/foreshadow-ledger/{entry_id}` | 无 | void | foreshadow.ts:66-67 | ✅ 已建 APIEndpoint.Foreshadow.delete |
| G6 | 伏笔 | foreshadowApi.markConsumed | PUT | `/novels/{novel_id}/foreshadow-ledger/{entry_id}` | {status:'consumed', consumed_at_chapter} | ForeshadowEntry | foreshadow.ts:69-73 | ✅ 复用update |
| G7 | 道具 | propApi.list | GET | `/novels/{novel_id}/props` | 无 | PropDTO[] | propApi.ts:67-68 | ✅ 已建 APIEndpoint.Props.list |
| G8 | 道具 | propApi.create | POST | `/novels/{novel_id}/props` | Partial<PropDTO>&{name} | PropDTO | propApi.ts:70-71 | ✅ 已建 APIEndpoint.Props.create |
| G9 | 道具 | propApi.get | GET | `/novels/{novel_id}/props/{prop_id}` | 无 | PropDTO | propApi.ts:73-74 | ✅ 已建 APIEndpoint.Props.get |
| G10 | 道具 | propApi.patch | PATCH | `/novels/{novel_id}/props/{prop_id}` | Partial<PropDTO> | PropDTO | propApi.ts:76-77 | ✅ 已建 APIEndpoint.Props.update |
| G11 | 道具 | propApi.remove | DELETE | `/novels/{novel_id}/props/{prop_id}` | 无 | void | propApi.ts:79-80 | ✅ 已建 APIEndpoint.Props.delete |
| G12 | 道具 | propApi.listEvents | GET | `/novels/{novel_id}/props/{prop_id}/events` | 无 | PropEventDTO[] | propApi.ts:82-83 | ✅ 已建 APIEndpoint.Props.events |
| G13 | 道具 | propApi.createEvent | POST | `/novels/{novel_id}/props/{prop_id}/events` | {chapter_number, event_type, description, ...} | PropEventDTO | propApi.ts:85-86 | ✅ 已建 APIEndpoint.Props.createEvent |
| G14 | 道具 | manuscriptApi.listChapterMentions | GET | `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions` | 无 | {mentions: ChapterEntityMention[]} | manuscript.ts:31-34 | ❌ 需补建 |
| G15 | 道具 | manuscriptApi.reindexChapterMentions | POST | `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions/reindex` | {}(?content可选) | {ok, mentions} | manuscript.ts:36-46 | ❌ 需补建 |
| G16 | 道具 | bibleApi.listCharacters | GET | `/novels/{novel_id}/bible/characters` 或 `/bible/novels/{novel_id}/bible/characters` | 无 | Character[] | ManuscriptPropsPanel.vue:223 | ✅ 已建 APIEndpoint.Bible.characters |
| G17 | 演化 | narrativeEngineApi.getStoryEvolution | GET | `/novels/{novel_id}/narrative-engine/story-evolution` | 无 | StoryEvolutionReadModel | narrativeEngine.ts:85-88 | ❌ 需补建 |
| G18 | 演化 | evolutionApi.listSnapshots | GET | `/novels/{novel_id}/evolution/snapshots?branch_id=main` | 无 | EvolutionSnapshotList | evolution.ts:51-55 | ✅ 已建 APIEndpoint.Evolution.snapshots |
| G19 | 演化 | evolutionApi.applyOverrides | POST | `/novels/{novel_id}/evolution/snapshots/{chapter_number}/overrides` | {branch_id, patches} | EvolutionSnapshot | evolution.ts:69-73 | ✅ 已建 APIEndpoint.Evolution.snapshotOverrides |
| G20 | 演化 | evolutionApi.gate | POST | `/novels/{novel_id}/evolution/gate` | {chapter_number, branch_id, ...} | EvolutionGateReport | evolution.ts:57-67 | ✅ 已建 APIEndpoint.Evolution.gate |
| G21 | 演化 | evolutionApi.replayFrom | POST | `/novels/{novel_id}/evolution/replay-from/{chapter_number}` | {branch_id} | Record<string, unknown> | evolution.ts:75-79 | ✅ 已建 APIEndpoint.Evolution.replay |
| G22 | 演化 | getGovernanceState | GET | `/novels/{novel_id}/governance/state` | 无 | GovernanceStateDTO | governance.ts:69-71 | ✅ 已建 APIEndpoint.Governance.state |
| G23 | 演化 | worldlineApi.getGraph | GET | `/novels/{novel_id}/worldline/graph` | 无 | WorldlineGraph | worldline.ts:53-54 | ✅ 已建 APIEndpoint.Worldline.graph |
| G24 | 演化 | novelApi.getNovel | GET | `/novels/{novel_id}` | 无 | NovelDTO | StoryEvolutionPanel.vue:463 | ✅ 已建 (Novel enum) |
| G25 | 演化 | bibleApi.getBible | GET | `/bible/novels/{novel_id}/bible` | 无 | BibleDTO | StoryEvolutionPanel.vue:464 | ✅ 已建 APIEndpoint.Bible.get |
| G26 | 演化 | workflowApi.getPlotOutline | GET | `/novels/{novel_id}/workflow/plot-outline` (待确认) | 无 | {plot_outline: PlotOutlineDTO} | StoryEvolutionPanel.vue:465 | ⚠️ 需确认iOS是否有对应端点 |
| G27 | 编年史 | chroniclesApi.get | GET | `/novels/{novel_id}/chronicles` | 无 | ChroniclesResponse | chronicles.ts:43-44 | ✅ 已建 APIEndpoint.Chronicles.get |
| G28 | 编年史 | chroniclesApi.rollbackToSnapshot | POST | `/novels/{novel_id}/snapshots/{snapshot_id}/rollback` | 无 | SnapshotRollbackResponse | chronicles.ts:46-49 | ❌ 需补建 |
| G29 | AntiAI | scanChapter | POST | `/anti-ai/scan` | {content, chapter_id} | ScanResult | anti-ai.ts:21-26 | ✅ 已建 APIEndpoint.AntiAI.scan |
| G30 | AntiAI | getAntiAIStats | GET | `/anti-ai/stats` | 无 | AntiAIStats | anti-ai.ts:52-54 | ✅ 已建 APIEndpoint.AntiAI.stats |
| G31 | AntiAI | getRules | GET | `/anti-ai/rules` | 无 | AntiAIRule[] | anti-ai.ts:34-36 | ✅ 已建 APIEndpoint.AntiAI.rules |
| G32 | AntiAI | getAllowlistScenes | GET | `/anti-ai/allowlist/scenes` | 无 | AllowlistScene[] | anti-ai.ts:39-41 | ✅ 已建 APIEndpoint.AntiAI.allowlistScenes |
| G33 | AntiAI | getCategories | GET | `/anti-ai/categories` | 无 | PromptCategory[] | anti-ai.ts:29-31 | ✅ 已建 APIEndpoint.AntiAI.categories |
| G34 | AntiAI | updateAllowlist | POST | `/anti-ai/allowlist` | AllowlistUpdateRequest | {status, scene_type} | anti-ai.ts:44-49 | ✅ 已建 APIEndpoint.AntiAI.allowlist |
| G35 | 对话沙盒 | sandboxApi.getDialogueWhitelist | GET | `/novels/{novel_id}/sandbox/dialogue-whitelist` | 无(?chapter_number, ?speaker) | DialogueWhitelistResponse | sandbox.ts:46-55 | ✅ 已建 APIEndpoint.Sandbox.dialogueWhitelist |
| G36 | 对话沙盒 | sandboxApi.getCharacterAnchor | GET | `/novels/{novel_id}/sandbox/character/{character_id}/anchor` | 无 | CharacterAnchor | sandbox.ts:58-60 | ✅ 已建 APIEndpoint.Sandbox.characterAnchor |
| G37 | 对话沙盒 | sandboxApi.patchCharacterAnchor | PATCH | `/novels/{novel_id}/sandbox/character/{character_id}/anchor` | {mental_state, verbal_tic, idle_behavior} | CharacterAnchor | sandbox.ts:63-72 | ❌ 需补建 |
| G38 | 对话沙盒 | sandboxApi.generateDialogue | POST | `/novels/{novel_id}/sandbox/generate-dialogue` | GenerateDialogueRequest | GenerateDialogueResponse | sandbox.ts:75-77 | ✅ 已建 APIEndpoint.Sandbox.generateDialogue |

### 需补建API端点汇总（4个）

| # | 端点 | HTTP | 路径 | 用途 |
|---|------|------|------|------|
| 1 | NarrativeEngine.storyEvolution | GET | `/novels/{novel_id}/narrative-engine/story-evolution` | 演化面板司令塔数据聚合 |
| 2 | Chronicles.rollback | POST | `/novels/{novel_id}/snapshots/{snapshot_id}/rollback` | 编年史快照回滚 |
| 3 | Manuscript.chapterMentions | GET | `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions` | 道具面板本章实体索引 |
| 4 | Manuscript.reindexMentions | POST | `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions/reindex` | 道具面板从正文重建索引 |
| 5 | Sandbox.patchCharacterAnchor | PATCH | `/novels/{novel_id}/sandbox/character/{character_id}/anchor` | 对话沙盒anchor写入 |

---

## H. iOS现有基础核对

### H.1 伏笔面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| ForeshadowLedgerPanel.swift | ⚠️ 极简（67行）：仅列表+urgencySort，无创建/编辑/消费弹窗，无筛选条，无Tab，无优先级星标，无重要程度chip | **需大幅重写**：添加全部52个功能点 |
| ForeshadowStore.swift | ✅ 已有CRUD（loadEntries/createEntry/updateEntry/deleteEntry/markConsumed）+ pendingEntries/consumedEntries | ⚠️ 缺少togglePriority方法（需调update传is_priority_for_chapter） |
| ForeshadowModels.swift | ✅ 已有ForeshadowEntry + CreateForeshadowRequest + UpdateForeshadowRequest | ✅ 模型完整够用 |
| APIEndpoint.Foreshadow | ✅ 5个端点全有 | ✅ 无需新增 |
| importance映射 | ❌ 缺失 | **需新增**：FORESHADOW_IMPORTANCE_META等价（label/order/color/chipClass映射） |

### H.2 道具面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| PropManagerPanel.swift | ⚠️ 极简（92行）：仅列表+点击进入sheet，无创建/编辑modal，无数据表格列，无关键道具切换，无实体索引 | **需大幅重写**：添加表格列+CRUD modal+关键切换+实体索引 |
| PropDetailSheet(内联) | ⚠️ 简单List，无事件时间线n-timeline，无快速修复，无添加事件modal | **需替换为PropDetailDrawer等价View** |
| PropStore.swift | ✅ 已有CRUD + loadPropEvents + createPropEvent | ✅ Store基本够用 |
| PropModels.swift | ✅ 已有PropDTO + PropEventDTO + CreatePropRequest + PatchPropRequest + CreatePropEventRequest + PropCategory + PropLifecycleState枚举 | ✅ 模型完整够用 |
| APIEndpoint.Props | ✅ 7个端点全有 | ✅ 无需新增 |
| Manuscript端点 | ❌ 缺失 | **需新增**：chapterMentions + reindexMentions |
| LIFECYCLE_LABELS等映射 | ❌ 缺失 | **需新增**：生命周期/分类的中文标签+图标+颜色映射 |
| ChapterEntityMention模型 | ❌ 缺失 | **需新增** |

### H.3 演化面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| StoryEvolutionPanel.swift | ⚠️ 极简（60行）：仅快照列表+计数，无4个Tab，无司令塔，无状态机，无时间轴，无世界线 | **需大幅重写**：添加4 Tab + 全部command/state/timeline/worldline功能 |
| EvolutionStore.swift | ✅ 已有loadSnapshots + loadSnapshot + checkGate + applyOverrides + replay | ⚠️ 缺少loadBundle(loadStoryEvolution) + loadGovernanceState + loadWorldlineGraph + loadSetupAnchors |
| EvolutionModels.swift | ✅ 已有EvolutionSnapshot + EvolutionSnapshotListResponse + EvolutionGateRequest/Report + OverrideRequest + ReplayRequest | ⚠️ EvolutionSnapshot字段与原版差异大（iOS用snapshotData:AnyCodable，原版有opening_state/delta_actions/ending_state/conflicts等结构化字段） |
| APIEndpoint.Evolution | ✅ 5个端点全有 | ✅ 无需新增 |
| NarrativeEngine端点 | ❌ 缺失 | **需新增**：storyEvolution GET |
| GovernanceStore/Model | ✅ GovernanceModels.swift已有GovernanceState/Contract/Storyline/DebtRecord/Report/Budget | ⚠️ 字段名与原版不完全对齐（iOS用storylines/debts/reports，原版用canonical_storylines/open_debts/latest_report） |
| Worldline模型 | ❌ 缺失独立WorldlineGraph模型 | **需新增**：WorldlineGraph + CheckpointNode + BranchInfo（iOS有CheckpointDTO但字段不同） |
| StoryNavigator/StoryTimeline/StoryDetailPanel/WorldlineDAG子组件 | ⚠️ iOS有WorldlineDAGView.swift，无其他3个子组件 | **需新增或简化**：3个子组件的iOS等价View |

### H.4 编年史面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| ChroniclesPanel.swift | ⚠️ 极简（68行）：仅列表展示rows，无双螺旋布局，无Hover高亮，无回滚，无视图切换，无Timeline嵌入 | **需大幅重写**：添加双螺旋布局+回滚+视图切换 |
| ChronicleModels.swift | ✅ 已有ChronicleStoryEvent + ChronicleSnapshot + ChronicleRow + ChroniclesResponse | ✅ 模型完整够用 |
| APIEndpoint.Chronicles | ⚠️ 仅有get(novelId) | **需新增**：rollback(novelId, snapshotId) → POST /novels/{id}/snapshots/{snapshot_id}/rollback |
| SnapshotRollbackResponse模型 | ❌ 缺失 | **需新增** |
| TimelinePanel等价组件 | ❌ 缺失 | **需新增**（或简化为Bible时间线编辑View） |

### H.5 AntiAI面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| AntiAIPanel.swift | ⚠️ 极简（100行）：仅扫描按钮+结果展示（概要+违规短语+建议），无4个子Tab，无七层防御网格，无统计，无规则面板，无白名单面板，无教程 | **需大幅重写**：添加4 Tab + 七层防御 + 统计 + 规则 + 白名单 + 教程 |
| AntiAIModels.swift | ✅ 已有AntiAIScanRequest + AntiAIScanResult + AntiAIHit + AntiAICategoryInfo + AntiAIRuleInfo + AllowlistUpdateRequest + AntiAITrend | ⚠️ **缺AntiAIStats模型**（total_prompts/anti_ai_prompts/cliche_patterns/categories_count/layers）；**缺AllowlistScene模型**（scene_type/allowed_categories/allowed_patterns/max_density_per_1000/description） |
| AntiAIHit字段不匹配 | ⚠️ iOS: excerpt/suggestion/position；原版: text/replacement_hint/start/end | **需对齐**：添加text/replacement_hint/start/end字段 |
| APIEndpoint.AntiAI | ✅ 9个端点全有（scan/categories/rules/allowlist/allowlistScenes/stats/audits/chapterAudit/trend） | ✅ 无需新增 |
| ASSESSMENT_COLORS映射 | ❌ 缺失 | **需新增** |
| SCENE_TYPE_LABELS映射 | ❌ 缺失 | **需新增** |
| defenseLayers computed | ❌ 缺失 | **需新增**：7层防御定义 |
| AntiAIStore | ❌ 缺失 | **需新增**：loadStats/loadRules/loadAllowlist/scan方法 |

### H.6 对话沙盒面板

| 项目 | iOS现状 | T05需新增 |
|------|---------|----------|
| DialogueSandboxPanel.swift | ⚠️ 简单（99行）：有对话白名单(前5条)+AI生成。无章节/说话人/搜索筛选，无角色高亮，无anchor读写 | **需增强**：添加筛选+高亮+anchor读写 |
| SandboxModels.swift | ✅ 已有DialogueEntry + DialogueWhitelistResponse + CharacterAnchor + GenerateDialogueRequest + GenerateDialogueResponse | ⚠️ CharacterAnchor字段与原版不匹配（iOS: anchorTraits/verbalPatterns/behavioralNotes；原版: mental_state/verbal_tic/idle_behavior） |
| APIEndpoint.Sandbox | ⚠️ 有3个端点（dialogueWhitelist/characterAnchor GET/generateDialogue） | **需新增**：patchCharacterAnchor PATCH |
| DialogueCorpus等价View | ❌ 缺失独立语料筛选View | **需新增**（或增强现有DialogueSandboxPanel） |

---

## I. 疑问清单（上报主理人决策，不许自作主张）

### I.1 高优先级疑问

**疑问1：演化面板4个子组件（StoryNavigator/StoryTimeline/StoryDetailPanel/WorldlineDAG）是否需要全部移植？**
- 原版StoryEvolutionPanel.vue:324-359的时间轴Tab使用了3个子组件 + 1个WorldlineDAG。
- iOS已有WorldlineDAGView.swift，但StoryNavigator/StoryTimeline/StoryDetailPanel没有iOS等价物。
- 这些子组件本身可能很大（各自数百行），完整移植工作量巨大。
- **问题**：T05是否需要完整移植这4个子组件？还是时间轴Tab先做简化版（如直接展示快照列表+选中详情）？
- **寇豆码建议**：时间轴Tab先做简化版（列表+详情两栏），WorldlineDAG已有可复用。StoryNavigator/StoryTimeline/StoryDetailPanel标记为后续阶段完善。但司令塔和状态机两个Tab必须完整实现。

**疑问2：narrativeEngineApi.getStoryEvolution 返回的 StoryEvolutionReadModel 结构复杂，iOS如何处理？**
- 原版narrativeEngine.ts:9-38定义了StoryEvolutionReadModel，包含life_cycle/plot_spine/chronotope/chapters_digest/subtext_surface/evolution_surface等嵌套结构。
- 这个模型非常庞大，且很多字段是 `unknown[]` 或 `Record<string, unknown>`。
- **问题**：iOS是否需要完整建模StoryEvolutionReadModel？还是用AnyCodable/raw dict解析按需取值？
- **寇豆码建议**：用AnyCodable + 按需取值方式，因为原版TypeScript本身也大量使用unknown类型。只对实际使用的字段（chronotope.rows, evolution_surface.active_snapshot等）做结构化解析。

**疑问3：AntiAIHit 字段名不匹配 — iOS是 excerpt/suggestion/position，原版是 text/replacement_hint/start/end**
- iOS AntiAIModels.swift:67-88 的 AntiAIHit 用 excerpt/suggestion/position。
- 原版 types/anti-ai.ts:11-19 的 ClicheHit 用 text/replacement_hint/start/end。
- **问题**：这是后端API返回两种字段名？还是iOS T01建模时字段名写错了？
- **寇豆码建议**：需确认后端实际返回的字段名。如果后端返回的是text/replacement_hint/start/end，则iOS需要修改AntiAIHit字段名。如果后端返回excerpt/suggestion/position，则原版前端做了字段映射（但原版代码中未发现映射逻辑）。倾向于按原版ClicheHit对齐。

**疑问4：CharacterAnchor 字段名不匹配 — iOS vs 原版**
- 原版 sandbox.ts:22-28: `character_id, character_name, mental_state, verbal_tic, idle_behavior`
- iOS SandboxModels.swift:61-89: `characterId, name, anchorTraits, verbalPatterns, behavioralNotes, recentDialogueSamples`
- **问题**：后端API返回哪种字段名？iOS的CharacterAnchor模型是否需要重写对齐原版？
- **寇豆码建议**：按原版对齐，因为sandbox.ts直接从API返回类型声明，应该是后端原始字段名。iOS的CharacterAnchor需要修改字段名。

**疑问5：演化面板 EvolutionSnapshot 模型字段差异大**
- 原版 evolution.ts:3-19: 有 schema_version, status, opening_state, delta_actions, machine_state, human_override_patches, ending_state, source_refs, conflicts 等结构化字段。
- iOS EvolutionModels.swift:14-46: 用 `snapshotData: AnyCodable` (key="snapshot") + `violations: [AnyCodable]?`，字段结构完全不同。
- **问题**：iOS是否需要重写EvolutionSnapshot模型对齐原版？还是保持AnyCodable方式按需取值？
- **寇豆码建议**：状态机Tab需要结构化访问ending_state.characters/scene/delta_actions/conflicts，建议新增结构化字段或扩展模型。但考虑到T04教训11（自定义init会抑制memberwise init），需谨慎处理。

### I.2 中优先级疑问

**疑问6：GovernanceState 模型字段名差异**
- 原版 governance.ts:61-67: `contract, canonical_storylines, open_debts, latest_report, chapter_budget_preview`
- iOS GovernanceModels.swift:76-98: `contract, storylines, debts, reports`
- **问题**：iOS字段名与原版不匹配（storylines vs canonical_storylines, debts vs open_debts, reports vs latest_report）。需要修改吗？
- **寇豆码建议**：iOS用singleValueContainer+dict解析，字段名是Swift侧自定义的，不影响JSON解码。但语义上需要对齐（reports应该是latest_report单条而非列表）。

**疑问7：编年史 TimelinePanel 组件是否需要移植？**
- 原版HolographicChroniclesPanel.vue:97-99在timeline视图嵌入 `<TimelinePanel :slug="slug" />`。
- **问题**：iOS是否有TimelinePanel等价组件？如果没有，是否需要移植？
- **寇豆码建议**：需Grep确认iOS是否有Timeline相关View。如果没有，timeline视图先占位（显示"列表编辑模式待实现"），优先实现双螺旋视图。

**疑问8：workflowApi.getPlotOutline 端点路径**
- 原版StoryEvolutionPanel.vue:465调用 `workflowApi.getPlotOutline(props.slug)`，但未读workflow.ts确认具体路径。
- **问题**：iOS是否有对应的workflow/plot-outline端点？
- **寇豆码建议**：需确认。如果没有，loadSetupAnchors中的outline部分可降级为null（Promise.allSettled已处理失败）。

**疑问9：DialogueCorpus.vue 的 props.selectedCharacterId 从哪传入？**
- 原版DialogueCorpus.vue:92-96接收 `selectedCharacterId: string|null`，用于从Bible解析角色名并高亮。
- **问题**：iOS的DialogueSandboxPanel目前没有selectedCharacterId概念。这个值是从角色选择器传入的。
- **寇豆码建议**：iOS需要在对话沙盒面板中增加角色选择器（或从Bible角色列表选择），将选中的characterId传入语料筛选组件。

**疑问10：workbenchRefreshStore 的 foreshadowTick/deskTick/chroniclesTick 在iOS如何对应？**
- 原版多个面板watch workbenchRefreshStore的tick值实现跨面板刷新联动。
- **问题**：iOS是否有类似的刷新通知机制？
- **寇豆码建议**：iOS可用NotificationCenter或AppState的Published属性实现类似机制。需确认iOS现有架构。

### I.3 低优先级疑问

**疑问11：AntiAIDashboard.vue 使用 fetchJson 而非 apiClient**
- 原版anti-ai.ts:12-18使用独立的 `fetchJson` HTTP工具，API_BASE='/api/v1/anti-ai'。
- 其他面板使用 `apiClient`（api/config.ts）。
- **问题**：iOS的APIClient是否统一处理？还是AntiAI需要特殊处理？
- **寇豆码建议**：iOS统一用APIClient.shared.request即可，APIEndpoint已定义好路径。fetchJson和apiClient只是前端HTTP工具差异，后端API一致。

**疑问12：PropDetailDrawer 的 emit('updated') 和 emit('close') 在iOS如何对应？**
- 原版PropDetailDrawer.vue:76定义 `emit: { close: [], updated: [] }`。
- **问题**：iOS的sheet/dismiss机制如何传递"已更新"事件？
- **寇豆码建议**：iOS用@Environment(\.dismiss)关闭sheet，用ObservableObject的objectWillChange或回调闭包传递更新事件。

---

## J. 功能对齐度自报

### 原版功能点统计

| 模块 | 原版功能点数量 | 事实表覆盖数量 | 覆盖率 |
|------|--------------|--------------|--------|
| A. 伏笔面板 | 52条 | 52条 | 100% |
| B. 道具面板（主+抽屉） | 61条 | 61条 | 100% |
| C. 演化面板 | 57条 | 57条 | 100% |
| D. 编年史面板 | 22条 | 22条 | 100% |
| E. AntiAI面板 | 52条 | 52条 | 100% |
| F. 对话沙盒面板 | 23条 | 23条 | 100% |
| G. API端点汇总 | 38条 | 38条 | 100% |
| **合计** | **305条** | **305条** | **100%** |

### iOS现有基础覆盖度

| 面板 | Store现状 | Models现状 | APIEndpoint现状 | T05需新增/重写 |
|------|----------|-----------|----------------|---------------|
| 伏笔 | ✅ CRUD全有，缺togglePriority | ✅ 模型完整 | ✅ 5/5端点 | Panel需大幅重写(52功能点)；新增importance映射 |
| 道具 | ✅ CRUD+事件全有 | ✅ 模型完整 | ⚠️ 7/9端点(缺Manuscript 2个) | Panel需大幅重写；新增PropDetailDrawer；补2个Manuscript端点 |
| 演化 | ⚠️ 有基础方法，缺4路加载 | ⚠️ 字段差异大 | ⚠️ 5/6端点(缺NarrativeEngine) | Panel需大幅重写(4 Tab)；补NarrativeEngine端点；新增多个子View |
| 编年史 | ❌ 无Store(直接API调用) | ✅ 模型完整 | ⚠️ 1/2端点(缺rollback) | Panel需大幅重写(双螺旋+回滚)；补rollback端点 |
| AntiAI | ❌ 无Store | ⚠️ 缺Stats+AllowlistScene模型，Hit字段不匹配 | ✅ 9/9端点 | Panel需大幅重写(4 Tab+7层防御)；补2个模型；新增Store |
| 对话沙盒 | ❌ 无Store(直接API调用) | ⚠️ CharacterAnchor字段不匹配 | ⚠️ 3/4端点(缺PATCH anchor) | Panel需增强(筛选+高亮+anchor读写)；补PATCH端点 |

### 需补建API端点：5个
1. `NarrativeEngine.storyEvolution` — GET `/novels/{novel_id}/narrative-engine/story-evolution`
2. `Chronicles.rollback` — POST `/novels/{novel_id}/snapshots/{snapshot_id}/rollback`
3. `Manuscript.chapterMentions` — GET `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions`
4. `Manuscript.reindexMentions` — POST `/novels/{novel_id}/chapters/{chapter_number}/entity-mentions/reindex`
5. `Sandbox.patchCharacterAnchor` — PATCH `/novels/{novel_id}/sandbox/character/{character_id}/anchor`

### 待确认疑问数

| 优先级 | 数量 |
|--------|------|
| 高优先级 | 5条 |
| 中优先级 | 5条 |
| 低优先级 | 2条 |
| **合计** | **12条** |

---

## K. 附录：原版文件读取清单

| # | 原版文件 | 路径 | 行数 | 读取状态 |
|---|---------|------|------|---------|
| 1 | ForeshadowLedgerPanel.vue | components/workbench/ | 519 | ✅ 完整读取 |
| 2 | ManuscriptPropsPanel.vue | components/workbench/ | 567 | ✅ 完整读取 |
| 3 | PropDetailDrawer.vue | components/workbench/ | 146 | ✅ 完整读取 |
| 4 | StoryEvolutionPanel.vue | components/workbench/ | 1362 | ✅ 完整读取 |
| 5 | HolographicChroniclesPanel.vue | components/workbench/ | 489 | ✅ 完整读取 |
| 6 | AntiAIDashboard.vue | components/workbench/promptPlaza/ | 1043 | ✅ 完整读取 |
| 7 | DialogueCorpus.vue | components/workbench/ | 311 | ✅ 完整读取 |
| 8 | foreshadow.ts | api/ | 75 | ✅ 完整读取 |
| 9 | propApi.ts | api/ | 88 | ✅ 完整读取 |
| 10 | evolution.ts | api/ | 81 | ✅ 完整读取 |
| 11 | chronicles.ts | api/ | 51 | ✅ 完整读取 |
| 12 | anti-ai.ts | api/ | 55 | ✅ 完整读取 |
| 13 | sandbox.ts | api/ | 79 | ✅ 完整读取 |
| 14 | governance.ts | api/ | 100 | ✅ 完整读取 |
| 15 | narrativeEngine.ts | api/ | 96 | ✅ 完整读取 |
| 16 | worldline.ts | api/ | 116 | ✅ 完整读取 |
| 17 | manuscript.ts | api/ | 48 | ✅ 完整读取 |
| 18 | anti-ai.ts | types/ | 118 | ✅ 完整读取 |
| 19 | foreshadow.ts | domain/ | 87 | ✅ 完整读取 |

### iOS文件读取清单

| # | iOS文件 | 路径 | 行数 | 读取状态 |
|---|---------|------|------|---------|
| 1 | ForeshadowLedgerPanel.swift | Views/Panels/ | 67 | ✅ 完整读取 |
| 2 | PropManagerPanel.swift | Views/Panels/ | 92 | ✅ 完整读取 |
| 3 | StoryEvolutionPanel.swift | Views/Panels/ | 60 | ✅ 完整读取 |
| 4 | ChroniclesPanel.swift | Views/Panels/ | 68 | ✅ 完整读取 |
| 5 | AntiAIPanel.swift | Views/Panels/ | 100 | ✅ 完整读取 |
| 6 | DialogueSandboxPanel.swift | Views/Panels/ | 99 | ✅ 完整读取 |
| 7 | ForeshadowStore.swift | ViewModels/ | 108 | ✅ 完整读取 |
| 8 | PropStore.swift | ViewModels/ | 102 | ✅ 完整读取 |
| 9 | EvolutionStore.swift | ViewModels/ | 110 | ✅ 完整读取 |
| 10 | ForeshadowModels.swift | Models/ | 99 | ✅ 完整读取 |
| 11 | PropModels.swift | Models/ | 190 | ✅ 完整读取 |
| 12 | AntiAIModels.swift | Models/ | 204 | ✅ 完整读取 |
| 13 | EvolutionModels.swift | Models/ | 153 | ✅ 完整读取 |
| 14 | ChronicleModels.swift | Models/ | 120 | ✅ 完整读取 |
| 15 | SandboxModels.swift | Models/ | 161 | ✅ 完整读取 |
| 16 | GovernanceModels.swift | Models/ | 258 | ✅ 完整读取 |
| 17 | APIEndpoint.swift | Networking/ | ~1500+ | ✅ Grep+分段读取相关enum |

---

*事实表结束。等待主理人确认后进入实现阶段。*
