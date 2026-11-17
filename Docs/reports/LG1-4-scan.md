# LG1-L4: service logging scan tests (solo)

## What changed
Tests only, all new, under `ChristmasTracker/ChristmasTrackerTests/Core/Logging/` (one type per file):
- `ServiceSourceWalk.swift`: walks the app tree (via `ItemSourceTree.load(from: #filePath)`), finds service files, and holds the shared
  "calls a repository" detection (`try await ... *Repository` on a line, or `client.x`) and "writes a log line" detection.
- `ServiceLogsWhenCallingScanTests.swift`: rule R1.
- `LogCallDataScan.swift` (scanner, string and nested-interpolation aware) and `LogCallDataScanTests.swift`: rule R2.
- `ServiceInstrumentationRule.swift` (logic, documented empty `knownExceptions`) and `ServiceInstrumentationScanTests.swift`: rule R3.

No production file is changed (the deliberate breaks were reverted; `git status` shows only the six new test files plus this report).
`ServiceLogCallScanTests` is untouched; R2 reuses its `ServiceLogCallScan.violations` for step calls and `let op`.

## Rules and tests
- R1 "service logs when it calls": `ServiceLogsWhenCallingScanTests/servicesLogWhenTheyCall`, `walkIsNotVacuous` (>= 10 service files,
  >= 8 calling a repository), self-proofs `detectsRepositoryCalls`, `ignoresNonCalls`, `detectsLogLines`.
- R2 "no data in a log call": `LogCallDataScanTests/serviceAndTransportLogCallsCarryNoData` (all `*Service.swift` + `LoggingClientTransport.swift`;
  asserts >= 11 files, >= 10 `Log*(` calls, >= 4 transport `log.log(` calls), self-proofs `scannerFires` (18 inputs incl.
  `LogError("x \(price)")`, `log.processed(notes)`, `runManagement(..., op: "x \(id)")`), `scannerAllows` (22 inputs),
  `scannerReadsLinesAndStrings`. Allowed interpolations are the explicit set `LogCallDataScan.allowedNames` plus `method.rawValue`,
  `<path>.count`, `parts.joined(separator: ", ")`.
- R3 "new service file must be instrumented": `ServiceInstrumentationScanTests/serviceFilesAreInstrumented`, `walkIsNotVacuous` (>= 20 files,
  >= 8 calling), self-proofs `uninstrumentedFails`, `instrumentedPasses`, `nonCallingFileIsExempt`. Known exceptions: empty set.

## Deliberate breaks (reverted)
R1: temp `Features/Children/Services/TempBreakService.swift` (repository call, no log):
```
--- tests: 9 passed, 1 failed, 0 skipped ---
FAIL ServiceLogsWhenCallingScanTests/servicesLogWhenTheyCall(): Expectation failed: silent.isEmpty
isEmpty → false: Service files call a repository but never log: ["Features/Children/Services/TempBreakService.swift"]
```
R3: temp `Features/Children/Services/TempBreakFlow.swift` (repository call, no instrumentation, not named *Service so R1 stays green):
```
--- tests: 9 passed, 1 failed, 0 skipped ---
FAIL ServiceInstrumentationScanTests/serviceFilesAreInstrumented(): Expectation failed: missing.isEmpty
isEmpty → false: Calls a repository with no @Instrumented / InstrumentedOperation: ["Features/Children/Services/TempBreakFlow.swift"]
```
R2: `ItemService.swift` line 202 temporarily `LogInfo("Created item \(listId)", category: .business)`:
```
--- tests: 3 passed, 1 failed, 0 skipped ---
FAIL LogCallDataScanTests/serviceAndTransportLogCallsCarryNoData(): Expectation failed: found.isEmpty
found → ["LogInfo( interpolates `listId` at line 202"]
```
All three reverted (files deleted, text restored with Edit).

## Commands
- `scripts/test.sh ChristmasTrackerTests/ServiceLogsWhenCallingScanTests ChristmasTrackerTests/LogCallDataScanTests ChristmasTrackerTests/ServiceInstrumentationScanTests ChristmasTrackerTests/ServiceLogCallScanTests`
  - first run: `17 passed, 1 failed` (my `scannerAllows` fixture used `request.method.rawValue`, not an allowed shape; fixture changed to `method.rawValue`)
  - final run, after reverting every break: `--- xcodebuild exit status: 0 ---`, `--- tests: 18 passed, 0 failed, 0 skipped ---`
- `git status --short`: only the six new files under `ChristmasTrackerTests/Core/Logging/` (this report is added after).

## Deviations
- The R2 scan does not allow `request.method.rawValue`; only the transport's `method` local (and `method.rawValue`). Stricter than needed, not looser.
- `scripts/verify.sh` not run (per instruction); the full suite was not run, only the four scan suites.

## Not done or partial
- No real violation was found: every scan passed on the committed code with no production change.
- Detection is regex and line based: a repository call reached through an unrelated variable name (not ending in `repository`, not `client.`) is not seen.
- Not committed (per instruction).
