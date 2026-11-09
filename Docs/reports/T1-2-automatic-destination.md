# T1-2 — Automatic simulator destination

**Date:** 2026-11-09 · **Branch:** `chore/xcode-27-test-settings` · **Toolchain:** Xcode 27.2 (27B52)

## What changed

Files added:
- `scripts/lib/destination.sh` — sourced library defining `resolve_destination` (mode 644, sourced only).
- `scripts/test-destination.sh` — stub-and-fixture test harness (17 tests, executable).
- `Docs/reports/T1-2-automatic-destination.md` — this report.

Files changed:
- `scripts/build.sh` — the `DEST="${DEST:-...OS=latest}"` line replaced by `source "scripts/lib/destination.sh"` and
  `DEST="$(resolve_destination)" || exit 1`. Nothing else.
- `scripts/test.sh` — same two-line replacement. Nothing else.
- `scripts/verify.sh` — one added step ("destination script tests") before the prohibited-frameworks check.
  No existing step or output format changed.

`resolve_destination` behavior (READ from `scripts/lib/destination.sh`):
1. If `DEST` is set and non-empty, print it unchanged and return 0 (no simctl call).
2. Else run `${SIMCTL:-xcrun simctl} list devices available -j` and select with jq: iOS runtimes only (key matches
   `.iOS-<digits>`), available devices whose name starts with `iPhone`, the highest numeric runtime version
   (so 26.10 beats 26.5), then `iPhone 17 Pro` if present, else the first iPhone by name then udid.
   Runtimes with the same version (for example `iOS-27-2` and the `iOS-27-2-iPhone19-4` variant) are pooled.
3. Print `platform=iOS Simulator,id=<udid>` on stdout and one `destination: ...` info line on stderr.
4. No match: stderr says to install an iOS simulator runtime in Xcode Settings, Components; return 1.
   Malformed or wrong-shaped JSON, or a failing simctl: a clean one-line error, return 1.

Second place with the old default: none. `grep` for `iPhone 17 Pro` / `OS=latest` over `scripts/` found only
the comment and jq preference inside the new library (no `release.sh` or `verify.sh` default).

## Verification

Each claim says whether it came from running a command (RAN) or reading code (READ).

- RAN: `scripts/test-destination.sh`:

```
=== test-destination.sh: 17 passed, 0 failed ===
```

  The 17 tests: DEST override (unchanged, simctl not called); newest of several runtimes; numeric not lexical
  version order; runtime without an iPhone skipped; non-iOS runtimes ignored; iPhone 17 Pro preferred; otherwise
  first iPhone by name; same-version runtimes pooled; unavailable device ignored; unavailable-only newest runtime
  falls back; no runtime gives non-zero plus install message; only-unavailable gives the same; malformed JSON; wrong-shape
  JSON; failing simctl; info line reported once with clean stdout; stub was the only simctl used.
- RAN: `bash -n` on each of `scripts/lib/destination.sh`, `scripts/build.sh`, `scripts/test.sh`, `scripts/verify.sh`,
  `scripts/test-destination.sh` (one call per file): no output, exit 0.
- RAN: `shellcheck -x` on the same five files (shellcheck at `/opt/homebrew/bin/shellcheck`): no output, exit 0.
- RAN (real simctl, read-only, outside the tests): `source scripts/lib/destination.sh; resolve_destination` printed
  `destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)`.
  `DEST="x y"` printed `x y`.
- RAN: `scripts/verify.sh` with no `DEST` (automatic destination, iOS 27.2 runtime) before the commit. Headings and
  summary lines (per-test lines trimmed with grep):

