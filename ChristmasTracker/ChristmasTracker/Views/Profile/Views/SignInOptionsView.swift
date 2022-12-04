//
//  SignInOptionsView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/1/22.
//

import SwiftUI

struct SignInOptionsView: View {
    @EnvironmentObject var _session: UserSession
    @ObservedObject var viewModel: SignInOptionsViewModel
    @State private var passwordConfirmation = ""
    @State private var showingPasswordConfirmationAlert = false
    var body: some View {
        Form {
            Section("Biometric Options") {
                Toggle("Enable Face ID", isOn: $viewModel.isBiometricEnabled)
                    .font(.footnote)
                    .onChange(of: viewModel.isBiometricEnabled) { value in
                        self.viewModel.handleBiometricToggle(targetValue: value, confirmedPassword: passwordConfirmation)
                    }
                Text("Enabling Face ID allows you to quickly sign in without using your username and password. If you share your device with others, they may be able to access your account if their identity is registered to your device.")
                .font(.caption)
                .alert("New List", isPresented: $showingPasswordConfirmationAlert, actions: {
                    TextField("List Name", text: $passwordConfirmation)

                    Button("Confirm", action: {
                        Task {
                            self.viewModel.enableBiometricAuth(confimedPassword: passwordConfirmation)
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
    }
}

struct SignInOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        SignInOptionsView(viewModel: SignInOptionsViewModel(UserSession()))
    }
}
