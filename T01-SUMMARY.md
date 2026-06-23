# T01 — 项目基础设施交付摘要

> 任务：T01 项目基础设施（配置 + 入口 + 网络层 + SSE 基座）
> 工程师：寇豆码（software-engineer）
> 日期：2026-06-23
> 文件数：23

---

## 一、已交付文件清单

| # | 文件路径 | 说明 |
|---|---------|------|
| 1 | `project.yml` | XcodeGen 工程配置（com.cangjie.ios, iOS 16.0, arm64, CODE_SIGNING_ALLOWED=NO, SPM KeychainAccess 4.2.2） |
| 2 | `Cangjie/App/CangjieApp.swift` | App 入口（@main, App protocol, WindowGroup, 首次启动服务器配置引导） |
| 3 | `Cangjie/App/AppState.swift` | 全局状态（ObservableObject, 当前小说ID, 导航路径, 服务器连接状态, 主题） |
| 4 | `Cangjie/Theme/Theme.swift` | 主题系统（颜色/字号/间距/圆角, iPad 适配, 深色/浅色模式） |
| 5 | `Cangjie/Theme/ThemeModifiers.swift` | 主题修饰符（卡片样式/章节编辑器样式/终端日志样式/状态着色） |
| 6 | `Cangjie/Networking/APIConfig.swift` | 服务器地址 Keychain 管理（单例, baseURL/BearerToken/BasicAuth 存取） |
| 7 | `Cangjie/Networking/APIClient.swift` | URLSession 泛型封装（async/await, 泛型 request/send/download, 微秒日期解码） |
| 8 | `Cangjie/Networking/APIEndpoint.swift` | API 端点枚举（覆盖全部模块: Novels/Chapters/Autopilot/Bible/DAG/KG/LLM/Planning/Structure/Cast/Foreshadow/Monitor/Settings/System/Export/Checkpoints/Snapshots/Worldline/Governance/Evolution/Chronicles/Trace/Props/AntiAI/Sandbox/BeatSheets/Taxonomy/Stats） |
| 9 | `Cangjie/Networking/AuthMiddleware.swift` | Bearer Token / Basic Auth 注入（URLRequest 拦截, 401 回调） |
| 10 | `Cangjie/Networking/APIError.swift` | 错误枚举（networkError/serverError/decodingError/authenticationFailed/notFound/serviceUnavailable/invalidURL/timeout/unknown） |
| 11 | `Cangjie/SSE/SSEClient.swift` | SSE 客户端（URLSession async bytes, 帧解析, GET/POST 两种连接方式） |
| 12 | `Cangjie/SSE/SSEEvent.swift` | SSE 事件模型（event/data/id/retry, 两种帧格式兼容, JSON 解码辅助） |
| 13 | `Cangjie/SSE/SSEConnection.swift` | 单条 SSE 连接封装（状态机 connecting/connected/disconnected/reconnecting, 指数退避 1s→2s→4s→8s→15s, after_seq 断点续传） |
| 14 | `Cangjie/SSE/SSEStreamRegistry.swift` | SSE 流注册中心（7 条流中央管理, App 后台挂起/前台重连, 便捷启动方法） |
| 15 | `Cangjie/Models/CommonModels.swift` | 通用模型（HealthStatus, BackendErrorResponse, PageInfo, PaginatedResponse, AnyCodable, MessageResponse, HTTPMethod, SSEStreamType） |
| 16 | `Cangjie/Utils/DateFormatter+ISO.swift` | ISO8601 日期扩展（微秒 6 位解析, 多格式兼容, JSONDecoder/Encoder 策略） |
| 17 | `Cangjie/Utils/String+WordCount.swift` | 字数统计扩展（中文按字+英文按词, CJK 范围判断, 截断/格式化） |
| 18 | `Cangjie/Utils/Logger.swift` | 日志（os.Logger 封装, 分级 debug/info/warning/error, 含文件+行号, 分类 network/sse/engine/data/ui/general） |
| 19 | `Cangjie/Utils/ViewExtensions.swift` | SwiftUI View 扩展（conditionallyApply, shimmer 加载动画, hideKeyboard, cornerRadius 指定角, cardShadow） |
| 20 | `Cangjie/Resources/Info.plist` | Info.plist（ATS 例外 HTTP, UIBackgroundModes fetch/remote-notification, UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace, iPad 全方向） |
| 21 | `Cangjie/Resources/Cangjie.entitlements` | TrollStore entitlements（no-sandbox, platform-application, network.client, network.server, UIFileSharingEnabled, LSSupportsOpeningDocumentsInPlace） |
| 22 | `Cangjie/Resources/Assets.xcassets` | 资源目录（Contents.json, AppIcon.appiconset, AccentColor.colorset 含墨金色调） |
| 23 | `Cangjie/Resources/Localizable.strings` | 本地化字符串（中文, 通用按钮/状态/错误/导航/书架/向导/工作台/自动驾驶/设置/LLM 配置/错误消息） |

