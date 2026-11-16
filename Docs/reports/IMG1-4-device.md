# IMG1-4: the on-device image fallback
Branch: feat/img1-link-preview. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
New, under ChristmasTracker/ChristmasTracker/Features/LinkPreview/:
- Providers/ProductImageProviding.swift: `nonisolated protocol ProductImageProviding: Sendable`, `imageUrl(for:) async throws -> String?` (throws only CancellationError).
- Providers/LinkPresentationProductImageProvider.swift: the ONLY app file with `import LinkPresentation`, `value(forKey:` or `imageMetadata`. Carries the marker `APPSTORE-BLOCKER: non-public key path` and the release action. `LPMetadataProvider` with `timeout = 8`; the fetch is bridged to async with a continuation held in a `Mutex` (resumed exactly once); `withTaskCancellationHandler` calls `.cancel()` on the `LPMetadataProvider`, and a flag checked under the same lock closes the cancel-before-start race. `LPLinkMetadata` never leaves the completion handler: only a `String?` does. `@Instrumented` on `imageUrl(for:)`.
- `ProductImageMetadataReader.imageURLString(from: NSObject)`: pure two-hop extraction; each hop is guarded by `responds(to: NSSelectorFromString(...))` immediately before its `value(forKey:)`, with conditional casts only (no force casts). A missing selector, nil or non-URL value returns nil with no Objective-C exception.
- Providers/MockProductImageProvider.swift (fixed https image for `device.example.test`, nil otherwise) and InertProductImageProvider.swift (nil).
- Domain/ProductImageURLNormalizer.swift: http upgraded to https; every other scheme, userinfo, over 2048 (after the upgrade), whitespace and no-host rejected.
Changed:
- Services/LinkPreviewService.swift: `init(repository:provider:)` (default inert). After the API step yields nil (null, 429, error) or a value the filter rejects, and only if the task is not cancelled and the session generation is unchanged, the provider runs inside the same cancellable mechanism (both steps are cancelled by `clearForSession`), then normalize, then `LinkPreviewImageFilter`. A cancellation or session end at any point returns nil and starts no further step.
- App/LinkPreviewWiring.swift: mock mode uses the mock provider, real mode with a client the LinkPresentation provider, the failed-bootstrap and no-client cases the inert provider. `ChristmasTrackerApp.swift` is untouched in this story (still 548 lines).
Tests (ChristmasTrackerTests/LinkPreview/, 59 new tests in 13 new files): normalizer table, service ordering and each normalization case through the service, the 429 path through the real repository over the fake transport, cancellation and session end at both steps, the guarded extraction against fake NSObject classes (both selectors, each selector missing, nil, non-URL values), mock and inert providers, `timeout == 8`, wiring through behavior, and source scans (LinkPresentation, `value(forKey:` and `imageMetadata` in exactly one file; marker present; a `responds(to:)` guard within 6 lines before each `value(forKey:`; `withTaskCancellationHandler`, `.cancel()` and `timeout` present).

## Commands and raw output
Before this commit, `scripts/verify.sh`:
```
--- tests: 5253 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: OK ===
```
(5194 + 59 new tests.) The changed files contain neither of the words the verify script's prohibited-framework check looks for (grep run before the commit).

## Gate 2
- Convention review: pass with two warnings, both fixed: the two fake NSObject classes were split out of `ProductImageMetadataReaderTests.swift` into their own files (one type per file), and a comment now explains that the private helper `MetadataFetch.run` is covered by the `@Instrumented` `imageUrl(for:)`.
- Acceptance review: APPROVE, no findings (device step ordering, timeout, cancellation and single resume, KVC guards, normalization before the filter, single-file isolation, privacy, hotlink only, wiring and session safety, protected paths).

## Deviations
None from the brief.

## Not done or partial
- Nothing here was run against the network or a simulator. No test exercises a real `LPMetadataProvider`: the cancel-before-start race, the exactly-once continuation, the 8-second timeout actually taking effect and the real key path on a real page are verified by code reading and source scans only. Brian's real-mode checks 12 and 17 are the only proof, and the key path is not public API (see the release blocker below).
- RELEASE BLOCKER: before any App Store submission, remove or replace the `imageMetadata` key path in LinkPresentationProductImageProvider. Ad hoc distribution is unaffected. The only release document outside the synced Docs files is Docs/release-runbook.md, an ad hoc runbook that says "No TestFlight, no App Store"; it is not an App Store checklist, so it was not edited. The handoff and Brian's PROGRAM.md carry this item (decision 14); Brian can decide whether the runbook should mention it.
- The "Add image" button is not in this story (P5).
