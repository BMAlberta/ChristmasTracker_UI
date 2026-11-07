# iOS Handoff: Package I2b-2c (adopt contract C15 and C16)
**Date:** 2026-11-06
**From:** iOS agent (Orchestrator)
**To:** Brian (real-mode check, PROGRAM.md) and the API team
**Branch:** chore/contract-sync-f1d4f57 (Brian's sync branch; new commits only; not pushed)
**Contract:** contract content of C16 (backend f1d4f57), synced at backend commit 5c86cc3 (one docs-only commit later), spec sha256 55f570342c69. STATUS.md: CONFORMANT.

## Commits
`git log --oneline master..HEAD`, taken after the U3 commit (the U4 commit adds one more line, "I2b-2c: add the package handoff note"):
```
ed12b82 I2b-2c: use expiresIn, drop the null-email path, and treat a refresh 403 as a credential failure
06925a6 I2b-2c: end the session when the account is disabled or no longer exists
5d67f29 I2b-2c: regenerate the client from contract f1d4f57 and handle the new response cases
05a24ce I2b-2c: add brief and inventory
e3ae527 chore: sync the contract at f1d4f57
```
e3ae527 is Brian's sync commit. The four I2b-2c commits follow it, and the U4 commit comes last.

## Contract issues found
None new. `Docs/contract-issues.md` row 1 (login 403 not documented) is resolved: "fixed in 99e15fb (C15), synced at 5c86cc3".

## What changed
- **U1, regenerated client.**
  - The derived spec was regenerated with `scripts/make-client-spec.sh`; the count guard held at 5.
  - Every switch over a regenerated Output maps the new cases explicitly:
    - Login `.forbidden` maps to `accountDisabled`, and the old `.undocumented(403)` special case is removed.
    - Refresh `.badRequest`, `.forbidden` and `.tooManyRequests` map to `validation(message:)`, `accountDisabled` and `rateLimited`.
    - Logout `.forbidden` and `.notFound` map to `sessionExpired`, and `.tooManyRequests` maps to `rateLimited`.
  - The package fixtures carry non-null emails and `expiresIn`. Typed decoding tests cover the new statuses.
- **U2, end the session on a disabled or missing account.**
  - In the package: the `SessionEnding` seam and `SessionEndingMiddleware`. The middleware covers non-public operations only, and only 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND. The body is returned unchanged.
  - The middleware is wired into `TrackerClientFactory.make` through a defaulted parameter, and the order is documented.
  - In the app: `SessionEndingSeam` and `makeClientSeams()`. A server-initiated session end signs out a signed-in session once, even when calls arrive concurrently, and keeps the Face ID enrollment.
- **U3, expiresIn, non-null email, and the refresh 403 rule.**
  - Login and register use `expiresIn` from the response.
  - The nil-email path is gone. `invalidResponse` remains for malformed responses.
  - `isCredentialFailure(_:context:)` treats ACCOUNT_DISABLED as a credential failure on refresh, but not at login.
  - Refresh credential failures end the session on both refresh paths, `refreshTokenIfNeeded` and `forceRefresh`. They delete the current user's Face ID token, refresh the snapshot, and run a single-flight teardown.
  - Face ID sign-in with a refresh 403 ends on the password screen with no error text.
  - The login 403 alert now shows the administrator message from one shared source.
- **Real bugs found and fixed:**
  1. **The composition root dropped the seam box** (U2). The bearer-token seam always returned nil and the refresh seam always failed.
     - Introduced in I2b-2b C1 (a90965e) when `[weak auth]` captures were replaced by `[weak authBox]` on a local box.
     - Latent since then, because no screen makes an authenticated generated call yet.
     - Two composition tests now prove the fix.
  2. **Concurrent session ends tore down more than once** (U2, found at Gate 2).
  3. **The login 403 alert showed the wrong text** (U3, D-d). It said "Your account has been disabled. Please contact support" (`MockAuthenticationRepository.swift:211` before the fix, at 06925a6) instead of the administrator text (`AuthErrorMessages.swift:15`).
  4. **The enrolled-user snapshot stayed stale** after a refresh credential failure deleted the Face ID token (U3).
- **Tests:**
  - App: 612 → 618 (U1) → 630 (U2) → 633 (U3).
  - Package: 146 → 156 (U1) → 179 (U2) → 179 (U3).
  - `scripts/verify.sh` is OK after every commit. Details are in Docs/reports/I2b2c-*.md.

## What the API team must do
Nothing.

## Brian's real-mode check
These steps need the local backend from the backend repo's Docs/local-development.md. The seeded users are john.doe@example.com, jane.smith@example.com and mike.johnson@example.com; the password and registration code are printed in that document and are deliberately not written here. The psql commands below are for the development database only. The agents never run them.

1. Start the backend on http://localhost:3010 and confirm /livez.
2. In Xcode choose the ChristmasTracker scheme, then Edit Scheme, Run, Arguments, and add the launch argument `-apiModeOverride real`.
3. Run the Debug build on the simulator.
4. Confirm the Xcode console shows one version-check line (state ok).
5. Log in as a seeded user and confirm the Profile shows the right name.
6. Log in with a wrong password. Confirm the invalid-credentials message appears and that Sign In works again.
7. Register a new user with the registration code. Then try again with a wrong code (expect an inline code error), and then with an existing email (expect an inline email error).
8. Stop the backend and log out. Confirm the login screen appears immediately. Restart the backend.
9. Enable Face ID, quit and relaunch, and confirm Face ID signs in.
10. Set the backend's version policy to force_update using the policy:set recipe in section 10 of the backend's local-development doc (min-build 501, without setting any URL). Confirm that a login attempt shows the update-required message. Then restore the seeded policy with `npm run prisma:seed`.
11. **Disabled account at login.**
    - Disable Jane with `docker exec tracker-dev-db psql -U tracker -d christmas_tracker_dev -c "UPDATE users SET is_active = false WHERE email = 'jane.smith@example.com';"`.
    - Try to log in as Jane and confirm the administrator-contact message appears ("This account has been disabled. Contact your administrator."). A 403 at login is not a session end.
12. **Disabled account on the Face ID path.**
    - Re-enable Jane (the same command with `true`).
    - Log in as Jane, enable Face ID, and quit the app.
    - Disable Jane again and relaunch.
    - Confirm Face ID sign-in ends on the password screen with NO error text, and that the Face ID button reverts to the "sign in with your password first" state (the stored token was deleted).
    - On screen, the button label changes from "Sign in as Jane" to "Sign in with Face ID" (`LoginView.swift:311`/`:313`; the biometric name is filled in at runtime).
    - Tapping the button in that state would show the alert "Sign in with your password to enable Face ID for future logins." (`LoginView.swift:114`). Do NOT tap it before the password logins that steps 12 to 14 check (see the note under step 13).
    - Re-enable Jane afterwards.
13. **Expired refresh token.**
    - Log in as John, enable Face ID (from Profile, or by tapping the Face ID button before this first login), and quit.
    - Run `docker exec tracker-dev-db psql -U tracker -d christmas_tracker_dev -c "UPDATE refresh_tokens SET expires_at = now() - interval '1 minute' WHERE user_id = (SELECT id FROM users WHERE email = 'john.doe@example.com');"`.
    - Relaunch and confirm Face ID sign-in ends on the password screen with no error text.
    - Log in by password and confirm Face ID is silently re-enrolled, with no enablement screen.
    - Note: do not tap the Face ID button before this password login. Tapping it in the "not enrolled" state records an enablement request (`LoginBiometricModel.swift:72`), and that request takes priority over silent re-enrollment (`BiometricOfferAction.swift:50-57`). The enablement screen would then appear, which is correct behaviour but not this step's expected result.
14. **Invalid refresh token.**
    - With Face ID enabled for John, quit.
    - Run `docker exec tracker-dev-db psql -U tracker -d christmas_tracker_dev -c "DELETE FROM refresh_tokens WHERE user_id = (SELECT id FROM users WHERE email = 'john.doe@example.com');"`.
    - Relaunch and confirm the same outcome as step 13.
15. **Not performed until package I3.** Two paths can't be exercised manually yet, because no screen makes a generated authenticated call:
    - the 401 refresh-once-and-replay path;
    - the session end on an authenticated call that gets 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND.

    Package and app unit tests cover both. The manual versions come with I3. The backend's `JWT_EXPIRY=60s` setting, with the backend restarted after editing .env, will exercise refresh-once-and-replay then.

## Status of other checks
- **Lists, items and purchases** still use the old hand-written stack until I3 and I4 (the `ListRepository`, `ItemRepository` and `PurchaseRepository` protocols, built as `NetworkListRepository`, `NetworkItemRepository` and `NetworkPurchaseRepository` on `NetworkAPIClient`; members go through the list repository).
- **Face ID on a real device:** not performed. The Face ID behaviour has been checked only by unit tests with fakes.
- **I1-b real-mode check:** not performed. It waits for Brian to run the steps above.
- **I2b-2b real-mode check:** not performed. It waits for Brian to run the steps above, which supersede it.
- **I2b-2c real-mode check:** not performed. This is the list above.

## Open risks and items found, not fixed (no pre-existing fixes in this package; for a later pass)
| Item | Detail | Source |
|---|---|---|
| Logout ordering | `AuthenticationService.logout` clears tokens before its best-effort server call, so the generated-client logout always goes out with no bearer token and gets a 401. RefreshOn401 then calls `forceRefresh`, which throws because there are no tokens; this is logged as a best-effort failure and opens a Sentry transaction. Pre-existing since a90965e and harmless today, because iOS sends no refresh token to logout (A15). U3 makes sure this path cannot end a session twice. | U2 report |
| Two single-flight flags | `AuthServiceBox.isEndingSession` (server-initiated end, U2) and `AuthenticationService.isEndingSession` (refresh failure, U3) do not see each other. A logout suspended in teardown can overlap a refresh credential failure and tear down twice. Probably harmless, but not proven. Candidate: one flag in the service. | U3 acceptance finding 1 |
| Awaited session end | The session-ending handler is awaited inside the request, so the caller's typed `.forbidden` or `.notFound` arrives after the teardown, and a caller that loses the race returns mid-teardown. I3 screens must not write error state back after a sign-out. | U2 acceptance finding 2 |
| Stale 403/404 | A slow 403/404 from user A that arrives after user B has signed in signs B out, because the adapter checks only that someone is signed in. | U2 acceptance finding 3 |
| Login 403 and stored tokens | Guide 3.2 says to "discard stored tokens" on login 403. iOS keeps the Face ID token and deletes it on the next Face ID attempt (decision D-c). | D-c |
| Version-check 429 retryAfter | `GeneratedClientAppVersionRepository.swift:60` uses the error code (8001) as the retry-after seconds. | U1 acceptance A3 |
| Isolated-run test failure | `SignInWithBiometricTests/logoutSetsIsAuthenticatedFalseBeforeRepoLogoutCompletes` fails every time when run alone, including on 06925a6 before U3, and passes in every full run. The likely cause is that 10 `Task.yield()`s are not enough for the `sessionManager.teardown` actor hop. The test needs a deterministic handshake. | U3 report |
| Real Keychain in logout tests | `logout` reaches `KeychainService.delete` through `clearStoredTokens` in unit tests. This pattern predates the package. | U2 report |
| Untested branches | getCurrentUser 429 has no test, because RateLimitMiddleware's real sleeper retries GETs and the factory has no sleeper seam. The typed `.tooManyRequests` arms on the POST auth operations can't be reached through the factory. | U1 report |
| Minor | Repository `?? "…"` fallbacks after a non-optional `error.message` are dead code. `nonisolated(unsafe)` on `AuthServiceBox` is probably unnecessary. No span on the private helper `endSessionAfterRefreshCredentialFailure` (convention W1). Some test files and the AuthenticationService type exceed size limits. | Gate 2 warnings |

## PROGRAM.md section 9 (one line)
I2b-2c: adopted C15 and C16 (regenerated the client; typed 400/403/404/429 cases; expiresIn from login and register; non-null email; refresh 403 is a credential failure; session ends on 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND through new package middleware), fixed the dead seam box in the composition root (latent since a90965e) and the login 403 message; contract-issues row 1 resolved; real-mode check pending Brian.
