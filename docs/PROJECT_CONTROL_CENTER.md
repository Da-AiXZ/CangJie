# CangJie Project Control Center

- Authority: current operational truth
- Updated: 2026-07-16
- Repository: `F:\project\CangJie`
- Remote: `https://github.com/Da-AiXZ/CangJie`, branch `main`

## Product and UI decision

CangJie is agent-first: persistent center conversation controls a governed novel engine through typed tools. The left region has an independent `NavigationStack`; Novel Projects pushes a dedicated page with back navigation, never an in-place tree and never a center reset. The right artifact/approval drawer is collapsed by default. Workbenches are secondary.

## Authority order

`IMPLEMENTATION_PLAN.md` -> this file -> `COMPOUNDING_AND_PITFALLS.md` -> ADRs -> `M0_VALIDATION.md`. `ROADMAP.md` is retired.

## Current milestone

M1 First-Chapter Agent Vertical Slice. Commit `648c8da` contains the M1-B recoverable runtime slice. Core CI is green; iPadOS CI exposed one regression-test fixture ordering error. The current worktree fixes that test contract and is not yet a validated M1-B exit.

```text
open -> restore conversation/session/run/messages -> center conversation
-> project.create transaction -> durable project plus scoped receipt
-> one-question interview -> durable session and messages
-> openingPlan.save transaction -> waitingApproval artifact plus receipt
-> restart -> restore the same conversation and approval state
-> openingPlan.approve transaction -> approved artifact plus receipt
```

## Validated baseline

Device-accepted M0 baseline:

```text
commit 7b2658caf78fa21d4cbf28e0b8851eb3bcfec23b
Build IPA 29500269591 | iPadOS CI 29500271632 | Core CI 29500273381
IPA F:\project\CangJie\artifacts\CangJie-M0-run-20\CangJie-M0.ipa
SHA-256 2092cfb5fe94b463c453ca25e6107a12de1d77e8be8309c85ee027f8863d62ef
```

User confirmed TrollStore install, launch, immediate restart persistence, and no immediate crash for that M0 artifact.

Latest committed software evidence:

```text
commit 648c8da feat: add recoverable agent runtime
Core CI 29526906495: success
iPadOS CI 29526906476: failure
```

The iPadOS run compiled the App and executed 18 App tests; 17 passed. Its first and only real failure was `AppViewModelTests.testApprovedPlanReconcilesAnInterruptedApprovalRun` at line 236. The test inserted an approved artifact with epoch timestamp `701`, but the original waiting-approval plan had a current wall-clock `updatedAt`. Because production correctly selects `latestArtifact` by `updatedAt DESC`, the older approved fixture could not supersede the plan. The fix makes the approved fixture exactly one second newer than `plan.updatedAt`; production ordering semantics are unchanged.

Current verification remains partial until the corrective commit passes iPadOS CI and the Agent-first UI smoke test. M1 device acceptance, complete Keychain tests, real Provider SSE/cancel/reconcile, exact plan/budget approval, bible confirmation, generation, canon, import, and serial flow remain unproven.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Immediate queue

1. Commit and push the artifact-version test fixture correction after minimum deterministic checks.
2. Run App database/view-model/restart tests and Agent-first UI smoke test in the new iPadOS CI run.
3. If CI fails, inspect and fix only the first causal error; do not weaken production ordering or safety gates.
4. When Core and iPadOS CI are green, trigger the TrollStore IPA workflow and verify its manifest and SHA-256.
5. Pause only at the physical-device acceptance gate with a complete install and test script.
6. Do not enter M1-C until exact revision/budget approval and approval invalidation are implemented and verified.

## Change log

### 2026-07-16 Agent-first reset

Retired old roadmap; corrected left navigation; established runtime/tool/canon/clean-room baseline. The first write was corrupted into question marks and repeated blocks, so the documents were rewritten in ASCII-dominant UTF-8 and an encoding gate was added. Documentation baseline commit: `bdf0056`. Post-push Actions are checked separately after this entry.

## 2026-07-16 M1-A implementation checkpoint

Implemented the first real vertical slice in `App/CangJieApp/ContentView.swift`, `AppViewModel.swift`, and `AppDatabase.swift`: persistent center conversation shell, independent left navigation to Novel Projects, collapsed artifact drawer, `novelProject` migration, and project create/list persistence. Added AppDatabase/AppViewModel tests. Windows `swift test` passed all 35 core tests. iOS App compilation and UI tests remain pending GitHub Actions.

## Continuous execution rule

Progress summaries are informational checkpoints, not pauses. After reporting completed work and the next action, continue automatically. Stop only when a major milestone has produced a candidate IPA requiring physical-device installation/acceptance, or when required user input is genuinely unavailable. At a device gate, provide artifact source, hash, install steps, test script, expected results, and rollback notes.


## 2026-07-16 M1-B runtime recovery worktree checkpoint

Version nature: committed as `648c8da`; partial M1-B implementation under CI correction, not a release, candidate IPA, or validated milestone.

Included:

- Added a recoverable `AgentRuntime` that restores a stable conversation snapshot containing messages, projects, session state, the scoped opening plan, the latest receipt, and the latest run.
- Added durable `agentConversation`, `agentMessage`, `agentSession`, and `agentRun` records. Session state carries focused project scope, interview step, current question, and interview answers.
- Scoped artifacts and receipts by conversation and project where available.
- Moved `project.create` and artifact writes behind typed database tool transactions. Each transaction writes the state change and receipt in one SQLite transaction, uses a unique idempotency key, and replays the referenced output and same receipt for an existing key.
- Added `artifact.openingPlan.save` and `artifact.openingPlan.approve` receipts with durable output references.
- Added view-model restart tests for conversation/interview restoration and opening-plan approval/receipt restoration.
- Added approval-run retry/reconciliation coverage so a repeated approval idempotency key updates the existing run instead of failing its unique constraint; an approved artifact can settle an interrupted approval run.
- Adopted legacy unscoped artifacts and receipts into the default conversation so the runtime upgrade does not hide existing opening-plan state.
- Kept an approved opening plan terminal for the interview slice: the next user message reports the next governed step instead of silently reopening approval.
- Replaced the stale last-message assertion and the M0 UI smoke identifiers in the current worktree.

Excluded or still incomplete:

- Exact approval binding to plan revision/hash, tool version, parameters, target versions, cost ceiling, expiration, and expected diff.
- Approval invalidation after a material plan, parameter, target, or budget change.
- General turn-level unknown-outcome reconciliation across message/session/artifact/run transactions, Provider execution, chapter generation, canon settlement, and M1 device acceptance.
- Capability-specific artifact APIs, private database authority, trusted-system message separation, and negation-safe project-creation confirmation remain required before model-driven tool dispatch.

Verification:

- Commit `648c8da`: Core CI `29526906495` succeeded; iPadOS CI `29526906476` compiled and ran the suite but failed one App test because its manually inserted approved artifact was timestamped earlier than the plan it was intended to supersede.
- The corrective test uses `plan.updatedAt.addingTimeInterval(1)` and intentionally preserves production `updatedAt DESC` selection.
- Windows `swift test` previously passed 35 core tests; this does not compile or run the iPadOS App/XCTest targets.
- Next required evidence: a green Core and iPadOS CI run for the corrective commit, then a successful TrollStore IPA workflow and physical-device acceptance.
