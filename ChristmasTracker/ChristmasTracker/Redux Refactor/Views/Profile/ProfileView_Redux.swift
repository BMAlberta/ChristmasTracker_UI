//
//  ProfileView_Redux.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct ProfileViewRedux: View {
    @State private var faceIDEnabled = true
    @State private var darkModeEnabled = false
    @State private var showingEditNameSheet = false
    @State private var showingChangePassword = false
    @State private var showingSignInOptionsSheet = false
    @State private var showingClearCacheSheet = false
    @State private var showingNotificationsSheet = false
    @State private var showingDeleteAccountSheet = false
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileViewState>
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileViewState(
                    isLoading: appState.user.isLoading,
                    error: appState.user.error,
                    metadata: appState.user.metadata)
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile Card
                        ProfileSummaryView(store: store)
                        // Profile Details
                        ProfileDetailsView(store: store)
                        // Account Settings
                        ProfileSettingsView(showingEditNameSheet: $showingEditNameSheet,
                                            showingChangePassword: $showingChangePassword,
                                            showingSignInOptionsSheet: $showingSignInOptionsSheet)
                        
                        // App Settings
                        AppSettingsView(darkModeEnabled: $darkModeEnabled,
                                        showingClearCacheSheet: $showingClearCacheSheet,
                                        showingNotificationsSheet: $showingNotificationsSheet)
                        
                        // Danger Zone
                        ProfileDangerZoneView(showingDeleteAccountSheet: $showingDeleteAccountSheet)
                        
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        LogoutButton
                    }
                }
                .background(Color(.systemGray6))
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                
                if viewStore.state.isLoading {
                    Color.black.opacity(0.65)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryRed))
                        .controlSize(.large)
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.8)))
                }
            }
            
        }
        .onAppear {
            viewStore.updateStore(store)
        }
        .sheet(isPresented: $showingEditNameSheet) {
            ProfileEditNameView(store: store)
                .presentationBackground(.white)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingChangePassword) {
            ProfileChangePasswordView(store: store)
                .presentationBackground(.white)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSignInOptionsSheet) {
            ProfileSignInOptionsView(store: store)
                .presentationBackground(.white)
                .presentationDetents([.fraction(0.4)])
        }
        .alert("Reset Cache", isPresented: $showingClearCacheSheet) {
            Button("Reset Cache", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "savedEmail")
            }
            Button("Cancel", role: .cancel){}
        } message: {
            Text("This action will clear your saved user id from the system. You will have to re-enter your login credentials the next time you sign in.\n\nDo you wish to proceed?")
        }
        .alert("Currently Unavailable", isPresented: $showingNotificationsSheet) {
            Button("OK") {}
        } message: {
            Text("The notifications functionality is currently not available. Please try again later.")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountSheet) {
            Button("Yes, delete", role: .destructive) {}
            Button("Cancel", role: .cancel){}
        } message: {
            Text("Your account will be **immediately marked for deletion**.\n\nYou will be **signed out** and unable to log in again.\n\nAll of your data — including account details, lists, and purchase history — will be **permanently deleted within 30 days**.\n\nIf you decide to keep your account, you can contact our support team within 30 days to cancel the deletion and restore access.\n\nAfter 30 days, all data will be permanently removed and **cannot be recovered**.\n\n**Note:** Once deletion is complete, this action cannot be undone.")
        }
    }
    
    private var LogoutButton: some View {
        Button("Sign Out") {
            Task {
                viewStore.dispatch(UserActions.logout)
            }
        }
    }
}

struct ProfileDangerZoneView: View {
    @Binding var showingDeleteAccountSheet: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Danger Zone")
                .font(.system(size: 18, weight: .bold))
                .padding()
            
            Divider()
            
