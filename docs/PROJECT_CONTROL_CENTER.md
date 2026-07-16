# CangJie Project Control Center

- Authority: current operational truth
- Updated: 2026-07-16
- Repository: `F:\project\CangJie`
- Remote: `https://github.com/Da-AiXZ/CangJie`, branch `main`

## Product and UI decision

CangJie is agent-first: persistent center conversation controls a governed novel engine through typed tools. The left region has an independent `NavigationStack`; Novel Projects pushes a dedicated page with back navigation, never an in-place tree and never a center reset. The right artifact/approval drawer is collapsed by default. Workbenches are secondary.

## Authority order

`IMPLEMENTATION_PLAN.md` -> this file -> `COMPOUNDING_AND_PITFALLS.md` -> ADRs -> `M0_VALIDATION.md`. `ROADMAP.md` is retired.

## Current milestone

M1 First-Chapter Agent Vertical Slice; current slice M1-A Agent-first shell and real project tools.

```text
open -> center conversation -> ask to create cultivation novel
-> project.create -> durable record -> left Projects page shows it
-> center remains intact -> Agent reports verified receipt
```

## Validated baseline

```text
commit 7b2658caf78fa21d4cbf28e0b8851eb3bcfec23b
Build IPA 29500269591 | iPadOS CI 29500271632 | Core CI 29500273381
IPA F:\project\CangJie\artifacts\CangJie-M0-run-20\CangJie-M0.ipa
SHA-256 2092cfb5fe94b463c453ca25e6107a12de1d77e8be8309c85ee027f8863d62ef
```

User confirmed TrollStore install, launch, immediate restart persistence, and no immediate crash. Not yet proven: M1 UI/tools, complete Keychain tests, real Provider SSE/cancel/reconcile, interview/bible/generation/canon/import/serial flow.

## Source boundaries

Novel package concepts are recorded in the plan. `cc.zip` is clean-room abstract reference only. Private audit evidence stays outside Git at `F:\NVA-AUDIT-0716\` and the workspace `_cc_cleanroom_audit` directory.

## Immediate queue

1. Commit/push this documentation baseline and inspect Actions.
2. Start M1-A with failing core/UI tests.
3. Build stable shell ownership and independent left navigation.
4. Add minimum conversation/project/run/event/artifact schema.
5. Implement real project create/list/inspect and run inspect tools.
6. Complete Fake Provider E2E and candidate IPA.
7. Update this file and pitfalls log after every slice.

## Change log

### 2026-07-16 Agent-first reset

Retired old roadmap; corrected left navigation; established runtime/tool/canon/clean-room baseline. The first write was corrupted into question marks and repeated blocks, so the documents were rewritten in ASCII-dominant UTF-8 and an encoding gate was added. Commit and post-push runs are pending this entry.
