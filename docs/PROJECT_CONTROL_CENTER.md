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

Build 26 established the physical-device baseline: build identity, Refresh separators, the clean-install opening-plan review/detail surface, the observed Chapter 1 path, Keychain read, force-quit persistence, overwrite-install persistence, delete, and post-delete `Absent` all passed. Overwrite installation correctly retained the already-approved opening-plan state and therefore did not recreate a pending approval card; deleting the App cleared the database, and rerunning the flow correctly produced the card again.

Build 27 is the current independently audited M1-C candidate. Commit `2c61bc2` clarifies that the page has one secure input reused by both create and update, separates numbered input/action/read-delete sections, exposes `Stored` or `Absent` plus next-step guidance, and gives the state-dependent primary action an unmistakable button style. Core CI `29592373178`, iPadOS CI `29592385850`, and TrollStore build `29593245829` are green. The first physical-device pass is a focused discoverability check, but it does not clear the artifact manifest's fail-closed contract. Formal acceptance of this exact SHA-256 still requires its complete create/read/update/delete, reinstall-persistence, and isolation evidence. Previously accepted novel approval and Chapter 1 behavior are not invalidated because those surfaces were untouched. The governed novel workflow is not weakened or removed.

Build 28 is now the active implementation worktree and is not yet a device candidate. The Build 27 device report exposed an update-activation risk: after a TrollStore overwrite, the App may show metadata from the newly installed disk bundle while an older executable process remains alive. TrollStore source inspection shows that its update path attempts process termination before replacing the bundle, but the termination result is not verified; this is a risk model consistent with the observed first-overwrite/second-overwrite behavior, not a claim that every TrollStore update has this defect. Build 28 therefore stops treating `Info.plist` alone as proof of running code. It embeds an executable identity at compile time, independently loads the installed bundle identity from disk, compares version/build/commit/fingerprint strictly, and fails closed on mismatch or unavailable identity. While blocked, Agent turns, opening-plan approval, chapter operations, canon mutation, and paid generation must not execute.

The same Build 28 worktree adds a separately bundled Keychain Isolation Probe with its own Bundle ID and access group. That companion can prove only that the exact audited Probe binary in the exact candidate set, with the recorded SHA-256 and entitlements, cannot access the main App's Keychain group. It cannot prove that arbitrary TrollStore-installed software is isolated, because TrollStore's ability to install applications carrying arbitrary entitlements remains part of the platform trust boundary. The paired main-App and Probe IPAs, CI results, independent artifact audit, and physical-device acceptance are still pending.

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

Current independently audited device candidate (focused UX check and complete Keychain acceptance pending):

```text
commit 2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca
Core CI 29592373178: success
iPadOS CI 29592385850: success, including real Simulator Keychain create/read/update/delete and discoverability assertions
Build TrollStore IPA 29593245829: success | run number 27
Artifact CangJie-M0-device-validation-required-27-2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca
SHA-256 260478b5cf0b8ab06ea75ce6b231041c9dedf82a6c10d05ba06afb8114e1b8ec
Bundle ID com.juyang.CangJie | arm64 | deployment target 16.6 | build 27 | commit 2c61bc2d1c38
No embedded.mobileprovision | no CMS slot | ad-hoc CodeDirectory flags 0x00000002
XML application-identifier com.juyang.CangJie | keychain-access-groups [com.juyang.CangJie] | DER entitlement slot present
Acceptance blocked-pending-trollstore-device-keychain-validation (expected fail-closed state)
Local audit F:\project\CangJie\artifacts\CangJie-M1C-clarified-run-29593245829-verified\independent-audit.json
```

Build 26 remains useful physical-device regression evidence, but it cannot satisfy Build 27's artifact-bound Keychain contract. Build 27 must first show visible build `27` and commit `2c61bc2d1c38`. The immediate check focuses on the clarified create/update path; the candidate remains fail-closed until complete CRUD, reinstall persistence, and a user-operable isolation check are also recorded for this exact IPA.

