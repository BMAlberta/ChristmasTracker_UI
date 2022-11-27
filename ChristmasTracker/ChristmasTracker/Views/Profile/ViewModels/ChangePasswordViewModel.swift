//
//  ChangePasswordViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/5/21.
//

import Foundation
import Combine

class ChangePasswordViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isErrorState = true
    @Published var isSuccessState = false
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var newPasswordConfirmation: String = ""
    
    private var _session: UserSession
    
    init(_ session: UserSession) {
        _session = session
    }
    
    @MainActor
    func resetPassword() async {
        self.isLoading = true
        
        let newPasswordModel = ChangePasswordModel(oldPassword: currentPassword,
                                                   newPassword: newPassword,
                                                   newPasswordConfirmation: newPasswordConfirmation)
        
        do {
            
            guard doesPasswordMeetRequirements() else {
                throw AuthServiceError.unknown
            }
            
            let passwordChangeResponse = try await AuthServiceStore.resetPassword(model: newPasswordModel)
            print(passwordChangeResponse)
            self.isLoading = false
            self.isSuccessState = true
            self.isErrorState = false
        } catch {
            print(error.localizedDescription)
            self.isLoading = false
            self.isErrorState = true
            self.isSuccessState = false
        }
    }
    
    func doesPasswordMeetRequirements() -> Bool {
        let newPasswordsMatch = newPassword == newPasswordConfirmation
        let newPasswordContainsData = newPassword.count > 0
        let newPasswordConfirmationContainsData = newPasswordConfirmation.count > 0
        
        return newPasswordsMatch && newPasswordContainsData && newPasswordConfirmationContainsData
    }
}
