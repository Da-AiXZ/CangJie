# CI#29 编译错误修复摘要

**修复时间**: 2026-06-25  
**修复人**: 寇豆码 (Kou) — software-engineer-3  
**CI编号**: #29  
**错误总数**: ~25个编译错误（14组）  
**修复结果**: IS_PASS: YES

---

## 修复清单

### 1. SnapshotRollbackResponse 重复声明（教训10）
- **错误**: `invalid redeclaration of 'SnapshotRollbackResponse'`
- **原因**: 三个文件同时声明了 `SnapshotRollbackResponse`
  - EvolutionModels.swift:429（已删除）
  - StorylineGraphModels.swift:378（已删除）
  - SnapshotModels.swift:137（保留 — 最完整版本，含 `hasEngineState`）
- **连锁修复**: ChroniclesPanel.swift:217 的 `SnapshotRollbackResponse is ambiguous` 随此修复解决
- **修改文件**: EvolutionModels.swift, StorylineGraphModels.swift

### 2. EmptyBody 重复声明
- **错误**: `invalid redeclaration of 'EmptyBody'`
- **原因**: KnowledgeGraphStore.swift:266 有 `private struct EmptyBody`，OnboardingWizardView.swift:206 有模块级 `struct EmptyBody`，Swift不允许同名类型（即使private）
- **修复**: 删除 KnowledgeGraphStore.swift 中的 private 声明，保留 OnboardingWizardView.swift 的模块级声明
- **修改文件**: KnowledgeGraphStore.swift

### 3. StorylineGitGraphView.swift:563 — guard 语法错误
- **错误**: `expected 'else' after 'guard' condition`（3条）
- **原因**: `guard let mainLine = lines.first(where: { isMainStoryline($0) }) ) else { return }` 多了一个 `)`
- **修复**: 删除多余的 `)`
- **修改文件**: StorylineGitGraphView.swift

### 4. ActPlanningModalView.swift:410,542,553,564 — self immutable（4处）
- **错误**: `cannot assign to property: 'self' is immutable`
- **原因**: `private var streamTask: Task<Void, Never>?` 是普通存储属性，在 SwiftUI View struct 中非 mutating 方法不能赋值
- **修复**: 改为 `@State private var streamTask: Task<Void, Never>?`
- **修改文件**: ActPlanningModalView.swift

### 5. ChapterStatusPanelView.swift:326,328 — VStack 初始化错误
- **错误**: `result of 'VStack<Content>' initializer is unused` + `no return statements`
- **原因**: 函数有 `let steps = ...` 语句后接 VStack，不是单表达式函数，需要显式 `return`
- **修复**: 在 VStack 前加 `return`
- **修改文件**: ChapterStatusPanelView.swift

### 6. AntiAIPanel.swift:119,321 — 2个错误
- **错误1**: `DefenseLayer does not conform to 'Identifiable'`
  - **修复**: 添加 `var id: String { key }` 计算属性
- **错误2**: `cannot find '禁止' in scope`
  - **原因**: 字符串内含未转义的 ASCII 双引号 `"`，编译器将其解释为字符串结束
  - **修复**: 将内部双引号转义为 `\"`
- **修改文件**: AntiAIPanel.swift

### 7. BibleModels.swift:879 — comparing non-optional Any to nil
- **错误**: `comparing non-optional value of type 'Any' to 'nil' always returns true`
- **原因**: `character.voiceProfile.value` 是 `Any`（非 Optional），`!= nil` 无意义
- **修复**: 移除 `!= nil` 检查，改用 `!(vpVal is NSNull)` 检查空值
- **修改文件**: BibleModels.swift

### 8. DialogueGeneratorModalView.swift:207,208 — Any has no member stringStringValue
- **错误**: `value of type 'Any' has no member 'stringStringValue'`
- **原因**: `raw.dictionaryValue` 返回 `[String: Any]?`，值类型为 `Any`，不能用 `AnyCodable` 扩展方法
- **修复**: 改用 `(dict["dialogue"] as? String) ?? ""`
- **修改文件**: DialogueGeneratorModalView.swift

### 9. KnowledgeGraphModels.swift:292,300,301,302,310 — Any has no member intValue（5处）
- **错误**: `value of type 'Any' has no member 'intValue'`
- **原因**: `dictionaryValue` 返回 `[String: Any]?`，值类型为 `Any`
- **修复**: 改用 `as? Int` 直接转换
- **修改文件**: KnowledgeGraphModels.swift

