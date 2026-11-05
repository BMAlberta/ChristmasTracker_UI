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
    var isDisabledForOtherUser: Bool
    var disabledMessage: String?

    // MARK: - Dependencies

    private let authService: AuthenticationService

    // MARK: - Initialization

    init(authService: AuthenticationService) {
        self.authService = authService
        let matchesSession = authService.enrolledUserMatchesSession
        let hasOtherEnrollment = authService.enrolledUser != nil && !matchesSession
        self.isEnabled = matchesSession
        self.isDisabledForOtherUser = hasOtherEnrollment
        self.disabledMessage = hasOtherEnrollment
            ? "Face ID is set up for another account on this device."
            : nil
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

        guard !isDisabledForOtherUser else { return }

        if !newValue {
            try? authService.revokeEnrollment()
            isEnabled = false
            return
        }

        do {
            try await authService.enrollCurrentSession()
            isEnabled = true
        } catch {
            isEnabled = false
            errorMessage = "Biometric enrollment failed. Try again or use your password."
        }
    }
}
