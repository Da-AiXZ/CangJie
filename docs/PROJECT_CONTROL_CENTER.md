# CangJie Project Control Center

- Authority: compact operational dashboard
- Updated: 2026-07-24
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
| Real Provider generation | Frozen boundary | Streaming and real Tool execution passed on device; replacement keeps sent cancellation unknown and non-retryable | Exact-SHA Core/App/UI automation passed | Candidate 36 pending device |
| Provider-backed AgentRun | Frozen boundary | Current-Conversation and global-primary task scopes are separated | Exact-SHA Core/App/UI automation passed | Candidate 36 pending device |
| Typed Tool and ToolReceipt continuation | Frozen boundary | Real project creation and exact receipt passed on Candidate 35 before later recovery failure | Existing device evidence plus exact-SHA regression passed | Candidate 36 pending device |
| Task control, queue and shared projection | Frozen boundary | Global primary projection, cross-Conversation controls and explicit unknown-task closure do not retry the original request | Complete offline/queue/pause XCUITest passed | Candidate 36 pending device |
| Lifecycle, offline recovery and notifications | Frozen boundary | Fresh network snapshots, phase-aware background persistence, truthful streaming-cancellation unknown state and a finite UIKit background lease are implemented | Complete background terminate/relaunch XCUITest passed | Candidate 36 pending device |

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

## Pending S2 Candidate 36

- Commit: `e7fdedc8c52a0aeb8b33a2138ea227f3c0f43f94`
- Version/build: `1.0 (36001)`
- Candidate Set ID: `ceb0a2a30931fa4cbd0cdb5d8043889c2352e62dc26f1cca33c5e9c8c03c8c71`
- Core CI: `30044654032` passed
- iPadOS CI: `30044653983` passed
- Apple tests: 402 App XCTest, 22 App XCUITest, 13 Probe XCTest and 1 Probe XCUITest passed
- Candidate workflow: `30045964946` passed
- Main IPA: `CangJie-M0.ipa`
- Main SHA-256: `0f2a9c4680db1421757d9ba686414901bdabebe068af1819f0b504d1aef1c901`
- Probe IPA: `CangJie-Keychain-Isolation-Probe.ipa`
- Probe SHA-256: `abdb00426648a56d945c892f2c6df5b250597e7a512f73bdf5dc436a9788c514`
- Artifact directory: `artifacts/CangJie-S2-run-30045964946/`
- Acceptance: blocked pending exact-set TrollStore device validation.

The macOS workflow independently verified strict ldid signing and distinct
Main/Probe entitlement groups. Windows metadata-only verification independently
matched the manifest, compiled identities, archive structure, IPA hashes and
exported signed-entitlement files. Neither result substitutes for the device gate.

## Rejected S2 Candidate 34

- Commit: `f4fa6172ed70590493134c6bdef3d60282988f8e`
- Version/build: `1.0 (34001)`
- Candidate Set ID: `0b7e5f2911a489ae0fa5da9c1e7a9d405317e847dacb30c7f797c5b222dd51a0`
- Core CI: `29992029384` passed
- iPadOS CI: `29992029418` passed
- Apple tests: 381 App XCTest, 20 App XCUITest, 13 Probe XCTest and 1 Probe XCUITest passed
- Candidate workflow: `29993609075` passed
- Main IPA: `CangJie-M0.ipa`
- Main SHA-256: `207c11e7259d022e7ea383981363484f271033bf7b0bb9886006c9458442acde`
- Probe IPA: `CangJie-Keychain-Isolation-Probe.ipa`
- Probe SHA-256: `13d49379fa8b1af0a06593053af7a99a2e77905773b21ad87794638f94763351`
- Artifact directory: `artifacts/CangJie-S2-run-29993609075/`
- Device result: rejected on 2026-07-23. Keychain isolation and basic Provider/tool execution passed, but notification-permission inactivity interrupted a live stream; pending tasks reopened a stale connection card; offline and pause flows became stuck; the composer was locked; and task notifications were not reliably delivered.
- Acceptance: rejected. This candidate cannot complete S2.

The downloaded manifest and local SHA-256 verification match the exact workflow
identity. The macOS workflow independently verified ldid signatures and the
separate Main/Probe entitlement groups. Windows cannot repeat `codesign`; the
workflow result remains the authority for signed-entitlement verification, but
artifact integrity does not override the failed device behavior gate.

## Rejected S2 Candidate 35

- Commit: `ca309143608525432fd2d28a7db48e6ee98b64a5`
- Version/build: `1.0 (35001)`
- Candidate Set ID: `1eac1b4ff7372805e4a75ae28248635d84a7004de850da6f687b78a91b1ff64e`
- Core CI: `30025029331` passed
- iPadOS CI: `30025028405` passed
- Apple tests: 399 App XCTest, 20 App XCUITest, 13 Probe XCTest and 1 Probe XCUITest passed
- Candidate workflow: `30026256106` passed
- Main IPA: `CangJie-M0.ipa`
- Main SHA-256: `e32cf0e124d64c3bcd9842a080aed4b13e6ef73b2933c84550193123db2a6559`
- Probe IPA: `CangJie-Keychain-Isolation-Probe.ipa`
- Probe SHA-256: `1c73681407a701135d89dc87881aa903e1e3f3aad3405a10db798153fe5d1e74`
- Artifact directory: `artifacts/CangJie-S2-run-30026256106/`
- Device result: rejected on 2026-07-24. Isolation, exact build identity,
  notification-sheet streaming and real project ToolReceipt passed. Offline
  submission did not appear on the global AI Tasks surface, reconnect exposed no
  explicit send confirmation, the originating Conversation remained blocked,
  a second Conversation showed obsolete S1 copy and only queued, and an explicit
  pause exposed no resume action.

The workflow independently verified ldid signatures and distinct Main/Probe
entitlement groups. Local SHA-256 values match the manifest exactly, but artifact
integrity and passing automation do not override the failed device behavior gate.
Candidate 35 cannot complete S2.

## Active blocker

Candidate 36 has passed exact-SHA Core, App XCTest, complete App XCUITest, Probe
and paired signing/artifact gates. The remaining blocker is physical-device
validation of real NWPathMonitor transitions, notification permission and delivery,
TrollStore Keychain isolation, lifecycle interruption and the full real Provider /
Typed Tool continuation. S2 remains unaccepted until that differential script passes.

## Immediate queue

1. Install both exact-SHA Candidate 36 IPA files from the same artifact directory.
2. Verify build identity and the Main/Probe isolation canary before S2 behavior checks.
3. Re-run the differential physical-device script for real Provider/tool execution, notification interruption, offline confirmation, cross-Conversation queue control, pause/unknown handling and force-quit recovery.
4. Record the exact device result; accept S2 only if every required step passes.

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
