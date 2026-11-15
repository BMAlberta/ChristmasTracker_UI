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
    @State private var toggleModel: ProfileBiometricToggleModel?
    @State private var showsChildren = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    if let user = authService.currentUser {
                        UserInfoCardView(user: user)
                    }

                    if let model = toggleModel {
                        SettingsSectionView(
                            isBiometricAvailable: authService.isBiometricAvailable,
                            biometricType: authService.biometricType,
                            toggleModel: model,
                            onEditProfile: {
                                // TODO: Phase 8 - Navigate to edit profile
                                print("Edit profile tapped")
                            },
                            onNotifications: {
                                // TODO: Phase 10 - Navigate to notifications
                                print("Notifications tapped")
                            }
                        )
                    }

                    ChildrenSectionView {
                        showsChildren = true
                    }

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

                    LogoutButtonView(isConfirming: $showLogoutConfirmation) {
                        Task { await authService.logout() }
                    }
                }
                .padding(EdgeInsets.appScreenPadding)
            }
            .background(Color.backgroundPrimaryColor)
            .navigationTitle("Profile")
            .navigationDestination(isPresented: $showsChildren) {
                ChildrenView()
            }
            .task {
                authService.refreshBiometricAvailability()
                if toggleModel == nil {
                    toggleModel = ProfileBiometricToggleModel(authService: authService)
                }
            }
            .onDisappear {
                toggleModel?.dismissBanner()
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

private struct UserInfoCardView: View {

    let user: User

    /// Avatar diameter: 80pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .title) private var avatarSize: CGFloat = 80

    var body: some View {
        CardContainerView {
            VStack(spacing: AppSpacing.lg) {
                Circle()
                    .fill(Color.primaryColor.opacity(0.2))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Text(user.initials)
                            .font(.appTitle1)
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
    let toggleModel: ProfileBiometricToggleModel
    let onEditProfile: () -> Void
    let onNotifications: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "Settings")

            if let banner = toggleModel.banner {
                InlineErrorBanner(
                    state: banner,
                    onTryAgain: { Task { await toggleModel.toggle(to: true) } },
                    onDismiss: { toggleModel.dismissBanner() }
                )
                .padding(.bottom, AppSpacing.md)
            }

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

                        Toggle(
                            "Unlock with \(biometricType.displayName)",
                            isOn: Binding(
                                get: { toggleModel.isEnabled },
                                set: { newValue in Task { await toggleModel.toggle(to: newValue) } }
                            )
                        )
                        .disabled(toggleModel.isDisabledForOtherUser)
                        .font(.appBody)
                        .foregroundStyle(Color.textPrimaryColor)
                        .padding(AppSpacing.md)

                        if let message = toggleModel.disabledMessage {
                            Text(message)
                                .font(.appCaption1)
                                .foregroundStyle(Color.textMutedColor)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.bottom, AppSpacing.md)
                        }
                    }
                }
            }
        }
    }
}

private struct ChildrenSectionView: View {

    let onChildren: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "Family")

            CardContainerView {
                SettingsRowView(
                    icon: "person.2",
                    title: "Children",
                    subtitle: "Manage the children you make lists for",
                    showChevron: true,
                    action: onChildren
                )
                .accessibilityIdentifier("profile.childrenRow")
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

    @Binding var isConfirming: Bool
    let onConfirm: () -> Void

    var body: some View {
        Button {
            isConfirming = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Logout")
            }
            .font(.appHeadline)
            .foregroundStyle(Color.surfaceColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(Color.primaryColor, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, AppSpacing.md)
        // Attached to this trigger, not to the screen's scroll view.
        .confirmationDialog(
            "Are you sure you want to logout?",
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("Logout", action: onConfirm)
            Button("Cancel", role: .cancel) { }
        }
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

    /// Row icon size and slot width: 20pt and 28pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var iconSlotWidth: CGFloat = 28
    /// Chevron size: 14pt at the default text size, scaling with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14

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
                .font(.system(size: iconSize))
                .foregroundStyle(.accent)
                .frame(minWidth: iconSlotWidth)

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
                    .font(.system(size: chevronSize, weight: .semibold))
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
        sessionManager: SessionManager(initialClearables: [])
    )

    var body: some View {
        ProfileView()
            .environment(\.authenticationService, authService)
            .task {
                await authService.login(email: "test@example.com", password: "password", rememberEmail: false)
            }
    }
}

#Preview("Logged In") {
    ProfilePreviewContainer()
}

#Preview("Logged Out") {
    ProfileView()
}
