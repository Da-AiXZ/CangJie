# T05 QA独立验收报告

> QA工程师：严过关（Yan）
> 验收日期：2026-06-24
> 验收方法：独立读代码逐条对照事实表305条功能点，不rubber-stamp工程师自报

## 验收结论

- **IS_PASS: NO**
- **功能对齐度：~285/305（93.4%）**，非工程师自报的305/305
- **12条决策执行：11/12**（决策8部分违反——路径正确但loadSetupAnchors未实现导致plot-outline端点从未被调用）
- **3个已知风险：3/3 已解决**（均无编译风险）
- **智能路由判定：源码砍功能 → Engineer返工**

---

## 逐条验收（按事实表6模块+API端点）

### A. 伏笔面板（52条）— 对齐 ForeshadowLedgerPanel.vue:1-519

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 1 | 面板标题"伏笔账本" (:8) | PASS | ForeshadowLedgerPanel.swift:160 | - |
| 2 | 待兑现计数chip (:9) | PASS | ForeshadowLedgerPanel.swift:161-168 | - |
| 3 | 已消费计数chip (:10) | PASS | ForeshadowLedgerPanel.swift:169-176 | - |
| 4 | 帮助tooltip (:11-18) | **MISSING** | - | 砍了，无帮助tooltip按钮 |
| 5 | "+ 添加"按钮 (:22) | PASS | ForeshadowLedgerPanel.swift:178-183 | - |
| 6 | 刷新按钮 (:23-30) | PASS | ForeshadowLedgerPanel.swift:184-192 | - |
| 7 | 筛选"全部" (:36-40) | PASS | ForeshadowLedgerPanel.swift:200 | - |
| 8 | 筛选"本章到期" (:41-46) | PASS | ForeshadowLedgerPanel.swift:201-203 | - |
| 9 | 筛选角色下拉 (:47-56) | PASS | ForeshadowLedgerPanel.swift:204-218 | - |
| 10 | Tab"待兑现"+badge (:62-65) | PASS | ForeshadowLedgerPanel.swift:238-241 | - |
| 11 | Tab"已消费" (:66) | PASS | ForeshadowLedgerPanel.swift:241 | - |
| 12 | 首次加载骨架屏 (:74-78) | PASS | ForeshadowLedgerPanel.swift:276-282 | - |
| 13 | 待兑现空状态 (:84-88) | PASS | ForeshadowLedgerPanel.swift:284-286 | - |
| 14 | 待兑现卡片容器 (:89-98) | PASS | ForeshadowLedgerPanel.swift:322-414 | - |
| 15 | 重要程度chip (:101-103) | PASS | ForeshadowLedgerPanel.swift:327-332 | - |
| 16 | 疑问文本 (:104) | PASS | ForeshadowLedgerPanel.swift:333-336 | - |
| 17 | 优先级星标按钮 (:105-112) | PASS | ForeshadowLedgerPanel.swift:338-350 | - |
| 18 | 章节chip (:116) | PASS | ForeshadowLedgerPanel.swift:354-359 | - |
| 19 | 角色chip (:117) | PASS | ForeshadowLedgerPanel.swift:360-367 | - |
| 20 | 兑现提示 (:118-120) | PASS | ForeshadowLedgerPanel.swift:368-372 | - |
| 21 | 消费按钮(✓) (:122-127) | PASS | ForeshadowLedgerPanel.swift:374-382 | - |
| 22 | 编辑按钮 (:128) | PASS | ForeshadowLedgerPanel.swift:384-388 | - |
| 23 | 删除按钮+确认 (:129-134) | **SIMPLIFIED** | ForeshadowLedgerPanel.swift:390-399 | 原版n-popconfirm确认弹窗，iOS直接删除无确认 |
| 24 | 已消费空状态 (:143-146) | PASS | ForeshadowLedgerPanel.swift:292-294 | - |
| 25 | 已消费卡片 (:147-163) | PASS | ForeshadowLedgerPanel.swift:417-448 | - |
| 26 | ✓已消费chip+疑问 (:153-155) | PASS | ForeshadowLedgerPanel.swift:419-429 | - |
| 27 | 埋/兑现章节 (:157-161) | PASS | ForeshadowLedgerPanel.swift:431-443 | - |
| 28 | 创建/编辑modal (:169-202) | PASS | ForeshadowLedgerPanel.swift:451-501 | - |
| 29 | 表单疑问textarea (:172-178) | PASS | ForeshadowLedgerPanel.swift:456-459 | - |
| 30 | 表单关联角色 (:180-182) | PASS | ForeshadowLedgerPanel.swift:462-464 | - |
| 31 | 表单埋入章节 (:183-185) | PASS | ForeshadowLedgerPanel.swift:466-471 | - |
| 32 | 表单重要程度 (:186-188) | PASS | ForeshadowLedgerPanel.swift:472-476 | - |
| 33 | 表单预计兑现章 (:189-191) | PASS | ForeshadowLedgerPanel.swift:477-486 | - |
| 34 | 校验疑问必填 (:340) | PASS | ForeshadowLedgerPanel.swift:497 | - |
| 35 | 校验角色必填 (:341) | PASS | ForeshadowLedgerPanel.swift:497 | - |
| 36 | 提交编辑→update (:344-351) | PASS | ForeshadowLedgerPanel.swift:526-534 | - |
| 37 | 提交新建→create (:353-361) | PASS | ForeshadowLedgerPanel.swift:536-543 | - |
| 38 | 提交后reload (:365) | PASS | ForeshadowLedgerPanel.swift:547 | - |
| 39 | 消费弹窗 (:205-217) | PASS | ForeshadowLedgerPanel.swift:551-572 | - |
| 40 | 消费章节输入 (:207-209) | PASS | ForeshadowLedgerPanel.swift:554-556 | - |
| 41 | 消费确认→markConsumed (:384-397) | PASS | ForeshadowLedgerPanel.swift:574-583 | - |
| 42 | markConsumed默认章号 (:380) | PASS | ForeshadowLedgerPanel.swift:376 | - |
| 43 | load列表 (:291-308) | PASS | ForeshadowStore.swift:27-38 | - |
| 44 | togglePriority (:400-412) | PASS | ForeshadowStore.swift:101-109 | - |
| 45 | remove删除 (:414-422) | PASS | ForeshadowStore.swift:72-79 | - |
| 46 | filteredPending排序 (:268-282) | PASS | ForeshadowLedgerPanel.swift:106-123 | - |
| 47 | due筛选 (:270-273) | PASS | ForeshadowLedgerPanel.swift:108-112 | - |
| 48 | char筛选 (:274-276) | PASS | ForeshadowLedgerPanel.swift:113-116 | - |
| 49 | onMounted→load (:427) | PASS | ForeshadowLedgerPanel.swift:133-138 | - |
| 50 | pendingCount→emit (:428) | PASS | ForeshadowLedgerPanel.swift:161-168 (chip显示) | - |
| 51 | foreshadowTick→reload (:429) | PASS | ForeshadowLedgerPanel.swift:139-143 | - |
| 52 | slug→reload (:430) | PASS | ForeshadowLedgerPanel.swift:144-148 | - |

