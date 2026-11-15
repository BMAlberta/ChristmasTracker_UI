# TH1.1 Step 4: handoff

## What changed

- Added Docs/handoffs/2026-11-14-ios-to-brian-th1-1.md: contract issues (none), what changed, the commit list, what the API team must do (nothing), open risks, one line for section 9 of PROGRAM.md, and Brian's real-mode check as a numbered list with an "Expect:" per step.
- Docs only. No code, test, contract, .claude or pbxproj change.

## Commands and raw output

`git log --oneline master..HEAD` before this commit:

```
48dda24 TH1.1: apply the destructive look to every destructive control
8bfadfd TH1.1: give Logout the destructive look
e810d84 TH1.1: add epic brief and inventory
```

Last `scripts/verify.sh` (after the A2 commit; this commit is docs only, and verify is re-run after it, see the final message):

```
--- tests: 4638 passed, 0 failed, 0 skipped ---
􁁛  Test run with 212 tests in 16 suites passed after 0.018 seconds.
=== verify: OK ===
```

## Deviations

- Step 5 of the real-mode check ("one more per audit row that changed") has no extra steps, because the audit changed only the Logout pair already covered by steps 1 and 2. The handoff says so.

## Not done or partial

- Brian's real-mode check: NOT PERFORMED. The agents never saw the simulator, and the check is for Brian to run.
- Visual verification of the new Logout look: NOT PERFORMED, for the same reason.
