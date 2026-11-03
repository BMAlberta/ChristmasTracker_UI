# I6a Story R1 — Sentry privacy hardening

## Files changed

**Modified:**
- `ChristmasTracker/ChristmasTracker/Core/Observability/SentryBootstrap.swift` — added `enableAutoBreadcrumbTracking = false`, `enableLogs = false`, explicit session-replay sample rates, `enableMetricKit = false`, `beforeSendSpan` scrubber, URL redaction in `scrubEvent`, changed DSN trim to `.whitespacesAndNewlines`, changed `scrubBreadcrumb` to return `Breadcrumb?` and drop touch/ui.lifecycle categories.
- `ChristmasTracker/ChristmasTracker/Core/Configuration/AppConfiguration.swift` — changed `.whitespaces` to `.whitespacesAndNewlines` in `APIMode.parse(_:)` and `readConfiguration`.
- `ChristmasTrackerTests/Core/Observability/SentryBootstrapTests.swift` — added 11 new tests; updated 3 existing `scrubBreadcrumb` tests for `Breadcrumb?` return type.
- `ChristmasTrackerTests/Core/Configuration/APIModeTests.swift` — added 1 new `APIMode.parse` trailing-newline test and 1 new `readConfiguration` DSN trailing-newline test.

## verify.sh raw output

```
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
check-config: all configuration values OK
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 112 passed, 0 failed, 0 skipped ---
--- result bundle: /tmp/ct-results-1793730614.xcresult ---
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

## Test arithmetic

Previous total: 99 (after Story 3). New tests added: 13. Removed: 0. New total: **112**. ✓

New test names:

In `SentryBootstrapTests`:
- `makeOptions enableAutoBreadcrumbTracking is false`
- `makeOptions enableLogs is false`
- `makeOptions session replay sample rates are zero`
- `makeOptions enableMetricKit is false`
- `makeOptions DSN with trailing newline trims correctly`
- `scrubBreadcrumb returns nil for touch breadcrumb with title in data`
- `scrubBreadcrumb returns nil for ui.lifecycle breadcrumb with title in data`
- `scrubBreadcrumb returns breadcrumb for app.lifecycle category`
- `scrubBreadcrumb still redacts email in message of a kept breadcrumb`
- `scrubEvent redacts request URL containing UUID`
- `scrubEvent redacts request URL containing email in path`

In `APIModeTests`:
- `parse 'mock' with trailing newline returns mock`

In `ReadConfigurationTests` (APIModeTests.swift):
- `sentryDSN with trailing newline is trimmed and non-nil`

Existing tests modified (return type fix only):
- `scrubBreadcrumbEmail` — changed to `throws`; result via `try #require(...)`
- `scrubBreadcrumbData` — same
- `scrubBreadcrumbClean` — same

## Verification claims

- `enableAutoBreadcrumbTracking = false` set in `makeOptions`: verified by reading SentryBootstrap.swift line 32 and test.
- `enableLogs = false` set explicitly: verified by reading line 33 and test.
- `sessionReplay.sessionSampleRate = 0` and `onErrorSampleRate = 0` set explicitly: verified by reading lines 34–35 and test.
- **Profiling (important finding):** There is no public `profilesSampleRate`, `profilesSampler`, or `profilingOptions` in sentry-cocoa 9.4.0's `Options.swift`. The only profiling-related property is `@_spi(Private) var profiling: SentryProfileOptions?` (line 449 of Options.swift in the resolved checkout). This property is SPI-private and must not be accessed from app code. Profiling is therefore **off by default** — no property was set. I1 must confirm this remains true if sentry-cocoa is upgraded. Verified by reading `Options.swift` in the DerivedData checkout at `/tmp/ct-derived/SourcePackages/checkouts/sentry-cocoa/Sources/Swift/Options.swift`.
- `enableMetricKit = false` set explicitly: verified by reading line 36 and test.
- `beforeSendSpan` set: verified by reading lines 40–50. The `Span` protocol provides `spanDescription: String?` (settable), `data: NSDictionary` (readonly, individual keys settable via `setData(value:key:)`). The closure redacts the description and all string data values. This is within the "trivial change" threshold — 10 lines. Verified by reading `SentrySpanProtocol.h` in the checkout.
- `scrubBreadcrumb` returns nil for touch/ui.lifecycle: verified by reading line 87 (guard returns nil) and tests `scrubBreadcrumbDropsTouch`, `scrubBreadcrumbDropsUILifecycle`.
- `scrubEvent` redacts `event.request?.url`: verified by reading lines 75–77 and tests.
- Trimming to `.whitespacesAndNewlines`: verified by reading all three locations and trailing-newline tests.
- 112 tests pass: verified by running `scripts/verify.sh`.

## Gate 2

**Convention reviewer:** PASS. All 12 checklist items pass. New/modified functions are `nonisolated` where required; no `async`/`throws` at repo/service layer; no Combine/GCD; no force unwraps; single commit per story; clean diff.

**Acceptance reviewer:** PASS (documentation gap resolved by this report). All technical criteria satisfied. Key verdict items:
- touch/ui.lifecycle drop is a nil return, not a scrub — privacy contract honored.
- No DSN in tracked code; no `Config-Secrets.xcconfig` created.
- No test calls `SentrySDK.start`.
- Profiling finding documented above and in this report.

## Stuck-detector log

No repeated errors. Tests went green on the first implementation attempt.

## Deviations

None. All Gate 1 spec items were implemented as specified. `enableLogs` and `enableMetricKit` are already `false` by default in sentry-cocoa 9.4.0; they are now set explicitly as required.

## Not done or partial

**Profiling note for I1:** `beforeSendSpan` scrubs the span description and string data values, but spans also bypass `beforeSend`. I1 must confirm that the `@Instrumented` macro does not attach function arguments (which could include list IDs or item names) to span descriptions or data. If it does, a span scrubber targeting those fields must be added.
