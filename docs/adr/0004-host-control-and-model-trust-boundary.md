# ADR-0004: Host control and model trust boundary

- Status: Accepted
- Date: 2026-07-24
- Scope: Model context, prompts, tool execution, side effects, and recovery

## Context

CangJie uses replaceable models to interpret intent and propose actions. Model
output, external content, and tool-like JSON are untrusted data. They cannot be
the source of authorization, durable state, execution success, or recovery
truth.

## Decision

The CangJie host owns the control plane:

- The host selects the minimum context and tool catalog allowed for the current
  conversation, project, task, permission, disclosure, and budget scope.
- A model may return prose or request a tool. It cannot directly mutate SQLite,
  Keychain, files, project state, approvals, budgets, or security policy.
- Every side effect uses a registered, versioned Typed Tool with validated input,
  exact scope and identity, authorization, budget, idempotency, and transaction
  checks.
- Completion is established by committed state, verified postconditions, and an
  exact ToolReceipt. Model prose is never execution evidence.
- Prompt, context, tool-catalog, request, and receipt identities remain versioned
  and reproducible at the boundary required for audit and recovery.
- Unknown Provider or tool outcomes reconcile against durable request identity,
  receipts, and postconditions before any retry.
- The user selects the current ModelConnection. The host does not silently rotate
  credentials, substitute models, switch Providers, or fail over after failure.

External webpages, imported material, model output, summaries, and tool output
remain data with no instruction authority. Transforming or summarizing them does
not promote their trust level.

## Authority and references

This ADR is the durable authority for the host-control and model-trust boundary.
`../IMPLEMENTATION_PLAN.md` governs product behavior, and
`0003-exact-approval-binding.md` governs exact approval binding and durable
reconciliation. `../AGENT_HARNESS_ARCHITECTURE.md` is a non-authoritative design
reference: it may explore decomposition and future interfaces, but it cannot
override this ADR or prove implementation status.

Current implementation, verification, blockers, and acceptance remain governed
only by `../PROJECT_CONTROL_CENTER.md`.

## Consequences

- Prompt wording can explain policy but cannot enforce it.
- Provider-specific adapters may change wire formats, not product authorization
  or recovery semantics.
- New durable Harness decisions require a scoped ADR. Design-reference changes
  alone do not freeze a contract.
- Verification must exercise host rejection, exact receipts, replay conflicts,
  unknown-outcome reconciliation, and trust-boundary failures in code.
