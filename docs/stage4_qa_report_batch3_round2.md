# 阶段4 批次3 轮2 QA回归验证报告

**核验人**: 严过关（Yan, QA Engineer）  
**核验日期**: 2026-06-25  
**核验方式**: 独立读代码逐条验证4项修复，不轻信寇豆码自报  
**核验范围**: 轮1抓到的4项修复（Bug-1 + 偏差#1/#2/#3）

---

## 核验结论

- **IS_PASS: YES**
- **4项修复全部真实解决**: 4/4 PASS
- **修复后对齐度: 49/49**（100%，轮1的3项偏差全部修复，Bug-1已解决）
- **修复引入编译风险: 0致命**（1处轻微观察：3个简单Response模型仍未补memberwise init，非阻断）
- **智能路由判定: NoOne**（全部通过，批次3完成，可进批次4）

---

## 一、4项修复逐条验证

### 修复1: Bug-1 紧急度聚合传0 → 改为方法接收参数

**文件**: `NarrativeDashboardStore.swift` + `NarrativeDashboardPanelView.swift`

| # | 验证点 | 结果 | 证据(iOS文件:行号) |
|---|---|---|---|
| 1 | `hasCriticalPromise` 从 computed property 改为 func，接收 `currentChapterNumber: Int` | ✅ PASS | Store:169-171 (`func hasCriticalPromise(currentChapterNumber: Int) -> Bool`) |
| 2 | `urgentCount` 从 computed property 改为 func，接收 `currentChapterNumber: Int` | ✅ PASS | Store:175-177 (`func urgentCount(currentChapterNumber: Int) -> Int`) |
| 3 | 函数内部调用 `foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber)`（不再传0） | ✅ PASS | Store:170 (`foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber)`) + Store:176 (同) |
| 4 | View调用处 `:304` 改为 `store.hasCriticalPromise(currentChapterNumber: currentChapterNumber)` | ✅ PASS | View:304 (`store.hasCriticalPromise(currentChapterNumber: currentChapterNumber)`) |
| 5 | View调用处 `:506` 改为 `store.urgentCount(currentChapterNumber: currentChapterNumber)` | ✅ PASS | View:506-507 (`store.urgentCount(currentChapterNumber: currentChapterNumber)` ×3处：value判断+value值+color判断) |
| 6 | 无其他地方调用旧的无参版本（Grep确认全项目仅2处调用，均带参数） | ✅ PASS | Grep `.hasCriticalPromise\b` → 仅 View:304; Grep `.urgentCount\b` → 仅 View:506,507（均带参数） |

**修复1结论: ✅ 真实解决。** 紧急度聚合现在正确传入实际章节号，`foreshadowUrgencyClass` 的 `remaining ≤ 3 → danger` 和 `≤ 10 → warning` 分支能正确触发。

---

### 修复2: 偏差#1 汇流曲线source→target分支映射

**文件**: `WorldlineDAGView.swift`（computeLayout + drawConfluenceCurves）

| # | 验证点 | 结果 | 证据(iOS文件:行号) |
|---|---|---|---|
| 1 | 新增 `storylineBranchName(_ storylineId:)` 查找逻辑 | ✅ PASS | :410-421 (先查 branches.storylineId → 再查 storylines.isMainStoryline → 默认"main"，对齐Vue:620-623) |
| 2 | 新增 `chapterToY(_ chapter:)` 章节→Y坐标映射 | ✅ PASS | :399-407 (ratio = max(0, chapter-1)/max(maxChapter-1,1); return topPad + ratio * usableH，对齐Vue:542-545) |
| 3 | 贝塞尔曲线从source分支列(sourceCx) → target分支列(targetCx)，不再固定main列+cx+40偏移 | ✅ PASS | :432-453 (sourceBranchIdx/targetBranchIdx via storylineBranchName; sourceCx = leftPad + sourceBranchIdx * colW + nodeW/2; targetCx同理; path.move(sourceCx) → path.addCurve(targetCx+offset)) |
| 4 | label格式 `"Ch.\(cp.targetChapter) \(getConfluenceLabel(cp.mergeType))"` | ✅ PASS | :456 (`let label = "Ch.\(cp.targetChapter) \(getConfluenceLabel(cp.mergeType))"`，对齐Vue:557-558) |
| 5 | 重叠偏移 `(index % 3) * 10` | ✅ PASS | :443 (`let offset: CGFloat = CGFloat(idx % 3) * 10`，对齐Vue:559；注：iOS偏移应用于x轴，Vue应用于y轴，均为防重叠，功能等价) |
| 6 | 移除冗余confluenceLabel函数，统一用StorylineDomain.getConfluenceLabel | ✅ PASS | Grep `confluenceLabel` → 0命中（旧私有函数已删除）; :456 + :814 均用 `getConfluenceLabel`（来自StorylineDomain.swift:108） |

