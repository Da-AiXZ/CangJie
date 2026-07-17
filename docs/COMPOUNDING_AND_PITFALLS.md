# CangJie Compounding and Pitfalls Log

Updated: 2026-07-17. Update after every slice or milestone with evidence.

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

Approval is not consent to a category such as ?the opening plan.? It must bind the request ID and canonical hash visible to the user, including exact artifact identity, tool version, parameters, targets, budget, expiration, and expected diff. Never approve by querying whatever record is currently latest.

## P-032 Artifact revision and approval decision are separate records

Artifact workflow status cannot represent immutable content identity, a user's historical decision, and current executable authorization at the same time. Keep immutable artifact revisions, approval requests, and execution receipts separate and verify their relationships explicitly.

## P-033 Recovery must use exact idempotency identity

A successful side effect followed by a crash is reconciled only through the original request, binding hash, tool/version, scopes, output reference, and idempotency key. ?Latest receipt? or ?latest artifact? is not proof and can cross project or lineage boundaries.

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

A replacement-character or `????` scan does not catch text that was decoded and re-encoded through the wrong code page, because strings such as mojibake remain technically valid UTF-8. Review user-facing Chinese source semantically, scan for known mojibake markers, and keep representative Chinese intent/template tests. When rewriting paragraph text, operate on decoded content while preserving the original raw LF, CRLF, or CR separator bytes so fixing encoding does not weaken byte-exact locks.

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