Build 27 physical-device CRUD and overwrite persistence are now regression evidence, including the report that the first overwrite could expose stale presentation while a later overwrite or relaunch exposed the expected UI. Build 28 supersedes Build 27 as the next candidate under development, but no Build 28 SHA-256, run ID, candidate-set ID, or device acceptance exists yet. Until the paired artifacts are built and audited, Build 28 remains `blocked-pending-trollstore-device-keychain-isolation-validation` with fail-closed acceptance.

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

## Device acceptance instruction contract

Every physical-device test request must be self-contained and state all of the following. Do not name an action without explaining how the user reaches the state in which that action exists.

```text
Entry path: exact navigation route from App launch
Control location: page region and nearby heading
Control type: text field, secure field, button, card, drawer, or status label
Action: exact tap/type/scroll sequence
Expected result location: where the result appears, not only what it says
Failure signal: visible text, missing state change, crash, or disabled control
Reset/recovery: how to return to the required starting state
```

## Immediate queue

1. Complete the Build 28 executable-versus-installed-bundle activation gate and verify every governed entry point fails closed on mismatch without losing the user's draft.
2. Complete the independent Keychain Isolation Probe integration with a distinct Bundle ID, distinct access group, positive own-group control, and fail-closed main-group checks.
3. Build the main App and Probe as one candidate set; stamp both with the same candidate-set ID and record each IPA SHA-256, executable SHA-256, build, commit, and exact entitlements.
4. Run Core CI and iPadOS CI, fix only from the first causal error, then trigger the dual-IPA workflow and independently audit the downloaded artifacts. Double overwrite is not an accepted recovery or test procedure.
5. Physical-device gate remains pending. For the one-time upgrade from Build 27 to Build 28, first remove Build 27 from the iPad app switcher, then overwrite-install the audited Build 28 main IPA. Confirm running executable identity and installed bundle identity match and status is `Active` before any Agent or canon test. Then install the paired Probe IPA and execute the exact candidate-set isolation procedure.

## Change log

### 2026-07-17 Build-28 activation and Keychain-isolation worktree checkpoint

The Build 27 physical-device pass completed visible Keychain create/read/update/delete and overwrite-persistence checks, but repeated a previously suspected activation anomaly: after one TrollStore overwrite the App could retain an older UI shape, while a subsequent overwrite or full restart exposed the expected build. The working diagnosis is an old-process/new-disk-bundle identity split. Because an old executable can read the replacement bundle's `Info.plist`, build text sourced only from the bundle is not proof that the newly installed executable is running. Requiring a second overwrite would hide rather than solve the defect and is prohibited.

Build 28 introduces two independent identities: a compile-time executable stamp and an installed-bundle stamp loaded from disk. Version, build, commit, and fingerprint must match exactly. A mismatch or unavailable identity transitions activation to blocked, cancels or refuses Agent execution, and prevents approval, chapter, canon, and paid-generation operations. This checkpoint is implementation-only; authoritative Xcode compilation, CI, dual-IPA packaging, download audit, and real-device behavior have not yet passed.

The Keychain acceptance design now uses an independent companion application with Bundle ID and Keychain access group `com.juyang.CangJie.KeychainIsolationProbe`, separate from the main App's `com.juyang.CangJie` group. Its own-group create/read/delete is the positive control; default-group access to the main canary must return not-found, and an explicit request for the main group must return missing-entitlement. Success, item-not-found on the explicit check, or any ambiguous status fails closed as critical or inconclusive. The Probe never requests or displays the main canary bytes. Its result is meaningful only when the main App and Probe come from the same audited candidate set and their exact SHA-256 values and entitlements are verified. It does not remove the TrollStore platform trust boundary for arbitrary entitlements.

The first upgrade into this protection has a one-time limitation: Build 27 does not contain the new runtime identity guard and cannot retroactively stop its already-running process. Before overwriting Build 27 with the first audited Build 28 candidate, the user must fully remove the old App from the app switcher. From Build 28 onward, an active old process can detect that the installed bundle changed and block governed work instead of silently continuing.

