//
//  LoginBiometricModel.swift
//  ChristmasTracker
//
//  View model that drives the biometric sign-in button on LoginView.
//

import Foundation

// MARK: - LoginBiometricModel

@MainActor @Observable internal final class LoginBiometricModel {

    // MARK: - Derived state (computed live from the service)

    var buttonState: LoginBiometricButtonState {
        loginBiometricButtonState(
            readiness: authService.biometricAuthenticator.readiness,
            enrolledUser: authService.enrolledUserSnapshot,
            biometryTypeName: authService.biometricType.displayName
        )
    }

    var biometricSignInState: BiometricSignInState {
        authService.biometricSignInState
    }

    var isLoading: Bool {
        authService.isLoading
    }

    // MARK: - Alert state

    var showSetupAlert: Bool = false
    var showNotEnrolledAlert: Bool = false
    var setupMessage: String? = nil
    var setupOpensSettings: Bool = false

    // MARK: - Private

    private let authService: AuthenticationService

    // MARK: - Initialization

    init(authService: AuthenticationService) {
        self.authService = authService
        syncFromService()
    }

    // MARK: - Sync

    /// Refreshes alert-related local state from the current buttonState.
    /// Computed properties (`buttonState`, `biometricSignInState`, `isLoading`) are always live.
    func syncFromService() {
        if case .showNeedsSetup(let message, let opensSettings) = buttonState {
            setupMessage = message
            setupOpensSettings = opensSettings
        }
    }

    // MARK: - Actions

    func tap() async {
        switch buttonState {
        case .hidden:
            return
        case .showNeedsSetup(let message, let opensSettings):
            setupMessage = message
            setupOpensSettings = opensSettings
            showSetupAlert = true
        case .showNotEnrolled:
            authService.pendBiometricEnablementRequest()
            showNotEnrolledAlert = true
        case .showEnrolled:
            await authService.signInWithBiometric()
        }
    }

    // MARK: - Process-level once flag

    // nonisolated(unsafe) because this is a static property accessed from @MainActor context;
    // writes happen only on MainActor (autoAttemptIfNeeded / resetAutoAttemptFlagForTesting)
    // but the property must be nonisolated to allow static access.
    nonisolated(unsafe) private(set) static var hasAutoAttempted: Bool = false

    internal static func resetAutoAttemptFlagForTesting() {
        hasAutoAttempted = false
    }

    func autoAttemptIfNeeded(appIsActive: @escaping @Sendable () -> Bool = { true }) async {
        guard !LoginBiometricModel.hasAutoAttempted else { return }
        guard appIsActive() else { return }   // return WITHOUT consuming the flag
        LoginBiometricModel.hasAutoAttempted = true
        syncFromService()
        guard case .showEnrolled = buttonState else { return }
        await authService.signInWithBiometric()
    }
}
