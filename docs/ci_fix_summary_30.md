# CI#30 编译错误修复摘要

**修复时间**: CI#30
**修复工程师**: 寇豆码（Kou）— software-engineer-4
**IS_PASS**: YES

---

## 修复清单（6组，约20个错误）

### 1. LLMConfigSection.swift:311 — protocol关键字转义（CI#29遗留）
- **错误**: `keyword 'protocol' does not need to be escaped in argument list`
- **原因**: CI#29修复了:261的 `` `protocol` `` 转义，但:311还有一处遗留
- **修复**: 去掉 `` `protocol` `` 的反引号，改为 `protocol: protocolType`
- **修改文件**: `Cangjie/Views/Settings/LLMConfigSection.swift`

### 2. CharacterNavigatorView.swift:112,136,140,142 — nil合并运算符左操作数非Optional（4处）
- **错误**: `left side of nil coalescing operator '??' has non-optional type 'String', so the right side is never used`
- **原因**: `CharacterDTO.role` 是计算属性 `var role: String`（BibleModels.swift:926），非Optional，`?? ""` 永远不会被使用
- **修复**: 4处 `char.role ?? ""` 全部改为 `char.role`
  - :112 `roleColor(char.role)`
  - :136 `roleLabel(char.role)`
  - :140 `roleBgColor(char.role)`
  - :142 `roleFgColor(char.role)`
- **修改文件**: `Cangjie/Views/Workbench/CharacterNavigatorView.swift`

### 3. NodeDetailPanel.swift:576 — FlowLayout重复声明
- **错误**: `invalid redeclaration of 'FlowLayout'`
- **原因**: FlowLayout在两个文件中各声明了一次：
  - `PropManagerPanel.swift:463`（首次声明）
  - `NodeDetailPanel.swift:576`（重复声明）
- **修复**: 删除 NodeDetailPanel.swift 中的 FlowLayout 声明（:573-624），保留 PropManagerPanel.swift 中的声明。两个声明功能等价（均有 sizeThatFits + placeSubviews），NodeDetailPanel 的 `FlowLayout(spacing: 4)` 调用兼容 PropManagerPanel 的 `var spacing: CGFloat = 6` 成员初始化器
- **修改文件**: `Cangjie/Views/Autopilot/NodeDetailPanel.swift`

### 4. StoryEvolutionPanel.swift:627,642,721,723 — AnyCodable不符合Hashable/类型转换（4处）
- **错误1** (:627): `referencing initializer 'init(_:id:content:)' on 'ForEach' requires that 'AnyCodable' conform to 'Hashable'`
  - `snap.deltaActions` 是 `[AnyCodable]`（EvolutionModels.swift:22），AnyCodable 仅 conform Equatable，不 conform Hashable
  - **修复**: `ForEach(Array(snap.deltaActions.prefix(20)), id: \.self)` → `ForEach(Array(snap.deltaActions.prefix(20)).enumerated(), id: \.offset) { _, action in`
- **错误2** (:642): 同上模式，`snap.conflicts` 也是 `[AnyCodable]`（EvolutionModels.swift:27）
  - **修复**: `ForEach(Array(snap.conflicts.prefix(10)), id: \.self)` → `ForEach(Array(snap.conflicts.prefix(10)).enumerated(), id: \.offset) { _, conflict in`
- **错误3** (:721): `cannot convert value of type 'ChronicleStoryEvent' to expected argument type 'AnyCodable'`
  - StoryTimelineView 的 `onSelectEvent` 回调参数类型是 `ChronicleStoryEvent`，但 `StorySelectedItem.data` 是 `AnyCodable`
  - **修复**: `data: event` → `data: AnyCodable(event)`
- **错误4** (:723): `cannot convert value of type 'ChronicleSnapshot' to expected argument type 'AnyCodable'`
  - StoryTimelineView 的 `onSelectSnapshot` 回调参数类型是 `ChronicleSnapshot`，但 `StorySelectedItem.data` 是 `AnyCodable`
  - **修复**: `data: snapshot` → `data: AnyCodable(snapshot)`
