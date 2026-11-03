# Handoff: Package I6a — Observability and Configuration
**Date:** 2026-11-03
**Branch:** `feat/i6a-observability-config`
**From:** iOS
**To:** Brian (for PROGRAM.md and merge decision)

---

## Contract issues found

None. This package has no networking work. The contract is PRE-CONFORMANCE; no API models were created or modified.

---

## What changed

### Story 1 — Remove New Relic code
- `Core/Logging/NewRelicDestination.swift` deleted, including the `LogEvent.toAttributes()` extension (no other callers).
- `Logger.setupDestinations()` had the `NEW_RELIC_LICENSE_KEY` environment-variable lookup and `NewRelicDestination` init removed.

### Story 2 — API_MODE and observability configuration
- `Info.plist` gained `API_MODE`, `SENTRY_DSN`, `APP_ENVIRONMENT` as `$(...)` substitutions.
- `Config.xcconfig` (Release): stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `SENTRY_DSN_RELEASE =` fallback (before `#include?`), optional `#include? "../../Config-Secrets.xcconfig"`, `API_MODE = real`, `APP_ENVIRONMENT = production`, `SENTRY_DSN = $(SENTRY_DSN_RELEASE)`.
- `Config-Debug.xcconfig`: stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `API_MODE = mock`, `APP_ENVIRONMENT = development`, `SENTRY_DSN =` (after include).
- `Config-QA.xcconfig`: stale `PRODUCT_BUNDLE_IDENTIFIER` removed; added `API_MODE = mock`, `APP_ENVIRONMENT = qa`, `SENTRY_DSN =` (after include).
- `AppConfiguration.swift`: added `APIMode` enum with `nonisolated parse(_:)`, `readConfiguration(from:)` pure function, `apiMode`/`sentryDSN`/`appEnvironment` static properties; retained `environment`/`isDebug` compile-time helpers for existing tests.
- `ChristmasTrackerApp.AppDependencies.make()`: `#if DEBUG` mock switch replaced by `switch AppConfiguration.apiMode`. Both branches compile in every configuration.
- `scripts/build.sh`: added optional `CONFIGURATION` env variable (default `Debug`).
- `scripts/check-config.sh` added: checks `API_MODE`, `APP_ENVIRONMENT`, `SENTRY_DSN`-is-empty, and `PRODUCT_BUNDLE_IDENTIFIER` for Debug, QA, and Release; exits non-zero on mismatch; never prints DSN.
- `scripts/verify.sh`: calls `check-config.sh` after the build step.
- `ChristmasTracker/Config-Secrets.example.xcconfig` added (tracked, outside synchronized folder): template for Brian to copy as `Config-Secrets.xcconfig` and fill in a real DSN.
- `.gitignore`: added `ChristmasTracker/Config-Secrets.xcconfig`.

### Story 3 — Sentry initialization with scrubbing
- `Core/Observability/SentryBootstrap.swift` added: `nonisolated makeOptions(dsn:environment:release:)`, `nonisolated scrubEvent(_:)`, `nonisolated scrubBreadcrumb(_:)`, `startIfConfigured()`. Sentry import is direct (`import Sentry`).
- `ChristmasTrackerApp.init`: `SentryBootstrap.startIfConfigured()` added as first statement, before `FirstLaunchWipe`.

### Story R1 — Sentry privacy hardening (rework)
- `SentryBootstrap.makeOptions`: added `enableAutoBreadcrumbTracking = false` (prevents recording UIButton titles and ViewController titles as breadcrumbs); added explicit `enableLogs = false`, `sessionReplay.sessionSampleRate = 0`, `sessionReplay.onErrorSampleRate = 0`, `enableMetricKit = false`; added `beforeSendSpan` closure to redact span descriptions and string data values; changed DSN trimming to `.whitespacesAndNewlines`.
- `SentryBootstrap.scrubBreadcrumb`: return type changed to `Breadcrumb?`; now drops (returns nil for) any breadcrumb with category `"touch"` or `"ui.lifecycle"` — these can carry UIButton titles and ViewController navigation titles in this SDK version.
- `SentryBootstrap.scrubEvent`: now also redacts `event.request?.url` via `PIIFilter.redact`.
- `AppConfiguration.APIMode.parse` and `readConfiguration` DSN trim: changed from `.whitespaces` to `.whitespacesAndNewlines`.

---

## What the API team must do

None for this package.

---

## Test count

| Story | Tests |
|---|---|
| Before I6a | 65 |
| After Story 1 | 65 (no change) |
| After Story 2 | 80 (+15) |
| After Story 3 | 99 (+19) |
| After Story R1 | **112** (+13) |

---

## Rework commit hashes (master..HEAD, taken after Story R1 report commit)

