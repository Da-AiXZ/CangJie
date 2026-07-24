# Candidate 36 Automation Evidence

This file preserves historical evidence only. Candidate 36 was never accepted on
a physical device and does not describe the current source tree.

- Commit: `e7fdedc8c52a0aeb8b33a2138ea227f3c0f43f94`
- Version/build: `1.0 (36001)`
- Candidate Set ID: `ceb0a2a30931fa4cbd0cdb5d8043889c2352e62dc26f1cca33c5e9c8c03c8c71`
- Core CI: `30044654032` passed
- iPadOS CI: `30044653983` passed
- Apple tests: 402 App XCTest, 22 App XCUITest, 13 Probe XCTest and 1 Probe XCUITest passed
- Candidate workflow: `30045964946` passed
- Main IPA: `CangJie-M0.ipa`
- Main SHA-256: `0f2a9c4680db1421757d9ba686414901bdabebe068af1819f0b504d1aef1c901`
- Probe IPA: `CangJie-Keychain-Isolation-Probe.ipa`
- Probe SHA-256: `abdb00426648a56d945c892f2c6df5b250597e7a512f73bdf5dc436a9788c514`
- Artifact directory: `artifacts/CangJie-S2-run-30045964946/`
- Acceptance: blocked pending exact-set TrollStore device validation.

The macOS workflow independently verified strict ldid signing and distinct
Main/Probe entitlement groups. Windows metadata-only verification independently
matched the manifest, compiled identities, archive structure, IPA hashes and
exported signed-entitlement files. Neither result substitutes for the device gate.

The current repair supersedes Candidate 36 for source-level acceptance and does
not inherit its CI or device status.
