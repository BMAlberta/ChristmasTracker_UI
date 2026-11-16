# IMG1: Fill the item image from the product link
Track: iOS. Depends on: the API link-preview package (C18, C19), merged and synced; TH1 (thumbnails, merged). Blocks: nothing.
Contract state: synced from backend commit b52957c, decisions revision 41, spec sha256 43800da4ba32. `contract/STATUS.md` says CONFORMANT. No contract change in this package.

Why: TH1 shows thumbnails from the stored `imageUrl`. This package fills that field. When the user finishes entering the product URL on the Add or Edit form, the app asks the API for the product image (`getLinkPreview`). Because the API gets null for most large retailers, the device then tries a fallback through LinkPresentation behind one protocol in one file. iOS never downloads or parses page HTML itself. A user-started "Add image" action on the Edit form fills a missing image the same way.

The full instruction is `prompts/mobile-ui/IMG1-link-preview.md` (outside this repo). The decisions below are copied from it; where this file and the synced contract differ, the contract wins.

## Server contract (C18, C19)
- `POST /link-preview` with `{ url }` (http or https, at most 2048 characters). 200 with `data: { imageUrl: string | null }`. A missing image, a blocked target and every fetch failure are 200 with null, indistinguishable. 429 over 10 requests per minute per user. Usual 400, 401, 403, 500 envelopes.
- Item `url` must be http or https and `imageUrl` must be https, both at most 2048 characters and without userinfo; anything else is a 400.
- Generated client: `Operations.GetLinkPreview` (`Input.Body.json(JsonPayload(url:))`; `Output.ok` body `json.data` is `Components.Schemas.LinkPreview`). The derived spec turns the nullable `imageUrl` into an optional String.

## Decisions (1 to 17)
1. Trigger: when editing of the URL field ends (focus leaves, or submit), never per keystroke; at most one call per finish; the URL must pass the form's URL validation or no call is made.
2. When to fill: Add: when the image field is empty OR was set by a previous preview (never when the user typed it). Edit: only when the image field is empty, and only when the URL differs from the saved one or is newly entered.
3. A new call cancels the previous one. Leaving or saving the form cancels it. A result for a URL the field no longer holds is dropped.
4. From the API, null, 429 and any error mean "ask the device next"; cancellation and session end mean stop, silently. When the device also finds nothing the result is "no image": silent, no change. The field stays editable. The only new user-facing copy is the failure line of "Add image" (decision 16).
5. Typing in the image field marks the value as the user's own; previews never overwrite it. Clearing makes it empty again.
6. A returned value is accepted only if `ThumbnailURL.validate` accepts it and it has no userinfo; otherwise null.
7. Small thumbnail preview (ItemThumbnail) and a spinner while a call is in flight, in the Links section. No other layout change.
8. Tighten client validation to C19: `imageUrl` must be https; both URL fields reject userinfo.
9. Privacy: never log, report, breadcrumb or put the page URL or image URL in an error, span or description. This covers the device step.
10. Out of scope: item detail and rows, image upload, caching the preview, a favicon badge, automatic or bulk backfill, atomic create-and-purchase, theme changes, any contract edit.
11. Device fallback: API first, then the device, then no image. Runs on API null, 429 or error (never after cancellation or session end), on the same triggers, never on display. `LPMetadataProvider.startFetchingMetadata(for:)`, timeout about 8 seconds, image URL read through key path "imageMetadata" then "URL".
12. Isolation: `ProductImageProviding` (nonisolated, Sendable; page URL string in, image URL string or nil out; cancellation propagates, any other failure is nil), `LinkPresentationProductImageProvider` (the ONLY file allowed to import LinkPresentation or call `value(forKey:)`; a scan test enforces it), `MockProductImageProvider`. Only a String leaves the provider. Cancelling the task cancels the `LPMetadataProvider`.
13. KVC safety: guard EVERY hop with `responds(to: NSSelectorFromString(...))` before `value(forKey:)`. A pure function over `NSObject` does the guarded two-hop extraction and is tested with fake objects. Then: upgrade http to https, reject other schemes, reject userinfo, drop values over 2048 characters or with whitespace, then apply decision 6.
14. Release blocker: marker comment `APPSTORE-BLOCKER: non-public key path` in the provider file, a test that it exists, and the handoff line "Before any App Store submission, remove or replace the imageMetadata key path in LinkPresentationProductImageProvider."
15. Hotlink only: never store, copy or cache the image; metadata only; nothing else may be contacted by this code.
16. "Add image" on the Edit form only: shown when the image field is empty and the URL is valid; spinner and disabled while it runs; same lookup; on success fills the field as a fetched value and the normal Save sends it; on failure one quiet line "Couldn't find an image for this link."; never on display; one item at a time.
17. PATCH sends only what changed: on Edit, `url` and `imageUrl` only when the user changed them; clearing sends an empty string (never null); an Add-image fill counts as a change. On Edit, an unchanged stored value that fails the tightened rules (a legacy http image) must not block saving and shows no invalid message; only a changed field is validated.

