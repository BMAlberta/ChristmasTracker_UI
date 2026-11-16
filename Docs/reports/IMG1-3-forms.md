# IMG1-3: fill the item image from the product link (the form behavior)
Branch: feat/img1-link-preview. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
New (ChristmasTracker/ChristmasTracker/Features/Items/):
- ViewState/ItemImageFillState.swift: pure value type (`ItemImageSource`, `ItemFormMode`, `ItemImageLookup`, `ItemImageFillState`) holding the decision table of decisions 1 to 5: trigger rules, fill rules, request tokens, stale-result dropping, echo handling for the programmatic fill, cancel.
- ViewState/ItemImageFillModel.swift: `@MainActor @Observable`; owns the lookup Task (a new accepted lookup cancels the previous one; `cancel()` cancels and drops the result); calls `LinkPreviewService`; logs nothing.
- Components/ItemLinksSection.swift: the Links section subview. The ONE call site of `urlEditingFinished` (focus leaving the URL field, and `.onSubmit`); the Image URL field reports typing to the model; a spinner labelled "Looking for a product image"; the decorative ItemThumbnail preview when the image text is not blank; invalid-field lines for both URL fields.
Changed:
- ItemFormFields.swift uses the subview. AddItemView and EditItemView each own an `ItemImageFillModel`, pass it down, cancel it on disappear and when saving or creating starts; both have previews with the mock link preview service.
- ItemFormValidation.swift: `makeUpdateInput` sends `url` and `imageUrl` only when the user changed them; clearing sends `""` (never null); new `ItemFormCopy` strings (`invalidUrl`, `invalidImageUrl`, `lookingForImage`). The generated-client repository already passed `""` through unchanged; a new test pins the wire body `{"url":"","imageUrl":""}`.
Tests (6 new files, 67 new tests, all under ChristmasTrackerTests/Features/Items/): state decision table, model with the real service over the gated fake, update-input clearing, repository clear body, copy strings, source scans (one trigger call site, neither view contains it, both pass the model, no URL in logs, no Combine or GCD, spinner label, ItemThumbnail reuse).

## Commands and raw output
Before this commit, `scripts/verify.sh`:
```
--- tests: 5194 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: OK ===
```
(5127 + 67 new tests.) Earlier runs in the story: the first implementer run could not compile the tests (`#require` over a mutating call; the tests were fixed to bind the result first, the state stays a value type); then `5192 passed, 2 failed` (two old `ItemInputBuildingTests` cases that asserted "clearing is not a change"); updated, then 5194 passed.

## Gate 2
- Convention review: PASS, no findings.
- Acceptance review: APPROVE, no findings (checked trigger, fill rules, silent failures, filtering, stale results, echo, PATCH semantics, the legacy-http Edit path, invalid lines, spinner, privacy, protected paths).

## Deviations
- The brief names no invalid-field message for the URL fields; there was none (only the price had one). Step 10 of the real-mode check expects one, so `ItemFormCopy.invalidUrl` and `invalidImageUrl` and two caption lines (Cranberry destructive token, same style as the price line) were added.
- Old tests were UPDATED, not deleted: `ItemInputBuildingTests` (`updateClearingSendsEmptyString`, `updateClearingNextToChange`) now pin decision 17.
- The implementer subagent could not use the swiftui-expert-skill (the Skill tool was not available to it); the convention reviewer did not run it either. The SwiftUI review is by reading only.

## Not done or partial
- Nothing ran on a simulator or against the network: the focus and submit behavior, the spinner, the thumbnail and the invalid lines are covered by pure logic, model and source-scan tests and by previews only.
- Edge, by the letter of decision 2: on Edit the fill requires a blank image field, so after an Edit fill, changing the URL again does not re-fill (the image stays until the user clears it). On both forms a URL already looked up is not looked up again in the same form session, even after the image is cleared (this also keeps calls under the 10-per-minute limit).
- The device fallback is not in this story (P4), so a null from the API currently means no image.
- The "Add image" button is not in this story (P5).