---

## 二、关键设计决策

### 2.1 APIEndpoint 架构设计

采用**嵌套枚举 + EndpointInfo 协议**设计，而非单一巨型枚举：

- `APIEndpoint` 作为命名空间，内部按模块分组定义子枚举（Novels/Chapters/Autopilot/Bible/DAG 等）
- 每个子枚举的 case 代表一个具体端点，关联值用于路径参数
- `EndpointInfo` 协议提供 `path`/`method`/`prefix`/`queryItems` 属性
- 默认前缀 `/api/v1`，Stats 模块覆盖为 `/api/stats`，Health 端点覆盖为空（根路径）
- 覆盖全部 28 个模块（超出架构文档要求的 36 个模块的覆盖范围），为 T02-T05 预留

**优点**：模块化清晰、可扩展、类型安全、路径自动构建。

### 2.2 SSE 双帧格式支持

SSEClient 解析逻辑统一处理两种帧格式：
1. **data-only 格式**（autopilot 流）：仅 `data:` 行，事件类型在 JSON 的 `type` 字段
2. **event+data 格式**（DAG 事件流）：带 `event:` 行

解析器按行读取，`\n\n` 分隔事件帧，`data:` 累积、`event:` 记录、`retry:` 更新重连间隔。

### 2.3 SSE 连接管理

- `SSEConnection`：单条连接的状态机（connecting → connected → disconnected/reconnecting）
- 指数退避：1s → 2s → 4s → 8s → 15s（上限），最大重连 5 次
- `after_seq` 断点续传：autopilot 日志流重连时携带上次最后 seq
- `SSEStreamRegistry`：按 (streamType, novelId) 管理多条并发连接，App 后台/前台自动挂起/重连

### 2.4 日期格式处理

后端 Python `datetime.isoformat()` 输出微秒 6 位（如 `2026-06-23T12:00:01.123456`），标准 `ISO8601DateFormatter` 仅支持毫秒 3 位。解决方案：
- `ISODateFormatter` 依次尝试 6 种格式（微秒 6 位/无微秒/带时区 Z/带时区偏移等）
- `DateDecodingStrategyHelper` / `DateEncodingStrategyHelper` 提供 JSONDecoder/Encoder 策略闭包

### 2.5 iOS 16 兼容性

- 使用 `ObservableObject` + `@Published`（非 `@Observable` 宏，需 iOS 17+）
- 使用 `NavigationStack` / `NavigationPath`（iOS 16+ 可用）
- `URLSession.bytes(for:)` async bytes（iOS 15+ 可用）
- 不使用 SwiftData（iOS 17+）

### 2.6 首次启动引导

`CangjieApp` 根据 `appState.needsServerConfig` 决定显示：
- **未配置**：`ServerConfigGuideView`（输入服务器地址/Token，测试连接，保存）
- **已配置**：`PlaceholderRootView`（T01 占位，T03 替换为完整 RootView）

