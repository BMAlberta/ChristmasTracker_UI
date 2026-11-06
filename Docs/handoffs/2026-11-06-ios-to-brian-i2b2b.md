# iOS Handoff — Package I2b-2b: Authentication on the Generated Client
**Date:** 2026-11-06  
**From:** iOS agent  
**To:** Brian (real-mode check) and API team  
**Branch:** feat/i2b2b-generated-auth  
**Commits:** a90965e (C1) → aa3a395 (C2) → 7195761 (C3) → 7ab50d7 (C4) → 89731f5 (F1 fix pass)

---

## Brian's Real-Mode Check

Before merging, test the following flows against the real server. Build the `ChristmasTracker` scheme (not `ChristmasTrackerMock`).

**Step 1 — Start the backend**  
Start the backend server on `http://localhost:3010`.

**Step 2 — Configure the real API mode**  
In Xcode, select the `ChristmasTracker` scheme. Choose Edit Scheme → Run → Arguments. Add the launch argument `-apiModeOverride real`.

**Step 3 — Run a Debug build on simulator**  
Build and run the Debug configuration on a simulator. Verify the app launches, the login screen appears, and no crash or force-update prompt appears.

**Step 4 — Login: valid credentials**  
Log in with a seeded user account. Verify the session is established and the user's display name appears in the Profile tab.

**Step 5 — Login: wrong password**  
Attempt login with the correct email but a wrong password. Verify an inline or alert message appears ("The email or password is incorrect.") and `isLoading` resets to false.

**Step 6 — Registration: success, then invalid code, then existing email**  
Navigate to Create Account. Register a new user with a valid registration code — verify the session is established. Then attempt to register again with the same (or any) email but an incorrect registration code — verify an inline error appears below the Registration Code field. Then attempt registration with an email that already exists — verify an inline error appears below the Email field.

**Step 7 — Logout: confirm it is immediate**  
Stop the backend server. Tap logout from an authenticated session. Verify the logout completes immediately (no spinner, no timeout delay) and the login screen appears. This confirms the iOS client sends no refresh token to the logout endpoint and does not wait for a server response.

**Step 8 — Face ID: enrollment, quit/relaunch, and token refresh**  
With the backend running again: after a successful login, verify the biometric enrollment offer appears. Accept and complete Face ID enrollment. Quit the app fully. Relaunch — verify Face ID fires automatically on the first appearance. After Face ID succeeds, wait for the 15-minute access token to expire (or trigger a request that gets a 401) and verify the session survives the refresh without requiring another Face ID prompt.

**Step 9 — Forgot Password: administrator guidance, no network request**  
From the login screen, tap the Forgot Password link. Verify a sheet appears with the administrator-contact guidance message, no email field, and a Close button. Confirm tapping Close dismisses it without any network request (observe the network tab in Xcode or use a proxy — no request to `/auth/*` should fire).

---

## What Still Uses the Hand-Written Stack

The following features were NOT changed by I2b-2b and still use pre-generated network code:

| Feature | Blocking package |
|---|---|
| Lists (fetch, create, delete) | I3 |
| List items (create, update, delete, purchase) | I3 / I4 |
| Members (invite, remove) | I3 |
| Purchases and budget confirmation | I4 |
| Stats | I3 |

The auth repository is now on the generated client. The `ListRepository`, `ItemRepository`, `MemberRepository`, and `PurchaseRepository` remain on hand-written network code until I3/I4.

---

## Open Risks and Known Issues

| Risk | Detail | Mitigation |
|---|---|---|
| 900-second `expiresIn` assumption | Login and register responses omit `expiresIn`; client defaults to 900 s (15 min). If the server's actual access token lifetime differs, tokens will appear valid after they expire. | Verify server token lifetime. API team to add `expiresIn` to login/register responses, or confirm 900 s is correct. |
| Nil-email rejection on login/register/refresh | If the server ever omits `email` from a User object on these endpoints, the client throws `.invalidResponse` and the user sees an error. The contract says `email` is nullable. | Confirm the server always populates `email` on auth responses even though the schema marks it nullable. |
| Login 403 arrives as `.undocumented` | `Operations.Login.Output` has no `.forbidden` case. ACCOUNT_DISABLED (403) is handled by status-code check in the `.undocumented` path. | See contract-issues.md row 1. API team to add `403 ForbiddenError` to the login operation in openapi.json. |
| Removed protocol members | `biometricLogin`, `ping`, `forgotPassword` removed from `AuthenticationRepository`. Any future code that expects them will not compile — this is the desired state. | No action needed. |
| `autoAttemptIfNeeded` appIsActive default | The `appIsActive` default is `{ true }`, meaning production calls (from `LoginView`) fire the auto-attempt even if the app is briefly backgrounded between the guard and the check. This is acceptable given the existing `hasAutoAttempted` flag prevents re-triggering. | No action needed for now; monitor if spurious biometric prompts are reported. |

---

## Contract Issues Filed This Package

| # | Endpoint | Issue | Action for API team |
|---|---|---|---|
| 1 | POST /auth/login | `Login.Output` has no `.forbidden` case; 403 ACCOUNT_DISABLED arrives as `.undocumented(403)` | Add `403 ForbiddenError` to the login operation in openapi.json and regenerate |

---

## What Changed (summary for PROGRAM.md section 9)

I2b-2b: moved login, register, refresh, and logout from the hand-written auth stack to the generated TrackerAPI client; replaced `AuthData` with `AuthSession`; added registration code, first/last name fields; closed 4 Face ID gaps (LAError mapping, swipe-down dismissal, appIsActive guard, shared offer logic); deleted `NetworkAuthenticationRepository`, all wire-format auth models, and dead session code; removed JSONSerialization fallback parser and carried server validation messages via `AuthenticationError.validation(message:)`; withdrew the false RolePayload contract issue.
