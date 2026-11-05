//
//  LoginView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/10/26.
//

import SwiftUI

internal nonisolated func loginInitialState(remembered: String?) -> (email: String, rememberEmail: Bool) {
    (email: remembered ?? "", rememberEmail: remembered != nil)
}

// MARK: - Biometric Button State

internal enum LoginBiometricButtonState: Equatable {
    case hidden
    case showNotEnrolled
    case showNeedsSetup(message: String, opensSettings: Bool)
    case showEnrolled(firstName: String)
}

internal nonisolated func loginBiometricButtonState(
    readiness: BiometricReadiness,
    enrolledUser: (userId: String, firstName: String)?,
    biometryTypeName: String
) -> LoginBiometricButtonState {
    switch readiness {
    case .noHardware:
        return .hidden
    case .needsSetup:
        let msg = biometricReadinessMessage(for: readiness, biometryTypeName: biometryTypeName)
        return .showNeedsSetup(message: msg.message, opensSettings: msg.opensSettings)
    case .ready:
        if let enrolled = enrolledUser {
            return .showEnrolled(firstName: enrolled.firstName)
        }
        return .showNotEnrolled
    }
}

internal nonisolated func shouldAutoAttemptBiometricLogin(
    readiness: BiometricReadiness,
    hasEnrolledUser: Bool,
    alreadyAttemptedThisLaunch: Bool,
    appIsActive: Bool
) -> Bool {
    guard case .ready = readiness else { return false }
    return hasEnrolledUser && !alreadyAttemptedThisLaunch && appIsActive
}


struct LoginView: View {
    // MARK: - Environment
    @Environment(\.authenticationService) private var authService

    // MARK: - State
    @State private var email: String
    @State private var password: String = ""
    @State private var rememberEmail: Bool
    @State private var showPassword: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var showError: Bool = false
    @State private var biometricModel: LoginBiometricModel? = nil

    init() {
        let initial = loginInitialState(remembered: RememberedEmailStore().rememberedEmail)
        _email = State(wrappedValue: initial.email)
        _rememberEmail = State(wrappedValue: initial.rememberEmail)
    }

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
            .alert("Error", isPresented: $showError) {
                Button("OK") { authService.clearError() }
            } message: {
                Text(authService.error?.localizedDescription ?? "")
            }
            .alert(
                "Set Up Biometrics",
                isPresented: Binding(
                    get: { biometricModel?.showSetupAlert ?? false },
                    set: { biometricModel?.showSetupAlert = $0 }
                )
            ) {
                if biometricModel?.setupOpensSettings == true {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(biometricModel?.setupMessage ?? "")
            }
            .alert(
                "Enable \(authService.biometricType.displayName)",
                isPresented: Binding(
                    get: { biometricModel?.showNotEnrolledAlert ?? false },
                    set: { biometricModel?.showNotEnrolledAlert = $0 }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Sign in with your password to enable \(authService.biometricType.displayName) for future logins.")
            }
            .onChange(of: authService.error) { _, e in showError = e != nil }
            .onChange(of: authService.biometricSignInState) { _, _ in
                biometricModel?.syncFromService()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .task {
                authService.refreshBiometricState()
                if biometricModel == nil {
                    biometricModel = LoginBiometricModel(authService: authService)
                }
                biometricModel?.syncFromService()
                await biometricModel?.autoAttemptIfNeeded()
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
                rememberEmail: $rememberEmail,
                showPassword: $showPassword,
                onForgotPassword: { showForgotPassword = true }
            )
            LoginActionSection(
                isLoading: authService.isLoading,
                isFormValid: isFormValid,
                onLogin: handleLogin
            )
            if let model = biometricModel, model.buttonState != .hidden {
                BiometricButtonSection(model: model, biometricType: authService.biometricType)
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
                rememberEmail: rememberEmail
            )
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
    @Binding var rememberEmail: Bool
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
                rememberEmail: $rememberEmail,
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
    @Binding var rememberEmail: Bool
    let onForgotPassword: () -> Void

    var body: some View {
        HStack {
            Toggle("Remember email", isOn: $rememberEmail)
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
private struct BiometricButtonSection: View {
    @Bindable var model: LoginBiometricModel
    let biometricType: BiometricType

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            DividerRow()
            Button {
                Task { await model.tap() }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: biometricType == .faceID ? "faceid" : "touchid")
                        .font(.system(size: 20))
                    if case .showEnrolled(let firstName) = model.buttonState {
                        Text("Sign in as \(firstName)")
                    } else {
                        Text("Sign in with \(biometricType.displayName)")
                    }
                }
            }
            .font(.appHeadline)
            .foregroundStyle(Color.primaryColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, AppSpacing.md)
            .background(Color.surfaceColor)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primaryColor, lineWidth: 2))
            .clipShape(.rect(cornerRadius: 12))
            .disabled(model.isLoading)
            .accessibilityLabel(biometricType == .faceID ? "Sign in with Face ID" : "Sign in with Touch ID")
            .accessibilityHint("Uses biometric authentication to sign in")
            switch model.biometricSignInState {
            case .retryHint(let msg), .passwordOnly(let msg), .neutralError(let msg):
                Text(msg)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
                    .multilineTextAlignment(.center)
            default:
                EmptyView()
            }
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
