# I2b-2c U3: use expiresIn, drop the null-email path, and treat a refresh 403 as a credential failure

Package: I2b-2c. Story: U3. Date: 2026-11-06.
Contract: contract content of C16 (backend f1d4f57), synced at backend commit 5c86cc3 (one docs-only commit later), spec sha256 55f570342c69. Client guide 3.2 and 3.3.
Pipeline: full, every step one at a time:
1. Test-writer.
2. Brian decision D-d, then one more test from the test-writer.
3. Implementer.
4. Fix round: the test-writer added snapshot assertions, then the implementer fixed the snapshot refresh.
5. Convention reviewer, then acceptance reviewer.

## After the U2 commit (06925a6), from running commands
```
=== verify: derived spec ===
Transformed 5 null-schema properties.
Derived spec is up to date.
=== verify: build ===
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
--- tests: 630 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 179 tests in 13 suites passed after 0.012 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"`: `􁁛  Test run with 179 tests in 13 suites passed after 0.015 seconds.`
These also serve as the "before" outputs for U3.

## Files
Changed, production:
- `Features/Authentication/Services/BiometricSignInState.swift`
- `Features/Authentication/Services/AuthenticationService.swift`
- `Core/API/SessionRefreshSeam.swift`
- `Features/Authentication/Repositories/GeneratedClientAuthenticationRepository.swift`
- `Features/Authentication/Repositories/MockAuthenticationRepository.swift`
- `Core/Models/AuthTypes.swift`

All of these are under `ChristmasTracker/ChristmasTracker/`.

Changed, tests (all under `ChristmasTracker/ChristmasTrackerTests/`):
- `Features/Authentication/BiometricSignInStateTests.swift`
- `LoginBiometricButtonTests.swift`
- `GeneratedClientAuthRepositoryTests.swift`
- `AuthenticationServiceTests.swift`
- `AuthErrorMappingTests.swift`
- `SignInWithBiometricTests.swift`
- `Core/API/SeamTests.swift`

Changed, docs:
- `Docs/contract-issues.md`: row 1 resolved, header intact.
- `Docs/epics/I2b2c-adopt-c15-c16.md`: U3 "Exact signatures" and D-d, added at Gate 1.

Added or deleted files: none.

`git diff --stat`: 15 files changed, 583 insertions(+), 96 deletions(-).

## What changed
- **Classification** (`BiometricSignInState.swift:22-56`). The two-argument form replaces the one-argument `isCredentialFailure(_:)`:
  ```swift
  nonisolated internal enum AuthErrorContext: Sendable, Equatable { case login, refresh }
  internal nonisolated func isCredentialFailure(_:context:)
  ```
  - The switch is exhaustive, with no `default`.
  - invalidRefreshToken, sessionExpired, invalidCredentials and credentialExpired are true in both contexts.
  - accountDisabled returns `context == .refresh`.
  - The other 11 cases are listed and return false.
  - Callers, all `.refresh`:
    - `biometricSignInOutcome` (line 90)
    - `SessionRefreshSeam.refresh` (`SessionRefreshSeam.swift:18`)
    - `refreshTokenIfNeeded` (`AuthenticationService.swift:335`)
    - `forceRefresh` (:367)
  - Login does not call it.
- **Session end after a refresh credential failure** (`AuthenticationService.swift`):
  - A new main-actor flag `isEndingSession` (62-63).
  - A new helper `endSessionAfterRefreshCredentialFailure()` (declared at 391; guard 393-395; snapshot refresh at 401):
    - It guards `isAuthenticated && !isEndingSession`, sets the flag with no suspension between, and clears it with `defer`.
    - It deletes the enrollment only when it belongs to the current user, then calls `refreshBiometricState()` (fix round).
    - It then calls `logout(reason: .sessionExpired)`.
  - `refreshTokenIfNeeded` uses the helper. Its non-credential branches are unchanged.
  - `forceRefresh` (declared at 353; catch at 365-373), per D-b:
    - It keeps the no-tokens guard, which throws `invalidRefreshToken` and ends nothing.
    - On a refresh-context credential failure it calls the helper and rethrows the original error.
    - Other errors are rethrown unchanged.
  - The manual Sentry spans and their comments are kept; no `@Instrumented` on MainActor methods.
  - The new log lines are fixed strings (336, 368), with no tokens, emails or passwords.
- **expiresIn** (`GeneratedClientAuthenticationRepository.swift:44, 103`): login and register use `data.expiresIn`, and the 900 literals are gone.
  - `mapUser` keeps the form U1 left (non-optional `schema.email`).
  - The `AuthTypes.swift:17-18` comment now says `expiresIn` comes from the login, register and refresh responses.
  - The mock repository's 900 values stay; they are mock data.
