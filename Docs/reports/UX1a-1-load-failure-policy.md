# UX1a-1: The pure load failure policy

Commit subject: "UX1a: add the pure load failure policy".
Pipeline: full (isolated test-writer, implementer, convention-reviewer, then acceptance-reviewer, strictly one after the other). The swiftui-expert-skill was not needed: this story has no view code.

## Baseline for this story (after-commit run of the epic commit ede6a10; also the P2 baseline of the package)
Command run: `scripts/verify.sh` (summary lines) and `swift test --package-path "LocalPackages/TrackerAPI"`.
```
--- tests: 3870 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.020 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
The P2 baseline matched the expected totals (3870, 212, 92, 17); no new baseline was needed.

## Files
Added production (ChristmasTracker/ChristmasTracker/Features/Shared/ErrorPolicy/; the Shared folder is new):
- LoadFailureCategory.swift: `LoadFailureCategory` (eight categories, CaseIterable, `isConnectivity`), `LoadSource`.
- LoadFailure.swift: `LoadFailure` and the four classifying initializers for ListError, ItemError, ChildError and BudgetError (exhaustive switches, no `default`; `plainMessage` copied from `userMessage`; `retryAfter` nil when not finite or below 1, rounded up, capped at 3600).
- LoadFailurePolicy.swift: `LoadBanner`, `LoadFailureOutcome`, `LoadFailurePolicy.outcome(hasCachedData:failures:)` and `staleDataText`.
Added tests (ChristmasTrackerTests/Features/Shared/ErrorPolicy/): LoadFailureFixtures (helper), LoadFailurePolicyTruthTableTests, LoadFailurePolicyMergeTests, LoadFailureClassificationTests, LoadFailureTextTests.
Changed: Docs/epics/UX1a-errors-and-stale-data.md (the Gate 1 "Exact definitions" amendment, written before the test-writer started; it adds `plainMessage` and `LoadBanner`, the evaluation order and the tie-break).
Deleted: none. No existing production or test file was edited.

## Test arithmetic (app suite)
Previous total 3870 + new 55 - deleted or rewritten 0 = 3925 (verify.sh: 3925 passed, 0 failed, 0 skipped). New entries (grep -c "@Test" per file; a parameterized test counts as one): TruthTable 11, Merge 19, Classification 16, Text 9 = 55. (The test-writer reported 15 for Classification; the grep count of 16 is the one that reconciles with the runner's total.) Package suite 212, release script tests 92, destination script tests 17: unchanged.

## Verification (commands run)
Before commit, run by the Orchestrator, `scripts/verify.sh` (summary lines):
```
--- tests: 3925 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.023 seconds.
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
Package suite: the package run inside verify.sh above is `swift test --package-path "LocalPackages/TrackerAPI"` (212 tests passed). The after-commit output for this commit is recorded in the Story U2 report (the after-commit run of the U2 baseline).
These came from running the commands. The mapping completeness and the rule order came from reading the code (both reviewers).

## Stuck-detector log
Attempt 1: build passed, 3924 passed and 1 failed (`rateLimitedRetryAfterIsNilWhenNotUsable`: 0.5 and 0.999 gave `retryAfter` 1 because the value was rounded up before the `< 1` check). Fix: check the raw value is at least 1 before rounding. Attempt 2: green. A repeated error signature never occurred.

## Gate 2
Convention-reviewer: APPROVED. No hard blocks. Evidence: no Combine or `DispatchQueue`, no force unwraps or `as!`, no commented-out code, no `default:` in any production switch (the only grep hit is a comment in LoadFailureFixtures.swift:44), all types `nonisolated`/`Sendable`, files 45 to 118 lines, no logging at all, fixtures use fake text only. Warnings (not blocking, not reworked): four lines over 120 characters in tests (LoadFailureTextTests.swift:26 and :65, LoadFailurePolicyMergeTests.swift:200 and :207, all under the 160 limit); a needless `throws` at LoadFailureTextTests.swift:23; an unreachable fallback to the stale text at LoadFailurePolicy.swift:71 for an empty group.
Acceptance-reviewer: APPROVED, from reading the code, not from running it. Focus answers: (1) evaluation order at LoadFailurePolicy.swift:37 (none), :38 (sessionEnded), :39 (notFound), priority groups :32-34 and :57-62, message :69-73, one group :75-80, two groups :82-91; (2) forbidden is not connectivity (LoadFailureCategory.swift:29) so it never reaches the stale text, and notFound returns at :39; (3) classifier mapping complete for 15 ListError, 11 ItemError, 10 ChildError and 12 BudgetError cases, LoadFailure.swift:28-103; (4) retryAfter at LoadFailure.swift:114-117, pinned by ClassificationTests:121-137; (5) each rule has a test that a plausible wrong implementation fails (MergeTests:175-184, TruthTable:56-60, MergeTests:100-113 and others).
Rejections: none. No re-review was needed.

## Deviations and decisions
- The classifiers are in LoadFailure.swift and `LoadSource` in LoadFailureCategory.swift, a slightly different file split than the Gate 1 listing; the tests sit one folder deeper (`Features/Shared/ErrorPolicy/`). Harmless.
- `isConnectivity` on the category is a helper the spec did not list.
- Decision recorded (reviewer item f, test-writer ambiguity 4): two different connectivity categories with cached data (for example unreachable and server) yield TWO banners with the identical text "Couldn't update. Showing saved data." and different retry targets. This follows the brief literally ("one banner per distinct category"). Only unreachable and server can occur together today, because no typed error produces `timeout`. If Brian prefers one banner there, it is a small change in the policy (collapse same-text banners) and belongs in a later amendment.
- Open points the reviewer raised for U2 and U3, accepted into those Gate 1 specs: (a) the policy has no dismissal concept, so the caller removes dismissed failures before calling (an empty list gives `none`); (b) `hasCachedData` is one Bool per screen, and on the list detail screen it means "the detail is shown"; (c) a thin mapping from `LoadBanner` to `InlineErrorBannerState` is needed in U3, with the fallback message for an empty text; (d) the stats year filtering for finding C happens before the call; (e) the existing list-detail behavior for 403 on a cached detail (the service drops the list) is kept; (f) the create-list child-recipient load uses `LoadSource.children`.
- An empty `plainMessage` is not handled or tested in the policy (the typed errors already fall back to a default text); the U3 mapping carries the fallback.

## Not done or partial
- No simulator run was possible and none was needed for this pure story; Brian's real-mode check is the only proof of on-screen behavior, and it does not exercise this story directly.
- Nothing from the story's scope is partial. Optional hardening suggested by the reviewers (an independent mapping table in the tests, an empty-message test, the three convention warnings) was not done.