- **修改文件**: `Cangjie/Views/Panels/StoryEvolutionPanel.swift`

### 5. StorylineGitGraphView.swift:278,314,356,392 — StrokeStyle无效参数 + iOS 17 API（4处）
- **错误1** (:278): `extra argument 'opacity' in call`
  - `StrokeStyle(lineWidth:isActive ? 2.5 : 1.6, opacity:isActive ? 0.85 : 0.35)` — SwiftUI.StrokeStyle 没有 `opacity` 参数
  - **修复**: 将 opacity 移到颜色上：`.color(tr.color.opacity(isActive ? 0.85 : 0.35))`，StrokeStyle 改为 `StrokeStyle(lineWidth: isActive ? 2.5 : 1.6)`
- **错误2** (:314): 同上
  - `StrokeStyle(lineWidth: 2, opacity: 0.75)` — 同样无效
  - **修复**: `.color(sourceColor.opacity(0.75))` + `StrokeStyle(lineWidth: 2)`
- **错误3** (:356): `'init(_:)' is only available in iOS 17.0 or newer`
  - `Color(Theme.textTertiary)` — `Theme.textTertiary` 已是 `Color` 类型（Theme.swift:115 `Color(.tertiaryLabel)`），`Color(Color)` 的 `init(_:)` 仅 iOS 17+ 可用
  - **修复**: 去掉 `Color(...)` 包装，直接用 `Theme.textTertiary`
- **错误4** (:392): 同上
  - **修复**: `Color(Theme.textTertiary)` → `Theme.textTertiary`
- **修改文件**: `Cangjie/Views/Workbench/StorylineGitGraphView.swift`

### 6. WorldlineDAGView.swift:285-437 — branchOrder找不到（约15处）
- **错误**: `cannot find 'branchOrder' in scope`（:287,288,293,294,298,299,301,302,320,325,338,436,437等）
- **根因**: 第285行 `// 分支列分配 — WorldlineDAG.vue:428-440        var branchOrder: [String] = []` — `var branchOrder` 声明与 `//` 注释在同一行，被当作注释内容，导致变量未实际声明
- **修复**: 将注释和声明拆分为两行：
  ```swift
  // 分支列分配 — WorldlineDAG.vue:428-440
  var branchOrder: [String] = []
  ```
- **修改文件**: `Cangjie/Views/Snapshot/WorldlineDAGView.swift`

---

## 自检结果

| 检查项 | 结果 | 验证方式 |
|--------|------|----------|
| FlowLayout 仅1处声明 | PASS | Grep `struct FlowLayout` → 仅 PropManagerPanel.swift:463 |
| CharacterNavigatorView 无 `?? ""` 残留 | PASS | Grep `\?\? ""` → No matches found |
| iOS 16兼容（无17+ API未包裹） | PASS | Grep `Color(Theme.` → 无独立 Color(Theme.xxx) 包装；Grep `if #available` → 无需（已消除17+ API） |
| LLMConfigSection 无 `` `protocol` `` 转义 | PASS | Grep `` `protocol` `` → No matches found |
| WorldlineDAGView branchOrder 作用域正确 | PASS | :286 `var branchOrder` 独立一行，后续:288-437均可访问 |
| StoryEvolutionPanel 无 `id: \.self` on AnyCodable | PASS | Grep `id: \.self` → 仅 String 数组(:594,:604)，无 AnyCodable |
| StorylineGitGraphView 无 StrokeStyle opacity | PASS | Grep `StrokeStyle.*opacity` → No matches found |

---

## 技术约定遵守

1. **iOS 16+ 兼容**: 所有修复均使用 iOS 16 兼容 API，无新增 17+ API
2. **零新SPM依赖**: 未引入任何新依赖
3. **CangjieDecoder.shared**: 未涉及日期处理
4. **Store模式**: 未涉及 Store 修改
5. **catch块error常量**: 未涉及 catch 块修改

---

## IS_PASS: YES
