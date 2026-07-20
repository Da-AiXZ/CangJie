# CangJie Compounding and Pitfalls Log

Updated: 2026-07-19. Update after every slice or milestone with evidence.

## P-001 M0 shell was mistaken for product UX
Feasibility screen is not the Agent product. Label every IPA as feasibility, development slice, candidate, or accepted milestone; report included/excluded/verification/next.

## P-002 Form/workbench-first design replaced Agent-first
The user must be able to start with a thought in the center conversation. Forms and workbenches are secondary tools/pages. First E2E starts with natural language and verifies a real tool.

## P-003 Left secondary drawer was misunderstood
Novel Projects must push a dedicated page inside the left region's own NavigationStack. No in-place project-tree expansion. Center conversation, draft, scroll, stream, and run remain intact. Test model identity across push/pop.

## P-004 CI was debugged by speculative ldid experiments
Read the newest run and first causal error before changing code. Make one minimal fix, push when remote verification is requested, and record run ID.

## P-005 XcodeGen overwrote entitlements
Declare signing/entitlement inputs in project.yml and verify generated settings and final app entitlements in CI.

## P-006 Verification directories were omitted
Scripts must create and validate output directories and pass on a clean runner.

## P-007 IPA success was reported without scope
Always state version nature, included, excluded, verification, commit, run ID, hash, device checks, and next step.

## P-008 Local testing continued after remote verification was requested
Do only cheap deterministic checks locally, then commit, push, inspect Actions, and read the failure log.

## P-009 Security gates must not be deleted for green CI
Never remove secret, entitlement, path, signature, or safety checks to pass a build. Change implementation/test environment and document any contract change.

## P-010 Context compaction restored old direction
Read IMPLEMENTATION_PLAN, PROJECT_CONTROL_CENTER, this log, and ADRs before work. ROADMAP is retired. Update the two operational docs after every slice.

## P-011 Low-level objects became primary navigation
Users should see goals and artifacts; canon stores, task journals, and provider internals stay behind secondary inspectors.

## P-012 Model text pretended to execute tools
Only typed tool receipts can support success claims. Proposal, approval, running, verified, failed, and unknown must be distinct; unknown outcomes reconcile before retry.

## P-013 Documentation encoding corruption
A shell/code-page path turned Chinese into literal question marks and repeated blocks. Do not declare docs complete from size/timestamps. Write with a proven UTF-8 writer, run diff check, scan for `???`, replacement/mojibake markers, repeated headings, and abnormal size. This baseline uses ASCII-dominant UTF-8 to make transport safe.

## P-014 Agent capacity can be exhausted
Close completed agents after integrating results. If a new reviewer cannot be spawned, do not claim an independent review; run local gates and report the limitation.

## Pre-commit gate

1. Read the authoritative docs and confirm slice.
2. Run focused tests and `git diff --check`.
3. Scan secrets/private imports/generated artifacts/retired references/encoding damage/conflicting stage claims.
4. Review diff by file.
5. Update this log and control center.
6. Commit conventional message, push, inspect Actions, report evidence.


## P-015 M1-A must not use iOS 17-only UI APIs

The target is iPadOS 16.6. New UI must be checked against the deployment target before remote build. Avoid convenience APIs introduced after 16.6, such as `ContentUnavailableView`; use compatible composition or gate availability explicitly.


## P-016 Progress reporting must not become an artificial stop

A mid-slice summary is only a visibility checkpoint. Continue work after reporting. Pause only for a major candidate-IPA physical-device acceptance gate or genuinely blocking user input.


## P-017 Read the first compiler error, not downstream cascades

The iPadOS run reported missing `makeDatabase` first; subsequent key-path errors were cascading type inference failures. Fix the earliest causal error, then rerun before changing unrelated production code.

## P-018 Conversation growth invalidates positional message assertions

After project creation began appending the first strategic interview question, the old unit test still required the last message to contain `Project created`. Assert the durable event or search the scoped message history; do not encode an incidental final-array position as the product contract.

## P-019 UI smoke tests must move with the product identity

The `51443c2` iPadOS run still queried `m0-title` and `draft-editor` after the M0 workbench had been replaced by the Agent-first workspace. When a shell is retired, update smoke identifiers in the same slice and test the stable product contract: center control plane, composer, left Novel Projects navigation, and preserved conversation identity.

## P-020 Recoverable Agent state needs explicit conversation scope

In-memory interview counters and a global latest artifact are not restart semantics. Persist conversation, ordered messages, session focus, interview answers/current question, and run stage; scope artifacts and receipts to the same conversation and project. Restore one coherent runtime snapshot before publishing UI state.

## P-021 Tool success and receipt must share one idempotent transaction

Do not perform a side effect and then best-effort its receipt with `try?`. A typed tool transaction must write the state change and durable receipt atomically, bind an idempotency key to the output reference and scope, and return the same output/receipt on replay. `openingPlan.save` and `openingPlan.approve` require separate receipts because they are separate mutations.

## P-022 Windows shell rendering is not proof of source corruption

A Windows shell/code-page path may display valid UTF-8 Chinese as mojibake or literal `?`. Do not rewrite source or docs from console rendering alone. Inspect UTF-8 bytes with an explicit decoder, review `git diff`, and scan for actual replacement characters or stored question marks. Keep operational docs ASCII-dominant to reduce transport risk.

## P-023 SQLite WAL files follow the database connection lifecycle

A test must not delete its temporary database directory while `AppDatabase`, `AgentRuntime`, a view model, or another `DatabaseQueue` owner still holds the SQLite connection. In WAL mode the main database, `-wal`, and `-shm` files are one lifecycle unit; unlinking them while open can emit SQLite API-violation warnings and make restart tests nondeterministic. Release or close all owners first, then remove the directory, and preserve file-protection/backup handling for all three files in production.

## P-024 Idempotent run retries must conflict on the idempotency key

A retry may have a new in-memory Run UUID while representing the same governed operation. If persistence only upserts by Run ID, the unique idempotency key turns a recoverable partial failure into a permanent retry failure. Upsert by idempotency key, preserve the original durable Run identity, and reconcile an already-applied tool receipt to a terminal Run state.

## P-025 Adding scope columns requires an adoption path for legacy rows

Adding nullable `conversationID` columns without backfilling makes old artifacts and receipts invisible to new scoped queries. During the single-conversation migration, adopt legacy NULL-scoped rows into the default conversation and cover the upgrade path with a test before introducing true multi-conversation ownership rules.

## P-026 Approved workflow states must not fall back into data collection

After the opening plan is approved, the next ordinary message must not be appended as a fourth interview answer or create a new waiting-approval plan. Treat approved state as a guarded transition boundary and route the user to the next implemented governed step.

## P-027 Version-order tests must create a genuinely newer revision

When production selects the latest artifact by `updatedAt DESC`, a test that inserts a supposed replacement with an arbitrary ancient epoch does not model a replacement. Derive the new fixture time from the artifact it supersedes, for example `plan.updatedAt.addingTimeInterval(1)`. Do not change correct production ordering to accommodate an impossible fixture, and always distinguish fixture chronology failures from reconciliation logic failures.

## P-028 Candidate identity is commit plus manifest hash, not a legacy filename

The packaging workflow still emits `CangJie-M0.ipa` while later milestone slices are under test. Never infer milestone content from that filename. Device acceptance must bind the Git commit, Actions run, manifest, bundle identifier, and exact SHA-256. Renaming can improve presentation later, but it must not change or obscure the verified bytes.

## P-029 Transient lifecycle notices must not overwrite Agent workflow status

A scene-inactive/background checkpoint is operational evidence, not the primary business state. Publishing `Saved checkpoint` through the same scalar used for `opening plan approved`, waiting approval, errors, and run progress makes the UI lie by omission after every app switch. Keep durable Agent/run status separate from transient lifecycle notices, define display priority, and test background/foreground projection without losing the governed stage.

## P-030 Silent refresh is indistinguishable from a broken control

Reloading an unchanged project list can correctly produce identical data, but a button with no acknowledgement looks nonfunctional. Preserve immutable data flow and show a short non-destructive refresh result or timestamp without replacing Agent workflow status, clearing selection, or recreating the center conversation.

## P-031 Approval must bind the displayed request

Approval is not consent to a category such as `the opening plan` It must bind the request ID and canonical hash visible to the user, including exact artifact identity, tool version, parameters, targets, budget, expiration, and expected diff. Never approve by querying whatever record is currently latest.

## P-032 Artifact revision and approval decision are separate records

Artifact workflow status cannot represent immutable content identity, a user's historical decision, and current executable authorization at the same time. Keep immutable artifact revisions, approval requests, and execution receipts separate and verify their relationships explicitly.

## P-033 Recovery must use exact idempotency identity

A successful side effect followed by a crash is reconciled only through the original request, binding hash, tool/version, scopes, output reference, and idempotency key. `Latest receipt` or `latest artifact` is not proof and can cross project or lineage boundaries.

## P-034 Legacy approval cannot be promoted silently

A legacy `approved` artifact status lacks the exact request and receipt relationship required by the governed runtime. Migrate artifact identity, but require a fresh explicit ApprovalRequest rather than manufacturing authorization from old presentation state.

## P-035 Candidate binding must use current trusted policy

Validation is meaningless if the candidate copies tool version, parameters, cost, budget, or target versions from the stored request. Rebuild the candidate from current trusted app policy and current target versions, then compare it to what the user approved.

## P-036 Artifact and approval must be projected as one paired state

Restoring the newest artifact and newest approval in separate queries can combine records from different projects, lineages, or revisions. Query and return a paired projection scoped to the focused conversation and project.

## P-037 Success messages require durable idempotent reconciliation

The approval transaction may commit before the assistant success message is appended. Give that message its own durable idempotency key so restart can create the missing message exactly once without repeating the mutation or charge.

## P-038 Approved history differs from pending authorization

Pending authorization expires at its deadline. A completed historical decision does not become unapproved only because time passes, but current execution authority can still be invalidated by changed artifacts, target versions, tool policy, budget, or a missing exact receipt. Model those concepts deliberately.

## P-039 PowerShell singleton arrays can pass paths character by character

When a pipeline returns one file, PowerShell may unwrap the collection to a scalar string. Splatting that value can pass `F`, `:`, and each remaining character as separate compiler arguments. Force an array with `@(...)` or invoke the single known path directly before diagnosing a source failure.

## P-040 Never round-trip UTF-8 Swift files through unsafe PowerShell encoding

Console mojibake is not a reason to rewrite source. PowerShell defaults and lossy pipelines can replace valid Chinese literals. Use explicit UTF-8 APIs, inspect bytes and `git diff`, and avoid read-modify-write commands whose encoding behavior is uncertain.


## P-041 A throwing RHS makes the short-circuit operator expression throwing

In Swift, placing `try` only around a throwing function on the right side of `||` can still fail because the short-circuit operator uses a rethrowing autoclosure. Prefer an explicit immutable branch when the non-throwing left side can decide the result; this is clearer, preserves short-circuit behavior, and compiles consistently under the pinned Xcode toolchain.

## P-042 Parameters can shadow static helper functions

A parameter named `approval` made `approval(...)` resolve to the `ApprovalRequest` value rather than the intended static predicate. Qualify same-named type helpers with `Self.` or choose non-colliding parameter names. Parse-only Windows checks may miss target/type-checking failures, so the pinned iPadOS CI remains the authoritative compiler gate.


## P-043 A throwing closure call is not an implicit return in a multi-statement method

A method with setup statements followed by `try queue.write { ... }` still needs an explicit `return` when its signature returns the closure result. Parse-only validation does not typecheck this contract; always follow the pinned Xcode compiler's first concrete diagnostic and keep the return type visible during review.


## P-044 Time-sensitive fixtures must isolate the behavior under test

A restore test that uses a fixed expiration near the Unix epoch will eventually exercise expiration renewal instead of the intended project-pairing behavior. Use an injected clock where available, or choose a clearly future deadline when expiration is not the subject of the test. Never weaken production expiration checks to preserve a stale fixture.

## P-045 Accessibility identifiers on SwiftUI containers can hide child contracts

Attaching a UI-test identifier to a compound container can collapse or overwrite descendant accessibility identifiers. Put the card-level identifier on a visible semantic heading, and keep each governed approval field and action independently addressable. Passing visual rendering is not enough; inspect the accessibility hierarchy through UI tests.

## P-046 Manual visible persistence does not prove every structured field

Seeing all interview exchanges after force-quit proves that the conversation projection is durable, but it does not by itself prove that the structured interview answer array retained every element or that the plan compiler consumed all of them. Keep the evidence layers explicit: physical-device tests validate what the user can observe, while deterministic database/runtime restore tests validate hidden structured state and its downstream use. Do not overclaim either layer, and do not dismiss a valid device result merely because part of the invariant is intentionally non-visible.

## P-047 Pending work must be projected by state, not object existence

A durable approval record remains valuable after completion, but it no longer belongs in the central pending queue. Render the central action card only when `status == pending`; after exact success, remove it only from the action projection while preserving approved history, binding evidence, and receipts in the artifact inspector.

## P-048 Governed authorization content must never be hidden by line limits

