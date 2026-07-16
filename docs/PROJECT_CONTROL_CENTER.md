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

M1 First-Chapter Agent Vertical Slice. Commit `a0fa83b` is the current M1-B recoverable-runtime device candidate. Core CI, iPadOS App tests, and Agent-first UI smoke are green. The slice is paused only at the required TrollStore physical-device acceptance gate; it is not yet a complete M1-B exit.

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
commit a0fa83be8980825651a798d7de9a9c1b083ed55c
Core CI 29527519632: success
iPadOS CI 29527519653: success
Build TrollStore IPA 29528048015: success
```

The corrective commit preserved production `latestArtifact(updatedAt DESC)` semantics and made the approved test fixture newer than the waiting plan it supersedes. The successful iPadOS run includes App unit/integration tests and the Agent-first UI smoke flow.

Candidate artifact:

```text
GitHub artifact CangJie-M0-device-validation-required-21-a0fa83be8980825651a798d7de9a9c1b083ed55c
IPA CangJie-M0.ipa (legacy filename; identity comes from manifest, commit, and hash)
SHA-256 6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78
Bundle ID com.juyang.CangJie | arm64 | deployment target 16.6
Local verified copy F:\project\CangJie\artifacts\CangJie-M1B-run-29528048015-verified\CangJie-M0-device-validation-required-21-a0fa83be8980825651a798d7de9a9c1b083ed55c\CangJie-M0.ipa
```

Manifest acceptance remains fail-closed until the exact SHA-256 IPA passes TrollStore device checks. Complete Keychain lifecycle/isolation, real Provider SSE/cancel/reconcile, exact plan/budget approval, bible confirmation, generation, canon, import, and serial flow remain unproven.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Immediate queue

1. User installs the exact SHA-256 candidate with TrollStore and executes the M1-B runtime acceptance script.
2. Record pass/fail evidence, including screenshots and the first reproducible failure step when applicable.
3. If accepted, settle the device gate and continue M1-B exact revision/budget approval plus invalidation work automatically.
4. If rejected, inspect the first reproducible device failure before changing code and preserve the accepted M0 rollback artifact.
5. Do not enter M1-C until exact revision/budget approval and approval invalidation are implemented and verified.

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

- Commit `648c8da`: Core CI `29526906495` succeeded; iPadOS CI `29526906476` found the test-fixture chronology error.
- Corrective commit `a0fa83b`: Core CI `29527519632` and iPadOS CI `29527519653` succeeded, including Agent-first UI smoke.
- TrollStore candidate workflow `29528048015` succeeded for exact commit `a0fa83be8980825651a798d7de9a9c1b083ed55c`; downloaded IPA hash matches the manifest and `.sha256` file.
- Required next evidence is physical-device acceptance of exact SHA-256 `6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78`.