**A模块小结：50/52 PASS，2项缺失/简化（#4帮助tooltip缺失，#23删除无确认弹窗）**

### B. 道具面板（61条）— 对齐 ManuscriptPropsPanel.vue + PropDetailDrawer.vue

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 53 | 面板标题"手稿道具" (:7) | PASS | PropManagerPanel.swift:133 | - |
| 54 | "+ 新建"按钮 (:9) | PASS | PropManagerPanel.swift:135-139 | - |
| 55 | 用法提示折叠面板 (:13-28) | **MISSING** | - | 砍了，无`[[prop:道具ID\|显示名]]`语法说明折叠面板 |
| 56 | 实体索引header (:34-49) | PASS | PropManagerPanel.swift:146-179 | - |
| 57 | 实体刷新按钮 (:43) | PASS | PropManagerPanel.swift:154-161 | - |
| 58 | 实体reindex下拉 (:44-47) | PASS | PropManagerPanel.swift:164-178 | - |
| 59 | 实体标签云 (:54-68) | PASS | PropManagerPanel.swift:184-188 | - |
| 60 | 实体kind标签 (:61) | PASS | PropManagerPanel.swift:207-213 (entityColor) | - |
| 61 | 实体kind中文 (:66) | PASS | ManuscriptModels.swift:77-85 (EntityKindHelper) | - |
| 62 | 实体空提示 (:51-53) | PASS | PropManagerPanel.swift:180-182 | - |
| 63 | 道具库header (:73-82) | PASS | PropManagerPanel.swift:220-229 | - |
| 64 | 道具库骨架屏 (:84-86) | **MISSING** | - | 砍了，无骨架屏加载占位 |
| 65 | 道具库空状态 (:88-92) | PASS | PropManagerPanel.swift:231-242 | - |
| 66 | 道具数据表 (:93-100) | PASS | PropManagerPanel.swift:244-247 (列表代替表格，功能等价) | - |
| 67 | 表格列名称 (:398-403) | PASS | PropManagerPanel.swift:258-259 | - |
| 68 | 表格列简述 (:404-411) | PASS | PropManagerPanel.swift:274-276 | - |
| 69 | 表格列持有者 (:412-422) | PASS | PropManagerPanel.swift:278-280 | - |
| 70 | 表格列类型(关键/普通) (:423-446) | PASS | PropManagerPanel.swift:265-272, 287-298 | - |
| 71 | 表格列操作 (:447-461) | PASS | PropManagerPanel.swift:300-311 | - |
| 72 | 关键道具切换 (:374-394) | PASS | PropStore.swift:140-149 | - |
| 73 | 创建/编辑modal (:108-155) | PASS | PropManagerPanel.swift:326-376 | - |
| 74 | 表单名称 (:115-117) | PASS | PropManagerPanel.swift:330 | - |
| 75 | 表单简述 (:118-124) | PASS | PropManagerPanel.swift:331-335 | - |
| 76 | 表单别名 (:125-127) | PASS | PropManagerPanel.swift:336-339 | - |
| 77 | 表单分类 (:128-130) | PASS | PropManagerPanel.swift:341-345 | - |
| 78 | 表单持有者 (:131-139) | PASS | PropManagerPanel.swift:346-351 | - |
| 79 | 表单登场章 (:140-147) | PASS | PropManagerPanel.swift:352-361 | - |
| 80 | 校验名称必填 (:323) | PASS | PropManagerPanel.swift:372 | - |
| 81 | 提交编辑→patch (:327-335) | PASS | PropManagerPanel.swift:408-416 | - |
| 82 | 提交新建→create (:337-345) | PASS | PropManagerPanel.swift:418-427 | - |
| 83 | 提交后reload (:349) | PASS | PropManagerPanel.swift:429 | - |
| 84 | loadCharOptions (:220-228) | PASS | PropManagerPanel.swift:432-441 | - |
| 85 | loadProps (:230-248) | PASS | PropStore.swift:28-39 | - |
| 86 | loadMentions (:250-266) | PASS | PropStore.swift:109-118 | - |
| 87 | runReindex (:268-281) | PASS | PropStore.swift:124-133 | - |
| 88 | onMounted→3路加载 (:465-469) | PASS | PropManagerPanel.swift:93-97 | - |
| 89 | slug/chapter/deskTick→reload (:471-477) | PASS | PropManagerPanel.swift:98-107 | - |
| 90 | slug→reload charOptions (:479) | PASS | PropManagerPanel.swift:103-107 | - |
| 91-113 | PropDetailDrawer全部23条 | PASS | PropDetailDrawer.swift:1-216 | 全部实现，含生命周期/分类/描述/持有者/快速修复/事件时间线/添加事件/来源标签/onUpdated闭包 |

