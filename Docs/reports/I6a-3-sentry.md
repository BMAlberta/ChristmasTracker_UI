# I6a Story 3 — Sentry initialization with scrubbing

## Files added and changed

**Added:**
- `ChristmasTracker/ChristmasTracker/Core/Observability/SentryBootstrap.swift` — Sentry bootstrap with `makeOptions`, `scrubEvent`, `scrubBreadcrumb`, `startIfConfigured`
- `ChristmasTracker/ChristmasTrackerTests/Core/Observability/SentryBootstrapTests.swift` — 19 new tests

**Modified:**
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` — added `SentryBootstrap.startIfConfigured()` as first statement of `init`, before `FirstLaunchWipe`

## Sentry import method

The app links both `SentrySwiftUI` (direct, from the remote sentry-cocoa package) and `TrackerInstrumentation` (local, which `@_exported import Sentry`). `SentryBootstrap.swift` uses `import Sentry` directly. Both approaches work; direct import chosen since TrackerInstrumentation is a macro package whose re-export is an implementation detail.

## Swift type names (verified from Sentry.framework headers)

| ObjC type | Swift name |
|---|---|
| `SentryOptions` | `Options` (via `SWIFT_CLASS_NAMED`) |
| `SentryEvent` | `Event` (via `NS_SWIFT_NAME`) |
| `SentryBreadcrumb` | `Breadcrumb` (via `NS_SWIFT_NAME`) |
| `SentryException` | `Exception` (error from compiler) |
| `SentryMessage` | `SentryMessage` (no rename) |

## verify.sh raw output

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- tests: 99 passed, 0 failed, 0 skipped ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

First run produced a transient simulator error ("Application failed preflight checks"). Second run: 99 passed.

## Test arithmetic

Previous total: 80. New tests added: 19. New total: **99**. ✓

New test names:
- `SentryBootstrapTests/makeOptions returns nil for empty DSN`
- `SentryBootstrapTests/makeOptions returns nil for blank DSN`
- `SentryBootstrapTests/makeOptions sendDefaultPii is false`
- `SentryBootstrapTests/makeOptions attachScreenshot and attachViewHierarchy are false`
- `SentryBootstrapTests/makeOptions network breadcrumbs and tracking are false`
- `SentryBootstrapTests/makeOptions enableCaptureFailedRequests is false`
- `SentryBootstrapTests/makeOptions enableUserInteractionTracing is false`
- `SentryBootstrapTests/makeOptions tracesSampleRate is <= 0.1`
- `SentryBootstrapTests/makeOptions sets expected environment and release strings`
- `SentryBootstrapTests/scrubEvent redacts email in message`
- `SentryBootstrapTests/scrubEvent redacts Bearer token in exception value`
- `SentryBootstrapTests/scrubEvent redacts email in extras`
- `SentryBootstrapTests/scrubEvent redacts email in tags`
- `SentryBootstrapTests/scrubEvent clears user and serverName`
- `SentryBootstrapTests/scrubEvent redacts UUID in request query string`
- `SentryBootstrapTests/scrubEvent does not alter a clean event except clearing user and serverName`
- `SentryBootstrapTests/scrubBreadcrumb redacts email in message`
- `SentryBootstrapTests/scrubBreadcrumb redacts Bearer token in data`
- `SentryBootstrapTests/scrubBreadcrumb does not alter a clean breadcrumb`

## Verification claims

- `makeOptions` returns nil for empty/blank DSN: verified by test (`makeOptions returns nil for empty DSN`, `makeOptions returns nil for blank DSN`).
- Privacy flags set correctly: verified by individual tests (sendDefaultPii, attachScreenshot, attachViewHierarchy, enableNetworkBreadcrumbs, enableNetworkTracking, enableCaptureFailedRequests, enableUserInteractionTracing, tracesSampleRate ≤ 0.1).
- Scrubbers redact PII and clear user/serverName: verified by tests (email in message/extras/tags, Bearer token in exception value/breadcrumb data, UUID in query string).
- SDK does not start in tests: `startIfConfigured()` is not called in any test; tests call `makeOptions`, `scrubEvent`, `scrubBreadcrumb` directly.
- `startIfConfigured()` is first statement of `ChristmasTrackerApp.init`: verified by reading the file.
- `SentryBootstrap.startIfConfigured()` placed before `FirstLaunchWipe`: verified by reading the file.

## Gate 2

**Convention reviewer:**
- `SentryBootstrap` is a `nonisolated` enum (namespace pattern) — correct for a utility with no state.
- `makeOptions`, `scrubEvent`, `scrubBreadcrumb` are all `nonisolated` — correct (pure helpers called by Sentry's background threads during crash/event processing).
- `startIfConfigured()` is not `nonisolated` (it calls `AppConfiguration` which is `@MainActor`) — correct; it's called from `@MainActor` `ChristmasTrackerApp.init`.
- No design tokens required (Observability layer, no UI).
- No new async/throws at repo/service layer — `@Instrumented` not required.
- Single commit per story. ✓

**Acceptance reviewer:** All Gate 1 criteria met:
1. ✓ `SentryBootstrap` has `makeOptions(dsn:environment:release:)`, `scrubEvent`, `scrubBreadcrumb`, `startIfConfigured`.
2. ✓ `ChristmasTrackerApp.init` calls `SentryBootstrap.startIfConfigured()` as first statement, before `FirstLaunchWipe`.
3. ✓ Tests cover: nil for empty DSN; privacy flags; scrubbers redact email/token/UUID in all specified fields; user and serverName cleared; clean event unchanged.
4. ✓ Tests do not call `SentrySDK.start`.
5. ✓ verify.sh passes: 99 tests.

## Stuck-detector log

Round 1: `Message` not in scope — fixed to `SentryMessage`. Round 2: `SentryException` renamed to `Exception` in Swift — fixed in test. 2 issues; not repeated.

## Suspected-flaky tests

The transient simulator "Application failed preflight checks" error on first run is not test-specific — it's a simulator scheduler issue. Confirmed flake-free on retry (99/99 passed on second run).

## Deviations

None. `@Instrumented` not applied to `startIfConfigured` — it is a `@MainActor`-inferred non-async function, not an `async/throws` function at repo/service layer.

## Not done or partial

None.
