# Security Policy

## Secrets

- API keys must be stored only in iOS Keychain.
- Never commit project databases, imported manuscripts, backups, `.env` files, signing assets, or credentials.
- Logs must redact authorization, cookie, key, token, and secret fields before persistence.

## M0 threat boundaries

- Network streaming only accepts explicitly configured HTTPS URLs.
- SQLite writes are parameterized through GRDB.
- The checkpoint payload is metadata only; no API key is serialized.
- Imported archives and third-party Skills are not enabled in M0.