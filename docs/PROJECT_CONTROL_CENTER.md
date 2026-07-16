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

M1 First-Chapter Agent Vertical Slice. The recoverable-runtime candidate at commit `a0fa83b` passed the user's detailed physical-device gate. That test exposed two non-blocking presentation defects: an unchanged project Refresh had no acknowledgement, and lifecycle checkpoint text could replace the durable Agent business status. Both fixes, plus exact opening-plan approval binding and paired restore/reconciliation, passed Core/iPadOS CI and were packaged from commit `874f73d`; the new candidate now awaits a focused physical-device differential gate. M1-B is not yet complete.

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
commit 874f73d1aa1336e6f7fbae9ed503d5096e1e2759
Core CI 29538641046: success (47 tests, coverage gate passed)
iPadOS CI 29538641041: success (App, integration, Agent-first UI, exact-approval metadata, Refresh feedback)
Build TrollStore IPA 29539149285: success
```

The preceding device-accepted recoverable-runtime candidate remains:

```text
commit a0fa83be8980825651a798d7de9a9c1b083ed55c
Core CI 29527519632: success
iPadOS CI 29527519653: success
Build TrollStore IPA 29528048015: success
SHA-256 6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78
```

The user confirmed on the target iPad that overwrite installation retained prior composer text; the app launched without a crash; a project did not appear before the actual `project.create` action; `Untitled Novel` appeared after that action; navigation and draft retention behaved correctly; all three visible interview exchanges survived force-quit; opening-plan generation and approval completed; `artifact.openingPlan.approve` appeared as the expected durable tool receipt; the approval result survived restart; and the post-approval planning guard behaved correctly. Automated database/runtime tests separately prove that all three structured interview answers, rather than only the last visible message, survive restore and are compiled into the plan.

The same device run confirmed the two presentation defects described above: Refresh appeared inert when the list was unchanged, and `Saved checkpoint #5 (sceneInactive)` could temporarily replace the business stage. These are fixed in the new candidate and require only differential retesting.

New exact-approval candidate artifact:

```text
GitHub artifact CangJie-M0-device-validation-required-22-874f73d1aa1336e6f7fbae9ed503d5096e1e2759
IPA CangJie-M0.ipa (legacy filename; identity is manifest + commit + run + hash)
Build run 29539149285 | run number 22
Commit 874f73d1aa1336e6f7fbae9ed503d5096e1e2759
SHA-256 fb8da1d86c0ebfb475161c38b7381083f49bc63c4a11588d229a270020e7f109
Bundle ID com.juyang.CangJie | arm64 | deployment target 16.6
Xcode 16.4 | iPhoneOS SDK 18.5 | GRDB 6.29.3
Local verified copy F:\project\CangJie\artifacts\CangJie-M1B-exact-approval-run-29539149285-verified\CangJie-M0-device-validation-required-22-874f73d1aa1336e6f7fbae9ed503d5096e1e2759\CangJie-M0.ipa
```

The downloaded checksum matches the manifest and local SHA-256; the archive contains `Payload/CangJie.app`; the repository verifier passed; the manifest is correctly fail-closed at `blocked-pending-trollstore-device-keychain-validation`. That acceptance status is expected and is not a build failure.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Immediate queue

1. Install the exact run `29539149285` candidate over the existing app and confirm launch plus old-data retention.
2. Differentially verify that Novel Projects Refresh now shows an acknowledgement while leaving the Agent business status unchanged.
3. Put the app inactive/background and return; checkpoint feedback may appear as a secondary notice, but the durable business status must remain the actual creative stage.
4. Create a fresh project through conversation, reach the Opening Plan, inspect the exact request/revision/hash/tool/budget/expiration/diff/binding/status fields, approve through `Approve exact revision`, and verify the result survives force-quit.
5. Keep the manifest's separate Keychain device gate fail-closed until create/read/update/delete/reinstall/isolation can be exercised through an explicit device-validation surface.
6. Do not enter M1-C implementation until items 1-4 pass physical-device acceptance; then begin V1 chapter generation, evidence review, locked ranges, diagnostic rejection, confirmed rewrite scope, V2 diff, acceptance, and retained history.

## Change log

### 2026-07-16 M1-B exact-approval candidate and prior-device acceptance

Recorded the user's detailed acceptance of the `a0fa83b` recoverable-runtime candidate. Classified retained visible interview messages as device evidence for conversation persistence and retained structured answer arrays/plan compilation as automated-test evidence; neither is substituted for the other. Confirmed `artifact.openingPlan.approve` is the expected tool receipt. Recorded silent Refresh and checkpoint/status collision as real non-blocking presentation defects already corrected in `874f73d`. Core CI `29538641046`, iPadOS CI `29538641041`, and TrollStore build `29539149285` are green. Downloaded and verified the run-22 artifact with SHA-256 `fb8da1d86c0ebfb475161c38b7381083f49bc63c4a11588d229a270020e7f109`; the next stop is the focused physical-device differential gate.

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
- Physical-device acceptance passed for exact SHA-256 `6060dc1bcf511467484b4af0a99805c7a49249bd59e653063738ab2ea8065a78`: update install, project creation, navigation/draft retention, interview/plan approval, lifecycle return, force-quit recovery, and crash check behaved as expected. The checkpoint-status projection and silent Refresh observations are tracked as UX defects for the next slice.