### 10. GovernanceCockpitView.swift:310 — GovernanceReport has no member violations
- **错误**: `value of type 'GovernanceReport' has no member 'violations'`
- **原因**: GovernanceReport 模型字段名是 `issues`（非 `violations`）
- **修复**: `report.violations` → `report.issues`
- **修改文件**: GovernanceCockpitView.swift

### 11. GovernanceStore.swift:110 — GovernanceState has no member reports
- **错误**: `value of type 'GovernanceState' has no member 'reports'`
- **原因**: GovernanceState 字段是 `latestReport`（单条），非 `reports`（数组）
- **修复**: 改为从 `state?.latestReport` 包装为数组返回
- **修改文件**: GovernanceStore.swift

### 12. LLMConfigSection.swift:261 — protocol keyword escaping
- **错误**: `keyword 'protocol' does not need to be escaped in argument list`
- **原因**: 调用点使用 `` `protocol`: `` 反引号转义，Swift 调用点参数标签不需要转义
- **修复**: 移除反引号 → `protocol:`
- **修改文件**: LLMConfigSection.swift

### 13. ForeshadowLedgerPanel.swift:217 — iOS 16.4 API on 16.0 target
- **错误**: `'presentationCompactAdaptation' is only available in iOS 16.4 or newer`
- **原因**: 项目 deployment target 是 iOS 16.0，使用了 16.4+ API
- **修复**: 移除 `.presentationCompactAdaptation(.popover)`（非关键 UI 修饰符）
- **修改文件**: ForeshadowLedgerPanel.swift

### 14. DAGToolbarView.swift:196,197,211 — main actor-isolated property（3处）
- **错误**: `main actor-isolated property 'xxx' can not be referenced from a non-isolated context`
- **原因**: `DAGStore` 是 `@MainActor`，其 `@Published` 属性在非隔离上下文不可访问
- **修复**: 给 `DAGStatsSummary.from(dagStore:)` 方法添加 `@MainActor` 注解
- **修改文件**: DAGToolbarView.swift

---

## 额外修复（潜伏错误，被前序错误掩盖）

### 15. StorylineGitGraphView.swift:687-708 — Any 类型调用 AnyCodable 扩展方法
- **原因**: 被 :563 的 guard 语法错误掩盖。修复语法错误后，编译器会检查后续代码
- **错误行**: `dict["rows"]?.arrayValue`, `row.dictionaryValue`, `rowDict["chapter_index"]?.intValue`, `rowDict["snapshots"]?.arrayValue`, `snap.dictionaryValue`, `snapDict["id"]?.stringStringValue`
- **修复**: 全部改用 `as?` 直接类型转换
- **修改文件**: StorylineGitGraphView.swift

### 16. ChapterCastManagerView.swift:273-275 — Any 类型调用 stringStringValue
- **原因**: `candidate.dictionaryValue?["name"]?.stringStringValue` — dictionaryValue 返回 `[String: Any]?`，值是 `Any`
- **修复**: 改用 `(candidate.dictionaryValue?["name"] as? String) ?? "未知"`
- **修改文件**: ChapterCastManagerView.swift

---

## 自检结果

| 检查项 | 结果 |
|--------|------|
| Grep 确认无 SnapshotRollbackResponse 重复声明 | PASS — 仅 SnapshotModels.swift:137 |
| Grep 确认无 EmptyBody 重复声明 | PASS — 仅 OnboardingWizardView.swift:206 |
| Grep 确认无 `.violations` 误用（GovernanceReport） | PASS — QualityGuardrailPanel 用的是 GuardrailCheckResponse 类型 |
| Grep 确认无 `state?.reports` 误用 | PASS |
| Grep 确认无未包裹的 iOS 16.4+ API | PASS — presentationCompactAdaptation 已移除 |
| Grep 确认无 Any 类型误调 AnyCodable 扩展方法 | PASS — 所有残留调用均在 `[String: AnyCodable]` 上 |
| 确认 DAGToolbarView @MainActor 不破坏调用方 | PASS — 调用方 DAGCanvasView.body 是 @MainActor 上下文 |
| 确认 LLMProfile init 声明仍用反引号 | PASS — LLMControlModels.swift:112 `` `protocol`: String `` 保持不变 |

---

## IS_PASS: YES

所有 14 组 CI#29 编译错误 + 2 组潜伏错误已修复。修改涉及 16 个文件，无新增依赖，保持 iOS 16.0 兼容。
