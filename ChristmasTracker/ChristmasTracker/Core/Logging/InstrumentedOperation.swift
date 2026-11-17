//
//  InstrumentedOperation.swift
//  ChristmasTracker
//
//  Performance wrapper for functions that cannot use @Instrumented (for example @MainActor service
//  methods). Starts a Sentry transaction and a signpost named by the operation, measures the
//  duration with a monotonic clock, finishes the span with a status, and in verbose (Debug) mode
//  logs one .debug line. The operation name is the only variable that reaches a span or a line;
//  the thrown error is never interpolated and is rethrown unchanged.
//

import Foundation
import Sentry

nonisolated enum InstrumentedOperation {

    /// Runs `operation` inside a span named `name`. Runs on the caller's isolation, so a
    /// `@MainActor` caller may touch its own state in the closure.
    /// - Parameters:
    ///   - log: sink for the single duration line (verbose mode only).
    ///   - verbosity: when not verbose, the helper logs and signposts nothing.
    ///   - now: monotonic time source, injectable for tests.
    static func run<T>(
        _ name: String,
        log: any OperationLogging = AppOperationLog(),
        verbosity: LogVerbosity = .current,
        now: @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now },
        isolation: isolated (any Actor)? = #isolation,
        _ operation: () async throws -> T
    ) async throws -> T {
        let span = SentrySDK.startTransaction(name: name, operation: name)
        let signpostID: UUID? = verbosity.isVerbose ? Logger.shared.signpostBegin(name) : nil
        let start = now()

        func finish(_ status: SentrySpanStatus, _ verb: String) {
            let ms = milliseconds(from: start, to: now())
            span.finish(status: status)
            if let signpostID { Logger.shared.signpostEnd(name, id: signpostID) }
            if verbosity.isVerbose {
                log.log(.debug, "\(name) \(verb) \(ms) ms", category: .performance)
            }
        }

        do {
            let value = try await operation()
            finish(.ok, "finished in")
            return value
        } catch let cancellation as CancellationError {
            finish(.cancelled, "cancelled after")
            throw cancellation
        } catch {
            finish(.internalError, "failed after")
            throw error
        }
    }

    private static func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Int {
        let parts = start.duration(to: end).components
        return Int(max(0, parts.seconds)) * 1000 + Int(max(0, parts.attoseconds) / 1_000_000_000_000_000)
    }
}
