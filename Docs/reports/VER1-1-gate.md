# VER1-1: the install link and the update gate

Branch `feat/ver1-update-prompt`. Story V1 of `Docs/epics/VER1-update-prompt.md`. No UI.

## What changed

New (`ChristmasTracker/ChristmasTracker/Features/Version/`):
- `UpdateInstallLink.swift`: pure nonisolated `url(from:)`. Trims input; accepts an `https` manifest and builds
  `itms-services://?action=download-manifest&url=` plus the manifest percent-encoded (only `A-Za-z0-9-._~` left
  bare); accepts an `itms-services` string only when it is exactly the canonical form this type builds (inner URL
  decodes to an acceptable https URL and re-encodes to the same value). Nil for nil, empty, other schemes, userinfo,
  empty host, over 2048 characters.
- `UpdateGate.swift`: `Decision` (none, recommended(VersionPolicy), required(RequiredUpdate)), `RequiredUpdate`
  (minimumVersion, minimumBuild, manifest, releaseNotes) and `decide(...)`. A 426 is required when there is no policy
  or its order is at least the policy order; otherwise the policy decides. A dismissed `latestVersion` hides
  recommended only.
- `UpdateSequence.swift`: `@MainActor` counter, `next()` starts at 1.

Changed:
- `Core/API/VersionService.swift`: injectable `minimumCheckInterval` (default 900 s) and clock; `checkIfDue()`;
  `policyOrder`; `dismissedLatestVersion` and `dismissRecommended(latestVersion:)`. `check()` always runs, records the
  attempt start before the request (a failed attempt counts), and sets `policyOrder` only on success. Manual Sentry span
  unchanged and constant-named.
- `Core/API/VersionGate.swift`: `init(sequence:)` (default keeps old call sites compiling), `outdatedOrder`.
- `ChristmasTrackerApp.swift`: one `UpdateSequence` shared by gate and service. No scene-phase wiring yet (V2).

Tests (`ChristmasTrackerTests/Features/Version/`): `UpdateInstallLinkTests`, `UpdateGateTests`,
`VersionServiceCadenceTests`, `VersionServiceDismissalTests`, `VersionGateOrderTests`, `UpdateSequenceTests`, plus
`FakeAppVersionChecker`, `TestClock`, `VersionTestFixtures`.

## Commands and raw output

`scripts/verify.sh` before the V1 commit (filtered to the summary lines):
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 4743 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.021 seconds.
```
Baseline before the package: 4679 app tests, 212 package tests. Net +64 app tests, package unchanged.

Process: test-writer produced a red build (only missing-symbol errors); implementer went green on attempt 2 (a
nonisolated `Equatable` use and the existing `VersionGate()` call sites); convention-reviewer rejected once
(missing explaining comment on `checkIfDue()`), fixed and re-approved; acceptance-reviewer approved with coverage
gaps, which a second test-writer pass closed (4733 to 4743).

## Deviations and interpretations

- A newer policy of any state supersedes an older 426 (brief: "required wins over recommended" and "a later ok
  policy clears required"). Recorded in the epic brief. A 426 with an order equal to or newer than the policy blocks.
- `CLAUDE.md` has no confirmation anchoring rule (the brief mentions one); noted in the epic brief for V2.

## Not done or partial

- Nothing is wired to a screen: `checkIfDue()` has no caller, no scene-phase hook, no mock policy source, no root
  modifier. All of that is V2.
- Two loose edges of `UpdateInstallLink` are accepted and untested by design (low risk, the server supplies the value
  and it is only passed on as an encoded query value): an uppercase `HTTPS` scheme is accepted (the encoded value keeps
  the uppercase), and a host containing a backslash such as `https://evil.com\.good.com` passes because only `@`, `/`,
  `?`, `#` are checked in the authority.
- `VersionService.swift:40` comment is about 143 characters (warning limit 120, error 160).
- No simulator or visual check (no UI in this story).
