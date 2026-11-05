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
    private var preference: any BiometricUnlockPreferring

    init(authenticator: any BiometricAuthenticating, preference: any BiometricUnlockPreferring) {
        self.authenticator = authenticator
        self.preference = preference
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
            preference.biometricUnlockEnabled = true
            state = .succeeded
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