**修复2结论: ✅ 真实解决。** 汇流曲线现在正确映射source→target分支列，label包含"Ch.X"前缀，重叠偏移已实现。偏移轴差异（iOS x轴 vs Vue y轴）为视觉适配，功能等价。

---

### 修复3: 偏差#2 空详情面板汇流列表补storylineName

**文件**: `WorldlineDAGView.swift`（emptyDetailPanel）

| # | 验证点 | 结果 | 证据(iOS文件:行号) |
|---|---|---|---|
| 1 | 汇流列表每行显示 `storylineDisplayName(source)→storylineDisplayName(target)` | ✅ PASS | :810 (`Text("\(storylineDisplayName(cp.sourceStorylineId))→\(storylineDisplayName(cp.targetStorylineId))")`，对齐Vue:271 "sourceName→targetName") |
| 2 | 新增View级别 `storylineDisplayName` 辅助方法 | ✅ PASS | :952-959 (`private func storylineDisplayName(_ storylineId: String?) -> String`：查store.storylines匹配id，返回name或id前8位，空值返回"主线") |
| 3 | 保留"第N章"和mergeType标签（与原版一致） | ✅ PASS | :807-808 ("第\(cp.targetChapter)章") + :814 (`Text(getConfluenceLabel(cp.mergeType))`) |

**修复3结论: ✅ 真实解决。** 空详情面板汇流列表现在完整显示"第N章 · sourceName→targetName · mergeType"，对齐Vue:271。

---

### 修复4: 偏差#3 11个模型补memberwise init（教训8）

**文件**: `WorldlineModels.swift` + `ChapterDraft.swift`

| # | 模型 | 显式memberwise init | 参数顺序一致 | 默认值 | 证据(文件:行号) |
|---|---|---|---|---|---|
| 1 | WorldlineGraph | ✅ | ✅ nodes/edges/branches/headId | ✅ 全Optional/空数组 | WorldlineModels.swift:32-40 |
| 2 | WorldlineCheckpointNode | ✅ | ✅ id/name/triggerType/branchName/createdAt/anchorChapter/worldSlice/rollbackSlice | ✅ Optional=nil, String=""/"main" | :78-91 |
| 3 | WorldSlice | ✅ | ✅ chapterNumber/timeAnchor/location/emotionalResidue/characters/items/actionsCount/conflictsCount | ✅ 全Optional=nil | :129-145 |
| 4 | WorldSliceCharacter | ✅ | ✅ id/name/status/location | ✅ Optional=nil, String="" | :167-173 |
| 5 | WorldSliceItem | ✅ | ✅ id/name/holder | ✅ Optional=nil, String="" | :193-197 |
| 6 | RollbackSlice | ✅ | ✅ toCheckpointId/toChapter/branchName | ✅ String=""/"main", Int=0 | :221-225 |
| 7 | WorldlineBranchInfo | ✅ | ✅ id/name/headId/isDefault/storylineId | ✅ Optional=nil, String=""/"main", Int=0 | :254-262 |
| 8 | WorldlineEdge | ✅ | ✅ from/to/kind | ✅ Optional=nil, String="" | :284-288 |
| 9 | WorldlineCheckoutResult | ✅ | ✅ stashId/restoredChapters/deletedChapters/message | ✅ 全Optional=nil | :315-323 |
| 10 | ConfluencePointDTO | ✅ | ✅ id/novelId/sourceStorylineId/targetStorylineId/targetChapter/mergeType/contextSummary/preRevealHint/behaviorGuards/resolved | ✅ Optional=nil, String=""/"intersect", Int=0, Bool=false | :458-473 |
| 11 | ConfirmActChaptersResponse | ✅ | ✅ success/message | ✅ Optional=true/"" | ChapterDraft.swift:69-72 |

**修复4结论: ✅ 真实解决。** 11个模型全部补齐显式memberwise init，参数顺序与存储属性声明顺序一致，Optional字段默认nil，非Optional字段有合理默认值。memberwise init与init(from decoder:)共存不冲突。

---

## 二、修复引入的编译风险扫描

### 2.1 教训10：新增函数重复声明扫描

