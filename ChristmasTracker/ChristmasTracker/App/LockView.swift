//
//  LockView.swift
//  ChristmasTracker
//
//  The inactivity lock screen. Shown in its own UIWindow above all app content.
//  DesignSystem tokens only. No app data exposed.
//

import SwiftUI
import UIKit

struct LockView: View {

    let controller: InactivityLockController
    let biometricAuthenticator: any BiometricAuthenticating

    @State private var showPasswordOnly = false

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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
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

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: AppSpacing.md) {
            if !showPasswordOnly && biometricAuthenticator.isAvailable {
                biometricButton
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
                .clipShape(.rect(cornerRadius: 12))
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
        switch result {
        case .success:
            controller.unlock()
        case .userCancelled, .systemCancelled:
            break
        case .userFallback, .lockedOut, .unavailable, .failed:
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
