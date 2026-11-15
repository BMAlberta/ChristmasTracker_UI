# VER1: the update prompt

Branch `feat/ver1-update-prompt` (from master at 21a0647, the PAL1 merge). Package brief:
`/Users/brian/Development/christmasTracker/prompts/mobile-ui/VER1-update-prompt.md` (Brian, 2026-11-15).

## Goal

The app is installed outside the App Store: an `itms-services` link opens an install from a manifest on
Brian's own host. The version check and the 426 capture already exist and no screen uses them. This package
adds the UI: a blocking, full-screen "Update required" screen and a dismissible "Update available" prompt,
each with an Update button that opens the install link.

## Decisions (from the package brief)

1. The server decides the state. The client compares versions only to display them. State `ok` shows nothing.
2. `UpdateInstallLink` (pure, nonisolated) turns an optional manifest string into an optional `URL`:
   - `itms-services://?action=download-manifest&url=<https url>`: accepted only in exactly that form.
   - `https` URL: build `itms-services://?action=download-manifest&url=` plus the manifest URL percent-encoded
     for a query value (every reserved character encoded).
   - Anything else is "no install link": other scheme, nil or empty, over 2048 characters, userinfo present,
     inner manifest URL that is not `https`.
3. Update calls the SwiftUI `openURL` action with that URL only. No link: Update hidden and the screen says
   "Ask the person who sent you the app for the update link." A recommended prompt without a link is not shown.
4. Blocking screen copy: app name in the serif accent, "Update required", "This version of Christmas Tracker
   is no longer supported. Update to keep using the app.", "You have <version> (<build>). Required:
   <minimumVersion> (<minimumBuild>)." (required part omitted when data is missing), release notes (plain
   Text, at most 500 characters, ellipsis), primary "Update", small secondary "Check again" with a spinner.
5. Recommended prompt: native alert "Update available", message "Version <latestVersion> is available." plus
   release notes only if at most 200 characters. Buttons "Update" and "Later". Later remembers the dismissed
   `latestVersion` in memory for the process only.
6. Blocking wins over everything in the app. It sits above login and tabs, is not in a navigation stack,
   cannot be dismissed, works signed out and signed in, never signs out or clears state. The lock and privacy
   windows stay above it and are not touched.
7. Cadence: check on launch (existing task) and when the app becomes active, at most once per 15 minutes
   (injectable interval and clock). A failed check keeps the last policy and never blocks or shows an error.
8. A 426 blocks at once through `VersionGate` with no extra check. `UpdateGate` is the one pure type that
   answers none, recommended(policy), required(details). A 426 without usable details still blocks, with no link.
9. Mock mode and previews get a mock policy source that can show each state. No network in tests.
10. Out of scope: version-check API or contract, release script and runbook, the App Store, silent updates,
    progress, the lock and privacy windows, a Settings entry (the Profile "Version" row stays).

## Findings that shape the design

- `CLAUDE.md` has no "anchoring rule" for confirmations (the brief mentions one). `ConfirmationPresentation`
  (`Features/Shared/Presentation/ConfirmationPresentation.swift:12`) is a pure generic target-idle state used
  for destructive dialogs anchored to a row. The recommended prompt has no row to anchor to, so it uses a
  root-level `.alert` driven by `UpdateGate` and the dismissed-version memory, not `ConfirmationPresentation`.
  This is recorded as a deviation from the brief wording, not a behavior change.
- The existing launch check runs only in real mode with a client (`ChristmasTrackerApp.swift:389-400`). Mock mode
  never checks today. The mock policy source needs its own entry in the composition root.
- The serif app name is `Font.appBrand` (`DesignSystem/Typography/AppTypography.swift:26`), used by the login
  header (`Features/Authentication/Views/LoginView.swift:199-200`).
- `VersionService.check()` swallows every error into `lastErrorCategory` and keeps `lastPolicy`
  (`Core/API/VersionService.swift:26-41`), which already satisfies "a failed check keeps the last policy".
