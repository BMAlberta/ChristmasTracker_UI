# OL1-1: the already-bought rules (story O1)

Branch: feat/ol1-offlist-purchase. Pipeline: full (isolated test-writer, implementer, convention-reviewer, acceptance-reviewer).

## What changed
- New `Features/Items/ViewState/OffListPurchaseOption.swift`: `OffListPurchaseFormMode` and `OffListPurchaseOption` (pure, nonisolated, Sendable). Toggle shown only for Add mode with `canAddOffList` (through `ItemPermissions.showsOffListNotice`) and `canPurchase`; never a role. `totalCents` is the unit price in integer cents times the quantity (1 to 999), price above zero through `ItemFormValidation.parsePrice`, `multipliedReportingOverflow`, and a total above 99,999,999 cents is rejected (the Record Purchase form rejects a cost above 999999.99). `totalText` is built from integer cents with the passed locale's decimal separator, two decimals, no grouping, no floating point. `allowsAdd(formIsValid:)` is `formIsValid && priceRequirementMet`. `startingInput` is the `RecordPurchaseFormInput` for the sheet.
- New `Features/Items/ViewState/OffListPurchaseStep.swift`: `idle`, `creating`, `createdAwaitingPurchase(ListItem)`, `finished`; `beginCreate()` succeeds only from idle.
- `Features/Purchases/ViewState/RecordPurchaseModel.swift`: one trailing optional initializer parameter `startingInput: RecordPurchaseFormInput? = nil` (`storedInput = startingInput ?? today's default`). Diff +3/-2.
- Tests (7 new files, no existing test edited): toggle table, add-allowed table, total arithmetic and boundaries, comma-locale round trip through `RecordPurchaseFormState.parseTotalCost`, starting input, state machine, model with a starting input, and a scan test for logging or interpolation of price, total, cost, name, cents or amount.

## Commands and raw output
Baseline (Step 0): `tests: 5334 passed, 0 failed, 0 skipped`; package `Test run with 212 tests in 16 suites passed`.

Red phase (test-writer): `scripts/test.sh` exit status 65, only missing-type errors and `extra argument 'startingInput' in call`.

After (before commit), `scripts/verify.sh`:
```
** BUILD SUCCEEDED **
--- tests: 5383 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.040 seconds.
=== verify: OK ===
```
49 new tests.

## Reviews
- Convention reviewer: PASS. Warnings W1 and W2 (two lines over 120 characters in tests) fixed by wrapping, then `grep -nE '.{121,}'` over the new files returned nothing and `scripts/test.sh` stayed at 5383 passed. W3 (top-level types without an explicit access level): kept as is, the neighbouring ViewState files declare types the same way.
- Acceptance reviewer: APPROVE, no rejection. Observations: the overflow branch is defensive and unreachable with the price cap and quantity of at most 999; the quantity guard 1...999 repeats the stepper limit; the option and the model each take their own `Locale` (both default to `.current`), so O2 must pass the same locale to both.

## Deviations
- The brief says the total is "shown with two decimals"; the cap of 99,999,999 cents is an addition from the Record Purchase form's own maximum and is recorded in the epic brief.

## Not done or partial
- No UI yet (story O2). Nothing was run in the simulator; O1 has no UI.
- The overflow branch of `totalCents` has no test that reaches it (it cannot be reached with the current limits).
