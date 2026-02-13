//
//  ForgotPasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct ForgotPasswordView: View {
    @Environment(\.authenticationService) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var emailSent: Bool = false

    init(emailSent: Bool = false) {
        _emailSent = State(initialValue: emailSent)
    }

    var body: some View {
        NavigationStack {
            contentView
                .padding(EdgeInsets.appScreenPadding)
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    private var contentView: some View {
        Group {
            if emailSent {
                ForgotPasswordSuccessView(
                    onDone: { dismiss() }
                )
            } else {
                ForgotPasswordFormView(
                    email: $email,
                    isLoading: authService.isLoading,
                    isEmailValid: isEmailValid,
                    onSubmit: handleSendReset
                )
            }
        }
    }

    private func handleSendReset() {
        Task {
            await authService.forgotPassword(email: email)
            if authService.error == nil {
                emailSent = true
            }
        }
    }

    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }
}
// MARK: - Form
private struct ForgotPasswordFormView: View {
    @Binding var email: String
    let isLoading: Bool
    let isEmailValid: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ForgotPasswordHeaderView(
                iconName: "envelope.badge.shield.half.filled",
                title: "Reset Your Password",
                message: "Enter your email address and we'll send you instructions to reset your password."
            )
            EmailFieldView(email: $email)
            PrimaryActionButton(
                title: "Send Reset Email",
                isLoading: isLoading,
                isEnabled: isEmailValid,
                action: onSubmit
            )
            Spacer()
        }
    }
}
// MARK: - Success
private struct ForgotPasswordSuccessView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ForgotPasswordHeaderView(
                iconName: "checkmark.circle.fill",
                title: "Email Sent!",
                message: "Check your email for instructions to reset your password. If you don't see it, check your spam folder."
            )
            PrimaryActionButton(
                title: "Done",
                isLoading: false,
                isEnabled: true,
                action: onDone
            )
            Spacer()
        }
    }
}
// MARK: - Components
private struct ForgotPasswordHeaderView: View {
    let iconName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundStyle(Color.primaryColor)
            Text(title)
                .font(.appTitle2)
                .foregroundStyle(Color.textPrimaryColor)
            Text(message)
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
                .multilineTextAlignment(.center)
        }
    }
}
private struct EmailFieldView: View {
    @Binding var email: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Email")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
}
private struct PrimaryActionButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
            }
        }
        .font(.appHeadline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(Color.primaryColor)
        .clipShape(.rect(cornerRadius: 12))
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}
#Preview("Form") {
    ForgotPasswordView()
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
#Preview("Success") {
    ForgotPasswordView(emailSent: true)
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
