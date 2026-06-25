# 阶段4 批次3 QA轮1修复摘要

> 工程师：寇豆码（Kou）
> 日期：2026-06-26
> QA验收：严过关（IS_PASS:YES，对齐度46/49→修复4项）

---

## 修复清单

### 必修1: Bug-1 紧急度聚合传0（功能Bug）

**文件**: `Cangjie/ViewModels/NarrativeDashboardStore.swift:167-177`

**问题**: `hasCriticalPromise` 和 `urgentCount` 固定传 `currentChapterNumber: 0`，导致 `importance != "critical"` 但距到期≤3章的伏笔不被判定为danger。

**修复**: 改为方法接收参数：
- `hasCriticalPromise` → `func hasCriticalPromise(currentChapterNumber: Int) -> Bool`
- `urgentCount` → `func urgentCount(currentChapterNumber: Int) -> Int`

**View调用处同步修改**:
- `NarrativeDashboardPanelView.swift:304` → `store.hasCriticalPromise(currentChapterNumber: currentChapterNumber)`
- `NarrativeDashboardPanelView.swift:506-507` → `store.urgentCount(currentChapterNumber: currentChapterNumber)`

### 必修2: 偏差#1 汇流曲线source→target分支映射（核心视觉）

**文件**: `Cangjie/Views/Snapshot/WorldlineDAGView.swift:392-466`（computeLayout内汇流点计算）

**问题**: 汇流曲线始终用"main"分支列 + 固定偏移(cx→cx+40, cy→cy-20)，未实现原版source→target分支映射。

**修复**:
1. 新增 `storylineBranchName(_ storylineId:)` — 查找storylineId对应的分支名（先查branches.storylineId，再查storylines中isMainStoryline，默认"main"）
2. 新增 `chapterToY(_ chapter:)` — 章节→Y坐标映射
3. 贝塞尔曲线从source分支列(sourceCx) → target分支列(targetCx+offset)
4. label格式改为 `"Ch.\(cp.targetChapter) \(getConfluenceLabel(cp.mergeType))"`
5. 重叠偏移 `(index % 3) * 10`
6. ConfluencePos结构体新增 `sourceName`/`targetName` 字段
7. 移除冗余的私有 `confluenceLabel` 函数（统一用StorylineDomain的 `getConfluenceLabel`）

### 必修3: 偏差#2 空详情面板汇流列表补storylineName（小修）

**文件**: `Cangjie/Views/Snapshot/WorldlineDAGView.swift:802-819`（emptyDetailPanel汇流列表）

**问题**: 仅显示"第N章"+mergeType标签，缺"sourceName→targetName"文本。

**修复**: 补 `Text("\(storylineDisplayName(cp.sourceStorylineId))→\(storylineDisplayName(cp.targetStorylineId))")`，用View级别的 `storylineDisplayName` 查找storylines列表。

### 必修4: 偏差#3 11个Worldline模型补memberwise init（教训8铁律）

**文件**: `Cangjie/Models/WorldlineModels.swift` + `Cangjie/Models/ChapterDraft.swift`

**问题**: 11个API响应模型仅有 `init(from decoder:)` 无显式memberwise init。

**修复**: 每个模型补显式memberwise init（参数带默认值，顺序与存储属性声明顺序一致）：

| # | 模型 | 文件 |
|---|---|---|
| 1 | WorldlineGraph | WorldlineModels.swift |
| 2 | WorldlineCheckpointNode | WorldlineModels.swift |
| 3 | WorldSlice | WorldlineModels.swift |
| 4 | WorldSliceCharacter | WorldlineModels.swift |
| 5 | WorldSliceItem | WorldlineModels.swift |
| 6 | RollbackSlice | WorldlineModels.swift |
| 7 | WorldlineBranchInfo | WorldlineModels.swift |
| 8 | WorldlineEdge | WorldlineModels.swift |
| 9 | WorldlineCheckoutResult | WorldlineModels.swift |
| 10 | ConfluencePointDTO | WorldlineModels.swift |
| 11 | ConfirmActChaptersResponse | ChapterDraft.swift |

---

## 修复后对齐度

| 组件 | 修复前 | 修复后 |
|---|---|---|
| 4.2 世界线DAG重写 | 28/28 | 28/28（偏差#1+#2修复） |
| 4.3 ActPlanningModal | 16/16 | 16/16 |
| 4.3 NarrativeDashboardPanel | 2/5 (Bug-1 + 偏差#3) | 5/5 |
| **总计** | **46/49** | **49/49 = 100%** |

## IS_PASS: YES
