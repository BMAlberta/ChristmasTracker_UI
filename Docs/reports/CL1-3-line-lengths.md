# CL1 story C3: line lengths

Method: the lines VER1, PH1 and IMG1 added (commits 17b8efc^..3654b03) were found with
`git diff -U0 17b8efc^ HEAD -- <scoped folders> | grep -E "^(\+\+\+ |\+[^+].{120,})"` (HEAD differs from 3654b03 only by the
CL1 commits, which add no long lines), then matched to their line numbers at HEAD with
`grep -rnE --include="*.swift" ".{121,}" <folder>`. Long lines at HEAD that are not in that diff are pre-existing from
other packages and were not touched.

## Hit list (before)

Production code (HEAD line numbers, before any edit):

| File | Line | Package |
|------|------|---------|
| ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift | 131 | VER1 |
| ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift | 394 | IMG1 |
| ChristmasTracker/ChristmasTracker/Core/API/VersionService.swift | 47 | VER1 |
| ChristmasTracker/ChristmasTracker/Features/Version/UpdatePresentation.swift | 12 | VER1 |
| ChristmasTracker/ChristmasTracker/Features/Version/Views/UpdateRequiredView.swift | 115, 130 | VER1 |
| ChristmasTracker/ChristmasTracker/Features/PurchaseHistory/Repositories/MockPurchaseHistoryRepository.swift | 78 | PH1 |
| ChristmasTracker/ChristmasTracker/Features/PurchaseHistory/ViewState/PurchaseHistoryRowPresentation.swift | 32 | PH1 |
| ChristmasTracker/ChristmasTracker/Features/PurchaseHistory/Views/PurchaseHistoryFilterBar.swift | 63 | PH1 |

Tests (under ChristmasTracker/ChristmasTrackerTests/):

| File | Lines | Package |
|------|-------|---------|
| App/BudgetCompositionTests.swift | 223, 229, 232 | PH1 |
| Features/Version/UpdatePresentationTests.swift | 21, 98, 100, 115, 151 | VER1 |
| Features/Version/UpdateViewsSourceScanTests.swift | 66 | VER1 |
| Features/Items/ItemAddImageModelTests.swift | 61 | IMG1 |
| Features/Items/ItemAddImageRequestTests.swift | 29, 214, 225 | IMG1 |
| Features/Items/ItemAddImageSourceScanTests.swift | 123, 128 | IMG1 |
| Features/Items/ItemAddImageVisibilityTests.swift | 25 | IMG1 |
| Features/Items/ItemImageFillSourceScanTests.swift | 113, 114, 124 | IMG1 |
| Features/Items/ItemImageFillStateTests.swift | 192 | IMG1 |
| Features/Items/ItemInputBuildingTests.swift | 164 | IMG1 |
| Features/Items/ItemUpdateInputClearingTests.swift | 24, 50, 74 | IMG1 |
| Features/PurchaseHistory/PurchaseHistoryFilterTests.swift | 66 | PH1 |
| Features/PurchaseHistory/PurchaseHistoryQueryTests.swift | 51, 76 | PH1 |
| Features/PurchaseHistory/PurchaseHistorySUT.swift | 35, 40 | PH1 |
| Features/PurchaseHistory/GeneratedClientPurchaseHistoryErrorTests.swift | 115, 133, 250, 260 | PH1 |
| Features/PurchaseHistory/GeneratedClientPurchaseHistoryResponseTests.swift | 107, 128, 152, 162, 190 | PH1 |
| Features/PurchaseHistory/PurchaseHistoryCompositionTests.swift | 44, 63, 86, 105, 186 | PH1 |
| Features/PurchaseHistory/PurchaseHistorySourceScanTests.swift | 22, 60, 105, 143, 145, 155, 167 | PH1 |
| Features/PurchaseHistory/MockPurchaseHistoryRepositoryTests.swift | 253 | PH1 |
| Features/PurchaseHistory/PurchaseHistoryServiceHarness.swift | 52, 55 | PH1 |
| Features/PurchaseHistory/Model/PurchaseHistoryModelSourceScanTests.swift | 42, 46, 73 | PH1 |
| Features/PurchaseHistory/Screen/PurchaseHistoryViewScanTests.swift | 108 | PH1 |

