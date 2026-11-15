# VER1-3: package handoff

Branch `feat/ver1-update-prompt`. Docs only.

## What changed

- `Docs/handoffs/2026-11-15-ios-to-brian-ver1.md`: contract issues (none), what changed, commits, what the API data
  must contain, open risks, the PROGRAM.md section 9 line, and Brian's real-mode check (eight numbered steps with the
  `-mockVersionState` launch argument for each state and the local-API steps).
- This report.

## Commands and raw output

`scripts/verify.sh` after the V2 commit (summary lines):
```
** BUILD SUCCEEDED **
--- xcodebuild exit status: 0 ---
--- tests: 4786 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.051 seconds.
```
`git log --oneline master..HEAD` before the handoff commit:
```
690e25f VER1: show the update screens
c141e39 VER1: add the install link and the update gate
17b8efc VER1: add epic brief and inventory
```

## Deviations

- Step 2 of Brian's check ("required, signed in") cannot use the mock launch argument because the mock state is fixed
  at launch and the cover blocks the login screen. It is written against the local API (`policy:set`).

## Not done or partial

- None of Brian's eight checks were run; the agents never saw the simulator. Real-device install is untested.
- The sheet-above-cover limitation is banked (see the handoff, open risks).
