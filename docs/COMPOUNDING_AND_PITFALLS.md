# CangJie Curated Compounding and Pitfalls

- Updated: 2026-07-22
- Scope: reusable cross-task safeguards only
- Historical source: `docs/history/COMPOUNDING_AND_PITFALLS-through-P305.md`

Search this file by the boundary being changed. Do not read the historical P-001 through P-305 log by default. Current milestone and candidate status belong in `PROJECT_CONTROL_CENTER.md`, not here.

## Authority and truth

### R-001 Separate decision, implementation, automation and device status

Never use `FROZEN`, green CI or a generated IPA as shorthand for all four states. Report each dimension independently or capability status will be overstated.

### R-002 Current status has one source

Only `PROJECT_CONTROL_CENTER.md` defines the current milestone, blocker and queue. Historical statements remain evidence of their time and cannot override it.

### R-003 History is searchable evidence, not startup context

Load a dated archive only for an exact prior run, candidate or experiment. Default-loading history reintroduces superseded states and consumes the context needed for current code.

### R-004 Model text is never execution evidence

A model saying it created, saved, paused or completed something proves nothing. Accept only host state and an exact ToolReceipt from the governed tool path.

### R-005 Honest absence beats fabricated progress

When a Provider, tool, receipt, index or recovery result does not exist, show a truthful pending or unavailable state. Never fill a product gap with canned AI-success copy.

## Agent and workspace boundaries

### R-006 The center conversation is persistent infrastructure

Left navigation, drawers, rotation and overlays must not recreate the center model, lose its draft or interrupt its stream. Test state preservation across each structural transition.

### R-007 Left navigation is independent

Novel Projects pushes a dedicated left-region page with a back action. It does not expand a tree in place or replace the center conversation.

### R-008 Agent delegation is optional engineering machinery

Use a sidecar only for independent, bounded work with minimal context. Do not make simple fixes wait for planner/reviewer/security Agents that add no independent evidence.

### R-009 Context and tools follow least authority

Subagents, external material and model calls receive only the context, tools, scope and budget they need. A copied prompt or document cannot expand authority.

## Identity, transactions and recovery

### R-010 Identity-bearing objects are immutable

Connections, artifact revisions, requests, approvals and receipts keep exact IDs, versions and hashes. A changed candidate creates a new identity instead of mutating history.

### R-011 Idempotency replays exact identity only

An idempotency key may return the original result only when every bound identity matches. Any substituted scope, input, model, version or target is a conflict.

### R-012 Commit state and receipt atomically

The durable state transition, checkpoint and ToolReceipt belong in one transaction. A success message is a projection and can be reconciled later.

### R-013 Reconcile unknown outcomes before retry

If a crash or disconnect leaves execution uncertain, inspect the original request identity, durable transaction, usage, stream and receipt. Do not issue a new creative request while outcome remains unknown.

### R-014 Pending intent is a Conversation-scoped mutex

Allow at most one unconsumed model intent per Conversation in both code and schema. Consume it only after the real continuation boundary is committed.

### R-015 An absent intent does not match an unbound Conversation

Unwrap optional scope objects before comparing IDs. `nil == nil` must not disable a fresh composer or produce a false connection-required status.

### R-016 A blank Conversation receives an ID on its first durable turn

Starting a new empty Conversation preserves an unbound draft and creates no row. Tests may require a durable ID only after the first persisted turn.

### R-017 Published migrations are immutable

Never edit a migration that may have shipped. Add an ordered migration and test upgrade from the real historical boundary, including rejection of ambiguous legacy data.

### R-018 Cross-store compensation is one serialized operation

Keychain mutation, read-back verification, SQLite commit and rollback share one process-local coordinator. Compensation must restore or revoke exact prior evidence and fail closed when it cannot prove cleanup.

## Provider and credential security

### R-019 Credentials are Keychain-only

Do not persist API-key plaintext in SQLite, logs, artifacts, UI labels or diagnostics. Scan changed lines and candidate contents before commit.

### R-020 Credential evidence binds the full connection

Bind credential ID, generation/proof, connection ID, Provider, host and port across discovery, Keychain, SQLite, setup journal and request admission. Metadata alone is not credential evidence.

### R-021 Activation and deletion fail closed

