//
//  CreatePasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/5/22.
//

import SwiftUI

struct CreatePasswordView: View {
    @EnvironmentObject var _session: UserSession
    var body: some View {
        Form {
            Text("""
Your password must meet the following requirements:
⊝ Be between 6 and 64 characters.
⊝ Contain at least 1 number.
⊝ Contain at least 1 special character.
""")
            
            Section("New password") {
                TextField("New password", text: .constant(""))
            }
            Section("Re-type password") {
                TextField("Password confirmation", text: .constant(""))
            }
            Section {
                Button(action: {
                    //                        Task {
                    //                            await self.viewModel.doLogin()
                    //                        }
                    _session.enrollmentInProgress = false
                }) {
                    Text("Set password")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
                        .background(Color.green)
                        .cornerRadius(15.0)
                }//.padding(.top, UIScreen.main.bounds.height * 0.05)
                .buttonStyle(.plain)
            }
            .listRowBackground(Color(UIColor.systemGroupedBackground))
        }
        .navigationTitle("Create password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CreatePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePasswordView()
    }
}
