# LG1-L1: instrumentation helper

## What changed
- New `Core/Logging/OperationLogging.swift`: `OperationLogging` protocol, `AppOperationLog`, `LogVerbosity`.
- New `Core/Logging/InstrumentedOperation.swift`: `InstrumentedOperation.run`.
- New tests under `ChristmasTrackerTests/Core/Logging/`: `InstrumentedOperationTests.swift` (8 tests), `CapturingOperationLog.swift` (shared capturing sink).
- Behavior: Sentry transaction named by the operation; in verbose mode a signpost begin/end (.performance) and one `.debug` `.performance` line `<name> finished in <n> ms` / `<name> failed after <n> ms` / `<name> cancelled after <n> ms`. Span status .ok / .internalError / .cancelled. The same error is rethrown; the error is never interpolated. Non-verbose: no signpost, no log line (Sentry span still runs, like the hand spans).

## Commands and raw output
- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- `scripts/test.sh ChristmasTrackerTests/InstrumentedOperationTests`: `tests: 8 passed, 0 failed, 0 skipped`
- `scripts/test.sh` (full): `tests: 5418 passed, 0 failed, 0 skipped` (baseline 5410 + 8)
- Attempts: 1; no failures, no stuck-detector trigger.

## Deviations
- The implementation was written before the tests, so the red step was not observed (the tests could not compile without the types).
- `now:` is a closure time source (not a Clock generic) for test injection; `isolation: isolated (any Actor)? = #isolation` lets @MainActor callers touch their state.
- Test file holds two small private helper types (error, step clock) besides the suite.
- Signposts are emitted only in verbose mode (Release stays quiet).

## Not done or partial
None. (No screenshot: no UI.)
