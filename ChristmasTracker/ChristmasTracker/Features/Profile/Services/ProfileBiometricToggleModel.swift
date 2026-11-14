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
    /// The failure of the last enable attempt, shown inline by the Profile screen. Cleared by
    /// `dismissBanner()`, by the next toggle and when the screen disappears.
    private(set) var banner: InlineErrorBannerState?
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
        banner = nil

        if !newValue {
            try? authService.revokeEnrollment()
            authService.clearPreviouslyEnrolledUserId()
            isEnabled = false
            return
        }

        let authResult = await authService.biometricAuthenticator.authenticate(
            reason: "Enable Face ID for Christmas Tracker"
        )
        guard authResult == .success else {
            isEnabled = false
            banner = Self.failureBanner("Biometric authentication failed. Try again or use your password.")
            return
        }

        do {
            try await authService.enrollCurrentSession()
            isEnabled = true
        } catch {
            isEnabled = false
            banner = Self.failureBanner("Biometric enrollment failed. Try again or use your password.")
        }
    }

    func dismissBanner() {
        banner = nil
    }

    private static func failureBanner(_ message: String) -> InlineErrorBannerState {
        InlineErrorBannerState(message: message, canRetry: true, isDismissible: true)
    }
}
