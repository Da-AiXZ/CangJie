# ADR-0001：平台边界与依赖方向

- 状态：接受
- 日期：2026-07-16

## 决策

`CangJieCore` 不依赖 SwiftUI、Security、GRDB、PDFKit、Vision 或其他 Apple-only API。它保存领域状态机、预算、SSE 语义和 checkpoint 恢复决策，并在 Windows SwiftPM 测试。

iPad App 层实现 Keychain、SQLite、生命周期和网络字节流适配器。所有对核心的依赖为单向依赖：

```text
SwiftUI App -> iOS Adapters -> CangJieCore
```

## 原因

用户没有 Mac。平台边界必须允许大多数业务规则在 Windows 快速验证，同时保留 SwiftUI/iPad 原生体验。