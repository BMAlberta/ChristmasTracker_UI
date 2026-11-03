//
//  ProfileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import SwiftUI

/// Profile view with user info and logout
struct ProfileView: View {

    @Environment(\.authenticationService) private var authService

    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    if let user = authService.currentUser {
                        UserInfoCardView(user: user)
                    }

                    SettingsSectionView(
                        isBiometricAvailable: authService.isBiometricAvailable,
                        biometricType: authService.biometricType,
                        onEditProfile: {
                            // TODO: Phase 8 - Navigate to edit profile
                            print("Edit profile tapped")
                        },
                        onNotifications: {
                            // TODO: Phase 10 - Navigate to notifications
                            print("Notifications tapped")
                        },
                        onBiometric: {
                            // TODO: Phase 8 - Navigate to biometric settings
                            print("Biometric settings tapped")
                        }
                    )

                    AboutSectionView(
                        appVersion: appVersion,
                        onHelp: {
                            // TODO: Phase 11 - Navigate to help
                            print("Help tapped")
                        },
                        onPrivacy: {
                            // TODO: Phase 11 - Navigate to privacy
                            print("Privacy tapped")
                        }
                    )

                    LogoutButtonView {
                        showLogoutConfirmation = true
                    }
                }
                .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Profile")
            .confirmationDialog(
                "Are you sure you want to logout?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Logout", role: .destructive) {
                    Task {
                        await authService.logout()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

private struct UserInfoCardView: View {

    let user: User

    var body: some View {
        CardContainerView {
            VStack(spacing: AppSpacing.lg) {
                Circle()
                    .fill(Color.primaryColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(user.initials)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color.primaryColor)
                    )

                VStack(spacing: AppSpacing.xs) {
                    Text(user.name)
                        .font(.appTitle2)
                        .foregroundStyle(Color.textPrimaryColor)

                    if let email = user.email {
                        Text(email)
                            .font(.appBody)
                            .foregroundStyle(Color.textMutedColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
        }
    }
}

private struct SettingsSectionView: View {

    let isBiometricAvailable: Bool
    let biometricType: BiometricType
    let onEditProfile: () -> Void
    let onNotifications: () -> Void
    let onBiometric: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "Settings")

            CardContainerView {
                VStack(spacing: 0) {
                    SettingsRowView(
                        icon: "person.circle",
                        title: "Edit Profile",
                        subtitle: "Update your name and information",
                        showChevron: true,
                        action: onEditProfile
                    )

                    Divider()
                        .padding(.leading, 52)

                    SettingsRowView(
                        icon: "bell",
                        title: "Notifications",
                        subtitle: "Manage your notification preferences",
                        showChevron: true,
                        action: onNotifications
                    )

                    if isBiometricAvailable {
                        Divider()
                            .padding(.leading, 52)

                        SettingsRowView(
                            icon: biometricType == .faceID ? "faceid" : "touchid",
                            title: biometricType.displayName,
                            subtitle: "Sign in with biometrics",
                            showChevron: true,
                            action: onBiometric
                        )
                    }
                }
            }
        }
    }
}

private struct AboutSectionView: View {

    let appVersion: String
    let onHelp: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "About")

            CardContainerView {
                VStack(spacing: 0) {
                    SettingsRowView(
                        icon: "questionmark.circle",
                        title: "Help & Support",
                        subtitle: "Get help with the app",
                        showChevron: true,
                        action: onHelp
                    )

                    Divider()
                        .padding(.leading, 52)

                    SettingsRowView(
                        icon: "hand.raised",
                        title: "Privacy Policy",
                        subtitle: "Learn how we protect your data",
                        showChevron: true,
                        action: onPrivacy
                    )

                    Divider()
                        .padding(.leading, 52)

                    SettingsRowView(
                        icon: "info.circle",
                        title: "Version",
                        subtitle: appVersion,
                        showChevron: false,
                        action: nil
                    )
                }
            }
        }
    }
}

private struct LogoutButtonView: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Logout")
            }
            .font(.appHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(.red, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.md)
    }
}

private struct SectionHeaderView: View {

    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(Color.textMutedColor)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xs)
    }
}

private struct SettingsRowView: View {

    let icon: String
    let title: String
    let subtitle: String
    let showChevron: Bool
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .contentShape(.rect)
        .padding(AppSpacing.md)
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appBody)
                    .foregroundStyle(Color.textPrimaryColor)

                Text(subtitle)
                    .font(.appCaption1)
                    .foregroundStyle(Color.textMutedColor)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.textMutedColor)
            }
        }
    }
}

private struct CardContainerView<Content: View>: View {

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.surfaceColor, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - User Extension

extension User {
    var initials: String {
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }
        return initials.prefix(2).joined().uppercased()
    }
}

private struct ProfilePreviewContainer: View {

    @State private var authService = AuthenticationService(
        repository: MockAuthenticationRepository(),
        sessionManager: SessionManager(authRepository: MockAuthenticationRepository())
    )

    var body: some View {
        ProfileView()
            .environment(\.authenticationService, authService)
            .task {
                await authService.login(email: "test@example.com", password: "password", rememberMe: false)
            }
    }
}

#Preview("Logged In") {
    ProfilePreviewContainer()
}

#Preview("Logged Out") {
    ProfileView()
}
