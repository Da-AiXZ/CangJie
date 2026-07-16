# M0 Feasibility and Device Validation

> Version nature: engineering feasibility baseline, not the product UI and not a completed Agent.
> Baseline date: 2026-07-16.

## Validated

- Windows builds/tests the platform-neutral Swift package.
- GitHub Actions compiles the iPad app and packages a device IPA.
- TrollStore installed the IPA on the user's M1 11-inch iPad Pro running iPadOS 16.6.1.
- The app opened without immediate crash.
- Basic typed content persisted across an immediate restart in the tested scenario.

## Evidence

```text
Baseline commit: 7b2658caf78fa21d4cbf28e0b8851eb3bcfec23b
Build TrollStore IPA: 29500269591
iPadOS CI:            29500271632
Core CI:              29500273381
IPA: F:\project\CangJie\artifacts\CangJie-M0-run-20\CangJie-M0.ipa
SHA-256: 2092cfb5fe94b463c453ca25e6107a12de1d77e8be8309c85ee027f8863d62ef
```

## Not validated by M0

Agent-first UI, real project tools and receipts, full Keychain reinstall/isolation, real Provider SSE/cancellation/reconciliation, research/import, strategic interview, production bible, chapter generation, canon governance, and rolling serial generation.

## Background limitation

iPadOS 16.6 may suspend the app in background. CangJie checkpoints at safe boundaries and resumes after return; it does not promise indefinite background generation.

Outstanding checks move into the relevant M1 slices and must not be reported complete early.
