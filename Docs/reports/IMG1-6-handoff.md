# IMG1-6: the package handoff note
Branch: feat/img1-link-preview. Docs only; no code change.

## What changed
- Docs/handoffs/2026-11-15-ios-to-brian-img1.md: contract issues (none), what changed, commits, what the API team must do (nothing; the egress risk), open risks (the non-public key path and App Store release blocker with the required sentence, the measured retailer results, nothing run on a simulator or network, rate limit, the fill-rule edges, the derived-spec incident, the verify.sh word check), the PROGRAM.md section 9 line, and Brian's real-mode check as a numbered list of 17 steps with an "Expect:" each.

## Commands and raw output
Before this commit, `scripts/verify.sh` (code unchanged since bf56a2e):
```
--- tests: 5320 passed, 0 failed, 0 skipped ---
Test run with 212 tests in 16 suites passed after 0.021 seconds.
=== verify: OK ===
```
Package-end diff (`git diff --name-only master...HEAD`, taken before this docs commit): nothing under contract/, .claude/, any .pbxproj or the synced Docs files (client-guide, error-codes, DECISIONS, PRD, privacy-matrix) changed. LocalPackages/ shows one file, `LocalPackages/TrackerAPI/Sources/TrackerAPI/openapi.json`, from commit c34f44c ("chore: regenerate derived client spec"), which Brian made before P1, not an agent. ChristmasTrackerApp.swift shows the approved 5-line edit.

## Which checks were run
Brian's real-mode check was NOT PERFORMED: none of its 17 steps was run, and the agents never saw the simulator or the network.

## Deviations
None.

## Not done or partial
- The whole real-mode check (see above).
- The release blocker (the non-public key path) is documented, not resolved; it must be handled before any App Store submission.