**B模块小结：59/61 PASS，2项缺失（#55用法提示折叠面板，#64骨架屏）**

### C. 演化面板（57条）— 对齐 StoryEvolutionPanel.vue:1-1362

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 114 | Banner头部 (:4-17) | PASS | StoryEvolutionPanel.swift:88-91 | - |
| 115 | Tab按钮组4个 (:19-48) | PASS | StoryEvolutionPanel.swift:19-24, 50-70 | - |
| 116 | "角色档案"按钮 (:49) | **MISSING** | - | 砍了，无"角色档案"按钮（原版dispatchEvent打开sandbox面板） |
| 117 | Hero区域Narrative Ops (:63-69) | PASS | StoryEvolutionPanel.swift:89-112 | - |
| 118 | Hero承诺命中率 (:71-77) | **BUG** | StoryEvolutionPanel.swift:93-98 | 用`report.budget as? Double`代替`latest_report.promise_hit_rate`，GovernanceReport模型缺promise_hit_rate字段 |
| 119 | Hero状态快照 (:78-82) | PASS | StoryEvolutionPanel.swift:101-108 | - |
| 120 | Hero世界线 (:83-87) | **MISSING** | - | 砍了，Hero区域无世界线摘要（分支数/存档数） |
| 121 | 引导落点区域 (:90-112) | **SIMPLIFIED** | StoryEvolutionPanel.swift:134-158 | 原版setupAnchorRows有12种锚点类型，iOS仅显示storylines+chronotope摘要 |
| 122 | 引导落点：类型世界基调 (:536-544) | **MISSING** | - | 砍了，需novel.locked_genre + locked_world_preset |
| 123 | 引导落点：初始粗纲 (:546-554) | **MISSING** | - | 砍了，需novel.premise |
| 124 | 引导落点：故事骨架节奏 (:556-564) | **MISSING** | - | 砍了，需novel.locked_story_structure |
| 125 | 引导落点：主线总纲 (:566-574) | **MISSING** | - | 砍了，需outline.main_story_overview |
| 126 | 引导落点：核心冲突 (:576-584) | **MISSING** | - | 砍了，需outline.core_conflict |
| 127 | 引导落点：结局走向 (:586-594) | **MISSING** | - | 砍了，需outline.expected_ending |
| 128 | 引导落点：核心人物 (:596-610) | **MISSING** | - | 砍了，需bible.characters |
| 129 | 引导落点：世界观落点 (:612-626) | **MISSING** | - | 砍了，需bible.world_settings |
| 130 | 引导落点：关键地点 (:628-642) | **MISSING** | - | 砍了，需bible.locations |
| 131 | 引导落点：文风公约 (:644-653) | **MISSING** | - | 砍了，需bible.style + novel.locked_writing_style |
| 132 | 引导落点：特殊要求 (:655-663) | **MISSING** | - | 砍了，需novel.locked_special_requirements |
| 133 | 自动写前约束面板 (:115-137) | **MISSING** | - | 砍了，GovernanceState模型缺chapter_budget_preview字段，无预算/承诺标签展示 |
| 134 | 叙事治理面板 (:139-156) | **SIMPLIFIED** | StoryEvolutionPanel.swift:160-176 | 仅显示storylines+debts，缺governanceIssues列表展示 |
| 135 | 状态连续性面板 (:158-174) | **MISSING** | - | 砍了，无evidenceRows展示 |
| 136 | 世界线面板简要 (:176-198) | **MISSING** | - | 砍了，commandTab无世界线检查点/分支/HEAD计数 |
| 137 | 风险与修复队列 (:201-222) | **SIMPLIFIED** | StoryEvolutionPanel.swift:178-195 | 仅显示conflicts，缺combinedRisks（governance issues + conflicts合并） |
| 138 | 状态树列 (:226-272) | PASS | StoryEvolutionPanel.swift:198-263 | - |
| 139 | 状态摘要网格 (:238-255) | PASS | StoryEvolutionPanel.swift:202-209 | - |
| 140 | 角色状态列表 (:256-270) | PASS | StoryEvolutionPanel.swift:215-230 | - |
| 141 | 角色状态修改 (:262-268) | **SIMPLIFIED** | StoryEvolutionPanel.swift:248-255 | 原版有n-dropdown改角色状态+JSON Patch，iOS仅有"应用覆盖"按钮且patches为空数组 |
| 142 | 状态流列 (:274-295) | PASS | StoryEvolutionPanel.swift:234-243 | - |
| 143 | 证据列 (:297-311) | **SIMPLIFIED** | - | 状态机Tab无独立证据列，证据信息散布在其他区域 |
| 144 | 时间轴n-split布局 (:315-359) | PASS | StoryEvolutionPanel.swift:273-315 | - |
| 145 | StoryNavigator子组件 (:324-330) | PASS | StoryNavigatorView.swift:1-204 | - |
| 146 | StoryTimeline子组件 (:338-346) | PASS | StoryTimelineView.swift:1-200 | - |
| 147 | StoryDetailPanel子组件 (:351-355) | PASS | StoryDetailPanelView.swift:1-191 | - |
| 148 | 世界线Tab (:54-59) | PASS | StoryEvolutionPanel.swift:318-320 | - |
| 149 | loadBundle (:419-429) | PASS | EvolutionStore.swift:123-131 | - |
| 150 | loadEvolutionSnapshots (:431-441) | PASS | EvolutionStore.swift:37-52 | - |
| 151 | loadGovernanceState (:443-449) | PASS | EvolutionStore.swift:135-143 | - |
| 152 | loadWorldlineGraph (:451-457) | PASS | EvolutionStore.swift:147-156 | - |
| 153 | loadSetupAnchors (:459-473) | **MISSING** | - | **砍了**，EvolutionStore.loadAll仅4路加载，缺第5路Promise.allSettled([getNovel, getBible, getPlotOutline]) |
| 154 | updateCharacterStatus (:479-495) | **SIMPLIFIED** | EvolutionStore.swift:92-102 | applyOverrides存在但chapterNumber硬编码为0，patches为空 |
| 155 | escapeJsonPointer (:475-477) | **MISSING** | - | 砍了，因角色状态修改未完整实现 |
| 156 | onSelectStoryline (:769-774) | PASS | StoryEvolutionPanel.swift:280-282 | - |
| 157 | onSelectEvent (:777-779) | PASS | StoryEvolutionPanel.swift:292-293 | - |
| 158 | onSelectSnapshot (:782-784) | PASS | StoryEvolutionPanel.swift:294-295 | - |
| 159 | onCheckpointRestored (:787-793) | PASS | StoryDetailPanelView.swift:178-189 (performRollback+onRefresh) | - |
| 160 | slug watch→5路reload (:746-758) | **SIMPLIFIED** | EvolutionStore.swift:160-166 | 仅4路（缺loadSetupAnchors第5路） |
| 161 | useWorkbenchPlotTimelineReload→5路 (:760-766) | PASS | StoryEvolutionPanel.swift:37-41 (deskTick→loadAll) | - |
| 162-170 | 计算属性 | PASS | 分散在各View中 | 大部分通过computed property实现 |

