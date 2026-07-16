# CangJie Agent-First Production Implementation Plan

- Status: ACTIVE AND AUTHORITATIVE
- Baseline: 2026-07-16
- Replaces retired `docs/ROADMAP.md` and all form/workbench-first interpretations.

## 1. Product contract

CangJie is an agent-first, local-first iPad application for 1-2 million-character Simplified Chinese male-audience progression web novels.

```text
App and Agent Runtime = machine
LLM                   = pilot
Typed tools           = controls
Novel engine          = mission system
User                  = final commander
```

The LLM may understand, question, plan, draft, and propose. It cannot mutate state. Project creation, setting persistence, generation, pause/resume, status queries, canon merges, version acceptance, and chapter freezing require real versioned tools and durable receipts.

North-star: idea/materials -> strategic interview -> reviewable cards -> confirmed opening bible -> approved chapters 1-3 -> rolling generation. Rejection requires diagnosis, locked good ranges, confirmed root cause/scope, then a main revision. Default chapter pipeline target is 10-20 minutes and RMB 5-20; hard limits pause. Recovery must be idempotent and must not duplicate charges or lose drafts.

## 2. Workspace contract

```text
left independent pages | center persistent Agent | right artifacts/approvals
```

Center conversation is the primary control plane and retains conversation ID, draft, scroll, streaming, and active run.

Left region owns its own `NavigationStack`. Tapping Novel Projects pushes a dedicated `NovelProjectsPage` inside the left region and shows back navigation. It must not use a `DisclosureGroup`/accordion project tree, replace the center, recreate the conversation model, or silently bind browsing to Agent context. Conversations, Projects, Workbenches, Research, Runs, and Settings are left pages; workbenches are secondary.

Right drawer is collapsed by default and contains project cards, bible, plans, chapters, diffs, canon proposals, research, quality reports, costs, approvals, and receipts. Panel navigation never interrupts the Agent.

## 3. Governed runtime

Safety invariants:

1. Every side effect uses a typed tool.
2. Model output is untrusted proposal data, never permission or proof.
3. App code enforces schema, capability, scope, risk, approval, budget, idempotency, transition, verification, reconciliation, and audit.
4. Showrunner is the only plan/prose/canon merger.
5. Unknown outcomes reconcile before retry.
6. External pages, imports, tool output, and model output cannot change policy.
7. Execution claims link to receipts.

Durable types: `Conversation`, `WorkItem`, `AgentRun`, `RunAttempt`, append-only `RunEvent`, `RunSnapshot`, `ResumeCursor`, `ToolReceipt`, and versioned `Artifact`. Work item, run, and attempt are separate.

```text
queued -> planning -> waitingApproval -> executing
-> waitingNetwork | pausedAtCheckpoint | reconciling
-> completed | failed | cancelled
```

Pause persists the next safe cursor. Cancel ends the run. Background suspension checkpoints; iPadOS 16.6 is not promised unlimited background execution.

Each `AgentTool` declares stable ID/version, input/output schema, capability/scope, risk/approval, idempotency key, cost ceiling, execute/cancel/verify/reconcile handlers, redaction, and audit fields. M1 minimum: `project.create/list/inspect`, `conversation.setProjectFocus`, `run.inspect/pause/resume/cancel`, artifact draft/patch/accept, interview answer, bible propose/confirm, and chapter plan/generate/revise/accept.

Approval binds exact plan revision, tool version, parameters, target versions, cost, expiration, and expected diff. Material changes invalidate approval.

## 4. Agent team

Strategic Adviser asks one highest-information question and converts answers to confirmable rules. Showrunner decomposes/arbitrates and alone merges. Plot Architect manages hierarchy and promises. Character Steward manages motives, costs, relationships, and knowledge. World Steward manages rules/resources/genre purity. Researcher creates sourced cards. Writer writes approved plans but cannot alter canon. Style, continuity, and quality agents submit evidence-located reports without infinite loops. Only one Writer owns prose.

## 5. Novel and canon state

```text
create -> import/research -> strategic interview -> review cards
-> confirm bible -> plan/generate/review chapter 1 -> approve or diagnose/rewrite
-> repeat chapters 2-3 -> unlock rolling serial -> at most 5 unread chapters
```

`FactStatus`: proposed, workingCanon, confirmedCanon, deprecated, contradicted.
`TruthScope`: objective, rumor, belief(characterID), secret(audience).
Chapter: draft, calibrationReview, rejected, approvedFrozen, workingCanon, invalidated, superseded.

Unread chapters are working canon, not human-confirmed. Approval freezes prose and settles canon. Returning to an older chapter preserves the old branch, runs impact analysis, and regenerates only affected descendants. Pause for protagonist-goal changes, major death/turn, world-rule rewrite, main-track change, invalid volume outline, hard conflict, or budget overrun.

