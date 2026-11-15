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
    var model: BiometricEnablementModel
    var onComplete: ((Bool) -> Void)?
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
                isEnabling: model.state == .inProgress,
                onEnable: handleEnableBiometric,
                onSkip: {
                    onComplete?(false)
                    dismiss()
                }
            )
        }
    }

    private func handleEnableBiometric() {
        Task {
            await enableBiometric()
        }
    }

    private func enableBiometric() async {
        await model.enable()
        switch model.state {
        case .succeeded:
            onComplete?(true)
            dismiss()
        case .idle:
            break
        case .failed:
            break
        case .inProgress:
            break
        }
    }
}
// MARK: - Header
private struct BiometricHeaderView: View {
    let biometricType: BiometricType

    /// Decorative icon size: 96pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 96

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: heroSize))
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
                Group {
                    if isEnabling {
                        ProgressView()
                    } else {
                        Text("Enable \(biometricType.displayName)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isEnabling)

            Button("Not Now", action: onSkip)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
        }
        .padding(.bottom, AppSpacing.xl)
    }
}
#Preview {
    let auth = FakeBiometricAuthenticator()
    BiometricSetupView(model: BiometricEnablementModel(authenticator: auth, enrollAction: {}))
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(initialClearables: [])
        ))
}
