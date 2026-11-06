# I1-b Handoff: iOS → Brian

**Date:** 2026-11-06  
**Package:** I1-b — App integration of the generated API client  
**Branch:** `feat/i1b-api-integration`

---

## What Changed

### B1 — Hosts and Configuration
- Fixed `Config.xcconfig`: Release `API_BASE_URL` now `https:/$()/api.bmalberta.com` (was parsed as `https:` due to `//` comment stripping).
- Fixed `Config-Debug.xcconfig` and `Config-QA.xcconfig`: both now `http:/$()/localhost:3010` (were broken with literal space).
- Added `NSAppTransportSecurity / NSAllowsLocalNetworking: true` to `Info.plist`; no arbitrary loads.
- Added `AppConfiguration.validateBaseURL(_:)` pure validator with 6 error cases.
- Extended `scripts/check-config.sh` to verify effective `API_BASE_URL` per configuration and forbid arbitrary loads keys.

### B2 — API Mode Override and Composition Root
- `resolveAPIMode(infoValue:override:environment:)` — pure resolver; production environment ignores `apiModeOverride` launch argument.
- `AccessTokenSeam`, `SessionRefreshSeam`, `VersionGate`, `RequestIDSeam` — four seam implementations bridging the app to the generated client.
- `AuthenticationService.forceRefresh()` — new method mapping credential failures to `SessionRefreshError.credentialFailure`.
- `AppDependencies` promoted to top-level; `trackerClient: (any APIProtocol)?` wired in real mode.

### B3 — Version-Check Slice (new types in TrackerAPI package)
- `VersionPolicy` + `VersionPolicyState` — domain model for the version-check response.
- `AppVersionChecking` protocol + `GeneratedClientAppVersionRepository` — calls `GET /app/version-check` through the real generated client; caches last successful policy for 304 responses.
- `VersionService` (`@MainActor @Observable`) — holds `lastPolicy` and `lastErrorCategory`; never crashes on failure.
- `MockAppVersionRepository` — development stub used by the composition root in mock mode.
- Launch-time version check in `ChristmasTrackerApp.init`: runs in real mode only, logs state + build numbers only.

### B4 — Verify Hardening
- `scripts/verify.sh`: added `=== verify: TrackerAPI Xcode scheme ===` step that builds the TrackerAPI scheme via xcodebuild.

---

## Contract Issues Found

None. The contract at backend commit 35ff2bc is CONFORMANT and matches the generated client. No new issues discovered.

---

## What the API Team Must Do

None required for this package. All work is iOS-side integration of the existing generated client against the existing `/app/version-check` endpoint.

---

## Brian's Real-Mode Check

Before merging, test the version-check path against the real backend:

1. Build and run on a simulator or device in Release (or with `-apiModeOverride real` as a launch argument on Debug).
2. Watch the Xcode console for:
   ```
   [business] Version check: state=ok minBuild=1 latestBuild=N
   ```
3. Confirm no crash and no token/email logged.
4. Optionally test with a stale `If-None-Match` by clearing derived data between runs to force a fresh 200.

---

## Open Risks

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R1 | `AuthenticationService.forceRefresh()` error mapping (`isCredentialFailure`) references internal app-module logic; will be replaced by generated auth mapping in I2b-2b. TODOs placed at both sites. | Low | Tagged `TODO(I2b-2b, 2026-11-05)` |
| R2 | `GeneratedClientAppVersionRepository.checkVersion()` has no `@Instrumented` tracing because the TrackerAPI package carries no Sentry dependency. All repository-layer calls via this path are untraced. | Low — version check is non-critical path | Accept for now; add Sentry to TrackerAPI only if the package expands to cover auth/list/item calls in I3+ |
| R3 | `VersionService.lastErrorCategory` stores only a classification enum, not an error message. No user-facing error UI is wired in this package (intentional per Non-goals). | Deferred | I6b (version manager UI) |
| R4 | `VersionGate.latestDetails` is wired but no UI observes it yet. Force-update blocker is not enforced. | Expected | I6b |

---

## PROGRAM.md Line (Section 9)

> I1-b (2026-11-06): Fixed xcconfig URL breakage; wired generated TrackerAPI client at composition root with four seams; added version-check domain model, repository, and service; verify.sh now builds TrackerAPI Xcode scheme.
