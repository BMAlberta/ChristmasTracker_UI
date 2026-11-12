# I4a-2: The purchase domain, the budget confirmation state machine, and the form rules

Branch: feat/i4a-record-purchase. Pipeline: full (isolated test-writer, implementer, then convention-reviewer and acceptance-reviewer one after the other). Gate 1 spec: Docs/epics/I4a-record-purchase.md, section "Story A". This story adds no view, no network code, and no service.

## What changed
- Domain types (Features/Purchases/Domain): RecordedPurchase (+ RecordedShippingStatus), PurchaseDraft, BudgetWarning (+ BudgetWarningLevel), PurchaseOutcome, RecordPurchaseError.
- Pure view-state and rules (Features/Purchases/ViewState): RecordPurchaseFormState (+ RecordPurchaseFormInput, OverPurchasePrompt), BudgetWarningPanelState (+ BudgetWarningRowState, RecordPurchaseCopy), RecordPurchaseFlow (+ PendingConfirmation, state, event, and effect types) with an injected clock and the single expiry constant `RecordPurchaseFlow.confirmationLifetime` (270 s, comment: the server's limit is 5 minutes).
- Mapping (Features/Purchases/Repositories/PurchaseMapping.swift): pure nonisolated functions from the generated purchase, warning, and result types to the domain types, money through `doubleToDecimal`.
- ListItem gains optional `quantityPurchased` and `quantityRemaining` (nil when absent); ItemMapping fills them from the generated Item (the detail mapping inherits them); `ItemDetailState.remainingQuantity` now comes from `quantityRemaining` only and is nil when the caller cannot see gift activity (never computed).

## Files
Added (production): `Features/Purchases/Domain/{RecordedPurchase,PurchaseDraft,BudgetWarning,PurchaseOutcome,RecordPurchaseError}.swift`, `Features/Purchases/ViewState/{RecordPurchaseFormState,BudgetWarningPanelState,RecordPurchaseFlow}.swift`, `Features/Purchases/Repositories/PurchaseMapping.swift`.
Changed (production): `Core/Models/ListItem.swift`, `Features/Items/Repositories/ItemMapping.swift`, `Features/Items/ViewState/ItemViewState.swift`.
Added (tests, `ChristmasTrackerTests/Features/Purchases/`): PurchaseFixtures, PurchaseFlowHarness (no tests), RecordPurchaseFormValidityTests, RecordPurchaseTotalCostParsingTests, RecordPurchaseOverPurchasePromptTests, RecordPurchaseUnitCostTests, BudgetWarningPanelStateTests, RecordPurchaseErrorTests, RecordPurchaseFlowTests, RecordPurchaseFlowConfirmationTests, RecordPurchaseFlowIgnoredEventsTests, PurchaseMappingTests.
Changed (tests, `ChristmasTrackerTests/Features/Items/`): ItemWireSupport, ItemFixtures, ItemMappingTests, GeneratedClientItemRepositoryTests, ItemDetailStateTests, ItemDetailStateRemainingTests.
Docs: this report; the epic (brief text brought in line with the patched prompt, Gate 1 interface for Story A); the P0 report (after-commit output for 9f88f78 added, as agreed with Brian; one prose line reworded so the word for the prohibited dispatch API no longer appears in a changed file). Deleted: none (one test deleted, see below).

## Deviations and decisions
1. NAME: the brief says `PurchaseError`; a top-level `enum PurchaseError` already exists in the legacy `Features/Purchases/Repositories/MockPurchaseRepository.swift:159` and is used by legacy views that must not be touched until I4b, so a second one would be a redeclaration. The new type is `RecordPurchaseError`. I4b can rename it after deleting the legacy one. (Decided by the Orchestrator at Gate 1 and recorded in the epic; Brian did not pre-approve this name, so please confirm or choose another.)
2. STATE ADDED: the brief lists the states editing, submitting, awaitingConfirmation, recorded, failed. The flow adds `expired` (the expired message with one button back to editing) because the expiry message needs a state of its own. The events `retry` and `dismissError` were added for the failed-state buttons (Try Again repeats the submit with NO token; Dismiss returns to editing). `submitting` carries only `isConfirmed`, never the token.
3. PATCHED PROMPT: per Brian's instruction there is no token-error branch. A confirmed resubmit answered by a new confirmation_required uses the replacement rule with the notice "The amounts changed since the last warning. Review them and confirm again."
4. PARSER choices the spec left open (in the code): only ASCII digits and the locale's decimal separator are accepted; grouping separators, signs, exponents, and currency symbols are rejected (tested); integer text such as "12" is accepted (tested); ".50" (empty whole part) and "12." (trailing separator) are rejected by the code but NOT pinned by any test. Unit cost is Decimal rounded to two places with `.plain`.
5. The mapping functions carry no `@Instrumented`: they are pure, non-suspending nonisolated free functions, following the precedent of `Features/Items/Repositories/ItemMapping.swift` (convention-reviewer confirmed the precedent). `@Instrumented` applies to the async repository functions in Story B.
6. A 200 body that carries `created` maps to `created` (the purchase exists); a 201 body that carries confirmation_required is `invalidResponse`; a 200 confirmation_required never becomes `created`. The generated `PurchaseConfirmationRequiredData` has no purchase member at all (the generator dropped the null-typed property); Story B re-checks the shape after this regeneration as agreed.
7. Process note: the test-writer used `sed -i` and a one-off python heredoc on test files, against the command habits. No stray files remain (convention-reviewer ran a search). The implementer added `import Testing` to `PurchaseFlowHarness.swift` (a genuine compile error; no assertion changed).

## Tests
Previous total (baseline after P0): 2089 app tests, 212 package tests. New: 121. Deleted: 1. Rewritten (count unchanged): 4. New total: 2089 + 121 - 1 = 2209 (run result below). Package: 212 + 0 = 212.
- New, Purchases folder (113): Record purchase form validity (11), total cost parsing (7), over-purchase prompt (7), unit cost (5), budget warning panel state (11), error (9), flow (19), flow confirmation (20), flow ignored events (4), purchase mapping (20). Names are the `@Test` functions of the files listed above (for example `validCosts`, `enUSRejectsRange`, `zeroRemaining`, `replacementOnConfirmedResubmit`, `confirmationNeverCreated`, `guideShapedConfirmationJSON`).
- New, Items (8): ItemMappingTests `quantitiesPresentMap`, `quantitiesAbsentStayNil`, `zeroQuantitiesStayZero`, `detailInheritsQuantities`; GeneratedClientItemRepositoryTests `fetchItemsQuantitiesPresentAndAbsent`, `fetchItemDetailQuantitiesPresentAndAbsent`; ItemDetailStateRemainingTests `absentIsNotComputed`, `visibleForGiftActivityPersonas`.
- Changed deliberately (reason for all: decision P24, the remaining text comes from the server's `quantityRemaining`, never from `requested - totalQuantityPurchased`): ItemDetailStateTests "Remaining quantity is requested minus purchased" renamed to "Remaining quantity is the server's quantityRemaining, not a client computation" (item now carries `quantityRemaining: 3`, expectation still 3); `richItem` gains the two quantities; ItemDetailStateRemainingTests `overPurchaseNotNegative` replaced by `overPurchaseShowsServerZero`, `partialUnchanged` replaced by `remainingComesFromServer` (0, 1, 3, 5), `hiddenStaysNil` broadened to blind owner, blind co-owner, viewer, and public non-member. DELETED: `fullyPurchased` (covered by `remainingComesFromServer` with 0).
- Reconciliation: the acceptance-reviewer counted 113 `@Test` functions in Purchases, +2 and +4 in the Item tests, and ItemDetailStateRemainingTests 4 to 5, for a net +120 = 2209 - 2089 (a count of test functions; the run result is the authority).

## Raw output (command run)
Before the commit (the Story A working tree, `scripts/verify.sh` summary lines):
```
=== verify: derived spec ===
=== verify: build ===
=== verify: configuration check ===
=== verify: unit tests ===
--- xcodebuild exit status: 0 ---
--- tests: 2209 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 212 tests in 16 suites passed after 0.023 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 92 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.018 seconds.`

The after-commit runs for this commit are recorded in the Story B report (a report cannot contain the result of the commit that adds it).

## Gate 2
- convention-reviewer: APPROVE. No hard blocks. Evidence: no force unwraps, Combine, or GCD in new or changed files; no Log calls or token/amount interpolation (the only interpolations are the intended panel and prompt text, RecordPurchaseFormState.swift:130, BudgetWarningPanelState.swift:53 and :62); `Double` appears in production only as the input to `doubleToDecimal` (PurchaseMapping.swift:15); the expiry constant is defined once (RecordPurchaseFlow.swift:53) with the 5-minute comment; legacy files, contract/, .claude/, .pbxproj, synced Docs, and LocalPackages untouched; no stray files. One low warning (the prohibited word in a docs line of the P0 report) was fixed by rewording that line.
- acceptance-reviewer: APPROVE. Transition table verified against the code (RecordPurchaseFlow.swift:62-67 read-only matrix, :112-120 first confirmation and S12 replacement with `budgetChangedNotice`, :133-148 expiry, :87 and :99 sends are `send(nil)`); parser rejections at RecordPurchaseFormState.swift:103-118 and boundaries tested at RecordPurchaseTotalCostParsingTests.swift:30-59; prompt rule at :127-133; mapping at PurchaseMapping.swift:72-91; `ItemViewState.swift:215` takes `quantityRemaining` only when `showsActivity`; no test judged vacuous (expiry at 269.999, 270, 270.001; S12 asserts the full replaced pending confirmation).
- Rejections: none. Stuck-detector log: no triggers (the implementer's first test run failed only to compile because of the missing `import Testing`; fixed, then green).
- Reviewer note carried forward: `PendingConfirmation` is Equatable and holds the token, so any future `String(describing:)` or log of the flow state would include it. No such use exists; Stories B and C must not log or describe the state.

## Not done or partial
- No view, repository, service, composition, or real-mode check exists yet (Stories B to D).
- No test pins ".50" or "12." either way beyond the documented rejection; if Brian wants ".50" accepted, it is a one-line parser change.
- Name `RecordPurchaseError` awaits Brian's confirmation (deviation 1).
- `scripts/verify.sh` after the commit is not in this report (see above).
