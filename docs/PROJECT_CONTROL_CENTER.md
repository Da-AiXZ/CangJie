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

**S2**

Active repair scope: S1 regressions and the S2 Provider runtime.

The previously accepted device baseline remains historical evidence. Exact commit
`7c6b059b3841be6709fb760affed522ec387000f` passes Core and iPadOS CI, but it is
not an accepted candidate until candidate construction and device validation.
S2 is not complete.

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
| S1 cockpit and workspace | Frozen | Main workspace, durable conversation, paging and queue UI exist; persistent-center interaction and accessibility repairs are implemented | Exact-SHA App and UI suites passed | Dynamic Type, VoiceOver, rotation/navigation and scroll retention pending |
| Provider/credential/discovery | Frozen | Credential binding and supported-provider gating are implemented | Exact-SHA Core, App and Keychain probe passed | Real connection setup pending |
| Real Provider generation | Frozen boundary | Durable request/usage and strict finish semantics implemented; stream checkpointing is throttled but coordinator remains MainActor | Deterministic Provider App/UI contracts passed | Real Provider streaming pending |
| Typed Tool and ToolReceipt | Frozen boundary | One authorized tool batch plus no-tool final turn; create premise and read disclosure are host-gated; switch/save remain unadvertised | Exact-SHA App and UI contracts passed | Real Provider tool lifecycle pending |
| Task control and recovery | Frozen boundary | Explicit retry, responseComplete local continuation, unknown-outcome non-retry and terminal turn limit are implemented | Exact-SHA App and UI lifecycle suites passed | Lock, force-quit and notification checks pending |
| Budget governance | Frozen requirement | Per-request output cap and at-most-two automatic Provider turns only | No persisted token/cost/time approval loop | Incomplete |

## Current exact-SHA automation

- Commit: `7c6b059b3841be6709fb760affed522ec387000f`
- Core CI: `30093994570` passed.
- iPadOS CI: `30093994501` passed.
- App XCTest: 423 passed; XCUITest: 22 passed; Keychain isolation probe: 13 passed.
- Local Core: 174 XCTest and 15 Swift Testing passed with 92.35% line coverage.
- Python build/import/candidate contracts: 9 scripts passed.

This proves the checked-in contracts and deterministic fixtures. It does not prove
a real paid Provider response, device VoiceOver focus, physical lifecycle behavior
or candidate identity.

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

Candidate 36 is retained as historical automation evidence only. The current
repair supersedes it for source-level acceptance and does not inherit its CI or
device status.

## Active blocker

S1 still needs Dynamic Type, VoiceOver, rotation/navigation and scroll-retention
device checks. S2 lacks a persisted cumulative token/cost/time budget approval
loop and still needs the complete real Provider / Typed Tool lifecycle on device.

## Immediate queue

1. Add the persisted cumulative budget and approval loop before claiming S2 budget safety.
2. Rerun the exact-SHA Core and iPadOS gates for that budget boundary.
3. Build a new candidate only after those gates are green.
4. Run the physical-device differential script, including real Provider, VoiceOver and lifecycle checks.

## Stable decision routing

Do not restate these contracts here. Read their canonical sources:

- Agent-first product and S0-S6: `IMPLEMENTATION_PLAN.md` sections 2 and 8.
- No-key/deferred setup: `IMPLEMENTATION_PLAN.md` section 2.22.
- Provider lifecycle: `IMPLEMENTATION_PLAN.md` section 7.2.
- Quality and physical-device evidence: `IMPLEMENTATION_PLAN.md` section 9.
- Platform boundaries: `adr/0001-platform-boundaries.md`.
- Persistent center and independent left navigation: `adr/0002-agent-first-workspace.md`.
- Exact approval binding and reconciliation: `adr/0003-exact-approval-binding.md`.
- Host control and model trust boundary: `adr/0004-host-control-and-model-trust-boundary.md`.

Optional design reference, loaded only for Harness decomposition work:
`AGENT_HARNESS_ARCHITECTURE.md`. It is not a stable decision source.

## Historical evidence

The former full control center and P-001 through P-305 log are preserved byte-for-byte at archive creation:

- `history/PROJECT_CONTROL_CENTER-through-2026-07-22.md`
- `history/COMPOUNDING_AND_PITFALLS-through-P305.md`

Rejected physical-device candidate evidence is preserved separately:

- `history/2026-07-23-candidate-34-device-rejection.md`
- `history/2026-07-24-candidate-35-device-rejection.md`

These files are searchable evidence and never current authority. Their indexed hashes are recorded in `history/README.md`.
