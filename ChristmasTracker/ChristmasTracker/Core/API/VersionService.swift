// VersionService.swift
// ChristmasTracker

import Foundation
import Sentry
import TrackerAPI

@MainActor @Observable final class VersionService {
    private(set) var lastPolicy: VersionPolicy?
    private(set) var lastErrorCategory: ErrorCodeClassification?

    /// Position of `lastPolicy` in the shared sequence; 0 until a check succeeds.
    private(set) var policyOrder = 0
    /// The latestVersion the user chose "Later" for. In memory only.
    private(set) var dismissedLatestVersion: String?

    private let repository: any AppVersionChecking
    private let minimumCheckInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let sequence: UpdateSequence
    private let failureRetryInterval: TimeInterval
    /// When the last check succeeded; cleared by a failure.
    private var lastSuccess: Date?
    /// When the last check failed; cleared by a success.
    private var lastFailure: Date?

    init(
        repository: any AppVersionChecking,
        minimumCheckInterval: TimeInterval = 900,
        failureRetryInterval: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() },
        sequence: UpdateSequence = UpdateSequence()
    ) {
        self.repository = repository
        self.minimumCheckInterval = minimumCheckInterval
        self.failureRetryInterval = failureRetryInterval
        self.now = now
        self.sequence = sequence
    }

    func dismissRecommended(latestVersion: String) {
        dismissedLatestVersion = latestVersion
    }

    /// The "active again" entry: skips when the last success is inside the minimum interval,
    /// or the last failure is inside the failure retry interval.
    // @MainActor-isolated, so @Instrumented is skipped per coding-standards.md; its span comes from check(), and the skipped path makes no span.
    func checkIfDue() async {
        let current = now()
        if let success = lastSuccess, current.timeIntervalSince(success) < minimumCheckInterval {
            return
        }
        if let failure = lastFailure, current.timeIntervalSince(failure) < failureRetryInterval {
            return
        }
        await check()
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    // The span carries no URL, release notes or error text.
    func check() async {
        let span = SentrySDK.startTransaction(
            name: "service.version.check",
            operation: "service.version.check"
        )
        defer { span.finish() }
        do {
            let policy = try await repository.checkVersion()
            lastPolicy = policy
            policyOrder = sequence.next()
            lastErrorCategory = nil
            lastSuccess = now()
            lastFailure = nil
        } catch let error as TrackerAPIError {
            recordFailure()
            switch error {
            case .validation: lastErrorCategory = .showMessage
            case .rateLimited: lastErrorCategory = .backOff
            case .server: lastErrorCategory = .showMessage
            case .undocumented: lastErrorCategory = .showMessage
            case .network: lastErrorCategory = .showMessage
            default: lastErrorCategory = .showMessage
            }
        } catch {
            recordFailure()
            lastErrorCategory = .showMessage
        }
    }

    /// A failure replaces any earlier success time, so the short retry window governs.
    private func recordFailure() {
        lastSuccess = nil
        lastFailure = now()
    }
}
