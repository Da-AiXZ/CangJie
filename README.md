# CangJie

CangJie is an agent-first, local-first iPad application for producing long-form Simplified Chinese web novels. It is not a generic chat client and not a form-driven writing tool.

> Conversation is the operating surface; the novel-production system is the body.

The LLM interprets intent and proposes plans. Only versioned typed tools may create projects, write settings, generate chapters, pause work, query state, update canon, or freeze approved prose.

## Product shell

- Center: persistent Agent conversation and command surface.
- Left: an independent `NavigationStack`. Tapping Novel Projects pushes a dedicated page inside the left region; it never expands a project tree in place and never replaces the center conversation.
- Right: collapsed-by-default artifacts, approvals, diffs, evidence, and run receipts.
- Workbenches remain available as secondary pages and tools, not the startup flow.

## Current status

M0 engineering feasibility is validated on the user's iPad: TrollStore installation, launch, basic persisted input, restart, and no immediate crash. The repository is entering **M1: First-Chapter Agent Vertical Slice**. No M1 behavior is claimed complete until its tests and device acceptance pass.

## Authoritative documents

1. [Implementation plan](docs/IMPLEMENTATION_PLAN.md) - the only active plan.
2. [Project control center](docs/PROJECT_CONTROL_CENTER.md) - current operational truth.
3. [Compounding and pitfalls log](docs/COMPOUNDING_AND_PITFALLS.md) - mistakes and prevention gates.
4. [Architecture decisions](docs/adr/) - durable scoped decisions.
5. [M0 validation](docs/M0_VALIDATION.md) - feasibility evidence.

`docs/ROADMAP.md` is retired and must not be recreated or cited as an active plan.

## Technology

SwiftUI/iPadOS 16.6+, Swift 5 language mode, `CangJieCore`, GRDB/SQLite, Keychain, URLSession/SSE, Windows SwiftPM tests, GitHub Actions, and ad-hoc/fakesigned TrollStore IPA packaging without Apple Developer signing.

## Local core tests

```powershell
scripts\windows\test-core.cmd
```

## Rights

Source is visible, but no open-source license is granted. See `NOTICE.md`.
