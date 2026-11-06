# I1a-5: Derived OpenAPI Spec for TrackerAPI

**Package:** I1-a fix pass  
**Date:** 2026-11-05  
**Author:** Implementer subagent

---

## Files Changed / Created

| File | Change Type | Summary |
|---|---|---|
| `scripts/make-client-spec.sh` | New | Shell script that transforms `contract/openapi.json` → `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`, collapsing 5 anyOf-null / bare-null schemas into optional `$ref` schemas or removing them |
| `scripts/verify.sh` | Modified | Added `make-client-spec.sh --check` as the first verify step |
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` | New | Derived spec produced by `make-client-spec.sh`; replaces the old `openapi.yaml` symlink |
| `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml` | Deleted (git rm) | Old symlink to `contract/openapi.yaml` — removed because generator now uses `openapi.json` |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/SpecConformanceTests.swift` | New | Two tests verifying the derived spec matches the Swift-reimplemented transform and that exactly 5 properties are transformed |
| `LocalPackages/TrackerAPI/Tests/TrackerAPITests/DecodingTests.swift` | Modified | Replaced all Mirror-based assertions with direct Swift property access; updated NOTE block |

---

## Gate 2 verdicts

**Convention reviewer:** PASS (no violations in derived-spec additions; explaining comment present for `@Instrumented` exception).

**Acceptance reviewer:** PASS — all 10 new decoding tests pass; derived spec confirmed current; 486 app tests and 93 package tests pass; `contract/` unmodified. Commit: `eed4b93`.

---

## Raw verify.sh output

```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
--- errors (first 20) ---
--- last 8 lines of /tmp/ct-build.log ---
note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestBundleInject.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/Frameworks/libXCTestSwiftSupport.dylib'

note: Removed stale file '/tmp/ct-derived/Build/Products/Debug-iphonesimulator/ChristmasTracker.app/PlugIns'

** BUILD SUCCEEDED **

=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 486 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793929827.xcresult ---
=== verify: TrackerAPI package tests ===
[... build output omitted for brevity ...]
Test run with 93 tests in 10 suites passed after 0.012 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

Exit code: 0

---

## Test count

**Before (prior to derived spec):**
- App: 486 pass, 0 fail
- Package: 83 pass + pre-existing failure (`Concurrent 401 responses cause exactly one refresh call`) = 83+1 (note: that test actually passes now — see deviations)

**After:**
- App: 486 pass, 0 fail
- Package: 93 pass, 0 fail

**10 new G1 tests added by the test-writer:**

| Test Name | Suite | Status |
|---|---|---|
| `Decode ListSummary with null coOwner decodes base fields correctly` | TrackerAPI Decoding | PASS |
| `Decode ListSummary with non-null coOwner decodes successfully` | TrackerAPI Decoding | PASS |
| `Decode Item with money expectedUnitPrice of 349.99 decodes required fields correctly` | TrackerAPI Decoding | PASS |
| `Decode Item with null expectedUnitPrice decodes with nil expectedUnitPrice` | TrackerAPI Decoding | PASS |
| `Decode YearStats with null totalBudget yields nil totalBudget` | TrackerAPI Decoding | PASS |
| `Decode YearStats with non-null totalBudget yields the correct value` | TrackerAPI Decoding | PASS |
| `Decode StatsYearResponse with null budget yields nil budget` | TrackerAPI Decoding | PASS |
| `Decode StatsYearResponse with non-null budget yields a BudgetStats value` | TrackerAPI Decoding | PASS |
| `Derived spec file matches the Swift-transform applied to contract/openapi.json` | SpecConformance | PASS |
| `Applying the nullable transform to contract/openapi.json produces exactly 5 changes` | SpecConformance | PASS |

Note: `Decode PurchaseConfirmationRequiredData without purchase field succeeds` was already in the test suite (generator had already dropped the bare-null `purchase` field) and continues to pass.

---

## Generated Swift property types

| Field path | Generated Swift type | Previously |
|---|---|---|
| `Components.Schemas.ListSummary.Value1Payload.coOwner` | `Components.Schemas.PersonRef?` | Dropped (anyOf[PersonRef, null] unsupported) |
| `Components.Schemas.Item.expectedUnitPrice` | `Components.Schemas.Money?` (= `Swift.Double?`) | Dropped (anyOf[Money, null] unsupported) |
| `Components.Schemas.YearStats.totalBudget` | `Components.Schemas.Money?` (= `Swift.Double?`) | Dropped (anyOf[Money, null] unsupported) |
| `Components.Schemas.StatsYearResponse.budget` | `Components.Schemas.BudgetStats?` | Dropped (anyOf[BudgetStats, null, description] unsupported) |
| `Components.Schemas.PurchaseConfirmationRequiredData.purchase` | (property does not exist) | Already absent — bare-null `{type:null}` was dropped; now explicitly removed by transform |

---

## Deviations from spec

1. **Pre-existing failure resolved:** The spec anticipated `Concurrent 401 responses cause exactly one refresh call` as a pre-existing H6 failure. It passes in the actual run (93/93). The spec instructions predated the fix that resolved it, or the test passes with the current implementation. Total test count is 93 (not 95 as the spec anticipated), and all 93 pass.

2. **Test count lower than spec anticipated:** The spec said "85 original tests (minus 1 pre-existing failure) + 10 new G1 tests = 94 passing, 1 pre-existing failure." The actual count before this story's new tests was 83 (not 85), and the anticipated pre-existing failure already passes. After adding the 10 new tests: 93 total, all passing.

3. **`openapi.yaml` was a symlink:** The file `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml` pointed to `contract/openapi.yaml`. It was removed with `git rm` and replaced by the derived `openapi.json`.

---

## Not done or partial

None — all checklist items completed:

- `scripts/make-client-spec.sh` exists, is executable, prints "Transformed 5 null-schema properties."
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` exists
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.yaml` symlink is gone
- `scripts/verify.sh` has the derived-spec check as the first verify step
- All Mirror-based assertions in DecodingTests.swift replaced with direct property access
- `swift test --package-path "LocalPackages/TrackerAPI"` runs 93 tests: all pass
- `scripts/verify.sh` exits 0
- Nothing under `contract/` or the app target was modified
- No commit made
