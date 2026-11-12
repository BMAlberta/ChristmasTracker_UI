# I4a-1: Regenerate from the synced contract, and make the configuration tests hermetic

Branch: feat/i4a-record-purchase. Pipeline: full (generated-client layer): Gate 1 spec in Docs/epics/I4a-record-purchase.md, isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer one after the other.

## What changed
1. `scripts/make-client-spec.sh` (write mode) regenerated `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` from the synced contract (decisions revision 32, spec sha256 prefix 7c5880219bd5). The transformed-property count guard held at 5 ("Transformed 5 null-schema properties."), so the guard and its pinning test (SpecConformanceTests.swift) did not change. The diff is additive: `quantityPurchased` and `quantityRemaining` (optional integers, minimum 0) on the `Item` schema (the getItem data extends Item, so the detail inherits them), plus two description edits (`deleteList`: "owner or co-owner"; `deleteChild`: 422 CANNOT_DELETE_RESOURCE wording). The package and app built with no compile error and no app change was needed.
2. `readConfiguration(from:apiModeOverride:)` in `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift` takes the override as an explicit parameter and no longer reads UserDefaults. The static `config` constant passes `UserDefaults.standard.string(forKey: "apiModeOverride")` at the one production call site.

## Files
Changed:
- `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json` (regenerated)
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/Configuration/APIModeTests.swift`
- `ChristmasTracker/ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift`
Added: this report. Deleted: none.

## Deviation
The brief says the parameter has a default whose production value reads UserDefaults. The implementer made the parameter REQUIRED (no default) and moved the UserDefaults read to the single static call site. This is stricter: no test can pick up the process default by omission. The acceptance bullet "pass with and without the override argument present" is met because every call passes the override explicitly (nil or a value), and the hermeticity tests set, clear, and restore the process key. The acceptance-reviewer accepted the deviation.

## Tests
- Rewritten (explicit `apiModeOverride: nil`, no new assertions), 12: the 9 tests of suite "readConfiguration Tests" in APIModeTests.swift (apiModeFromDictMock, apiModeFromDictReal, apiModeMissingKeyDefaultsReal, sentryDSNEmptyIsNil, sentryDSNWhitespaceIsNil, sentryDSNTrimmedNonNil, appEnvironmentFallback, durationKeys, sentryDSNTrailingNewline) and the 3 tests of suite "readConfiguration apiBaseURL field" in AppConfigurationTests.swift (validURLProducesNonNil, missingKeyProducesNil, invalidURLProducesNil).
- New, 10, suite "readConfiguration hermeticity" (`.serialized`, helper sets or removes the key and restores the previous value in a `defer`): standardDefaultsMockIgnored, standardDefaultsRealIgnored, identicalWithKeyAbsent, explicitMockWinsNonProduction, explicitRealWinsNonProduction, explicitMockIgnoredInProduction, explicitRealIgnoredInProduction, explicitOverrideIgnoredWhenEnvironmentMissing, garbageOverrideFallsBackToInfoMock, garbageOverrideFallsBackToInfoReal.
- Deleted: none.
- Arithmetic (app suite): 2079 (baseline recorded in the prompt) + 10 new - 0 deleted = 2089, matching the run below (the 12 rewritten tests keep their count). Package suite: 212 + 0 = 212.

## Raw output
Source of each claim: command run unless marked "read".

Before the change (after the contract sync commit, before regeneration), `scripts/verify.sh`:
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
ERROR: Derived spec is out of date. Run scripts/make-client-spec.sh to regenerate.
=== verify: DERIVED SPEC OUT OF DATE — run scripts/make-client-spec.sh ===
```
and `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites failed after 0.019 seconds with 1 issue.` (the only failing test: "Derived spec file matches the Swift-transform applied to contract/openapi.json").

After the change, before the commit, `scripts/verify.sh` (summary lines, then OK):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2089 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.019 seconds.`

After the commit (9f88f78 "I4a: regenerate from contract revision 31 and make the configuration tests hermetic"), `scripts/verify.sh` (summary lines; recorded here in the Story A commit, as agreed with Brian, because a report cannot contain the result of the commit that adds it):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2089 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.017 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
and `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

Also recorded after the earlier commit aabd269 (docs only, before regeneration): `scripts/verify.sh` failed at the derived spec exactly as before, and the package suite reported `Test run with 212 tests in 16 suites failed after 0.020 seconds with 1 issue.` (the same single derived-spec test).

## Gate 2
- convention-reviewer: APPROVE. No hard blocks, no warnings. Evidence: four modified files only; no change under contract/, .claude/, any .pbxproj, or synced Docs; no force unwraps and none of the prohibited frameworks (Combine, GCD); the UserDefaults-mutating suite is serialized and restores the key. Optional nit (not blocking, not changed): long one-line closures at APIModeTests.swift:185-187 and a long line at AppConfigurationTests.swift:177.
- acceptance-reviewer: APPROVE. (a) AppConfiguration.swift:86 takes the parameter, :110 passes it on, and the only remaining UserDefaults read of the key is the static config call at :127-130. (b) Every call passes the override explicitly; the new tests are not vacuous (standardDefaultsMockIgnored fails if production still read the key). (c) `scripts/make-client-spec.sh --check` printed "Derived spec is up to date."; the count is pinned at 5 at SpecConformanceTests.swift:172 and :201 (read). (d) No change under contract/, .claude/, any .pbxproj, or synced Docs.
- Rejections: none. Stuck-detector log: no triggers (implementer green on the first attempt).

## Not done or partial
- The configuration tests were not run with `-apiModeOverride` actually present in the scheme; hermeticity is proven by setting and clearing the process key inside the tests (read and run), not by running the scheme with the launch argument.
- No real-mode or simulator check belongs to this story.
