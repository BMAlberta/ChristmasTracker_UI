# IMG1-1: the link preview call (no UI)
Branch: feat/img1-link-preview. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
New, under ChristmasTracker/ChristmasTracker/:
- Features/LinkPreview/Repositories/LinkPreviewLoading.swift: protocol, `imageUrl(for:) async throws -> String?`, throws only CancellationError.
- Features/LinkPreview/Repositories/GeneratedClientLinkPreviewRepository.swift: `@Instrumented`; explicit switch over every documented output case; 200 returns `data.imageUrl`; every other status, transport error and decode error returns nil; CancellationError and URLError.cancelled, bare or wrapped in ClientError, propagate as CancellationError.
- Features/LinkPreview/Repositories/MockLinkPreviewRepository.swift (known host `shop.example.test`, fixed https image) and InertLinkPreviewLoader.swift (always nil).
- Features/LinkPreview/Domain/LinkPreviewInput.swift (http or https, host, no userinfo, at most 2048, no whitespace; returns the input unchanged, so padded input is rejected) and LinkPreviewImageFilter.swift (ThumbnailURL.validate plus no userinfo).
- Features/LinkPreview/Services/LinkPreviewService.swift: `@MainActor @Observable`, SessionClearable, generation guard, in-flight cancel handles, manual Sentry span with an explaining comment, nothing logged.
- Core/Extensions/EnvironmentValues+LinkPreviewService.swift: key with an inert default.
- App/LinkPreviewWiring.swift: `makeLinkPreviewService(mode:state:client:)`; inert unless bootstrap state is ready; mock in mock mode; generated-client repository in real mode with a client, inert without one.

Edited: ChristmasTrackerApp.swift, +5 lines (one @State, one construction line, one assignment, one `Task { await sm.register(linkPreview) }`, one `.environment`). 543 to 548 lines (limit 600). Brian approved this edit in the session. `makeProductionClearables` and SessionClearable.swift are untouched: the service registers like ImageCacheClearable does.

Tests (ChristmasTrackerTests/LinkPreview/, 11 files): repository against the real factory client over a fake transport, ClientError wrapping, input validation, image filter, mock, service, session safety, environment default, wiring, and a source scan (no URL or error text in any log, report, span or breadcrumb; `@Instrumented` present).

## Commands and raw output
Baseline (before the brief commit and again after it): `tests: 5048 passed, 0 failed, 0 skipped`; `Test run with 212 tests in 16 suites passed`.
Before this commit, `scripts/verify.sh`:
```
** BUILD SUCCEEDED **
--- tests: 5108 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: OK ===
```
(5048 + 60 new tests.) `grep -c "" ChristmasTrackerApp.swift` gives 548.

## Gate 2
- Convention review: no blocks. Two warnings (comment-only) fixed: InertLinkPreviewLoader and `perform` now carry explaining comments.
- Acceptance review: first pass REJECTED for test coverage only (no ClientError-wrapped cancellation test; `makeLinkPreviewService` untested). The test-writer added LinkPreviewClientErrorWrappingTests and LinkPreviewWiringTests; the same reviewer re-reviewed and APPROVED.

## Deviations
- The brief says to wire in App/Bootstrap.swift. That file is only the bootstrap decision; the composition root is ChristmasTrackerApp.swift. Brian approved the minimal edit there.
- The first `scripts/verify.sh` run in the session failed with "Derived spec is out of date"; the derived client spec was regenerated outside the session and the rerun passed.

## Not done or partial
- Nothing ran against the network or a simulator. `sm.register(linkPreview)` is a `Task` in the app init, so a teardown before it runs is theoretically possible (the same as the ImageCacheClearable line above it); it is covered by a manual read and the generic SessionManager tests, not a dedicated test.
- The service is not used by any screen yet (P3 wires the forms).
- The device fallback is not part of this story (P4).