### 2026-07-17 M1-C final device candidate

Commit `d27de88` added the previously missing user-operable `Device Diagnostics` secondary page, exact installed build identity, and a ThisDeviceOnly Keychain create/read/update/delete probe whose UI exposes only a 12-character SHA-256 digest. Its first iPadOS CI run `29559288088` failed only in the real UI Keychain test: the workflow had explicitly set `CODE_SIGNING_ALLOWED=NO`, so `SecItemCopyMatching` and `SecItemAdd` could not use the declared access group. Commit `9a8a9eb` retained the production entitlement contract and changed only the Simulator test invocation to ad-hoc signing with `CODE_SIGN_IDENTITY="-"`; Core CI `29560398690` and iPadOS CI `29560398699` then passed, including the real Simulator Keychain CRUD flow.

Build run `29560810381` produced run number `26` and artifact `CangJie-M0-device-validation-required-26-9a8a9eb45bfc41c5c32e1b78f9f9027d7f61ed92`. The downloaded IPA independently matched manifest and checksum SHA-256 `3aeb88fae96cd3a2ad8a6f74fc4ac629df54a027e9bd0a7fd0c6447511139d27`; final `Info.plist` contains bundle `com.juyang.CangJie`, deployment target `16.6`, build `26`, visible commit `9a8a9eb45bfc`, and iPad-only family `[2]`. Independent Mach-O inspection confirms arm64, an ad-hoc CodeDirectory, XML and DER entitlement slots, prefixless `application-identifier` and Keychain group `com.juyang.CangJie`, no CMS/Apple Developer signature slot, no `embedded.mobileprovision`, and executable hash equality with the manifest. The manifest remains deliberately fail-closed at `blocked-pending-trollstore-device-keychain-validation`. Run-25 is superseded and must not be used for M1-C acceptance because it has no user-operable Keychain diagnostic surface.

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

Historical checkpoint: the documentation commit, final-HEAD CI, TrollStore build, identity, entitlement, SHA-256, manifest, and independent audit steps described here were completed by Build 27. The authoritative pending device work is listed in the current Immediate queue.

## 2026-07-17 M1-C final-HEAD CI assertion repair

Final documentation commit `641e30a` preserved the implementation but exposed one nondeterministic audit assertion in iPadOS CI run `29555834009`. Core CI `29555834104` passed. The first real iPadOS error was `testChapterApprovedFrozenRejectsForgedApprovalAndFurtherMutation`: the database correctly rejected the forged mutation, and every visible business field remained identical, but the test compared a SQLite-restored `ChapterCalibration` to the receipt-restored calibration with synthesized `Equatable` instead of the established one-ULP-only audit equivalence.

The test now asserts `isAuditEquivalent(to:)`. This does not change product behavior or weaken the frozen-chapter trigger, exact version/hash binding, receipt validation, lock integrity, diagnosis state, rewrite scope, or canon gates. It applies the same narrowly tested timestamp representation rule already used by production receipt reconciliation. The final candidate must be built only after Core and iPadOS CI are green for the new documentation-inclusive HEAD.

## 2026-07-17 M1-C IPA build-identity packaging repair

TrollStore build run `29556797484` compiled the Release app successfully but failed before signing because the processed app `Info.plist` omitted `CangJieGitCommit` even though Xcode received the custom build setting. The packaging script now stamps the exact 12-character HEAD identity and Actions build number into the built plist atomically after compilation and before any signing. It permits only the declared project baseline build, unresolved placeholders, or already-correct values; rejects malformed identities, unexpected pre-existing values, symlinks, and invalid plists; then reopens and verifies both stamped fields. The existing package verifier still independently checks bundle ID, minimum OS, device family, executable name, build number, and commit.

The same failure also exposed a Bash error-propagation bug: `readonly EXECUTABLE_NAME="$(...)"` can return the status of `readonly` instead of the failed command substitution. The script now captures the verification command in an explicit `if ! ...; then fail` block and marks the variable read-only only after success, so the first causal identity error stops packaging immediately. Contract tests cover successful stamping, refusal to overwrite an unexpected identity, refusal of a mismatched build number, and the absence of the masked-failure pattern.

