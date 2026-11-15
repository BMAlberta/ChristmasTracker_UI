# iOS to Brian: TH1.1 the destructive look

Date: 2026-11-14. Branch `feat/th1-1-destructive-look` (from master at the TH1 merge 62d8110). Not pushed.

## Contract issues

None. No networking, API model or repository change. contract/STATUS.md reads CONFORMANT.

## What changed

- Logout on Profile is now a bordered, Cranberry-tinted button with the destructive role, like Leave list. It is no longer a filled green capsule. Its confirmation dialog's "Logout" button has the destructive role, so iOS shows it red. The icon, full width, 44pt minimum height, confirmation and `authService.logout()` call are unchanged, and the dialog is still attached to the button.
- This reverses the UX1b decision that sign out is neutral, per Brian on 2026-11-14. It is recorded in Docs/epics/TH1-1-destructive-look.md. The two UX1b scans that enforced it were replaced with scans for the new rule, and ProfileView was removed from the `PrimaryButtonStyle` file list.
- Audit: 22 destructive controls inventoried (swipe actions, menu items, buttons and dialog buttons). Only the Logout pair did not comply. Nothing else was restyled.
- A new scan test fails if a `confirmationDialog` or `alert` action button titled Delete, Remove, Archive, Leave, Logout or Sign Out lacks `role: .destructive`. It has no allow-list. Two dialog buttons with generic titles (ChildrenView and the member Remove dialog) are covered by pinned tests.
- Tests: app 4622 to 4638 passed (A1: -2 +3, A2: +15), 0 failed. TrackerAPI 212, unchanged.
- Reports: Docs/reports/TH1-1-1-logout.md, TH1-1-2-audit.md, TH1-1-3-handoff.md.

## Commits (`git log --oneline master..HEAD`, before this handoff commit)

```
48dda24 TH1.1: apply the destructive look to every destructive control
8bfadfd TH1.1: give Logout the destructive look
e810d84 TH1.1: add epic brief and inventory
```

The handoff commit `TH1.1: add the package handoff note` follows these.

## What the API team must do

Nothing.

## Open risks

- The visual result is unchecked. No agent ran the app in the simulator, so the Cranberry-on-dim-fill look and the red dialog button are verified only by source scans.
- The convention-reviewer noted the bare `minHeight: 44` on the Logout button. It matches the Leave list button and the brief's "same minimum height", so it was left as is.
- The new scan matches the button's own title. A future dialog button with a generic title and no keyword needs its own pin (the scanner file header says so).
- The scanner ignores string literals when matching brackets, and misses a dialog written with an explicit `actions:` label. Neither occurs in the app today.

## For PROGRAM.md section 9

TH1.1 (destructive look): Logout is now bordered with the destructive tint and role, its dialog button is destructive, UX1b's "sign out is neutral" is reversed on purpose (Brian, 2026-11-14), the audit found no other non-compliant control, and a dialog-button role scan guards the rule. Tests: app 4638 passed, TrackerAPI 212. No contract or API impact. Pending Brian's real-mode visual check.

## Brian's real-mode check

Run steps 1 and 2 in dark mode first, then in light mode. Steps 3 to 6 in either mode.

1. **Logout button.**
   - Open the Profile tab and scroll to the bottom.
   - Expect: a bordered Cranberry-tinted button with the sign-out icon, no longer a filled green capsule. In dark mode, Cranberry text on a dim Cranberry fill.
2. **Logout dialog.**
   - Tap Logout.
   - Expect: the confirmation anchored to the button, with Logout shown in red and Cancel below.
3. **Children swipe delete.**
   - Profile, then Children. Swipe a child left.
   - Expect: a red Delete action (unchanged).
4. **Leave list.**
   - Open a list you are a member of.
   - Expect: the Leave list button looks the same as before and the same as Logout.
5. **One more per audit row that changed.**
   - The audit changed nothing beyond the Logout pair in steps 1 and 2, so there are no extra steps.
6. **Sign out still works.**
   - Tap Logout, then confirm Logout in the dialog.
   - Expect: the login screen.

Checks run: `scripts/verify.sh` (app tests, TrackerAPI package tests, script tests) after every commit, and both Gate 2 reviews for each code story. Checks NOT PERFORMED: all six steps above. The agents never saw the simulator, and Brian has not yet run the real-mode check.
