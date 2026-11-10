# I3b-2 R3: the screen
Date: 2026-11-10. Branch: feat/i3b-members-children. Weight: full pipeline (capability-flag-driven UI). Gate 1 spec in the epic brief, isolated test-writer, isolated implementer, convention-reviewer, acceptance-reviewer, one rejection fixed and re-reviewed. All strictly sequential.

## What changed
Production:
- `Features/Lists/ViewState/CoOwnerViewState.swift`: `CoOwnerSectionState.clearingSupported` removed; `showsRemove = canSetCoOwner && coOwner != nil`; `showsChange = canSetCoOwner`. New nonisolated pure types `CoOwnerRemoveConfirmation` (texts), `CoOwnerRemoval` (`presentation(for:)`, `canRemove(isMutating:isSaving:)`), `EditListDetailSource.resolve(snapshot:live:)`, and (after the rejection) `EditFailedAction` and `EditRetry.action(after:)`.
- `Features/Lists/Views/EditListView.swift`: the co-owner section reads the resolved live detail; the dead `removesCoOwner` state, its toggle and the `.disabled(removesCoOwner)` are deleted; a destructive "Remove co-owner" button (44-point target, accessibility label and hint, identifier `editList.removeCoOwnerButton`) opens a `confirmationDialog`; on confirm it calls `listService.removeCoOwner(listId:)`; the sheet stays open on success and the section re-renders from the service's returned detail; failures show the existing `ListErrorBanner` through `CoOwnerRemoval.presentation(for:)`; notFound and archivedReadOnly dismiss the sheet through `ListScreenExit.shouldDismissEdit(for:)`; cancellation shows nothing; "Try Again" re-runs the action that failed (`failedAction`). Save and the rest of the screen are unchanged.

Tests: new `CoOwnerRemoveViewStateTests.swift`; changed `CoOwnerSectionStateTests.swift`, `MembersTruthTableTests.swift`, `MembersSourceScanTests.swift`, `MembersChildrenViewScanTests.swift`. Brief: Gate 1 spec for R3. Files deleted: none.