- **invalidResponse**: the case stays, with its comment changed to "undecodable or malformed response" (`MockAuthenticationRepository.swift:181`).
- **D-d, login 403 message** (`MockAuthenticationRepository.swift:210-212`): `AuthenticationError.errorDescription` for `.accountDisabled` now returns `userMessage(for: .accountDisabled)`.
  - `AuthErrorMessages.swift:15` is the single source of truth.
  - The old literal "Your account has been disabled. Please contact support" is removed. That was the mock repository file's own hard-coded copy, because `AuthenticationError` is defined in `MockAuthenticationRepository.swift`.
  - No other mock behaviour or `errorDescription` string changed.
  - Grep (from running a command; the implementer and both reviewers confirmed it): "Contact your administrator" appears exactly once in production code, at `AuthErrorMessages.swift:15`, and "contact support" appears nowhere.
- **Departure from the literal Gate 1 signature**: `AuthErrorContext` is declared `nonisolated internal enum`.
  - The app target defaults to MainActor isolation, so without `nonisolated` the enum's `Equatable` conformance is main-actor-isolated and cannot be used in the nonisolated classifier. That was the attempt-1 compile error.
  - This matches the existing `nonisolated struct AuthSession`. It is not an `@unchecked Sendable` or a `nonisolated(unsafe)`.
- **Docs/contract-issues.md row 1, Status**: "Resolved: fixed in 99e15fb (C15), synced at 5c86cc3 (contract content of C16, backend f1d4f57, spec sha256 55f570342c69). …". The file keeps resolved rows; its header is untouched.

## Real bugs found
1. **The login 403 alert showed the wrong message.**
   - What the user saw: "Your account has been disabled. Please contact support" instead of the administrator message.
   - The two source locations:
     - `ChristmasTracker/ChristmasTracker/Features/Authentication/Repositories/MockAuthenticationRepository.swift:211`. This was `AuthenticationError.errorDescription`, which `LoginView.swift:85` displays as `localizedDescription`.
     - `ChristmasTracker/ChristmasTracker/Features/Authentication/AuthErrorMessages.swift:15`. This holds the administrator text, and only `RegistrationView` used it.
   - Fixed under D-d with one shared source.
   - Tests asserting the old "contact support" wording: none existed, per a grep of `ChristmasTracker/` and `LocalPackages/` by the Orchestrator and the test-writer. So none needed updating.
   - The existing test `AuthErrorMappingTests.accountDisabledMapsToExpectedMessage` now reads a file-level constant. Its assertion is unchanged, and it is listed as rewritten below.
   - The new test `accountDisabledLocalizedDescriptionIsAdministratorMessage` failed before the fix with `(shown → "Your account has been disabled. Please contact support") == (userMessage(for: .accountDisabled) → "This account has been disabled. Contact your administrator.")`.
2. **After a refresh credential failure, the enrolled-user snapshot stayed stale.** Found by the implementer and fixed in the fix round.
   - Before, `refreshTokenIfNeeded` deleted the enrollment without calling `refreshBiometricState()`, so the login screen could still offer Face ID for a deleted token.
   - The new shared helper now refreshes the snapshot after a deletion, which covers `forceRefresh` too.

## Tests
App suite: 630 previous + 16 new - 13 deleted = 633. A parameterized test counts as one entry.

Deleted (13):
- BiometricSignInStateTests.swift (4): `isCredentialFailureTrueForInvalidCredentials`, `isCredentialFailureTrueForSessionExpired`, `isCredentialFailureTrueForInvalidRefreshToken`, `isCredentialFailureFalseForNetworkError`.
  - Reason: they tested the removed one-argument signature and are subsumed by the truth table.
- LoginBiometricButtonTests.swift (8), deleted for the same reason:
  - `isCredentialFailureTrueForInvalidRefreshToken`
  - `isCredentialFailureTrueForSessionExpired`
  - `isCredentialFailureTrueForInvalidCredentials`
  - `isCredentialFailureFalseForBiometricFailed`
  - `isCredentialFailureFalseForBiometricNotAvailable`
  - `isCredentialFailureFalseForNetworkError`
  - `isCredentialFailureFalseForEmailAlreadyExists`
  - `isCredentialFailureFalseForUserNotFound`
- GeneratedClientAuthRepositoryTests.swift (1): `loginNilEmailThrowsInvalidResponse` and its fixture `loginNilEmailBody`.
  - Reason: C16 makes email non-null and the nil-email path is removed.
  - `invalidResponse` stays covered by the new malformed-body test.

Added (16):
- BiometricSignInStateTests.swift (3):
  - `isCredentialFailureMatchesTruthTable(row:context:)`: 16 cases × 2 contexts.
  - `truthTableCoversEveryCaseOnce`: its exhaustive `caseName` switch has no default, so a new case does not compile without a row.
  - `accountDisabledAuthErrorMapsToPasswordRequired`.
