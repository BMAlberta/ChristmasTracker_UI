# CL1-4 — Split the app composition file: STOPPED

Status: **stopped by the story's own stop rule. No code changed, nothing to revert.**

## What happened
The implementer measured `ChristmasTracker/ChristmasTrackerApp.swift` (551 lines now; 548 in the brief, plus 3 from the C3 wraps) and could not reach 400 lines with a pure move without editing more than 4 scan tests, which the brief says is a stop condition.

Groups in the file:
- `LockCoordinator` (private class), about 68 lines.
- `AppDependencies` (struct with `makeMock`, `makeReal`, `makeInert`, `resolve`), about 118 lines.
- `buildGeneratedClient`, about 32 lines.
- `ChristmasTrackerApp` with a ~200 line `init`, `body` and `appContent`.

Moving `LockCoordinator`, `buildGeneratedClient` and `AppDependencies.resolve` removes only about 125 lines (to about 425). The `init` body cannot move without becoming new helper functions, which is not a pure move. Reaching 400 therefore needs `AppDependencies` (`makeMock`/`makeReal`/`makeInert`) moved too.

Scan tests that read `ChristmasTrackerApp.swift` and slice out the `func makeMock` / `makeReal` / `makeInert` bodies, which would need edits if `AppDependencies` moves (found by `grep -rlE "ChristmasTrackerApp\.swift|func makeMock"` over the tests):
- `App/BootstrapSourceScanTests.swift` (4 tests)
- `App/BudgetCompositionTests.swift` (3 tests via `appSource()`)
- `App/PurchaseCompositionTests.swift`
- `App/PurchaseManagementCompositionTests.swift`
- `Features/PurchaseHistory/PurchaseHistoryCompositionTests.swift`
Other tests read only the `init`/`body` text, which stays: `UpdateWiringScanTests`, `ThumbnailSourceScanTests`, `ButtonChromeScanTests`, `DeletedLegacyNamesScanTests`.
At least 5 files (more than 10 tests) would change, and some also check `init` text, so a helper that reads two files would change what they prove. Also, `LockCoordinator` is `private`; moving it needs `internal`, which breaks "same access levels".

## Commands and raw output
- `git status --short` after the attempt: empty (no changes).
- `wc -l ChristmasTracker/ChristmasTrackerApp.swift`: `551`.
- No `scripts/verify.sh` run for this story (no change); the last run, after C3, was 5331 app tests passed, 212 package tests passed, `verify: OK`.

## Deviations
- The story was not delivered. No new files, no `EDITED` tests.

## Not done or partial
- The whole split. `ChristmasTrackerApp.swift` stays at 551 lines: over the 400 warning, under the 600 error limit.

## Options for Brian (a decision, not taken here)
1. Allow about 5 scan-test files to be edited (their `appSource()` helpers read the new file too), then move `AppDependencies`, `LockCoordinator` (made internal) and `buildGeneratedClient`; the app file would be about 330 lines.
2. Small pure move only: `LockCoordinator` and `buildGeneratedClient`; the file would be about 450 lines, still over 400.
3. Allow a non-pure refactor of the `init` (for example moving the lock-observer registration into a helper).