## 2026-07-17 M1-C identity-verified IPA candidate

Status: Core CI `29557784425`, iPadOS CI `29557784433`, and TrollStore build `29558102714` are green for commit `bb9cc55fa060b8e7098acb51e23f7eec89eda0b1`. The exact candidate is ready for target-iPad acceptance; no physical-device result is claimed yet.

The second packaging failure (`29557446291`) proved that Xcode also left the declared baseline `CFBundleVersion` in the processed plist rather than the Actions run number. The repaired pre-signing stamper now accepts only the exact expected run number, the declared baseline `1`, or the unresolved build placeholder; it atomically writes both commit and build number and refuses any unfamiliar pre-existing value. Commit `bb9cc55` then passed both CI workflows.

Independent post-download audit of the run-25 artifact verified:

```text
Artifact CangJie-M0-device-validation-required-25-bb9cc55fa060b8e7098acb51e23f7eec89eda0b1
IPA SHA-256 ba75a069c3b727b64c179ebf3bbd9e4e7e8cf6442b1934f12664ff9ee52ec641
Bundle ID com.juyang.CangJie
MinimumOSVersion 16.6 | UIDeviceFamily [2] | architecture arm64
CFBundleVersion 25 | CangJieGitCommit bb9cc55fa060
No embedded.mobileprovision | no CMS certificate slot
ldid CodeDirectory and XML/DER entitlement slots present
application-identifier com.juyang.CangJie
keychain-access-groups [com.juyang.CangJie]
Manifest commit, run number, signed executable hash, IPA hash, and acceptance gate all match
Acceptance blocked-pending-trollstore-device-keychain-validation (expected fail-closed state)
```

Historical run-25 next-gate note: superseded by the authoritative Build-27 queue and acceptance instructions above. Opening-plan and Chapter 1 do not need repetition for the diagnostics-only change; the exact Build-27 Keychain contract remains fail-closed until its own required evidence is complete.

## 2026-07-17 Build-26 physical-device feedback and diagnostic UX correction

The target-iPad report confirmed that overwrite installation preserves the database and approved opening-plan state. A pending approval card must not reappear merely because the same App is overwritten; after deleting the App, reinstalling, and rerunning the workflow, the card correctly appears and its full review content scrolls. This is accepted persistence behavior, not a failed presentation fix.

The Keychain screen exposed one secure field followed by a dynamic action button. After a successful write the field was cleared and the button changed from `Create and verify` to `Update and verify`, becoming disabled until a new value was entered. Because neither the page nor the prior test instructions explicitly identified the control types and state transition, the user reasonably interpreted `Update and verify` as a second input that could not be edited. Read, force-quit persistence, overwrite-install persistence, delete, and post-delete absence were observed; create-versus-update was not validly distinguished. The replacement candidate must make that distinction self-evident and must not ask the user to retest the ambiguous build.

## 2026-07-17 Clarified diagnostic first CI correction

Commit `2125fd6` passed Core CI run `29589924030`. iPadOS CI run `29589924300` compiled and ran all App/unit coverage, but its first and only failing test was `CangJieSmokeUITests.testDeviceDiagnosticsVerifiesKeychainCreateReadUpdateAndDelete` at line 67: the custom helper asserted that the Save button must become `isHittable` after six whole-App upward swipes. The following native `save.tap()` immediately succeeded because XCTest itself scrolled the identified button into view and computed a valid hit point. The failure therefore came from the new test helper, not the Keychain implementation, SwiftUI layout, or security contract.

The correction removes the contradictory pre-tap `isHittable` gate and relies on XCTest's native identifier-bound tap auto-scrolling while retaining exact state, visible-label, digest-change, disappearance, and plaintext-leak assertions. No production Keychain or governed novel workflow code is weakened.


## 2026-07-17 Build-27 clarified Keychain diagnostic candidate

