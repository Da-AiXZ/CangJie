# Candidate 34 device rejection

- Date: 2026-07-23
- Commit: `f4fa6172ed70590493134c6bdef3d60282988f8e`
- Version/build: `1.0 (34001)`
- Candidate Set ID: `0b7e5f2911a489ae0fa5da9c1e7a9d405317e847dacb30c7f797c5b222dd51a0`
- Core CI: `29992029384` passed
- iPadOS CI: `29992029418` passed
- Candidate workflow: `29993609075` passed
- Device disposition: rejected

## Device evidence

The paired Main/Probe Keychain isolation check passed. With a real DeepSeek connection, streaming and governed project creation could also complete when the notification explanation was left untouched until the Provider response finished.

The same candidate failed the complete S2 device gate:

- accepting the in-App notification explanation while a Provider response was streaming caused the remaining stream to disappear;
- returning from the system permission sheet left the Conversation at a stale completed connection-setup card with the status `正在核对上次请求的真实结果`;
- dismissing the card did not restore the composer or pending task;
- offline submission and pause flows reopened the same connection card instead of showing their real task state;
- once one Conversation was stuck, new Conversation input was routed back to that state;
- leaving the App during a long task did not produce the expected notification.

## Causal defect class

The notification permission sheet produces transient scene inactivity. Candidate 34 treated every `inactive` event as background termination, cancelled the live Provider task, and then ran startup reconciliation while the same process was still active. Separately, setup presentation treated any unconsumed pending intent as proof that a model connection was required. This collapsed offline, queued, paused and reconciling states into the connection card and locked the composer.

The replacement repair also closes adjacent proven risks: notification consent now follows the system result, Provider status is Conversation-scoped, offline queue admission and prepared-run projection remain atomic through explicit confirmation, pending task notifications are revision-ordered and cancellable, and Provider completion no longer cancels a pending draft autosave.

This file is historical evidence only. Current blocker and queue remain in `../PROJECT_CONTROL_CENTER.md`.

## First replacement validation

Replacement commit `a0ba2d28345f45b918e6026ba99667b7a5477290` passed Core CI `30012079846`. iPadOS CI `30012079896` compiled successfully, passed 20 App XCUITest cases and the complete Probe suite, but failed one of 399 App XCTest cases: `testResumingTaskCancelsItsPendingWaitingNotification`. The test combined its notification-cancellation assertion with entry into the asynchronous Provider fake in one short polling condition, so the failure did not identify which contract timed out. The follow-up keeps the notification test scoped to a strictly newer cancellation revision; the independent offline-resume test remains the Provider-send evidence.

## Second replacement validation

Follow-up commit `5c71ace036fb91e4afe9a32aaaac722f7c402a29` passed Core CI `30014276319`. iPadOS CI `30014276216` again compiled successfully and passed the complete XCUITest and Probe suites, but the same notification test still timed out while waiting for a cancellation above the waiting task revision. The full log therefore isolated a production ordering defect: explicit resume persisted and cancelled a new revision for paused tasks, while `waitingUser/networkConfirmation` deferred both operations to later dispatch. The replacement moves that exact network-confirmation transition and cancellation to the explicit user-action boundary, while unavailable network remains fail-closed and `connectionInvalid` continues through verified-connection dispatch.

## Final replacement validation

The second-validation diagnosis above was incomplete because both polling sites reported through the same helper line. Commit `1082ff1ff118c4c196610508b0787461829814f8` moved the explicit network-confirmation transition to the user-action boundary, but iPadOS CI `30021563174` still reported only the shared timeout helper. Commit `9d66e0b14bbaa2b28e2604c0da2d7bac4e400884` replaced the ambiguous second poll with direct state assertions and split App XCTest from XCUITest so App failures stop before the ten-minute UI suite. iPadOS CI `30023681870` then proved the timeout occurred in the first `requests.count == 1` wait: the count jumped from zero to two.

The actual duplicate came from `applyS1ConversationWorkspace` restoring the pending intent through the registered resume-decision handler, followed by `sendModelDependentMessage` invoking the same decision a second time. Commit `ca309143608525432fd2d28a7db48e6ee98b64a5` removed the duplicate call. Core CI `30025029331` passed; iPadOS CI `30025028405` passed 399 App XCTest cases, 20 App XCUITest cases and the complete Probe suite. Candidate workflow `30026256106` produced Build `35001`, Candidate Set ID `1eac1b4ff7372805e4a75ae28248635d84a7004de850da6f687b78a91b1ff64e`, Main SHA-256 `e32cf0e124d64c3bcd9842a080aed4b13e6ef73b2933c84550193123db2a6559` and Probe SHA-256 `1c73681407a701135d89dc87881aa903e1e3f3aad3405a10db798153fe5d1e74`. Device acceptance remains pending.
