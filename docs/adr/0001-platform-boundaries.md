# ADR-0001: Platform boundaries and dependency direction

- Status: Accepted
- Date: 2026-07-16

`CangJieCore` does not depend on SwiftUI, Security, GRDB, PDFKit, Vision, or other Apple-only APIs. It owns state machines, tool contracts, context, budget, provider-neutral streaming, canon, and checkpoint decisions and is tested via Windows SwiftPM.

The iPad layer implements Keychain, SQLite, lifecycle, files, OCR, and URLSession adapters:

```text
SwiftUI App -> iPad adapters -> CangJieCore
```

The user has no Mac, so core behavior must be testable on Windows while native SwiftUI remains the device experience.
