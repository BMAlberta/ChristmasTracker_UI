//
//  InstrumentedOperationTests.swift
//  ChristmasTrackerTests
//
//  Story LG1-L1: the performance helper returns the value, rethrows the identical error, logs one
//  .debug line with only the operation name, treats cancellation as not-a-failure, never leaks the
//  thrown error, and logs nothing when not verbose.
//

import Foundation
import Testing
@testable import ChristmasTracker

private struct SecretError: Error, Equatable, CustomStringConvertible {
    let code: Int
    var description: String { "ZZ-secret-token-\(code)" }
}

/// A clock source that returns a fixed start and then a time `elapsed` later.
private final class StepClock: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let base = ContinuousClock.now
    private let elapsed: Duration

    init(elapsed: Duration) { self.elapsed = elapsed }

    func now() -> ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        calls += 1
        return calls == 1 ? base : base + elapsed
    }
}

@Suite("InstrumentedOperation Tests")
@MainActor
struct InstrumentedOperationTests {

    private let verbose = LogVerbosity(isVerbose: true)
    private let quiet = LogVerbosity(isVerbose: false)

    @Test("returns the operation's value and logs one finished line")
    func returnsValue() async throws {
        let sink = CapturingOperationLog()
        let value = try await InstrumentedOperation.run("op.test", log: sink, verbosity: verbose) { 42 }
        #expect(value == 42)
        #expect(sink.lines.count == 1)
        #expect(sink.lines.first?.level == .debug)
        #expect(sink.lines.first?.category == .performance)
        #expect(sink.lines.first?.message.hasPrefix("op.test finished in ") == true)
    }

    @Test("records the measured duration as integer milliseconds")
    func recordsDuration() async throws {
        let sink = CapturingOperationLog()
        let clock = StepClock(elapsed: .milliseconds(250))
        _ = try await InstrumentedOperation.run(
            "op.timed", log: sink, verbosity: verbose, now: { clock.now() }
        ) { 1 }
        #expect(sink.lines.first?.message == "op.timed finished in 250 ms")
    }

    @Test("lets the closure touch main actor state")
    func touchesOwnState() async throws {
        let sink = CapturingOperationLog()
        var counter = 0
        try await InstrumentedOperation.run("op.state", log: sink, verbosity: verbose) {
            counter += 1
        }
        #expect(counter == 1)
    }

    @Test("rethrows the identical error and logs a failed line at debug, never error")
    func rethrowsSameError() async {
        let sink = CapturingOperationLog()
        let thrown = SecretError(code: 7)
        do {
            try await InstrumentedOperation.run("op.fail", log: sink, verbosity: verbose) {
                throw thrown
            }
            Issue.record("expected a throw")
        } catch {
            #expect((error as? SecretError) == thrown)
        }
        #expect(sink.lines.count == 1)
        #expect(sink.lines.first?.level == .debug)
        #expect(sink.lines.first?.message.hasPrefix("op.fail failed after ") == true)
        #expect(!sink.lines.contains { $0.level == .error || $0.level == .critical })
    }

    @Test("the thrown error's text never reaches a line")
    func errorNeverInterpolated() async {
        let sink = CapturingOperationLog()
        _ = try? await InstrumentedOperation.run("op.secret", log: sink, verbosity: verbose) {
            throw SecretError(code: 1)
        }
        #expect(!sink.lines.isEmpty)
        for line in sink.lines {
            #expect(!line.message.contains("ZZ-secret"))
            #expect(!line.message.contains("SecretError"))
        }
    }

    @Test("cancellation logs a cancelled line, no failed line and no error line")
    func cancellation() async {
        let sink = CapturingOperationLog()
        do {
            try await InstrumentedOperation.run("op.cancel", log: sink, verbosity: verbose) {
                throw CancellationError()
            }
            Issue.record("expected a throw")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(sink.lines.count == 1)
        #expect(sink.lines.first?.level == .debug)
        #expect(sink.lines.first?.message.hasPrefix("op.cancel cancelled after ") == true)
        #expect(!sink.lines.contains { $0.message.contains("failed") || $0.level == .error })
    }

    @Test("every line holds only the name plus the expected words and an integer")
    func lineShape() async {
        let sink = CapturingOperationLog()
        _ = try? await InstrumentedOperation.run("op.shape", log: sink, verbosity: verbose) { 1 }
        _ = try? await InstrumentedOperation.run("op.shape", log: sink, verbosity: verbose) {
            throw SecretError(code: 2)
        }
        _ = try? await InstrumentedOperation.run("op.shape", log: sink, verbosity: verbose) {
            throw CancellationError()
        }
        let pattern = /op\.shape (finished in|failed after|cancelled after) \d+ ms/
        #expect(sink.lines.count == 3)
        for line in sink.lines {
            #expect(line.message.wholeMatch(of: pattern) != nil)
        }
    }

    @Test("non-verbose mode logs nothing, still returns the value and rethrows")
    func quietMode() async {
        let sink = CapturingOperationLog()
        let value = try? await InstrumentedOperation.run("op.quiet", log: sink, verbosity: quiet) { 5 }
        #expect(value == 5)
        let thrown = SecretError(code: 3)
        do {
            try await InstrumentedOperation.run("op.quiet", log: sink, verbosity: quiet) { throw thrown }
        } catch {
            #expect((error as? SecretError) == thrown)
        }
        _ = try? await InstrumentedOperation.run("op.quiet", log: sink, verbosity: quiet) {
            throw CancellationError()
        }
        #expect(sink.lines.isEmpty)
    }
}