| LinkPreview/LinkPreviewSourceScanTests.swift | 114 | IMG1 |
| LinkPreview/LinkPreviewWiringTests.swift | 38, 41 | IMG1 |
| LinkPreview/LinkPreviewServiceRateLimitFallbackTests.swift | 38 | IMG1 |

Total in scope: 70 lines (9 production, 61 test). Outside the listed folders: 1 line (see "Deviations"), not touched.

## What changed

64 of the 70 in-scope added lines were rewrapped (whitespace and line breaks only: after commas, before operators,
one argument per line, `@Test` arguments moved to their own line, a long `//` comment split in two). 31 `.swift` files
changed (6 production, 25 test files; see `git diff --stat`). No renames, no token changes, no logic edits, no
new locals. Includes `ChristmasTrackerApp.swift` (lines 131 and 394), as asked, with no logic change.

## Remaining and why

Lines over 120 characters that VER1, PH1 and IMG1 added and that stay, because wrapping them would alter a string or
regex literal token:

- `Features/Version/UpdatePresentation.swift:12`: user-facing sentence string literal.
- `ChristmasTrackerTests/App/BudgetCompositionTests.swift:223`: `@Test("...")` display name.
- `ChristmasTrackerTests/Features/Version/UpdateViewsSourceScanTests.swift:66`: `#expect` message string literal
  (the call is wrapped; the literal line stays over 120).
- `ChristmasTrackerTests/Features/Items/ItemAddImageSourceScanTests.swift:123`: raw-string regex.
- `ChristmasTrackerTests/Features/Items/ItemImageFillSourceScanTests.swift:113`: raw-string regex.
- `ChristmasTrackerTests/Features/PurchaseHistory/PurchaseHistorySourceScanTests.swift:22`: raw-string regex.

That is 6 lines in scope. The 7th remaining added line is outside the scoped folders (next section).

## Commands and raw output

Hit list: `git diff -U0 17b8efc^ HEAD -- <scoped folders> | grep -E "^(\+\+\+ |\+[^+].{120,})"`, then
`grep -rnE --include="*.swift" ".{121,}" <folder>` for line numbers. Total added over 120 characters, whole repo:

```
git diff -U0 17b8efc^ 3654b03 -- ChristmasTracker | grep -cE "^\+[^+].{120,}"
71
```

After the rewrap, the same diff against the working tree (`git diff -U0 17b8efc^ -- ChristmasTracker | grep -E "^\+[^+].{120,}"`)
lists 7 lines: the 6 above plus `ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift`
(out of scope).

scripts/verify.sh summary lines:

```
--- tests: 5331 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.018 seconds.   (TrackerAPI package tests)
=== verify: OK ===
```

## Deviations

- The brief listed test folders `Features/LinkPreview`; the IMG1 link preview tests live in
  `ChristmasTrackerTests/LinkPreview/` (no `Features/LinkPreview` test folder exists). The 4 added long lines there
  were wrapped too.
- 1 added long line is outside the listed folders and was not touched:
  `ChristmasTrackerTests/Features/Authentication/InactivityLockIntegrationTests.swift` (a string-literal message line
  added by PH1).
- Attribution used the net diff `17b8efc^..HEAD` rather than per-line `git blame`; the CL1 commits since 3654b03 add no
  long lines, and the whole-repo count matches the brief's 71.
- Line numbers in the hit list are HEAD numbers before any edit.

## Not done or partial

- The 6 in-scope lines listed under "Remaining and why" are still over 120 characters by design (string and regex
  literals, rule: no token changes).
- The 1 Authentication test line outside the scope is still long.
- Pre-existing long lines from other packages (for example in `ItemMapping.swift`, `ItemDetailView.swift`,
  `Features/Statistics` tests, `App` tests) are untouched by instruction.
- Nothing committed or pushed.
