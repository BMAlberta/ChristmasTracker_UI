//
//  LoginView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/10/26.
//

import SwiftUI
struct LoginView: View {
    // MARK: - Environment
    @Environment(\.authenticationService) private var authService
    
    // MARK: - State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = false
    @State private var showPassword: Bool = false
    @State private var showForgotPassword: Bool = false
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                contentView
                    .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Welcome Back")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .constant(authService.error != nil)) {
                Button("OK") {
                    // Error dismissed in service
                }
            } message: {
                if let error = authService.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    // MARK: - Subviews
    private var contentView: some View {
        VStack(spacing: AppSpacing.xl) {
            LoginHeaderView()
            LoginFormView(
                email: $email,
                password: $password,
                rememberMe: $rememberMe,
                showPassword: $showPassword,
                onForgotPassword: { showForgotPassword = true }
            )
            LoginActionSection(
                isLoading: authService.isLoading,
                isFormValid: isFormValid,
                onLogin: handleLogin
            )
            if authService.isBiometricAvailable {
                BiometricOptionView(
                    biometricType: authService.biometricType,
                    isLoading: authService.isLoading,
                    onBiometricLogin: handleBiometricLogin
                )
            }
            SignUpRow()
        }
    }
    // MARK: - Actions
    private func handleLogin() {
        Task {
            await authService.login(
                email: email,
                password: password,
                rememberMe: rememberMe
            )
        }
    }

    private func handleBiometricLogin() {
        Task {
            await authService.loginWithBiometric()
        }
    }
    // MARK: - Validation
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
}
// MARK: - Header
private struct LoginHeaderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "gift.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.primaryColor)
            Text("Christmas Tracker")
                .font(.appTitle1)
                .foregroundStyle(Color.textPrimaryColor)
        }
        .padding(.top, AppSpacing.xl)
    }
}
// MARK: - Form
private struct LoginFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var rememberMe: Bool
    @Binding var showPassword: Bool
    let onForgotPassword: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            EmailFieldView(email: $email)
            PasswordFieldView(
                password: $password,
                showPassword: $showPassword
            )
            RememberForgotRow(
                rememberMe: $rememberMe,
                onForgotPassword: onForgotPassword
            )
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
private struct PasswordFieldView: View {
    @Binding var password: String
    @Binding var showPassword: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Password")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            HStack {
                if showPassword {
                    TextField("Password", text: $password)
                        .textContentType(.password)
                } else {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Color.textMutedColor)
                }
            }
            .textFieldStyle(CustomTextFieldStyle())
        }
    }
}
private struct RememberForgotRow: View {
    @Binding var rememberMe: Bool
    let onForgotPassword: () -> Void

    var body: some View {
        HStack {
            Toggle("Remember me", isOn: $rememberMe)
                .font(.appBody)
                .foregroundStyle(Color.textPrimaryColor)
                .tint(Color.primaryColor)
            Spacer()
            Button("Forgot?", action: onForgotPassword)
                .font(.appBody)
                .foregroundStyle(Color.accentColor)
        }
    }
}
// MARK: - Actions
private struct LoginActionSection: View {
    let isLoading: Bool
    let isFormValid: Bool
    let onLogin: () -> Void

    var body: some View {
        Button(action: onLogin) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text("Sign In")
            }
        }
        .font(.appHeadline)
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(Color.primaryColor)
        .clipShape(.rect(cornerRadius: 12))
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.5)
    }
}
// MARK: - Biometrics
private struct BiometricOptionView: View {
    let biometricType: BiometricType
    let isLoading: Bool
    let onBiometricLogin: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            DividerRow()
            Button(action: onBiometricLogin) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                    Text("Sign in with \(biometricType.displayName)")
                }
            }
            .font(.appHeadline)
            .foregroundStyle(Color.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(Color.surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primaryColor, lineWidth: 2)
            )
            .clipShape(.rect(cornerRadius: 12))
            .disabled(isLoading)
        }
    }
}
private struct DividerRow: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.borderColor)
                .frame(height: 1)
            Text("or")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
                .padding(.horizontal, AppSpacing.sm)
            Rectangle()
                .fill(Color.borderColor)
                .frame(height: 1)
        }
    }
}
// MARK: - Sign Up
private struct SignUpRow: View {
    var body: some View {
        HStack {
            Text("Don't have an account?")
                .font(.appBody)
                .foregroundStyle(Color.textMutedColor)
            NavigationLink("Sign Up") {
                RegisterView()
            }
            .font(.appHeadline)
            .foregroundStyle(Color.accentColor)
        }
    }
}
// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(AppSpacing.md)
            .background(Color.surfaceColor)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
    }
}
#Preview {
    LoginView()
        .environment(\.authenticationService, AuthenticationService(
            repository: MockAuthenticationRepository(),
            sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
        ))
}
