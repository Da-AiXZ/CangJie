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

M1 First-Chapter Agent Vertical Slice. The current worktree slice is M1-B runtime recovery and typed persistence hardening on top of commit `51443c2`. It is an uncommitted development slice, not a validated M1-B exit.

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
commit 51443c25623bf508e6aa5f50c4de9918ee39e036
Core CI 29524038473: success
iPadOS CI 29524038602: failure
```

The first causal failures in the iPadOS run were stale tests, not a new compiler failure: `AppViewModelTests` assumed the last message still contained `Project created` after the Agent began appending the first interview question, and `CangJieSmokeUITests` still queried the retired M0 identifiers `m0-title` and `draft-editor`. The current worktree changes the unit assertion to search the message history and changes the smoke test to the Agent-first identifiers.

Current worktree verification is partial: Windows `swift test` passes all 35 core tests. App database, view-model, restart, and UI smoke tests require the next iPadOS CI run. M1 device acceptance, complete Keychain tests, real Provider SSE/cancel/reconcile, exact plan/budget approval, bible confirmation, generation, canon, import, and serial flow remain unproven.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Immediate queue

1. Finish the current M1-B runtime slice without overwriting unrelated worktree changes.
2. Run the App database/view-model/restart tests and Agent-first UI smoke test in iPadOS CI.
3. Inspect the first causal failure, including SQLite WAL lifecycle warnings, before changing production code.
4. Commit and push the runtime slice only after reviewing the scoped diff and encoding gate.
5. Record the new commit, run IDs, included/excluded scope, and remaining M1-B gaps here.
6. Do not enter M1-C until exact revision/budget approval and approval invalidation are implemented and verified.

## Change log

### 2026-07-16 Agent-first reset

Retired old roadmap; corrected left navigation; established runtime/tool/canon/clean-room baseline. The first write was corrupted into question marks and repeated blocks, so the documents were rewritten in ASCII-dominant UTF-8 and an encoding gate was added. Documentation baseline commit: `bdf0056`. Post-push Actions are checked separately after this entry.

## 2026-07-16 M1-A implementation checkpoint

Implemented the first real vertical slice in `App/CangJieApp/ContentView.swift`, `AppViewModel.swift`, and `AppDatabase.swift`: persistent center conversation shell, independent left navigation to Novel Projects, collapsed artifact drawer, `novelProject` migration, and project create/list persistence. Added AppDatabase/AppViewModel tests. Windows `swift test` passed all 35 core tests. iOS App compilation and UI tests remain pending GitHub Actions.

## Continuous execution rule

Progress summaries are informational checkpoints, not pauses. After reporting completed work and the next action, continue automatically. Stop only when a major milestone has produced a candidate IPA requiring physical-device installation/acceptance, or when required user input is genuinely unavailable. At a device gate, provide artifact source, hash, install steps, test script, expected results, and rollback notes.


## 2026-07-16 M1-B runtime recovery worktree checkpoint

Version nature: uncommitted development slice on top of `51443c2`; partial M1-B implementation, not a release, candidate IPA, or validated milestone.

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

- Base commit evidence: Core CI `29524038473` succeeded; iPadOS CI `29524038602` failed on the two stale test contracts described above.
- Current Windows core gate: `swift test` passed 35 tests. This does not compile or run the iPadOS App/XCTest targets.
- Next required evidence: a green iPadOS CI run for the worktree slice, followed by an updated checkpoint with the resulting commit and run IDs.