**C模块小结：~41/57 PASS，16项缺失/简化（核心问题集中在司令塔Tab的引导落点和治理面板）**

### D. 编年史面板（22条）— 对齐 HolographicChroniclesPanel.vue:1-489

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 171 | 头部标题+说明+刷新 (:3-12) | PASS | ChroniclesPanel.swift:42-59 | - |
| 172 | 说明文案 (:6-9) | PASS | ChroniclesPanel.swift:46-47 | - |
| 173 | Note提示条 (:14-16) | **MISSING** | - | 砍了，API返回的note字段未在UI显示 |
| 174 | 视图切换 (:18-21) | PASS | ChroniclesPanel.swift:62-72 | - |
| 175 | Helix空状态 (:25-31) | PASS | ChroniclesPanel.swift:112-119 | - |
| 176 | Helix表头 (:34-38) | PASS | ChroniclesPanel.swift:93-101 | - |
| 177 | Helix章节锚点 (:46-49) | PASS | ChroniclesPanel.swift:128-136 | - |
| 178 | Helix剧情事件 (:51-62) | PASS | ChroniclesPanel.swift:139-158 | - |
| 179 | Helix快照节点 (:64-88) | PASS | ChroniclesPanel.swift:163-189 | - |
| 180 | Hover高亮 (:44,70-71) | PASS | ChroniclesPanel.swift:125, 195 | - |
| 181 | 智能离开 (:136-141) | N/A | - | 触摸界面不适用 |
| 182 | snapTooltip (:130-133) | PASS | ChroniclesPanel.swift:167-174 | - |
| 183 | 回滚按钮 (:77-85) | PASS | ChroniclesPanel.swift:176-184 | - |
| 184 | 回滚确认对话框 (:143-165) | PASS | ChroniclesPanel.swift:196-205 | - |
| 185 | 回滚API调用 (:152-153) | PASS | ChroniclesPanel.swift:213-214 | - |
| 186 | 回滚成功消息 (:154) | PASS | ChroniclesPanel.swift:216 | - |
| 187 | 回滚后刷新 (:155-156) | PASS | ChroniclesPanel.swift:217-218 | - |
| 188 | 轴底footer (:91-93) | PASS | ChroniclesPanel.swift:108-109 | - |
| 189 | Timeline视图 (:97-99) | PASS | ChroniclesPanel.swift:77-84 (TimelinePanel) | - |
| 190 | load (:167-181) | PASS | ChroniclesPanel.swift:229-236 | - |
| 191 | slug→load (:183) | PASS | ChroniclesPanel.swift:31-33 | - |
| 192 | chroniclesTick→load (:185-187) | PASS | ChroniclesPanel.swift:28-30 | - |

**D模块小结：21/22 PASS，1项缺失（#173 Note提示条未显示）**

