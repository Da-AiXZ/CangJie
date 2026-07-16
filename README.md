# 仓颉（CangJie）

仓颉是一款面向简体中文男频升级成长类网络小说的个人 AI 创作 Agent。它围绕正典记忆、层级规划、受控生成、作者校准和可审计恢复构建，而不是通用聊天或简单续写器。

## 当前阶段

当前仓库只实施 **M0：可行性与安装链验证**，目标是证明：

1. `CangJieCore` 可在 Windows 通过 SwiftPM 构建和测试；
2. iPadOS 16.6+ SwiftUI App 可在 GitHub Actions 编译；
3. App 可在本地 SQLite 保存草稿，在后台切换前写入 checkpoint，恢复后不丢数据；
4. API 凭证只进入 Keychain；
5. 设备 `.app` 可经 ad-hoc 签名后封装为 TrollStore 可尝试安装的 IPA。

M1–M5 的功能不会在 M0 中伪装完成。详见 `docs/ROADMAP.md`。

## 技术栈

- SwiftUI，iPadOS 16.6+
- Swift 5 语言模式；Swift Package tools version 5.10
- 平台无关 `CangJieCore`
- GRDB/SQLite（仅 App 层）
- XcodeGen 生成 Xcode 工程
- Windows SwiftPM 测试 + GitHub Actions macOS/iOS 构建

## 本地核心测试

```powershell
swift test --enable-code-coverage
```

## 生成 Xcode 工程

在 macOS 安装 XcodeGen 2.45.4 后：

```bash
xcodegen generate --spec project.yml
```

## 权利声明

本仓库源码可见，但当前未授予任何开源许可证。除法律明确允许的情形外，不得复制、修改、再分发或用于商业产品。详见 `NOTICE.md`。