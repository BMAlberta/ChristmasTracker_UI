# T1-1 — Test target compiles and passes under Xcode 27

**Date:** 2026-11-09 · **Branch:** `chore/xcode-27-test-settings` · **Toolchain:** Xcode 27.2 (27B52),
simulator `iPhone 17 Pro`, iOS 26.5 runtime (`DEST="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5"`)

## What changed

Isolation-only edits in the test target. No test was renamed, removed, or weakened.

| File (under `ChristmasTracker/ChristmasTrackerTests/`) | Change | Reason |
|---|---|---|
| Core/Networking/MockAPIClientTests.swift | 3 local `TestResponse` types become `nonisolated struct ...: Codable, Sendable` | Family A: isolated `Decodable` conformance cannot satisfy a `Sendable` generic parameter |
| Features/Authentication/AuthenticationServiceTests.swift | `AccountDisabledLoginRepository` actor to `@MainActor private final class` | Family B |
| Features/Authentication/LogoutPathTests.swift | `ThrowingLogoutRepository` | Family B |
| Features/Authentication/ObservableSnapshotTests.swift | `BiometricRefreshFailingRepository` | Family B |
| Features/Authentication/SessionEndGuardTests.swift | `GatedClearable`, `GatedRefreshRepository` | Family B |
| Features/Authentication/SessionTeardownTests.swift | `FastMockListRepository`, `FastMockItemRepository` | Family B |
| Features/Authentication/SignInWithBiometricTests.swift | 8 fakes: `SuspendableRepository`, `BlockingRepository`, `SuspendingLogoutRepository`, `ExpiringTokenRepository`, `CredentialFailureRepository`, `NetworkFailRefreshRepository`, `FailingRefreshRepository`, `ScriptedRefreshRepository` | Family B |
| Features/Authentication/BiometricOfferIntegrationTests.swift | `makeSUT` default argument `InMemoryEnrollmentHistory()` becomes `InMemoryEnrollmentHistory? = nil`, built in the `@MainActor` body | Family C: default arguments are evaluated nonisolated |
| Features/Authentication/EnrollMarkerRegistrationTests.swift | same | Family C |
| Features/Authentication/FirstLaunchWipeTests.swift | `mock: MockKeychainWiper = MockKeychainWiper()` becomes `MockKeychainWiper? = nil`, built in the body | Family C |

Files added: none in this story besides this report. 10 files changed, 27 insertions, 21 deletions.
Conversions: 15 actors to `@MainActor final class` (1 + 1 + 1 + 2 + 2 + 8). Follow-on
`User(...)` / `AuthSession(...)` errors inside those fakes were resolved by the class conversion with no further edit.
Call sites keep the same external labels (`enrollmentHistory:`, `mock:`), so no caller changed.

Isolation keywords used in the diff: `nonisolated` (3, plain, on local data types), `@MainActor` (15, on
fakes that build MainActor-default `User`/`AuthSession`/`GiftList` values). Not used: `@preconcurrency`,
`@unchecked Sendable`, `nonisolated(unsafe)`. No justification entries are therefore needed.

## Verification

Each claim says whether it came from running a command (RAN) or reading code (READ).

- RAN: baseline `scripts/verify.sh` before any edit: unit tests `0 passed, 0 failed, 0 skipped`, exit 65, test target did not compile (34 distinct file:line diagnostics, see `Docs/epics/T1-xcode-27-compat.md`).
- RAN: one fix round was enough; no further diagnostics appeared after round 1.
- RAN: three consecutive `scripts/test.sh` runs after the fixes:

```
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---    (run 1, /tmp/ct-results-1794234961.xcresult)
--- tests: 677 passed, 0 failed, 0 skipped ---    (run 2, /tmp/ct-results-1794235008.xcresult)
--- tests: 677 passed, 0 failed, 0 skipped ---    (run 3, /tmp/ct-results-1794235041.xcresult)
```

- RAN: `scripts/verify.sh` before the commit (headings and summary lines only; per-test lines trimmed):

```
=== verify: derived spec ===
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.017 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

  Exit status of this run: 0 (the final heading is `=== verify: OK ===`).
- Verify after the commit: the commit adds no content beyond the tree already verified here, so a second run
  would repeat these lines. The after-commit run is recorded in `Docs/reports/T1-2-automatic-destination.md`
  (it runs on the T1A commit plus the T1B changes). See Deviations.

## Test arithmetic

Previous total 677 + new 0 - removed 0 = 677. Observed 677 passed, 0 failed, 0 skipped, three times.
TrackerAPI package tests: 191 (unchanged from baseline). Release script tests: 62 (the prompt said "92 or the
current counts you record in P3"; the real current count is 62, recorded in the baseline run and unchanged).

## Gate 2

- convention-reviewer: APPROVE. Evidence: 10 files all under `ChristmasTrackerTests`; no Combine, `DispatchQueue`,
  GCD, `as!`, `try!`, `@preconcurrency`, `@unchecked`, `nonisolated(unsafe)` in added lines; no added line over
  120 characters; comments match root cause C. One warning: the branch name `chore/xcode-27-test-settings` is not
  `feat/` or `fix/`; the brief names this branch as intended, and Brian's commit is already on it.
- acceptance-reviewer: APPROVE. Focus answers:
  1. Scope: 10 test files only, no production, `.pbxproj`, or setting change (`git diff --stat`, `git status --short`).
  2. Names and assertions: `git diff -U0 | grep -E '^[-+].*(@Test|#expect|#require|func test)'` returned nothing.
  3. Annotations: `nonisolated` at `MockAPIClientTests.swift:17, 36, 59`; `@MainActor` only on fakes that need it
     (`User(...)`/`AuthSession(...)` are MainActor-default); no escape hatches.
  4. Fake behavior: continuation handshakes (`SessionEndGuardTests.swift:92-217`, `SignInWithBiometricTests.swift:203-261`)
     do not rely on actor reentrancy; `Task.yield` polling (`SignInWithBiometricTests.swift:175`) still ends only on a
     real call, and `refreshCallCount == 1` assertions still fail if single-flight breaks.
  5. No actor conforming to `AuthenticationRepository`, `ListRepository`, `ItemRepository`, or `SessionClearable` remains.
  Reviewer count discrepancy: the reviewer text says 14 and 20 converted fakes in different places; the diff shows 15
  (counted above from the file list). The verdict does not depend on it.
- Rejections and re-reviews: none.
- Stuck detector: 1 attempt, no repeated error signature.

## Deviations, bugs, scope

- The Orchestrator applied the code fixes before committing the brief (the brief was committed first, containing only
  the brief; the code commit follows the reviews). Recorded in the brief.
- Release script test count is 62, not the 92 the prompt mentioned.
- The after-commit verify run is recorded in the T1-2 report rather than appended here (appending would need a further commit).
- `xcodebuild -showBuildSettings -scheme ChristmasTracker` shows only the app target block, so the test target's
  settings were not read from it; the `.pbxproj` was read by `grep` only.
- Editor (SourceKit) showed "No such module 'Testing'" while editing; it is an indexing artifact, the build succeeds.
- No real bugs found in production code. Nothing outside scope was touched.

## Not done or partial

- The after-commit `verify.sh` run is not in this file (see above).
- UI tests (`ChristmasTrackerUITests`) were not built or run; they were not reported as failing to compile, and
  `scripts/verify.sh` does not run them.
- Not run on the iOS 27.2 runtime; all runs used the iOS 26.5 simulator (the automatic destination arrives in T1B).
