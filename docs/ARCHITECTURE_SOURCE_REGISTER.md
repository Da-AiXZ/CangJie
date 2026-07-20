# 仓颉 Agent Harness 架构来源登记

- 状态：`ACTIVE EVIDENCE REGISTER`
- 登记日期：2026-07-18
- 适用范围：Context、Prompt、Agent Loop、Tools、Session、恢复、Subagent、Hooks、权限和治理
- 关联基线：`docs/AGENT_HARNESS_ARCHITECTURE.md`

本文只登记来源、允许提取的非表达性工程原则和禁止边界，不保存第三方源码、私有 Prompt、Schema、字符串或目录映射。

## 1. 官方公开来源

| 来源 | 类型 | 用于核验 | 禁止推断 |
|---|---|---|---|
| `https://code.claude.com/docs/en/how-claude-code-works` | Anthropic 官方文档 | Gather context → take action → verify results 的公开 Agent 行为；工具、环境反馈和循环 | Claude Code 完整私有状态机或内部源码 |
| `https://code.claude.com/docs/en/memory` | Anthropic 官方文档 | 持久指令、项目上下文和会话上下文的公开边界 | 直接复制 CLAUDE.md 规则或内部压缩实现 |
| `https://code.claude.com/docs/en/hooks` | Anthropic 官方文档 | 生命周期事件和 Hook 概念 | 在仓颉首版开放任意 Shell/脚本 Hook |
| `https://code.claude.com/docs/en/sub-agents` | Anthropic 官方文档 | Subagent 独立上下文、工具和职责的公开模式 | 复制官方内置 Agent Prompt 或命名 |
| `https://platform.claude.com/docs/en/agent-sdk/overview` | Anthropic 官方文档 | Agent SDK 的 session、tools、permissions、streaming 和宿主集成 | 声称 SDK 等于 Claude Code 完整生产核心 |
| `https://platform.claude.com/docs/en/agent-sdk/sessions` | Anthropic 官方文档 | Session、resume 和持久会话概念 | 直接照搬具体存储实现 |
| `https://platform.claude.com/docs/en/agent-sdk/hooks` | Anthropic 官方文档 | SDK 生命周期回调 | 任意代码执行权限 |
| `https://platform.claude.com/docs/en/agent-sdk/subagents` | Anthropic 官方文档 | 子 Agent 声明与隔离 | 复制角色 Prompt |
| `https://platform.claude.com/docs/en/agent-sdk/custom-tools` | Anthropic 官方文档 | Typed/custom tool 的公开接口思想 | 复制官方具体 Schema 或签名 |
| `https://github.com/anthropics/claude-code` | Anthropic 官方 GitHub | README、插件、示例、脚本和公开发布材料 | 该仓库包含完整 Claude Code 生产核心源码 |
| `https://github.com/anthropics/claude-agent-sdk-python` | Anthropic 官方 GitHub，MIT | 公开 SDK wrapper 的 sessions、streaming、interrupt、permissions、hooks 和 agent definitions | SDK wrapper 代表私有 CLI 全部实现 |
| `https://github.com/anthropics/claude-agent-sdk-typescript` | Anthropic 官方 GitHub | TypeScript SDK 的公开能力合同 | 复制仓颉 Swift 接口命名或结构 |

本地只读研究快照：

```text
F:\project\Novel-Agent\_claude_architecture_research\claude-agent-sdk-python
commit: 94ff18e08551e1b96ba2668d90eacfedd92a3a55
```

该快照只用于核对官方公开 SDK 行为。仓颉实现必须使用原创 Swift 类型、测试和目录组织。

## 2. `cc.zip` 风险登记

```text
source: F:\project\Novel-Agent\cc.zip
sha256: 371146d9df915c9995928a8eb84539fde76f619ef791514b443a4c69e35f4c65
package metadata: private / UNLICENSED / self-described leaked, version 0.0.0-leaked
status: non-official, provenance incomplete, implementation use forbidden
```

允许保留的只有高层、非表达性结论：成熟 Agent 需要宿主循环、Context/Prompt 编译、Typed Tools、权限、Session、恢复、Subagent 和可观测性等独立工程层。

禁止：

- 复制、改写或翻译源码；
- 复制 Prompt、Schema、字符串、注释、测试、目录结构、接口签名或命名组合；
- 将包内容放入仓颉仓库、构建缓存、测试夹具、Prompt 资产或实现 Agent 上下文；
- 声称该包是 Anthropic 官方开源发布；
- 用“参考 Claude Code”掩盖近似实现。

## 3. 后续实现隔离规则

1. 实现任务只读取本登记、官方公开来源、仓颉产品文档和 ADR，不再读取 `cc.zip`。
2. 每个 Harness ADR 写明：官方公开证据、仓颉产品需求、原创决定、替代方案和测试证据。
3. Swift 类型名、目录、协议、状态机、Prompt 和测试从仓颉问题域独立命名。
4. 提交前扫描私有包独特字符串、Prompt、Schema 和目录相似性；发现疑似相似内容即停止并重写。
5. 该流程是风险控制，不构成法律意见，也不对外宣传为经过第三方认证的 clean-room 实现。

## 4. 当前能诚实声称的结论

- 仓颉参考了 Claude Code 和 Claude Agent SDK 的**官方公开 Agent 工程原则**；
- 仓颉的小说领域 Context、故事治理、Writer Lease、Evidence Index、分支/叙事时间隔离、审批、费用和 checkpoint 设计是原创产品架构；
- 目前完成的是架构基线和实施计划，不是 H0–H5 已实现；
- 后续每项能力必须通过 TDD、失败注入和真机/CI 证据后，才能标记为已实现。