# I1-a Story A3 — Verify Script and Handoff

**Package:** I1-a — TrackerAPI Swift Package  
**Story:** A3 — Add package tests to verify.sh; add -skipPackagePluginValidation to build.sh and test.sh  
**Date:** 2026-11-05

---

## Files Modified

| File | Change |
|---|---|
| `scripts/verify.sh` | Added `swift test --package-path "LocalPackages/TrackerAPI"` step after the main unit-test step |
| `scripts/build.sh` | Added `-skipPackagePluginValidation` to the xcodebuild invocation |
| `scripts/test.sh` | Added `-skipPackagePluginValidation` to the xcodebuild invocation |

## Files Added

| File | Purpose |
|---|---|
| `Docs/reports/I1a-4-verify-and-handoff.md` | This report |
| `Docs/handoffs/2026-11-05-ios-to-brian.md` | Package-end handoff |

---

## Raw verify.sh Output

```
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 486 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Build complete! (7.95s)
Test run with 85 tests in 9 suites passed after 0.007 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Count

- App tests: **486 passed** (unchanged from baseline)
- Package tests: **85 passed** (11 from A1 + 74 from A2)
- Total: **571**

---

## Deviations from Prompt

None. The three script edits are exactly as specified.

---

## Not Done or Partial

None.