            Button(action: {
                showingDeleteAccountSheet = true
            }) {
                HStack {
                    Image(systemName: "person.fill.xmark")
                        .foregroundColor(.primaryRed)
                        .frame(width: 24)
                    
                    Text("Delete Account")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primaryRed)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct AppSettingsView: View {
    @Binding var darkModeEnabled: Bool
    @Binding var showingClearCacheSheet: Bool
    @Binding var showingNotificationsSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("App Settings")
                .font(.system(size: 18, weight: .bold))
                .padding()
            
            Divider()
            
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(.primaryGreen)
                    .frame(width: 24)
                
                Text("Dark Mode")
                    .font(.system(size: 16, weight: .regular))
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("", isOn: $darkModeEnabled)
                    .labelsHidden()
            }
            .padding()
            
            Divider()
            
            SettingsRow(icon: "trash.fill", iconColor: .primaryGreen, title: "Clear Cache", displaySheet: $showingClearCacheSheet)
            
            Divider()
            
            SettingsRow(icon: "bell.fill", iconColor: .primaryGreen, title: "Notifications", displaySheet: $showingNotificationsSheet)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ProfileSettingsView: View {
    @Binding var showingEditNameSheet: Bool
    @Binding var showingChangePassword: Bool
    @Binding var showingSignInOptionsSheet: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Settings")
                .font(.system(size: 18, weight: .bold))
                .padding()
            
            Divider()
            
            SettingsRow(icon: "person.fill", iconColor: .primaryGreen, title: "Edit Name", displaySheet: $showingEditNameSheet)
            
            Divider()
            
            SettingsRow(icon: "lock.fill", iconColor: .primaryGreen, title: "Change Password", displaySheet: $showingChangePassword)
            
            Divider()
            
            SettingsRow(icon: "faceid", iconColor: .primaryGreen, title: "Sign-In Options", displaySheet: $showingSignInOptionsSheet)
            
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ProfileSummaryView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileSummaryViewState>
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileSummaryViewState(
                    metadata: appState.user.metadata
                )
            }
        ))
    }

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewStore.state.metadata.firstName) \(viewStore.state.metadata.lastName)")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text(viewStore.state.metadata.email)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
//                
//                Button(action: {}) {
//                    Image(systemName: "pencil")
//                        .foregroundColor(.primaryGreen)
//                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    struct ProfileSummaryViewState: Equatable {
        let metadata: UserMetadata
    }
}

struct ProfileDetailsView: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileDetailsViewState>
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileDetailsViewState(
                    metadata: appState.user.metadata
                )
            }
        ))
    }
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Profile Details")
                .font(.system(size: 18, weight: .bold))
                .padding()
            
            Divider()
            
            ProfileDetailRow(title: "Member since", dataPoint: FormatUtility.convertDateStringToHumanReadable(rawDate: viewStore.state.metadata.creationDate))
            
            Divider()
            
            ProfileDetailRow(title: "Last Seen", dataPoint: FormatUtility.convertDateStringToHumanReadable(rawDate: viewStore.state.metadata.lastLogInDate))
            
            Divider()
            
            ProfileDetailRow(title: "Last Login Location", dataPoint: viewStore.state.metadata.lastLogInLocation)
            
            Divider()
            
            ProfileDetailRow(title: "Password Age (days)", dataPoint: "\(FormatUtility.calculateTimeInterval(from: viewStore.state.metadata.lastPasswordChange))")
        }

        .background(Color.background)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    struct ProfileDetailsViewState: Equatable {
        let metadata: UserMetadata
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var displaySheet: Bool
    
    var body: some View {
        Button(action: {
            displaySheet = true
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}

struct ProfileDetailRow: View {
    let title: String
    let dataPoint: String
    
    var body: some View {
        HStack {
            Text("\(title): ")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.primaryText)
            Text(dataPoint)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.secondaryText)
        }
        .padding()
    }
}

struct ProfileViewState: Equatable {
    let isLoading: Bool
    let error: UserError?
    let metadata: UserMetadata
}

struct ProfileViewRedux_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ProfileViewRedux(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
            ProfileViewRedux(store: StoreEnvironmentKey.defaultValue)
                .preferredColorScheme(.dark) // Dark mode
        }
    }
}
