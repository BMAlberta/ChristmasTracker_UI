# I1-b Story 1 — Fix API Hosts, Validate Base URL, Verify Effective Values

**Date:** 2026-11-05
**Branch:** feat/i1b-api-integration
**Story:** B1 — fix xcconfig `//` escaping, add `validateBaseURL`, add ATS entry

---

## Files Changed

### New interface added

**`ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift`**
- Lines 34–44: added `BaseURLError` enum (`nilOrEmpty`, `unparseable`, `unsupportedScheme`, `emptyHost`, `nonRootPath`, `queryPresent`)
- Lines 70–87: added `nonisolated static func validateBaseURL(_ raw: String?) -> Result<URL, BaseURLError>` to `AppConfiguration`
- Lines 55–59: updated `readConfiguration(from:)` to call `validateBaseURL` instead of bare `URL(string:)` for the `apiBaseURL` field
- Line 72–74: updated stale doc comment on `apiBaseURL` to reflect new hostnames

### xcconfig files fixed

**`ChristmasTracker/ChristmasTracker/Config/Config.xcconfig`** (Release)
- Line 21: `API_BASE_URL = https://api.christmastracker.com` → `API_BASE_URL = https:/$()/api.bmalberta.com`

**`ChristmasTracker/ChristmasTracker/Config/Config-Debug.xcconfig`** (Debug)
- Lines 15–16: removed stale `// Debug Overrides` comment and changed `API_BASE_URL = https:/ /api-dev.christmastracker.com` → `API_BASE_URL = http:/$()/localhost:3010`

**`ChristmasTracker/ChristmasTracker/Config/Config-QA.xcconfig`** (QA)
- Line 16: `API_BASE_URL = https:/ /api-qa.christmastracker.com` → `API_BASE_URL = http:/$()/localhost:3010`

### Info.plist updated

**`ChristmasTracker/ChristmasTracker/Info.plist`**
- Added `NSAppTransportSecurity` / `NSAllowsLocalNetworking = true` (lines 24–28). No `NSAllowsArbitraryLoads`.

### check-config.sh updated

**`scripts/check-config.sh`**
- `check_config` now accepts a 5th parameter `EXPECTED_API_BASE_URL` and verifies `actual_api_base_url` from build settings
- Three call sites updated: Debug and QA expect `http://localhost:3010`; Release expects `https://api.bmalberta.com`
- Added ATS checks after the existing plist check: `NSAllowsLocalNetworking` must be present; `NSAllowsArbitraryLoads` and `NSAllowsArbitraryLoadsInWebContent` must NOT be present

### Test file fixed

**`ChristmasTracker/ChristmasTrackerTests/Core/Configuration/AppConfigurationTests.swift`**
- Three uses of `try #require(result.get())` changed to `try #require(try result.get())` — the Swift 6.3.3 Testing `#require` macro does not propagate `try` to throwing subexpressions in its closure expansion; the inner `try` is required

---

## Effective API_BASE_URL — Before and After

| Config   | Before (broken)                             | After (xcodebuild output)        |
|----------|---------------------------------------------|----------------------------------|
| Debug    | `https:/ /api-dev.christmastracker.com`     | `http://localhost:3010`          |
| QA       | `https:/ /api-qa.christmastracker.com`      | `http://localhost:3010`          |
| Release  | `https:` (truncated by xcconfig `//`)       | `https://api.bmalberta.com`      |

Actual xcodebuild output:
```
Debug:   API_BASE_URL = http://localhost:3010
QA:      API_BASE_URL = http://localhost:3010
Release: API_BASE_URL = https://api.bmalberta.com
```

---

## Raw verify.sh Output Summary

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
--- tests: 499 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed after 0.011 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

Previous baseline: 486 app tests + 2 existing AppConfiguration suite tests = 488 (the existing suite had 3 tests in `AppConfigurationTests`, plus others). The prior run shows 486 passed. After this story: 499 total passed.

New tests added (11):

**Suite: `AppConfiguration.validateBaseURL`**
1. `http localhost with explicit port is accepted`
2. `https domain without trailing slash is accepted`
3. `https domain with trailing slash only is accepted`
4. `URL with a non-trivial path is rejected`
5. `Bare scheme with no host is rejected`
6. `Empty string is rejected`
7. `URL with a literal space is rejected`
8. `ftp scheme is rejected`
9. `nil input is rejected`
10. `URL with a query string is rejected`

**Suite: `readConfiguration apiBaseURL field`**
11. `Valid API_BASE_URL produces a non-nil apiBaseURL`
12. `Missing API_BASE_URL key produces nil apiBaseURL`
13. `Invalid API_BASE_URL produces nil apiBaseURL`

That is 13 tests in the two new suites. 486 + 13 = 499. Confirmed: 0 tests removed.

Note: the story description stated 11 tests; the actual test file has 13 (10 in `ValidateBaseURLTests` + 3 in `ReadConfigurationBaseURLTests`). All pass.

---

## Build/Test Loop Log

**Attempt 1:**
- Build: succeeded
- Test: failed — `Call can throw, but it is not marked with 'try'` in macro expansion of `#require(result.get())` in AppConfigurationTests.swift (lines 58, 67, 75)
- Root cause: Swift 6.3.3 `#require` macro expansion does not auto-propagate `try` to throwing subexpressions; test needed `try #require(try result.get())`

**Attempt 2 (after fix):**
- Build: succeeded
- Tests: 499 passed, 0 failed

---

## Screenshot

Not performed (no UI changes in this story).

---

## Gate 2 Verdict

Pending.

---

## Deviations

1. The story spec said 11 new tests; the test file actually contains 13 (3 in `ReadConfigurationBaseURLTests`). All 13 pass.
2. The test file required a correction (`try #require(try result.get())`) to compile under Swift 6.3.3. The original `try #require(result.get())` does not compile because the `#require` macro expands in a way that does not propagate `try` to inner throwing calls. This is a test-writer error, corrected within the scoped file.

---

## Not Done or Partial

None
