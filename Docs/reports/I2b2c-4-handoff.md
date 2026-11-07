# I2b-2c U4: real-mode check and handoff (docs only)

Package: I2b-2c. Story: U4. Date: 2026-11-06.
Contract: contract content of C16 (backend f1d4f57), synced at backend commit 5c86cc3 (one docs-only commit later), spec sha256 55f570342c69.
Pipeline: the Orchestrator wrote the docs, then the convention reviewer and the acceptance reviewer reviewed them, one after the other. There is no code, so there was no test-writer or implementer.

## After the U3 commit (ed12b82), from running commands
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 633 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 179 tests in 13 suites passed after 0.015 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `􁁛  Test run with 179 tests in 13 suites passed after 0.013 seconds.`
These also serve as the "before" outputs for U4. U4 changes no code, so the suites are unchanged.

## Files
- Added: `Docs/handoffs/2026-11-06-ios-to-brian-i2b2c.md`, `Docs/reports/I2b2c-4-handoff.md`.
- Changed: none.
- Deleted: none.

## What the handoff contains
Everything CLAUDE.md and the prompt require:
- contract issues found (none new; row 1 resolved);
- what changed;
- the commit hashes with subjects (`git log --oneline master..HEAD`);
- what the API team must do (nothing);
- open risks;
- one line for PROGRAM.md section 9.

The section "Brian's real-mode check" contains the 15 steps from the package prompt. The seeded user emails are named, and the password and registration code are deliberately not written. The psql commands are marked development-only and never run by agents. Step 15 explains why the authenticated-call paths wait for I3.

It also gives the status of the other checks:
- Lists, items and purchases still use the hand-written stack until I3 and I4.
- Face ID on a real device: not performed.
- The I1-b and I2b-2b real-mode checks: not performed; they wait for Brian.

## Tests
App: 633 previous + 0 - 0 = 633. Package: 179 + 0 - 0 = 179. U4 is docs only.

## Verification claims
- Commit list: from running `git log --oneline master..HEAD` after the U3 commit.
- Test totals per story: from running verify.sh after each commit, as recorded in the U1 to U3 reports and above.
- Step 12's on-screen change: from reading the code. The button label is at `LoginView.swift:310-314`, and the not-enrolled alert at `LoginView.swift:105-115`, shown only on tap (`LoginBiometricModel.swift:71-73`).
- Step 13's tap warning: from reading `LoginBiometricModel.swift:72` and `BiometricOfferAction.swift:50-57`.
- Open risks: from the U1 to U3 reports and the reviewers' findings (reading code).

## Gate 2 results (written after the reviews)
Convention reviewer: **APPROVED**, with no hard blocks and no warnings.
- Required handoff sections present: handoff lines 19-20, 22-52, 54-55 and 115-116 at review time.
- No secrets, and no GitHub `@name` mentions; every `@` is inside an example.com address.
- Facts match the repo: the commit list, the test totals, `AuthErrorMessages.swift:15`, `GeneratedClientAppVersionRepository.swift:60`.
- The report has every required element.
- Only the two new files are in `git status`.
- Notes:
  - N1: the step 12 text is interpolated at runtime.
  - N2: this section was still to be written.
  - N3: the pre-fix line citation.

Acceptance reviewer, first review: **REJECTED**, routed to the Orchestrator as docs author.
- F1: step 12 pointed at alert text (`LoginView.swift:114`) instead of the button-label change (`LoginView.swift:310-314`).
- F2: step 13 could fail if the Face ID button was tapped first. An enablement request takes priority over silent re-enrollment (`BiometricOfferAction.swift:50-57`).
- F3: "MemberRepository" does not exist.
- Advisory A1: the pre-fix citation needs its commit.
- Advisory A2: optional `.env` and seed notes for step 10.
- Verified OK in the first review:
  - the commit list and the test totals against the reports;
  - steps 1-15 against the backend's local-development doc, including the container, user, database and schema columns for the psql commands;
  - the expected UI for steps 11-14 against the code, including the silent re-enrollment path (`AuthenticationService.swift:138-140, 419-423`);
  - every real-bug and open-risk row against the cited code and reports.

Fixes, by the Orchestrator: F1, F2, F3 and A1. A2 was not taken, because the prompt said to cite the recipe.

Acceptance reviewer, re-review: **APPROVED**.
- All three findings and A1 are fixed (handoff 78-79, 86, 98, 47; report 55-56, 64-65).
- The three psql commands match the prompt's text character for character (a `grep -cF` fixed-string match).
- Non-blocking note N1: clarify how John enables Face ID in step 13 and what the no-tap note covers. Applied after the re-review as a wording-only change to the two bullets: "before the password logins that steps 12 to 14 check", and "from Profile, or by tapping the Face ID button before this first login".

Stuck-detector log: one rejection, fixed on the first attempt.

## Deviations
- Steps 12 and 13 keep the prompt's wording and add guidance from the code. No other step was changed.
  - Step 12 adds what changes on screen: the button label goes from "Sign in as Jane" to "Sign in with Face ID" (`LoginView.swift:311`/`:313`). It also adds that tapping the button shows the alert "Sign in with your password to enable Face ID for future logins." (`LoginView.swift:114`), and says not to tap it.
  - Step 13 adds a note not to tap the Face ID button before the password login. Tapping records an enablement request, which takes priority over silent re-enrollment (`BiometricOfferAction.swift:50-57`).
- The commit list in the handoff was taken before the U4 commit. It notes that the U4 commit adds one line. The package-end `git diff --stat master...HEAD` is taken after the final commit and reported in the session summary.

## Not done or partial
- Brian's real-mode check (steps 1 to 14): not performed. It needs Brian and the local backend.
- Step 15 (authenticated-call paths): deferred to I3 by design.
- Face ID on a real device: not performed.