```
=== verify: derived spec ===
=== verify: build ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
** BUILD SUCCEEDED **
=== verify: configuration check ===
=== verify: unit tests ===
destination: platform=iOS Simulator,id=75A7BAE2-47DA-428F-BE13-B49B9135A6B9 (iPhone 17, iOS 27.2)
--- xcodebuild exit status: 0 ---
--- tests: 677 passed, 0 failed, 0 skipped ---
=== verify: TrackerAPI package tests ===
􁁛  Test run with 191 tests in 13 suites passed after 0.019 seconds.
=== verify: TrackerAPI import audit ===
=== verify: release script tests ===
=== test-release.sh: 62 passed, 0 failed ===
=== verify: destination script tests ===
=== test-destination.sh: 17 passed, 0 failed ===
=== verify: prohibited frameworks in changed lines ===
=== verify: OK ===
```

  Exit status 0. This run is also the after-commit run for T1A (the T1A commit `feeba51` was already in place),
  and it shows the app suite passing on the iOS 27.2 runtime: 677 passed.
- Verify after this story's commit: recorded in the T1-3 handoff report (appending here would need another commit).

## Test arithmetic

- App tests: 677 + 0 - 0 = 677 (unchanged, on iOS 27.2).
- TrackerAPI package tests: 191 unchanged. Release script tests: 62 unchanged.
- New: 17 destination script tests (a new harness, counted separately; it is one added `verify.sh` step).

## Gate 2

- convention-reviewer: APPROVE, no blocks and no warnings. Evidence: five permitted paths only (`git status --short`);
  `build.sh:4-5`, `test.sh:6-7` change only the DEST line; `verify.sh:27-28` is exactly one added step; no
  `DispatchQueue` or `import Combine` in the changed files; `bash -n` and `shellcheck -x` clean; style matches
  `test-release.sh`. Nits (non-blocking): `test-destination.sh:6` uses `set -uo pipefail` without `-e`
  (deliberate, failures are tallied); FAIL lines go to stderr as in `test-release.sh`.
- acceptance-reviewer: APPROVE. Focus answers:
  (5) DEST first at `destination.sh:16-19`, asserted at `test-destination.sh:75-79` with an empty call log; newest by
  numeric version at `destination.sh:32-42` (tests `:81-94`); 17 Pro preference `destination.sh:43-44` (tests `:111-121`);
  clear failure `destination.sh:52-57` (tests `:143-151`); `run_resolve` (`:56`) always sets SIMCTL to the stub, and the
  last test (`:175-177`) asserts the stub log.
  (6) `build.sh` and `test.sh` differ only by the two destination lines; the `cd` precedes `source`, so the relative path
  works; flags, LOG, RESULT, parsing, and exit handling untouched; a resolver failure exits 1 before xcodebuild.
  Edge probes by the reviewer (stub only): `iOS-27-2-iPhone19-4` parses as 27.2; `iOS-26-10` as 26.10; keys with no or
  a non-numeric version are skipped; names with spaces, apostrophes, and accents work; `DEST=""` falls through to
  auto-detection; `SIMCTL="stub.sh list extra"` is word-split into command and arguments.
  Reviewer notes: `verify.sh` also gained a step (expected; stated above).
- Rejections and re-reviews: none.
- Stuck detector: 1 attempt, no repeated error signature.

## Deviations, bugs, scope

- `DEST="  "` (whitespace only) is non-empty, so it is passed through unchanged as the story literally says; xcodebuild
  would then reject it. Not changed.
- A `SIMCTL` path containing spaces would be word-split (the default `xcrun simctl` needs the splitting). Documented limit.
- The automatic choice on this Mac is `iPhone 17` (iOS 27.2) because `iPhone 17 Pro` is not present on that runtime;
  this follows the specified rule (first iPhone by name).
- The destination is now an `id=` destination; the old default used `name=...,OS=latest`. Anyone relying on the old
  default must set `DEST`, which still wins.
- An extra `destination: ...` line now appears on stderr (build and test each print one); it is not written to the logs.
- No real bugs found elsewhere. Nothing outside the permitted files was touched.

## Not done or partial

- `scripts/release.sh` and `scripts/test-release.sh` were not changed or examined for destination use beyond the grep.
- The after-commit `verify.sh` run for this story is in the T1-3 report, not here.
- UI tests were not run; `verify.sh` does not run them.
