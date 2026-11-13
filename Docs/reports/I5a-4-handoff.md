# I5a-4: Handoff and the real-mode check (docs only)

Commit subject: "I5a: add the package handoff note". Pipeline: docs only; no code, so no test-writer or implementer. Gate 2 ran both reviewers one after the other.

## Files
Added: Docs/handoffs/2026-11-13-ios-to-brian-i5a.md, Docs/reports/I5a-4-handoff.md. Changed: none. Deleted: none. No code, test, .pbxproj, contract, LocalPackages or synced Docs file changed.

## Test arithmetic
Previous total 3870 + new 0 - deleted or rewritten 0 = 3870 (app suite). Package 212, release scripts 92, destination scripts 17, all unchanged.

## Verification (commands run)
Before commit (scripts/verify.sh and the package suite) are the same as the after-commit run of the Story C commit, which was taken at the Story C commit with the tree clean apart from this docs work:
```
--- tests: 3870 passed, 0 failed, 0 skipped ---
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
Test run with 212 tests in 16 suites passed
```
A before-commit run with the two new files present and the after-commit run for this commit are given in the Orchestrator's final message (a report committed with the code cannot contain its own after-commit output).

## Gate 2
Convention-reviewer: APPROVED. File name pattern, required sections (contract issues, what changed, API team, section 9 line), commit hashes and subjects against `git log --oneline master..HEAD`, test totals consistent with reports 1 to 3, no secrets or real paths, no change outside Docs. The "Brian's real-mode check" section: the restart note and steps (1) to (14) are byte-identical to the prompt's Story D text (restart note 194 bytes, steps 3994 bytes, `diff` empty). Non-blocking notes: the report I5a-4 did not yet exist when reviewed (written now), "4 commits" wording made consistent ("4 commits plus this handoff commit").
Acceptance-reviewer: APPROVED. Focus items: (12) the real-mode check matches the Story D text character for character and the not-performed statement is explicit and honest (handoff lines 42-46). The reviewer checked each step against the built code: steps (2), (3), (7), (8), (11), (12) hold (for example BudgetRecipientOptions.swift:23-27 excludes John's own list because it has canPurchase false in the seed, which the reviewer could not check; the invalidation hook and pull to refresh at StatsScreenModel.swift:158-159 and :282-283; duplicateYears excludes years with a budget at BudgetYearChoices.swift:31-33; the empty picker text "Nobody to add yet" at BudgetEditorView.swift:121). ONE STEP CANNOT BE SATISFIED AS WRITTEN: step (1) says a fresh John sees a "No budget for <year>" card; the code (StatsScreenState.swift:70, :84-86; StatsView.swift:133-135, :145-150) shows the explanation card "Nothing spent in <year> yet. Create a budget to plan your spending." with the Create Budget button for a year with no purchases and no budget, and the "No budget for <year>" card only when the year has purchases but no budget. This follows the brief's own Decisions (which are internally inconsistent with the step text). The check text was kept verbatim; the difference is recorded in the handoff section "Known wording difference in step (1)". (13) nothing under contract/, the agent config directory, any .pbxproj, the synced Docs files or LocalPackages/ changed; the only purchase production files changed are PurchaseRefreshPlan, PurchaseRefreshRunner, ItemDetailView and ManagePurchaseView (declared in the Story B report and the handoff).
Rejections: none. Stuck-detector: none.

## Deviations and findings
- Step (1) wording difference above (a disagreement between the brief's Decisions and its real-mode text; not changed in code).
- The after-commit run for this commit appears only in the final message (a report cannot contain the output of a run that happens after it is committed).

## Not done or partial
- Brian's real-mode check was NOT PERFORMED: none of steps (1) to (14) was run. No backend was started, no simulator was driven, no screenshot was taken. The session has no network or database access by rule and no booted simulator. Brian's run is the only proof of the on-screen behavior of the whole package (layout, Dynamic Type reflow, light and dark, the confirmation dialog presentation, VoiceOver order).
- The reviewer findings A to G of the Story C report are open (listed in the handoff).
- PROGRAM.md was not edited (Brian updates section 9 from the handoff line).
