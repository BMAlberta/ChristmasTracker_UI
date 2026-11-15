# IMG1-2: item URL validation to match C19
Branch: feat/img1-link-preview. Pipeline: solo (implementer wrote the failing tests, implemented, looped build and test), then convention review.

## What changed
- `ItemFormValidation.swift`: `url` accepts http or https; `imageUrl` accepts https only; both reject userinfo (`user@host`, `user:pass@host`) and keep the host, 2048-character and no-whitespace rules. Header comment updated.
- Decision 17, validation half: `validate` takes optional `originalUrl` and `originalImageUrl` (default nil). A field whose trimmed value equals its trimmed stored original is not validated, so an unchanged legacy value (for example a stored http image) neither blocks Save nor sets an invalid flag. `makeUpdateInput` passes `original.url` and `original.imageUrl`. Add passes nothing, so everything is validated. How `makeUpdateInput` chooses which fields to send is unchanged (the empty-string clear is story P3).
- Tests: new `ItemFormValidationC19Tests` (18 tests: valid and invalid cases for both fields, 2048 boundary, userinfo, create and update builders, legacy unchanged, padded, changed, changed to https, legacy url with userinfo, no-originals). Existing tests updated, not deleted: `fullFormIsValid` and `validUrls` (https-only image), new `httpUrlOnly`, and `ItemInputBuildingTests.createFull` (http to https at the input and the expectation; this file was outside the first file list and the edit was approved by the Orchestrator because it is the same old-http-image case).

## Commands and raw output
Red: the first `scripts/test.sh` run exited 65 with no tests run (the new `validate` parameters did not exist, so the tests did not compile).
Intermediate full-suite run: `5126 passed, 1 failed` (`ItemInputBuildingTests/createFull()`, an old http image case); fixed as above.
Before this commit, `scripts/verify.sh`:
```
--- tests: 5127 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.017 seconds.
=== verify: OK ===
```
(5108 + 19 new tests.)

## Gate 2
Convention review: PASS, no findings. Acceptance review is not required on the solo path.

## Deviations
- The brief says the Edit-form legacy tests belong to P3 (decision 17); the validation-layer tests are here because the tightened rule would otherwise block saving an item with a legacy http image between this commit and P3. P3 still adds the changed, unchanged and cleared send tests.

## Not done or partial
- No form passes the originals yet: the forms still do not show an invalid message for either URL field (only the price has one today). P3 adds that message and wires the forms.
- Nothing ran on a simulator or against the network.
