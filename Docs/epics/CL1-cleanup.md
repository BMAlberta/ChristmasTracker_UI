# CL1 — Cleanup after VER1, PH1 and IMG1

Branch: `feat/cl1-cleanup` (from master at the IMG1 merge, 3654b03).
Small, low-risk package. No screens, no contract, no user-visible behavior except where a story says so.
Every story is independent: if one cannot be finished safely, stop that story, report why, go on.

## Baseline (Step 0)

- `scripts/verify.sh`: OK. App tests: 5320 passed, 0 failed, 0 skipped.
- `swift test --package-path "LocalPackages/TrackerAPI"`: 212 tests in 16 suites passed.

## Decisions

1. Behavior-preserving: C3 (line lengths) and C4 (file split) change no behavior. C1 and C2 change behavior only in the stated ways.
2. A test is never weakened or deleted to get green. A test is edited only to follow a moved file or a stated
   behavior change, marked `EDITED (CL1-<story>): <reason>` and listed in the story report.
3. Out of scope: ListService.swift and its split, a window-level cover for sheets over the update screen, the Delivered
   status dot color, the unused `budgetWarning` token and the dark-mode Gifted pill edge, PH1 reload-on-return behavior,
   the IMG1 fill rules, the device image fallback, theme colors, the contract, any API behavior.

## Gate 1 spec

No new interface is introduced in any story (C1 and C2 change internals of existing types; C4 moves code; C3 and C5
touch whitespace and docs). Solo path per CLAUDE.md, with the convention-reviewer on every story and the
acceptance-reviewer on the package.

### C1 — Install link edges

Contract slice: none. Files: `Features/Version/UpdateInstallLink.swift`, `Features/Version/UpdateInstallLinkTests.swift`.
Acceptance:
- The `https` scheme is matched case-insensitively; the built link always carries lowercase `https://`.
- The authority (text before the first `/`, `?` or `#`) is rejected (nil) if it contains a backslash, whitespace or a control character.
- An `itms-services` input is accepted only if its decoded inner URL passes the same rules and re-encodes to exactly the same value (rule unchanged).
- New tests: uppercase and mixed-case scheme build the lowercase link; backslash, space, tab, newline and a control
  character in the host give nil. Every existing case passes unchanged.

### C2 — A failed version check must not use up the interval

Files: `Core/API/VersionService.swift`, `Features/Version/VersionServiceCadenceTests.swift`.
Acceptance:
- A successful check records its time; the next automatic check waits 15 minutes (unchanged).
- A failed check records a separate failure time; the next automatic check is allowed after at most 60 seconds.
- A failed check keeps the last policy and never blocks or shows an error (unchanged). Manual `check()` always runs (unchanged).
- Uses the existing clock seam. Tests: success then inside 15 min (no check); success then after 15 min (check);
  failure then 30 s (no check); failure then 61 s (check); failure then success then inside 15 min (no check);
  manual check ignores both times.
- Note: the brief also lists "session end resets both times". `VersionService` holds no session state and is not a
  clearable (the version policy is pre-auth and VER1 clears nothing on sign-out), so there is no session-end reset to
  test. No reset is added; this is reported as a deviation.
- Note: the existing tests `failedAttemptCounts` (60 s after a failure makes no second call) and
  `failedAttemptRetriesAfterInterval` encode the old behavior and will be edited (EDITED marker) to follow the stated change.

### C3 — Line lengths

Files: only lines over 120 characters that VER1, PH1 and IMG1 added, in the folders named in the brief
(Features/Version, PurchaseHistory, LinkPreview, Items, Statistics; Core/API/VersionService.swift; App wiring files;
ChristmasTrackerApp.swift; and the matching test folders). The hit list (file and line) is recorded in the report
before any change. Whitespace and wrapping only; no token changes. Pre-existing long lines from earlier packages are
not touched.

### C4 — Split the app composition file

File: `ChristmasTracker/ChristmasTrackerApp.swift` (548 lines; target 400 or fewer). Pure move into new files
(each under 300 lines, with a header comment) next to the existing wiring files. Same names, access levels and order
of side effects at launch. At most 4 scan tests may be edited to follow the move; otherwise stop and revert.

### C5 — Release runbook note

File: `Docs/release-runbook.md` only. New section "Before any App Store submission" naming the
`APPSTORE-BLOCKER: non-public key path` in `LinkPresentationProductImageProvider.swift`; ad hoc distribution is unaffected.

## Inventory (current line counts)

| Story | File | Lines |
|-------|------|-------|
| C1 | `ChristmasTracker/ChristmasTracker/Features/Version/UpdateInstallLink.swift` | 56 |
| C1 | `ChristmasTracker/ChristmasTrackerTests/Features/Version/UpdateInstallLinkTests.swift` | 190 |
| C2 | `ChristmasTracker/ChristmasTracker/Core/API/VersionService.swift` | 76 |
| C2 | `ChristmasTracker/ChristmasTrackerTests/Features/Version/VersionServiceCadenceTests.swift` | 190 |
| C3 | folders listed above (hit list in `Docs/reports/CL1-3-line-lengths.md`) | — |
| C4 | `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift` | 548 |
| C5 | `Docs/release-runbook.md` | 321 |
