//
//  LoginView_Redux.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import SwiftUI

struct LoginView_Redux: View {
    private var store: Store<AppState>
    @StateObject private var viewStore: ViewStore<LoginViewState>
    
    @AppStorage("savedEmail") var email: String = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var showingLoginError = false
    @State private var showingBiometricsUnenrolledError = false
    @State private var showingBiometricsUnavailableError = false
    @State private var biometricEnrollmentInProgress = false
    
    
    init(store: Store<AppState>) {
        self.store = store
        self._viewStore = StateObject(wrappedValue: ViewStore(
            store: store,
            observe: { appState in
                LoginViewState(
                    isLoading: appState.user.isLoading,
                    error: appState.user.error,
                    shouldPromptForUpdate: appState.ui.shouldPromptForUpdate,
                    updateConfiguration: appState.ui.updatePrompt,
                    biometricStatus: appState.user.biometricsState
                    
                )
            }
        ))
    }
    
    
    
    var body: some View {
        ZStack {
            MainLoginView
            if (viewStore.state.isLoading) {
                Color.black.opacity(0.65) // Semi-transparent background
                    .edgesIgnoringSafeArea(.all) // Extend over safe areas
                
                ProgressView("Loading...") // Your loading indicator
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryRed))
                    .controlSize(.large)
                    .foregroundColor(.white)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.8)))
            }
        }.onAppear {
            viewStore.dispatch(UIActions.checkForUpdate)
        }
        .alert("Login Failed", isPresented: .constant(viewStore.state.error != nil)) {
            Button("OK") {
                viewStore.dispatch(UserActions.loginErrorsCleared)
//                UserDefaults.standard.removeObject(forKey: "savedEmail")
            }
        } message: {
            Text("We are currently unable to log you in. Please try again later.")
        }
        .alert("Enable \(BiometricUtility.biometricName)?", isPresented: $showingBiometricsUnenrolledError) {
            Button("OK") {
                
            }
        } message: {
            Text("Please sign in with your username and password to enable \(BiometricUtility.biometricName)")
        }
        .alert("Biometrics Not Available", isPresented: $showingBiometricsUnavailableError) {
            Button("OK") {
                biometricEnrollmentInProgress = true
            }
        } message: {
            Text("Biometric authentication is not available for your device. Please ensure you have a device passcode set and biometric settings are enabled.")
        }
        .alert(isPresented: $viewStore.state.shouldPromptForUpdate) {
            Alert(
                title: Text(viewStore.state.updateConfiguration?.title ?? ""),
                message: Text(viewStore.state.updateConfiguration?.message ?? ""),
                primaryButton: .default(Text(viewStore.state.updateConfiguration?.positiveActionTitle ?? "")) {
                    guard let updateUrl = viewStore.state.updateConfiguration?.updateUrl else {
                        viewStore.dispatch(UIActions.hideUpdateDialog)
                        return
                    }
                    UIApplication.shared.open(updateUrl)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var MainLoginView: some View {
        VStack {
            TitleView
            LogoView
            CredentialsView
            Spacer()
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [.brandBackgroundSecondary,
                                                       .brandBackgroundSecondary
            ]), startPoint: .top, endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
        )
    }
    
    private var CredentialsView: some View {
        VStack {
            VStack(alignment: .leading, spacing: 15) {
                TextField("Textfield.Placeholder.Username", text: $email)
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textFieldStyle(PlaceholderStyle())
                    .background(Color.white)
                    .cornerRadius(20.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
                
                HStack {
                    SecureField("Textfield.Placeholder.Password", text: $password, onCommit: {
                        Task {
                            viewStore.dispatch(UserActions.login(email: email, password: password, enableBiometrics: biometricEnrollmentInProgress))
                        }                })
                    .padding()
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .textFieldStyle(PlaceholderStyle())
                    
//                    if (BiometricUtility.isBiometricSupported) {
                    if (true) {
                        Button(action: {
                            Task {
                                handleBiometricInteraction()
                            }
                        }) {
                            Image(systemName: "faceid")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                                .foregroundColor(.green)
                        }
                    }
                }
                .background(.white)
                .cornerRadius(20.0)
                .shadow(radius: 10.0, x:20, y: 10)
            }.padding([.leading, .trailing], 27.5)
            
            Button(action: {
                Task {
                    viewStore.dispatch(UserActions.login(email: email, password: password, enableBiometrics: biometricEnrollmentInProgress))
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 300, height: 50)
                //                    .background(Color.green)
                    .background(.primaryGreen)
                    .cornerRadius(15.0)
                    .shadow(radius: 10.0, x: 20, y: 10)
            }.padding(.top, UIScreen.main.bounds.height * 0.05)
        }
    }
    
    private func handleBiometricInteraction() {
        switch viewStore.state.biometricStatus {
        case .unenrolled:
            showingBiometricsUnenrolledError = true
        case .enrolled:
            viewStore.dispatch(UserActions.biometricLogin)
        case .unavailable:
            showingBiometricsUnavailableError = true
        }
    }
    
    private var EmailField: some View {
        TextField("Email", text: $email)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .textFieldStyle(PlaceholderStyle())
            .background(Color.white)
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
    
    private var PasswordField: some View {
        SecureField("Password", text: $password)
            .padding()
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .background(Color.white)
            .textFieldStyle(PlaceholderStyle())
            .cornerRadius(20.0)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
    
    private var LogoView: some View {
        Image("wreath")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: UIScreen.main.bounds.width * 0.75)
            .padding(.bottom, 20)
    }
    
    private var TitleView: some View {
        Text("Christmas Tracker")
            .font(.largeTitle).foregroundColor(Color.white)
            .padding([.top, .bottom], 20)
            .shadow(radius: 10.0, x: 20, y: 10)
    }
}

struct LoginViewState: Equatable {
    var isLoading: Bool
    var error: UserError?
    var shouldPromptForUpdate: Bool
    var updateConfiguration: UpdateAlertConfiguration?
    var biometricStatus: BiometricUtility.BiometricState
}

#Preview {
    LoginView_Redux(store: StoreEnvironmentKey.defaultValue)
}

#Preview {
    LoginView_Redux(store: StoreEnvironmentKey.defaultValue)
        .preferredColorScheme(.dark)
}