### E. AntiAI面板（52条）— 对齐 AntiAIDashboard.vue:1-1043

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 193 | 头部标题+副标题 (:4-8) | PASS | AntiAIPanel.swift:53-65 | - |
| 194 | 使用教程按钮 (:10-13) | PASS | AntiAIPanel.swift:61-62 | - |
| 195 | 子标签页4个 (:17-27) | PASS | AntiAIPanel.swift:19-24, 68-92 | - |
| 196 | 七层防御网格 (:34-53) | PASS | AntiAIPanel.swift:96-103, 127-138 | - |
| 197-203 | L1-L7七层 (:427-482) | PASS | AntiAIPanel.swift:130-137 | 7层全部实现，active状态动态/硬编码对齐原版 |
| 204 | 系统统计区 (:56-76) | PASS | AntiAIPanel.swift:106-114 | - |
| 205-208 | 统计4项 (:60-71) | PASS | AntiAIPanel.swift:109-112 | - |
| 209 | 扫描文本输入 (:85-91) | PASS | AntiAIPanel.swift:176-178 | - |
| 210 | 扫描按钮 (:93-100) | PASS | AntiAIPanel.swift:181-189 | - |
| 211 | 清空按钮 (:101-103) | PASS | AntiAIPanel.swift:191-194 | - |
| 212 | 总评 (:108-111) | PASS | AntiAIPanel.swift:208-210 | - |
| 213 | 严重性分数 (:112-114) | PASS | AntiAIPanel.swift:211-212 | - |
| 214 | 统计3项 (:117-130) | PASS | AntiAIPanel.swift:216-219 | - |
| 215 | 分类分布 (:133-151) | PASS | AntiAIPanel.swift:223-241 | - |
| 216 | 改进建议 (:154-163) | PASS | AntiAIPanel.swift:244-252 | - |
| 217 | 修改建议 (:166-175) | PASS | AntiAIPanel.swift:255-263 | - |
| 218 | 命中详情 (:178-196) | PASS | AntiAIPanel.swift:266-291 | - |
| 219 | 超30条提示 (:193-195) | PASS | AntiAIPanel.swift:292-296 | - |
| 220 | handleScan (:492-502) | PASS | AntiAIStore.swift:46-57 | - |
| 221 | assessmentColor (:486-489) | PASS | AntiAIModels.swift:206-208 | - |
| 222 | severityTagType (:504-511) | PASS | AntiAIPanel.swift:309-316 | - |
| 223 | 规则说明文案 (:206-209) | PASS | AntiAIPanel.swift:321-322 | - |
| 224 | 规则加载中 (:211-213) | PASS | AntiAIPanel.swift:324-325 | - |
| 225 | 规则卡片列表 (:215-233) | PASS | AntiAIPanel.swift:330-357 | - |
| 226 | 规则空状态 (:235) | PASS | AntiAIPanel.swift:326-328 | - |
| 227 | loadRules (:525-534) | PASS | AntiAIStore.swift:73-81 | - |
| 228 | 白名单说明文案 (:244-247) | PASS | AntiAIPanel.swift:365-366 | - |
| 229 | 白名单加载中 (:249-251) | PASS | AntiAIPanel.swift:368-369 | - |
| 230 | 场景卡片列表 (:253-291) | PASS | AntiAIPanel.swift:374-420 | - |
| 231 | 场景类型中文 (:260) | PASS | AntiAIModels.swift:197-204, AntiAIPanel.swift:377 | - |
| 232 | 密度上限 (:262-264) | PASS | AntiAIPanel.swift:385-389 | - |
| 233 | 豁免分类标签 (:267-278) | PASS | AntiAIPanel.swift:392-402 | - |
| 234 | 豁免模式标签 (:279-289) | PASS | AntiAIPanel.swift:404-414 | - |
| 235 | 白名单空状态 (:293) | PASS | AntiAIPanel.swift:370-372 | - |
| 236 | loadAllowlist (:536-545) | PASS | AntiAIStore.swift:86-94 | - |
| 237 | 教程弹窗 (:298-304) | PASS | AntiAIPanel.swift:426-485 | - |
| 238 | 教程这是什么 (:306-316) | PASS | AntiAIPanel.swift:430-433 | - |
| 239 | 教程七层防御 (:318-343) | PASS | AntiAIPanel.swift:435-443 | - |
| 240 | 教程如何使用 (:345-356) | PASS | AntiAIPanel.swift:445-453 | - |
| 241 | 教程35+模式 (:358-371) | PASS | AntiAIPanel.swift:455-464 | - |
| 242 | 教程注意事项 (:373-383) | PASS | AntiAIPanel.swift:466-473 | - |
| 243 | onMounted→3路加载 (:547-551) | PASS | AntiAIStore.swift:98-104 | - |
| 244 | loadStats (:517-523) | PASS | AntiAIStore.swift:62-68 | - |

**E模块小结：52/52 PASS，无缺失。AntiAI面板完整度最高。**

### F. 对话沙盒面板（23条）— 对齐 DialogueCorpus.vue:1-311

