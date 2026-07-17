# CangJie Project Control Center

- Authority: current operational truth
- Updated: 2026-07-17
- Repository: `F:\project\CangJie`
- Remote: `https://github.com/Da-AiXZ/CangJie`, branch `main`

## Product and UI decision

CangJie is agent-first: persistent center conversation controls a governed novel engine through typed tools. The left region has an independent `NavigationStack`; Novel Projects pushes a dedicated page with back navigation, never an in-place tree and never a center reset. The right artifact/approval drawer is collapsed by default. Workbenches are secondary.

## Authority order

`IMPLEMENTATION_PLAN.md` -> this file -> `COMPOUNDING_AND_PITFALLS.md` -> ADRs -> `M0_VALIDATION.md`. `ROADMAP.md` is retired.

## Current milestone

M1 First-Chapter Agent Vertical Slice. M1-B exact opening-plan approval remains device-accepted at the business-state level. The current 2026-07-17 M1-C implementation checkpoint implements the previously bundled presentation/reconciliation corrections: Refresh feedback uses literal `|` separators rather than `?`; only a pending approval is projected as a central action card; an exact successful approval removes that central card while the right drawer retains the approved binding and receipt history; foreground activation restores the durable projection; and landscape uses a compact summary card that opens a scrollable full-detail review.

The same worktree implements the first governed Chapter 1 calibration loop: approved opening-plan validation through the canonical approval validator, immutable V1 generation, paragraph locks, accept-and-freeze or reject-and-diagnose, exactly three ordered one-question diagnosis turns, exact rewrite-scope confirmation, immutable V2 with parent lineage, byte-exact locked-paragraph and separator validation, V1/V2 diff review, exact-version acceptance, scope-bound receipts, receipt-bound historical snapshot replay, and restart recovery. The opening-plan approval review closes only after the exact operation succeeds and the reapplied projection confirms the same request ID and binding hash as `approved`; chapter actions separately remain bound to the exact displayed version ID and content hash.

This is implementation status, not device acceptance. Commit `2a5d8de` has passed authoritative Core and Xcode/iPadOS CI, including the governed Chapter 1 rejection, three-answer diagnosis, exact rewrite-scope, immutable V2, freeze, restart, and Agent-first UI smoke paths. The remaining gate is a green identity-verified IPA build followed by physical-device acceptance on the target iPad.

