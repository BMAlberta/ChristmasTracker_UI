//
//  BiometricEnablementModel.swift
//  ChristmasTracker
//

import Foundation
import TrackerInstrumentation

@MainActor
@Observable
internal final class BiometricEnablementModel {

    enum EnablementState: Equatable {
        case idle
        case inProgress
        case succeeded
        case failed(String)
    }

    private(set) var state: EnablementState = .idle

    private let authenticator: any BiometricAuthenticating
    private let enrollAction: () async throws -> Void

    init(authenticator: any BiometricAuthenticating, enrollAction: @escaping () async throws -> Void) {
        self.authenticator = authenticator
        self.enrollAction = enrollAction
    }

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func enable() async {
        let transaction = SentrySDK.startTransaction(
            name: "service.biometricEnablement.enable",
            operation: "service.biometricEnablement.enable"
        )
        defer { transaction.finish() }
        state = .inProgress
        let result = await authenticator.authenticate(reason: "Enable biometric unlock for Christmas Tracker.")
        switch result {
        case .success:
            do {
                try await enrollAction()
                state = .succeeded
            } catch {
                state = .failed("\(authenticator.biometryTypeName) enrollment failed. Try again or use your password.")
            }
        case .userCancelled, .systemCancelled:
            state = .idle
        case .failed:
            state = .failed("\(authenticator.biometryTypeName) didn't recognize you. Try again or use your password.")
        case .lockedOut:
            state = .failed("Biometric authentication is locked. Use your password to continue.")
        case .unavailable:
            state = .failed("Biometric authentication is not available on this device.")
        case .userFallback:
            state = .failed("Biometric authentication was declined.")
        }
    }

    func reset() {
        state = .idle
    }
}