| # | 功能点(原版行号) | 实现状态 | 证据(iOS文件:行号) | 缺失/简化 |
|---|---|---|---|---|
| 245 | 头部标题+副标题+刷新 (:3-9) | PASS | DialogueSandboxPanel.swift:114-129 | - |
| 246 | 筛选章节下拉 (:13-20) | PASS | DialogueSandboxPanel.swift:133-139 | - |
| 247 | 筛选说话人下拉 (:21-29) | PASS | DialogueSandboxPanel.swift:141-147 | - |
| 248 | 筛选搜索框 (:30-36) | PASS | DialogueSandboxPanel.swift:149-150 | - |
| 249 | 加载中状态 (:41-43) | PASS | DialogueSandboxPanel.swift:154-155 | - |
| 250 | 空数据状态 (:46-50) | PASS | DialogueSandboxPanel.swift:156-159 | - |
| 251 | 无匹配状态 (:51-55) | PASS | DialogueSandboxPanel.swift:160-163 | - |
| 252 | 对话列表 (:56-71) | PASS | DialogueSandboxPanel.swift:165-167 | - |
| 253 | 对话项章节tag (:66) | PASS | DialogueSandboxPanel.swift:180-183 | - |
| 254 | 对话项说话人tag (:67) | PASS | DialogueSandboxPanel.swift:184-188 | - |
| 255 | 对话项内容 (:69) | PASS | DialogueSandboxPanel.swift:190-193 | - |
| 256 | 角色高亮 (:61-63,155-159) | PASS | DialogueSandboxPanel.swift:177, 196-200 | - |
| 257 | 底部统计 (:75-79) | PASS | DialogueSandboxPanel.swift:169-171 | - |
| 258 | chapterOptions (:113-120) | PASS | DialogueSandboxPanel.swift:59-61 | - |
| 259 | speakerOptions (:123-130) | PASS | DialogueSandboxPanel.swift:64-66 | - |
| 260 | filteredDialogues (:133-153) | PASS | DialogueSandboxPanel.swift:44-56 | - |
| 261 | load (:183-196) | PASS | DialogueSandboxPanel.swift:314-327 | - |
| 262 | syncSelectionFromBible (:161-181) | PASS | DialogueSandboxPanel.swift:339-347 | - |
| 263 | deskChapterNumber→filterChapter (:198-203) | **BUG** | DialogueSandboxPanel.swift:38-41 | currentChapterNumber硬编码返回nil，desk章节联动失效 |
| 264 | slug→load (:205-207) | PASS | DialogueSandboxPanel.swift:97-101 | - |
| 265 | [slug,selectedCharacterId]→sync (:209-215) | PASS | DialogueSandboxPanel.swift:218-225 | - |
| 266 | deskTick→reload (:217-220) | PASS | DialogueSandboxPanel.swift:92-96 | - |
| 267 | defineExpose({load}) (:222-224) | N/A | - | SwiftUI无此概念，loadAll已暴露 |

**F模块小结：22/23 PASS，1项BUG（#263 currentChapterNumber硬编码nil）**

### G. API端点（38条）

| # | 端点 | 实现状态 | 证据 | 缺失 |
|---|---|---|---|---|
| G1-G6 | 伏笔5端点+markConsumed | PASS | APIEndpoint.Foreshadow + ForeshadowStore | - |
| G7-G13 | 道具7端点 | PASS | APIEndpoint.Props + PropStore | - |
| G14 | Manuscript.chapterMentions | PASS | APIEndpoint.Manuscript.chapterMentions (APIEndpoint.swift:548) | - |
| G15 | Manuscript.reindexMentions | PASS | APIEndpoint.Manuscript.reindexMentions (APIEndpoint.swift:550) | - |
| G16 | Bible.characters | PASS | APIEndpoint.Bible.characters (APIEndpoint.swift:132) | - |
| G17 | NarrativeEngine.storyEvolution | PASS | APIEndpoint.NarrativeEngine.storyEvolution (APIEndpoint.swift:556) | - |
| G18-G23 | 演化6端点 | PASS | APIEndpoint.Evolution + Governance + Worldline | - |
| G24-G26 | Novel/Bible/Workflow端点 | PASS | APIEndpoint.Novels.get + Bible.get + Workflow.getPlotOutline | - |
| G27-G28 | 编年史2端点 | PASS | APIEndpoint.Chronicles.get + rollback (APIEndpoint.swift:465-466) | - |
| G29-G34 | AntiAI 6端点 | PASS | APIEndpoint.AntiAI (9端点全有) | - |
| G35-G38 | 对话沙盒4端点 | PASS | APIEndpoint.Sandbox (4端点全有，含patchCharacterAnchor) | - |

**G模块小结：38/38 PASS，5个新端点全部补建正确。**

---

## 12条决策执行核对

