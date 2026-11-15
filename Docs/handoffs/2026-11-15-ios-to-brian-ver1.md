# Handoff: iOS to Brian, package VER1 (update prompt)

Date: 2026-11-15. Branch `feat/ver1-update-prompt` (from master at the PAL1 merge 21a0647). Not pushed.

## Contract issues found

None. No API model, networking, repository or contract change. `VersionOutdatedDetails` (426) and `VersionPolicy`
(check-app-version) are used as they are.

## What changed

- A blocking, full-screen "Update required" screen over the whole app (login and tabs), shown when the server's
  version policy says `forceUpdate` or any API call returns 426. No dismissal, no sign-out, no state cleared; when the
  policy clears (Check again, or a later check says ok) the app is where it was.
- A dismissible "Update available" alert (Update, Later) when the policy says `updateRecommended`. Later hides it for
  that `latestVersion` until the next launch or a newer version (in memory only).
- Update opens an `itms-services` link built from the server's `manifestUrl` by one tested type (`UpdateInstallLink`);
  no link means no Update button and the line "Ask the person who sent you the app for the update link."
- `UpdateGate` decides none, recommended or required from the latest policy and the latest 426, newest wins.
- Cadence: check on launch, and again when the app becomes active, at most once per 15 minutes. A failed check keeps
  the last policy and never blocks or shows an error.
- Mock launch argument `-mockVersionState <ok|recommended|required|requiredNoLink>` (mock mode only, ignored in a
  production build).
- Tests: app 4679 to 4786 (V1 +64, V2 +43); TrackerAPI 212 unchanged. Reports: `Docs/reports/VER1-1-gate.md`,
  `VER1-2-screens.md`, `VER1-3-handoff.md`. Brief: `Docs/epics/VER1-update-prompt.md`.

## Commits (`git log --oneline master..HEAD` before this handoff commit)

```
690e25f VER1: show the update screens
c141e39 VER1: add the install link and the update gate
17b8efc VER1: add epic brief and inventory
```

The handoff commit (`VER1: add the package handoff note`) follows these.

## What the API team must do

Nothing. For this to work the version-check data (and the 426 body) must contain:
- `manifestUrl`: either the `https` URL of the manifest plist (the client builds the `itms-services` link), or exactly
  `itms-services://?action=download-manifest&url=<https url>`. Anything else (http, other scheme, userinfo, over 2048
  characters, a non-https inner URL) is treated as "no link" and the screen asks the person to find the update link.
  `policy:set --manifest-url` already stores the https form from `install-info`.
- A sensible `minimumBuild` and `minimumVersion`: they are shown on the screen ("Required: 2.0 (40)"). Raising them
  blocks every older build (see the runbook warning); raise only after every phone has the new build.
- Release notes (`--notes`) are shown as plain text (500 characters on the blocking screen; the alert shows them only
  when 200 or shorter).

## Open risks and deviations

- **A sheet already open inside the app stays above the cover.** If a 426 arrives while a sheet is up (add-item,
  biometric setup), that sheet is a separate presentation layer and is not covered or hidden from VoiceOver until it
  closes. A full fix needs a window-level cover, which this package was told not to touch. Banked.
- The install itself only works on a real device over a real HTTPS link; the simulator cannot install. Nobody has
  tapped Update on a device.
- Nobody, agent or human, has looked at the screens: previews were compiled but not viewed. VoiceOver "title first" is
  sort priority plus a hidden brand text, not programmatic focus.
- The brief's "anchoring rule in CLAUDE.md" does not exist; the recommended prompt is a root `.alert`.
- The mock policy uses reserved `.invalid` manifest URLs in `MockVersionState.swift` (mock-only; no view has a URL
  literal, a scan proves it).
- A newer policy of any state supersedes an older 426 (so a relaxed minimum does not trap the user); a 426 at or after
  the newest policy blocks. Say if you want the stricter reading ("a 426 stays until an ok policy").
- Tapping Update also dismisses the recommended alert for that version (otherwise it re-presents at once).
- `UpdateInstallLink` is a little loose in two low-risk places: an uppercase `HTTPS` scheme is accepted, and a host
  containing a backslash is not rejected (only `@`, `/`, `?`, `#` are checked). The value only travels as an encoded
  query value to `itms-services`.
- A failed check counts toward the 15 minute interval, so a failure delays the next active-check.
- A few lines are 121 to 129 characters (warning limit 120).

## Section 9 of PROGRAM.md (one line)

VER1 (iOS, 2026-11-15): update prompt shipped on `feat/ver1-update-prompt` (blocking "Update required" screen for forceUpdate or 426, dismissible "Update available" alert, Update opens the `itms-services` link built from `manifestUrl`, check on launch and when active at most every 15 minutes); no contract change, nothing for the API team; real-device install untested; a sheet already open stays above the cover.

## Brian's real-mode check

State at handoff: Brian has not run any of these checks (all NOT PERFORMED). The agents never saw the simulator; the
previews were compiled by the build but nobody looked at them. In Debug, set the mode and state with launch
arguments (Edit Scheme, Run, Arguments): `-apiModeOverride mock -mockVersionState required`. Both are ignored by a
production build. Valid states: `ok`, `recommended`, `required`, `requiredNoLink`.

1. **Required, mock.** Launch with `-apiModeOverride mock -mockVersionState required`.
   - Expect: the full-screen Update required screen over the login screen, no way to dismiss it (try swipe down and
     tapping outside), an Update button and a small Check again button.
   - Check again: Expect a spinner, then the screen stays (the mock still says required).
2. **Required, signed in.** The mock state is fixed at launch, so this needs the local API (real mode). Sign in to the
   local API with the Debug build, then run `policy:set` on the backend with `--min-build` above the app's build,
   `--minimum-version` and a `--manifest-url`, then pull to refresh a list (or relaunch, or background the app for
   15 minutes and return).
   - Expect: the screen covers the tabs; no sign-out happens; after you lower `--min-build` again and tap Check again,
     the screen clears and the app is where it was.
   - Note: if a sheet was open when the 426 arrived it stays above the cover until closed (known, see open risks).
3. **Update button.** On the screen from step 1, tap Update.
   - Expect: iOS asks to open the install link (the simulator cannot install; a real device offers "Install"). No
     crash. The mock manifest is a reserved `.invalid` host, so nothing will install from it.
4. **No link.** Launch with `-mockVersionState requiredNoLink`.
   - Expect: the sentence "Ask the person who sent you the app for the update link." and no Update button; Check
     again is still there.
5. **Recommended.** Launch with `-mockVersionState recommended`, wait for the login screen.
   - Expect: an Update available alert with "Version <latest> is available." and Update and Later. Tap Later: the alert
     closes and does not come back until you relaunch.
6. **Large type and dark mode.** Repeat step 1 in dark mode and at the largest accessibility text size.
   - Expect: readable, scrollable, no clipping; Update and Check again reachable by scrolling.
7. **VoiceOver (optional).** Turn VoiceOver on and launch as in step 1.
   - Expect: "Update required" is read first as a heading; the login screen behind is not reachable; the button reads
     "Update Christmas Tracker".
8. **Real device (optional, release rehearsal).** On a phone with an older build, point the version policy at a newer
   build (`policy:set` on the API, per `Docs/release-runbook.md`) and open the app.
   - Expect: the screen (or alert) shows and Update starts a real install.

Checks Brian ran: none recorded. Checks NOT PERFORMED: all eight. The agents never saw the simulator.
