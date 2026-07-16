# M0 Windows 与 iPad 验证手册

## 已安装的 Windows 工具

- Git：`F:\Git`
- Visual Studio Build Tools 2022：`F:\DevTools\VisualStudio\2022\BuildTools`
- Swift 6.3.3：`F:\DevTools\Swift`
- Swift 平台 SDK：`F:\DevTools\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk`
- SwiftPM/Clang 缓存：`F:\DevTools\CangJie`

Swift 安装器原本写入用户 LocalAppData；为节省 C 盘空间，完整 Swift 目录已移动到 F 盘，并在原路径保留目录联接，避免破坏安装器升级/卸载记录。

## 本地测试

在资源管理器或终端运行：

```cmd
scripts\windows\test-core.cmd
```

当前 M0 Core 要求：

- 19 个测试全部通过；
- Core 行覆盖率至少 90%；
- App/GRDB/Keychain/UI 测试留给 macOS GitHub Actions。

## M0 文件型 checkpoint 的边界

`FileCheckpointStore` 只用于 Windows 平台无关 Core 的 M0 持久化与幂等恢复测试。同一个文件路径在同一进程中必须只有一个 store 实例；它不承担跨进程或多实例并发写入。iPad App 的正式 checkpoint 存储使用 GRDB/SQLite 事务、WAL 和唯一约束，M1 以后不以 JSON 文件 store 作为生产仓储。
## GitHub Actions 前置条件

远程仓库创建前需要确认：

1. GitHub 用户名或目标组织；
2. 仓库 `CangJie` 是否仍为公开；
3. 本机 GitHub CLI 登录方式，或由用户在网页创建空仓库后提供 remote URL。

远程 workflow 不会在未明确批准前触发。

## iPad 真机 M0 清单

1. 从 Actions artifact 下载 IPA、SHA-256 和 build manifest；
2. 校验 SHA-256；
3. 用 TrollStore 安装；
4. 启动 App，输入一段草稿并保存；
5. 手动创建 checkpoint；
6. 切后台、锁屏、返回；
7. 强退重开，确认草稿和 checkpoint 序号恢复；
8. 写入一个临时 Keychain 测试值，确认 App 重启后仍显示“已保存”；
9. 使用自有 HTTPS SSE 端点验证分段输出和取消；
10. 记录 iPad 型号、iPadOS 16.6.1、IPA SHA、commit 和 workflow run ID。