Commit `2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca` passed Core CI `29592373178` and iPadOS CI `29592385850`. The latter retains real Simulator Keychain CRUD, state transition, digest-change, plaintext-redaction, and discoverability assertions. TrollStore workflow `29593245829` produced run number `27` and artifact `CangJie-M0-device-validation-required-27-2c61bc2d1c38e6844fe9c9d36a32b7ed4a0ec7ca`.

The downloaded IPA was independently parsed rather than accepted from workflow status alone. Audit result:

```text
IPA SHA-256 260478b5cf0b8ab06ea75ce6b231041c9dedf82a6c10d05ba06afb8114e1b8ec
Info.plist build 27 | commit 2c61bc2d1c38 | Bundle ID com.juyang.CangJie
MinimumOSVersion 16.6 | UIDeviceFamily [2] | thin arm64 device Mach-O
No embedded.mobileprovision | no CMS slot or BlobWrapper
Ad-hoc CodeDirectory slots 0 and 4096, both flags 0x00000002
XML entitlement application-identifier com.juyang.CangJie
XML keychain-access-groups [com.juyang.CangJie] | DER entitlement slot present
Signed executable SHA-256 352354110f047ab3c1564c7ec66e288f51a37eb08cb500fca10e4fdc594ffd70
Fail-closed acceptance blocked-pending-trollstore-device-keychain-validation
Audit F:\project\CangJie\artifacts\CangJie-M1C-clarified-run-29593245829-verified\independent-audit.json
```

This candidate does not ask the user to repeat untouched opening-plan or Chapter 1 checks. The first physical-device pass verifies visible build identity, the single input, create/read/update/delete behavior, a 12-character digest that changes after update, and plaintext absence. Passing that focused pass validates the repaired diagnostic UX but does not by itself clear the fail-closed artifact contract; exact Build-27 reinstall persistence and a user-operable isolation check remain required.

## 2026-07-17 Build 28 pre-CI implementation checkpoint

The overwrite-activation repair is implemented locally and remains unaccepted until GitHub Actions, paired-IPA audit, and real-device checks pass. The main App now compares an immutable compiled identity with a fresh disk `Info.plist` identity at launch, lifecycle transitions, and every governed mutation boundary. Missing or mismatched identity prevents database/runtime initialization where possible, revokes the shared runtime authorizer, cancels streaming, and blocks Agent turns, runtime reconciliation, opening-plan approval, paragraph locks, chapter rejection/diagnosis/rewrite/acceptance, canon-adjacent settlement, and paid generation paths.

The same candidate-set pipeline now builds the main App and a separate Keychain Isolation Probe. Both artifacts share commit, run, build, and candidate-set identity but have distinct executable fingerprints, Bundle IDs, Keychain groups, entitlements, IPA hashes, and executable hashes. The Probe performs its own-group CRUD positive control, a default-group canary-status query, and an explicit main-group query without requesting result data. Only exact expected statuses pass; all ambiguous results fail closed.

Pre-push evidence:

```text
Swift parse: 33 files passed
Python build/manifest/verifier contract suites: 4 files, all passed
Property-list parsing: main Info.plist, Probe Info.plist, and both entitlement files passed
git diff --check: passed (line-ending warnings only)
tracked secret-pattern scan: no findings
project.yml accidental BOM removed
Probe user-facing mojibake removed
Probe identity tests moved into the XCTestCase and lifecycle mismatch coverage added
iPadOS CI now generates both identities, runs both schemes, and uploads two xcresult bundles
```

Authoritative Xcode compilation and simulator execution are still pending on `macos-15` with Xcode 16.4. No device acceptance may be requested until Core CI and iPadOS CI are green and the exact paired IPA artifact has been independently audited.

## 2026-07-17 Build 28 candidate-set and runtime authorization hardening

Status: implementation and local static/script validation complete; Core CI, iPadOS CI, paired IPA construction, offline artifact audit, and physical-device acceptance are still pending. No Build 28 real-device success is claimed yet.