| 决策# | 描述 | 执行状态 | 证据 |
|---|---|---|---|
| 1 | 演化4子组件全部移植 | **PASS** | StoryNavigatorView.swift + StoryTimelineView.swift + StoryDetailPanelView.swift 新建，WorldlineDAGView复用 |
| 2 | StoryEvolutionReadModel结构化建模 | **PASS** | EvolutionModels.swift:206-388 完整结构化（novelId/schemaVersion/lifeCycle/plotSpine/chronotope/chaptersDigest/subtextSurface/evolutionSurface），非全AnyCodable |
| 3 | AntiAIHit字段改为text/replacementHint/start/end | **PASS** | AntiAIModels.swift:68-92 字段名对齐（text/replacementHint=replacement_hint/start/end） |
| 4 | CharacterAnchor字段改为mentalState/verbalTic/idleBehavior | **PASS** | SandboxModels.swift:61-93 字段对齐 + 显式memberwise init |
| 5 | EvolutionSnapshot完整结构化+snapshotData兜底+memberwise init | **PASS** | EvolutionModels.swift:14-94 全部结构化字段 + snapshotData:AnyCodable兜底 + 显式init(行72-94) |
| 6 | GovernanceState语义对齐 | **PARTIAL** | GovernanceModels.swift:77-97 storylines←canonical_storylines✅, debts←open_debts✅, latestReport←latest_report✅，**但缺chapter_budget_preview字段** |
| 7 | TimelinePanel完整新建 | **PASS** | TimelinePanel.swift:1-271 完整Bible时间线CRUD（load/add/edit/delete/save） |
| 8 | workflowApi.getPlotOutline核对路径不许降级null | **FAIL** | APIEndpoint.Workflow.getPlotOutline路径正确(/novels/{id}/setup/plot-outline)，**但loadSetupAnchors未实现，该端点从未被调用**，plot-outline数据完全缺失 |
| 9 | DialogueSandboxPanel增加角色选择器 | **PASS** | DialogueSandboxPanel.swift:211-225 Picker角色选择器 + anchor读写联动 |
| 10 | WorkbenchStore用NotificationCenter实现tick机制 | **PASS** | WorkbenchStore.swift:18-35 三种Notification.Name + bump方法，各面板onReceive接听 |
| 11 | AntiAIDashboard统一用APIClient.shared.request | **PASS** | AntiAIStore.swift全用apiClient.request，无fetchJson |
| 12 | PropDetailDrawer用闭包回调 | **PASS** | PropDetailDrawer.swift:14 onUpdated闭包 + PropManagerPanel.swift:109-115 传入回调 |

**决策执行：11/12 PASS，1项FAIL（决策8）**

---

## 3个已知风险核查

| 风险# | 描述 | 核查结果 | 修复建议 |
|---|---|---|---|
| 1 | TimelinePanel BibleResponse与现有Bible模型冲突 | **✅ 无冲突** | Grep搜索确认`BibleResponse`仅在TimelinePanel.swift:245定义一次，与现有`BibleDTO`/`Bible`类型名不同，无重复声明。字段使用decodeIfPresent容错，CharacterDTO等引用已有类型。 |
| 2 | StoryEvolutionPanel endingState解析 AnyCodable.value | **✅ 可访问** | AnyCodable定义在CommonModels.swift:215，`value`属性类型为`Any`（行218）。init(from:)解码字典时存储`dict.mapValues { $0.value }`即`[String: Any]`。`endingState?.value as? [String: Any]`可正常访问。 |
| 3 | StoryTimelineView [String: AnyCodable] body APIClient.send | **✅ 接受** | APIClient.send泛型签名为`func send<B: Encodable>(_:body:)`（APIClient.swift）。`[String: AnyCodable]`符合Encodable（Dictionary+AnyCodable均Encodable），调用合法。 |

**3个已知风险：3/3 已解决，均无编译风险。**

---

## 技术铁律检查

| 检查项 | 结果 | 备注 |
|---|---|---|
| 1. iOS 16+兼容 | PASS | 未使用iOS 17+独占API，FlowLayout用Layout协议(iOS 16+) |
| 2. 零新SPM依赖 | PASS | 无新增import外部包 |
| 3. 日期解码用CangjieDecoder.shared | PASS | EvolutionModels/GovernanceModels中用CangjieDecoder.shared |
| 4. Store用ObservableObject+@Published | PASS | AntiAIStore/EvolutionStore/ForeshadowStore/PropStore均符合 |
| 5. catch块error是常量(教训1) | PASS | 各catch块均用`error`常量，无var |
| 6. Codable CodingKeys覆盖所有存储属性(教训2) | PASS | 抽查AntiAIHit/EvolutionSnapshot/CharacterAnchor/GovernanceState CodingKeys完整 |
| 7. 无类型重复声明(教训4) | PASS | BibleResponse仅一处定义，无重复。Grep确认 |
| 8. 补字段同步调用处(教训5) | PASS | AntiAIHit新字段在AntiAIPanel命中详情中使用 |
| 9. 自定义init(from:)补memberwise init(教训8) | PASS | EvolutionSnapshot(行72-94) + CharacterAnchor(行86-92) + TimelineNoteDTO(行32-37)均有显式memberwise init |

---

## 智能路由判定

**判定：源码砍功能 → Engineer返工**

### 需Engineer修复的问题清单（按优先级排序）

#### P0 — 核心功能缺失（必须修复）