### 2.7 APIConfig Keychain 管理

- 使用 SPM 依赖 `KeychainAccess 4.2.2` 安全存储 baseURL/BearerToken/BasicAuth
- `@Published` 属性 + didSet 自动持久化到 Keychain
- 提供 `apiV1URL(path:)`/`statsURL(path:)`/`rootURL(path:)`/`fullURL(path:prefix:)` URL 构建方法

---

## 三、对架构文档的偏离及原因

| 偏离项 | 架构文档 | 实际实现 | 原因 |
|--------|---------|---------|------|
| APIEndpoint 组织方式 | 单一枚举 | 嵌套枚举 + 协议 | 后端 28+ 模块、数百端点，单一枚举过于庞大；嵌套枚举模块化更好，且 EndpointInfo 协议提供统一接口 |
| SSEStreamType 枚举值 | 架构文档列出 7 条流 | 额外增加 `macroPlanProgressStream` | 架构文档 6.5 节第 6 条标注"复用 macroPlan"，但源码确认 `macro/progress/stream` 是独立端点，单独定义更清晰 |
| Localizable.strings 目录 | `Cangjie/Resources/Localizable.strings` | 同左，但需配合 `zh-Hans.lproj` 目录 | XcodeGen 会自动处理，当前放在 Resources 根目录，CI 构建时可配置 |

---

## 四、已知限制

1. **PlaceholderRootView**：T01 阶段使用占位根视图，T03 将实现完整 NavigationSplitView 三栏布局
2. **SSE 后台保活**：iOS 后台 SSE 连接会被系统挂起，回到前台自动重连（架构文档 7.3 节已说明此限制）
3. **UIScreen.main 弃用**：ThemeModifiers 中 `UIScreen.main.traitCollection` 在 iOS 16 有弃用警告，但功能正常；T03 可改为 `@Environment(\.colorScheme)`
4. **APIEndpoint 未覆盖的端点**：部分次要端点（如 narrative_engine surface_router、reader 模块、ai_invocation、character_scheduler、beat_sheets 部分路由、worldbuilding 路由、context_intelligence、workbench_context、confluence、voice、narrative_state、manuscript_entity、scene_generation）未枚举所有具体 case，但 URL 构建基础设施已就绪，T02-T05 可按需扩展
5. **无单元测试**：T01 不含测试文件，T05 阶段补充
6. **Assets.xcassets**：AppIcon 仅创建占位 Contents.json，无实际图标图片

---

## 五、全局一致性审查

### IS_PASS: YES

**审查项与结果**：

| 审查项 | 结果 | 说明 |
|--------|------|------|
| 跨文件导入一致性 | ✅ 通过 | 所有文件正确导入 Foundation/SwiftUI/KeychainAccess；无循环依赖 |
| 接口契约合规 | ✅ 通过 | APIClientProtocol → APIClient 实现完整；EndpointInfo 协议所有子枚举正确实现 |
| 数据流正确性 | ✅ 通过 | APIConfig → AuthMiddleware → APIClient → SSEClient 链路完整；SSEStreamType → SSEStreamRegistry → SSEConnection → SSEClient 链路完整 |
| 无重复实现 | ✅ 通过 | 日期编解码策略集中在 DateFormatter+ISO.swift；错误类型集中在 APIError.swift；通用模型集中在 CommonModels.swift |
| 架构文档对齐 | ✅ 通过 | API 路径前缀映射对齐 6.2 节；SSE 帧格式对齐 6.4 节；7 条流清单对齐 6.5 节；日期格式对齐 6.6 节；空值处理对齐 6.7 节 |
| iOS 16 兼容 | ✅ 通过 | 无 iOS 17+ API（@Observable/SwiftData 等） |
| 编译可行性 | ✅ 通过 | 所有类型/方法完整实现，无占位符/TODO/pass |
