//
//  RegistrationView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/11/26.
//

import SwiftUI
struct RegisterView: View {
    @Environment(\.authenticationService) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var registrationCode: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @State private var codeFieldError: String? = nil
    @State private var emailFieldError: String? = nil
    var body: some View {
        ScrollView {
            contentView
                .padding(EdgeInsets.appScreenPadding)
        }
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: .constant(authService.error != nil)) {
            Button("OK") { authService.clearError() }
        } message: {
            if let error = authService.error {
                Text(userMessage(for: error))
            }
        }
    }
    private var contentView: some View {
        VStack(spacing: AppSpacing.xl) {
            RegisterHeaderView()
            RegistrationFormView(
                firstName: $firstName,
                lastName: $lastName,
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                registrationCode: $registrationCode,
                showPassword: $showPassword,
                showConfirmPassword: $showConfirmPassword,
                codeFieldError: codeFieldError,
                emailFieldError: emailFieldError,
                onEmailChanged: { emailFieldError = nil },
                onCodeChanged: { codeFieldError = nil }
            )
            RegistrationActionSection(
                isLoading: authService.isLoading,
                isFormValid: isFormValid,
                onRegister: handleRegister
            )
        }
    }

    private func handleRegister() {
        codeFieldError = nil
        emailFieldError = nil
        Task {
            await authService.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName,
                registrationCode: registrationCode
            )
            if authService.isAuthenticated {
                dismiss()
            } else if let error = authService.error {
                switch error {
                case .invalidRegistrationCode:
                    codeFieldError = userMessage(for: .invalidRegistrationCode)
                    authService.clearError()
                case .emailAlreadyExists:
                    emailFieldError = userMessage(for: .emailAlreadyExists)
                    authService.clearError()
                default:
                    break
                }
            }
        }
    }

    private var isFormValid: Bool {
        RegistrationFormValidator.isValid(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            registrationCode: registrationCode
        )
    }
}
// MARK: - Header
private struct RegisterHeaderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.appIconHero)
                .foregroundStyle(Color.primaryColor)
            Text("Join Christmas Tracker")
                .font(.appTitle2)
                .foregroundStyle(Color.textPrimaryColor)
        }
    }
}
// MARK: - Form
private struct RegistrationFormView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var registrationCode: String
    @Binding var showPassword: Bool
    @Binding var showConfirmPassword: Bool
    let codeFieldError: String?
    let emailFieldError: String?
    let onEmailChanged: () -> Void
    let onCodeChanged: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            SimpleTextFieldView(
                label: "First Name",
                placeholder: "First",
                text: $firstName,
                autocapitalization: .sentences,
                autocorrection: false
            )
            SimpleTextFieldView(
                label: "Last Name",
                placeholder: "Last",
                text: $lastName,
                autocapitalization: .sentences,
                autocorrection: false
            )
            EmailFieldView(
                email: $email,
                fieldError: emailFieldError,
                onChanged: onEmailChanged
            )
            PasswordFieldView(
                title: "Password",
                placeholder: "At least 8 characters",
                text: $password,
                showText: $showPassword
            )
            PasswordFieldView(
                title: "Confirm Password",
                placeholder: "Re-enter password",
                text: $confirmPassword,
                showText: $showConfirmPassword
            )
            SimpleTextFieldView(
                label: "Registration Code",
                placeholder: "Enter code",
                text: $registrationCode,
                autocapitalization: .never,
                autocorrection: false,
                fieldError: codeFieldError,
                onChanged: onCodeChanged
            )
            if !password.isEmpty {
                PasswordRequirementsView(
                    password: password,
                    confirmPassword: confirmPassword
                )
            }
        }
    }
}
private struct SimpleTextFieldView: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let autocapitalization: TextInputAutocapitalization
    let autocorrection: Bool
    var fieldError: String? = nil
    var onChanged: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(!autocorrection)
                .textFieldStyle(CustomTextFieldStyle())
                .onChange(of: text) {
                    onChanged?()
                }
            if let error = fieldError {
                Text(error)
                    .font(.appCaption1)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
private struct EmailFieldView: View {
    @Binding var email: String
    var fieldError: String? = nil
    var onChanged: (() -> Void)? = nil

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
                .onChange(of: email) {
                    onChanged?()
                }
            if let error = fieldError {
                Text(error)
                    .font(.appCaption1)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
private struct PasswordFieldView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Binding var showText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            HStack {
                if showText {
                    TextField(placeholder, text: $text)
                        .textContentType(.newPassword)
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.newPassword)
                }
                Button {
                    showText.toggle()
                } label: {
                    Image(systemName: showText ? "eye.slash" : "eye")
                        .foregroundStyle(Color.textMutedColor)
                }
            }
            .textFieldStyle(CustomTextFieldStyle())
        }
    }
}
private struct PasswordRequirementsView: View {
    let password: String
    let confirmPassword: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            PasswordRequirementRow(
                text: "At least 8 characters",
                isMet: password.count >= 8
            )
            PasswordRequirementRow(
                text: "Contains a number",
                isMet: password.contains(where: \.isNumber)
            )
            PasswordRequirementRow(
                text: "Passwords match",
                isMet: !confirmPassword.isEmpty && password == confirmPassword
            )
        }
        .padding(AppSpacing.md)
        .background(Color.surfaceColor)
        .clipShape(.rect(cornerRadius: 8))
    }
}
private struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? Color.primaryColor : Color.textMutedColor)
                .font(.appCaption1)
            Text(text)
                .font(.appCaption1)
                .foregroundStyle(isMet ? Color.textPrimaryColor : Color.textMutedColor)
            Spacer()
        }
    }
}
// MARK: - Actions
private struct RegistrationActionSection: View {
    let isLoading: Bool
    let isFormValid: Bool
    let onRegister: () -> Void

    var body: some View {
        Button(action: onRegister) {
            if isLoading {
                ProgressView()
                    .tint(Color.white)
            } else {
                Text("Create Account")
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
#Preview {
    NavigationStack {
        RegisterView()
            .environment(\.authenticationService, AuthenticationService(
                repository: MockAuthenticationRepository(),
                sessionManager: SessionManager(initialClearables: [])
            ))
    }
}