```
2d379d2 I6a: add Story R1 sentry privacy report
0f6dbe1 I6a: harden Sentry privacy (no UI breadcrumbs, explicit-off features)
ced2046 I6a: add rework Gate 1 spec
284e0d3 I6a: add package handoff note
9daf05b I6a: add Story 3 report
e61b2a5 I6a: initialize Sentry with scrubbing and low trace sampling
780bcc4 I6a: add Story 2 report
3e3dd44 I6a: add API_MODE and observability configuration
6fd8f63 I6a: add Story 1 report
fbb7ea2 I6a: remove New Relic code
829cfc8 I6a: add epic brief and inventory
```

## Diff stat (master...HEAD, taken at commit 2d379d2)

```
22 files changed, 1606 insertions(+), 169 deletions(-)
```

No `.pbxproj` touched. No `contract/`, `.claude/`, synced Docs files, or `Core/Networking` touched. No `API_BASE_URL` line changed.

---

## Open risks

1. **Sentry is off until Brian creates Config-Secrets.xcconfig.** Copy `ChristmasTracker/Config-Secrets.example.xcconfig` → `ChristmasTracker/Config-Secrets.xcconfig` and fill in the real DSN. The file is gitignored; it must never be committed. Until it exists, Release also has `SENTRY_DSN` empty and Sentry does not start.

2. **Release resolves API_MODE=real with a base URL that still cannot reach a server until I1.** `API_BASE_URL` in Config.xcconfig is `https://api.christmastracker.com` which the xcconfig `//` parser truncates to `https:`. The `https:/ /...` space form used in Debug/QA is broken — it resolves to an invalid URL at runtime (the space is preserved in the expanded value). I1 must use the `https:/$()/host` form (proven for the DSN in this package, verified with `-showBuildSettings`), or split into separate scheme, host, and port xcconfig variables.

3. **AppConfiguration's comments still mention the old `api-dev.christmastracker.com` and `api-qa.christmastracker.com` hosts.** These will be updated in I1 when the real host is finalized.

4. **P4 result (macro validation):** `@Instrumented` macro compiled without `-skipMacroValidation` — no flag needed. SourceKit shows "No such module 'TrackerInstrumentation'" in the IDE index but the compiler accepts it. This IDE-only issue pre-dates I6a.

5. **Pre-existing findings from I2a handoff** (carried forward):
   - `SessionClearable` naming: the protocol name uses a gerund adjective rather than the `-ing` suffix convention. Not blocking but worth a future rename.
   - Late-response risk: services have no in-flight task cancellation at teardown.
   - On-device wipe test pending (first TestFlight build).
   - 426 session-clear UX decision pending for I1.

6. **Unmet acceptance item — xcconfig files in app bundle:** `Config-Debug.xcconfig`, `Config-QA.xcconfig`, and `Config.xcconfig` are copied into the Debug app bundle because they live inside the file-synchronized folder. They contain no secrets (DSN empty in Debug/QA; Release values are non-secret). `Config-Secrets.xcconfig` is correctly outside the synchronized folder and absent from the bundle. Fixing requires removing target membership or adding a per-file exception in the Xcode project (a `.pbxproj` edit Brian must make in Xcode).

7. **Sentry stays OFF until this rework merges and Brian creates Config-Secrets.xcconfig.** Brian must not create `Config-Secrets.xcconfig` (and therefore must not enable Sentry) until the rework branch (`feat/i6a-observability-config`) is merged. Creating the secrets file before the rework merges would enable Sentry with the pre-rework code, which still has `enableAutoBreadcrumbTracking = true` — the exact privacy gap this rework closes.

8. **I1 must verify the @Instrumented macro does not attach function arguments to spans.** `beforeSendSpan` scrubs `spanDescription` and string data values, but the `@Instrumented` macro (used in the repository and service layers starting in I1) may attach function argument values to the span's description or data dict. If it does, those values could include list IDs, item names, or other user data that bypasses `beforeSend`. I1 must inspect the macro expansion and add a targeted span scrubber if needed.

9. **Transactions bypass beforeSend.** Sentry transactions (top-level spans) are serialized and sent independently of `beforeSend`. The `beforeSendSpan` closure added in R1 is the correct mitigation path for span-level data, but it only fires for child spans. I1 should verify whether transaction-level data (operation name, description) can carry PII from `@Instrumented` call sites.

---

## One line for PROGRAM.md section 9

> I6a (2026-11-03, rework 2026-11-03): removed New Relic; xcconfig-driven API_MODE/APP_ENVIRONMENT/SENTRY_DSN; Sentry initialized with PII scrubbing, UI breadcrumbs disabled and dropped (touch/ui.lifecycle → nil), explicit-off for logs/replay/MetricKit/profiling, beforeSendSpan scrubber, 0.05 trace rate; disabled until Brian creates Config-Secrets.xcconfig after rework merges; 112 tests, 0 failures.