| 新增函数 | 声明处数 | 结果 |
|---|---|---|
| `storylineBranchName` | 1 (WorldlineDAGView.swift:410, computeLayout内嵌套函数) | ✅ PASS |
| `chapterToY` | 1 (WorldlineDAGView.swift:399, computeLayout内嵌套函数) | ✅ PASS |
| `storylineDisplayName` | 2 (:424 computeLayout内嵌套函数 + :953 View私有方法) | ✅ PASS（合法shadowing：嵌套函数在computeLayout作用域内shadow View方法，两者实现相同，Swift允许，不致编译错误） |

### 2.2 ConfluencePos新增字段冲突检查

| 新增字段 | 类型 | 与现有字段冲突 | 结果 |
|---|---|---|---|
| sourceName | String | 否（现有: cx/cy/path/label/resolved） | ✅ PASS |
| targetName | String | 否 | ✅ PASS |

**观察**: `sourceName`/`targetName` 字段在ConfluencePos中已赋值(:463-464)，但当前`drawConfluenceCurves`和`emptyDetailPanel`均未读取这两个字段（emptyDetailPanel直接调用View级`storylineDisplayName`方法）。字段存在但不使用，不致编译错误，属于预留字段。

### 2.3 iOS 16兼容性

| 检查项 | 结果 | 证据 |
|---|---|---|
| 无@Observable/@Bindable | ✅ PASS | Grep批次3修改文件零命中 |
| 无NavigationSplitView | ✅ PASS | Grep批次3修改文件零命中 |
| 无.scrollContentMargins | ✅ PASS | Grep零命中 |
| 无SpatialTapGesture | ✅ PASS | Grep零命中（WorldlineDAGView用.onTapGesture，决策#5） |

### 2.4 memberwise init与init(from decoder:)共存

| 检查项 | 结果 | 证据 |
|---|---|---|
| 11个模型均有init(from decoder:) + 显式memberwise init | ✅ PASS | 逐个核验：两个init签名不同（一个接Decoder，一个接存储属性参数），Swift允许共存，不冲突 |
| memberwise init参数带默认值（可无参构造） | ✅ PASS | 11个模型memberwise init所有参数均有默认值，可`WorldlineGraph()`无参构造 |

---

## 三、轻微观察（非阻断，不触发路由）

| # | 观察 | 涉及文件:行号 | 影响 |
|---|---|---|---|
| 1 | 3个简单Response模型仍缺memberwise init（CreateWorldlineCheckpointResponse/CreateWorldlineBranchResponse/MergeWorldlineBranchResponse） | WorldlineModels.swift:343/372/400 | 非阻断。这3个模型仅有1-2个Optional字段，当前代码仅从API解码，不影响编译。轮1报告列出14个模型缺init，寇豆码修复了其中11个（主理人指定的11个），这3个未被指定。 |
| 2 | storylineDisplayName存在2处定义（computeLayout内嵌套:424 + View方法:953），实现相同 | WorldlineDAGView.swift:424,953 | 非阻断。Swift合法shadowing，但略冗余。computeLayout可直接调用View方法，省去嵌套定义。 |
| 3 | ConfluencePos.sourceName/targetName字段已赋值但未被读取 | WorldlineDAGView.swift:264-265,463-464 | 非阻断。预留字段，不影响编译。 |
| 4 | 汇流曲线重叠偏移iOS应用于x轴（targetCx+offset），Vue应用于y轴（cy+(index%3)*10） | WorldlineDAGView.swift:450 vs Vue:559 | 非阻断。均为防重叠，功能等价，视觉方向不同。 |

---

## 四、智能路由判定

### 判定: NoOne（全部通过）

**判定依据**: 轮1抓到的4项修复（1 Bug + 3偏差）全部真实解决，修复未引入新的编译风险。批次3功能对齐度从轮1的46/49提升至49/49。

**寇豆码自报"IS_PASS:YES、49/49=100%"核验结果**: IS_PASS:YES确认，49/49=100%确认。本轮寇豆码自报准确。

---

## 五、总结

| 维度 | 轮1 | 轮2 |
|---|---|---|
| IS_PASS | YES（1 Bug非阻断） | **YES** |
| 功能对齐度 | 46/49 (93.9%) | **49/49 (100%)** |
| Bug数 | 1 (Bug-1) | **0** |
| 偏差数 | 3 (#1/#2/#3) | **0**（全部修复） |
| 编译风险 | 0致命, 1警告 | **0致命**（3个Response模型缺init为轻微观察） |
| 智能路由 | Engineer | **NoOne** |

**批次3 QA验收完成。IS_PASS: YES，对齐度100%，可进入批次4。**
