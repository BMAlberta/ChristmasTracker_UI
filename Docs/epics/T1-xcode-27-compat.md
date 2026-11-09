# T1 — Xcode 27 toolchain compatibility

**Status:** Gate 1 · **Branch:** `chore/xcode-27-test-settings` · **Date:** 2026-11-09

## Context

Brian upgraded macOS and Xcode (Xcode 27.2, build 27B52). The newest simulator runtime is
iOS 27.2; iOS 26.5 is still installed. Two things broke:

1. `scripts/build.sh` and `scripts/test.sh` default to `iPhone 17 Pro,OS=latest`, which does
   not exist on the iOS 27.2 runtime.
2. The app test target `ChristmasTrackerTests` no longer compiled. It builds in Swift 5
   language mode (`SWIFT_VERSION = 5.0`, unchanged on purpose) and had no default actor
   isolation, so the app's MainActor-by-default types were used from nonisolated test code.
   The new compiler reports those diagnostics as errors.

Commit `9ac92d7` (Brian) gives the test target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
That commit is the only build-setting change in this package.

## Scope

| Story | Goal | Files allowed |
|---|---|---|
| T1A | Test target compiles and passes (677 tests) | `ChristmasTracker/ChristmasTrackerTests/` only |
| T1B | Automatic simulator destination | `scripts/lib/destination.sh` (new), `scripts/test-destination.sh` (new), `scripts/build.sh`, `scripts/test.sh`, `scripts/verify.sh` (one step) |
| T1C | Handoff note | `Docs/handoffs/`, `Docs/reports/` |

Out of scope: production sources, any `.pbxproj`, other build settings, `contract/`,
`LocalPackages/`, `.claude/`, `CLAUDE.md`, xcconfig files, synced Docs.

## Acceptance criteria

- T1A: app suite compiles; exactly 677 passed, 0 failed, 0 skipped, three runs in a row;
  no test renamed, removed, or weakened; no production or build-setting change.
- T1B: `resolve_destination` honors `DEST` first, else picks the newest iOS runtime with an
  available iPhone (prefers "iPhone 17 Pro"), fails clearly when none; tested with stubs only.
- T1C: handoff per CLAUDE.md.

New interface at Gate 1: `resolve_destination` shell function only (T1B). No Swift interface.

## Baseline (before any edit)

- `xcodebuild -version`: Xcode 27.2, Build version 27B52
- Runtimes: iOS 26.5 (23F77), iOS 27.2 (24B8117), iOS 27.2 (24B91016s, iPhone19-4 variant)
- `verify.sh` with `DEST="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5"`: derived spec OK,
  app build OK, config check OK, unit tests `0 passed, 0 failed, 0 skipped` (exit 65,
  test target did not compile), TrackerAPI package tests 191 passed, release script tests pass,
  final line `=== verify: FAILED ===`.
- `xcodebuild -showBuildSettings -scheme ChristmasTracker` prints only the app target block
  (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, SWIFT_VERSION = 6.0,
  SWIFT_APPROACHABLE_CONCURRENCY = YES); it does not show per-target blocks for the test
  target. The pbxproj (read-only grep) shows the Swift 5.0 build configurations with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for the test target after Brian's commit.

## Inventory of compile errors

Source of truth: `grep "error:" /tmp/ct-test.log` after the baseline run. 34 distinct
file:line diagnostics in the test sources (the four trailing `.abi.json`/`.swiftmodule`
errors are consequences, not separate defects).

**Round 1 (all errors surfaced in one batch; no later batch appeared):**

| # | File:line | Family | Fix |
|---|---|---|---|
| 1-3 | Core/Networking/MockAPIClientTests.swift:22, 43, 63 | A | `nonisolated struct TestResponse: Codable, Sendable` (three local types) |
| 4 | Authentication/AuthenticationServiceTests.swift:35 | B | `AccountDisabledLoginRepository` actor to `@MainActor final class` |
| 5 | Authentication/LogoutPathTests.swift:26 | B | `ThrowingLogoutRepository` |
| 6 | Authentication/ObservableSnapshotTests.swift:63 | B | `BiometricRefreshFailingRepository` |
| 7 | Authentication/ObservableSnapshotTests.swift:72 | B (follow-on) | `User(...)` call inside the fake, resolved by the class conversion |
| 8-9 | Authentication/SessionEndGuardTests.swift:92, 141 | B | `GatedClearable`, `GatedRefreshRepository` |
| 10 | Authentication/SessionEndGuardTests.swift:162 | B (follow-on) | `User(...)` inside the fake |
| 11-12 | Authentication/SessionTeardownTests.swift:23, 41 | B | `FastMockListRepository`, `FastMockItemRepository` |
| 13-20 | Authentication/SignInWithBiometricTests.swift:34, 158, 203, 882, 923, 956, 984, 1017 | B | eight fakes (`SuspendableRepository`, `BlockingRepository`, `SuspendingLogoutRepository`, `ExpiringTokenRepository`, `CredentialFailureRepository`, `NetworkFailRefreshRepository`, `FailingRefreshRepository`, `ScriptedRefreshRepository`) |
| 21-31 | SignInWithBiometricTests.swift:93, 101, 167, 208, 216, 224, 890, 931, 959, 992, 1031 | B (follow-on) | `User(...)` calls inside those fakes, resolved by the class conversion |
| 32 | Authentication/BiometricOfferIntegrationTests.swift:46 | C | default argument `InMemoryEnrollmentHistory()` moved into the `@MainActor` factory body |
| 33 | Authentication/EnrollMarkerRegistrationTests.swift:64 | C | same |
| 34 | Authentication/FirstLaunchWipeTests.swift:96 | C | default argument `MockKeychainWiper()` moved into the factory body |

Root causes: A is an isolated `Decodable` conformance used as a `Sendable` generic argument.
B is an `actor` conforming to a protocol that is MainActor-isolated by the app's module
default. C is a default-argument expression, which is evaluated in a nonisolated context.

Rebuild after round 1: compiles; `677 passed, 0 failed, 0 skipped`.

## Process deviation (recorded honestly)

The Orchestrator applied the T1A fixes before this brief was committed, so the brief is
committed after the code was written but before the code is committed. The brief commit
contains only this file. The Gate 2 reviews still run before the T1A commit.