Purpose: eliminate the recurring ambiguous state where one TrollStore overwrite can leave old UI/code visible while files on disk report the new build. Build 28 does not normalize a second overwrite. It embeds identity into each final Mach-O, compares the running executable identity with the installed bundle identity, and fails closed when they cannot be proven identical.

Implemented candidate and artifact controls:

- The main App and Keychain Isolation Probe are built as one Candidate Set with fixed roles and Bundle IDs.
- Candidate Set derivation now binds commit, marketing version, run ID, run attempt, run number, derived build number, and both Bundle IDs.
- The manifest stores one top-level `version`; both compiled identities and both packaged plists must match it.
- Build retries derive collision-free build numbers from `runNumber * 1000 + runAttempt`.
- Executable identity is emitted to Swift and C, embedded in each Mach-O, extracted from each IPA, and compared against manifest and plist identity.
- Artifact verification recomputes Candidate Set ID instead of trusting the manifest value.
- Manifest and artifact JSON reject duplicate keys.
- IPA inspection rejects case-folded and NFC/NFD-equivalent path collisions, symlinks, special files, unsafe roots, archive bombs, and unreviewed nested code.
- The artifact directory itself must be a real directory rather than a symlink.

Implemented runtime controls:

- `BuildActivationAgentAuthorizer.performAuthorized` holds an authorization boundary over the current synchronous governed side effect and prevents revocation from interleaving with an admitted mutation.
- Runtime initialization, reconciliation, Agent turns, and opening-plan approval are governed; existing finer-grained durable and chapter mutation checks remain nested.
- Dynamic identity mismatch cancels governed work and clears cached Keychain/canary evidence without repository access.
- A rejected Agent turn preserves the unsent draft and does not append fictitious conversation messages.
- Device Diagnostics exposes running executable, installed bundle, Candidate Set, and an explicit active/mismatch diagnostic.

Local validation completed on 2026-07-17:

```text
Python unittest scripts: 47 passed, 1 platform-dependent symlink test skipped on Windows
Contract scripts: build identity and candidate-set contracts passed
Python py_compile: passed
Swift frontend parse for all modified Swift and XCTest files: passed
Git Bash syntax check for build-candidate-set.sh: passed
git diff --check: passed
```

Current authoritative gate:

1. Review the complete diff and remove temporary logs/caches.
2. Commit and push the exact Build 28 HEAD.
3. Require Core CI and iPadOS CI to pass for that HEAD; Xcode type-check and XCTest discovery remain authoritative.
4. Trigger `build-ipa.yml` only after both CI workflows pass.
5. Download the main and Probe IPA from the same artifact directory and run the strict offline verifier.
6. Ask for one-overwrite real-device acceptance only after the paired Candidate Set audit passes.
7. If the first overwrite does not activate the new executable, terminate/relaunch or respring and collect diagnostics; never instruct a second overwrite as the fix.

## 2026-07-17 Build 28 CI repair log

- Commit `02d9e4e` passed Core CI run `29614001984`. iPadOS CI run `29614001983` reached Xcode tests and exposed the first real compiler error: a throwing authorization call was placed directly inside a non-throwing `DispatchQueue.async` closure.
- Commit `4bf6dd1` moved error capture inside the async closure and passed Core CI run `29614715038`. iPadOS CI run `29614715082` then advanced to the next real compiler error: an AppViewModel test referenced `PersistedCheckpoint.reason`, while the persisted model intentionally names the field `stage`.
- The next repair changes only that test access from `.reason` to `.stage`. A failed local PowerShell edit briefly corrupted Chinese test literals because of implicit encoding; Swift parse caught it before staging. The file was restored from HEAD and patched with explicit UTF-8 handling.
- Companion Probe UI assertions also appear later in the failed logs, but they are not being guessed at in parallel. The strict sequence remains: fix the earliest causal compiler/test error, push, and rerun until the App test step reaches a trustworthy result; then diagnose the first remaining Probe failure from its own screenshots and logs.
