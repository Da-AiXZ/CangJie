# T05 — P2 导出/快照/Trace 收尾 + CI 编译 IPA 交付摘要

> 任务：T05 P2 视图收尾、全局路由集成、GitHub Actions 编译 IPA 方案落盘
> 工程师：寇豆码（software-engineer）
> 日期：2026-06-23
> 新增文件：6 | 更新文件：4 | 总计：10

---

## 一、已交付文件清单

### P2 视图（4 文件，前序阶段已落盘，本阶段核查确认）

| # | 文件 | 说明 |
|---|------|------|
| 1 | `Cangjie/Views/Export/ExportView.swift` (206行) | 导出页：格式选择（EPUB/PDF/DOCX/MD）+ 章节范围 + 选项 + ShareLink 分享，调 ExportStore |
| 2 | `Cangjie/Views/Snapshot/CheckpointTimelineView.swift` (224行) | 检查点时间线：垂直 TimelineView，快照/检查点分段，点击详情 Sheet，回滚确认弹窗，调 SnapshotStore |
| 3 | `Cangjie/Views/Snapshot/WorldlineDAGView.swift` (174行) | 世界线 Git 图：自定义 Canvas 泳道布局，节点=检查点，边=父子派生，缩放/平移手势，调 SnapshotStore |
| 4 | `Cangjie/Views/Trace/TraceRecordView.swift` (289行) | AI Trace 溯源：Trace 列表 → span 瀑布图（彩色条宽度=耗时，按 phase 着色），点击 span 详情 Sheet，调 TraceStore |

### CI 编译 IPA 方案（3 文件）

| # | 文件 | 说明 |
|---|------|------|
| 5 | `scripts/build-ipa.sh` (86行) | 从 xcarchive 构建 IPA：提取 .app → ldid fakesign（带 entitlements）→ fakesign framework/dylib → zip Payload。**本阶段修复 entitlements 路径** |
| 6 | `scripts/verify-ipa.sh` (92行，新增) | IPA 验证脚本：检查 .app 结构、可执行文件、部署目标（≤16.x）、entitlements（no-sandbox/network.client）、Info.plist |
| 7 | `.github/workflows/build.yml` (105行，新增) | GitHub Actions workflow：macos-14 + Xcode 15.4 + xcodegen + ldid，objectVersion 77→60 降级，CODE_SIGNING_ALLOWED=NO archive → build-ipa.sh → verify-ipa.sh → upload-artifact |

### 更新文件（3 文件，不算新文件，路由集成）

| 文件 | 更新内容 |
|------|---------|
| `Cangjie/Views/Root/RootView.swift` | `.export/.snapshot/.trace` 占位替换为真实 T05 视图；新增 `.locations` 路由到 LocationGraphView；新增 `SnapshotContainerView` 容器（检查点时间线 + 世界线 DAG 分段切换）；移除已失效的 `placeholderFor` 死代码 |
| `Cangjie/App/AppState.swift` | `SidebarDestination` 新增 `case locations = "地点"` 及对应 iconName（`map.fill`） |
| `Cangjie/Views/Root/SidebarView.swift` | 「设定」分组新增 `.locations` 导航项 |

> 另：`scripts/build-ipa.sh` 修复 1 行（见下方二.3），归入「更新文件」。

---

## 二、路由集成状态

### 2.1 PRD 导航项对齐

架构文档 5.1 节要求 9 个导航项 + P2 的导出/检查点/世界线/Trace。核查结果：

