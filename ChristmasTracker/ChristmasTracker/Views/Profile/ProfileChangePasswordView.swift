//
//  ChangePasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/27/25.
//

import SwiftUI


struct ProfileChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileChangePasswordViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var oldPasswordFieldContainsError = false
    @State private var newPasswordFieldContainsError = false
    @State private var confirmPasswordFieldContainsError = false
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileChangePasswordViewState(
                    isLoading: appState.user.isLoading,
                    error: appState.user.error,
                    changePasswordSuccessful: appState.user.changePasswordSuccess
                )
            }
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                
                    // Old password
                    EditPasswordFieldView(type: .oldPassword, name: $oldPassword, fieldInErrorState: $oldPasswordFieldContainsError)
                    
                    // New password
                    EditPasswordFieldView(type: .newPassword, name: $newPassword, fieldInErrorState: $newPasswordFieldContainsError)
                    
                    // Confirm New Password
                    EditPasswordFieldView(type: .confirmPassword, name: $confirmPassword, fieldInErrorState: $confirmPasswordFieldContainsError)
                    
                    // Update password button
                    Button(action: {
                        // Add action here
                        if (!validateNewListInput()) {
                            viewStore.dispatch(UserActions.submitPasswordChange(currentPassword: oldPassword, newPassword: confirmPassword))
                        }
                        
                    }) {
                        if (viewStore.state.isLoading) {
                            TextTypingIndicator()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(.gray)
                                .cornerRadius(16)
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Update password")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.primaryGreen)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }.alert("Input Errors", isPresented: $showingErrorDialog) {
            // Define alert actions (buttons) here
            Button("OK") {}
        } message: {
            Text("Please correct the errors on the form and re-submit.")
        }.overlay(
            Group {
                if viewStore.state.changePasswordSuccessful  {
                    AnimatedCheckmarkView()
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                                Task { @MainActor in
                                    dismiss()
                                    viewStore.dispatch(UserActions.passwordChangeFlowComplete)
                                }
                            }
                        }
                }
            }
        )
    }
    
    private func validateNewListInput() -> Bool {
            
        // Validate first name
        if oldPassword.isEmpty {
            oldPasswordFieldContainsError = true
        } else {
            oldPasswordFieldContainsError = false
        }
        
        // Validate last name
        if newPassword.isEmpty {
            newPasswordFieldContainsError = true
        } else {
            newPasswordFieldContainsError = false
        }
        
        // Validate confirmation password
        if confirmPassword.isEmpty {
            confirmPasswordFieldContainsError = true
        } else {
            confirmPasswordFieldContainsError = false
        }
        
        let passwordsMatch = newPassword == confirmPassword
    
        
        let errorExists = oldPasswordFieldContainsError || newPasswordFieldContainsError || confirmPasswordFieldContainsError || !passwordsMatch
        
        if errorExists {
            showingErrorDialog = true
        }
        
        return errorExists
        
    }
    
    struct EditPasswordFieldView: View {
        var type: ProfileSettingsFieldType
        @Binding var name: String
        @Binding var fieldInErrorState: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    Text(type.fieldTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("*")
                        .foregroundColor(.red)
                }
                
                SecureField(type.fieldPlaceholder, text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textContentType(.password)
                    .border(fieldInErrorState ? .primaryRed: .clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    
    struct ProfileChangePasswordViewState: Equatable {
        let isLoading: Bool
        let error: UserError?
        let changePasswordSuccessful: Bool
    }
    
    enum ProfileSettingsFieldType: CaseIterable {
        case oldPassword
        case newPassword
        case confirmPassword
        
        var fieldTitle: String {
            switch self {
            case .oldPassword: return "Current password"
            case .newPassword: return "New password"
            case .confirmPassword: return "Confirm new password"
            }
        }
        
        var fieldPlaceholder: String {
            switch self {
            case .oldPassword: return "Enter your current password"
            case .newPassword: return "Enter your new password"
            case .confirmPassword: return "Confirm your new password"
            }
        }
    }
}


#Preview {
    ProfileChangePasswordView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
}

#Preview {
    ProfileChangePasswordView(store: StoreEnvironmentKey.defaultValue) // Default (light mode)
        .preferredColorScheme(.dark)
}



