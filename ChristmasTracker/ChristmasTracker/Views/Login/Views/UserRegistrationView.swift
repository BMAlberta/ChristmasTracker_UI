//
//  UserRegistrationView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/29/21.
//

import SwiftUI

struct UserRegistrationView: View {
    @EnvironmentObject var _session: UserSession
    @State private var shouldShowVerificationScreen = false
    @State private var alertPresented = false
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section {
                        TextField("First Name", text: .constant(""))
                        TextField("Last Name", text: .constant(""))
                    }
                    Section {
                        TextField("Email address", text: .constant(""))
                            .textInputAutocapitalization(.never)
                    }
                    Section {
                        Button(action: {
                            //                        Task {
                            //                            await self.viewModel.doLogin()
                            //                        }
//                            self.shouldShowVerificationScreen = true
                            alertPresented = true
                        }) {
                            Text("Submit")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                                .background(Color.green)
                                .cornerRadius(15.0)
                        }.padding(.top, UIScreen.main.bounds.height * 0.05)
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color(UIColor.systemGroupedBackground))
                }.navigationTitle("Create an Account")
                    .alert(isPresented: $alertPresented) {
                        Alert(
                            title: Text("Email Already Registered"),
                            message: Text("A user with that email address already exists. Please check your information and try again.\n\nIf this is your email address, please reset your password."),
                            primaryButton: .default(Text("OK")) {
                                
                            },
                            secondaryButton: .destructive(Text("Reset Password")) {
                                _session.enrollmentInProgress = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                                    _session.passwordResetInProgress = true
                                }
                                
                            }
                        )
                    }
                NavigationLink(destination: UserVerificationView(), isActive: $shouldShowVerificationScreen) { EmptyView() }
            }
        }
    }
}

struct UserRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        UserRegistrationView()
    }
}
