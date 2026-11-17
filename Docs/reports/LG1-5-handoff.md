# LG1-5: package handoff

## What changed
- Added `Docs/handoffs/2026-11-17-ios-to-brian-lg1.md` (contract issues, commits, counts, edited tests, instrumentation list, creation-point lines, risks, PROGRAM.md line, Brian's real-mode check).
- No code changed in this story.

## Commands and raw output
Final `scripts/verify.sh` (on the tree of commit `f7712f1`, run 2026-11-17):
```
** BUILD SUCCEEDED **
--- tests: 5598 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
```
Baseline before the package: 5410 passed (app), 212 passed (package).

Package-end diff: see the section "Package-end diff (taken after the final docs commit)" at the end of this file.

## Deviations
- The agents never saw the simulator or the network. None of the seven real-mode checks were PERFORMED; they are Brian's.
- The implementer wrote production code before tests in L1 (disclosed in `LG1-1-performance.md`); L2 and L3 batch D went through an isolated test-writer.
- A permission rule blocked one test filename (`LoggingTransportSecretTests.swift`); with Brian's approval the same tests live in `LoggingTransportLeakTests.swift`.

## Not done or partial
- The lists pull-to-refresh problem is not fixed (by design; separate package).
- Real-mode and Release checks (see the handoff) were not performed.
- File splits for `ListService.swift`, `AuthenticationService.swift`, `ItemService.swift` (already over the limit) were out of scope.
- `AsyncImage` thumbnails and `LPMetadataProvider` requests bypass the logging transport.

## Package-end diff (taken after the final docs commit)
`git diff --stat main...HEAD` taken 2026-11-17 after commit `2a4a7f1` (the handoff commit): 57 files changed, 6501 insertions, 1121 deletions. The changed paths are only: the app target (`ChristmasTrackerApp.swift` +2/-1 for the one `transport:` argument, the new `Core/API/` and `Core/Logging/` files, the ten services, and the small `reason:` call-site edits in DashboardView, ListDetailView, PurchaseHistoryView, PurchaseHistoryModel and StatsScreenModel), the new and edited tests under `ChristmasTrackerTests/`, `Docs/epics/LG1-client-logging.md`, `Docs/handoffs/2026-11-17-ios-to-brian-lg1.md` and `Docs/reports/LG1-*.md`. Nothing under `contract/`, `.claude/`, `LocalPackages/`, any `.pbxproj`, or the synced Docs (`client-guide.md`, `error-codes.md`, `privacy-matrix.md`, `PRD.md`, `DECISIONS.md`). The stat is re-run after this note's own commit; this file is the only difference.
