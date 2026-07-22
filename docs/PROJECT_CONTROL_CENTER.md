# CangJie Project Control Center

- Authority: compact operational dashboard
- Updated: 2026-07-23
- Repository: `F:\project\CangJie`
- Remote: `https://github.com/Da-AiXZ/CangJie`, branch `main`
- Authority boundary: single source for current implementation, verification, blockers and queue

This file answers four questions only:

1. What milestone is active?
2. What exact candidate is accepted or pending?
3. What blocks progress?
4. What work is next?

Stable product requirements belong in `IMPLEMENTATION_PLAN.md`; architecture belongs in ADRs; reusable safeguards belong in `COMPOUNDING_AND_PITFALLS.md`; detailed execution history belongs in `docs/history/`.

## Current milestone

**S2 - 真正可操作软件的 Agent**

S1 is accepted. S2 is not complete.

S2 must prove this exact vertical loop:

```text
no current connection
-> persist the original Conversation-scoped request
-> explicit Provider / Key / Endpoint
-> bounded connection verification and model discovery
-> explicit user-selected model and named current connection
-> real Provider request with durable identity and stream state
-> Provider-backed AgentRun
-> versioned Typed Tool project creation/status query
-> exact ToolReceipt
-> atomic pending-intent consumption
-> force-quit reconciliation and continuation
```

Formal prose generation is outside S2.

## Status summary

| Area | Decision | Implementation | Automation | Device |
|---|---|---|---|---|
| S1 cockpit and workspace | Frozen | Complete | Passed | Accepted |
| Provider/credential/discovery hardening | Frozen | Complete for slice | Passed | Accepted on Candidate 32 |
| Central model-connection setup | Frozen | Complete for slice | Passed | Accepted on Candidate 33 |
| Real Provider generation | Frozen boundary | OpenAI-compatible streaming transport implemented for DeepSeek, OpenAI and OpenRouter | Passed on `313165a` | None |
| Provider-backed AgentRun | Frozen boundary | Durable request, stream, usage and unknown-outcome projection implemented | Passed on `313165a` | None |
| Typed Tool and ToolReceipt continuation | Frozen boundary | Strict project create/status execution, exact receipt and Provider continuation are complete in the coordinator slice; central Conversation wiring remains | Core and iPadOS passed on `d355331` | None |
| Force-quit recovery of the real S2 loop | Frozen boundary | Not implemented | None | None |

## Last accepted device baseline

- Commit: `cb9b4ebd536ef6dd02c6448f179c4c1f1f145841`
- Version/build: `1.0 (33001)`
- Candidate Set ID: `06d268b604c8eefee21814bef8b41e0bdd46226ff52b18ed7ad9508d6b6e19a7`
- Core CI: `29916742888` passed
- iPadOS CI: `29916742840` passed
- Candidate workflow: `29918215122` passed
- Main IPA: `CangJie-M0.ipa`
- Main SHA-256: `1ab74cc072cda4c510ca7761225f9a2391df6c2c075f66534087691cd4777530`
- Probe IPA: `CangJie-Keychain-Isolation-Probe.ipa`
- Probe SHA-256: `70ce44ec5e4786a7b1829ca8d8a381d142ee22e2ebb0046e93a531fcae2ca084`
- Artifact directory: `artifacts/CangJie-S2-run-29918215122/`
- Device result: user reported no problem after testing this candidate on 2026-07-22.

This is the accepted central connection-setup baseline, not S2 completion.

## Candidate 33 scope

Implemented and automated:

- atomic first pending-intent Conversation turn;
- one unconsumed pending intent per Conversation;
- Provider selection and official/custom endpoint presentation;
- transient Key entry and bounded discovery;
- explicit model selection and named current connection;
- Keychain/SQLite journal persistence and fresh verification;
- fail-closed Custom transport behavior;
- Conversation switching and lifecycle rehydration;
- explicit settings management detached from hidden Conversation intent;
- nested setup-controller observation at the SwiftUI root;
- independently scrollable long model catalog;
- fixture-free relaunch restoration of request, connection and model.

Explicitly absent:

- creative Provider request or streaming completion;
- Provider-backed `AgentRun`;
- Typed Tool authorization/execution;
- `ToolReceipt`;
- consumption of the pending intent;
- formal prose generation.

## Active blocker

