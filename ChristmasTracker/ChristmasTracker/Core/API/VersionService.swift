// VersionService.swift
// ChristmasTracker

import Foundation
import Sentry
import TrackerAPI

@MainActor @Observable final class VersionService {
    private(set) var lastPolicy: VersionPolicy?
    private(set) var lastErrorCategory: ErrorCodeClassification?

    private let repository: any AppVersionChecking

    init(repository: any AppVersionChecking) {
        self.repository = repository
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func check() async {
        let span = SentrySDK.startTransaction(
            name: "service.version.check",
            operation: "service.version.check"
        )
        defer { span.finish() }
        do {
            let policy = try await repository.checkVersion()
            lastPolicy = policy
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