| PRD 导航项 | SidebarDestination | 路由目标 | 状态 |
|-----------|-------------------|---------|------|
| 📚书架 | `.bookshelf` | HomeView | ✅ |
| ✍️工作台 | `.workbench` | WorkbenchView + ContextPanelTabView | ✅ |
| 🤖自动驾驶 | `.autopilot` | AutopilotConsoleView | ✅ |
| 🕸️知识图谱 | `.knowledgeGraph` | KnowledgeGraphView | ✅ |
| 👥人物 | `.cast` | CastGraphView | ✅ |
| 🗺️地点 | `.locations` | LocationGraphView | ✅ **本阶段新增**（原 LocationGraphView 孤立无入口） |
| 📊监控 | `.monitor` | MonitorDashboardView | ✅ |
| 🧩提示词 | `.promptPlaza` | PromptPlazaView | ✅ |
| ⚙️设置 | `.settings` | SettingsView | ✅ |
| 导出（P2） | `.export` | ExportView | ✅ **本阶段接入**（原占位） |
| 检查点（P2） | `.snapshot` | SnapshotContainerView → CheckpointTimelineView | ✅ **本阶段接入**（原占位） |
| 世界线（P2） | `.snapshot` | SnapshotContainerView → WorldlineDAGView | ✅ **本阶段接入**（原占位，与检查点共入口分段切换） |
| Trace（P2） | `.trace` | TraceRecordView | ✅ **本阶段接入**（原占位） |

额外导航项（非 PRD 强制但已实现）：`.bible`（设定集，含人物/世界/地点/时间线/文风 Tab）、`.governance`（叙事治理驾驶舱）。

### 2.2 三栏路由完整性

- **左栏（SidebarView）**：5 分组（创作/设定/分析/工具/系统）共 13 个导航项，全部 `tag(destination)` 绑定 `$appState.sidebarSelection`。✅
- **中栏（RootView.contentColumn）**：`switch appState.sidebarSelection` 穷尽覆盖全部 13 个 case + `.none` 兜底。✅
- **右栏（RootView.detailColumn）**：工作台模式显示 ContextPanelTabView，其余清空。✅
- **小说守卫**：需要小说上下文的导航项（工作台/自动驾驶/设定集/导出/快照/Trace/地点）均检查 `appState.currentNovelId != nil`，未选小说时显示「请先选择一部小说」占位 + 返回书架按钮。✅

### 2.3 build-ipa.sh entitlements 路径修复（关键 Bug）

| 项 | 修复前 | 修复后 |
|----|--------|--------|
| ENTITLEMENTS 路径 | `Cangjie/Cangjie.entitlements`（不存在） | `Cangjie/Resources/Cangjie.entitlements`（实际位置） |

**影响**：修复前 ldid 找不到 entitlements 文件，回退到 `ldid -S`（ad-hoc 无 entitlements 签名），导致 IPA 在 TrollStore 安装后闪退（架构文档 10 节「IPA 装上闪退｜entitlements 没签进去」）。此为阻断性 Bug，已修复。

---

## 三、全局一致性审查

### IS_PASS: YES

| 审查项 | 结果 | 说明 |
|--------|------|------|
| 路由穷尽性 | ✅ | `SidebarDestination` 新增 `.locations` 后，两处穷尽 switch（`AppState.iconName`、`RootView.contentColumn`）均已补 case，无遗漏 |
| 视图接口契约 | ✅ | ExportView/CheckpointTimelineView/WorldlineDAGView/TraceRecordView/LocationGraphView 均为 `@EnvironmentObject appState` 无参 init，RootView 调用签名匹配；环境对象经 NavigationSplitView 子树自动传播至 SnapshotContainerView 内嵌视图 |
| 跨文件引用 | ✅ | RootView 引用的 5 个 T05/T04 视图均已存在；build.yml 引用的 `scripts/build-ipa.sh`、`scripts/verify-ipa.sh` 均已落盘；PRODUCT_NAME="Cangjie" 三脚本一致 |
| CI 脚本一致性 | ✅ | build.yml → build-ipa.sh（archive→output）→ verify-ipa.sh（output/Cangjie.ipa）→ upload-artifact，路径链路贯通；objectVersion 60 / CODE_SIGNING_ALLOWED=NO / IPHONEOS_DEPLOYMENT_TARGET=16.0 与 project.yml 对齐 |
| entitlements 路径 | ✅ | build-ipa.sh 已修正为 `Cangjie/Resources/Cangjie.entitlements`，与实际文件位置一致 |
| 死代码清理 | ✅ | 移除失效的 `placeholderFor`（原 .export/.snapshot/.trace 占位用），无残留引用 |
| iOS 16 兼容 | ✅ | ShareLink/Picker(.segmented)/Canvas/MagnificationGesture/Task 均为 iOS 16 API；无 iOS 17+ 专有 API |
| 无占位符/TODO | ✅ | T05 视图无 `TODO`/`pass`/占位；CI 脚本完整可执行 |