1. **EvolutionStore.loadAll缺第5路加载 (功能点#153)**
   - 文件：`EvolutionStore.swift:160-166`
   - 问题：`loadAll`仅4路（bundle/snapshots/gov/worldline），缺第5路`loadSetupAnchors`
   - 修复：新增`loadSetupAnchors(novelId:)`方法，调`Promise.allSettled`等价的`async let`三路加载Novel+Bible+PlotOutline，存入`@Published var setupAnchors`

2. **司令塔引导落点12种锚点全缺 (功能点#122-#132)**
   - 文件：`StoryEvolutionPanel.swift:134-158`
   - 问题：`setupAnchorsSection`仅显示storylines+chronotope，缺12种锚点（genre-world/premise/structure/plot-outline/core-conflict/ending/characters/world-settings/locations/style/special-requirements）
   - 修复：基于loadSetupAnchors加载的Novel+Bible+Outline数据，实现12种锚点卡片渲染

3. **GovernanceState缺chapter_budget_preview字段 (功能点#133)**
   - 文件：`GovernanceModels.swift:77-97`
   - 问题：GovernanceState CodingKeys缺`chapter_budget_preview`，无法解码预算预览
   - 修复：添加`chapterBudgetPreview: GovernanceBudgetPreview?`字段+CodingKey

4. **GovernanceReport缺promise_hit_rate字段 (功能点#118)**
   - 文件：`GovernanceModels.swift:187-210`
   - 问题：GovernanceReport无`promise_hit_rate`字段，Hero承诺命中率用`report.budget as? Double`替代（错误字段）
   - 修复：添加`promiseHitRate: Double?`字段+CodingKey，StoryEvolutionPanel.swift:96改用`report.promiseHitRate`

#### P1 — 面板功能缺失（应修复）

5. **司令塔缺状态连续性面板 (功能点#135)**
   - 文件：`StoryEvolutionPanel.swift` commandTab
   - 问题：无evidenceRows展示（原版:158-174）
   - 修复：在commandTab添加状态连续性区域，从latestSnapshot取ending_state数据展示

6. **司令塔缺世界线简要面板 (功能点#136)**
   - 文件：`StoryEvolutionPanel.swift` commandTab
   - 问题：commandTab无世界线检查点/分支/HEAD计数
   - 修复：从store.worldlineGraph提取摘要数据展示

7. **司令塔缺"角色档案"按钮 (功能点#116)**
   - 文件：`StoryEvolutionPanel.swift` tabBar
   - 问题：原版:49有"角色档案"按钮dispatchEvent打开sandbox面板，iOS缺失
   - 修复：在tabBar旁添加按钮，用NotificationCenter或AppState切换到DialogueSandboxPanel

8. **风险与修复队列简化 (功能点#137)**
   - 文件：`StoryEvolutionPanel.swift:178-195`
   - 问题：riskSection仅显示conflicts，缺combinedRisks（governance issues + conflicts合并，最多12条）
   - 修复：合并governanceState.latestReport.violations + snapshot.conflicts

#### P2 — 次要问题（建议修复）

9. **ForeshadowLedgerPanel删除无确认 (功能点#23)**
   - 文件：`ForeshadowLedgerPanel.swift:390-399`
   - 修复：添加.confirmationDialog或.swipeActions确认

10. **ForeshadowLedgerPanel缺帮助tooltip (功能点#4)**
    - 修复：添加帮助按钮+popover

11. **PropManagerPanel缺用法提示折叠面板 (功能点#55)**
    - 修复：添加DisclosureGroup显示`[[prop:道具ID|显示名]]`语法说明

12. **PropManagerPanel缺骨架屏 (功能点#64)**
    - 修复：isLoading时显示redacted placeholder

13. **DialogueSandboxPanel currentChapterNumber硬编码nil (功能点#263)**
    - 文件：`DialogueSandboxPanel.swift:38-41`
    - 修复：从NovelStore或AppState获取当前章节号

14. **ChroniclesPanel Note未显示 (功能点#173)**
    - 修复：从chronicles.note取值显示alert

15. **角色状态修改不完整 (功能点#141)**
    - 文件：`StoryEvolutionPanel.swift:248-255`
    - 问题：applyOverrides chapterNumber硬编码0，patches空数组
    - 修复：实现角色状态下拉选择+JSON Patch构建

16. **StoryNavigatorView confluenceList恒空**
    - 文件：`StoryNavigatorView.swift:180`
    - 问题：`confluenceList`返回`[]`，汇流轴区域永远不显示
    - 修复：从evolutionBundle解析汇流点数据

---

## 遗留问题

1. **EvolutionStore.applyOverrides chapterNumber硬编码为0** — `EvolutionStore.swift:95`中`snapshotOverrides(novelId: novelId, chapterNumber: 0)`，应传入实际章节号。这不是T05新增问题（T04遗留），但影响演化面板功能。

2. **BibleResponse vs 现有BibleDTO** — 虽然无类型冲突，但TimelinePanel.swift定义了一个独立的`BibleResponse`结构体来读写timeline_notes，而项目中可能已有`BibleDTO`模型。建议确认是否应复用现有模型以避免模型碎片化。

3. **StoryEvolutionPanel的governanceSection缺少issues展示** — 原版叙事治理面板(:139-156)显示`governanceState.latest_report.issues`列表，iOS仅显示storylines+debts计数。需补充issues列表渲染。

---

## 验收统计

| 模块 | 总功能点 | PASS | MISSING/SIMPLIFIED | 对齐率 |
|---|---|---|---|---|
| A. 伏笔面板 | 52 | 50 | 2 | 96.2% |
| B. 道具面板 | 61 | 59 | 2 | 96.7% |
| C. 演化面板 | 57 | 41 | 16 | 71.9% |
| D. 编年史面板 | 22 | 21 | 1 | 95.5% |
| E. AntiAI面板 | 52 | 52 | 0 | 100% |
| F. 对话沙盒面板 | 23 | 22 | 1 | 95.7% |
| G. API端点 | 38 | 38 | 0 | 100% |
| **合计** | **305** | **283** | **22** | **92.8%** |

**IS_PASS: NO**

核心问题集中在**演化面板司令塔Tab**（16项缺失/简化），根因是`loadSetupAnchors`第5路加载未实现 + `GovernanceState`/`GovernanceReport`模型字段不全。AntiAI面板和API端点实现质量最高（100%）。

---

*报告结束。等待Engineer返工修复P0/P1问题后进行第2轮回归验证。*
