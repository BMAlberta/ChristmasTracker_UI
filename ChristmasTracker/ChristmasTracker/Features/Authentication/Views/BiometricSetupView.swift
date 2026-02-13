//
//  BiometricSetupView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct BiometricSetupView: View {
    @Environment(\.authenticationService) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabling: Bool = false
    var body: some View {
        contentView
            .padding(EdgeInsets.appScreenPadding)
            .background(Color.backgroundPrimaryColor)
    }

    private var contentView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            BiometricHeaderView(biometricType: authService.biometricType)
            Spacer()
            BiometricActionSection(
                biometricType: authService.biometricType,
                isEnabling: isEnabling,
                onEnable: handleEnableBiometric,
                onSkip: { dismiss() }
            )
        }
    }

    private func handleEnableBiometric() {
        Task {
            await enableBiometric()
        }
    }

    private func enableBiometric() async {
        isEnabling = true
        do {
            // Generate biometric token (use refresh token as biometric token)
            guard let refreshToken = try? KeychainService.get("auth.refresh_token") else {
                LogError("No refresh token available for biometric setup", category: .auth)
                isEnabling = false
                return
            }
            try await authService.setupBiometrics(biometricToken: refreshToken)
            // Success - dismiss
            dismiss()
        } catch {
            LogError("Biometric setup failed: \(error)", category: .auth)
        }
        isEnabling = false
    }
}
// MARK: - Header
private struct BiometricHeaderView: View {
    let biometricType: BiometricType

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 96))
                .foregroundStyle(Color.primaryColor)
            Text("Enable \(biometricType.displayName)?")
                .font(.appTitle1)
                .foregroundStyle(Color.textPrimaryColor)
            Text("Sign in faster and more securely with \(biometricType.displayName). You can disable this anytime in settings.")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
}
// MARK: - Actions
private struct BiometricActionSection: View {
    let biometricType: BiometricType
    let isEnabling: Bool
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Button(action: onEnable) {
                if isEnabling {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Enable \(biometricType.displayName)")
                }
            }
            .font(.appHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(Color.primaryColor)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(isEnabling)

            Button("Not Now", action: onSkip)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
        }
        .padding(.bottom, AppSpacing.xl)
    }
}
#Preview {
    BiometricSetupView()
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