Versioned domain records include `AuthorProfile`, `ProjectPreference`, `CreativeContract`, `PlanNode`, `Chapter/Version/Scene`, `CanonFact`, `CharacterKnowledge`, `PromiseLedger`, `ResearchCard`, `TaskRun`, `Checkpoint`, and `UsageRecord`. Chat is not canon.

## 6. Context, providers, import, security

`ContextCompiler` selects minimum versioned fragments: task/plan, confirmed rules, knowledge boundaries, recent prose and hierarchical summaries, open promises, relevant research, author/project preferences, locked ranges, and rejection diagnosis. Each fragment stores source, revision, priority, token estimate, sensitivity, retention, hash, and payload. Strict order: final prose -> canon/timeline/character/promise settlement -> checkpoint -> next chapter.

Provider-neutral protocols support OpenAI Responses/chat-compatible, Anthropic, Gemini, DeepSeek, and custom compatible endpoints such as Agnes; runtime-probe capabilities. Support streaming, structured output, tools, cancellation, usage, errors, and reconciliation. Search adapters: Tavily, Brave, native search, URL Reader. Web is untrusted.

Import TXT/MD/DOCX/PDF/ZIP with PDFKit, page OCR, source tracking, explicit result status, and ZIP traversal/symlink/bomb/size defenses. Export TXT/MD/DOCX and a versioned optional encrypted project package, never API keys.

Keys live only in Keychain. Logs/events/checkpoints/exports redact credentials. HTTPS is default. Skills are validated Markdown/JSON using an internal tool allowlist; no third-party code, shell, arbitrary files, or direct canon write in v1. `cc.zip` is private/unlicensed: absorb only generic concepts; never copy source, prompts, names, exact schemas/events, strings, structure, or tests.

## 7. Architecture and CI

```text
SwiftUI App -> iPad adapters -> CangJieCore
```

Core owns domain/runtime/tool/context/budget/canon protocols and tests on Windows without Apple-only frameworks. App owns SwiftUI, GRDB/SQLite, Keychain, lifecycle, PDFKit, Vision, files, and URLSession. Stable root models separately own shell, conversation, left navigation, right artifacts, and run projection; left routes never own the conversation model.

CI: Windows core build/tests/coverage; pinned macOS/Xcode iPad build and tests; manual/tag device Release `.app`, ad-hoc/fakesign, `Payload/CangJie.app` IPA, SHA-256 and manifest. Acceptance combines deployment target, available simulator, and the physical iPadOS 16.6.1 device.

## 8. Milestones

### M0 validated feasibility
Windows core, Actions builds, installable IPA, device launch/basic persistence. It is not product UX.

### M1 current: first-chapter Agent vertical slice

- M1-A: persistent center, independent left project page, collapsed right drawer, minimum durable models and real project/status tools. E2E: natural-language project request -> `project.create` -> durable project -> visible left page -> unchanged center -> verified receipt.
- M1-B: one-question strategic interview, first-chapter card/bible proposal, exact plan/budget approval surviving restart.
- M1-C: V1 generation, evidence review, locked ranges, diagnostic rejection, confirmed scope, V2 diff, acceptance and retained history.
- M1-D: network/force-quit/background/repeated-tap recovery, unknown-outcome reconciliation, deterministic Fake Provider E2E, same-SHA device candidate.

### M2
Secure import/OCR/ZIP, search/research cards, genre-purity research, richer interview, field approval, confirmed production bible.

### M3
Three chapter gates, diagnosis, locked preservation, author/project preference separation, canon settlement, frozen chapters.

### M4
Hierarchical rolling plans, five-chapter lead, working canon, major-event/budget pauses, branch impact, knowledge/timeline/relationships/resources/promises.

### M5
Chinese novel regression, AI-pattern/repetition checks, exports/encryption/Face ID, accessibility/performance, licenses/SBOM/security audit/release candidate.

## 9. Quality gates

TDD is mandatory. Targets: core 90%, all executable 80%+. Unit tests cover navigation identity, context budget, canon/truth/knowledge, approval/rejection, three-chapter unlock, five-chapter cap, cost/cancel/idempotency/branches. Integration covers SQLite recovery, SSE/429/timeout/malformed data/reconciliation, search provenance, imports and round trips. E2E covers idea-to-project, left navigation without center loss, rejection and locked rewrite, recovery, backup/export, and Face ID.

Chinese fixtures check genre pollution, knowledge leakage, ability/item/count/geography/time conflict, traceable promises, motivated choices/costs, repetitive AI language, false hooks, and summary dialogue. LLM judges cite evidence and never independently approve.

Every slice updates the control center and pitfalls log and reports version nature, included, excluded, verification, and next.