## 2026-07-16 M1-B recoverable-runtime device acceptance

The user installed the exact `a0fa83b` candidate over the accepted M0 build. Existing composer text survived the update. No novel project existed before the first governed create action, which is expected because the prior build had no project record; after the natural-language request, `Untitled Novel` and its premise appeared in the dedicated Novel Projects page. Left navigation preserved the center conversation and unsent draft. The three-question interview, plan creation, `artifact.openingPlan.approve` receipt, approved-state guard, background return, force-quit restart, and no-crash checks passed.

Acceptance scope is the recoverable Agent runtime only. Device observations added two next-slice defects: unchanged project refresh has no visible acknowledgement, and `sceneInactive` checkpoint status overwrites the more important Agent workflow status. The three answer values are not separately exposed in the current UI, but device message recovery plus automated session/plan tests provide evidence that all three are durable rather than only the final answer.

## 2026-07-16 M1-B exact-approval governance worktree checkpoint

Status: uncommitted implementation under final review; not yet a candidate IPA.

Implemented:

- Added `CangJieCore.ApprovalBinding` with canonical versioned SHA-256 binding, epoch-millisecond expiration, strict structural validation, Codable tamper rejection, and deterministic test vectors.
- Added immutable Artifact logical identity/revision/content hash/parent adoption, exact `ApprovalRequest` persistence, target-version hashes, expected-diff hashes, current-policy candidate reconstruction, and fail-closed invalidation.
- Bound approval receipts to request, binding, tool/version, scopes, output artifact, and idempotency key; hardened generic Artifact tool replay against changed inputs or scope.
- Restored Artifact and Approval as one focused-project pair; reconciled approved transactions to one idempotent success message and only eligible nonterminal runs.
- Separated `businessStatus`, transient notices, and errors. Added visible Novel Projects Refresh acknowledgement without replacing workflow status.
- Added App database/runtime/UI tests for replay, tampering, stale versions, duplicate targets, legacy schema upgrade, cross-project restore, missing-message reconciliation, terminal-run preservation, and exact metadata presentation.
- Recorded the governing decision in `docs/adr/0003-exact-approval-binding.md` and pitfalls P-031 through P-040.

Local deterministic evidence before remote Xcode validation: `swift test` passed 47 Core tests; App, AppTests, and UITests Swift parse checks passed; `git diff --check` passed apart from a non-blocking CRLF normalization warning in one test working copy. Windows cannot typecheck SwiftUI/GRDB iOS targets, so GitHub Actions remains the build authority.


## 2026-07-16 Exact-approval CI compile correction

GitHub iPadOS CI run `29536878074` reached the Xcode 16.4 simulator compile step and exposed two concrete Swift errors in `AppDatabase+Approval.swift`: a throwing call embedded on the right side of `||` without marking the operator expression as throwing, and a parameter named `approval` shadowing the static relationship predicate. The repair evaluates the receipt lookup in an explicit branch and qualifies the predicate as `Self.approval(...)`; no approval, receipt, budget, or fail-closed behavior was removed.

Local evidence after the repair: all 47 `CangJieCore` tests pass, every App/AppTests/UI test Swift file parses, `git diff --check` passes, and the temporary downloaded Actions log was deleted. The next gate is a direct `main` push followed by inspection of the new Core and iPadOS runs; only a fully green commit may produce the next TrollStore candidate.


## 2026-07-16 Exact-approval CI second compile correction

The first repair commit `73b9d49` made Core CI run `29537449945` pass. iPadOS CI run `29537449881` then progressed to the next first real compiler error: `executeArtifactTool` declared `ArtifactToolResult` but did not return the `queue.write` result. The method now uses `return try queue.write`; no runtime behavior or authorization rule changed.


## 2026-07-16 Exact-approval CI test correction

iPadOS CI run `29537777876` compiled the App and exposed three test-contract issues. The exact replay fixture created a 500-unit approval but executed under the zero-unit default policy; it now supplies the exact matching current policy for both execution and replay. The focused-project fixture used an approval expiration in 1970 while restore correctly evaluates the current wall clock; it now isolates project pairing with a future expiration. The approval-card identifier was attached to the container and masked descendant identifiers in the SwiftUI accessibility hierarchy; it now identifies the visible card title so request, revision, hash, policy, status, and action remain individually inspectable.
