# I1a-7 — Money, Error Codes, Single-Flight

**Date:** 2026-11-05
**Story:** G3 implementation fix pass for I1-a

## Files Changed

| File | Change | Summary |
|------|--------|---------|
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/MoneyHelpers.swift` | Rewritten | `doubleToDecimal` returns `Decimal?` (nil for NaN/Infinity); uses `String(format:) + Decimal(string:locale:)` only; no private Decimal fields; `decimalToDouble` uses `NSDecimalRound` → string → `Double` |
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/TrackerAPIError.swift` | Modified | `isCredentialFailure`: removed 1007 (UNUSED), added 1013; added `ErrorCodeClassification` enum + `classifyErrorCode` free function |
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/Middleware/RefreshOn401Middleware.swift` | Modified | Stale-token detection: captures `requestToken` before first request; after 401, compares `currentToken` — if rotated by concurrent caller, replays directly with zero refresh calls |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/MoneyHelpersTests.swift` | Rewritten | Decimal VALUE equality (not `.description`); handles `Decimal?` return; NaN/Infinity nil tests; 0.1+0.2→0.3 round-trip; JSON encoding check |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TrackerAPIErrorTests.swift` | Modified | 1007 test flipped to expect `false`; 1013 test added; 32 new `classifyErrorCode` tests |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/RefreshOn401MiddlewareTests.swift` | Modified | Added `staleTokenReplaySkipsRefresh` test |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/TestHelpers.swift` | Modified | `FakeAccessTokenProvider` added `init(tokens: [String])` for token-sequence simulation |

## Gate 2 Verdicts

**Convention reviewer:** Initial verdict REJECT — `@Instrumented` absent on `RefreshOn401Middleware.intercept`.

**Orchestrator override:** N/A. TrackerAPI is a Swift package with no Sentry dependency (I1-a epic: "The package has no Sentry dependency"). The `@Instrumented` macro is unavailable in this module; it applies only to app-layer service and repository types. An explaining comment was added to `intercept` documenting this. The stray `test_check` binary (created by a subagent) was deleted.

Convention reviewer re-evaluation: PASS (all other items passed; blocking item resolved by comment and Orchestrator judgment).

**Acceptance reviewer:** PASS — All 5 ACs verified with passing tests; 486+141 passing; contract/ unmodified. Advisory: error code 4009 (`MEMBER_EMAIL_NOT_FOUND`) was misclassified as `.notFound` in the G3 spec; `Docs/error-codes.md` says `show message`. Fixed by Orchestrator before commit: `classifyErrorCode` now returns `.showMessage` for 4009, test updated with reason.

## Raw verify.sh Output

```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
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
Build complete! (4.98s)
...
Test run with 141 tests in 11 suites passed after 0.015 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test Count

- Before: 104 package tests (pre-G3)
- After: 141 package tests (104 existing + 37 new)

### New G3 Tests

| Test | Suite | Status |
|------|-------|--------|
| `doubleToDecimalZeroPointOne` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalZeroPointZeroSeven` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalNineteenNinetyNine` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalOneThousandTwoThirtyFourPointFive` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalLargeValue` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalZero` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalNegative` (rewritten) | MoneyHelpers | PASS |
| `doubleToDecimalNaN` | MoneyHelpers | PASS |
| `doubleToDecimalPlusInfinity` | MoneyHelpers | PASS |
| `doubleToDecimalMinusInfinity` | MoneyHelpers | PASS |
| `additionRoundTrip` | MoneyHelpers | PASS |
| `decimalToDoubleJSONEncoding` | MoneyHelpers | PASS |
| `roundTrip*` (7 tests, rewritten) | MoneyHelpers | PASS |
| `code1007IsNowNotCredentialFailure` | TrackerAPIError | PASS |
| `code1013IsCredentialFailure` | TrackerAPIError | PASS |
| `classify*` (32 tests) | TrackerAPIError | PASS |
| `staleTokenReplaySkipsRefresh` | RefreshOn401Middleware | PASS |

## Deviations

### decimalToDouble implementation

The spec prescribed `NSDecimalNumberHandler` + `.doubleValue`. The implementer used `NSDecimalRound` + `NSDecimalNumber.stringValue` + `Double(formatted)`. The string-parse path avoids the floating-point imprecision of `NSDecimalNumber.doubleValue` (which can produce a Double like `19.990000000000001` whose JSON encoding is not `"19.99"`). The `decimalToDoubleJSONEncoding` test verifies the JSON output is exactly `"19.99"`. Both approaches are semantically equivalent for the passing value range; the string path is safer.

### TestHelpers.swift modified by test-writer

`TestHelpers.swift` is a test-support file (not a test file per se), and the `FakeAccessTokenProvider` update (adding `init(tokens:)`) was required for the stale-token test to compile. This is a support file edit, not production code. No existing tests were broken.

## Not Done or Partial

None. All three production files required by the spec are modified. 141 package tests and 486 app tests pass. verify.sh exits 0.
