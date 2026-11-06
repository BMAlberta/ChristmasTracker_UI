# I1a-10 — Factory Fractional-Second Dates (H2)

**Date:** 2026-11-05  
**Story:** H2 — Prove fractional-second dates decode through the factory-built client  
**Commit:** 79c9474

---

## What Changed

One file added to (no production changes):

| File | Change |
|------|--------|
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerClientFactoryTests.swift` | 2 new tests in the `// MARK: - Date transcoder` section |

---

## New Tests

| Test | Fixture timestamps | Status |
|------|--------------------|--------|
| `clientDecodesFractionalSecondISO8601Dates` | `createdAt: "2025-12-30T10:00:00.123Z"`, `updatedAt: "2025-12-30T10:00:00.456Z"`, `timestamp: "2025-12-30T10:00:00.789Z"` | PASS |
| `clientDecodesZeroFractionalSecondISO8601Dates` | `createdAt: "2025-12-30T10:00:00.000Z"` etc. | PASS |

Both tests call `client.getCurrentUser()` through a factory-built client, assert `.ok` response, and assert `body.data.firstName == "Alice"`. A throw at any point would be a test failure, proving the transcoder is not wired or cannot handle the format.

Both passed immediately — `TrackerDateTranscoder` already handles fractional seconds and `TrackerClientFactory.make` already wires it correctly. These tests are now the coverage proof for that path.

---

## Test Count

| Before | After |
|--------|-------|
| 144 (post-H1) | 146 |

---

## verify.sh Output

```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 486 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed after 0.012 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Results

**Convention reviewer:** PASS — camelCase names, no force unwraps in new code, no DispatchQueue, no secrets.

**Acceptance reviewer:** PASS — both ACs verified with passing tests; 146/146 passing; no production code changed; `contract/` unmodified.

---

## Not Done or Partial

None.
