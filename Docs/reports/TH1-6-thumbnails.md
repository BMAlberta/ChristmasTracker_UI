# TH1-6: Item thumbnails (display only)

Commit: "TH1: show item thumbnails from the stored image URL". Pipeline: full (Gate 1 in Docs/epics/TH1-theme-pass.md; isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer, one after the other).
SwiftUI guidance (swiftui-expert-skill rules passed to the implementer in the brief): modern APIs, private @State and @ScaledMetric, no AnyView, Dynamic Type, DesignSystem tokens only, previews with placeholder, dark and large-type states.

## After-commit run of the previous commit (TH1-5, 0da27aa), taken by running the commands
```
--- tests: 4587 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```

## What changed
- `ThumbnailURL.validate` (pure, nonisolated) accepts only an absolute https URL with a non-empty host, at most 2048 characters, no whitespace or control characters, and a round trip (`absoluteString == input`, so anything the parser would normalise is rejected). Everything else (nil, empty, http, other schemes, malformed, missing host, relative, over-long) gives the placeholder and no request. `ThumbnailPresentation.content(for:)` returns `.image(URL)` only for a valid value. `ThumbnailLayout`: base size 56, maximum 112 (`clamped`), and `rowThumbnailVisible(for:)` false at accessibility Dynamic Type sizes.
- `ItemThumbnail` (Features/Items/Components): a square with a @ScaledMetric size (base 56, relative to `.body`) capped at 112, continuous rounded corners, `AsyncImage` only for a valid value; the loading, failure and invalid states all show ONE shared placeholder view (`backgroundSecondaryColor` with a gift symbol in `textMutedColor`); the whole view is `.accessibilityHidden(true)` and the row's text carries the meaning. The URL is never logged, interpolated or reported.
- `ItemRowState` and `ItemDetailState` carry `imageUrl` (copied from `ListItem`; `ItemRowState.init` defaults it to nil, used only by two previews; every production call passes the item's value). `ItemRow` shows the thumbnail as the leading child of its row (hidden at accessibility text sizes, decision: the row text matters more there); `ItemDetailView` shows it as the first child of the header card (always, within the 112 cap). The row's text layout is otherwise unchanged.
- Image cache clear: `ImageCacheClearing` seam (Sendable), `URLCacheClearer` (calls `URLCache.shared.removeAllCachedResponses()`), and `ImageCacheClearable: SessionClearable` (calls the seam exactly once per `clearForSession`). It is registered once through the existing teardown mechanism, `SessionManager.register`, in ChristmasTrackerApp.swift (line 370), so it runs on every session end (userLogout, sessionExpired, forcedUpdate, lockFallback). The 10-element `makeProductionClearables` array, its scan tests and SessionManager.swift are untouched. This is the ONE allowed non-presentation change.
- `clearForSession` is `async throws` in a service layer and MainActor-isolated by the module default, so it follows the actor exception: no `@Instrumented`, a manual Sentry span `service.imageCache.clearForSession` with the explaining comment (ChildService precedent), and no data in the span.

## Notes and deviations
- The registration is `Task { await sm.register(ImageCacheClearable(cache: URLCacheClearer())) }` in the synchronous `ChristmasTrackerApp.init`, because there is no async context there; making it race-free would mean changing the clearables array, which the brief forbids. The first teardown needs a user action or a failing request after launch, so a window is theoretical; and `SessionManager.teardown` already clears `URLCache.shared` directly at SessionManager.swift:46 (existing session logic, unchanged), so a missed registration could not leave a stale cache. The new clearable makes the clear explicit and testable; it is a harmless second clear.
- The implementer added the four clamp tests itself (a deviation from the test-writer/implementer split, allowed by the Orchestrator for a pure function with a clear spec).
- Test spy `MockImageCacheClearing` is `@unchecked Sendable`: `ImageCacheClearing` is a nonisolated `Sendable` protocol, so the spy needs a class with a mutable counter, guarded by an `NSLock` (as `MockSessionClearable` does).
- The literal `"gift"` SF symbol is in ItemThumbnail.swift because the project has no AppIcons type.
- Recommendations (not done, optional hardening, banked): reject URLs with userinfo (`https://user:pass@host`) and consider localhost and private hosts; the brief only requires https, a host and the length cap. `failedLoadIsPlaceholder` is a close-to-tautological test (enum case equals itself); the structure (one shared `ThumbnailPlaceholder`) is what guarantees it.
- No contract change; no `Docs/contract-issues.md` entry.

## Files
Added: Features/Items/Components/ThumbnailURL.swift, ItemThumbnail.swift; Features/Authentication/Services/ImageCacheClearable.swift; tests Features/Items/ThumbnailURLTests.swift, ThumbnailLayoutTests.swift, ItemImageUrlStateTests.swift, ThumbnailSourceScanTests.swift; Features/Authentication/ImageCacheClearableTests.swift.
Changed: Features/Items/ViewState/ItemViewState.swift, Features/Items/Components/ItemRow.swift, Features/Items/Views/ItemDetailView.swift, ChristmasTrackerApp.swift (the one register line). No asset catalog file changed. Deleted: none. No existing test changed.

## Tests: arithmetic
4587 + 35 = 4622. New (parameterized counted as one): ThumbnailURLTests 9 (maximum length, valid accepted and round trips, invalid rejected (19 labelled cases), uppercase scheme, exactly 2048, 2049 rejected, presentation placeholder for every invalid value, presentation image for a valid value, failed load maps to the placeholder case); ThumbnailLayoutTests 7 (base size, row visibility per DynamicTypeSize, both outcomes occur, and four clamp tests: maximum 112, below, exactly, above); ItemImageUrlStateTests 4 (row nil, row value, detail nil, detail value); ImageCacheClearableTests 6 (nothing cleared before a session ends, exactly one clear per clearForSession, two calls two clears, one clear per teardown for each of the four reasons, a throwing sibling registered first, a throwing sibling registered after); ThumbnailSourceScanTests 9 (AsyncImage only in ItemThumbnail, no URLSession image loading in Features/Items, URLCache.shared only in the clearer file and SessionManager, no logging or reporting in the thumbnail files, accessibility/scaling/continuous corners, row and detail use ItemThumbnail, row hides through ThumbnailLayout, the app registers the clearable exactly once, makeProductionClearables unchanged). Rewritten/deleted: none. Package 212, release 92, destination 17 unchanged. No test loads a real image or touches the real URLCache.

## Raw verification (before the commit, by running the commands)
```
--- tests: 4622 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
swift test --package-path "LocalPackages/TrackerAPI": Test run with 212 tests in 16 suites passed
```
The after-commit run of this commit is recorded in the TH1-7 report.

## Gate 2
- convention-reviewer: first REJECTED (hard block: `clearForSession` had neither `@Instrumented` nor a manual span). Fixed with the manual span and re-reviewed by the same reviewer: APPROVED. It also passed naming, nonisolated/Sendable, no force unwraps, Combine, GCD or logging, design tokens, and the `Task { await sm.register }` concurrency analysis; warning (closed by the second fix): `@ScaledMetric` had no upper bound, so the 112 cap and `clamped` were added.
- acceptance-reviewer: APPROVED. Evidence: only a valid https URL reaches AsyncImage (ThumbnailURL.swift:18-29, :41; ItemThumbnail.swift:25, :27); no logging (ItemThumbnail.swift, ThumbnailURL.swift, and the span carries no data); decorative (ItemThumbnail.swift:20); one placeholder (ItemThumbnail.swift:33, :37); registered once (ChristmasTrackerApp.swift:370); all teardown reasons run it; production callers pass imageUrl (ItemViewState.swift:93-97, :211); no change under contract/, .claude/, any .pbxproj, LocalPackages/ or synced Docs.
- Rejections: one (above). Stuck detector: the implementer was green on the first attempt; one fix round after the rejection; no repeat.

## Not done or partial
- The two optional hardening items above (userinfo, localhost and private hosts) and the tautological test are banked, not done. The thumbnail layout (row at normal sizes, detail header, cap at large text), the placeholder and loaded looks, and that images actually load from a real https URL are NOT verified: no simulator run was possible. Brian's real-mode check is the only proof of what the screens look like (colors, the glass chrome, the prominent button's label color in dark mode, the Dynamic Type layout and the thumbnails all need eyes on the simulator).