- GeneratedClientAuthRepositoryTests.swift (2): `loginSuccessMapsGeneratedEmail`, `loginMalformedSuccessBodyThrowsInvalidResponse`.
- SeamTests.swift (1): `throwsCredentialFailureForAccountDisabled`.
- AuthErrorMappingTests.swift (1): `accountDisabledLocalizedDescriptionIsAdministratorMessage` (D-d).
- AuthenticationServiceTests.swift (1): `login403AccountDisabledShowsAdministratorMessageAndKeepsEnrollment` (D-c and D-d).
- SignInWithBiometricTests.swift (8):
  - `signInWithBiometricAccountDisabledDeletesEnrollmentSilently`
  - `refreshTokenIfNeededAccountDisabledDeletesEnrollmentAndEndsSession`
  - `forceRefreshCredentialFailureRethrowsDeletesEnrollmentAndEndsSession(error:)`, parameterized over `.accountDisabled` and `.invalidRefreshToken`
  - `forceRefreshAccountDisabledForDifferentUserKeepsEnrollmentAndEndsSession`
  - `forceRefreshWithNoTokensThrowsWithoutTeardown`
  - `forceRefreshAfterLogoutDoesNotTearDownAgain`: the logout-ordering case from the U2 report.
  - `forceRefreshNetworkFailureRethrowsAndKeepsSession`
  - `concurrentRefreshesSharingAccountDisabledTearDownOnce`
  - In the fix round, three of these gained snapshot assertions: the refreshTokenIfNeeded test, the forceRefresh credential-failure test, and the different-user test.

Rewritten (count unchanged):
- `loginSuccessDecodesThroughGeneratedClient(expiresIn:)` and `registerSuccessDecodesThroughGeneratedClient(expiresIn:)`.
  - They are now parameterized over 900 and 3600, replacing the fixed `== 900` assertions, to prove the value is read from the response.
  - Their fixtures take `expiresIn`.
- `AuthErrorMappingTests.accountDisabledMapsToExpectedMessage`: uses the file-level constant; the assertion is unchanged.

Package suite: 179, unchanged; no package change.

Reconciliation: the acceptance reviewer counted the added, deleted and rewritten tests from the files and got the same 630 - 13 + 16 = 633 (from reading code). The total comes from running verify.sh below.

