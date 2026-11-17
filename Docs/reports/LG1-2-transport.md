# LG1-2: logging transport

## What changed
- New `ChristmasTracker/ChristmasTracker/Core/API/LoggingClientTransport.swift`: `nonisolated final class LoggingClientTransport: ClientTransport, Sendable`, `init(wrapping:log:verbosity:now:)`, `send(_:body:baseURL:operationID:)`, `static func production()`.
- New `ChristmasTracker/ChristmasTracker/Core/API/TransportErrorCategory.swift`: pure mapping of `URLError.Code` / `CancellationError` to timeout, offline, dns, tls, other; cancellation detection. Never reads an error description.
- `ChristmasTracker/ChristmasTracker/ChristmasTrackerApp.swift`, inside `buildGeneratedClient`, the single `TrackerClientFactory.make(` call only.

Before:
```
            requestIDObserver: requestIDObserver,
            sessionEndingHandler: sessionEndingHandler
        )
```
After:
```
            requestIDObserver: requestIDObserver,
            sessionEndingHandler: sessionEndingHandler,
            transport: LoggingClientTransport.production()
        )
```

## Attempt numbers
A lock-protected dictionary (NSLock in a private `@unchecked Sendable` final class) is keyed by the `X-Request-Id` request header. Each send increments the count for that id. The entry is discarded after any outcome except a 401 or 429 response, and after any throw. With no header, every send is attempt 1. The clock is read exactly twice per send.

## Gate 2 rework
- Bounded counter: the attempt counter holds at most 64 request ids (insertion order kept in an array). A 65th distinct id evicts the oldest. `var trackedRequestCount: Int` (internal, synchronous) exposes the size for tests; a discarded id is removed from both the dictionary and the order list.
- Request id sanitizing: a request id is logged only if 1 to 64 characters, all in [A-Za-z0-9-]. The response id is used if valid, else the request-header id if valid, else the id part is omitted. The counter still keys on the raw request header id (bounded to 64 entries).
- The two source lines over 120 characters were wrapped; no line in the file exceeds 120.
- Leak tests are in `LoggingTransportLeakTests.swift` (with `LoggingTransportTestSupport`, `LoggingTransportAttemptTests`, `LoggingTransportRequestIDTests`).
- Rework run: `scripts/build.sh` succeeded; `scripts/test.sh`: exit 0, `5461 passed, 0 failed, 0 skipped`; `swift test` on TrackerAPI: `212 tests in 16 suites passed`. Green on the first attempt.

## Build and test (original run)
- `scripts/build.sh`: `** BUILD SUCCEEDED **`
- First `scripts/test.sh` run: exit 65, 0 tests, because the composition test file lacked `import TrackerAPI` (test-writer fixed it).
- `scripts/test.sh` after the fix: `xcodebuild exit status: 0`, `tests: 5449 passed, 0 failed, 0 skipped` (baseline was 5410).
- `swift test --package-path "LocalPackages/TrackerAPI"`: `Test run with 212 tests in 16 suites passed`.
- One test attempt after the fix; no stuck-detector trigger.

## Deviations
None. Tests were not edited by the implementer. `scripts/verify.sh` was not run, as instructed.

## Not done or partial
None for this story. No test judged wrong. Visual check not applicable (no UI).
