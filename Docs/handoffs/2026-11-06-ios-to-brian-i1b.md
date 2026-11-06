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

### B3 → F1 — Version-Check Slice
- `VersionPolicy` + `VersionPolicyState` — domain model for the version-check response. Lives in the **app module** under `Features/Version/` (initially placed in the TrackerAPI package in B3; moved back in F1 fix pass — see F1 notes below).
- `AppVersionChecking` protocol + `GeneratedClientAppVersionRepository` — calls `GET /app/version-check` through the real generated client; caches last successful policy for 304 responses. `@Instrumented` on `checkVersion()` (restored in F1).
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

1. Start the backend on `http://localhost:3010` (run the API server locally).
2. In the Xcode scheme editor for `ChristmasTracker`, add `-apiModeOverride real` as a launch argument under Arguments Passed On Launch.
3. Run the **Debug** build on a simulator (do not use Release — Release ignores the override).
4. Watch the Xcode console for a line matching:
   ```
   [business] Version check: state=ok minBuild=1 latestBuild=N
   ```
5. Stop the backend and relaunch the app (backend still stopped). Confirm no crash; the console should show the client error log instead of the version-check success line.
6. Remove the `-apiModeOverride real` launch argument and rerun to confirm mock mode works (no network call, no version-check log line).

---

## Open Risks

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R1 | `AuthenticationService.forceRefresh()` error mapping (`isCredentialFailure`) references internal app-module logic; will be replaced by generated auth mapping in I2b-2b. TODOs placed at both sites. | Low | Tagged `TODO(I2b-2b, 2026-11-05)` |
| R2 | ~~`GeneratedClientAppVersionRepository.checkVersion()` has no `@Instrumented` tracing.~~ **Resolved in F1 fix pass.** The repository now lives in the app module and `@Instrumented` has been restored. | Resolved | F1 |
| R3 | `VersionService.lastErrorCategory` stores only a classification enum, not an error message. No user-facing error UI is wired in this package (intentional per Non-goals). | Deferred | I6b (version manager UI) |
| R4 | `VersionGate.latestDetails` is wired but no UI observes it yet. Force-update blocker is not enforced. | Expected | I6b |

---

---

## Fix Pass (F1–F3, 2026-11-06)

Three defects found in chat review after the four B stories were committed:

**F1 — Repository back in app:** `VersionPolicy`, `AppVersionChecking`, and `GeneratedClientAppVersionRepository` were incorrectly placed in the TrackerAPI package during B3 (a linker error workaround). Root cause: the package was linked to multiple targets, forcing dynamic linking and removing OpenAPIRuntime symbols from the app binary. Brian's commit `3e35e09` fixed this by linking TrackerAPI to the app target only (static). F1 moves the three types back to `ChristmasTracker/Features/Version/` and the 15 repository tests back to `ChristmasTrackerTests/Features/Version/`. `@Instrumented` restored. Test count: 549 app, 146 package.

**F2 — Import audit guard:** The `=== verify: TrackerAPI Xcode scheme ===` step introduced in B4 printed `BUILD SUCCEEDED` during the HTTPTypes mutation experiment — the step was ineffective. Replaced with `scripts/check-package-imports.sh`, a deterministic script that compares `import X` statements against declared Package.swift products. Exits non-zero when HTTPTypes is removed.

**F3 — Test stubs out of production:** `AppDependencies.make(mode:baseURL:)` defined `TestAPIClient`, `TestListRepo`, `TestItemRepo`, and `NoopVersionHandler` inline in production code. Replaced with `buildGeneratedClient(mode:serverURL:info:tokenProvider:sessionRefresher:versionOutdatedHandler:requestIDObserver:) -> (any APIProtocol)?` — an `internal nonisolated` free function. The composition-root tests now call it with no-op stubs defined in the test target. The `try?` swallowing is gone; errors are logged. `AppConfiguration.apiBaseURL` is not accessed in mock mode.

---

## PROGRAM.md Line (Section 9)

> I1-b (2026-11-06): Fixed xcconfig URL breakage; wired generated TrackerAPI client at composition root with four seams; added version-check domain model, repository, and service; fix pass moved repository back to app module, replaced ineffective Xcode scheme verify step with import audit, removed test stubs from production code.
