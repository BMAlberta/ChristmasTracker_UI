# I6b-1 R2 — Runbook and Handoff

## What Changed

| File | Change |
|------|--------|
| `Docs/release-runbook.md` | New — prerequisites, step-by-step procedure (all 9 steps), 4.4 coexistence notes, rollback, troubleshooting table |
| `Docs/handoffs/2026-11-06-ios-to-brian-i6b1.md` | New — what changed, what Brian must do next, unverified assumptions, Section 9 line for PROGRAM.md |

## verify.sh output (pre-commit)

Unchanged from R1 — R2 is documentation only, so only the docs-unaffected sections run.

```
=== verify: derived spec ===
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- tests: 612 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Build complete! (0.18s)
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 45 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Deviations from Gate 1 spec

None. The runbook covers all required sections. The handoff includes the first-release
checklist and flags all unverified assumptions.

## Not done or partial

None. All Gate 1 R2 acceptance criteria met.
