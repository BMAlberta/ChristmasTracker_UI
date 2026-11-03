# Setup Report — chore/ios-setup

**Date:** 2026-11-02  
**Branch:** chore/ios-setup  
**Objective:** Finish iOS agent setup (items 1–7)

---

## Files Changed

| Item | Files |
|---|---|
| 1 | `.claude/agents/convention-reviewer.md`, `.claude/agents/acceptance-reviewer.md`, `.claude/agents/implementer.md`, `.claude/agents/test-writer.md` |
| 2 | `Docs/process/coding-standards.md`, `Docs/process/testing-conventions.md` |
| 3 | `LocalPackages/TrackerInstrumentation/Package.swift`, `Sources/TrackerInstrumentation/Instrumented.swift`, `Sources/TrackerInstrumentationMacros/InstrumentedMacro.swift`, `Tests/TrackerInstrumentationTests/InstrumentedMacroTests.swift` |
| 4 | `scripts/build.sh`, `scripts/test.sh`, `scripts/verify.sh` |
| 5 | `AGENTS.md` (new), `ChristmasTracker/AGENTS.md` (deleted), `Docs/AGENTS.md` (deleted), `Docs/epics/README.md`, `Docs/reports/README.md`, `Docs/contract-issues.md` |
| 6 | `CLAUDE.md`, `contract/STATUS.md` |

---

## Item 3 — Macro Test Output

```
swift test --package-path "LocalPackages/TrackerInstrumentation"

Build complete! (43.26s)
Test Suite 'All tests' started at 2026-11-02 15:20:15.435.
Test Suite 'TrackerInstrumentationPackageTests.xctest' started.
Test Suite 'InstrumentedMacroTests' started.
Test Case '-[InstrumentedMacroTests testInstrumentedAsync]' passed (0.001 seconds).
Test Case '-[InstrumentedMacroTests testInstrumentedAsyncThrowing]' passed (0.000 seconds).
Test Case '-[InstrumentedMacroTests testInstrumentedSync]' passed (0.000 seconds).
Test Case '-[InstrumentedMacroTests testInstrumentedThrowing]' passed (0.000 seconds).
Test Case '-[InstrumentedMacroTests testRequiresBody]' passed (0.000 seconds).
Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.002) seconds
```

All 5 macro tests passed.

---

## Item 7 — verify.sh BASELINE

### Simulator note

The scripts default to `platform=iOS Simulator,name=iPhone 16 Pro`. This machine does not
have a simulator with that exact name — the available device is `iPhone 16 Pro (26.4)`
(id `BDA94E1A-7F5D-4689-A195-7F293ECC57A6`). The build was re-run with
`DEST="platform=iOS Simulator,id=BDA94E1A-7F5D-4689-A195-7F293ECC57A6"` to get the actual
build output.

### Build result: BUILD FAILED

Swift compilation and linking: **SUCCEEDED**  
Resource copy phase: **FAILED — 20 errors**

First errors:
```
CpResource .../ChristmasTracker.app/11_Phase_6-5_Purchase_Management_Part3.pdf
  .../Docs/11_Phase_6-5_Purchase_Management_Part3.pdf
  (no such file)
CpResource .../ChristmasTracker.app/11_Phase_6-5_Purchase_Management_Part1.pdf
  ...
CpResource .../10_Phase_6_Implementation_Guide_Part3.pdf ...
CpResource .../10_Phase_6_Implementation_Guide_Part2.pdf ...
CpResource .../11_Phase_6-5_Purchase_Management_Part2.pdf ...
CpResource .../10_Phase_6_Implementation_Guide_Part1.pdf ...
CpResource .../10_Phase_5_Supplement_Sections_1-10.pdf ...
CpResource .../09_Phase_5_Supplement_Sections_11-14.pdf ...
CpResource .../08_Phase_5_Implementation_Guide_Part2.pdf ...
CpResource .../08_Phase_5_Implementation_Guide_Part1.pdf ...
CpResource .../07_Phase_4_Implementation_Guide.pdf ...
CpResource .../06_Phase_3_Implementation_Guide_Part2.pdf ...
CpResource .../06_Phase_3_Implementation_Guide.pdf ...
CpResource .../05_Phase_2_Implementation_Guide.pdf ...
CpResource .../04_Phase_1_Implementation_Guide.pdf ...
CpResource .../03_Design_System_Specification.pdf ...
CpResource .../02_Project_Structure_Blueprint.pdf ...
CpResource .../01_Architecture_Decision_Record.pdf ...
CpResource .../00_Implementation_Phases_Overview.pdf ...
Building project ChristmasTracker with scheme ChristmasTracker
(20 failures)
```

**Root cause:** `project.pbxproj` still references 20 PDF implementation guide files that no
longer exist in the repo. The `.md` stale references were removed before this session, but
the PDF references were not. This is the P0 blocker documented in `Docs/ios-state-audit.md`
Section 2.

**Unit tests:** NOT RUN (build did not produce a runnable app bundle).

---

## Not done or partial

- **Item 1 agent files** cannot be staged via `git add .claude/agents/` because the
  `guard-bash.sh` hook blocks shell commands on `.claude/` paths. The files were written
  correctly via the Write tool. To include them in a commit, run:
  ```
  ! git add .claude/agents/
  ```
  then commit with an appropriate message.

- **Build baseline:** BUILD FAILED. The 20 PDF `CpResource` errors are the P0 blocker
  (stale references in `project.pbxproj`). Swift compilation succeeded. This is the
  recorded baseline — not fixed here per instructions.

- **Default simulator name mismatch:** `scripts/build.sh` and `scripts/test.sh` default to
  `name=iPhone 16 Pro`, but no such simulator exists (closest: `iPhone 16 Pro (26.4)`).
  Override with `DEST="platform=iOS Simulator,id=BDA94E1A-7F5D-4689-A195-7F293ECC57A6"` or
  update the default after creating the correct simulator.
