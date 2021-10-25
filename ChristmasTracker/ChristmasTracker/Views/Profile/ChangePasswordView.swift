//
//  ChangePasswordView.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/23/21.
//

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject var store: AppStore
    @State var model = ChangePasswordModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        let shouldDisplayError =  Binding<Bool>(
            get: { store.state.auth.isPasswordResetError == true},
            set: { _ in store.dispatch(.auth(action: .passwordResetError(error: nil))) }
        )
        
        let shouldDisplaySuccess =  Binding<Bool>(
            get: { store.state.auth.isPasswordResetError == false && store.state.auth.passwordResetSuccess == true},
            set: { _ in store.dispatch(.auth(action: .passwordResetError(error: nil))) }
        )
        
        
        Form {
            Text("New password must be at least 6 characters long.")
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Old Password", text: $model.oldPassword)
            SecureField("New Password", text: $model.newPassword)
            SecureField("Confirm Password", text: $model.newPasswordConfirmation)
            Section {
                Button(action: {
                    store.dispatch(.auth(action: .resetPassword(token: store.state.auth.token,
                                                                 model: model)))
                }) {
                    HStack {
                        Spacer()
                        Text("Save")
                        Spacer()
                    }
                }
                .foregroundColor(.white)
                .padding(10)
                .background(((model.newPassword == model.newPasswordConfirmation) && (model.newPasswordConfirmation.count > 0 && model.newPassword.count > 0)) ? Color.green : Color.gray)
                .cornerRadius(8)
                .disabled((model.newPassword != model.newPasswordConfirmation) && (model.newPasswordConfirmation.count > 0 && model.newPassword.count > 0))
            }
            .alert(isPresented: shouldDisplayError) {
                Alert(title: Text("Password Change Failed"), message: Text("Unable to process your change password request. Please try again."), dismissButton: .default(Text("Ok")))
            }
            .alert(isPresented: shouldDisplaySuccess) {
                Alert(title: Text("Password Changed"), message: Text("Your password has been successfully changed."), dismissButton: .default(Text("Ok"), action: { self.presentationMode.wrappedValue.dismiss() }))
            }
            
        }
        .navigationBarTitle("Change Password")
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        
        ChangePasswordView()
    }
}
