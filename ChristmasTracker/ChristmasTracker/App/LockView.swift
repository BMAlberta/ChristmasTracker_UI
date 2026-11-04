//
//  LockView.swift
//  ChristmasTracker
//
//  The inactivity lock screen. Shown in its own UIWindow above all app content.
//  DesignSystem tokens only. No app data exposed.
//

import SwiftUI
import UIKit

// MARK: - BiometricOutcome

/// The outcome of a biometric authentication attempt, mapped from BiometricResult.
/// Lives at module scope (not inside LockView) so it is testable via free functions.
internal enum BiometricOutcome: Equatable {
    /// Authentication succeeded — unlock immediately.
    case unlock
    /// Keep the biometric button visible. hint is non-nil only for a transient `.failed`.
    case keepBiometric(hint: String?)
    /// Hide the biometric button and show only the password option.
    case passwordOnly
}

// MARK: - Pure mapping functions

/// Maps a BiometricResult to a BiometricOutcome.
/// nonisolated so it can be called from any context without an actor hop.
internal nonisolated func biometricOutcome(
    for result: BiometricResult,
    biometryTypeName: String
) -> BiometricOutcome {
    switch result {
    case .success:
        return .unlock
    case .userCancelled, .systemCancelled:
        return .keepBiometric(hint: nil)
    case .failed:
        let hint = "\(biometryTypeName) didn't recognize you. Try again or use your password."
        return .keepBiometric(hint: hint)
    case .userFallback, .lockedOut, .unavailable:
        return .passwordOnly
    }
}

/// Returns whether the biometric unlock button should be visible.
internal nonisolated func showBiometricButton(
    isAvailable: Bool,
    preferenceEnabled: Bool,
    isPasswordOnly: Bool
) -> Bool {
    isAvailable && preferenceEnabled && !isPasswordOnly
}

/// Returns true iff all conditions are met to auto-attempt biometric unlock on appearance.
internal nonisolated func shouldAutoAttemptBiometrics(
    isAvailable: Bool,
    preferenceEnabled: Bool,
    isPasswordOnly: Bool,
    alreadyAttempted: Bool,
    appIsActive: Bool
) -> Bool {
    isAvailable && preferenceEnabled && !isPasswordOnly && !alreadyAttempted && appIsActive
}

// MARK: - LockView

struct LockView: View {

    let controller: InactivityLockController
    let biometricAuthenticator: any BiometricAuthenticating

    @State private var showPasswordOnly = false
    @State private var biometricHint: String?
    @State private var hasAutoAttempted: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    private let buttonCornerRadius: CGFloat = AppSpacing.md

    var body: some View {
        ZStack {
            Color.backgroundPrimaryColor
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xxl) {
                Spacer()
                headerSection
                Spacer()
                buttonSection
            }
            .padding(EdgeInsets.appScreenPadding)
        }
        .onAppear {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
            guard shouldAutoAttemptBiometrics(
                isAvailable: biometricAuthenticator.isAvailable,
                preferenceEnabled: controller.preference?.biometricUnlockEnabled ?? false,
                isPasswordOnly: showPasswordOnly,
                alreadyAttempted: hasAutoAttempted,
                appIsActive: scenePhase == .active
            ) else { return }
            hasAutoAttempted = true
            Task { await attemptBiometricUnlock() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.appLargeTitle)
                .foregroundStyle(Color.primaryColor)

            Text("Christmas Tracker")
                .font(.appTitle1)
                .foregroundStyle(Color.textPrimaryColor)

            Text("Your session was locked due to inactivity.")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }

    // MARK: - Biometric visibility

    private var shouldShowBiometricButton: Bool {
        showBiometricButton(
            isAvailable: biometricAuthenticator.isAvailable,
            preferenceEnabled: controller.preference?.biometricUnlockEnabled ?? true,
            isPasswordOnly: showPasswordOnly
        )
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: AppSpacing.md) {
            if shouldShowBiometricButton {
                biometricButton
                if let hint = biometricHint {
                    Text(hint)
                        .font(.appCaption1)
                        .foregroundStyle(Color.textMutedColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
            }
            passwordButton
        }
        .padding(.bottom, AppSpacing.xl)
    }

    private var biometricButton: some View {
        Button {
            Task {
                await attemptBiometricUnlock()
            }
        } label: {
            Text("Unlock with \(biometricAuthenticator.biometryType.displayName)")
                .font(.appHeadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.primaryColor)
                .clipShape(.rect(cornerRadius: buttonCornerRadius))
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Unlock with \(biometricAuthenticator.biometryType.displayName)")
    }

    private var passwordButton: some View {
        Button {
            controller.usePasswordTeardown()
        } label: {
            Text("Use password")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .padding(.vertical, AppSpacing.md)
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Use password")
    }

    // MARK: - Biometric path

    private func attemptBiometricUnlock() async {
        let result = await biometricAuthenticator.authenticate(reason: "Unlock Christmas Tracker")
        let outcome = biometricOutcome(
            for: result,
            biometryTypeName: biometricAuthenticator.biometryTypeName
        )
        switch outcome {
        case .unlock:
            controller.unlock()
        case .keepBiometric(let hint):
            biometricHint = hint
        case .passwordOnly:
            showPasswordOnly = true
        }
    }
}

// MARK: - Previews

#Preview("Lock — Face ID available") {
    let controller = InactivityLockController(policy: LockPolicy())
    let authenticator = FakeBiometricAuthenticator()
    return LockView(controller: controller, biometricAuthenticator: authenticator)
}

#Preview("Lock — biometrics unavailable") {
    let controller = InactivityLockController(policy: LockPolicy())
    let authenticator = FakeBiometricAuthenticator()
    authenticator.stubbedIsAvailable = false
    return LockView(controller: controller, biometricAuthenticator: authenticator)
}

#Preview("Lock — Touch ID") {
    let controller = InactivityLockController(policy: LockPolicy())
    let authenticator = FakeBiometricAuthenticator()
    authenticator.stubbedBiometryType = .touchID
    return LockView(controller: controller, biometricAuthenticator: authenticator)
}
