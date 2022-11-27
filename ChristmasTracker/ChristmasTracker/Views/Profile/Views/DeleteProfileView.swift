//
//  DeleteProfileView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/6/22.
//

import SwiftUI

struct DeleteProfileView: View {
    @State private var alertPresented = false
    @State private var selection = 0
    @EnvironmentObject private var _session: UserSession
    private var isOwner = true
    var body: some View {
        VStack {
            Form {
                Section {
                    Text("""
By deleting your account, all of your information will be permanently removed from our systems. Lost information includes, but is not limited to:
 
⊝ User profile (name, email, password, etc.)
⊝ Purchase statistics including history.
⊝ Gift entries

Additionally, members of your group will no longer see your entries.
""")
                }
                
                if isOwner {
                    Section("Select new group owner") {
                        Text("You are a group owner, you must select a new owner before deleting your profile.")
                        Picker("Menu picker", selection: .constant(1)) {
                            Text("John Doe")
                            Text("Jane Doe")
                            Text("Billy Doe")
                            Text("John Doe")
                            Text("Jane Doe")
                            Text("Billy Doe")
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("Confirm email") {
                    TextField("Email address", text: .constant(""))
                }
                Section("Confirm password") {
                    TextField("Password", text: .constant(""))
                }
                Section {
                    Button(action: {
                        //                        Task {
                        //                            await self.viewModel.doLogin()
                        //                        }
                        //                            self.shouldShowVerificationScreen = true
                        alertPresented = true
                    }) {
                        Text("Delete")
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
            }.navigationTitle("Delete Account")
                .alert(isPresented: $alertPresented) {
                    Alert(
                        title: Text("Confirmation"),
                        message: Text("By deleting your account, all of your information including your profile, purchase history, gift entries, etc. will be permanently lost. You will not be able to recover this data.\n\n By confirming, you acknowledge that your information will be removed and cannot be recovered."),
                        primaryButton: .default(Text("Keep Account")) {
                            
                        },
                        secondaryButton: .destructive(Text("I Understand, Delete Account")) {
                            
                        }
                    )
                }
        }
    }
}

struct DeleteProfileView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteProfileView()
    }
}
