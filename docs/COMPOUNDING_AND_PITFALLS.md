# CangJie Compounding and Pitfalls Log

Updated: 2026-07-16. Update after every slice or milestone with evidence.

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