## Gate 1 spec

### Wiring note (Brian, this session)
`App/Bootstrap.swift` is only the bootstrap decision file. The real composition root is `ChristmasTrackerApp.swift` (543 lines, error limit 600). All new code goes in new files (a `LinkPreviewWiring` file and the environment key file). `ChristmasTrackerApp.swift` gets the smallest possible edit, about 5 lines (one `@State`, one construction line, one `sm.register(...)`, one `.environment(...)`), and its line count is reported. Brian approved this edit.

### P1: the preview call (no UI). Full pipeline (generated-client and repository layer).
- Contract slice: `getLinkPreview` only.
- New interface: yes. `LinkPreviewLoading` (nonisolated, Sendable): `func imageUrl(for pageURL: String) async throws -> String?`. `GeneratedClientLinkPreviewRepository`, `MockLinkPreviewRepository`, `LinkPreviewService` (`@MainActor @Observable`, session-safe like StatsService): `func imageUrl(for pageURL: String) async -> String?`.
- Acceptance: 200 with a value maps to that string; 200 with null to nil; 429, 400, 500, undocumented status, transport error and an undecodable body return nil without throwing; cancellation propagates as CancellationError; the service validates the input URL (no call for an invalid one), applies decision 6 to the result, is cleared on session end, a session end during a call produces no state change and no error; no log, report or error text contains a URL (scan test).
- Files: `Features/LinkPreview/` (Repositories, Services), `Core/Extensions/EnvironmentValues+LinkPreviewService.swift`, `App/LinkPreviewWiring.swift`, the 5-line edit to `ChristmasTrackerApp.swift`; tests under `ChristmasTrackerTests/LinkPreview/`.

### P2: validation to match C19. Solo.
- `ItemFormValidation`: `imageUrl` https only; `url` http or https; both reject userinfo; both keep 2048 and whitespace rules. Header comment updated. Old http image cases are updated, not deleted. Edit-form legacy rule (decision 17) is specified here and tested in P3.
- New interface: no. Files: `ItemFormValidation.swift` and its test file.

### P3: the form behavior. Full pipeline (capability-flag-driven UI path is not touched, but the form owns the write path).
- New interface: a pure state type `ItemImageFillState` (no SwiftUI) with the decision table of decisions 1 to 5 and request token / stale-result handling.
- Wiring: AddItemView, EditItemView, ItemFormFields (small extracted subview), spinner with label "Looking for a product image", decorative preview thumbnail.
- `EditItemView`/`makeUpdateInput` change: send `url`/`imageUrl` only when changed; cleared fields send an empty string. Tests for changed, unchanged and cleared per field, and for an unchanged legacy http `imageUrl` (Save enabled, field not sent).
- Acceptance: the decision-table tests; a scan test that both forms use the same trigger path; previews with the mock repository.

### P4: the device fallback. Full pipeline.
- New interface: `ProductImageProviding`, `LinkPresentationProductImageProvider`, `MockProductImageProvider`, and a pure guarded extraction function over `NSObject`.
- Acceptance: service ordering (API value means no provider call; null, 429 and error each call the provider); normalization table; cancellation cancels the provider; session end during either step is silent; guarded extraction against fake NSObject subclasses; scans (LinkPresentation and `value(forKey:` in exactly one file, APPSTORE-BLOCKER marker, no URL in log/report/error text).