- The 426 middleware builds details with `minimumVersion: ""` and nil everything when the body is unparseable
  (`LocalPackages/TrackerAPI/.../VersionOutdatedMiddleware.swift:44-54`), so "no usable details" is an empty
  `minimumVersion` with a nil `manifestUrl`.
- `VersionPolicy.manifestURL` is a `URL?` made with `URL(string:)` (`GeneratedClientAppVersionRepository.swift:56`).
  The install link builder takes `manifestURL?.absoluteString`.
- Ordering between a policy and a 426 is not recorded anywhere, and the brief needs "a later ok policy clears
  required but a 426 after it blocks again". Both sources get a number from one shared sequence.

## Inventory (every current use)

`VersionService`:
- `Core/API/VersionService.swift:8-43` definition (`lastPolicy`, `lastErrorCategory`, `check()` with manual Sentry span).
- `ChristmasTrackerApp.swift:242` `@State versionService`; `:385-386` created from `dependencies.appVersionRepository`;
  `:389-400` the only call site of `check()` (launch task, real mode with a client, logs state and build numbers).
- Tests: `ChristmasTrackerTests/Core/API/VersionCheckTests.swift:16-74`; `Features/Version/VersionCheckRetryAfterTests.swift:190-194`.

`VersionGate` (the 426 sink):
- `Core/API/VersionGate.swift:9-16` definition (`latestDetails`, `handleVersionOutdated`).
- `ChristmasTrackerApp.swift:241` `@State versionGate`; `:268-270` created first; `:307` passed to `buildGeneratedClient`.
  Nothing reads `latestDetails` outside tests (`ChristmasTrackerTests/Core/API/SeamTests.swift:155-206`).
- Package: `TrackerClientFactory.swift:15,62,71,85` wires `VersionOutdatedMiddleware`; `VersionOutdatedMiddleware.swift:36-37`.

`VersionPolicy` and `VersionPolicyState`:
- `Features/Version/VersionPolicy.swift:7-65` definition.
- `AppVersionChecking.swift:7-8`; `GeneratedClientAppVersionRepository.swift:24-80` builds it (mapping at `:49-61`,
  304 uses the cached policy at `:64-66`); `Core/API/MockAppVersionRepository.swift:6-26` (always `ok`);
  `App/InertRepositories.swift:207-209` (throws).
- `ChristmasTrackerApp.swift:94` (`AppDependencies.appVersionRepository`), `:129` mock, `:146-149` real, `:167` inert.
- Tests: `Features/Version/VersionCheckRepositoryTests.swift:74-98`.

`VersionOutdatedDetails` (package `Seams.swift:25-48`, public): `minimumVersion: String`, `minimumBuild: Int?`,
`latestVersion: String?`, `latestBuild: Int?`, `manifestUrl: String?`, `ipaUrl: String?`. Also carried by
`TrackerAPIError.versionOutdated` (`TrackerAPIError.swift:15,67-76`). It has no release notes, so the required
screen shows release notes only when the policy is the source.

## Gate 1 spec

New files (all under `ChristmasTracker/ChristmasTracker/`; Xcode groups are folder-synced, no pbxproj edit):
- `Features/Version/UpdateInstallLink.swift`, `Features/Version/UpdateGate.swift`,
  `Features/Version/UpdatePresentation.swift` (copy and truncation, pure),
  `Features/Version/Views/UpdateRequiredView.swift`, `Features/Version/Views/UpdatePromptModifier.swift`.
- Changed: `Core/API/VersionService.swift`, `Core/API/VersionGate.swift`, `Core/API/MockAppVersionRepository.swift`,
  `ChristmasTrackerApp.swift` (composition, scene phase, root modifier). `ContentView.swift` only if the cover
  is applied there.
- Tests under `ChristmasTrackerTests/Features/Version/` and `Core/API/`, one type per file.

New interface: yes (`UpdateInstallLink`, `UpdateGate`, service entry points). Pipeline: test-writer, then
implementer, then convention-reviewer and acceptance-reviewer.

### Story V1: the install link and the gate (no UI)

