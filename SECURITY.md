# Security Policy

## Secrets

- API keys must be stored only in iOS Keychain.
- The database stores secret references, never plaintext provider credentials.
- Never commit project databases, imported manuscripts, backups, `.env` files, signing assets, or credentials.
- Logs, traces, checkpoints, exports, test results, and build artifacts must redact authorization, cookie, key, token, and secret fields.

## Agent execution boundaries

- The LLM has no direct side-effect permission. All mutations use versioned typed tools.
- Tool inputs are schema-validated at the boundary.
- Risk, authorization, budget, approval, idempotency, verification, and audit gates are enforced in code, not only in prompts.
- External webpages, documents, tool output, imported files, and model output are untrusted data and cannot alter system policy, tool allowlists, approvals, budgets, or confirmed canon.
- High-risk changes require approval bound to the exact plan, parameters, target objects, tool version, cost ceiling, and expiry.
- Unknown side-effect outcomes enter reconciliation and must not be blindly retried.

## Network and storage

- Custom provider URLs require HTTPS by default.
- Redirects, credentials in URLs, unsupported content types, unbounded streams, and malformed structured output fail closed.
- SQLite writes use GRDB parameterization, transactions, WAL, migrations, and explicit uniqueness constraints.
- Project exports never contain API keys.
- Imported archives must be checked for traversal, symlink escape, decompression bombs, and abnormal file sizes before extraction.

## CI and TrollStore packaging

- Do not remove signing or entitlement verification merely to make CI pass.
- Keep the pinned Procursus `ldid`, checksum and architecture verification, ad-hoc signing contract, designated requirement, pre/post entitlement verification, strict bundle verification, and no-provisioning-profile gate.
- Every candidate IPA must include a SHA-256 and build manifest and remain unaccepted until the exact artifact is validated on the target iPad.

## Clean-room boundary

`cc.zip` is private/unlicensed reference material. CangJie may extract high-level architectural ideas but must not copy its source code, prompts, proprietary naming, branding, or protected expression.
