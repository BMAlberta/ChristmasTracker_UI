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
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    var body: some View {
        ScrollView {
            contentView
                .padding(EdgeInsets.appScreenPadding)
        }
        .background(Color.backgroundPrimaryColor)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: .constant(authService.error != nil)) {
            Button("OK") { }
        } message: {
            if let error = authService.error {
                Text(error.localizedDescription)
            }
        }
    }
    private var contentView: some View {
        VStack(spacing: AppSpacing.xl) {
            RegisterHeaderView()
            RegistrationFormView(
                name: $name,
                email: $email,
                password: $password,
                confirmPassword: $confirmPassword,
                showPassword: $showPassword,
                showConfirmPassword: $showConfirmPassword
            )
            RegistrationActionSection(
                isLoading: authService.isLoading,
                isFormValid: isFormValid,
                onRegister: handleRegister
            )
        }
    }

    private func handleRegister() {
        Task {
            await authService.register(
                email: email,
                password: password,
                name: name
            )
            if authService.isAuthenticated {
                dismiss()
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password.contains(where: \.isNumber) &&
        password == confirmPassword
    }
}
// MARK: - Header
private struct RegisterHeaderView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(Color.primaryColor)
            Text("Join Christmas Tracker")
                .font(.appTitle2)
                .foregroundStyle(Color.textPrimaryColor)
        }
    }
}
// MARK: - Form
private struct RegistrationFormView: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var showPassword: Bool
    @Binding var showConfirmPassword: Bool

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            NameFieldView(name: $name)
            EmailFieldView(email: $email)
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
            if !password.isEmpty {
                PasswordRequirementsView(
                    password: password,
                    confirmPassword: confirmPassword
                )
            }
        }
    }
}
private struct NameFieldView: View {
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Full Name")
                .font(.appCaption1)
                .foregroundStyle(Color.textMutedColor)
            TextField("John Doe", text: $name)
                .textContentType(.name)
                .textFieldStyle(CustomTextFieldStyle())
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
                    .tint(.white)
            } else {
                Text("Create Account")
            }
        }
        .font(.appHeadline)
        .foregroundStyle(.white)
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
                sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
            ))
    }
}
