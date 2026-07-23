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
