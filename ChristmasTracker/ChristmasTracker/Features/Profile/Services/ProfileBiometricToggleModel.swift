//
//  ProfileBiometricToggleModel.swift
//  ChristmasTracker
//

import Foundation
import TrackerInstrumentation

@MainActor
@Observable
internal final class ProfileBiometricToggleModel {

    // MARK: - Observable State

    var isEnabled: Bool
    var errorMessage: String?

    // MARK: - Dependencies

    private var preference: any BiometricUnlockPreferring
    private let enablementModel: BiometricEnablementModel

    // MARK: - Initialization

    init(preference: any BiometricUnlockPreferring, enablementModel: BiometricEnablementModel) {
        self.preference = preference
        self.enablementModel = enablementModel
        self.isEnabled = preference.biometricUnlockEnabled
    }

    // MARK: - Toggle

    // Actor-isolated (@MainActor): @Instrumented cannot be applied to actor-isolated methods;
    // using manual SentrySDK span per coding-standards.md.
    func toggle(to newValue: Bool) async {
        let transaction = SentrySDK.startTransaction(
            name: "service.profileBiometricToggle.toggle",
            operation: "service.profileBiometricToggle.toggle"
        )
        defer { transaction.finish() }

        if !newValue {
            preference.biometricUnlockEnabled = false
            isEnabled = false
            return
        }

        await enablementModel.enable()

        switch enablementModel.state {
        case .succeeded:
            preference.biometricUnlockEnabled = true
            isEnabled = true
        case .failed(let message):
            isEnabled = false
            errorMessage = message
        case .idle, .inProgress:
            isEnabled = false
            errorMessage = "Biometric authentication was not completed. Please try again."
        }
    }
}