## Commands and raw output (commands ran)
Before the R3 commit, `scripts/verify.sh` summary lines:
```
=== verify: unit tests ===
--- tests: 1497 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
Before the R3 commit, `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed after 0.019 seconds.`
The state before R3 (the R2 commit, aedc89d) is the R2 report's "before" run: 1464 app tests, 212 package tests, verify OK. The "after R3 commit" run is the R4 report's "before" run, because R3's commit changes no file after the runs above except this report.
Red states (reported by the test-writers, who ran `scripts/test.sh`): both times the test target did not compile; only the missing symbols were reported. Implementer: green on the first attempt in both rounds.

## Test arithmetic (by test function, as `scripts/verify.sh` counts)
Previous total 1464. Round 1: +27 (CoOwnerSectionStateTests +3 net, MembersTruthTableTests 0, MembersSourceScanTests +2, MembersChildrenViewScanTests +6, new CoOwnerRemoveViewStateTests +16) = 1491. Round 2 (the rejection fix): +6 (4 `EditRetry` tests in `CoOwnerRemoveViewStateTests`, 2 scans in `MembersChildrenViewScanTests`) = 1497. So 1464 + 33 new - 0 net deleted = 1497, matching the raw count. The acceptance-reviewer counted the `@Test` functions from the files against HEAD for round 1 (1464 + 27 = 1491) and confirmed +6 for round 2; its absolute counts for CoOwnerSectionStateTests (8 -> 11) are one higher than the test-writer's (7 -> 10) but the net is the same.
- Deleted (1), exclusively asserted the removed constant: `CoOwnerSectionStateTests.clearingNotSupported`.
- Rewritten (4), each asserted "Remove is never shown": `removeNeverShowsToday` (now `removeFollowsFlagAndCoOwner`), `removeFormula` (now `canSetCoOwner && coOwner != nil`), `MembersTruthTableTests.exhaustiveTruthTable` and `personaOutcome` (the self-list owner persona with a co-owner now expects `showsRemove: true`).
- New in `CoOwnerSectionStateTests`: `removeShowsForOwnerWithCoOwner`, `otherFlagsDoNotTurnRemoveOn` (16 flag combinations), `roleIsNotRead` (4 `myRole` values), `personaOutcome` (8 personas: owner with co-owner, owner without, co-owner, blind co-owner, MEMBER-role member, VIEWER-role member, PUBLIC non-member, archived list).
- New in `CoOwnerRemoveViewStateTests` (20 `@Test` functions): round 1 has 16 (4 confirmation texts, 7 for `presentation(for:)` (the test-writer's summary said 6 but listed 7 names), 1 `canRemove` truth table, 4 for `EditListDetailSource.resolve`); round 2 adds 4 for `EditRetry`.
- New scans: `MembersChildrenViewScanTests` +6 (round 1: uses the remove operation, confirms with a dialog, reads no role, tokens and no logging, button accessibility, identifiers carry no personal data) +2 (round 2: Try Again is not hard-wired to Save, operations record their failed action); `MembersSourceScanTests` +2 (new state types are clean, `clearingSupported` is gone).
Package suite: 212 + 0 - 0 = 212.

## Gate 2 (real verdicts, written after the reviews)
- Round 1 convention-reviewer: APPROVE (tokens, no force unwraps, no Combine/GCD/logging in views, 44-point target, identifiers without personal data, scope fence respected).
- Round 1 acceptance-reviewer: REJECT, routed to the implementer (with the test-writer first). Defect: `EditListView.swift:88` `onRetry: { Task { await saveChanges() } }`; after a failed removal (network, server, rateLimited, invalidResponse are retryable), "Try Again" re-ran Save, not the removal: silently nothing without edits, or a PATCH with unrelated edits and a dismissed sheet. Everything else on the focus list passed: (5) `showsRemove = canSetCoOwner && coOwner != nil` and `showsChange = canSetCoOwner` (`CoOwnerViewState.swift:20-21`), no role read in the view-state or the view; (6) notFound and archivedReadOnly dismiss the sheet (`EditListView.swift` `removeCoOwner()` -> `ListScreenExit.shouldDismissEdit(for:)`) and the service's `dropListIfGone` sets `goneListId`, which `ListDetailView.swift:108-111` observes; (4) the section updates from the returned detail through `EditListDetailSource.resolve` and the Save diff cannot send a co-owner change after a removal (`makeUpdateInput` compares name, theme and visibility only); (7) no logging, constant identifiers (the dialog shows the co-owner's display name on screen only); (9) the rest of the screen is unchanged; (10) no out-of-scope files.
- Rejection fix: the test-writer added 6 failing tests (red on the missing `EditRetry`/`EditFailedAction`), then the implementer added `EditFailedAction`, `EditRetry` and the `failedAction` state (green on the first attempt; 1491 -> 1497).
- Round 2 acceptance-reviewer (the same reviewer): APPROVE. Try Again re-runs the failed action in every path; no stale `failedAction` can run the wrong operation (both operations clear it on start, the banner dismissal clears it, a notFound/archived error dismisses the sheet, a cancellation sets nothing); the nil mapping to Save is harmless; `EditListView` re-diffed, nothing else changed; the scans would fail if `onRetry` were reverted. It noted the `EditRetry` unit tests are identity checks and weak alone; the scans carry the wiring check.
- Round 2 convention-reviewer: APPROVE. Two non-blocking observations: `EditRetry.action(after:)` is an identity function; the `removeButtonWindow` scan assumes the button is within 14 lines of its identifier, which is brittle if the layout changes.
- Both reviewers ran read-only and ran no builds or tests; the totals above come from my own `scripts/verify.sh` run.
- Stuck detector: not triggered (green on the first attempt in both rounds; one rejection).

## Deviations and findings
- Real bug found by the acceptance review and fixed in this story: Try Again after a failed removal ran Save (above).
- Choice by the implementer: the retry switch maps a nil action to Save, which equals the pre-change behavior; the banner only shows after an error has set `failedAction`.
- Cosmetic, left as is: the dialog title and message fall back to the literal "co-owner" while the dialog animates away after a successful removal (`EditListView.swift` around :133 and :142).
- Cancel stays enabled during a removal; acceptable per the acceptance review.

## Not done or partial
- No visual check: no booted simulator was running the app, so neither reviewer nor I took a screenshot; the screen has not been seen on a device or simulator.
- The view wiring is verified by source scans and pure view-state tests, not by an XCUITest or a running app.
- The real-mode check against a running backend (needs Brian; steps are in the combined handoff written in R4).
- Contract-issues row 2 is resolved in R4, not here.
