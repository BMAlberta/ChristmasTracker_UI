# I5a-3: The Statistics tab and the budget editor, duplicate and delete flows

Commit subject: "I5a: build the Statistics tab and the budget editor, duplicate and delete flows".
Pipeline: full (isolated test-writer, implementer, convention-reviewer, then acceptance-reviewer, one after the other). The swiftui-expert-skill was available to the Orchestrator; its rules were loaded and written into the Story C interface section of the epic brief (and so into the implementer's brief), because subagents cannot invoke skills.

## Baseline for this story (after-commit run of the Story B commit 9f6f895)
```
--- tests: 3703 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
Test run with 212 tests in 16 suites passed (package)
```

## Files
Added production (ChristmasTracker/ChristmasTracker/Features):
- Statistics/ViewState/StatsScreenModel.swift
- Budgets/ViewState/BudgetEditorModel.swift, DuplicateBudgetModel.swift
- Statistics/Views/StatsSummaryCardView.swift (also the shared `statsCardStyle()` modifier), BudgetCardView.swift (also BudgetPersonRowView, BudgetAmountLine, NoBudgetCardView, CreateBudgetButton), BudgetCardMenu.swift, SpendByPersonView.swift
- Budgets/Views/BudgetEditorView.swift, DuplicateBudgetView.swift
Changed: Statistics/Views/StatsView.swift (rewritten; also holds StatsContentView, StatsStateView, StatsYearPicker and a #Preview with mock-backed services). TabBarView.swift untouched (still `StatsView()`).
Dead code removed: the placeholder `StatsView.body` (the `EmptyStateView(icon: "chart.bar.fill", title: "Statistics coming soon", ...)` and its message), the old one-line `#Preview { StatsView() }` and the "Created by" header line of that file. No file deleted.
Docs: Docs/epics/I5a-stats-budgets.md (Story C interface section, written before the tests; one line corrected after the test-writer found that StatsScreenModel needs the ListService).
Added tests (ChristmasTrackerTests/Features): Statistics/{StatsScreenModelHarness (helper), StatsScreenModelLoadTests, StatsScreenModelStaleBannerTests, StatsScreenModelDeleteTests, StatsScreenModelSheetTests}; Budgets/{BudgetEditorModelHarness (helper), BudgetEditorModelStateTests, BudgetEditorModelPickerTests, BudgetEditorModelSaveTests, DuplicateBudgetModelTests, BudgetViewScanRules and BudgetViewScanSources (helpers), BudgetViewScanRuleTests, BudgetViewScanTests}. No existing test was edited or deleted (nothing asserted the placeholder).

## Test arithmetic (app suite)
Previous total 3703 + new 167 - deleted or rewritten 0 = 3870 (verify.sh: 3870 passed, 0 failed, 0 skipped). New entries (a parameterized test counts as one; verified with grep -c "@Test" per file, with one grep hit in BudgetViewScanRuleTests being a comment line, so 19 real tests there): StatsScreenModelLoad 23, StaleBanner 10, Delete 13, Sheet 15 = 61; BudgetEditorModelState 25, Picker 10, Save 19 = 54; DuplicateBudgetModel 12; BudgetViewScanRule 19; BudgetViewScan 21. 61 + 54 + 12 + 19 + 21 = 167. Package suite 212, release script tests 92, destination script tests 17: unchanged.

## Verification (commands run)
Before commit, scripts/verify.sh summary lines:
```
--- tests: 3870 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.019 seconds.` The implementer's scripts/build.sh ended `** BUILD SUCCEEDED **` (command output reported by the implementer; re-confirmed by the full verify run above). The after-commit output for this commit is recorded in the Story D report.

## Gate 2
Convention-reviewer: APPROVED, no hard blocks, from reading every production file. Evidence: tokens only (no raw color, numeric spacing/padding/frame, `.font(.system`, foregroundColor or cornerRadius(); card radius is `.rect(cornerRadius: AppSpacing.md)` at StatsSummaryCardView.swift:70); 44-point targets use `InlineErrorBannerState.minimumButtonHeight`; destructive items: BudgetCardMenu.swift:29-34 (`role: .destructive` with `Color.destructiveColor`), dialog button :50-53, remove-person button BudgetEditorView.swift:255; errors only through InlineErrorBanner (StatsView.swift:58 and :89, BudgetCardView.swift:31, BudgetEditorView.swift:29 and :112, DuplicateBudgetView.swift:28); no accessibilityIdentifier at all; no logging, Sentry or print in the new files; no Combine/GCD, no force unwraps, no @unchecked or nonisolated(unsafe).
Warnings (no routing needed): (1) the editor's summary-error line and the amount hint text are validation hints rendered as `Text` (BudgetEditorView.swift:92-97 and :270-277), not load or mutation errors (the summary line and its error styling are required by the brief); (2) the sheet models are built inside the `.sheet(item:)` content closure (StatsView.swift:102 and :108); (3) `currencyCode: "USD"` is hard-coded in buildModelOnce (StatsView.swift:45); (4) optional accessibilityHint on the menu and year picker.
Acceptance-reviewer: APPROVED. Focus answers with evidence: (4) over-budget text: BudgetCardView.swift:22-25 and :75-78 render `statusText` ("Over by ..." produced at BudgetCardState.swift:74-77) with the destructive token as extra styling; the progress bar has label "Budget progress" and value "Spent <amount> of <total>" (BudgetCardView.swift:26-29; BudgetCardState.swift:98); each person row is one combined element whose label contains the status text (BudgetCardView.swift:81-82); the editor over-total text is BudgetEditorView.swift:92-96. (5) create/edit/duplicate/delete update from returned data: StatsScreenModel.swift:258-276 (`finishSheet` closes the sheet, selects the returned budget's year, forces `statsService.refresh`); delete StatsScreenModel.swift:182-199 (404 swallowed by BudgetService, hasPurchases lands in `budgetCardBanner` at :191 and the budget stays, banner rendered on the card BudgetCardView.swift:30-35, cancellation sets nothing at :188). (6) the confirmationDialog is attached to the card's `Menu` (BudgetCardMenu.swift:45-57; the file contains no List, ScrollView, Form or NavigationStack), bound to `$model.isShowingDeleteConfirmation` (:47), state owned by StatsScreenModel.swift:65 above every row; strings at StatsScreenModel.swift:43-49. (7) mutation errors live only in `BudgetEditorModel.banner` (:50, :216), `DuplicateBudgetModel.banner` (:27, :59) and `budgetCardBanner`; the stats load error is `statsService.loadFailure` plus the model-private `budgetListFailure` (cleared at :150-155); stale banner :131-134 and full error state StatsView.swift:87-90. (2)/(10) session safety: all writes go through the generation-checked services; the models hold no cache. Locale: edit text formatted with the same locale as the parser (BudgetEditorModel.swift:235-240). Double submit blocked by `isSaving` set before the await (:199-202).
Rejections: none. Stuck-detector: none (green on the first attempt). Test-writer spec gap (the ListService argument of StatsScreenModel) was caught before the implementer started and fixed in the spec.

## Deviations, accepted notes, and findings (not reworked)
- Accepted deviation (finding E): the editor's person picker loads the lists through `ListService.loadLists()`, which writes the shared `ListService.error` property, so a list failure triggered from the editor can also show on the Lists screen. The brief mandates loading through the ListService; no list code was changed.
- A: when the stats response has a budget block but the budget cache lacks that year (the budget list load failed), the card shows but Edit Budget and Duplicate do nothing (StatsScreenModel.swift:212-219, BudgetCardMenu.swift:19-28). Edge case; not fixed.
- B: after a successful delete, if the follow-up stats refresh fails, the cached stats still contain the budget block and the card keeps showing it, with the stale banner disclosing the failed update (StatsScreenModel.swift:197-198). Not fixed.
- C: an onAppear load that finishes after onDisappear can set `statsService.loadFailure` while off-screen (cleared by the next load; the banner is shown only on screen); two concurrent loads for different years can show the old year's failure as a stale banner on the new year (display of data stays keyed by the selected year). Not fixed.
- D: if the editor opens while the lists are still loading, `ListService.loadLists()` returns at once (ListService.swift:131), so the picker shows "Nobody to add yet" (`.ready([])`) until a reload. Mitigation: normally the lists are loaded by the Dashboard first. Not fixed. Brian's real-mode check step 2 and 11 would show it if it happens.
- F: edit-mode total text uses the locale's digits; a locale with non-ASCII digits would be rejected by the ASCII-only parser. Not a risk for a USD family app. G: create-mode spend recipients come from the selected year's stats, not from the year picked in the editor (cosmetic).
- Sheet models are built inside the `.sheet(item:)` closure (wasteful, not a defect: the sheet keeps the first via State(initialValue:), `loadOptions()` runs from `.task` on the retained model).
- Currency is fixed to USD with `Locale.current`.

## Not done or partial
- No simulator run was possible: no booted simulator was driven in this session. NOT verified visually: card and sheet layouts, reflow at accessibility text sizes, light and dark rendering, the progress bar tint, the confirmationDialog presentation from the Menu button, VoiceOver order. The #Preview blocks are the implementer's own aid and were not rendered by anyone here. Brian's real-mode check (Story D) is the only proof of the on-screen behavior.
- accessibilityHint values were not added (optional).
- The findings A to D and G above are open and recorded in the handoff.