---

## 四、已知限制

### 4.1 T05 新增限制

1. **TrollStore iOS 上限**：目标设备 iOS 16.6.1 是 TrollStore 支持的最高版本，升级 iOS 17+ 后无法侧载（架构文档约束）
2. **fakesign 非 Apple 签名**：CI 使用 `ldid -S` 伪签名，仅 TrollStore 可安装，无法上架 App Store / TestFlight
3. **WorldlineDAGView 泳道简化**：`laneAssignment` 用 `hashValue % laneCount` 分配泳道，非真实分支拓扑；复杂多分支场景下节点可能错位
4. **ExportView 章节范围**：章节范围 Slider 为本地状态（1...200），未与后端实际章节数联动，可能超出真实范围
5. **SnapshotContainerView 重复请求**：检查点时间线与世界线 DAG 各自持有 `@StateObject SnapshotStore`，切换分段时分别重建并重复请求同一接口
6. **无单元测试**：T05 不含测试文件（T01-T05 全阶段无测试），QA 由主理人派发

### 4.2 前序阶段遗留限制（仍生效）

7. **SSE 后台保活**（T01）：iOS 后台 SSE 连接被系统挂起，回前台自动重连
8. **APIEndpoint 覆盖**（T01）：部分次要端点未枚举所有 case，URL 构建基础设施已就绪可按需扩展
9. **ChapterStreamView 轮询**（T03）：200ms Task.sleep 轮询，未用 Combine sink，存在轻微延迟
10. **ChapterElementPanel 提取简化**（T04）：角色/地点提取为简化版，需接后端章节元素 API
11. **QualityGuardrailPanel / ConsistencyReportPanel**（T04）：评分为模拟数据，需接真实 API
12. **DAG Canvas 节点拖拽**（T04）：SugiyamaLayout 静态布局，不支持拖拽动态调整
13. **AppIcon 占位**（T01）：Assets.xcassets 仅占位 Contents.json，无实际图标图片

---

## 五、CI 编译流程说明

```
git push main / 手动 workflow_dispatch
  → macos-14 + Xcode 15.4
  → brew install ldid xcodegen + gem install xcpretty
  → xcodegen generate + sed objectVersion 77→60
  → xcodebuild archive (arm64, Release, CODE_SIGNING_ALLOWED=NO)
  → build-ipa.sh (提取 .app → ldid -S fakesign → zip Payload)
  → verify-ipa.sh (验证结构/签名/部署目标/entitlements/Info.plist)
  → upload-artifact (Cangjie-IPA, 保留 30 天)
  → 浏览器下载 → AirDrop 传 iPad → TrollStore 安装
```

预期 CI 时间：缓存命中约 5-7 分钟，首次约 10-15 分钟。

---

*本阶段完成 T05 全部任务：4 个 P2 视图核查确认、CI 编译 IPA 方案（build-ipa.sh 修复 + verify-ipa.sh + build.yml）落盘、全局路由集成（含 .locations 新导航项）、全局一致性审查 IS_PASS: YES。项目 Swift 文件总数 130 个（T01 23 + T02 42 + T03 28 + T04 34 + T05 4，含本阶段 RootView 内嵌 SnapshotContainerView）。*
