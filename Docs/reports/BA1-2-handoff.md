# BA1 handoff report

Branch `feat/ba1-brand-assets`. Docs only: `Docs/handoffs/2026-11-14-ios-to-brian-ba1.md` and this report. No code, asset or project file change in this commit.

## What the handoff contains

- The fresh-install warning at the top ("Delete the app from the simulator, then build and run it fresh. iOS caches launch screens and icons; a stale one proves nothing.") and again at the head of the check.
- Contract issues (none), what changed, commit hashes from `git log --oneline master..HEAD`, what the API team must do (nothing), open risks, and the one line for PROGRAM.md section 9.
- Brian's real-mode check: seven numbered steps with a bold title, short nested bullets and an "Expect:" bullet each. The launch screen expectation has no title: background color and centered gift only, with the app name shown on the first app screen in the serif design from TH1.
- What is not part of the package: a Face ID or device pass, the web favicon, the tinted icon slot, Icon Composer.

## Checks run and not performed

- Run: `scripts/verify.sh` before and after the previous commits; the raw summary after the story commit (8506820):

```
=== verify: build ===
** BUILD SUCCEEDED **
check-config: all configuration values OK
--- xcodebuild exit status: 0 ---
--- tests: 4647 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.019 seconds.
=== verify: OK ===
```

- Not performed: all seven of Brian's steps. No agent ran the app in the simulator. Brian has not yet run the real-mode check.

## Not done or partial

- The icon and launch screen were never seen running (no simulator run was possible).
- The tinted icon slot is empty, and the web favicon and Icon Composer are out of scope.
- The verify run after this docs commit and the package-end diff are reported in the final message, not in this file, because this file is part of that commit.
