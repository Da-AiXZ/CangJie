# ADR 0003: Exact approval binding and durable reconciliation

- Status: Accepted
- Date: 2026-07-16
- Scope: Opening-plan approval governance; reusable for later high-risk tools

## Context

CangJie is Agent-first, but model text is not authority. An approval button must authorize exactly the proposal the user saw, not whichever artifact, parameters, project version, tool implementation, or cost happens to be current when execution begins. The application must also survive termination after a side effect commits but before the success message or run state is written.

The previous prototype stored approval mostly as artifact status. That is insufficient because artifact identity, approval intent, execution evidence, and UI presentation are distinct records with different lifecycles.

## Decision

### Immutable artifact revisions

Every governed artifact revision has its own `artifactID`, stable `logicalID`, positive `revision`, content hash, optional parent revision, conversation scope, and project scope. A revision is never edited in place after it is presented for approval. A changed proposal creates a new revision.

### ApprovalRequest is separate from Artifact

An `ApprovalRequest` records the exact authorization candidate and its lifecycle. Artifact status is presentation/workflow metadata and is not the source of truth for approval. Multiple requests may refer to the same immutable artifact, but each request has a distinct request ID and binding hash.

### What the approval binds

The user approves the request ID and binding hash displayed by the UI. The binding includes:

- approval request, conversation, and project IDs;
- artifact logical ID, artifact ID, revision, and content hash;
- tool ID and tool version;
- canonical parameters hash;
- target object IDs and versions;
- estimated cost and budget ceiling;
- expiration as epoch milliseconds;
- expected diff hash.

The binding hash is calculated only by platform-neutral `CangJieCore` using a canonical length-prefixed encoding and the versioned `sha256-v1` algorithm. App and UI code do not construct an independent approval hash.

### Candidate comes from current trusted policy

At execution and restore time, the app rebuilds the candidate from the current trusted execution policy, current project version, and stored immutable artifact. It must not copy tool version, parameters, cost, budget, targets, or expected diff from the old request and call that validation. Any material mismatch requires a new request and explicit re-approval.

### Fail-closed validation

Unknown, malformed, duplicate, empty, negative, over-budget, expired, cross-conversation, cross-project, stale-artifact, or hash-mismatched state fails closed. A pending request expires at its deadline. Approval history remains an immutable record after approval, but executable authority expires at the bound deadline and must also be rejected when the artifact, target versions, current tool policy, budget, or exact receipt relationship changes. Historical status and current execution authority are separate facts.

### Transaction and receipt

The approval state transition and its `ToolReceipt` are committed in one SQLite transaction. The receipt binds the same request ID, binding hash, tool ID/version, input hash, scopes, output artifact, outcome, and idempotency key. Reusing an idempotency key with any different identity is a conflict, not a replay.

### Recovery and success-message reconciliation

Restore projects the artifact and approval as one paired state for the focused project. It does not independently select a latest artifact and latest approval. An approved request is trusted only with its exact completed receipt. If the transaction committed but the success message or nonterminal run state did not, restore writes the success message through a durable message idempotency key and reconciles only `queued`, `running`, or `waitingUser` runs to completed. It never overwrites `failed`, `cancelled`, `paused`, or already completed terminal history.

### Legacy data

Legacy artifacts are migrated to explicit exact identities. Legacy approval-like artifact status is never silently promoted to exact authorization. Missing exact requests or receipts produce a new pending approval request.

### UI status separation

Durable Agent business status, transient lifecycle/storage/network notices, and errors are separate projections. A checkpoint or Refresh acknowledgement cannot overwrite the current governed workflow state.

## Consequences

Benefits:

- UI approval authorizes exactly the displayed revision and policy.
- Cross-project selection, stale parameters, replay substitution, and receipt guessing fail closed.
- Unknown-outcome recovery is idempotent and auditable.
- The same contract can govern bible confirmation, chapter generation, canon merge, pause/resume, and destructive branch operations.

Costs:

- More records, hashes, migrations, and reconciliation tests are required.
- A current policy or target-version change intentionally creates user-visible re-approval work.
- Historical approval and current executable authority must be presented as separate concepts.

## Verification

Required automated evidence includes canonical hash vectors, Codable tamper rejection, duplicate-target rejection, stale revision/tool/project/budget/expiration invalidation, exact receipt replay, cross-project restore, missing-message reconciliation, terminal-run preservation, and upgrade from the preceding runtime schema. Physical-device acceptance verifies the displayed metadata, exact approve action, restart recovery, business-status persistence, and visible Refresh acknowledgement.
