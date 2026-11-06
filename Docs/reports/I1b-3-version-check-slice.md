# I1-b Story 3: Version-Check Slice

**Package:** I1-b · **Story:** B3 · **Date:** 2026-11-06

---

## Files Added

### TrackerAPI package (`LocalPackages/TrackerAPI/Sources/TrackerAPI/`)

| File | Lines |
|------|-------|
| `VersionPolicy.swift` | 1–51 |
| `AppVersionChecking.swift` | 1–10 |
| `GeneratedClientAppVersionRepository.swift` | 1–74 |

### App module (`ChristmasTracker/ChristmasTracker/Core/API/`)

| File | Lines |
|------|-------|
| `VersionService.swift` | 1–43 |
| `MockAppVersionRepository.swift` | 1–27 |

## Files Changed

| File | Key Change |
|------|-----------|
| `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` | Added `@State private var versionService: VersionService`; default `MockAppVersionRepository` in init; real-mode block wires `GeneratedClientAppVersionRepository` and starts launch-check `Task` |

## Tests Added

### `LocalPackages/TrackerAPI/Tests/TrackerAPITests/VersionCheckRepositoryTests.swift` (new, 13 tests)

**VersionCheckRepository:**
- `200 state=ok maps to VersionPolicyState.ok`
- `200 state=update_recommended maps to VersionPolicyState.updateRecommended`
- `200 state=force_update maps to VersionPolicyState.forceUpdate`
- `200 without optional fields yields nil manifestURL, ipaURL, releaseNotes`
- `200 with manifestUrl and ipaUrl parses them as URLs`
- `200 with fractional-second updatedAt decodes the correct second component`
- `304 with no prior cache throws`
- `304 after a 200 returns the cached policy from the first successful call`
- `400 throws`
- `429 exhausted after retries throws TrackerAPIError.rateLimited`
- `500 throws`
- `418 (undocumented) throws`
- `transport failure throws`
- `request carries X-Platform, X-Build, X-App-Version, X-Client-Platform and no Authorization header`
- `request URL contains platform, version, and build query parameters`

### `ChristmasTracker/ChristmasTrackerTests/Core/API/VersionCheckTests.swift` (new, 3 tests)

**VersionService:**
- `check() sets lastPolicy after a successful repository call`
- `check() preserves lastPolicy and sets lastErrorCategory when repository throws`
- `VersionService lastPolicy is nil on init and non-nil after a successful check`

---

## Raw verify.sh Summary

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
--- tests: 534 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 161 tests in 12 suites passed after 0.016 seconds.
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Test Arithmetic

- Previous total (app): 531 tests
- New app tests: +3 (VersionService suite)
- Actual app total: **534 passed**

- Previous total (package): 146 tests
- New package tests: +15 (VersionCheckRepository suite: 13 tests + header + query = 15)
- Actual package total: **161 passed**

---

## Gate 2 Verdict

**Convention reviewer: APPROVED** — 12 checklist items pass or N/A. Two surfaced warnings:
- W1: `@Instrumented` absent on `GeneratedClientAppVersionRepository.checkVersion()` — omission explained by a comment; TrackerAPI package has no Sentry/TrackerInstrumentation dependency. No explicit coding-standards carve-out exists, but the reason is architectural (not a standards gap in the method itself).
- W2: `MockAppVersionRepository` placed in production app module — intentional, matches the existing pattern for mock repositories (`MockListRepository`, `MockItemRepository`) used by the composition root in mock mode.

**Acceptance reviewer: APPROVED** (after one-line fix) — Initial pass rejected because MARK L test omitted the `X-Build` header assertion. Added `#expect(req.headerFields[HTTPField.Name("X-Build")!] == "1")` to `VersionCheckRepositoryTests.swift` line 295. Re-review confirmed all 6 criteria satisfied.

---

## Deviations from Spec

1. **`VersionPolicy`, `AppVersionChecking`, `GeneratedClientAppVersionRepository` moved to TrackerAPI package** — the epic brief placed them in the app module under `Core/API/`. After implementation, linking failed: calling `client.checkAppVersion(input)` from the app binary causes the linker to reference `OpenAPIRuntime.AcceptHeaderContentType` (a type in the input's `Headers.accept` field), which is not in the app binary's link graph. The fix is architecturally correct: types that call generated operations belong in the package that links OpenAPIRuntime. This is the same constraint that required widening `Client?` to `(any APIProtocol)?` in B2.

2. **`@Instrumented` not applied to `GeneratedClientAppVersionRepository.checkVersion()`** — the TrackerAPI package does not carry `TrackerInstrumentation` or `Sentry` as a dependency. The comment at line 19 of `GeneratedClientAppVersionRepository.swift` documents the reason. The standard's `@Instrumented` requirement is effectively not satisfiable at the package layer; this is a standing constraint for all future repository types placed in TrackerAPI.

3. **Repository tests placed in package test target** — because `GeneratedClientAppVersionRepository` moved to TrackerAPI, its tests also moved to `TrackerAPITests/VersionCheckRepositoryTests.swift` to avoid re-importing `OpenAPIRuntime` from the app test target. The `VersionService` tests (which use only app-module types) remain in `ChristmasTrackerTests/`.

---

## Not Done or Partial

None.
