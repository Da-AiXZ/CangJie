# CangJie project instructions

## Restore context before work

Read in order: `docs/IMPLEMENTATION_PLAN.md`, `docs/PROJECT_CONTROL_CENTER.md`, `docs/COMPOUNDING_AND_PITFALLS.md`, then relevant ADRs. This order wins conflicts. `docs/ROADMAP.md` is retired.

## Non-negotiable direction

CangJie is agent-first. The center Agent conversation is the persistent control plane. The left region owns an independent navigation stack: tapping Novel Projects pushes a dedicated page inside the left region with a back action. It must not expand a project tree in place, replace the center conversation, recreate its model, lose its draft, or interrupt streaming. The right artifact/approval drawer is collapsed by default.

All side effects pass through typed tools. Model text is never authorization, truth, a tool receipt, or proof that an action occurred.

## Work discipline

- Plan complex work, use TDD, keep `CangJieCore` platform-neutral, and target at least 80% executable coverage.
- Never remove product or security gates merely to make CI green.
- Inspect the newest failing Actions log and first real error before changing code.
- When remote verification is requested, run minimum deterministic local checks, commit, push, and inspect Actions without prolonged speculation.
- Before commit, review diff, secrets, generated artifacts, private imports, databases, and signing material.
- After every implementation slice or milestone, update both the control center and pitfalls log with evidence.
- `cc.zip` is private/unlicensed reference material. Use clean-room concepts only; never copy source, prompts, proprietary names, exact schemas, strings, tests, or structure.
