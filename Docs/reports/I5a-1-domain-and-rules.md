# I5a-1: Domain and pure rules

Branch: feat/i5a-stats-budgets. Commit subject: "I5a: add budget and stats rules, view states, and mapping".
Pipeline: full (isolated test-writer, then implementer, then both reviewers one after the other). The SwiftUI guidance skill was not needed (no views in this story).

## Files
Added (production, ChristmasTracker/ChristmasTracker/Features):
- Budgets/Domain/Budget.swift (RecipientBudget, Budget, BudgetLimit, CreateBudgetRequest, UpdateBudgetRequest, DuplicateBudgetRequest)
- Budgets/Domain/BudgetError.swift, BudgetAmountParser.swift, BudgetValidation.swift (with BudgetRecipientDraft and BudgetDraft), BudgetRequestBuilder.swift, BudgetRecipientOptions.swift, BudgetYearChoices.swift
- Budgets/ViewState/MoneyText.swift, BudgetCardState.swift (with BudgetPersonRowState)
- Budgets/Repositories/BudgetMapping.swift (pure mapBudget, mapStatsYear)
- Statistics/Domain/StatsYear.swift (RecipientSpend, StatsRecipientBudget, StatsBudget, StatsYear)
- Statistics/ViewState/StatsScreenState.swift (StatsSummaryState, SpendRowState, StatsScreenState)

Added (tests, ChristmasTracker/ChristmasTrackerTests/Features):
- Budgets/: BudgetFixtures.swift (helper, no tests), BudgetAmountParserTests, BudgetValidationTests, BudgetRequestBuilderTests, BudgetRecipientOptionsTests, BudgetYearChoicesTests, BudgetErrorTests, MoneyTextTests, BudgetCardStateTests, BudgetMappingTests, StatsYearMappingTests
- Statistics/: StatsScreenStateTests, SpendRowStateTests

Changed: Docs/epics/I5a-stats-budgets.md (Gate 1 interface signatures added before the tests were written; that file is part of this commit). Deleted: none. No existing test changed.

## Test arithmetic (app suite)
Baseline 3241 + new 164 - deleted or rewritten 0 = 3405 (verify.sh reports 3405 passed, 0 failed, 0 skipped). New @Test entries by file (a parameterized test counts as one): parser 6, validation 22, request builder 21, recipient options 20, year choices 24, error 9, money text 4, card state 23, budget mapping 7, stats year mapping 9, stats screen state 14, spend row state 5 = 164. Package suite: 212 unchanged. Release script tests 92, destination script tests 17 (unchanged).

(The test-writer's first summary contained miscounts; the figures above are from the per-file lists it gave and they reconcile to the run: 164.)

## Verification (commands run)
Before commit (scripts/verify.sh, summary lines, raw):
```
--- tests: 3405 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"` before commit:
```
Test run with 212 tests in 16 suites passed after 0.018 seconds.
```
After-commit run: a report committed with the code cannot contain its own after-commit output; the after-commit raw summaries for this commit are recorded at the top of the Story B report ("baseline for Story B").

## Design decisions and deviations
- BudgetAmountParser is a NEW parser. RecordPurchaseFormState.parseTotalCost rejects zero (value must be above 0) and purchase code may not change in this package, but a budget may be 0 to 999999.99. The lexical rules are the same (ASCII digits plus the locale decimal separator, at most two decimals, no grouping or signs). Duplication is limited to those rules.
- BudgetError is also the error type of the stats repository (no separate StatsError); Story B follows.
- No over-budget color token exists (Assets Colors/Budget is empty); over-budget styling will use Color.destructiveColor in Story C. Over-ness is decided in Decimal, never from the server flag alone.
- MoneyText (one shared currency formatter) is new; older inline formatters were not refactored.
- Spec observation for Story B: updateBudget documents no 422 although the guide says the sum rule is enforced.
- The test files declare two small helper types for parameterized cases (ParserCase, BudgetErrorCase) beside their suites.

## Gate 2
Convention-reviewer: APPROVED, no hard blocks. Warnings: W1 eight test lines over 120 characters (none over 160); W2 StatsYearMappingTests sits in the Budgets test folder because the pure mapping lives in BudgetMapping.swift (consistent with Gate 1). Focus answers: no @Instrumented needed (pure, no repository/service functions); no force unwraps, no Combine/GCD (grep clean including comments); error switches exhaustive without default (BudgetError.swift:24-72); no logging; Double only for the final progress fraction (BudgetCardState.swift:103-107) and the mapping input (BudgetMapping.swift:12).
Acceptance-reviewer: APPROVED. Truth tables all covered and correct; "Over by ..." produced in one place (BudgetCardState.swift:74-79) for the card and person rows and asserted in BudgetCardStateTests.swift:237-262; the bounds are inclusive (BudgetAmountParser.swift:11-34); update sends only changed fields and the full recipient list when people or limits changed; mapping rejects non-finite money and the `.all` scope. Observations (not rework, recorded): the parser digit check uses a Character range, so a combining mark after a digit relies on Decimal(string:) leniency (same pattern as RecordPurchaseFormState); `Character(locale.decimalSeparator ?? ".")` would trap on a multi-grapheme separator (same pattern as the purchase form; no real locale triggers it); no test for a swapped person in an edit; the card year comes from budget.year when the two differ (the service keeps them equal).
Rejections: none. Stuck-detector: no attempts needed (green on first run). Verification claims above came from running commands except the focus answers, which came from reading code.

## Not done or partial
- No views, repositories, services or composition (Stories B and C).
- The low-priority observations above were not acted on.
- No simulator run was possible or attempted; this story has no UI. Brian's real-mode check (Story D) is the only proof of the on-screen behavior of the package.
