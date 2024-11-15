//
//  UserVerificationView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/29/21.
//

import SwiftUI

struct UserVerificationView: View {
    @State private var shouldShowCreatePasswordView = false
    var body: some View {
        VStack {
            Form {
                Section {
                    Text("Before going any further, we need to verify that you have access to the email address provided.\nAn email with a verification code has been sent to \nparameterizedEmail@gmail.com")
                }
                Section("Please enter the verification code:") {
                    TextField("Verification Code", text: .constant(""))
                }
                Section {
                    Button(action: {
                        //                        Task {
                        //                            await self.viewModel.doLogin()
                        //                        }
                        self.shouldShowCreatePasswordView = true
                    }) {
                        Text("Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                            .background(Color.green)
                            .cornerRadius(15.0)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color(UIColor.systemGroupedBackground))
                Section("No code?") {
                    Button(action: {
                        //                        Task {
                        //                            await self.viewModel.doLogin()
                        //                        }
                    }) {
                        Text("Resend code")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                            .background(Color.red)
                            .cornerRadius(15.0)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("Email Verification")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $shouldShowCreatePasswordView, destination: {
                CreatePasswordView()
                EmptyView()
            })
        }
    }
}

struct UserVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        UserVerificationView()
    }
}