Use separate activation/revocation evidence. Save activates last; deletion revokes first. Partial failures remain unusable and retryable rather than silently active.

### R-022 Custom endpoints are hostile input

Require HTTPS, reject userinfo/query/fragment, resolve every destination, reject private/link-local/reserved addresses and unsafe redirects, and attach credentials only after verified pinning.

### R-023 A catalog response is not authentication

A public `200 /models` or unsupported `404` does not prove a Custom key was accepted. Only exact authenticated evidence may authorize Custom connection persistence.

### R-024 No automatic Provider or model switching

The user explicitly selects the current named connection. Failure may reconnect or ask for another saved connection; it never silently rotates keys, substitutes models or fails over Providers.

### R-025 Replay cannot overwrite a later user choice

Replaying historical connection creation cannot rewrite credentials or reselect an older connection. Rotation and current-selection changes use separate versioned operations.

## Platform, UI and lifecycle

### R-026 Keep Core platform-neutral

`CangJieCore` owns portable contracts and state machines. SwiftUI, Security, GRDB, URLSession and Apple lifecycle adapters remain outside it.

### R-027 Apple semantic compile is authoritative for Apple APIs

Windows parse and Core tests cannot prove Darwin import shapes, SwiftUI behavior or XCTest semantics. Use exact-SHA iPadOS CI before declaring those boundaries accepted.

### R-028 Observe nested UI state where it is consumed

A parent observing one `ObservableObject` does not automatically receive a child's changes. The view reading child state must observe it directly or deliberately forward invalidation.

### R-029 Accessibility modality needs structural proof

Covered controls must leave the accessibility tree, especially UIKit-backed editors. Verify actual XCUITest queries and keyboard focus; modifier intent alone is not proof.

### R-030 Lifecycle persistence precedes suspension

Before backgrounding or identity invalidation, save draft, request state, stream fragments, usage and checkpoint. Recovery reports completed, paused, failed, unknown or invalid honestly.

### R-031 Local work remains available without a model connection

No-key state must still allow drafts, browsing, history and connection management. Block only model-dependent continuation, not the ordinary composer before a pending intent exists.

## Testing and CI

### R-032 Fix a causal defect class, not one assertion per CI run

Read the complete log, identify the first root class and repair every occurrence supported by the same evidence. Keep unrelated failures out of that slice.

### R-033 Tests change only when the contract proves them stale

Do not weaken assertions to make CI green. Correct a test when its timing, visibility or state expectation conflicts with the authoritative product or persistence contract.

### R-034 Use portable cancellation test doubles

Record `Task.isCancelled` at task exit and use a valid cancellable wait. `Task.sleep(UInt64.max)` and dependence on one concrete cancellation error are not cross-runtime evidence.

### R-035 Validate paths according to changed risk

Run Core coverage for Core changes, focused App checks plus Apple CI for App changes, and full security/artifact gates for credential, migration, signing and candidate boundaries.

### R-036 Coverage is a risk gate, not repeated ceremony

Keep the 80% project target and stricter Core threshold, but run unrelated full coverage at merge, nightly or candidate gates rather than every docs/UI micro-fix.

### R-037 A passing subset is not final acceptance

Core green does not imply iPadOS green; App XCTest green does not imply XCUITest green; automation green does not imply device acceptance. Name the exact completed gate.

## Delivery and documentation

### R-038 Candidate identity is an indivisible set

Bind commit, version, build, Candidate Set ID, Main/Probe hashes, signature and entitlements. Never mix files from different runs or let a later docs commit rewrite the candidate's identity.

### R-039 Physical-device-only claims remain blocked

TrollStore overwrite behavior, Keychain isolation, activation and lifecycle behavior require the exact device script. Preserve a valid unaccepted artifact instead of weakening the gate.

### R-040 Update governance only on meaningful triggers

Update current-state documents for milestone/status/blocker/queue changes, this file for reusable rules, and history for individual CI/commit evidence. Mechanical double-writing increases contradiction risk.

## Historical lookup

The complete former P-001 through P-305 log remains at `history/COMPOUNDING_AND_PITFALLS-through-P305.md`. Search it when an exact historical ID or failure narrative is required; promote a rule back here only when it remains broadly reusable and non-duplicative.
