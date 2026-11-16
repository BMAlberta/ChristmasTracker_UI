# CL1-2 — A failed version check must not use up the interval

## What changed
- `Core/API/VersionService.swift`
  - `lastAttemptStart` replaced by `lastSuccess` and `lastFailure`.
  - New injectable init parameter `failureRetryInterval` (default 60 s), placed after `minimumCheckInterval`; existing call sites use labels and are unchanged.
  - `checkIfDue()` skips if the last success is inside `minimumCheckInterval` (15 min, unchanged) or the last failure is inside `failureRetryInterval`.
  - A success records `lastSuccess` and clears `lastFailure`. A failure (both catch branches, via private `recordFailure()`) clears `lastSuccess` and records `lastFailure`, so after a failure the 60 s window governs even if an earlier success was recent.
  - Failure still keeps `lastPolicy`/`policyOrder`, never blocks or shows an error. Manual `check()` ignores both times. The manual Sentry span and comments are unchanged. The success time is now recorded when the check finishes (it was the attempt start before); this is a negligible difference for a 15 minute rule.
- `VersionServiceCadenceTests.swift`: 5 tests added: `failureRetriesAfterRetryWindow` (failure, 61 s, check), `failureThenSuccessWaitsFullInterval`, `failureAfterSuccessRetriesAfterRetryWindow`, `manualCheckIgnoresFailureTime`, `manualCheckIgnoresSuccessTime`.
  The spec cases "success then inside 15 min (no check)", "success then after 15 min (check)" are covered by the existing unchanged tests `checkIfDueSkipsAfterLaunchCheck` (899 s) and `checkIfDueRunsAfterInterval` (900 s). "Failure then 30 s (no check)" is covered by the edited `failedAttemptCounts`.

## EDITED tests
- `failedAttemptCounts`: `EDITED (CL1-C2)`: it encoded the old rule (60 s after a failure makes no second call). Now 30 s after a failure makes no second call; display name updated; assertion form unchanged.
- `failedAttemptRetriesAfterInterval`: comment-only edit with the marker; name, body and expectation unchanged.

## Commands and raw output
Red first: cadence suite 16 passed, 3 failed (the three new retry tests) before the change. Then `scripts/verify.sh` (implementer, working tree):
```
--- xcodebuild exit status: 0 ---
--- tests: 5331 passed, 0 failed, 0 skipped ---
=== verify: OK ===
```
Previous total 5326 (after C1); 212 package tests passed.

## Gate 2
- convention-reviewer: PASS. Two non-blocking notes: the comment-only EDITED marker (listed above) and `failedAttemptCounts` keeps its old function name.

## Deviations
- Not done on purpose: the brief's test "session end resets both times". `VersionService` holds no session state and is not a clearable (the version policy is pre-auth; VER1 clears nothing on sign-out), so there is nothing to reset and no existing session-safety test to follow. No reset was added. Brian can say if he wants one.

## Not done or partial
- The session-end reset test, as above. Nothing else. Simulator and network were not exercised. The package acceptance review found one regression (an in-flight overlap), fixed in the follow-up section below and re-approved.

## Follow-up: in-flight guard
Why: the acceptance reviewer found a regression. The old `lastAttemptStart` was set at the start of a check, so an `.active` scene-phase `checkIfDue()` during the launch check was suppressed. After C2 the times were recorded only after the await, so a second concurrent request could go out.

What changed:
- `VersionService.swift`: private `isChecking` flag, set at the start of `check()` before the first await and reset in the existing `defer` (so it always runs). `checkIfDue()` returns first thing when `isChecking` is true; the success/failure window rules are unchanged. Manual `check()` is not gated and always runs. Doc comment of `checkIfDue` mentions the in-flight skip. Span and comments kept.
- Correction: the earlier sentence calling the success-time-at-completion change "negligible" is withdrawn as the full story. The gap it opened (a request during the in-flight check) is now covered by the in-flight guard.
- Known limit: with a manual `check()` overlapping another in-flight check, the first to finish clears the flag while the other is still running. This is only reachable via manual checks, which are never gated; the launch/active path is covered.

Tests added (`VersionServiceCadenceTests.swift`): `checkIfDueSkipsWhileInFlight` (red first: callCount was 2), `windowAppliesAfterInFlightFinishes`, `manualCheckRunsWhileInFlight`.
`FakeAppVersionChecker.swift`: `EDITED (CL1-C2)`: added an off-by-default one-shot `holdFirstCall` gate plus `release()` so a test can hold a call open. Existing tests are unaffected (callCount semantics unchanged).

Raw verify summary (`scripts/verify.sh`):
```
--- xcodebuild exit status: 0 ---
--- tests: 5334 passed, 0 failed, 0 skipped ---
=== verify: OK ===
```
Package tests (212) passed in the same run. One attempt to green after the red run.