Red evidence before the implementation (test-writer's run against a temporary test-local stand-in for the new signature, removed afterwards; source: running commands):
- 10 intended failures, for example:
  - the 3600 `expiresIn` case (900 ≠ 3600)
  - `accountDisabled` in `.refresh` (false, expected true)
  - the Face ID enrollment kept
  - the session still signed in after a refresh 403
  - zero teardowns in the concurrency test
- The D-d failure, quoted above.
- The fix round: `enrolledUserSnapshot → (userId: "u1", firstName: "Alice")) == nil` failed in two tests.

## Raw outputs before the U3 commit
`scripts/verify.sh` (Orchestrator run, grep-filtered summary lines):
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
􁁛  Test run with 179 tests in 13 suites passed after 0.013 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```
`swift test --package-path "LocalPackages/TrackerAPI"` (implementer's fix-round run): `Test run with 179 tests in 13 suites passed after 0.013 seconds.`
After the U3 commit: recorded at the top of the U4 report.

## Gate 2
Convention reviewer: **APPROVED** (written after the review).
- Hard blocks: all pass.
  - Instrumentation: manual spans are kept on the MainActor methods `refreshTokenIfNeeded` (307-346) and `forceRefresh` (351-375), and `@Instrumented` is kept on the four repository methods.
  - The `nonisolated` enum departure is justified (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
  - The classification switch is exhaustive, with 16 cases.
  - Concurrency is clean. No GCD, Combine, force unwraps, `try!` or `as!`, and no sleeps.
  - The new `Task.yield` loops copy the existing pattern.
  - Logging is safe and test emails are reserved.
  - D-d leaves a single source in production.
  - Deleted tests are named in each file's header.
  - The contract-issues header is intact. Scope holds: nothing under `.claude/`, any `.pbxproj`, `contract/`, the synced Docs or the package.
- Warnings, recorded and not fixed:
  - W1: the new private async helper (`AuthenticationService.swift:391`) has no manual span and no explaining comment. The precedent is I2b2a-2 Gate 2, which treated `singleFlightRefresh` as a warning, and the helper is called only inside spanned methods.
  - W2: branch name (chore branch per Brian).
  - W3: file and type size. SignInWithBiometricTests.swift is about 1,100 lines, and the AuthenticationService type body was already over the limit before U3.
  - W4: test lines over 120 characters, all under 160.
  - W5: hand-rolled repository fakes; MockAuthenticationRepository cannot script a 403 or a blocked refresh.
  - W6: some tests construct the service without `makeSUT`, matching nearby tests.
  - W7: implicit access on the `CredentialFailureRow` test struct.
  - W8: the administrator literal is repeated in `AuthenticationServiceTests.swift:370` (test only).

Acceptance reviewer: **APPROVED** (written after the review). Focus answers:
- (6) Login and register read `data.expiresIn` (44, 103). The only remaining 900s are mock data (`MockAuthenticationRepository.swift:58, 94, 121`) and unrelated configuration. The tests are parameterized over 900 and 3600, with interpolated fixtures (`GeneratedClientAuthRepositoryTests.swift:242, 433`).
- (7) `mapUser` uses the non-optional email (224-237). The nil-email test and fixture are deleted and named. `invalidResponse` remains through `classifyClientError` and is proven by `loginMalformedSuccessBodyThrowsInvalidResponse` (:269).
- (8) Refresh 403:
  - The classifier and all its callers pass `.refresh`.
  - The helper deletes the enrollment for the current user only and refreshes the snapshot.
  - Face ID gives `.passwordRequired` with `error` unset. `LoginView.swift:327-335` renders `EmptyView()` for it, and the alert at 82-86 is driven only by `error`, so no error text appears.
  - Login 403 shows the administrator message: `MockAuthenticationRepository.swift:212`, `AuthErrorMessages.swift:15`, `LoginView.swift:85`.
  - The truth table is at `BiometricSignInStateTests.swift:153`, with the exhaustive `caseName` at :203.
  - The session-end tests are at `SignInWithBiometricTests.swift:641-769`, and the seam test at `SeamTests.swift:104`.
- (10) 630 - 13 + 16 = 633, verified; the package stays at 179.
- (11) No change under `contract/`, `.claude/`, any `.pbxproj`, the package or the synced Docs. Row 1 is resolved with the required wording and the header is intact.

Advisory findings, recorded for the handoff:
- 1: two separate single-flight flags (U2's `AuthServiceBox.isEndingSession` and U3's `AuthenticationService.isEndingSession`). A server-initiated or user logout that is suspended in teardown can overlap a refresh credential failure, and both tear down. That is probably harmless, but nothing proves it. Candidate: merge them into one flag.
- 2: the concurrency test asserts the outcome, and depending on interleaving it may not prove the flag is necessary.
- 3: the optional comparison in the helper behaves the same as the old `if let`.

Rejections: none. The fix round (snapshot refresh) ran before Gate 2, so both reviewers reviewed the final code.

Stuck-detector log:
- Test-writer: attempt 1, the D-d addition, then the fix-round addition.
- Implementer:
  - Attempt 1 failed to compile: `main actor-isolated conformance of 'AuthErrorContext' to 'Equatable' cannot be used in nonisolated context`.
  - Attempt 2, after adding `nonisolated` (a different error signature), was green at 633.
  - Fix-round attempt 1 was green at 633.

## Pre-existing test-isolation failure (not caused by U3)
- `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` fails every time when run alone or with only its suite. It passes in every full run.
- The failure message: `Expectation failed: (sut.isAuthenticated → true) == false … isAuthenticated must be false while repo.logout is still suspended`.
- The implementer reproduced it alone on the U2 commit 06925a6, before U3. It used a temporary detached `git worktree` in the scratchpad, then removed it; `git worktree list` shows only the main tree.
- The acceptance reviewer confirmed that U3 does not touch the test's path: `login` and `logout` are unchanged, and `isEndingSession` is never read by `logout`.
- The likely cause is that the test's 10 `Task.yield()`s are not enough to get through the `sessionManager.teardown` actor hop in a fresh process.
- Not edited (no pre-existing fixes, D-a); recorded for the handoff.

## Deviations
- `AuthErrorContext` is `nonisolated internal enum`, not the literal `internal enum`. The reason is above.
- D-d, the login 403 message fix, was added to U3 by Brian's decision during this story.
- The snapshot refresh after deletion was added in a fix round. It also changes `refreshTokenIfNeeded`'s pre-existing behaviour, because the deletion moved into the shared helper.

## Out of scope (for the handoff)
- Unify the two single-flight flags (acceptance finding 1).
- The isolated-run failure of `logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` (above).
- D-c: client guide 3.2 says a login 403 should "discard stored tokens". iOS keeps the Face ID token on a login 403, and the next Face ID attempt deletes it, by design.
- W1: decide whether private async service helpers need manual spans.

## Not done or partial
- Real-mode check: not performed; it needs Brian (U4 handoff).
- The convention warnings W1 to W8 are recorded and not fixed.
