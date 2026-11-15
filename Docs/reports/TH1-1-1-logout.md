# TH1.1 Story A1: Logout

Branch `feat/th1-1-destructive-look`. Path: solo implementer, then convention-reviewer and acceptance-reviewer (both approved, no rejection routing).

## What changed

- `ChristmasTracker/ChristmasTracker/Features/Profile/Views/ProfileView.swift`, `LogoutButtonView` only:
  - The trigger is now `Button(role: .destructive)` with `.buttonStyle(.bordered)` and `.destructiveTint()`. It was `PrimaryButtonStyle`, with no role and no tint.
  - The trigger adds `.font(.appHeadline)` and uses `.frame(maxWidth: .infinity, minHeight: 44)`, the same as the Leave list button (MembersSectionView.swift:80-92). The icon (`rectangle.portrait.and.arrow.right`) and `.padding(.top, AppSpacing.md)` are unchanged.
  - The dialog button is now `Button("Logout", role: .destructive, action: onConfirm)` with `.destructiveTint()`.
  - The dialog is still attached to the trigger, and `showLogoutConfirmation` still lives in `ProfileView` above the rows. The same confirmation runs the same `authService.logout()`.
  - The Logout code had no accessibility label or identifier, and none was added or changed.
- `ChristmasTrackerTests/Features/Shared/DestructiveRealFilesTests.swift`:
  - Removed `signOutIsNeutral` and `logoutButtonViewIsNeutral`. They enforced the UX1b rule that Brian reversed on 2026-11-14.
  - Added `logoutTriggerIsDestructive` and `logoutDialogButtonIsDestructive`, which use `DestructiveScanner.buttonStatements`.
  - Updated the file header comment.
- `ChristmasTrackerTests/DesignSystem/ButtonChromeScanTests.swift`:
  - Removed `Features/Profile/Views/ProfileView.swift` from `primaryButtonFiles`. Logout was its only `PrimaryButtonStyle` use, so a stale entry would fail.
  - Added `logoutIsBorderedWithDestructiveTint`, modelled on `archiveListIsBorderedWithDestructiveTint`.
- `AppButtonKind.destructive` spec (criterion A1.3): not changed. The existing `DesignSystem/AppButtonStyleTests.swift` test `destructiveSpec` already asserts bordered, accent tint and `isDestructiveRole: true`, so no duplicate was added.

## Test arithmetic

Baseline app tests (scripts/test.sh before any change): 4622 passed. Removed 2, added 3, so 4622 - 2 + 3 = 4623. The run shows 4623. TrackerAPI package: 212 before and after.

## Commands and raw output

Baseline, before the story (Step 0):

```
--- tests: 4622 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: OK ===
```

After the change, before the commit (`scripts/verify.sh`, filtered to the summary lines):

```
--- tests: 4623 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.023 seconds.
=== verify: OK ===
```

Red before green: the first run of the new tests, before the production change, failed 2 (the old `Button { }` trigger was not a destructive Button). After the change, the first full run failed 2 (4621 passed) because the test's dialog-button finder was wrong. The scanner's chain starts at `("Logout"...`, not `Button(`. That was a test bug, fixed, and the second run was green. Two loop attempts, and the stuck detector never triggered.

## Deviations

- The UX1b rule "Sign out is neutral" is reversed on purpose, per Brian (2026-11-14). It is recorded in Docs/epics/TH1-1-destructive-look.md.
- The convention-reviewer warned about the bare `minHeight: 44`. `AppButtonSpec.minimumHeight` exists, but MembersSectionView.swift:72 and :86 use the bare 44 and the brief says to keep the same minimum height. It was left as is and is not a token violation.

## Not done or partial

- Visual check: not performed. Neither the agents nor I ran the app in the simulator. Brian's real-mode check in the handoff covers it.
- No test asserts the 44pt minimum height, the full width or the icon (the acceptance-reviewer's minor gap).
- The `ButtonChromeScanTests` check slices a 1500-character window after `LogoutButtonView`, which is weaker than the scanner-based checks. It matches the neighbouring Archive List test.
