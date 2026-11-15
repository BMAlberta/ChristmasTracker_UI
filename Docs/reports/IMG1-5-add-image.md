# IMG1-5: the Add image action on the Edit form
Branch: feat/img1-link-preview. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
Under ChristmasTracker/ChristmasTracker/Features/Items/:
- ViewState/ItemImageFillState.swift: `ItemAddImageStatus` (idle, running, failed); `addImageStatus`, `addImageVisible(url:imageUrl:)`, `addImageEnabled(url:imageUrl:)`, `addImageRequested(url:imageUrl:)`; `ItemImageLookup` gains a defaulted `isExplicit`. Visible on Edit only, only when the image text is blank and the url passes validation (stays visible while running and after a failure; hidden once any value is present; never on Add). An explicit request ignores the automatic rules "url differs from saved" and "url not looked up before", so an old item whose url equals the saved one works. An explicit success fills as a fetched value; nil or a filtered-out value sets `failed`; stale, cancelled, session-ended, url-changed and typed-meanwhile results are dropped silently (idle, no failure line). `failed` is cleared by a new request, typing in the image field, a new automatic lookup, and cancel.
- ViewState/ItemImageFillModel.swift: `addImageStatus` and `addImageRequested(...)`; both lookup kinds go through one private `run` (same task handling). `run` records the service's session generation and, if it changed during the call, applies nothing and shows no failure.
- ViewState/ItemFormValidation.swift: `ItemFormCopy.addImageTitle` ("Add image"), `addImageHint` ("Looks for a picture on the product page.") and `addImageFailure` ("Couldn't find an image for this link.").
- Components/ItemAddImageButton.swift (new): the ONLY place the button and the failure line are built (`ItemAddImageRow` stateless view plus `ItemAddImageButton` wrapper with the single `addImageRequested(` call site). The button is disabled with a labelled spinner while it runs; the failure line is one quiet caption under it, announced politely with `AccessibilityNotification.Announcement` when the status becomes failed. Three previews: button, running, failed.
- Components/ItemLinksSection.swift: shows the button once, below the image row, when `addImageVisible` is true; the section's own spinner is hidden while the explicit lookup runs (one spinner).
AddItemView.swift, EditItemView.swift and ChristmasTrackerApp.swift are unchanged in this story.

Tests (5 new files, 67 new tests): visibility and enabled tables, request and result tables including the key old-item case and the fill-then-Save trace (`makeUpdateInput` sends the new `imageUrl` and omits the unchanged `url`), the model with the real service over the gated fake (value applied once, nil gives failed, cancel, session end, one lookup at a time), copy strings, and source scans (the button is built and called in one place, neither form mentions the action, Add never references the button, the failure literal exists in one file, no URL in logs).

## Edit-form reachability (decision 16)
EditItemView is presented only from ItemDetailView.swift:318 (the `.edit` sheet), opened by the toolbar Edit button shown only when `state(for: item).showsEdit` (ItemDetailView.swift:66 to 69). The form cannot open without that gate, so no second check was added.

## Commands and raw output
Before this commit, `scripts/verify.sh`:
```
--- tests: 5320 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: OK ===
```
(5253 + 67 new tests.) Earlier in the story: the first implementer run could not compile the tests (the same `#require` over a mutating call as in P3, in two test files); the test-writer fixed the tests, then the suite passed.

## Gate 2
- Convention review: PASS, no findings.
- Acceptance review: APPROVE, no findings.

## Deviations
- Spec ambiguity resolved by the Orchestrator and accepted by the acceptance reviewer: decision 16 says the button shows a spinner and is disabled while it runs; the P5 step text says "hidden while a lookup runs". The button stays visible and disabled (decision 16): hiding it would move the layout and lose the spinner's place.
- The session-generation guard in `ItemImageFillModel.run` also applies to automatic lookups now. This is a small, benign change to the P3 behavior: a session end during an automatic lookup applies nothing (the service already returned nil then).
- The failure line uses the quiet caption style, not the destructive color of the invalid-URL lines (decision 16: "one quiet line").
- The swiftui-expert-skill was not available to the implementer or the convention reviewer (the Skill tool is not available inside subagents); the SwiftUI review is by reading only.

## Not done or partial
- Nothing ran on a simulator or against the network: the button's look, the spinner, the failure announcement and the real fills are covered by logic and model tests, scans and previews only.
- The explicit lookup is subject to the same API rate limit (10 per minute per user); a 429 or any failure shows the failure line like any other miss.
- There is no automatic or bulk backfill, by design (decision 16).
