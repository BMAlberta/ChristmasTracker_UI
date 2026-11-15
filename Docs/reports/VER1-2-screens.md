# VER1-2: the update screens

Branch `feat/ver1-update-prompt`. Story V2 of `Docs/epics/VER1-update-prompt.md`.

## What changed

New (`ChristmasTracker/ChristmasTracker/Features/Version/`):
- `UpdatePresentation.swift`: pure copy and rules. Title "Update required", the unsupported-version sentence, the
  no-link line, prompt title "Update available", `versionLine` (required part dropped when the minimum version is empty
  or the minimum build is missing), `requiredNotes` (plain text, 500 characters including the ellipsis),
  `promptMessage` (notes only when 200 characters or fewer), `hidesContent`, `installLink(for:)`, `showsPrompt`
  (recommended needs a link), `showsUpdateButton`.
- `MockVersionState.swift`: ok, recommended, required, requiredNoLink; `parse` returns nil in production.
- `Views/UpdateRequiredView.swift`: full-screen `ScrollView`; app name in `appBrand`, a header-trait title with
  sort priority 1, the sentence, the version line, release notes as `Text(verbatim:)`, primary "Update" (label
  "Update Christmas Tracker", `openURL` with the `UpdateInstallLink` result only; hidden with no link, replaced by the
  ask-the-person line), small "Check again" with a spinner. Four previews: with notes, without notes in dark, without
  a link, `.accessibility5`.
- `Views/UpdatePromptModifier.swift`: `.updatePrompt(service:gate:installedVersion:installedBuild:)`. Required: a
  `ZStack` cover above the content (no sheet, no stack, no dismissal), content behind gets `.accessibilityHidden` and
  `.allowsHitTesting(false)`. Recommended: a root `.alert` with Update and Later. Both buttons call
  `dismissRecommended(latestVersion:)` (Update also opens the link; without that the state-derived alert would
  re-present at once). The alert binding is derived from the decision and ignores writes.

Changed:
- `Core/API/MockAppVersionRepository.swift`: `init(state:)`; the no-argument init is unchanged.
- `ChristmasTrackerApp.swift`: reads `-mockVersionState` (mock mode only, ignored when `APP_ENVIRONMENT` is
  production), a `versionChecksEnabled` flag (real mode with a client, or mock mode with a state) that gates the launch
  check, `scenePhase == .active` calls `checkIfDue()`, and `.updatePrompt(...)` on `ContentView` in `appContent`. The
  launch `LogInfo` line is unchanged. Nothing under `App/` (lock and privacy windows) was touched.
- Tests: `TypographySourceScanTests` allowlist gets `UpdateRequiredView.swift` (the brief requires the login screen's
  serif helper; the scan stays strict for every other file) and its title says four files.

Tests added (`ChristmasTrackerTests/Features/Version/`): `UpdatePresentationTests`, `MockVersionStateTests`,
`MockAppVersionRepositoryStateTests`, `UpdateViewsSourceScanTests` (no URL literal or host, only the install-link value
is opened, no auth or store reference, no logging or Sentry, no banned constructs, no `.sheet`, tokens only,
accessibility label and header, content hidden and not hittable, no dismissal path), `UpdateWiringScanTests` (modifier
applied at the root, scene-phase and launch checks wired, lock and privacy window files do not mention the new types),
plus `UpdateViewsScanSupport`.

## Commands and raw output

`scripts/verify.sh` before the V2 commit (summary lines):
```
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 4786 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.022 seconds.
```
V1 ended at 4743 app tests; V2 adds 43 (4786). Package tests unchanged at 212.

Process: test-writer red (missing symbols only); implementer built it and stopped on one conflict (the typography scan
allowlist vs. the brief); allowlist updated by the test-writer; convention-reviewer approved (warnings only);
acceptance-reviewer approved; its three coverage notes were closed by a further test-writer pass (4783 to 4786).

## Deviations

- The brief's "anchoring rule in CLAUDE.md" does not exist; the recommended prompt is a root `.alert` and does not use
  `ConfirmationPresentation` (it has no row to anchor to). Recorded in the epic brief.
- The mock policy uses reserved `.invalid` manifest URLs in `MockVersionState.swift` (a mock-only file). The brief
  forbids hard-coded URLs "anywhere"; a mock cannot show a link without one. No view contains a URL literal and a scan
  proves it.
- Tapping Update also dismisses the recommended prompt for that `latestVersion` (needed so the alert closes).

## Not done or partial

- **A sheet already presented from inside the app (for example add-item or the biometric setup sheet) is a separate
  presentation layer and stays above the root cover** when a 426 arrives while it is open. The cover and its
  accessibility hiding do not reach it. This is narrower than "blocking wins over everything inside the app". A full fix
  needs a window-level cover or a dismissal of presented sheets; the brief forbids touching the window layer, so it is
  banked, not fixed. The block is visible as soon as that sheet closes.
- No simulator run and no screenshots: the agents never saw the simulator, so previews, layout, dark mode, large type,
  VoiceOver order and the real `openURL` hand-off are NOT PERFORMED. VoiceOver "title first" is sort priority plus a
  hidden brand text, not programmatic focus (no `AccessibilityFocusState`, no `.isModal`).
- Line-length warnings (121 to 129 characters, under the 160 error limit) in `UpdatePresentation.swift:12`,
  `UpdateRequiredView.swift:115,130`, `ChristmasTrackerApp.swift:411` and a few test lines. `UpdatePromptModifier` has no
  preview of its own (it wraps the previewed view).
- The two loose `UpdateInstallLink` edges noted in `VER1-1-gate.md` (uppercase `HTTPS`, backslash in a host) remain.
