# iOS Handoff — Package I2b-2b: Authentication on the Generated Client
**Date:** 2026-11-06  
**From:** iOS agent  
**To:** Brian (real-mode check) and API team  
**Branch:** feat/i2b2b-generated-auth  
**Commits:** a90965e (C1) → aa3a395 (C2) → 7195761 (C3)

---

## Brian's Real-Mode Check

Before merging, test the following flows against the real server with `APIMode.real`. Build the `ChristmasTracker` scheme (not `ChristmasTrackerMock`).

**Step 1 — Build and launch**
Build and run on a simulator or device. Verify the app launches, no crash, and the login screen appears. Confirm no "contract issues" banner or force-update prompt appears.

**Step 2 — Login: valid credentials**
Log in with a known-good account. Verify: session established, `isAuthenticated` becomes true, the main tab bar appears. Check that the session does not immediately expire (the 900-second default expiresIn is used since the login response omits `expiresIn`).

**Step 3 — Login: wrong password**
Attempt login with a wrong password. Verify: an alert appears with the "Invalid credentials" message (not a crash, not a blank screen). Verify `isLoading` resets to false.

**Step 4 — Login: account disabled (403)**
If a disabled test account is available, attempt to log in. Verify: the "Account disabled — contact your administrator" message appears. (This path arrives as `.undocumented(403)` in the generated client; the repository maps it correctly.)

**Step 5 — Registration: valid new account**
Navigate to Create Account. Fill in first name, last name, email, password (meeting all 5 rules), confirm password, and a valid registration code. Tap Create Account. Verify: session established and the user is logged in.

**Step 6 — Registration: existing email**
Attempt to register with an email address that already exists. Verify: an inline error message appears below the Email field (not an alert). Verify the code field is clear.

**Step 7 — Registration: invalid registration code**
Attempt to register with a valid email/password but an incorrect registration code. Verify: an inline error message appears below the Registration Code field (not an alert). Verify the email field is clear.

**Step 8 — Forgot Password screen**
From the login screen, tap the Forgot Password link. Verify: a sheet or screen appears with the "Contact your administrator" message, no email field, and a Close button. Confirm tapping Close dismisses it without any network request.

**Step 9 — Face ID: enrollment and auto-attempt**
After a successful login (Step 2), if the device supports Face ID and the user has no prior enrollment, verify the biometric enrollment offer appears. Accept the offer, complete Face ID enrollment. Log out. Relaunch the app. Verify Face ID auto-attempt fires on the first appearance (the `autoAttemptIfNeeded` path). Complete Face ID. Verify the session is restored.

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
| `RolePayload` frozen with only USER/ADMIN | `Components.Schemas.User.RolePayload` is `@frozen` with only `USER`/`ADMIN`. Extended role values (`viewer`, `member`, `owner`, `blind_viewer`) are handled by a JSONSerialization fallback decoder. If the generated client is regenerated before the backend adds those values to the schema, the fallback continues to work. | See contract-issues.md row 2. API team to add all role values to openapi.json. |
| Login 403 arrives as `.undocumented` | `Operations.Login.Output` has no `.forbidden` case. ACCOUNT_DISABLED (403) is handled by status-code check in the `.undocumented` path. | See contract-issues.md row 1. API team to add `403 ForbiddenError` to the login operation. |
| Removed protocol members | `biometricLogin`, `ping`, `forgotPassword` removed from `AuthenticationRepository`. Any future code that expects them will not compile — this is the desired state. | No action needed. |
| `autoAttemptIfNeeded` appIsActive default | The `appIsActive` default is `{ true }`, meaning production calls (from `LoginView`) fire the auto-attempt even if the app is briefly backgrounded between the guard and the check. This is acceptable given the existing `hasAutoAttempted` flag prevents re-triggering. | No action needed for now; monitor if spurious biometric prompts are reported. |

---

## Contract Issues Filed This Package

| # | Endpoint | Issue | Action for API team |
|---|---|---|---|
| 1 | POST /auth/login | `Login.Output` has no `.forbidden` case; 403 ACCOUNT_DISABLED arrives as `.undocumented(403)` | Add `403 ForbiddenError` to the login operation in openapi.json and regenerate |
| 2 | All auth endpoints | `RolePayload` is `@frozen` with only USER/ADMIN; server returns extended role values | Add `viewer`, `member`, `owner`, `blind_viewer` to `RolePayload` enum in openapi.json and regenerate |

---

## What Changed (summary for PROGRAM.md section 9)

I2b-2b: moved login, register, refresh, and logout from the hand-written auth stack to the generated TrackerAPI client; replaced `AuthData` with `AuthSession`; added registration code, first/last name fields; closed 4 Face ID gaps (LAError mapping, swipe-down dismissal, appIsActive guard, shared offer logic); deleted `NetworkAuthenticationRepository`, all wire-format auth models, and dead session code.
