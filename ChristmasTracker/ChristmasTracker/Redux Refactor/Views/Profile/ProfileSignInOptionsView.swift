//
//  ProfileSignInOptionsView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/27/25.
//

import SwiftUI

struct ProfileSignInOptionsView: View {
    @Environment(\.dismiss) var dismiss
    var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<ProfileSignInOptionsViewState>
    @State private var showingErrorDialog: Bool = false
    @State private var passwordConfirmation : String = ""
    @State private var showingPasswordConfirmationAlert: Bool = false
    @State private var isBiometricEnabled: Bool = false
    @State private var showingBioMetricNotAvailableAlert: Bool = false
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                return ProfileSignInOptionsViewState(
                    isLoading: appState.list.isLoading,
                    error: appState.list.error,
                    signInOptionsChangeSuccessful: appState.list.addListSuccess,
                    biometricState: appState.user.biometricsState
                )
            }
        ))
    }
    var body: some View {
        
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.primaryGreen)
                            .frame(width: 24)
                        
                        Text("Face ID")
                            .font(Font.brandFont(size: 16))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isBiometricEnabled)
                            .labelsHidden()
                    }
                    
                    Divider()
                    
                    Text("Enabling Face ID allows you to quickly sign in without using your username and password. If you share your device with others, they may be able to access your account if their identity is registered to your device.")
                        .font(.brandFont(size: 14))
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                
                Button(action: {
                    viewStore.dispatch(UserActions.disableBiometrics)
                }) {
                    HStack {
                        Image(systemName: "trash.slash.fill")
                        Text("Reset sign in options")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primaryRed)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                
            }.navigationTitle("Sign In Options")
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
                .onChange(of: viewStore.state.biometricState) { _, newValue in
                    self.isBiometricEnabled = newValue == .enrolled
                    }
                .onChange(of: isBiometricEnabled) { _, newValue in
                    handleBiometricToggle()
                }
                .alert("Biometrics Not Available", isPresented: $showingBioMetricNotAvailableAlert) {
                    Button("OK") {

                    }
                } message: {
                    Text("Biometric authentication is not available for your device. Please ensure you have a device passcode set and biometric settings are enabled.")
                }
                .alert("Confirm your login password", isPresented: $showingPasswordConfirmationAlert, actions: {
                    SecureField("Textfield.Placeholder.Password", text: $passwordConfirmation)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    Button("Confirm", action: {
                        Task {
                            viewStore.dispatch(UserActions.enableBiometrics(confirmedPassword: passwordConfirmation))
                            $passwordConfirmation.wrappedValue = ""
                        }
                    })
                    Button("Cancel", role: .cancel, action: {
                        $passwordConfirmation.wrappedValue = ""
                    })
                }, message: {
                    Text("Please confirm your password.")
                })
        }
    }
    
    private func handleBiometricToggle() {
        
        switch viewStore.state.biometricState {
        case .enrolled:
            viewStore.dispatch(UserActions.disableBiometrics)
        case .unavailable:
            self.showingBioMetricNotAvailableAlert = true
        case .unenrolled:
            self.showingPasswordConfirmationAlert = true
        }
    }
    
    struct ProfileSignInOptionsViewState: Equatable {
        let isLoading: Bool
        let error: ListError?
        let signInOptionsChangeSuccessful: Bool
        let biometricState: BiometricUtility.BiometricState
    }
}


#Preview {
    ProfileSignInOptionsView(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    ProfileSignInOptionsView(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