A compact card may summarize an approval and use `ViewThatFits` to remain actionable in landscape, but ellipsis is not an acceptable substitute for the exact artifact, binding, budget, expiry, expected diff, status, and full plan being authorized. Open a scrollable review surface in every orientation and place the exact action inside that surface.

## P-049 Foreground activation is a reconciliation boundary

An overwrite install or suspended process can resume with an old in-memory projection. On `.active`, restore and reconcile durable state idempotently. This path may project records and append an independently idempotent missing success message, but it must never repeat a paid tool mutation or create a second receipt.

## P-050 Every device candidate needs visible build identity

An IPA filename is not sufficient evidence that an overwrite install is running the intended binary. Embed and display marketing version, numeric build, and a short Git commit. The packaging script must verify the embedded values before uploading the candidate.

## P-051 Byte-exact paragraph locks must not normalize before comparison

Normalizing CRLF to LF or trimming whitespace before lock validation can silently alter content that the author explicitly protected. Paragraph segmentation must operate on raw UTF-8 and distinguish LF, CRLF, and CR. The protected payload includes the paragraph content plus its adjacent blank-line separator bytes, so changing a trailing or leading separator fails closed.

## P-052 Downstream execution must reuse the canonical approval validator

A chapter generator must not infer authorization from an `approved` status field. Reuse the same canonical validator that checks the latest artifact identity and content hash, exact approval binding and current policy, project/conversation scope, and the completed approval receipt's request, binding, input, tool/version, idempotency key, and output reference. A forged or orphaned approval row must not unlock downstream work.

## P-053 Version identity and receipts are scope-bound capabilities

A UUID is not sufficient authority by itself. Bind chapter reads and mutations to conversation ID, project ID, logical chapter ID, chapter number, exact version ID/content hash, and the receipt's matching scope and output reference. Reject cross-project and cross-conversation references before any write, even when the referenced UUID exists.

## P-054 Idempotent replay must return the receipt's historical snapshot

Returning the current aggregate state for an old idempotency key rewrites history: later locks, diagnosis answers, rewrites, or acceptance can make the old result appear to have produced state that did not exist then. Persist a hashed result snapshot keyed by receipt ID and validate receipt tool/version/input/scope/output against it. Replay the captured version and calibration, not today's active projection.

## P-055 Validate lineage before trusting active or historical chapter state

Immutable rows are not enough if their parent graph can be malformed. V1 must own its logical ID, use revision 1, and have no parent. Each later revision must be contiguous, parent the immediately preceding revision, and remain in the same conversation, project, and chapter. Diagnosis and rejection history must point to exact version/hash pairs in that validated lineage.

## P-056 Bound chapter inputs by UTF-8 bytes before opening a write transaction

Character counts do not bound storage, hashing, JSON, or database costs for multilingual text. Enforce strict UTF-8 byte limits at every chapter tool boundary, including title, prose, evidence, rejection, diagnosis question/answer, rewrite scope, hashes, and idempotency keys. Also cap paragraph count, per-paragraph bytes, and lock-index count. Fail before writes so rejected oversized input cannot leave partial state or receipts.

## P-057 Dismissal is a projection-confirmed state transition

A button callback returning without throwing is not enough reason to close governed UI. First verify the exact displayed request/version/hash, execute the tool, apply the returned durable snapshot, and confirm that the projection shows the same binding in its terminal state. Only then dismiss. On stale input, failure, or projection mismatch, keep the surface open and show the error.

## P-058 Human-visible separators are part of the tested UI contract

A transient acknowledgement can be semantically correct while its separators are corrupted by encoding or font pipelines. Use the literal ASCII `|` for the Refresh message and assert its rendered accessibility label contains the expected number of pipes and no replacement `?`. Keep transient feedback separate from the durable business status.


## P-059 Windows SwiftPM success does not type-check the iOS App target

`swift test` can be fully green while SwiftUI/GRDB App-only files still contain deterministic Xcode compile errors. Before push, parse all App and XCTest Swift files, but treat that only as a syntax gate; run a focused App-target review for mixed closure return types, invalid optional operators, framework-specific overloads, and other type errors, then let authoritative Xcode CI decide. Never present core-package tests as proof that the iOS target compiles.

## P-060 Valid UTF-8 can still be unreadable mojibake

A replacement-character or literal question-mark-run scan does not catch text that was decoded and re-encoded through the wrong code page, because strings such as mojibake remain technically valid UTF-8. Review user-facing Chinese source semantically, scan for known mojibake markers, and keep representative Chinese intent/template tests. When rewriting paragraph text, operate on decoded content while preserving the original raw LF, CRLF, or CR separator bytes so fixing encoding does not weaken byte-exact locks.

## P-061 Terminal chapter state needs database-level canonical evidence

Swift replay validation is necessary but not sufficient for an irreversible terminal state. The database transition into `approvedFrozen` must itself require the canonical `chapter.accept` tool/version, exact `chapter:<activeVersionID>:accept` summary, nonblank input hash and idempotency key, matching conversation/project/output, and a matching immutable result snapshot. Direct insertion of an already-frozen calibration is forbidden.

## P-062 Receipt, result snapshot, and terminal projection are one transaction

An accept flow has a deliberate order: build the immutable receipt, insert the receipt, insert its immutable result snapshot, then perform the guarded calibration transition. Any failure in the final transition must roll the entire transaction back so no orphaned success evidence remains. Tests must inject a final-update failure and assert both receipt and snapshot counts stay zero.

## P-063 Recovery evidence must bind to the originating durable run

A latest receipt in the same conversation is not proof that it belongs to a particular interrupted run. Agent-originated chapter tools record `originRunID`; restore validates the receipt-bound snapshot, appends the missing assistant result once, and completes only that exact nonterminal run. Direct UI-only tools such as paragraph locking do not impersonate Agent-run completion.

## P-064 Do not pipe Chinese source through a Windows console code page

A UTF-8 file can be destroyed before Python sees it when a PowerShell here-string containing Chinese is piped through the console encoding. For source containing Chinese, use `.NET` `WriteAllText` with `UTF8Encoding(false)` or another byte-safe direct writer. After every such edit, parse the file and keep readable Chinese regression fixtures.

## P-065 Fix the whole visible separator family, not one reported string

When one transient message displays `?` instead of a separator, search all user-facing status strings for the same encoding artifact. The Refresh acknowledgement and draft-save acknowledgement now use literal ASCII `|`; SQL placeholders and Swift ternary operators are not presentation defects and must not be rewritten.

## P-066 Origin run identity belongs in idempotent replay

Matching tool input, scope, and idempotency key is still insufficient when the durable result is used to settle an interrupted Agent run. Chapter replay must compare the requested `originRunID` with the stored receipt. A different run may not inherit another run's committed result, even when every business input is otherwise identical.

## P-067 Durable run scope must be proven at the database boundary

An `originRunID` string is not evidence by itself. Persist the run's project scope, keep its idempotency identity immutable, and reject any receipt whose origin run is missing or belongs to another conversation or project. Migration must also fail closed when historical origin bindings cannot be reconciled exactly; do not silently bless ambiguous recovery evidence.

## P-068 Same idempotency key requires one canonical payload builder

An idempotency key does not make two nearly identical side effects equivalent. The final diagnosis message used curly quotation marks in the normal path and straight quotation marks in receipt reconciliation, so the durable message store correctly rejected the second payload. Any execution/recovery pair that reuses an idempotency key must call the same serializer or message builder; punctuation, whitespace, localization, and ordering are part of payload identity.

## P-069 SQLite Double and JSON Date can differ by one ULP

The same Swift `Date` can travel through SQLite Double storage and JSON coding and recover one adjacent floating-point representation apart. Do not weaken whole-object receipt checks or use a broad time tolerance. Define an explicit audit equivalence that permits only identical or `nextUp`/`nextDown` adjacency for the timestamp field while all business state, hashes, versions, locks, diagnosis data, scope, and acceptance bindings remain exact. Add negative tests for two ULPs and business-state changes.

## P-070 Stage-only milestones miss durable same-stage progress

Diagnosis answer one and answer two both remain in `diagnosing`, yet their answer count and diagnosis hash are durable progress. If a lifecycle or projection gate ever decides whether to refresh content rather than only status text, its milestone must include same-stage state such as diagnosis count/hash, rewrite-scope hash, lock set, and accepted version. In the current design `apply(runtimeSnapshot:)` always replaces the chapter projection; the milestone gate is allowed to control only recomputation of transient business status.

## P-071 Historical receipt snapshots and live projections have different jobs

A receipt snapshot proves exactly what one tool committed. The live projection represents the latest aggregate after later tools. Replay must validate and return historical evidence, while restore may then reload the live aggregate after reconciliation. Never compare an old receipt snapshot to a newer live state as if they must be equal, and never use the live aggregate as the historical replay result.

## P-072 Persist the Agent run before high-risk decoding or dispatch

If session decoding, provider data, or command interpretation throws before the run exists, there is no durable failure record to inspect or reconcile. Create and persist the scoped Agent run first, then enter high-risk decoding and dispatch. On failure, settle that exact run as failed without overwriting already terminal failed or cancelled runs during later restore.

## P-073 CI diagnosis starts from the first real error and preserves raw encoding

Always download the newest run log and isolate the first causal compiler/test/runtime error before editing. GitHub logs captured through PowerShell tools may be UTF-16 even when the source is UTF-8; inspect with an encoding-aware reader and do not rewrite product files based on terminal mojibake. Record run IDs and remove temporary logs before commit.

## P-074 Audit tests must use the same explicit persistence equivalence as production

A security regression test can fail even when the protected mutation was rejected and all business fields are unchanged if it compares a SQLite-restored aggregate with a JSON-restored receipt snapshot using synthesized whole-object `Equatable`. Keep ordinary `Equatable` exact; do not make approximate floating-point equality global because adjacency is not transitive. At persistence/audit boundaries, use the explicit one-ULP-only audit equivalence and retain strict comparisons for every business field. A test that verifies frozen-state immutability must therefore use that named audit relation rather than broad equality or a broad time tolerance.

## P-075 Source Info.plist placeholders are not final artifact evidence

Xcode processes and merges the source plist during the build. A custom placeholder and a visible command-line build setting do not prove that the final app bundle retained the custom key. For user-visible build identity, stamp both commit and CI build number into the built plist after compilation but before signing, permit only declared baseline values, unresolved placeholders, or already-correct values, write atomically, reopen and verify, then let the packaging verifier inspect it again. Never patch identity after signing.

## P-076 Declaration builtins can mask command-substitution failure

In Bash, `readonly NAME="$(command)"` or `local NAME="$(command)"` can report the declaration builtin's success instead of the command substitution's failure. For security-critical discovery and verification, assign inside an explicit checked branch, fail immediately, and apply `readonly` only after a valid value exists. Otherwise one root error can be followed by misleading cascade errors such as a missing executable path.

## P-077 A green packaging job is not post-download artifact acceptance

Workflow success proves that the runner's checks passed, not that the bytes later offered to the user are the expected candidate. After download, independently bind the artifact name, full commit, Actions run number, manifest, IPA SHA-256, final processed `Info.plist`, Mach-O architecture, code-signature slots, entitlements, absence of `embedded.mobileprovision`, and fail-closed device gate. Device instructions must start by checking the app's visible build and commit identity; otherwise an overwrite-install mix-up can make valid behavior appear missing or make stale behavior appear fixed.

## P-078 Device acceptance requires a user-operable diagnostic surface

Internal repository methods and unit tests do not make a physical-device gate executable. The run-25 binary contained Keychain helper methods but the Agent-first UI exposed no route to invoke them, so asking the user to validate create/read/update/delete/reinstall behavior would have produced unverifiable evidence. Before declaring a candidate ready, walk every requested device step from the installed UI. If a security primitive needs device proof, expose a narrowly scoped diagnostic surface that shows exact build identity, uses disposable data, redacts plaintext and credentials, reports deterministic state, and can be removed or retained as an explicit secondary tool without displacing the Agent control plane.

## P-079 Keychain integration tests require a signed Simulator application

A declared `application-identifier` and `keychain-access-groups` file is not enough when the test command sets `CODE_SIGNING_ALLOWED=NO`; the running Simulator app has no signed entitlement claim, and real `SecItem` operations can fail even though repository fakes and unit tests pass. Do not weaken the Keychain test or replace it with an in-memory fake. Sign the Simulator target ad hoc (`CODE_SIGNING_ALLOWED=YES`, `CODE_SIGNING_REQUIRED=YES`, `CODE_SIGN_IDENTITY="-"`) while keeping the device IPA's separate ldid/prefixless entitlement verification unchanged. Diagnose from the first runtime error and preserve the real CRUD UI test as the regression gate.

## P-080 Tool timeouts do not prove the child operation failed

A desktop shell wrapper can time out while a native child process continues and completes the download. Before retrying an artifact transfer, inspect the exact target directory, file sizes, timestamps, and surviving processes; otherwise a second downloader can race with or overwrite a valid first result. Use a unique per-run audit directory, stop only the confirmed stuck child, reject zero-byte temporary files, and independently validate manifest and SHA-256 before trusting the bytes.

## P-081 A testable control is not necessarily a discoverable control

A passing UI automation path proves that XCTest can locate and operate a control; it does not prove that a person can identify the control type, understand its state-dependent label, or know where the result will appear. In build 26, one secure input was followed by a dynamic `Create and verify` / `Update and verify` button. After creation the input cleared and the button disabled until a new value was entered, so a user reasonably mistook the update action for a second non-editable field.

