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
    private var lastAttemptStart: Date?

    init(
        repository: any AppVersionChecking,
        minimumCheckInterval: TimeInterval = 900,
        now: @escaping @Sendable () -> Date = { Date() },
        sequence: UpdateSequence = UpdateSequence()
    ) {
        self.repository = repository
        self.minimumCheckInterval = minimumCheckInterval
        self.now = now
        self.sequence = sequence
    }

    func dismissRecommended(latestVersion: String) {
        dismissedLatestVersion = latestVersion
    }

    /// The "active again" entry: skips when the last attempt started inside the interval.
    // @MainActor-isolated, so @Instrumented is skipped per coding-standards.md; its span comes from check(), and the skipped path makes no span.
    func checkIfDue() async {
        if let last = lastAttemptStart, now().timeIntervalSince(last) < minimumCheckInterval {
            return
        }
        await check()
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    // The span carries no URL, release notes or error text.
    func check() async {
        lastAttemptStart = now()
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
        } catch let error as TrackerAPIError {
            switch error {
            case .validation: lastErrorCategory = .showMessage
            case .rateLimited: lastErrorCategory = .backOff
            case .server: lastErrorCategory = .showMessage
            case .undocumented: lastErrorCategory = .showMessage
            case .network: lastErrorCategory = .showMessage
            default: lastErrorCategory = .showMessage
            }
        } catch {
            lastErrorCategory = .showMessage
        }
    }
}