Interfaces:
- `nonisolated enum UpdateInstallLink { static func url(from manifest: String?) -> URL? }`
- `nonisolated struct UpdateGate` with an enum `Decision { none, recommended(VersionPolicy), required(RequiredUpdate) }`
  and `static func decide(policy: VersionPolicy?, policyOrder: Int, outdated: VersionOutdatedDetails?, outdatedOrder: Int, dismissedLatestVersion: String?) -> Decision`.
  `RequiredUpdate` carries current-install-independent display data: minimum version and build, the manifest string
  and the release notes (policy source only).
- `VersionService`: `init(repository:minimumCheckInterval:now:sequence:)` (defaults 900 s, system clock),
  `func checkIfDue() async` (the "active again" entry; skips inside the interval), `check()` unchanged in behavior
  and always runs, `dismissRecommended(latestVersion:)`, `dismissedLatestVersion`, `policyOrder`.
- `VersionGate`: records `outdatedOrder` from the same sequence when a 426 arrives.
- `UpdateSequence`: tiny `@MainActor` counter shared by service and gate.

Acceptance criteria:
1. `UpdateInstallLink` returns a URL for a good https manifest, the exact itms-services form and nothing else; every
   rejection in decision 2 returns nil; characters such as `&`, `=`, `#`, `?`, space round-trip through the encoding.
2. `UpdateGate`: ok gives none; updateRecommended gives recommended; forceUpdate gives required; a 426 gives required
   with and without details; required wins over recommended when both exist and the 426 is newer; a newer policy
   supersedes an older 426 (an ok policy clears it) and a 426 after it blocks again; a dismissed `latestVersion`
   hides recommended for that string only.
3. Cadence: `checkIfDue()` makes no second repository call inside 15 minutes and calls again after it; a failed check
   keeps the last policy and does not move the order; the launch `check()` still always runs.
4. A failed check never changes the gate decision and surfaces no error.

Interpretation recorded: the brief says "required wins over recommended" and "a later ok policy clears required".
Where a 426 exists and a newer policy says recommended, this package treats the newer policy as the truth (the
server has re-evaluated this build), so the 426 no longer blocks. Otherwise a relaxed minimum with a newer latest
build would trap the user behind the block with no way to clear it. Same-age or newer 426 still wins.

### Story V2: the screens

Interfaces: `UpdateRequiredView(state:onUpdate:onCheckAgain:isChecking:)`-style value-driven view; a root view modifier
`updatePrompt(...)` applied at the root; `UpdatePresentation` (pure) for the sentence, the version line, truncation.
The mock policy source reads `-mockVersionState <ok|recommended|required|requiredNoLink>` (UserDefaults, like
`apiModeOverride`), honored only in mock mode and a non-production environment.

Acceptance criteria:
1. Blocking screen shows decision-4 copy exactly; Update uses `openURL` with the `UpdateInstallLink` result only;
   no link hides Update and shows the ask-the-person sentence; Check again re-runs `check()` and shows a spinner.
2. Release notes: plain Text, 500 (required) and 200 (recommended, else not shown) characters, ellipsis on truncation.
3. Recommended prompt is a native alert titled "Update available" with "Update" and "Later"; Later hides that
   `latestVersion` for the process; a recommended policy without a link shows nothing.
4. The cover sits above login and tabs, has no dismissal path, hides content behind it from accessibility, does not
   reference the authentication service or any store, and leaves the lock and privacy windows untouched.
5. VoiceOver: title is a header and first; Update button label "Update Christmas Tracker". Dynamic Type to the
   accessibility sizes in a ScrollView. DesignSystem tokens only. Previews for all five states, light and dark,
   and the largest accessibility size.
6. A source scan proves the new views contain no literal URL or host and open only the `UpdateInstallLink` result;
   no manifest URL, link or release-note text reaches a log, span, breadcrumb or error.

## Baseline (Step 0, before any change)

`scripts/verify.sh`: build succeeded, configuration check OK, app tests 4679 passed, 0 failed, 0 skipped.
`swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.
