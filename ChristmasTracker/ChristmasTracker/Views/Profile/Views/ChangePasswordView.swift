//
//  ChangePasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/23/21.
//

import SwiftUI

struct ChangePasswordView: View {
    @StateObject var viewModel: ChangePasswordViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Text("New password must be at least 6 characters long.")
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Old Password", text: $viewModel.currentPassword)
            SecureField("New Password", text: $viewModel.newPassword)
            SecureField("Confirm Password", text: $viewModel.newPasswordConfirmation)
            Section {
                Button(action: {
                    Task {
                        await self.viewModel.resetPassword()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("Save")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .padding(10)
                .background(self.viewModel.doesPasswordMeetRequirements() ? Color.green : Color.gray)
//                .background(((viewModel.newPassword == viewModel.newPasswordConfirmation) && (viewModel.newPasswordConfirmation.count > 0 && viewModel.newPassword.count > 0)) ? Color.green : Color.gray)
                .cornerRadius(8)
                .disabled(!self.viewModel.doesPasswordMeetRequirements())
//                .disabled((viewModel.newPassword != viewModel.newPasswordConfirmation) && (viewModel.newPasswordConfirmation.count > 0 && viewModel.newPassword.count > 0))
            }
            .alert(isPresented: $viewModel.isErrorState) {
                Alert(title: Text("Password Change Failed"), message: Text("Unable to process your change password request. Please try again."), dismissButton: .default(Text("Ok")))
            }
            .alert(isPresented: $viewModel.isSuccessState) {
                Alert(title: Text("Password Changed"), message: Text("Your password has been successfully changed."), dismissButton: .default(Text("Ok"), action: { self.presentationMode.wrappedValue.dismiss() }))
            }
            
        }
        .navigationBarTitle("Change Password")
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ChangePasswordViewModel(UserSession())
        ChangePasswordView(viewModel: viewModel)
    }
}
