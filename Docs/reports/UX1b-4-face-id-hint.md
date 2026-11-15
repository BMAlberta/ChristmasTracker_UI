# UX1b Story B4: The Face ID hint

Branch: feat/ux1b-dialogs-colors-and-polish. Pipeline: full (test-writer, implementer, convention-reviewer, acceptance-reviewer, sequential).

## Decision recorded (conflict between the brief and the code)
Rule 5 said the hint goes "under the error" and is "announced to VoiceOver together with the error". The login error is a modal alert (LoginView `.alert("Error"...)`), so there is no inline error. Brian decided (asked during this story): the caption sits just below the Sign In button, kept in screen state so it stays after the alert is dismissed; the alert is untouched; the caption is a normal accessibility element read after Sign In, with no separate announcement. The epic's Rule 5 and Story B7 step 6 were updated to match. The Orchestrator's own reading, recorded in the epic: "available" means the existing biometric button state is `.showEnrolled` (biometric sign-in can be used now); `.showNotEnrolled` and `.showNeedsSetup` show no hint because they offer no usable biometric path.

## What changed
- New `Features/Authentication/LoginFaceIDHint.swift`: `LoginFaceIDHint.text(for:buttonState:biometricName:)` (pure; nil unless the error is `.invalidCredentials` and the button state is `.showEnrolled`; text "You can also sign in with <name>." with the name from `BiometricType.displayName`) and `LoginFaceIDHintState` (`none`, `signInFailed`, `fieldEdited`, `signInStarted`, `reset`).
- `LoginView.swift`, hint additions only: `@State private var hint`; `handleLogin` calls `signInStarted()` before and `signInFailed(...)` after `await authService.login`; two-parameter `onChange` on email and password call `fieldEdited()`; `onDisappear` calls `reset()`; a muted caption (`appCaption1`, `textMutedColor`) directly after `LoginActionSection`. The `.alert("Error"...)` block, sign-in, biometric, lock and AuthenticationService logic are untouched.

## Files
Added (production): Features/Authentication/LoginFaceIDHint.swift. Added (tests, Features/Authentication): LoginFaceIDHintTests.swift (8; one parameterized over the 15 non-credentials errors, 16 cases enumerated by hand), LoginFaceIDHintStateTests.swift (10), LoginFaceIDHintScanTests.swift (5). Changed: Features/Authentication/Views/LoginView.swift; Docs/epics/UX1b-dialogs-colors-and-polish.md (Rule 5, Gate 1); Docs/reports/UX1b-3-tab-bar.md (after-commit verify line). Deleted: none. Existing tests changed: none.

## Test arithmetic (app suite)
4345 + 23 new (8 + 10 + 5, grep -c @Test; parameterized counts once) - 0 = 4368. Measured by scripts/verify.sh: 4368. Package 212, release scripts 92, destination scripts 17.

## Raw output (from running commands)
Red before the change: the test target did not compile (missing LoginFaceIDHint and LoginFaceIDHintState). Before commit:
```
--- tests: 4368 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed
=== test-release.sh: 92 passed, 0 failed ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: OK ===
```
After commit 2eb069b (separate run): `--- tests: 4368 passed, 0 failed, 0 skipped ---`, `Test run with 212 tests in 16 suites passed`, `test-release.sh: 92 passed, 0 failed`, `test-destination.sh: 17 passed, 0 failed`, `=== verify: OK ===` (this line ships with the next commit).

## Gate 2
- convention-reviewer: APPROVE. Warnings: four test lines over 120 characters (LoginFaceIDHintStateTests 19, 34, 46; LoginFaceIDHintTests 51). `text` is `private(set) var` where the Gate 1 sketch said `let` (benign).
- acceptance-reviewer: APPROVE (read LoginView, the presenter, AuthenticationService.login, LoginBiometricModel). Findings: `login` sets `error = nil` before the request, so after the await the error is this attempt's result (no stale value); the hint is @State so it survives the alert's OK; biometric sign-in never writes `error`; `isLoading` prevents concurrent attempts; `.showEnrolled` is the same condition `LoginBiometricModel.tap` guards on.
- Rejections: none. Stuck detector: none.

## Verification sources
Totals from running commands; the race analysis and "no auth logic changed" from the reviewer reading code and `git diff`. No simulator run.

## Not done or partial
- No simulator run: the caption's look and placement, and that VoiceOver reads it right after Sign In, are proven only by Brian's real-mode check (step 6).
- Banked edges (acceptance-reviewer): a shown hint is not re-evaluated against later state (after a failed biometric tap, or if enrollment disappears, it can still say "sign in with Face ID"); an edit made while the request is in flight is followed by the hint if the request then fails.
