# CangJie project instructions

## Context restoration

Use progressive loading. Do not read complete history by default.

1. Read `docs/PROJECT_CONTROL_CENTER.md`.
2. Read only the relevant section of `docs/IMPLEMENTATION_PLAN.md`.
3. Read the ADRs governing the touched boundary.
4. Search `docs/COMPOUNDING_AND_PITFALLS.md` by relevant keywords.
5. Read `docs/history/` only when exact historical evidence is required.

Authority is scoped, not a single total ordering:

- this file governs execution discipline;
- `IMPLEMENTATION_PLAN.md` governs stable product contracts and S0-S6 definitions;
- `PROJECT_CONTROL_CENTER.md` is the single source for current implementation, verification, blockers and queue;
- `docs/adr/` governs durable architecture decisions;
- `COMPOUNDING_AND_PITFALLS.md` supplies reusable safeguards, not current status;
- `docs/history/` is evidence only and never overrides current authority.

`docs/ROADMAP.md` is retired and must not be recreated or cited as active authority.

## Non-negotiable product boundaries

- CangJie is agent-first. The center conversation is the persistent control plane.
- The left region owns an independent navigation stack. Novel Projects pushes a dedicated left page and never replaces or recreates the center conversation, loses its draft, or interrupts streaming.
- The right artifact and approval drawer is collapsed by default.
- Every side effect passes through a versioned Typed Tool. Model text is never authorization, truth, a ToolReceipt or proof of execution.
- `CangJieCore` remains platform-neutral. SwiftUI, Keychain, GRDB, URLSession and other Apple APIs stay in the App/adapters layer.
- Credentials remain Keychain-only and fail closed. Preserve exact binding, SSRF protection, migration, compensation, idempotency and recovery gates.
- Never claim a product stage, Provider action, tool effect, receipt, recovery result or device behavior without its required evidence.
- `cc.zip` is private/unlicensed reference material. Use clean-room concepts only; never copy its source, prompts, names, schemas, strings, tests or structure.

## Work method

- Plan complex or cross-boundary work. Use TDD for behavior changes; keep `CangJieCore` at or above 90% line coverage and target at least 80% across executable code.
- Agents are optional sidecars, not a mandatory ceremony. Use them only for independent work with minimal context; the main task owns the critical path and never waits on redundant Agent work.
- Preserve all existing uncommitted changes and generated evidence unless the user explicitly authorizes removal.
- Before editing, inspect the current diff and the newest relevant CI evidence.
- When CI fails, read the complete failed log, identify the first causal defect class, and fix every occurrence proven by the same evidence. Do not run one full CI cycle per assertion.
- Fix production code when the contract is violated. Fix a test only when evidence shows its expectation or timing conflicts with the authoritative contract.
- Never weaken product or security gates merely to make CI green.

## Path-aware verification

- Docs-only: verify links, anchors, authority/status consistency, archive integrity and `git diff --check`.
- `CangJieCore`: run focused tests, then full Core coverage when Core source or tests changed.
- App/SwiftUI: run focused syntax/contracts locally; Apple CI is authoritative for semantic compile, XCTest and XCUITest.
- Credentials, network, migration, recovery, signing or candidate changes: run the full applicable security and artifact gates.
- Full coverage and complete Apple suites belong at merge/candidate gates or when their boundary changed; do not repeat unrelated full suites for every micro-fix.
- Before commit, inspect diff, secrets, generated artifacts, private imports, databases and signing material.

## Documentation triggers

- Update `PROJECT_CONTROL_CENTER.md` only when the milestone, implementation status, accepted candidate, blocker or immediate queue changes.
- Update `COMPOUNDING_AND_PITFALLS.md` only for a new cross-task failure mode or a material correction to an existing rule.
- Put commit-by-commit CI logs, rejected experiments and expired status in `docs/history/`; they are not default context.
- Do not duplicate evidence already recorded in the correct destination.

## Execution and stopping

- Progress summaries are status broadcasts, not stop points.
- For an already authorized development run, commit, push and inspect exact-SHA Actions without asking again at each small gate.
- Use bounded `gh run list/view` or the Actions API; never use a blocking `gh run watch` as the control path.
- Pause only for a major product decision, required user input, a true external blocker, or a verified IPA that now requires physical-device installation.
- A candidate stays bound to its exact commit, build, Candidate Set ID, hashes, signature and entitlements. Later docs-only commits do not retroactively change that identity.
