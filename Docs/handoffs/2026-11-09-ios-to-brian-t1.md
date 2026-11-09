# iOS Handoff: Package T1 (Xcode 27 toolchain compatibility)
**Date:** 2026-11-09
**From:** iOS agent (Orchestrator)
**To:** Brian (PROGRAM.md)
**Branch:** chore/xcode-27-test-settings, from master (merge of PR #23). PR should target master. Not pushed.
**Contract:** untouched. No contract file, synced Docs file, or production source changed.

## Commits
`git log --oneline master..HEAD`, taken before the handoff commit:
```
548f277 T1: choose the simulator destination automatically
feeba51 T1: fix test-target isolation errors under Xcode 27
da34b84 T1: add brief and inventory
9ac92d7 chore: set the test target's default actor isolation to MainActor for Xcode 27
```
The handoff commit ("T1: add the package handoff note") adds one more line. It contains this file and
`Docs/reports/T1-3-handoff.md`.

## Contract issues found
None. No row was added to Docs/contract-issues.md.

## What changed
- **Build setting (Brian's commit `9ac92d7`, the only setting change):** the test target now has
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, matching the app. `SWIFT_VERSION = 5.0` for the test target is unchanged.
- **T1A, test target compiles and passes again** (test files only, 10 files):
  - Family A: three local `TestResponse` types in `MockAPIClientTests.swift` are `nonisolated struct ...: Codable, Sendable`.
  - Family B: 15 test-fake `actor`s that conform to MainActor-isolated production protocols (`AuthenticationRepository`,
    `ListRepository`, `ItemRepository`, `SessionClearable`) became `@MainActor private final class`.
  - Family C: three `makeSUT` default arguments (`InMemoryEnrollmentHistory()` twice, `MockKeychainWiper()` once) became
    optional parameters built inside the factory body, because default arguments are evaluated nonisolated.
  - 34 distinct diagnostics, all fixed in one round. No test renamed, removed, or weakened. No `@preconcurrency`,
    `@unchecked Sendable`, or `nonisolated(unsafe)` added.
- **T1B, automatic simulator destination:** new `scripts/lib/destination.sh` (`resolve_destination`), used by
  `scripts/build.sh` and `scripts/test.sh`. `DEST` still wins. Otherwise: newest iOS runtime (numeric version) with an
  available iPhone, preferring "iPhone 17 Pro", else the first iPhone by name; prints `platform=iOS Simulator,id=<udid>`.
  New `scripts/test-destination.sh` (17 stub-based tests) runs as one new `scripts/verify.sh` step.

## Exact versions used
- Xcode 27.2, build 27B52 (`xcodebuild -version`).
- Runtimes installed: iOS 26.5 (23F77), iOS 27.2 (24B8117), iOS 27.2 (24B91016s, the iPhone19-4 variant).
- Test runs for T1A used `iPhone 17 Pro` on iOS 26.5. The automatic destination on this Mac resolves to
  `iPhone 17` on iOS 27.2 (`id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9`); the full `verify.sh` also passes there.
- macOS: Darwin 27.2.0.

## Verification (after the last code commit `548f277`, run 2026-11-09, no `DEST`)
Raw summary lines of `scripts/verify.sh`:
```
=== verify: derived spec ===
=== verify: build ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.017 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
App suite: three consecutive runs of 677 passed on iOS 26.5, plus the verify runs on iOS 27.2 (677 passed).

## Xcode 27 notes
- The test target stays in Swift 5 language mode on purpose (`SWIFT_VERSION = 5.0`). Moving it to Swift 6 mode is a
  separate decision to revisit later; this package only fixes the isolation errors under Swift 5 mode.
- In this mode a default-argument expression is evaluated nonisolated even inside a MainActor function; build such
  values in the function body (the Family C fix).
- An `actor` cannot conform to a global-actor-isolated protocol; fakes for the app's protocols are `@MainActor` classes now.
- `xcodebuild -showBuildSettings -scheme ChristmasTracker` prints only the app target's block, so the test target's
  settings were checked in the `.pbxproj` by `grep` (read-only).

## Anything the API team must do
Nothing.

## What was not run
- `ChristmasTrackerUITests` (not built or run; `verify.sh` does not run them, and nothing reported them failing to compile).
- The unit suite on a physical device, and any archive, export, or release step.
- `scripts/release.sh` itself (only its stub-based `test-release.sh` runs inside `verify.sh`).
- A second test pass on iOS 26.5 after the T1B commit (the post-T1B runs used the iOS 27.2 runtime).

## Open risks
- The automatic destination picks the newest runtime, which may lack the simulator model a person expects; set `DEST` to override.
- The `id=` destination changes with the installed simulators; a different Mac may resolve to a different device.
- The two iOS 27.2 runtimes (base and iPhone19-4 variant) are pooled by version; a device from the variant could be picked.
  The udid is still valid for xcodebuild, but this is untested on a Mac where the variant has the preferred device.
- Test fakes now run on the main actor; a future test relying on actor-isolated parallelism would need review.
- Branch name `chore/xcode-27-test-settings` is not `feat/` or `fix/` (the convention-reviewer warned; Brian's commit is already on it).
- Release script test count is 62 (earlier prompts mentioned 92); the count is unchanged by this package.

## Section 9 of PROGRAM.md (one line)
T1 (Xcode 27 toolchain compatibility): done 2026-11-09 on chore/xcode-27-test-settings; test target compiles under Xcode 27.2 with 677 app tests passing, scripts pick the simulator automatically (DEST still overrides); no production, contract, or build-setting change beyond Brian's test-target isolation commit; not pushed.
