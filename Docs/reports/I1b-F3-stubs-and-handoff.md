# I1-b Story F3: Test Stubs Out of Production, Handoff Accuracy

**Package:** I1-b fix pass · **Story:** F3 · **Date:** 2026-11-06

---

## Summary

Removed `TestAPIClient`, `TestListRepo`, `TestItemRepo`, and `NoopVersionHandler` from production code in `ChristmasTrackerApp.swift`. Extracted `buildGeneratedClient(...)` as an `internal nonisolated` free function used by both `ChristmasTrackerApp.init()` and the composition-root tests. Fixed `try?` with `do-catch` logging. Updated composition-root tests in `SeamTests.swift` to call `buildGeneratedClient` with no-op stubs defined in the test target. Rewrote the I1b handoff's "Brian's Real-Mode Check", corrected the I1a handoff step 2, and corrected the deviations/mutation-check text in two story reports.

---

## Files Changed

| File | Change |
|------|--------|
| `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` | Removed `nonisolated static func make(mode:baseURL:)` testable overload and all inline stubs; replaced `try?` block with `buildGeneratedClient()` call; added `buildGeneratedClient` free function; added `resolvedBaseURL` ternary to avoid reading `AppConfiguration.apiBaseURL` in mock mode |
| `ChristmasTracker/ChristmasTrackerTests/Core/API/SeamTests.swift` | Replaced `AppDependenciesAPIModeTests` suite (called `AppDependencies.make(mode:baseURL:)`) with `BuildGeneratedClientTests` suite (calls `buildGeneratedClient(...)` with `NoopTokenProvider`, `NoopSessionRefresher`, `NoopVersionHandler` defined locally) |
| `Docs/handoffs/2026-11-06-ios-to-brian-i1b.md` | Rewrote "Brian's Real-Mode Check"; updated B3→F1 description; resolved R2 open risk; added Fix Pass section; updated PROGRAM.md line |
| `Docs/handoffs/2026-11-05-ios-to-brian.md` | Step 2 now says "app target only, never to a test target" with the reason (static linking, OpenAPIRuntime symbol embedding) |
| `Docs/reports/I1b-3-version-check-slice.md` | Deviations 1–3 rewritten: now correctly say the package placement was wrong; F1 fix pass corrects it |
| `Docs/reports/I1b-4-verify-and-handoff.md` | Mutation-check note corrected: the `=== verify: TrackerAPI Xcode scheme ===` step PASSED the mutation (was ineffective); only the pre-existing `=== verify: unit tests ===` step detected the breakage |

---

## buildGeneratedClient Design

```swift
nonisolated func buildGeneratedClient(
    mode: APIMode,
    serverURL: URL?,
    info: AppClientInfo,
    tokenProvider: some AccessTokenProviding,
    sessionRefresher: some SessionRefreshing,
    versionOutdatedHandler: some VersionOutdatedHandling,
    requestIDObserver: (any RequestIDObserving)? = nil
) -> (any APIProtocol)? {
    guard mode == .real, let url = serverURL else { return nil }
    do {
        return try TrackerClientFactory.make(...)
    } catch {
        LogError("Failed to build TrackerAPI client: \(error)", category: .business)
        return nil
    }
}
```

Structural guarantees:
- Returns `nil` without reading `AppConfiguration.apiBaseURL` when mode is mock (the app init uses a ternary short-circuit: `AppConfiguration.apiMode == .real ? AppConfiguration.apiBaseURL : nil`)
- Logs (not silently swallows) factory failures
- No placeholder repositories; pure construction function

---

## Raw verify.sh Summary

```
=== verify: derived spec ===
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 549 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 146 tests in 11 suites passed after 0.012 seconds.
=== verify: TrackerAPI import audit ===
--- checking TrackerAPI source imports ---
--- checking TrackerAPITests import ---
check-package-imports: OK
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

---

## Gate 2 Verdict

**Convention reviewer: APPROVED** — `buildGeneratedClient` is `nonisolated`; `do/catch` replaces `try?`; no Combine/GCD; local no-op stubs in test target; design tokens not applicable (no UI changed).

**Acceptance reviewer: APPROVED** — All 9 criteria pass. No banned stubs in production; `LogError` on factory failure; `buildGeneratedClient` is `internal nonisolated` and sole `TrackerClientFactory` caller; two composition-root tests pass with no-op stubs defined in test target; handoff "Brian's Real-Mode Check" covers all 6 required steps; 2026-11-05 handoff step 2 carries the app-target-only instruction and static-linking rationale; I1b-3 deviations name package misplacement and F1's correction; I1b-4 mutation-check section explicitly names xcodebuild step as ineffective; verify exits OK with 549 app tests and 146 package tests.

---

## Deviations from Spec

None.

---

## Not Done or Partial

None.