### P5: the Add image action. Full pipeline (touches the write path of the Edit form).
- Extends `ItemImageFillState` with the button rules and result handling; small extracted subview; accessibility label "Add image", hint, polite announcement of the failure line.
- Acceptance: the visibility table, the result handling table, a scan test that the button is built in one place, previews (button, running, failed).

## Inventory
"A/" = ChristmasTracker/ChristmasTracker/. "T/" = ChristmasTracker/ChristmasTrackerTests/.

Baseline (Step 0): `scripts/verify.sh` ends `verify: OK` with `tests: 5048 passed, 0 failed, 0 skipped`; `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed. The first verify run failed with "Derived spec is out of date"; the derived spec was regenerated outside this session and the second run passed.

### Forms and validation
- A/Features/Items/Views/AddItemView.swift (137 lines) and EditItemView.swift (134 lines): both own the field `@State` and build the input from `ItemFormValidation`. Edit passes `item` as `original`.
- A/Features/Items/Components/ItemFormFields.swift (73 lines): the shared Form sections; the Links section holds the `URL (optional)` and `Image URL (optional)` fields. The trigger, spinner, preview and button go here as small subviews.
- A/Features/Items/ViewState/ItemFormValidation.swift (166 lines): `validate`, `makeCreateInput`, `makeUpdateInput`. `optionalURLIsValid` accepts http or https for both fields today. `makeUpdateInput` sends `url`/`imageUrl` when non-empty and different from the original; clearing is treated as "not a change" (the generated update body could not clear a field). Decision 17 changes this: confirm in P3 against the generated `UpdateItemRequest` and the client guide what an empty string does.
- A/Features/Items/Components/ThumbnailURL.swift: `ThumbnailURL.validate` (https, host, at most 2048, no whitespace or control characters). A/Features/Items/Components/ItemThumbnail.swift: decorative, `accessibilityHidden(true)`.

### Service pattern to copy
- A/Features/Statistics/Services/StatsService.swift: `@MainActor @Observable`, `nonisolated let repository`, generation counter captured before the first await, `inFlight` cancel handles cancelled by `clearForSession()`, `perform` wrapper, `failure(...)` that drops cancelled or stale results, manual `SentrySDK.startTransaction` span with a comment because `@Instrumented` cannot apply to `@MainActor` methods, `SessionClearable` conformance.
- A/Features/Statistics/Repositories/GeneratedClientStatsRepository.swift: `nonisolated final class ... Sendable`, `@Instrumented` on the call, an explicit switch over every documented output case (no default), a failure mapper that passes `CancellationError` through and treats `URLError.cancelled` as cancellation. The link-preview repository differs: every non-cancellation failure returns nil.
- A/Features/Statistics/Repositories/StatsLoading.swift (protocol with the `-ing` suffix) and MockStatsRepository.swift; A/App/InertRepositories.swift holds the inert loaders used by the failed-bootstrap dependencies.
- A/Core/Extensions/EnvironmentValues+StatsService.swift: the environment key with an inert default. (The item one is spelled `EnvironemtValues+ItemService.swift`.)

### Composition root and session end
- A/ChristmasTrackerApp.swift (543 lines): `AppDependencies` (struct with one field per repository; `makeMock`, `makeReal`, `makeInert`), service construction (~lines 340 to 392), `SessionManager(initialClearables: makeProductionClearables(...))`, `Task { await sm.register(ImageCacheClearable(...)) }` for later registrations, and `.environment(\.statsService, ...)` at about line 489.
- A/Features/Authentication/Services/SessionClearable.swift: the protocol and `makeProductionClearables` (11 fixed clearables, indices must not move). The new service is registered with `sm.register(...)` so this list is not edited.
- A/Core/Extensions/NetworkCache+SessionClearable.swift and ImageCacheClearable.swift: other clearables.

### Seams used
- `APIProtocol` (TrackerAPI): `getLinkPreview(_ input: Operations.GetLinkPreview.Input)`. Middleware (bearer, refresh on 401, rate limit, version outdated, session ending) is applied by the client factory; a 429 on POST surfaces as `TrackerAPIError.rateLimited` without a retry.
- Logging: `LogError("...", category: .business)` with fixed text only. The new files log nothing that includes a URL, a value or an error description.

### Files over 400 lines that this package may touch
ChristmasTrackerApp.swift (543). Its final line count is reported in the P1 report.
