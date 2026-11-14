# UX1b Story B7: Handoff and the real-mode check (docs only)

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full for a docs story (the convention-reviewer and acceptance-reviewer both read the handoff against the brief and the code). No code changed.

## What was written
- Docs/handoffs/2026-11-14-ios-to-brian-ux1b.md per CLAUDE.md "Package end": contract issues (none), what changed (stories B0 to B6), the commit list (`git log --oneline master..HEAD`, ten commits), what the API team must do (nothing), open risks and banked items, the one line for section 9 of PROGRAM.md, and "Brian's real-mode check" as a numbered list with bold titles, nested bullets and an Expect bullet for each result, with the required restart note at the top.
- The fixed steps 1 and 3 to 9 are copied from the prompt file word for word (step 6 as Brian updated it: the caption stays below Sign In after the alert is dismissed). Step 2 expands to one sub-step per inventory dialog (2.1 to 2.11), each with the account and the tap path taken from the code, plus 2.12 naming the alerts that are not confirmations. Step 10 ("Confirming works, not only cancelling") was added by the build session, not in the brief, because the confirm-button ordering risk (see UX1b-1-dialogs.md) is the thing only the real app can prove; the handoff says so.
- NOT PERFORMED statements: the whole check (no backend, simulator or screenshot in the session), the second dialog of step 7 and step 8 (not reproducible by hand, covered by unit tests, which are named).

## Gate 2
- convention-reviewer: APPROVE (docs only, nothing under .claude/.pbxproj/contract/LocalPackages/synced Docs; format, top note, numbered list and secrets checks passed). Two points taken: steps 4 and 5 had small additions to the brief's wording; they were restored to verbatim and the additions moved to a "Notes on the steps above" section; the UX1b-6 report lacked an after-commit line for 8675501, now added.
- acceptance-reviewer: REJECT once, then APPROVE on re-review. The rejection was against the handoff text, not the code (routing: the Orchestrator owns the handoff): (1) sub-step 2.11 (over-purchase prompt) was wrong: the only over-purchase dialog (RecordPurchaseRecordSection.swift:31) opens from `RecordPurchaseFormState.prompt(quantity:remaining:)` when the quantity is above the remaining quantity, not from the cost; fixed to the quantity trigger and marked NOT verified, with a fallback; (2) the tap paths said "Lists tab" and "Statistics tab" but the tabs are "Dashboard", "Stats" and "Profile" (fixed in the sub-steps; the brief's fixed steps keep its own wording); (3) the shared Expect line for 2.1 to 2.10 is now disclosed; (4) two banked items from the reports were missing from the open risks (a stale keyed detail failure for a list the user left; an edit during an in-flight sign-in followed by the hint) and were added. The reviewer verified tap paths 2.1 to 2.10 against the views (file:line), the seed accounts against the backend's Docs/local-development.md (no password copied), the commit list, and the test arithmetic 4230 -> 4250 -> 4305 -> 4340 -> 4345 -> 4368 -> 4398.
- Stuck detector: none.

## Test arithmetic (app suite)
4398 + 0 = 4398 (docs only). Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Before the commit (with the handoff and reports in the tree):
```
--- tests: 4398 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After the commit: recorded in the Orchestrator's final message (the commit cannot contain its own result); the package-end diff is recorded there too.

## Verification sources
Counts and OK lines from running commands; tap paths, seed facts and arithmetic from the reviewers reading code and docs. No simulator run.

## Deviations
Step 10 added to the real-mode check beyond the brief (disclosed in the handoff). Step 2's Expect line is written once for 2.1 to 2.10 instead of once per sub-step (disclosed).

## Not done or partial
- Brian's real-mode check was NOT PERFORMED, and sub-step 2.11 cannot be reached with certainty from the seed (no seeded item is known to allow quantity above the remaining quantity). No simulator run was possible: the on-screen behavior of every UX1b change (dialog anchoring and staying open, confirming working, red colors, the swipe tint, the tab bar shrinking, the Face ID caption) is proven only by that check.
- The package-end diff and the final commit list are in the final message.