State-dependent actions must expose the current state and the next required action in visible language. Give the input a heading and input-like styling, give the primary action button-like styling, explain that update reuses the same field, and test the visible label plus enabled/disabled transition rather than only a stable accessibility identifier. Never write a device script that merely says "tap Create" when Create exists only in the `Absent` state; explain how to reach that state.

Every device acceptance step must specify the entry path, exact control position, control type, operation, expected-result location, failure signal, and reset/recovery path. This is part of the product acceptance contract, not optional prose. Requiring the user to ask where a control is or what success looks like wastes time, context, and evidence quality.

## P-082 Do not add a stricter precondition than the native UI action requires

An XCTest helper can create a false failure when it asserts `isHittable` after manual whole-App swipes even though `XCUIElement.tap()` can identify the same control, scroll it into view, compute a hit point, and activate it successfully. In iPadOS CI run `29589924300`, the custom helper failed after six swipes, then the immediately following native Save-button tap auto-scrolled and completed the Keychain write.

Use stable identifiers and let native XCTest actions perform their built-in scroll-to-visible behavior unless evidence shows they cannot. Add predicate waits for the resulting state rather than inventing a stronger pre-action gate. When CI fails, read the chronological action trace: a helper assertion followed by a successful native action proves the helper is wrong, not the product control.

## P-083 Physical-device retesting should be differential and identity-bound

A new binary does not automatically invalidate every previously accepted behavior, and asking the user to repeat a long suite increases fatigue, ambiguity, and accidental deviations. First bind the installed App to the exact visible build number and commit. Then retest the changed surface plus any behavior whose dependency graph was touched; carry forward prior evidence for untouched flows.

For a differential check, state both sides explicitly: what has already passed and does not need repetition, and what new observation is required. If the changed UI is state-dependent, include how to reset it to the starting state. Never interpret a terminal state preserved by overwrite installation as a failure to display an earlier pending action; durable state should not regress merely to make a test convenient.

Differential evidence cannot override an artifact-bound fail-closed security contract. If a candidate manifest requires complete CRUD, reinstall persistence, or isolation on that exact SHA-256 binary, earlier-build evidence is regression context only. Either execute the complete contract with a user-operable probe, or deliberately revise the contract and rebuild; never clear the gate by documentation alone.

## P-084 Installed bundle metadata does not prove which executable is running

After an overwrite install, an older process can remain alive while its on-disk bundle has already been replaced. That process may read the new `Info.plist`, so a visible new build number can coexist with old SwiftUI and business code. Treat build metadata loaded only from the bundle as packaging evidence, not runtime-executable evidence. Embed an immutable compile-time executable identity, load the installed bundle identity independently, compare version/build/commit/fingerprint strictly, and fail closed when they differ or cannot be read.

## P-085 Never normalize a second overwrite into the update procedure

"Overwrite twice" is not a fix, acceptance criterion, or user instruction. It masks an activation race, produces ambiguous evidence, and cannot guarantee which executable is alive. The first upgrade from an unguarded Build 27 must explicitly terminate the old App before installation. From guarded Build 28 onward, identity mismatch must block governed operations and instruct the user to terminate and relaunch or respring; it must not continue Agent, approval, chapter, canon, or paid work.

## P-086 Runtime activation failure must be fail-closed across governed boundaries

A warning banner alone is insufficient. When executable and disk identities disagree, cancel streaming, revoke runtime authorization, refuse new Agent turns, and block approval, chapter mutation, canon writes, and paid generation before durable writes or provider calls. Preserve local draft text and expose both identities for diagnosis. Do not write a misleading checkpoint after authorization has been revoked, and do not let restore or reconciliation paths bypass the same gate.

## P-087 A companion Keychain probe proves only its exact audited candidate

A companion with a different Bundle ID and Keychain access group can demonstrate that its exact binary lacks the main App entitlement only when all of the following remain bound together: candidate-set ID, source commit, build, IPA SHA-256, executable SHA-256, and final entitlements. Its own-group CRUD is a required positive control. The explicit main-group request must return `errSecMissingEntitlement`; success is critical failure, while item-not-found or any unexpected status is inconclusive and therefore rejected. Never request, display, log, or persist the main canary value in the Probe.

## P-088 TrollStore entitlement capability remains a platform trust boundary

An isolated companion does not establish universal protection against every TrollStore-installed application. TrollStore can install software carrying entitlements outside ordinary App Store provisioning constraints, so a separately crafted application may claim permissions that the audited Probe does not have. State this boundary honestly: the Probe validates the exact companion artifact and packaging contract, not the security of arbitrary sideloaded software or the device platform as a whole.

## P-089 Syntax parsing does not prove XCTest discovery

`swiftc -parse` can accept a function named like a test even when it is accidentally nested inside a helper type instead of an `XCTestCase`. That produces false confidence: syntax is valid, but Xcode will not discover or run the intended test. After moving or generating tests, inspect class boundaries and confirm the method belongs to the expected test case; then rely on the Xcode test report, not parse success alone, as the authoritative discovery evidence.

## P-090 Simulator build settings cannot replace installed plist stamping

