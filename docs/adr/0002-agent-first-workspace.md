# ADR-0002: Agent-first workspace and independent left navigation

- Status: Accepted
- Date: 2026-07-16

The center is a persistent Agent control plane. The workspace is:

```text
left independent NavigationStack | center persistent Agent | right collapsed artifacts/approvals
```

Tapping Novel Projects pushes a dedicated page inside the left region and provides back navigation. It does not expand a project tree in place, replace the center, recreate the conversation model, or silently change Agent context. Workbenches are secondary.

All side effects use typed tools. Model prose is never proof of execution. Showrunner alone merges plan, prose, and canon. Rejected alternatives: form-first onboarding, root-rail accordion trees, direct LLM mutation, and tool-like JSON treated as a receipt.