```text
open -> restore conversation/session/run/messages -> center conversation
-> project.create transaction -> durable project plus scoped receipt
-> one-question interview -> durable session and messages
-> openingPlan.save transaction -> waitingApproval artifact plus receipt
-> restart -> restore the same conversation and approval state
-> openingPlan.approve transaction -> approved artifact plus receipt
-> chapter.generate -> canonical approval validation -> immutable V1 plus scoped receipt/snapshot
-> accept exact V1 -> approvedFrozen, or reject -> three ordered diagnosis answers
-> confirm exact rewrite scope -> chapter.rewrite -> immutable V2 linked to V1
-> byte-exact lock/separator validation -> diff review -> accept exact V2 -> approvedFrozen
-> restart/replay -> validate lineage and return the receipt-bound historical snapshot
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
commit 2a5d8de51ab1f4b8727f6412efba6e98904c3f33
Core CI 29555500013: success (strict tests and 90 percent line coverage gate)
iPadOS CI 29555500055: success (87 App/integration tests plus Agent-first UI smoke tests)
Build TrollStore IPA: pending final documentation commit and identity-verified packaging run
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

1. Review and commit the current M1-C worktree without weakening exact approval, scope, lineage, replay, byte-exact lock, or UI projection gates.
2. Push the exact commit and require authoritative Xcode 16.4 iPadOS CI to compile the App, AppTests, and UITests and run the new chapter/approval coverage; Windows parse checks are not acceptance.
3. Only after green CI, build an identity-verified TrollStore IPA, download it, and verify manifest, embedded version/build/commit, archive contents, and SHA-256.
4. Run the target-iPad differential gate: Refresh displays two literal `|` separators and no `?`; exact approval succeeds, closes the central pending card, remains in right-side history, survives restart, and is fully scrollable in landscape.
5. Run the complete Chapter 1 device gate: generate V1, lock a paragraph, reject, answer the three ordered questions one at a time, inspect and confirm the exact rewrite scope, generate V2, verify the lock and V1/V2 history/diff, accept and freeze the exact version, then force-quit/restart and inspect receipts/history.
6. Keep M1-C marked unaccepted until both Xcode CI/IPA verification and physical-device acceptance pass. Keep the separate Keychain device gate fail-closed until its explicit CRUD/reinstall/isolation surface is exercised.

## Change log

### 2026-07-17 M1-C governed Chapter 1 pre-CI checkpoint

Status: implementation prepared for authoritative CI. No Xcode CI result, candidate IPA, or physical-device acceptance exists for this checkpoint yet.

Implemented in the current worktree:

- Refresh acknowledgement now renders `Projects refreshed | <count> <noun> | <time>` and UI coverage asserts exactly two literal pipes, no question-mark substitution, and no change to the durable Agent business status.
- The opening-plan action card is state-projected only for `pending`. A compact `ViewThatFits` summary keeps review reachable in landscape; the exact request, revision, artifact hash, tool/version, targets, budget, expiration, expected diff, binding, status, and full plan live in a scrollable review. After exact success the central card disappears, while the right artifact drawer retains approved status, binding metadata, and the tool receipt.
- Approval review dismissal is fail-closed: `approveOpeningPlan` first verifies the displayed request/binding is still pending, executes the exact tool, reapplies the returned runtime snapshot, and returns success only when the projection contains the same request ID and binding hash with `approved` status. The detail sheet independently checks that projection before dismissing.
- Chapter generation reuses the canonical `requireExactApprovedOpeningPlan` validator, including latest artifact identity/content hash, current approval policy/binding, and completed approval-receipt identity; chapter generation cannot rely on status text or an orphaned `approved` row.
- Added the governed Chapter 1 state machine and UI: immutable V1 plus evidence review; paragraph lock/unlock; exact accept-and-freeze; rejection without reroll; the ordered `root-cause`, `must-preserve`, and `chapter-end` questions asked one at a time; exact rewrite-scope text/hash confirmation; immutable V2; byte-exact lock validation; diff/history review; and exact-version freeze with restart restoration.
- Chapter versions and receipts are scope-bound to conversation/project and exact version/hash inputs. V1 owns the logical ID; later revisions must be contiguous and parent the immediately preceding revision in the same conversation, project, and chapter. Calibration diagnosis and rejection entries must reference a version/hash in that validated lineage.
- Idempotent replay is receipt-bound to a `chapterToolResultSnapshot`. Replay validates receipt tool/version/input/scope/output plus the snapshot hash, then returns the historical version and calibration captured for that receipt rather than silently substituting today's active calibration.
- Chapter boundary inputs now have pre-write UTF-8 hard limits: title `<512` bytes, body `<1,048,576`, evidence `<131,072`, rejection `<32,768`, question `<16,384`, answer and rewrite scope `<65,536`, question ID/hash `<128`, idempotency key `<512`; at most 10,000 paragraphs, each `<262,144` bytes, and at most 2,000 locked indexes.
- Paragraph splitting and lock binding operate on raw UTF-8. A protected paragraph includes its adjacent blank-line separator bytes, and distinguishes LF, CRLF, and CR; trimming or newline normalization cannot make a changed lock pass.
- The final pre-CI review caught App-target-only type errors and mojibake in `ChapterAgentTemplates.swift` that Windows `swift test` could not compile. The template now uses `ChapterContentIntegrity.rewritingParagraphs` so every replacement is a `String`, original LF/CRLF/CR paragraph separators remain byte-exact, locked paragraphs are untouched, and all Chinese intent/template text is valid UTF-8.

Verification state: deterministic tests were added for canonical approval receipt identity, cross-scope rejection, UTF-8 caps, trailing-separator preservation, receipt-to-historical-snapshot replay, raw UTF-8 lock comparison, immutable V1/V2 lineage, exact acceptance, restart recovery, landscape scrolling, central-card removal, and retained right-side history. These tests and all iOS source still require the authoritative Xcode CI run before any IPA is eligible for device testing.

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

## 2026-07-17 M1-B device-feedback repair plus M1-C pre-CI checkpoint

Status: implementation and deterministic Windows gates complete; authoritative Xcode/iPadOS CI and a new identity-verified IPA are still pending.

Included in the current worktree:

- User-reported Refresh feedback renders literal ASCII `|` separators. The same visible separator audit also corrected the draft-save acknowledgement.
- Exact opening-plan approval closes the central pending card only after the durable projection confirms the same request ID and binding hash as `approved`; approved metadata and `artifact.openingPlan.approve` remain visible in the right artifact history.
- Landscape no longer relies on a truncated authorization card: a compact summary opens a scrollable exact review containing the full plan, hook, protagonist, approval binding, budget, expiry, targets, expected diff, and action.
- Chapter 1 calibration is implemented end to end: immutable V1, evidence review, byte-exact paragraph locks, exact accept or diagnostic rejection, three ordered questions, explicit rewrite-scope confirmation, immutable V2 with parent lineage and diff, and exact acceptance/freeze. V2 cannot be rejected into an unbounded V3 loop.
- Chapter receipts now optionally bind `originRunID`. Restore reconciles committed Agent chapter tools to the exact interrupted run, appends a missing result message once, and does not let direct paragraph-lock receipts complete an Agent run.
- Final pre-push review found that `originRunID` was not yet part of replay identity and was stored without durable run-scope proof. Migration `m1c-origin-run-binding-v3` now gives each Agent run an immutable project scope, rejects missing or cross-conversation/project origin runs at the database boundary, fails migration on legacy mismatches, and treats a different run ID under the same chapter idempotency key as a conflict.
- `approvedFrozen` is protected both in Swift and SQLite. Direct frozen inserts are rejected; the transition requires canonical nonblank accept evidence and a matching immutable result snapshot; any final-transition failure rolls receipt and snapshot writes back atomically.
- Agent input is capped at 32,768 UTF-8 bytes before run creation. Chapter tool boundaries enforce field, body, paragraph, lock-index, hash, and idempotency limits before writes.
- Build candidates embed and display marketing version, numeric Actions build number, and the exact short Git commit; CI and packaging verify this identity before upload.

Local evidence on 2026-07-17:

```text
swiftc -parse App/CangJieApp/*.swift: pass
swiftc -parse App/CangJieAppTests/*.swift: pass
swiftc -parse App/CangJieUITests/*.swift: pass
swift test: 60 tests, 0 failures
App database regressions added for origin-run replay identity and missing/cross-project run rejection; authoritative execution remains Xcode CI
python scripts/tests/test-build-identity-contract.py: pass
git diff --check: pass (line-ending warnings only)
secret/private-binary scan: no tracked IPA, ZIP, SQLite, database, key, profile, or private source package
```

This checkpoint is not a device candidate. Next: complete focused review, commit and push `main`, inspect the first causal error of each GitHub run if any, make Core and iPadOS CI green, then build and verify a new TrollStore IPA before requesting physical-device acceptance.

## 2026-07-17 M1-C diagnosis replay repair and green CI checkpoint

Status: Core and iPadOS CI are green for implementation commit `2a5d8de`; the final TrollStore IPA build and real-device acceptance remain pending.

The final three failing Chapter 1 tests had one shared failure boundary. The third diagnosis answer committed its calibration and rewrite scope, then normal execution appended the completion message with curly quotation marks. Immediate restore reconciled the same receipt and attempted to append a textually different completion message with straight quotation marks under the same idempotency key. The message store correctly raised `idempotencyConflict`, so the ViewModel retained the prior two-answer projection even though the third answer was durable. Both execution and recovery now call one canonical `appendDiagnosisCompleteMessage` function, making payload identity and idempotency identity inseparable.

The preceding receipt-validation repair remains intentionally narrow. SQLite Double storage and JSON `Date` coding can recover the same audit timestamp one adjacent floating-point representation apart. `ChapterCalibration.isAuditEquivalent` therefore permits only identical or one-ULP-adjacent `updatedAt` values while every business field, stage, hash, version, diagnosis entry, lock, scope, acceptance binding, and receipt remains strict. A two-ULP timestamp difference and any business-state difference still fail closed.

Durable recovery boundaries now verified by CI include: Agent runs are written before high-risk session decoding; committed chapter tools reconcile only to their exact `originRunID`; receipt replay returns its historical snapshot rather than the live aggregate; direct lock receipts cannot settle Agent runs; normal execution and reconciliation share canonical assistant payloads; and failed/cancelled terminal runs are not overwritten by restore.

Authoritative evidence:

```text
Core CI 29555500013: success
iPadOS CI 29555500055: success
App test suite: 87 tests, 0 failures
UI smoke: Agent-first launch and scrollable opening-plan approval review passed
```

Next gate: commit this operational documentation, verify the final HEAD remains green, dispatch `build-ipa.yml`, verify Bundle ID `com.juyang.CangJie`, iPadOS 16.6 deployment target, exact commit identity, ad-hoc/fakesign entitlements, SHA-256 and manifest, then request target-iPad acceptance.

## 2026-07-17 M1-C final-HEAD CI assertion repair

Final documentation commit `641e30a` preserved the implementation but exposed one nondeterministic audit assertion in iPadOS CI run `29555834009`. Core CI `29555834104` passed. The first real iPadOS error was `testChapterApprovedFrozenRejectsForgedApprovalAndFurtherMutation`: the database correctly rejected the forged mutation, and every visible business field remained identical, but the test compared a SQLite-restored `ChapterCalibration` to the receipt-restored calibration with synthesized `Equatable` instead of the established one-ULP-only audit equivalence.

The test now asserts `isAuditEquivalent(to:)`. This does not change product behavior or weaken the frozen-chapter trigger, exact version/hash binding, receipt validation, lock integrity, diagnosis state, rewrite scope, or canon gates. It applies the same narrowly tested timestamp representation rule already used by production receipt reconciliation. The final candidate must be built only after Core and iPadOS CI are green for the new documentation-inclusive HEAD.