Passing `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, or custom identity values to `xcodebuild` does not prove that the built or installed `Info.plist` contains those values. Generate the executable identity before project generation, stamp the exact same identity into the source plist before XcodeGen for Simulator CI, and inspect the processed plist again during device packaging. The executable constants and installed bundle must be compared independently at runtime.

## P-091 Sidecar JSON does not prove executable compiled identity

A generated metadata JSON file can be correct while the shipped Mach-O contains stale code. Embed a canonical, bounded identity marker in the executable, extract it from the packaged binary, and require an exact match with manifest metadata, plist identity, commit, version, build, fingerprint, and Candidate Set ID. Treat sidecar files only as declared metadata, never as proof of the running executable.

## P-092 Candidate Set ID must be recomputed

A manifest-supplied Candidate Set ID is untrusted input. Recompute it from the full canonical binding and reject any mismatch. The binding includes commit, marketing version, GitHub run ID, run attempt, run number, derived build number, and both fixed Bundle IDs. A retry or marketing-version change must therefore produce a different Candidate Set ID even if every other input is unchanged.

## P-093 Cached authorization creates a mutation TOCTOU window

A separate `authorize()` call followed later by a database or Keychain mutation leaves a revocation window. Authorization must cover the protected side effect under one synchronization boundary, with identity and authorization epoch checked immediately before the body executes. Revocation must not interleave with a mutation already admitted under that boundary, and every later operation must observe the revoked state.

## P-094 Canary evidence must be build-activation gated

Keychain isolation evidence belongs to one exact active candidate, not to the installation in general. When runtime identity becomes unavailable or mismatched, clear cached key-presence, canary-presence, and digest displays without touching the repositories. Do not let stale evidence appear to validate a different executable, and do not read or mutate canaries until runtime activation is active.

## P-095 ZIP paths require filesystem-equivalent collision checks

Rejecting only byte-identical ZIP entry names is insufficient on case-insensitive or Unicode-normalizing filesystems. Before extraction or audit, compare archive paths under raw case folding plus NFC and NFD normalization, reject equivalent collisions, reject symlinks and special files, and reject unreviewed nested executable locations such as PlugIns, Watch, XPCServices, frameworks, and dylibs.

## P-096 Candidate Set must bind one shared marketing version

The main App and companion Probe must not share a Candidate Set while carrying different `CFBundleShortVersionString` values. Store one manifest-level version, include it in Candidate Set derivation, and require both compiled identities and both packaged plists to match it exactly. Mixed-version paired IPA artifacts are invalid even when commit, build number, signatures, and entitlements otherwise agree.

## P-097 Authorization must cover the protected side effect

Checking permission before entering a long method is not enough if the actual write occurs after the guard can change. Use a governed transaction-style API whose authorized closure encloses the current synchronous side effect. For future long-running model calls, do not hold the authorization lock across the network: authorize and journal the task, perform the remote call outside the lock, then reauthorize and commit atomically.

## P-098 Fail-closed errors must preserve unsent user input

Runtime activation failure is a security state, not a successful chat turn. Do not clear the draft, append a fake user message, or manufacture an Agent reply when the runtime is unavailable. Preserve the user's unsent text, show the activation error separately, and allow retry only after the candidate becomes active.

## P-099 Dynamic revocation must clear cached security evidence

When a previously active executable becomes mismatched at runtime, immediately revoke the runtime, cancel governed work, and clear UI-cached security evidence. Clearing the display must not itself trigger Keychain or canary repository access, because even a read would cross the newly closed authorization boundary.

## P-100 PowerShell default text encoding can corrupt UTF-8 Swift fixtures

Do not round-trip Swift, Markdown, JSON, or fixture files containing Chinese text through `Get-Content` plus `Set-Content` without an explicit verified encoding. Windows PowerShell can decode or re-encode the file under a legacy code page and silently corrupt string literals. Prefer a UTF-8-aware script, assert the exact replacement count, run `swiftc -frontend -parse` immediately, and restore from Git before retrying if any encoding damage appears.

## P-101 XcodeGen can overwrite source plist identity after pre-generation stamping

When XcodeGen manages an `Info.plist`, stamping identity before `xcodegen generate` is not sufficient: project generation can recreate the plist and silently restore stale values. Generate the Candidate Set identity first, run XcodeGen, then stamp the exact source plists that `xcodebuild` will process. Verify the processed plist and packaged plist against the compiled executable identity before accepting the artifact.

## P-102 plistlib acceptance does not guarantee ldid plist compatibility

A plist can be accepted by Python `plistlib` and Apple `plutil` but still be rejected by the pinned `ldid`. Build 28's Probe entitlement carried a UTF-8 BOM; preprocessing passed, while `ldid` failed with `Failed to parse plist`. Every entitlement passed to `ldid` must be a BOM-free UTF-8 XML plist or a separately proven compatible binary plist. Detect forbidden BOM bytes before parsing, fail with a stable user-readable error, and keep a fixture plus checked-in-file regression test.

## P-103 Defining the genre is not the same as defining the user's ability

The previous plan defined long-form male-audience progression novels but did not define whether the user could write, diagnose prose, or understand professional terminology. Product requirements must state the user's knowledge, expression ability, motivation, patience, and desired autonomy. The primary user is a novel reader who may have only a thought or feeling, not a trained author.

## P-104 Do not expose the novel engine as the driving interface

Canon, plans, approvals, knowledge boundaries, receipts, hashes, budgets, and branches are necessary production infrastructure, but ordinary users should not operate them directly to complete the main flow. The center Agent translates natural language into governed tools; workbenches and technical details are optional inspectors.

## P-105 A governed technical prototype is not validated product UX

Fixed interviews, exact approval cards, paragraph locks, diagnosis forms, Keychain CRUD, Candidate Set, and runtime probes can prove persistence, versioning, security, and recovery. They do not prove that a new user understands the product or feels that an Agent is leading. Every candidate must identify whether it validates infrastructure, product interaction, or both.

## P-106 Selection, preference evidence, soft preservation, and hard lock are different contracts

A text selection only identifies the current discussion focus and the starting point for analysis. “这段我喜欢” records positive evidence; “这个感觉别丢” records a soft preservation intent; “只讨论这段” limits the current conversation focus; “标记为问题” records negative evidence without requiring a reason. None of them makes bytes immutable. Only an explicit “锁定文字不变” action or an unambiguous command such as “这句一个字都不要动” creates a version-bound byte-exact lock. AI may hypothesize why the user likes something, but that hypothesis must remain correctable and separate from confirmed preference. Never infer a hard constraint or a preference reason from selection alone.

## P-107 Rejection reasons must be optional for ordinary users

A user may know that a chapter is wrong without knowing whether the cause is motivation, pacing, point of view, information order, genre purity, or prose. Record the rejection immediately, collect the exact selection and context, and let the Agent test one likely explanation at a time. A mandatory reason field makes the user do the Agent's work.

## P-108 Fixed question counts are test fixtures, not intelligence

“Exactly three interview questions” and “exactly three diagnosis questions” provided deterministic state-machine coverage, but must not define the final adviser. Production questioning is evidence-driven: keep multiple hypotheses, choose one high-information low-burden question, change method after “不知道”, and stop asking when a reversible sample will teach more.

## P-109 User language is a versioned interface contract

Internal names such as Bible, Canon, Artifact, Frozen, Rewrite Scope, Receipt, Binding, Hash, and Revision must map to stable plain-language labels. First use of a necessary technical term requires an explanation. Tests should assert that ordinary paths do not leak unexplained engineering terminology.

## P-110 Every milestone needs a visible product contract before implementation

Before coding a major stage, document what the user will see, what each region contains, what can and cannot be done, where to tap, what appears next, and how landscape/portrait differ. Device acceptance must include product-direction questions, not only functional pass/fail. This prevents weeks of technically correct work from accumulating on the wrong interface.

## P-111 Simplicity at the surface must not delete production governance

Making the App easy for ordinary users does not justify removing typed tools, exact approval binding, idempotency, receipts, canon states, character knowledge, branches, checkpoints, budgets, or security. Simplify through translation, defaults, automation, progressive disclosure, and Agent orchestration—not by weakening the engine.

## P-112 A real Agent milestone must name its real Provider boundary

Natural-language tool use cannot be accepted from keyword matching, canned replies, or local rules. The milestone must explicitly own Keychain credentials, a real Provider, streaming, cancellation, structured tool calls, tool-result return, usage, standard errors, and at least one recoverable governed task.

## P-113 Do not show an unavailable shortcut as if it works

A welcome-page shortcut creates a product promise. Hide it until the capability is real, or label it honestly as unavailable; never ship a dead import, research, or automation button that only looks finished. Split foundational and enhanced import capabilities across stages without breaking the core journey.

## P-114 Dynamic interviewing requires durable hypothesis state

Prompt prose alone cannot prevent repeated questions or random suggestion resets. Persist user evidence, candidate interpretations, rejected directions, unresolved questions, preference signals, decisions, and autonomy preferences with versions and scope. A denial is evidence, not permission to invent a replacement rule.

## P-115 Navigation contracts include history and presentation mode

“Left-side navigation” is incomplete unless it defines new conversation, history, current selection, timestamps, functional-page push/pop, and the exact presentation mode of reading/editing. Opening a full-screen reader must preserve the underlying conversation, scroll, draft, stream, and task state.

## P-116 Operational truth must record failed gates, not only passed subchecks

When a device test runs, replace “pending” with the observed result. If isolation checks pass only after a second overwrite, record both facts: the subchecks passed after activation, while the single-overwrite activation gate failed. Never let a stale pending label or a list of green checks imply full acceptance.

## P-117 First-run shortcuts are capability- and state-gated

A friendly shortcut is still a dead entry when no history, project, recoverable task, or implemented importer exists behind it. Hide unavailable first-run actions rather than disabling them, showing a placeholder, or routing to an empty page. `Continue last time` appears only when resumable state exists; import appears only after the relevant import slice is real.

## P-118 Milestone exit criteria require one cross-document contract

A stage cannot be defined as supporting only Chapter 1 in one authority and the first three chapters in another. Use one measurable boundary: S3 must make Chapter 1 safe to start and establish enough opening promises and character/world foundation that the first three chapters do not immediately lose their basis; chapter-level design and calibration remain S4.

## P-119 Navigation visibility follows real capability and meaningful state

A final information architecture can name every future destination, but an intermediate build must not expose pages that are empty, fake, or unavailable. Gate each navigation entry by implemented capability and data state, while preserving a useful, actionable empty state only where the page already has a real job.

## P-120 User-facing status labels are a finite vocabulary

Do not invent near-synonyms such as `recently completed` when the drawer contract defines `recently modified`. State names drive projection, dismissal, accessibility, and tests; keep one versioned human-language vocabulary and translate internal states into it.

## P-121 A visual prototype must disclose its response boundary

If S1 accepts text before a real Provider exists, the build must not leave users guessing whether the Agent is broken or intelligent. Persist the user message and show an explicitly labeled interface-preview system receipt; do not emit simulated advice, questions, or execution claims. The real conversational and tool boundary starts only when S2 Provider acceptance passes.

## P-122 The final milestone still needs an explicit non-goal list

A release-candidate stage without visible exclusions invites scope drift into platform publishing, multi-device sync, infinite background work, budget bypass, third-party code execution, and copyrighted corpus ingestion. Keep the first-release exclusions next to S6 acceptance, not only in a distant architecture section.

## P-123 A result drawer must not become a fourth landscape column

The confirmed landscape contract is one icon-only Activity Bar, one reader area at about two-thirds width, and one right-hand area at about one-third width. “仓颉” and “这次结果” switch inside that same right-hand area, exactly as portrait switches focus. Adding separate conversation and result columns would crush the reader and contradict the user-approved model.

## P-124 Structured sentiment labels and hard preservation do not belong in the first layer

Putting “喜欢 / 不喜欢” or “原样保留” in the first layer turns ordinary reading into annotation and locking work. The confirmed first layer is `复制 | 问仓颉 | 更多`. The primary path is free text selection → ask CangJie → automatic chapter/version/selection/context binding → plain-language impact preview when understood → dynamic questioning only when ambiguity remains. Keep the four soft signals and the rarely used hard lock under More. The mere existence of a selection must not create preference, problem, preservation or lock state.

## P-125 Brand naming does not justify an unapproved historical theme

The earlier paper, ink, vermilion, scroll and seal direction was inferred from the name “仓颉” rather than confirmed by the user. The approved direction is restrained, quiet, modern, warm-neutral, with limited warm-orange emphasis and a design philosophy similar to Claude Code. It must remain CangJie's own system and must never claim Claude official colors, components or brand assets.

## P-126 Icon-only navigation requires discoverability and accessibility

An icon-only Activity Bar saves space but becomes guesswork if icons are unexplained. Every visible icon needs a long-press name-and-purpose hint, a stable accessibility label, a selected state, and a real capability behind it. Do not solve discoverability by restoring permanent text that squeezes the reader.

## P-127 Portrait is a focus switch, not a shrunken landscape

Landscape panels may coexist, but portrait must show one primary surface at a time: 阅读, 仓颉 or 这次结果. Switching orientation or focus must preserve the same conversation draft, stream, chapter, scroll position, quote selection, task and approval state. Never compress the landscape columns into unusable portrait panes.

## P-128 An Agent must not turn ordinary work into confirmation labor

The earlier approval-heavy direction risked replacing forms with a stream of “are you sure?” dialogs. The confirmed default is “关键事情问我”: execute safe, reversible daily work and report afterward; show chapter text and important creative direction as reviewable results; pause only for major irreversible changes, destructive deletion, new external data disclosure, or budget overruns. “写完这一章暂停”应在当前章安全收尾后保存 checkpoint；“现在暂停”应立即取消当前请求并保留最近完整 checkpoint，不能把两种命令或“结束并保留成果”混成一个含糊的 pause，也不能再弹确认。

## P-129 Fewer prompts must not weaken production governance

Reducing visible approvals changes interruption frequency, not authorization or integrity rules. Typed tools, exact-version binding, idempotency, budgets, checkpoints, receipts, branch preservation, secret boundaries, and external-service consent remain mandatory in every autonomy mode. The first three chapters still require chapter-by-chapter calibration before higher automation is unlocked.
## P-130 More questions do not make the Agent more intelligent

A fixed interview can look thorough while exhausting the user and delaying the first useful creative signal. The required loop is understand a little, do a little, show something, then update understanding. Ask one easy question only when its answer changes the next decision; roughly 2–4 high-value questions before a scene, sample, or candidate is guidance rather than a coded quota. Stop when action is possible, further information gain is low, the user is tired or asks to proceed, or the decision is low-risk and reversible.

## P-131 AI hypotheses are not user decisions

Store user wording, confirmed decisions, AI hypotheses, and critical unknowns as separate versioned states. A plausible inference may guide a reversible sample, but it must never silently become a durable preference, story fact, or confirmed direction. Every projection and Typed Tool write must preserve that boundary.

## P-132 Persisting a conversation does not justify creating an empty novel

All conversations should survive restart from the first message, but automatically creating an unnamed project for every idea clutters the shelf and lies about commitment. Create and link a novel only when the user clearly continues, a first durable result exists, story memory becomes necessary, or prose generation starts. Do it without a form, explain it in plain language, and isolate distinct new-book ideas before they can affect the current novel.

## P-133 “This time's results” must not degrade into a chat dump or engineering log

The result surface exists to collect useful products that can be read, adopted, edited, executed, or saved for later. Ordinary questions, explanations, greetings, and every model message must remain in chat instead of spawning cards. Use a small stable plain-language status vocabulary and never expose Artifact, CanonFact, Revision Hash, Tool Receipt, or similar internal terms on the ordinary path.

## P-134 Adopting a result must not require manual transfer

A conversational command such as adopt, open, remove, or summarize should act on the bound result. Typed Tools must file adopted content into the correct chapter, story memory, source material, AI task, or creation record while preserving source conversation, version, replacement relation, receipt, and idempotency internally. Filing a result does not erase it from the current conversation's trace.

## P-135 Browsing a shelf is not permission to switch the active novel

The novel icon owns a left-side shelf and returnable detail stack; landscape changes only the left region and portrait overlays it. Rows show only title, plain-language progress, and recent time, while details expose useful book actions without project fields. Opening details or reading another book is inspection, not a context switch. Bind that book only through Continue Creating, asking CangJie from its prose, continuing one of its related conversations, or an explicit switch, then announce the new active book in plain language. This prevents cross-book contamination and preserves the center conversation, draft, stream, and reading position.

## P-136 Story memory is an Agent-maintained projection, not a settings form

A novice reader should not have to populate or reconcile a professional lore database before writing. Build Story Memory from conversations, adopted results, approved prose, user edits, research and chapter settlement, then project it through six plain-language groups and four stable statuses. Character knowledge becomes “现在知道 / 还不知道 / 错误地以为”, important entries expose a human-readable source, and AI hypotheses remain visibly unconfirmed. Keep CanonFact, TruthScope, CharacterKnowledge, PromiseLedger, evidence and versions as the governed backend rather than deleting them or exposing them raw.

## P-137 A story-memory correction is not permission to rewrite history silently

A small non-conflicting correction may execute through a Typed Tool and report afterward, but a change that contradicts approved prose or affects many later chapters, character knowledge states, promises or plans must first produce a plain-language impact explanation and governed change proposal. Preserve the old evidence and replacement relationship, then create a new version or branch only after the required user decision. A convenient memory editor must never become an unversioned shortcut around canon governance.

## P-138 The task page is not a second control plane

Keep the center CangJie conversation as the ordinary user's command surface. The AI Tasks page exists to make real execution visible, recoverable and diagnosable, not to force users to manually operate a scheduler. Every status answer and every task page field must come from the same transactional task source; chat history, cached prose and model claims are not status evidence. Project one versioned state into conversation, Current Results and AI Tasks so all three converge after run, pause, recovery, completion, failure or adoption. Never invent progress percentages or expose chain of thought to create an illusion of transparency.

## P-139 Pause, stop-with-results, and discard are different operations

A safe pause persists a checkpoint and preserves recovery. Stopping while keeping results ends future steps but retains generated, unadopted prose, plans and results without approving them. Discarding results is a separate, cautious operation that names the affected unadopted material and requests explicit confirmation when needed; it cannot delete adopted, approved or frozen content. Model task lifecycle and result-retention state separately, bind both to task version, usage, idempotency and checkpoint evidence, and use plain-language reasons for network loss, app suspension, provider load, budget limits, major story decisions and unknown outcomes. One primary creative task and one Writer owner prevent conflicting concurrent edits; additional work queues or asks first. Advanced diagnostics must remain redacted and never expose prompts, credentials or chain of thought.

## P-140 Research is proactive evidence work, not a user-operated search box

Ordinary users do not know which world rule is uncertain, stale or likely to contaminate a genre. Run knowledge-gap assessment during project formation, chapter planning, pre-draft and review, then use Story Memory, a versioned local topic pack, valid cache, necessary online research and source/conflict checks in that order. User-requested search remains an extra entry, not the trigger policy. For example, a 洪荒 (Honghuang) idea should automatically receive a sourced topic pack, while only disputes that truly change the story direction are surfaced to the user. Avoid both passive under-research and blind per-term searching; record why research ran, which layer answered, what it cost and what remains unresolved.

## P-141 A topic pack is not canon and external material is never authority

A topic pack must separate public or traditional facts, common web-fiction conventions, different schools, conflicting claims and the rule selected for this book, with sources, version, update time and scope. It may inform proposals but cannot silently become confirmed Story Memory or copy complete copyrighted novels. Web pages, search results, imported documents and packs are untrusted data: they cannot change Agent permissions, system prompts, tool policy or confirmation state. Extraction, provenance, conflict checks and governed adoption remain mandatory.

## P-142 LLM confidence is not a research trigger policy

A model saying “I know this” is neither evidence of coverage nor permission to skip research. Evaluate content type, existing coverage, consequence of error, freshness, source reliability, conflicts and genre-contamination risk independently. Treat “关闭联网 / offline-only”, “只用本地资料 / local-only”, and “研究预算 / research budget” as hard policy boundaries, and require an honest unresolved result when reliable confirmation is unavailable.

## P-143 Exploration samples do not require full opening planning

A 100–300 character scene, micro-sample, candidate opening, ability cost or chapter ending is a reversible probe for discovering taste. Requiring a completed outline, production bible or field-by-field approval before showing any prose recreates the professional-author form barrier. Store exploration output as evidence and a reviewable result, not as a full Chapter 1 or confirmed setting.

## P-144 One plain-language readiness result is enough to authorize Chapter 1

Before full Chapter 1, show one “我准备这样写” result covering story feel, protagonist situation, chapter event, ending payoff, explicit avoidances and unresolved choices. Do not expose CreativeContract, canon, opening-contract or beat-sheet terminology. A button and semantically clear conversation commands such as “直接写” or “你替我决定” must produce equivalent scoped authorization. Unresolved choices stay reversible temporary assumptions while the backstage Showrunner still prepares production-grade plans, research and constraints.

## P-145 Generated prose is not approved prose

Model completion, opening the reader, asking for a revision or retaining a result does not freeze a chapter. A generated Chapter 1 remains “供你看看” and cannot enter confirmed Story Memory or become immutable downstream truth until the user approves it. In plain-language product terms, “通过后才冻结”: only approval may freeze the exact version and settle character state, world rules, clues, reader promises and the next-chapter basis. Test the before/after boundary across conversation, Current Results, Story Memory, task state and version storage.

## P-146 A selection anchor is not the rewrite boundary

The user's highlighted words are evidence about where the problem became visible, not proof that the dependency ends there. Before editing, inspect the adjacent paragraph, scene motivation and result, chapter ending, downstream chapters, approved prose, user edits, Story Memory and plans. Show the real scope in plain language and offer “连带改顺后面 / 只改这里但可能不连贯 / 另建版本试试 / 先别改”. “只讨论这段” limits the conversation focus only; it must never suppress dependency warnings.

## P-147 Human edits outrank stale generated prose

Once the user has manually revised text, that provenance becomes the current authority for subsequent analysis and regeneration. A later model run must not reconstruct the scene from an older AI draft and overwrite the user's words or the state derived from them. Include human-edit provenance in context compilation, impact analysis, diffs and selective-regeneration tests. Replacing user text requires explicit scope and authorization.

## P-148 Mid-story edits require dependency reconnection

Changing a sentence in the middle of a story without reconnecting its consequences leaves characters knowing obsolete facts, timelines using old durations, later actions following removed causes, promises paying off against deleted setups, or genre rules reverting. Regenerate only affected working content, branch rather than overwrite approved prose, then reconnect in dependency order and rerun character-knowledge, time, causality, promise and genre-rule checks. A locally fluent patch is not complete if the downstream logic still belongs to the previous version.

## P-149 Human-edit priority does not make manual editing the primary UX

Human-authored text must outrank stale generated prose after the user chooses to edit, but that governance rule does not justify an editor-first product. The normal calibration path remains selection/reference, plain-language conversation, diagnosis, impact preview and Agent execution. A user who never manually edits must still be able to complete the first three chapters.

## P-150 Manual edits create versions, not implicit approval

Saving user edits must create a new version and preserve the prior AI draft. The edited text becomes the current source for later reasoning, but it does not mean the user has approved the whole chapter, frozen it or settled Story Memory. Keep editing provenance, chapter approval and canon settlement as separate state transitions.

## P-151 Do not interrupt every keystroke with impact dialogs

Per-character or per-sentence confirmation makes the fallback editor unusable and teaches users to avoid it. Autosave the edit session, then run one consolidated impact assessment when the user leaves editing, asks CangJie to revise, continues generation, approves the chapter or starts downstream work. Fail closed only when the deferred analysis finds a protected or high-impact conflict.

## P-152 Reference learning is not copyright imitation

A user-authorized novel, excerpt or personal work may support a sourced profile of abstract traits such as pacing, structure, narration, characterization and reading effect. It is not permission to reproduce distinctive wording, long passages, unique plot machinery or a reconstructable copyrighted corpus. Store traits and narrow provenance, not a clone target.

## P-153 Preference memory is not model fine-tuning

The first release does not train model weights or create a private fine-tuned Provider model. It stores reviewable local evidence, scopes and confirmations, retrieves relevant traits and compiles them into task context. UI and marketing must say this plainly; “upload a book and train your model” is both technically false and likely to create copyright and trust failures.

## P-154 One interaction is not a permanent preference

A user saying “ask less and show a sample” once may be a momentary need, not a lifelong working style. Record one-time, book-level and cross-project scopes separately, keep AI hypotheses distinct from user confirmation, and require evidence or explicit adoption before broadening scope. Every learned preference needs review, correction and revocation.

## P-155 Ambiguous rejection requires diagnosis, not a reason form

“This chapter feels wrong” is valid reader evidence. Asking the user to classify viewpoint, pacing, causality, payoff or style simply transfers expert work back to the person CangJie is meant to help. Use the conversation, confirmed preferences, Story Memory and prose to propose two or three concrete plain-language possibilities, then ask one easy, high-information question.

## P-156 Do not redraw a whole chapter before reaching actionable clarity

Blindly changing the prompt and regenerating the chapter wastes money, destroys useful passages and produces no learning about the mismatch. If understanding is still ambiguous, use a reversible 100–300-character diagnostic sample. Only after CangJie can reflect a sufficiently actionable understanding and show the real dependency impact should it request authorization for full revision or selective regeneration.

## P-157 Diagnostic candidates are hypotheses, not user-confirmed facts

A plausible diagnosis can still be wrong. Store each candidate with supporting and opposing evidence and a state such as hypothesized, user-confirmed, user-rejected or unresolved. A candidate must not become a permanent preference, confirmed Story Memory or rewrite rule merely because the model generated it or the user chose a sample without confirming the inferred reason.
## P-158 Chapter approval is an intent contract, not an approval form

A complex field-by-field approval page makes ordinary readers operate the governance engine. Keep the chapter in the continuous reader, offer only lightweight “就按这版继续 / 和仓颉聊聊”, and treat explicit natural-language approval as equivalent typed-tool intent. Buttons are convenience, not the only valid authorization channel.

## P-159 Ambiguous praise is not approval

“还行” and “差不多” may mean reluctant acceptance, unresolved discomfort or a wish to keep talking. Freezing on that evidence silently converts uncertainty into canon. Ask one low-burden clarification—continue calibration or proceed with this version—and do not freeze, settle or unlock the next chapter until the answer is explicit.

## P-160 Chapter approval is an ordered transaction

A success message before version freeze, Story Memory/character-knowledge/clue settlement and checkpoint can leave the UI ahead of durable truth. Bind the exact chapter version, freeze it, settle derived state, persist the checkpoint, and only then unlock the next chapter. A partial failure must remain recoverable and must not claim “这章确定了”.

## P-161 Chapter 3 approval is not continuous-creation authorization

The user may like the first three chapters but still want to stop, read, edit or control cost. Passing the calibration gate only makes continuous creation eligible. Keep the book readable and editable, explain automation, budget and major-event pause behavior in plain language, and request one separate authorization before generating Chapter 4.

## P-162 One continuous authorization should remove routine approval spam

After the user knowingly authorizes continuous creation, asking “continue?” after every ordinary chapter defeats the purpose of an Agent. Continue within the approved lookahead and budget, execute ordinary reversible decisions and report them, while preserving checkpoint, pause, revocation and scoped major-story-decision gates. Continuous creation is not blanket authority over every major story change. Never use this convenience to bypass budget, integrity, permission, safety, external-disclosure or version-governance hard limits.

## P-163 Major story decisions need scoped delegation, not one universal rule

“All major events must always ask” makes the Agent timid, while “automatic mode decides everything” removes user authorship. Classify decisions by consequence, then resolve versioned delegation by category and novel, volume or chapter scope. Ordinary reversible decisions execute and report; a major change executes only when an explicit current grant covers both category and scope. One accepted choice never implies permanent delegation.

## P-164 A pause card must reduce decision burden

A bare “major decision detected, please decide” gives the hardest creative work back to an ordinary reader. Pause before a safe checkpoint, explain why the choice matters and what it affects, offer two or three concrete directions, recommend one with a reason, and ask one easy high-information question. The card should help the user recognize a preference rather than invent a professional answer.

## P-165 Delegation scope must be visible, revocable and versioned

Natural-language grants such as “you decide character deaths in this volume” need explicit category, book/volume/chapter scope, source evidence, effective version and revocation history. Users must be able to inspect, narrow and revoke them in plain language. Revocation gates future decisions; already executed changes remain traceable and use normal branch and impact governance.

## P-166 Authorized major decisions still require conspicuous reporting

Delegation removes a blocking question, not accountability. After CangJie executes an authorized major change, conversation, Current Results and AI Tasks should conspicuously identify the actual choice, affected content and grant used. Silent execution makes later disagreement impossible to diagnose and turns scoped trust into hidden authorship.

## P-167 Creative autonomy cannot override hard safety and budget boundaries

Creative delegation governs story judgment only. Cost hard limits, task integrity, tool permissions, security policy, external-data disclosure consent, destructive deletion protection and version/idempotency/checkpoint requirements are non-delegable. No “less interruption” mode, volume-wide grant or blanket creative instruction can bypass them.

## P-168 Continuous creation needs a bounded unread lead

An unbounded generation queue wastes money and compounds drift before the user can react. Default to three prepared chapters, accept a plain-language or settings value from one to five, and hard-stop when five unread leading versions exist. “Batch target” and “unread lead limit” are different controls and must not be conflated.

## P-169 One Writer owner and chapter settlement prevent cross-chapter races

Starting Chapter N+1 while Chapter N prose, review, temporary Story Memory and checkpoint are still unsettled lets later text depend on facts that may disappear. Enforce strict chapter order and one prose-write owner. Research and read-only review may run concurrently only when they cannot mutate prose or steal ownership.

## P-170 Unread working chapters are useful context, not user-confirmed truth

Later drafting may need an unread chapter as working context, but the UI and governance must label it “仓颉准备的版本，等你看”. It cannot become approved prose or confirmed Story Memory until the user actually approves it. A prior-chapter edit preserves the old branch, analyzes dependencies and regenerates only affected work.

## P-171 “Finish this chapter then pause” and “pause now” are different commands

The first completes review, temporary settlement and checkpoint, then refuses the next Writer lease. The second cancels the active request immediately and treats partial output as temporary incomplete material, not a chapter. Conflating them either ignores urgency or destroys a nearly complete chapter the user wanted preserved.

## P-172 Resume requires idempotency and usage reconciliation

Every resume path must bind TaskRun, chapter/version, idempotency key, UsageRecord and the latest complete checkpoint. Partial provider outcomes require reconciliation before retry. A visually successful resume that duplicates prose, tool side effects or charges is still a production failure.

## P-173 Freeze the anti-drift proxy only with explicit role and authority boundaries

The architecture is now confirmed under the public names “用户偏好代理 / 影子用户” and the internal components `UserPreferenceProxy + BookReaderProxy`, so leaving it as an open research question would contradict the product contract. Confirmation does not justify vague power. Freeze its evidence flow, scope, abstention behavior, privacy boundary, evaluation plan and lack of approval/canon/major-plot authority before implementation. An attractive label must never expand permissions by documentation momentum.

## P-174 A preference proxy is not a digital clone

“Shadow user” is a product metaphor for evidence-based prediction, not a promise to reproduce the user’s mind, personality or every future judgment. Public wording must say user preference proxy or shadow user, explain uncertainty and allow correction. Claims such as “a complete digital version of you” create impossible expectations and conceal legitimate abstention.

## P-175 Start non-parametric; earn the right to evaluate a learned model

Sparse, changing and scope-dependent feedback is a poor foundation for immediate distillation, LoRA or user-specific fine-tuning. The first release should use reviewable evidence memory, retrieval, candidate comparison, blind review, calibration and abstention. Follow the frozen P0–P5 order: event/evidence foundation, passive profile, shadow review, continuous-generation integration, real-feedback calibration, then optional lightweight-model evaluation. A lightweight ranker or preference model may be evaluated only after a strong non-parametric baseline, an independent held-out set and real-user samples show stable net benefit. Model novelty is not a substitute for evidence quality.

## P-176 AI judgments cannot manufacture their own gold labels

If the system writes a chapter, predicts that the user will like it and then stores that prediction as preference evidence, it creates a self-reinforcing loop detached from the user. Calibration labels must come from real user expression, choices, rejection diagnosis, final approved versions, corrections or revocations. AI prose, shadow reviews and confidence scores may be evidence about system behavior, never proof of user preference.

## P-177 Preference scopes must not bleed into each other

A preference that is stable across books, a rule chosen for one novel and a temporary wish for one scene have different authority. Store the three scopes—长期跨项目偏好, 本书偏好, and 当前卷/章节临时意图—separately with original evidence, support, counterevidence, confidence, version, revocability and confirmation state. Retrieval must resolve the narrowest applicable scope, and temporary evidence must never silently rewrite the broader profile.

## P-178 The shadow user cannot exercise authorship authority

Prediction quality does not grant approval rights. The proxy may rank candidates, predict acceptance or rejection, pre-review, abstain and recommend a pause. It cannot approve a chapter, merge Story Memory or canon, overwrite user-authored text, acquire Writer ownership or decide an unauthorized major plot change. Typed-tool policy must reject those actions even if a prompt asks for them.

## P-179 Preference review must be blind and separate from story correctness review

A `BookReaderProxy` that sees the global continuity report first may merely repeat it and appear more accurate than it is. Run hard-rule, character-knowledge, time, causality, promise and genre review independently from the shadow reader. The shadow reader receives the planned user-evidence snapshot but not the other reviewer’s conclusion; conflicts go to Showrunner governance. This separation is required for honest evaluation as well as better diagnosis.

## P-180 Uploading or reading is not the same as liking

A user may upload material to criticize it, study it or avoid it. Extract only sourced, explainable abstract traits from material the user is authorized to use, and keep them unconfirmed until the user adopts them or later evidence supports them. Never copy distinctive expression, long passages, unique plot devices or full copyrighted text, and never infer a permanent preference from mere exposure.

## P-181 Drift control needs graduated responses

A binary “continue or stop” gate either interrupts too often or reacts too late. Combine single-chapter and cumulative drift evidence. A yellow signal（黄色缩小窗口）should reduce unread lead, shrink the next generation window and seek earlier real feedback; a red signal（红色安全暂停）should pause at a safe checkpoint with evidence and recovery options. Both thresholds need versioning, false-positive/false-negative measurement and task-state effects—not decorative colors or one unverified LLM score.

## P-182 Research metrics are method references, not product promises

Paper benchmarks, win rates and long-context claims are produced under specific datasets, prompts and evaluation conditions. Use them to choose candidate methods and design experiments, but do not paste their numbers into CangJie acceptance criteria or marketing. Product claims require CangJie’s own held-out evaluation of accept/reject prediction, candidate ranking, calibration, reasonable abstention, drift false negatives/positives, automation evidence and real-user sampling.
## P-183 Summaries and embeddings cannot replace immutable source text

A summary, vector, extracted event or Story Memory projection is a derived view that may be incomplete, stale or wrong. Imported material, chapter prose, human edits, research and authorized references need immutable source versions with source, chapter/scene/paragraph, time and exact span provenance. Reindexing or revision may add a new version, never overwrite the evidence needed to reproduce an older conclusion or branch.

## P-184 A novel index cannot rely on keywords or vectors alone

Keyword search misses paraphrase and semantic retrieval can surface convincing but narratively wrong matches. Long fiction also depends on chapter order, event progression, character state and knowledge, time, relationships, resources, abilities, foreshadowing and promises. Combine FTS5, lightweight vectors, chapter hierarchy and structured narrative relations, and keep every layer tied to source evidence and version identity.

## P-185 Chapter order and narrative relations belong in query planning

The nearest semantic match may come from a distant chapter after the character has learned something or a resource has changed. Plan searches from current scene and chapter through adjacent order before widening along relevant character/event/knowledge/promise relations. A flat top-k search can create knowledge leaks and timeline errors even when every returned paragraph is individually real.

## P-186 Insufficient evidence must widen the search before the system guesses

When local context cannot support a conclusion, expand in a recorded sequence from scene to chapter, current volume and neighbors, relevant narrative relations, the full book and only then necessary research. The planner must record why it widened and what versions it covered. If allowed evidence remains insufficient, return “暂时无法确认”; do not convert model confidence, a summary or a similar passage into fact.

## P-187 High-impact conclusions must return to original text

Character knowledge, event occurrence, chronology, causality, abilities, items, quantities, resources, foreshadowing, approved-prose boundaries, human edits and research support are too consequential to close from an LLM extraction alone. Use extraction to propose candidates, then verify against immutable source spans. A conclusion without valid source evidence is a hypothesis, not canon, approval evidence or a safe rewrite dependency.

## P-188 Narrative indexing must be progressive, resumable and honest about coverage

Blocking import until every embedding and relationship is built makes large novels unusable and fragile on iPad. Persist readable source and basic FTS5 first, then incrementally extract scenes, characters, events, knowledge, state, promises, vectors and relations with checkpoints and idempotency. Show what is searchable, what is still processing, coverage and freshness; never market a partial index as complete-book understanding.

## P-189 Reference novels create candidate abstract traits, not automatic preferences

Authorized reference material may provide sourced evidence for structure, pacing, viewpoint, narrative distance, characterization and information order. Uploading, reading or indexing it does not prove the user likes those traits. Keep extracted traits pending until user confirmation, preserve scope and revocation, and never let reference evidence enter Story Memory/canon or Agent permissions by itself.

## P-190 Do not reproduce copyrighted expression through the index

An immutable evidence layer is not permission to expose, reconstruct or imitate distinctive wording, long passages, unique plot devices or a copyrighted corpus. Store only what the user is authorized to provide, constrain quotations and outputs, derive explainable abstract traits, and test that retrieval cannot become a backdoor for verbatim reproduction. Evidence provenance supports audit; it does not erase copyright boundaries.

## P-191 Do not introduce heavy graph infrastructure before the local contract needs it

Neo4j, Qdrant, full GraphRAG/LightRAG services and cloud knowledge-graph dependencies add deployment, migration, privacy, recovery and offline failure modes that the first iPad release does not need. Start with SQLite/GRDB, FTS5, lightweight local vectors, structured relationship tables and `ContextCompiler`. Evaluate heavier components only against measured scale and quality failures, not architecture fashion.

## P-192 An index name or research result is not a product capability claim

Calling the design a “novel CodeGraph” explains the intended behavior; it does not prove the index is complete, correct or implemented. Likewise, GraphRAG papers and retrieval benchmarks provide methods, not CangJie acceptance numbers. Keep decision freeze, implementation status, coverage evidence and user-facing claims separate, and require the N1–N28 acceptance suite before claiming whole-book narrative or material understanding.

## P-193 Local basic indexing must not become a paid or external operation

Uploading a file should first produce a readable immutable source, usable text, basic FTS5, page/chapter/paragraph locations, hashes, duplicate detection and an honest usability state on-device. Requiring a paid model or sending content away before those basics work adds privacy, cost and availability failure modes to a task the device can perform. Keep this stage free of Provider calls and external disclosure, and never block reading on whole-book deep understanding.

## P-194 First networked deep understanding requires informed authorization

A generic “allow AI analysis” toggle is not enough. Before the first external LLM, embedding, OCR, search or other Provider call, show exactly which files, chapters, pages, spans or samples will be sent, what will not be sent, the Provider/model, purpose, expected cost or range, budget ceiling and whether later incremental processing is allowed. Tool policy must reject the call without explicit authorization; UI wording alone is not a security boundary.

## P-195 Material authorization must not expand silently

Permission for one source range, purpose, Provider/model and budget does not cover a different book, broader chapter set, new use, new external service or higher spending. Bind authorization to versioned scope and make pause, revocation and local-only mode effective at the tool layer. Any material change must trigger a new plain-language disclosure and authorization rather than being hidden inside settings or a task retry.

## P-196 Incremental analysis must not reprocess the whole book

Reanalyzing every chapter after one new chapter or paragraph edit wastes money, battery, network and time, and makes recovery hard to audit. Persist source versions, dependency ranges and a `MaterialAnalysisCursor`; invalidate and rebuild only affected indexes and derived records. Whole-book reanalysis is a separate explicit operation, not the default interpretation of “continue” or “refresh”.

## P-197 Pause and resume need idempotent disclosure and cost reconciliation

A checkpoint that remembers only a progress label can resend the same material or charge twice after an unknown response. Record disclosure scope, request/idempotency identity, Provider/model, source version, completed ranges, usage, cost and write state. On disconnect, suspension, crash or cancellation, reconcile unknown outcomes before retrying and resume from the last durable boundary without duplicate external transfer, analysis, index writes or charges.

## P-198 A unified evidence layer does not mean one universal understanding model

The shared `EvidenceIndex` contract should unify immutable source, provenance, version, span, hash, FTS/semantic candidates, incremental updates, checkpoints and evidence backlinks. Narrative sequence and character knowledge, factual source conflict, user project intent and preference evidence require different schemas and query planning. Forcing every material through one generic extractor produces plausible but category-wrong answers and hides where authority actually comes from.

## P-199 Material routing must classify mixed archives below the ZIP level

A ZIP may contain a novel draft, a setting note, a historical PDF and examples the user dislikes. Giving the archive one label contaminates every downstream index. Classify by file after security inventory, split a mixed file by `SourceSpan` when necessary, and ask one easy question only when reliable automatic classification is impossible and the mistake would materially change results. Every derived view must still point to the same immutable source.

## P-200 Retrieval isolation is a correctness and permission boundary

A semantically similar passage is not automatically eligible evidence. Every query must constrain project, material type, purpose, confirmation state, Agent/tool permission and external-disclosure authorization before ranking results. Cross-project, cross-purpose or unconfirmed hits may be useful candidates only when explicitly allowed; otherwise they must be excluded, not merely down-ranked.

## P-201 Reference material is neither book canon nor factual authority

A setting reference can inspire a candidate but cannot silently become “this book is definitely like this”. The same authorized reference novel may support a purpose-isolated `NarrativeIndex` structure view and `PreferenceIndex` abstract-preference view over one immutable source, but those views must not share confirmation or adoption state. Fiction must never enter `ResearchIndex` as evidence for historical, institutional, mythological or scientific facts. Keep `ProjectMaterialIndex`, `PreferenceIndex`, `NarrativeIndex` and `ResearchIndex` adoption rules separate, require user confirmation where appropriate, and preserve copyright boundaries.
## P-202 A model with a long prompt is not the product Agent

Do not build CangJie as chat history plus a giant prompt and a bag of tools. The host Harness owns the loop, state, permissions, budget, transactions, recovery and completion proof; the model only proposes the next action. Frozen architecture reference: `CJ-AH-001` (`FROZEN`, 2026-07-18); `P-203` records its execution-evidence corollary.

## P-203 Model narration is not execution evidence

A sentence such as “created”, “saved”, “paused” or “finished” is never a state transition. Only a validated Typed Tool transaction and `ToolReceipt` may change the UI to completed. Feed the receipt back to the model before the loop continues.

## P-204 More context can reduce correctness

Never send the whole book, all conversations, every material or every tool schema by default. Compile task-specific slots from authoritative evidence, save the selection reason and manifest hash, and return to immutable source spans for high-risk conclusions.

## P-205 Do not copy private or leaked implementation material

`cc.zip` is private/unlicensed and not an official Claude Code source release. Use only non-expressive high-level clean-room observations. Never copy or closely paraphrase source, Prompt, Schema, strings, tests, comments, directory structure or interface signatures.

## P-206 Recovering chat is not recovering an Agent task

A production resume restores the TaskRun, Provider request state, ToolCall, Artifact, UsageRecord, ChapterVersion, CanonTransaction and checkpoint. If an expensive request has unknown outcome, reconcile first and never silently resend.
## P-207 A checkpoint pointer must be part of the protected transaction

Never commit chapter/canon state and write the recovery checkpoint afterward. ChapterVersion, story state, character knowledge, promise ledger, UsageRecord, idempotency result, ToolReceipt, asset references and the checkpoint record/current pointer must commit atomically. Use content-addressed prewrites and a transactional outbox for effects SQLite cannot own.

## P-208 Approval is a durable protocol, not a button event

Persist proposal identity, input/version hashes, prerequisites, scope, risk and expiry. Approval, denial, expiry and deferral all return structured results. Revalidate permission, budget, target version, Writer Lease and prerequisites immediately before execution.

## P-209 A Writer Lease without a fencing token can still double-write

A recovered stale Writer must never commit after a new Writer takes ownership. Every prose/canon commit validates the monotonic fencing token in the same transaction; old tokens remain invalid forever.

## P-210 Branch and narrative time are Context isolation keys

Every story retrieval carries book, branch, lineage, chapter version and as-of scene/time. Replacing an upstream chapter invalidates dependent Context manifests, plans, reviews and unread chapters. Similarity alone may never cross these boundaries.

## P-211 Minimal tool context requires governed discovery

Do not send every tool Schema, but do not hide capabilities from the model. Build a versioned ToolCatalogManifest and a white-listed capability lookup that cannot expand permission, disclosure or budget.

## P-212 Clean-room language must match the actual process

Because early research touched a private/unlicensed package, do not claim legal clean-room certification. Isolate the package from implementation, give implementers only public-source/original specifications, keep a source register and scan for copied names, strings, Prompts, Schemas and structural similarity.

## P-213 An API key does not reliably identify its provider

A key prefix, length, or character format may overlap, change, or be arbitrary for a proxy/custom service. At most, a format match can produce a local candidate hint. It cannot authorize automatic Provider selection. Require the user to choose the Provider first, bind the credential to that identity and allowed host set, and send it only to that destination. Never fan the same key out to multiple Providers or candidate Base URLs to discover where it works. Custom OpenAI-compatible services also require a Base URL and model discovery or an explicit model name. Keys must stay out of logs, exports, diagnostics, error receipts, and network traces.

## P-214 Model selection must be real but not hidden behind routing modes

The user should not be forced to guess a model before connecting a service, but after connection CangJie must show the models that the selected key can actually access and let the user choose one. Do not replace that choice with quality/cost/speed modes, hidden per-task routing, or a silently substituted model. If a custom service cannot list models, make the limitation explicit and allow a manually entered model name.

## P-215 Multiple connections are user-managed, not an automatic failover system

A saved connection is `Provider + Base URL + credential + selected model`. Users may keep several Providers or several keys for one Provider, but only one is current and switching is manual. A request stays on the connection it started with; on failure, offer reconnect, refresh, re-enter key, or manual switch-and-retry. Never rotate keys, load-balance, or silently take over a task. Deleting a connection must not delete story data and requires an explicit switch or cancellation if it is current or needed by unfinished work.

## P-216 Do not turn one product area into a questionnaire

A coherent user-visible behavior should be decided as one product contract. Splitting Provider connection, model choice, profile storage, task binding, retry, and failover into many sequential approval questions creates decision fatigue and makes the product owner repeat the same intent. Keep internal trace IDs for engineering, but present one bundled design review for each meaningful product area. Ask again only when a genuinely different user-facing tradeoff appears.
## P-217 Driver Cockpit Snapshot must not become a whole-database Prompt

A model that receives only chat history, or receives the whole book and every tool on every turn, loses the current UI location, branch, version, approval and budget boundary. Compile a minimal, version-bound Driver Cockpit Snapshot with identity, location, project/branch/chapter version, confirmed and unconfirmed state, TaskRun/checkpoint, approvals, allowed and forbidden actions, tools, capability, budget, disclosure scope and evidence.

## P-218 Capability labels require runtime evidence

Provider names, key prefixes and marketing claims do not prove Tool Call, cancellation, streaming, usage or recoverability. Probe the connection and expose complete driving, restricted driving and writing-only modes. Missing capabilities must constrain or reject tools; hidden model replacement is not an acceptable fix.

## P-219 Five-level permission must be enforced by the host

If the five permission levels exist only in a Prompt, an erroneous model call can still reach a side effect. The registry, state machine, authorization, budget, version checks and Typed Tool layer must enforce Levels 1-5; Level 5 is always denied.

## P-220 Semantic Tool names are not execution proof

The approved semantic surface (project, conversation, material, research, story memory, artifact, chapter, generation, branch, export, budget and task) must remain typed and receipt-backed. A tool name, JSON-shaped model output or a "done" sentence cannot change real state without proposal, validation, commit, verification and receipt.

## P-221 A prerequisite rejection must not pollute the project

例如模型错误调用：

```text
generation.start
```

但当前还没有通过前三章，工具层应直接返回：

```text
拒绝执行
原因：前三章校准尚未完成
当前状态：第一章等待用户确认
可以执行：打开第一章、继续讨论、创建新版本
```

模型再向用户解释：

> 现在还不能开始连续创作，因为第一章还在等你确认。我可以先把第一章打开，或者根据你刚才的意见再调整一次。

因此：

> **模型可以提出行动，但最终执行权属于仓颉工具和状态机。**

驾驶员即使操作失误，高达自身的安全系统也会阻止它撞墙。

---

A regression test must prove that the rejected `generation.start` creates no task, chapter version, story-memory write, Writer Lease, fee settlement or checkpoint mutation.

## P-222 Multiple connections are manual user assets, not a failover pool

Multiple Providers and multiple keys are allowed, but a request remains bound to its selected ModelConnection. Failure may offer reconnect, refresh, re-enter key, manual switch or manual retry only. Never rotate keys, load-balance, auto-switch or silently take over.

## P-223 No API key must not become a blocked or fake home screen

A missing `ModelConnection` is a valid local product state. Do not replace the central conversation with a mandatory Provider form or disable the whole App. Local thought/draft persistence, local browsing/reading, history, and connection management remain usable. Conversely, never word a local save receipt as model understanding, generation, revision, research, or review. AI-dependent work stays visibly pending until a real user-selected connection exists.

## P-224 Connection setup must preserve and resume the triggering intent

If the first AI-dependent request opens connection setup, losing the original message, draft, project binding, or continuation point makes infrastructure become the product. Persist the triggering intent before setup; after explicit Provider, Key/Endpoint, model discovery, and model selection, return to the same conversation and continue it. Failure permits retry, correction, refresh, or user-selected manual switching only, never automatic Provider switching, key polling, load balancing, or takeover.

## P-225 Adding materials, exporting prose, and backing up a project are not one file feature

`添加资料` imports untrusted reference inputs; `导出小说` projects clean current-mainline prose; `备份项目` preserves complete recoverable project state. A generic import/export screen blurs purpose, leaks internal records into manuscripts, or produces backups that cannot restore. Keep the three entry points, schemas, receipts, warnings, and acceptance tests separate.

## P-226 Archives and documents are data, never executable authority

Save source material before processing, apply type/purpose isolation, and checkpoint large parsing/OCR/indexing work. A scanned PDF needs OCR only when text extraction requires it. A ZIP is an inert container: validate paths, size and type, then read supported entries as untrusted material. Never execute scripts, macros, commands, prompts, or instructions from an archive or document, and never let them change Agent permissions.

## P-227 A clean manuscript export is not a project backup

TXT/DOCX/Markdown novel export contains current-mainline reader-ready prose, with unconfirmed chapters excluded by default or visibly marked as drafts. It excludes conversations, approvals, ToolReceipts, Story Memory, costs, task state, credentials, internal IDs, and diagnostics. A project backup separately contains the creative state and recovery metadata, but never API keys, Keychain plaintext, authorization headers, or login credentials.

## P-228 Restore and persistence claims require fail-safe identity and exact device evidence

Restore creates a copy by default. Replacing the current project requires a recovery snapshot, impact preview, and explicit confirmation. Password-protected backups must warn that forgotten passwords are unrecoverable. Deleting the App may remove local projects, so device migration requires a backup prompt. Do not generalize overwrite-install or force-quit persistence from a different build; state only what the exact candidate passed on device.
## P-229 Persistence before suspension is not a promise of background execution

Before backgrounding, screen lock, or detected network loss, persist the composer draft, real TaskRun stage, Provider request identity/state, received stream cursor and fragments, UsageRecord/cost, and latest safe checkpoint. This gives the user a truthful recovery boundary; it does not mean iPadOS 16.6.1 will grant unlimited background runtime. UI, marketing, and acceptance receipts must separate “saved safely” from “kept running.”

## P-230 Offline AI requests must not auto-send when connectivity returns

Local projects, prose, materials, drafts, novel export, and project backup remain usable offline. A new AI intent created offline is durable waiting work, not a sent ProviderRequest. Connectivity restoration must not silently disclose data or incur cost: ask the user before sending it. Only a request already sent before disconnection may be automatically reconciled against its original identity, disclosure scope, model connection, idempotency key, stream, usage, and receipts.

## P-231 Interrupted stream bytes are not committed story state

Streaming fragments can be valuable recovery evidence, but an incomplete response is not a chapter, canon transaction, character-state update, promise settlement, or completed-ahead version. Persist it as an explicitly incomplete temporary artifact, preserve hash/order metadata, and quarantine it from formal projections. Immediate pause, cancellation, crash, lock, or network loss must not let readable-looking partial text bypass review and atomic settlement.

## P-232 Recovery needs five distinct outcomes and non-creative reconciliation

“Resume” is not one state. Project completed, safely paused, definitely failed, outcome unknown, and invalid connection require different explanations and actions. Unknown outcome first checks the original Provider request, local transaction, stream, UsageRecord, ToolReceipt, and postconditions without issuing a new creative generation or charge. Direct retry while still unknown risks duplicate prose and fees; only after a durable reconciliation result may the normal retry policy run.

## P-233 Notification permission is contextual, optional attention routing

Requesting notification permission on first launch asks for trust before the user has seen any value. Explain and request it only when the user starts the first long task. Notifications are limited to result completion, waiting for confirmation, pause/failure, cost limits, and major-story gates. Denial must not block tasks, recovery, local use, export, or backup; notifications observe durable task state and never drive the state machine.

## P-234 Plain-language task labels must still project real transactional state

The ordinary task surface should say only `正在做`, `接下来`, and `需要你`, with concise checkpoint and cost facts, instead of exposing an internal pipeline checklist. This simplification is a projection, not permission to collapse TaskRun states. Completed, paused, failed, unknown, connection-invalid, single-Writer ownership, and the two pause semantics must remain distinct underneath and stay consistent across conversation, results, task page, and notifications.

## P-235 Historical engineering labels are not the current product milestone

candidate-hardening M1 and Builds 26–28 are prototype and hardening evidence only. The current real milestone is S1 Agent 驾驶舱定调与重构, S0 is only the completed feasibility baseline, and Build 28 is not accepted. Never let a historical Build heading, old checkpoint or technically working screen overwrite the current S0–S6 product map.

## P-236 CI, static UI, documentation and code completion do not pass a product stage

A stage passes only with its stated user-visible capability, explicit included/excluded scope, automation evidence and exact device evidence. Green CI can prove a build; a static screen can prove layout; documentation can freeze a contract; code can prove implementation progress. None alone proves the product stage or user experience was accepted.

## P-237 Harness gates must advance in order and cannot become empty IPA milestones

H0–H5 are horizontal engineering gates, not user-facing product shells. S2 must prove the applicable H0–H3 minimum real loop before S3 advances H4; S4 completes H4 and enters H5; S5 completes H5. Do not skip early data/context/loop gates to demo multi-Agent serial generation, and do not package an empty Harness layer as a milestone IPA.

## P-238 Physical-device evidence must bind one exact candidate identity

Every candidate receipt binds version, Build, commit, IPA SHA-256 and candidate identity to the entry path, control location, action, result location, failure signal and recovery method. Evidence from another artifact, simulator, old process, disk bundle, or prior Build cannot silently prove the current executable.

## P-239 Differential acceptance never waives security re-proof

Unchanged ordinary behavior with valid exact-candidate evidence need not be mechanically retested after every slice. Security contracts are different: permissions, credential isolation, budget, idempotency, unknown-outcome reconciliation, Writer Lease, recovery and external disclosure must be re-proved on the exact candidate because packaging, entitlements, migration and lifecycle changes can invalidate them without visible UI changes.

## P-240 Million-character capability claims belong to their frozen stage boundary

S3 may use ordinary-scale materials but cannot claim complete million-character understanding. S5 is where the million-character narrative index and phased analysis of large reference novels are formally accepted. S6 completes million-character material handling across TXT/Markdown/DOCX/PDF/OCR/ZIP and the release-candidate quality, migration and security gates. Partial indexing, a successful fixture or a design document must not be marketed as full-book capability.

## P-241 A truthful S1 preview receipt is not an S2 Agent turn

A local persistence acknowledgement may say only what the transaction proved. During S1, the fixed receipt proves that the text was saved for interface and navigation validation; it does not prove model understanding, Provider availability, tool execution, story-state change, prose generation, or completion of an Agent loop. Do not create runtime, approval, artifact, chapter, receipt, usage, or novel side effects merely to make the preview look alive. Initialization and foreground restore must be read-only, and an empty installation must not create a Conversation until the first actual send.

## P-242 Autosave is a governed durable mutation, not a harmless property observer

A draft `didSet` can write while the app is inactive, after Build Activation has changed, after an atomic send already cleared the persisted draft, or with unbounded pasted content. Guard autosave by lifecycle and dynamic execution authorization at the write boundary; impose the same UTF-8 ceiling inside the database path; retain the last recoverable draft on failure; and suppress the observer when the successful send transaction has already cleared the persisted draft. Test rollback of user message, fixed receipt, Conversation time and draft clearing as one unit.

## P-243 Unicode and encoding checks must test the real threat, not produce false-green noise

Multiline user content can make a continuation line look like `System:` or `Agent:`, and bidi controls can visually reorder text around a trusted prefix. Reject unsafe directional controls before a preview message is committed and indent every displayed continuation line. Encoding scans must search explicit code points and literal corruption runs rather than treating ordinary Swift optionals such as `?` and `??` as mojibake. Scan touched files for U+FFFD, BOM/line-ending drift, a run of four consecutive ASCII question marks, trailing whitespace and credential patterns; never normalize unrelated legacy files merely to make a broad scanner green.

## P-244 First-send setup and first-turn commit are one transaction

Do not implement an empty-install send as `ensureConversation()` followed by `appendTurn()` in a second transaction. If the user message or fixed receipt fails after the first transaction commits, an empty Conversation survives even though the send failed, and recovery can mistake that shell for durable user work. On the first send, select or create the Conversation, insert the user message and honest fixed receipt, update the monotonic Conversation timestamp, and clear the persisted draft inside one database transaction. A forced failure on the second message must leave zero new Conversations, zero messages, and the prior draft unchanged.

## P-245 Selected Conversation is durable state, not a latest-timestamp guess

Conversation `updatedAt` sorts history; it does not identify the user's active workspace. Persist the selected Conversation separately, restore that exact identity after relaunch, and fail closed if it is missing or malformed. Otherwise background timestamps, delayed writes or another Conversation's newer activity can silently switch the center workspace and attach the next draft or send to the wrong story context.

## P-246 Unbound and bound drafts must never clear or overwrite each other

An unsent ?new conversation? draft is a real recoverable workspace even though no Conversation row exists yet. Each existing Conversation also owns an independent draft. A send, switch, delayed autosave or restore may update only the scope it was created for; it must carry the expected selection and fail closed after selection changes. Sending an existing Conversation must not erase the unsent-new draft, and first send must consume only that unbound draft inside the same transaction that creates and binds the Conversation.

## P-247 Checkpoint identity includes Conversation workspace scope

Payload hash plus task identity is insufficient once one task can visit several Conversations and an unbound new-conversation workspace. Checkpoints must bind a stable scope such as `s1:new` or `s1:conversation:<UUID>` and carry the Conversation identity where one exists. Deduplication may occur only inside that scope; sequence allocation, draft persistence and checkpoint insertion remain one transaction so recovery cannot restore the right bytes into the wrong Conversation.

## P-248 Legacy draft slots are compatibility mirrors, never UI truth

A retired singleton draft such as `draft(id='m0')` may temporarily mirror the active S1 draft for old callers, but it cannot choose the current Conversation, overwrite scoped drafts, or become a recovery authority. New UI and checkpoint code must read `s1WorkspaceState` plus `s1ConversationDraft`. Compatibility mirrors should be removed only in a deliberate migration after all legacy callers are gone, not promoted back into the architecture because they are convenient.

## P-249 Checkpoint audit identity must not decay through tolerant decoding or `SET NULL`

A non-empty but malformed `conversationID` is corrupted data, not the same thing as no Conversation. Likewise, `legacy:m0` and `s1:new` require a null Conversation identity, while `s1:conversation:<UUID>` requires the same parsed UUID in both columns. Decode these bindings fail-closed, reject unknown scopes, and use a restrictive foreign key plus an additive retention migration so databases that already applied an earlier `SET NULL` shape are also protected. Deleting a Conversation must never turn an auditable scoped checkpoint into an apparently unbound record. Regression tests must cover malformed identifiers, scope/identity mismatch, and attempted deletion of a Conversation that owns a checkpoint.

## P-250 Left-region navigation must not own or reset the center Conversation workspace

The Activity Bar and left-region pages are navigation surfaces, not the Agent control plane's state owner. Opening the novel shelf, pushing a book detail page, returning, or later switching among tasks/settings must not recreate the center Conversation view, select another Conversation, clear a scoped draft, interrupt streaming, or replace the current model. Test both empty and persisted shelves while asserting the same center messages, draft, and selected Conversation before and after the complete push/back path.

## P-251 UI test fixtures must be explicit, debug-only, isolated, and persistence-real

A fixture that appears during ordinary startup or can reach a normal application database may hide migration and state-ownership bugs or contaminate user data. Require an explicit launch-environment fixture name plus a valid isolated database scope, compile the bootstrap only for Debug, and fail closed when a requested fixture has an unknown name or a missing or malformed scope.

Ordinary fixtures should seed through the same production persistence APIs the product uses. A complex scale, restore, or Reader-projection fixture may use constrained direct SQL only when it is Debug-only, explicitly requested, bound to a fresh isolated scope, deterministic, and followed by exact reopen and projection assertions. Such a fixture proves database/schema compatibility and UI projection only; it is not evidence that the production writer can create the same state. Formal production-writer evidence requires separate tests that create the state through production APIs and then reopen the real database.

Describe these complex fixtures as fresh-only and insert-once, not idempotent. Also do not describe the entire bootstrap as insert-only: fixture-owned business entities may be inserted once, but the migration-created `s1WorkspaceState.default` singleton is updated to select the fixture Conversation. Fixture strings remain user-visible test data and must pass the same UTF-8 and corruption scans as product copy.

## P-252 Retention migration must stop on already-decayed checkpoint identity

An additive delete trigger protects future Conversation deletion, but it cannot truthfully reconstruct a Conversation identity that an older `ON DELETE SET NULL` schema has already erased. Before installing retention protection, detect scoped checkpoints with null Conversation identity and fail the migration closed. Do not invent an identity, rewrite the scope as unbound, or delete the audit record. Verify transaction rollback leaves the migration unapplied and the damaged row byte-for-byte available for a separate recovery procedure.

## P-253 Capability-gated navigation must hide dead or internal destinations

An icon, row, or button is a product promise. If S1 has no readable chapter, story-memory explanation, material workflow, device diagnostic need, or real task result, do not expose a dead `later` destination merely to make the shell look complete. Project only capabilities backed by meaningful state and a real action; keep diagnostics and build identity on an explicit debug/advanced surface. Tests should assert both the allowed destinations and the absence of retired or premature entries.

## P-254 Activity Bar selection must not become Conversation ownership

The Activity Bar may own which left navigation destination is visible, but it must not own, conditionally construct, or replace the center Conversation workspace. Keep the center Conversation mounted independently so switching to novels, tasks, or settings cannot recreate its model, change the selected Conversation, clear a scoped draft, interrupt streaming, or lose scroll state. Verify complete switch/back paths rather than only checking that destination pages appear.

## P-255 A persisted setting must change every user-facing projection consistently

A setting is not implemented merely because `@AppStorage` changes a visible `Text`. If `显示更新时间` hides timestamps visually, VoiceOver labels and UI-test projections must stop announcing the same time as well; re-enabling it must restore both. Persisted settings need relaunch coverage and must not mutate unrelated Conversation, draft, project, or task state.

## P-256 Ordinary result surfaces must not leak governance vocabulary

`这次结果` is a user-facing collection of real, actionable outcomes, not a convenient place to expose `Artifact`, `Tool Receipt`, revision hashes, bindings, internal Agent reports, or database identity. Preserve those objects and their security semantics in the governed runtime, but translate or move their diagnostic projection behind an explicit advanced surface. An honest empty state is better than fabricated engineering detail or a fake result.


## P-257 Ordinary copy must be a projection, not a deletion of diagnostics

Raw database, Keychain, network, approval, chapter and tool diagnostics are necessary for support and verification, but showing `DB-*`, `KEY-*`, `AGENT-*`, revision, binding, hash or Tool Receipt language in the ordinary cockpit makes the product feel broken and exposes implementation details. Keep the raw diagnostic in a separate diagnostic channel, then project a stable user-facing explanation with a concrete next action. Tests must assert both sides: the user surface contains no engineering code, while the diagnostic value still preserves the original reason.

## P-258 Recovery and replay paths require the same ordinary-language contract as the happy path

Humanizing only the first successful execution is insufficient. Durable recovery, idempotent replay and already-completed branches can append old engineering messages back into the same Conversation after relaunch. Route all of those branches through one tested pure copy projection, while leaving receipts, hashes, versions, approval bindings and completion checks unchanged. Regression tests should compare normal, recovered and replayed delivery and scan the resulting copy for forbidden governance vocabulary.

## P-259 A visual overlay must also be an accessibility modal boundary

Blocking taps with a dimming layer does not remove the covered workspace from VoiceOver. When an independent page or portrait navigation overlay is presented, every covered region must stop hit testing and leave the accessibility tree, while the overlay establishes a modal boundary and its close controls announce the action they actually perform. Page switches should also release composer focus so the software keyboard cannot obscure the newly presented surface.

## P-260 File-scoped Swift imports are outside `-frontend -parse` evidence

A Swift file that references a public type from `CangJieCore` must import `CangJieCore` in that same file; imports in sibling files or target dependency declarations do not enter the file's scope. `swiftc -frontend -parse` cannot detect this because it performs syntax parsing rather than module loading and name resolution, and the Windows SwiftPM package does not compile the iOS App target. Keep an explicit App-source import contract for known cross-module symbols, but treat macOS Xcode App-target compilation as the authoritative semantic check.


## P-261 Windows parse and Core CI cannot prove iOS XCTest actor isolation

Windows SwiftPM/Core tests and `swiftc -frontend -parse` do not fully validate `@MainActor` isolation, cross-actor calls, or `async/await` requirements in the iOS App XCTest target. When a test calls a MainActor-isolated helper, mark the test with the same isolation rather than weakening the helper; when an async GRDB API is selected in an async test context, use `await` rather than downgrading the API or removing the test. Treat macOS Xcode compilation and execution of the actual App XCTest target as authoritative. Preserve the Windows checks as auxiliary evidence only, and record the exact Apple CI result before advancing to IPA packaging.


## P-262 Optional comparison assertions must not chain equality

Swift comparison operators are non-associative, so an assertion such as `optionalString == expected == true` is a compile error rather than an extra truth check. Prefer `XCTAssertEqual(optionalString, expected)` for direct values and better failure diagnostics; reserve `XCTAssertTrue(expression == true)` only for a single optional-Bool comparison that is actually needed. Search the complete App XCTest target for the same chained pattern before pushing, because Windows syntax-only checks may not represent the exact Xcode target build.

## P-263 Concatenated SQL fragments require an explicit token boundary and real-database coverage

Swift multiline string delimiters do not provide a safe compositional contract at the `+` boundary. A shared query ending in `calibration.projectID` concatenated directly with a multiline fragment beginning `WHERE` can become the valid Swift string but invalid SQL token `calibration.projectIDWHERE`. Insert an explicit separator such as `"\n"` at every fragment boundary rather than relying on source indentation, invisible trailing spaces, or an assumed terminal newline. Cover each production composition path with a real SQLite execution test; syntax parsing, source scans, and mocked repositories cannot prove that SQLite can prepare the final statement. When one shared SQL boundary fails across many tests, repair that first cause and rerun the complete Apple suite before classifying later failures as independent or cascading.

## P-264 Evidence discipline must not become CI turnaround churn

A small App-only repair should not spend most of its cycle on unrelated full-suite reruns, repeated document narration, Agent coordination, or shell-environment retries. Preserve the required first-error, test, security, and evidence gates, but select checks by the actual write set: when Core already passed for the parent commit and no Core/package code changed, use focused App syntax/contracts plus complete diff and repository-safety review, then let `macos-15` perform the authoritative Xcode/XCTest/XCUITest validation. Batch every occurrence of the same proven defect class, keep project evidence concise, run sidecar Agents without blocking the critical path, and measure turnaround from failed run to replacement push so process overhead remains visible.
## P-265 Restore fixtures must use the production canonical ToolReceipt identity

Recovery fixtures must use the same canonical receipt identity as production Runtime: opening-plan approval uses `artifact.openingPlan.approve.<requestID>.<bindingHash>`, and a historical message idempotency key cannot substitute for a `ToolReceipt` key. Keep restore fail-closed and fix the fixture rather than weakening production governance; Apple App compilation, XCTest/XCUITest, and IPA packaging run on GitHub Actions `macos-15` through authenticated Windows `gh`, so no local Mac is required or a valid blocker.

## P-266 Runtime restoration tests must opt in after initializer side effects are removed

When ordinary App initialization intentionally stops constructing or restoring a governed Runtime, restore and reconciliation tests must activate that projection explicitly. Otherwise state-restoration assertions can fail against the truthful S1 preview, while tests that only assert that nothing changed can pass without exercising Runtime at all. Keep ordinary-start tests on the no-Runtime path, give historical Runtime tests an explicit activation seam protected by lifecycle and build-identity gates, and preserve lifecycle tests that first activate Runtime through a real interaction. Assert user-visible business copy separately from diagnostic codes: localized status and notices are product contract, while internal English identifiers belong in diagnostic channels rather than ordinary UI text.

## P-267 Conversation message assertions must use the rendered display contract

`AppViewModel.conversationMessages` is a rendered projection, not raw `AgentMessage.content`: assistant messages pass through `AgentRuntimeOrdinaryCopy` and `S1ConversationPreview.displayText`, which prefixes them with `仓颉：`. Tests of this property must assert the exact ordinary rendered string, including the speaker prefix, rather than raw canonical English, an unprefixed localized body, or substring checks such as `contains("approved")`. Raw persistence tests should query `AgentMessage.content` directly when canonical storage is the contract under test.

## P-268 Workspace accessibility identifiers must contain, not replace, descendants

Applying `.accessibilityIdentifier` directly to a composite SwiftUI workspace can cause XCUITest to expose the container identifier on a synthesized child representation while nested controls disappear as independently queryable elements. A hierarchy that shows a single `TextView` named for the workspace and carrying the composer draft is evidence of this collapse, not evidence that the App failed to launch. Before assigning a layout-level identifier to a composite root, use `.accessibilityElement(children: .contain)` so the root remains queryable while child titles, editors, buttons, Reader content, and drawers retain their own identifiers. Keep UI tests that assert both levels; do not repair this class by weakening child queries or deleting the workspace marker.

## P-269 Accessibility containment must be applied at every nested composite identifier boundary

Containment on a workspace root does not automatically preserve descendants of an inner composite view that also has an accessibility identifier. XCUITest can progress past the root and then collapse again at a nested region, exposing that region as a synthesized `TextView` carrying a descendant's value while identifiers such as the conversation title or composer disappear. Inventory every identifier attached to a composite layout, page, pane, overlay, rail, or Reader container whose children are independently queried, and place `.accessibilityElement(children: .contain)` immediately before that identifier. Keep leaf controls unchanged and retain tests that query both the container marker and its descendants; a hierarchy collapse moving inward after a root repair is evidence of another boundary of the same defect class, not a reason to weaken UI assertions.

## P-270 Dynamic accessibility hiding must remain outside containment

A composite region may need both `.accessibilityElement(children: .contain)` when visible and `.accessibilityHidden(...)` when inactive or covered. Modifier order is part of that semantic contract: apply containment first, apply the composite identifier next, and apply the dynamic hidden modifier last as the actual outer gate, so a later identifier cannot reintroduce a hidden region as a queryable container or expose its descendants. `XCUIElement` is a live query proxy, not a captured state snapshot. Verify exact state immediately before opening an independent modal page; while the modal is open, assert that covered workspace elements are absent; after closing it, query those elements again and verify exact state restoration. If a UIKit-backed child such as `TextEditor` remains queryable despite the parent region's hidden state, apply the same dynamic hidden condition directly to that child rather than weakening the modal-boundary assertion.

P-270 follow-up evidence: the direct hidden gate on the UIKit-backed `TextEditor` was insufficient in the failed iPadOS run. The current minimal experiment first applies `.accessibilityElement(children: .ignore)` to make the editor a single leaf accessibility element, then applies its identifier, disabled state, and the same dynamic `.accessibilityHidden(...)` condition. This preserves the modal absence assertion instead of weakening it; accept the change only if the exact replacement CI run proves the composer disappears while its draft and focus restoration remain intact.
