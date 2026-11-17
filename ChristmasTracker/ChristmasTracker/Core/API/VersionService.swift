// VersionService.swift
// ChristmasTracker

import Foundation
import TrackerAPI

@MainActor @Observable final class VersionService {
    private(set) var lastPolicy: VersionPolicy?
    private(set) var lastErrorCategory: ErrorCodeClassification?

    /// Position of `lastPolicy` in the shared sequence; 0 until a check succeeds.
    private(set) var policyOrder = 0
    /// The latestVersion the user chose "Later" for. In memory only.
    private(set) var dismissedLatestVersion: String?

    private let repository: any AppVersionChecking
    private let log: ServiceLog
    private let minimumCheckInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let sequence: UpdateSequence
    private let failureRetryInterval: TimeInterval
    /// When the last check succeeded; cleared by a failure.
    private var lastSuccess: Date?
    /// When the last check failed; cleared by a success.
    private var lastFailure: Date?
    /// True from the start of a check until it finishes; lets `checkIfDue()` skip a concurrent request.
    private var isChecking = false

    init(
        repository: any AppVersionChecking,
        minimumCheckInterval: TimeInterval = 900,
        failureRetryInterval: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() },
        sequence: UpdateSequence = UpdateSequence(),
        log: ServiceLog = ServiceLog()
    ) {
        self.repository = repository
        self.log = log
        self.minimumCheckInterval = minimumCheckInterval
        self.failureRetryInterval = failureRetryInterval
        self.now = now
        self.sequence = sequence
    }

    func dismissRecommended(latestVersion: String) {
        dismissedLatestVersion = latestVersion
    }

    /// The "active again" entry: skips when a check is already in flight, when the last success is
    /// inside the minimum interval, or when the last failure is inside the failure retry interval.
    // @MainActor-isolated, so @Instrumented is skipped per coding-standards.md; its span comes from check(),
    // and a skipped path makes no call, no span and no log line.
    func checkIfDue() async {
        if isChecking { return }
        let current = now()
        if let success = lastSuccess, current.timeIntervalSince(success) < minimumCheckInterval {
            return
        }
        if let failure = lastFailure, current.timeIntervalSince(failure) < failureRetryInterval {
            return
        }
        await check()
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods, so the
    // InstrumentedOperation span is used (the helper works on the main actor).
    // The span and the step lines carry no URL, release notes or error text.
    func check() async {
        let op = "check version"
        // The closure throws nothing (every error is handled inside), so `run` rethrows nothing.
        _ = try? await InstrumentedOperation.run("service.version.check") {
            log.started(op)
            isChecking = true
            defer { isChecking = false }
            do {
                let policy = try await repository.checkVersion()
                lastPolicy = policy
                policyOrder = sequence.next()
                lastErrorCategory = nil
                lastSuccess = now()
                lastFailure = nil
                log.processed(op)
            } catch let error as TrackerAPIError {
                recordFailure()
                log.failed(op)
                switch error {
                case .validation: lastErrorCategory = .showMessage
                case .rateLimited: lastErrorCategory = .backOff
                case .server: lastErrorCategory = .showMessage
                case .undocumented: lastErrorCategory = .showMessage
                case .network: lastErrorCategory = .showMessage
                default: lastErrorCategory = .showMessage
                }
            } catch {
                // The state is the same for every error; only the log tells a cancellation from a failure.
                recordFailure()
                lastErrorCategory = .showMessage
                if error is CancellationError { log.cancelled(op) } else { log.failed(op) }
            }
        }
    }

    /// A failure replaces any earlier success time, so the short retry window governs.
    private func recordFailure() {
        lastSuccess = nil
        lastFailure = now()
    }
}
