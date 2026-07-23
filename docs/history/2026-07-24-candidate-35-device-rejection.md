# Candidate 35 physical-device rejection

- Candidate commit: `ca309143608525432fd2d28a7db48e6ee98b64a5`
- Build: `35001`
- Candidate Set ID: `1eac1b4ff7372805e4a75ae28248635d84a7004de850da6f687b78a91b1ff64e`
- Core CI: `30025029331` passed
- iPadOS CI: `30025028405` passed
- Candidate workflow: `30026256106` passed
- Device decision: rejected on 2026-07-24

Physical-device checks 1 through 4 passed: exact Main/Probe identity and Keychain
isolation, unchanged canary, notification-permission inactivity without losing the
live stream, and real Provider-backed project creation with a ToolReceipt.

The offline and task-control checks failed as one causal class. A new offline
request did not become visible on the global AI Tasks surface; reconnect exposed
no explicit send confirmation; the originating Conversation remained blocked;
a second Conversation fell back to obsolete S1 copy and queued behind the hidden
primary; and a Provider request paused after it had reached streaming exposed no
resume action.

The prior automation covered platform-neutral contracts and selected-Conversation
ViewModel transitions, but its network fake delivered ideal synchronous state and
its pause test could cancel before the durable request reached streaming. The 20
XCUITest cases contained no offline-confirmation, cross-Conversation primary-task,
streaming-pause or background-recovery sequence. Passing automation therefore did
not prove the rejected device behavior.

The replacement repair separates selected-Conversation and global-primary
projections, reads the freshest monitor snapshot at send/confirm boundaries,
keeps every sent local cancellation as an unknown Provider outcome, permits an
unknown task to end while preserving evidence without retrying the original
request, and adds complete App and controllable Simulator UI sequences. Background
handling is phase-aware: `prepared` remains replayable, `responseComplete` remains
durable, and only `sending` or `streaming` becomes unknown before process-local
cancellation. Notification submission after a real background transition is
protected by a finite UIKit background task instead of relying on an unprotected
fire-and-forget operation. This historical record does not claim that replacement
is accepted; exact-SHA Apple CI and a new physical-device candidate remain required.