No external blocker. The Provider, AgentRun and governed project Tool/ToolReceipt
coordinator slices have passed exact-SHA automation. S2 remains incomplete because
the coordinator is not yet wired into the central Conversation and cancellation,
unknown-outcome reconciliation, lifecycle recovery and force-quit recovery have not
yet passed as one user-visible loop.

## Immediate queue

1. Wire `ProviderAgentRunCoordinator` into the central Conversation using the durable pending intent and verified current connection.
2. Project real streaming into the Conversation, execute strict Tool calls, return exact Tool results and consume the pending intent only with the durable final continuation.
3. Complete cancellation, lifecycle persistence and five-state recovery without duplicate Provider requests, tools, receipts, usage or intent consumption.
4. Prove unknown-outcome reconciliation and force-quit recovery through focused tests and exact-SHA Apple CI.
5. Build the next candidate only when the complete S2 loop becomes device-observable.

## Stable decision routing

Do not restate these contracts here. Read their canonical sources:

- Agent-first product and S0-S6: `IMPLEMENTATION_PLAN.md` sections 2 and 8.
- No-key/deferred setup: `IMPLEMENTATION_PLAN.md` section 2.22.
- Provider lifecycle: `IMPLEMENTATION_PLAN.md` section 7.2.
- Quality and physical-device evidence: `IMPLEMENTATION_PLAN.md` section 9.
- Platform boundaries: `adr/0001-platform-boundaries.md`.
- Persistent center and independent left navigation: `adr/0002-agent-first-workspace.md`.
- Exact approval binding and reconciliation: `adr/0003-exact-approval-binding.md`.
- Full Agent Harness architecture: `AGENT_HARNESS_ARCHITECTURE.md`.

## Non-negotiable delivery gates

- Model text cannot authorize or prove a side effect.
- Typed Tool and ToolReceipt identities are exact and versioned.
- Credentials are Keychain-only and bound to connection, Provider, destination and generation evidence.
- Custom endpoints are HTTPS-only and fail closed against unsafe resolution and redirects.
- Published migrations are immutable; new schema changes use ordered migrations.
- Unknown outcomes reconcile before retry.
- `CangJieCore` remains platform-neutral.
- Exact-SHA Apple CI is authoritative for Apple semantic compile and UI behavior.
- IPA acceptance binds commit, build, Candidate Set ID, artifact hashes, signature and entitlements.
- TrollStore/Keychain/lifecycle claims requiring hardware remain unaccepted until device evidence exists.
- `cc.zip` remains clean-room-only reference material.

## Path-aware validation

| Changed boundary | Minimum local evidence | Remote evidence |
|---|---|---|
| Docs only | links, anchors, current-state consistency, archive hash, diff check | none unless workflow policy triggers |
| Core | focused tests and relevant full coverage | Core CI |
| App/SwiftUI | parse and focused contracts | iPadOS XCTest/XCUITest |
| Credentials/network/migration/recovery | focused tests plus full security contracts | Core and iPadOS CI |
| Signing/candidate/device-visible behavior | artifact contracts and manifest checks | paired macOS workflow and device gate |

Full suites remain mandatory at their actual risk boundary. Unrelated full suites are not repeated merely because a documentation or isolated UI assertion changed.

## CI repair protocol

1. Read the complete failed-step log.
2. Separate compilation, App XCTest, XCUITest, Probe and packaging failures.
3. Identify the first causal defect class.
4. Enumerate every occurrence proven by the same evidence.
5. Repair that class in one bounded slice.
6. Run the minimum deterministic local gates.
7. Push and inspect replacement exact-SHA CI.
8. Do not treat a passing subset as full acceptance.

## Documentation update policy

Update this file only when one of these changes:

- current milestone;
- implementation status of a milestone capability;
- last accepted or currently pending candidate;
- active blocker;
- immediate queue;
- required acceptance gate.

Update `COMPOUNDING_AND_PITFALLS.md` only when a failure yields a new reusable cross-task rule or an existing rule is materially wrong. Put individual commit logs, CI IDs, rejected experiments and superseded status under `docs/history/`.

## Historical evidence

The former full control center and P-001 through P-305 log are preserved byte-for-byte at archive creation:

- `history/PROJECT_CONTROL_CENTER-through-2026-07-22.md`
- `history/COMPOUNDING_AND_PITFALLS-through-P305.md`

They are searchable evidence and never current authority. Their snapshot hashes are recorded in `history/README.md`.
