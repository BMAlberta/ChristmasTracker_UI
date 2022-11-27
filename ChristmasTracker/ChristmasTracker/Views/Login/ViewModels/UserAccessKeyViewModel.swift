//
//  UserAccessKeyViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/21/22.
//

import Foundation
import Combine

class UserAccessKeyViewModel: ObservableObject {
    
    enum ValidationState {
        case missingFields([String])
        case passwordMismatch
        case invalidEmail
        case noError
    }
    
    @Published var isLoading = false
    @Published var isErrorState = false
    @Published var isSuccessState = false
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var accessKey = ""
    @Published var errorState: ValidationState = .noError
    @Published var alertConfiguration: AlertConfiguration?
    
    private var _session: UserSession
    
    init(_ session: UserSession) {
        _session = session
    }
    var suppliedPasswordIsValid: Bool {
        let newPasswordPresent = newPassword.count > 0
        let confirmPasswordPresent = confirmPassword.count > 0
        let passwordsMatch = newPassword == confirmPassword
        
        return newPasswordPresent && confirmPasswordPresent && passwordsMatch
    }
    
    
    var suppliedEmailIsValid: Bool {
        let emailPresent = email.count > 0
        return emailPresent
    }
    
    
    func allRequiredFieldsPresent() -> Bool {
        
        let firstNamePresent = firstName.count > 0
        let lastNamePresent = lastName.count > 0
        let emailValid = suppliedEmailIsValid
        let passwordValid = suppliedPasswordIsValid
        let accessKeyPresent = accessKey.count > 0
        
        return firstNamePresent
        && lastNamePresent
        && emailValid
        && passwordValid
        && accessKeyPresent
    }
    
    
    var computeValidationState: ValidationState {
        
        var missingFields: [String] = []
        
        if (firstName.count == 0) {
            missingFields.append("Firat Name")
        }
        if (lastName.count == 0) {
            missingFields.append("Last Name")
        }
        if (email.count == 0) {
            missingFields.append("Email")
        }
        if (newPassword.count == 0 || confirmPassword.count == 0) {
            missingFields.append("Password")
        }
        if (accessKey.count == 0) {
            missingFields.append("Access Key")
        }
        
        if (missingFields.count > 0) {
            return .missingFields(missingFields)
        }
        
        if suppliedEmailIsValid {
            return .invalidEmail
        }
        
        if suppliedPasswordIsValid {
            return .passwordMismatch
        }
        
        return .noError
    }
    
    private func generateParameterModel() -> AccessKeyEnrollmentModel {
        return AccessKeyEnrollmentModel(firstName: firstName,
                                        lastName: lastName,
                                        email: email,
                                        newPassword: newPassword,
                                        confirmPassword: confirmPassword,
                                        accessKey: accessKey)
    }
    
    
    @MainActor
    func registerUser() async {
        
        self.isLoading = true
        
        
        guard case .noError = self.errorState else {
            self.isErrorState = true
            self.isLoading = false
           return
         }
    
        do {
            let model = generateParameterModel()
            let response = try await EnrollServiceStore.enrollWithAccessKey(model)
            self.isLoading = false
            
            if !response.success {
                let alertConfig = AlertConfiguration(title: "Registration Error",
                                                     message: response.error.errorMessage,
                                                     positiveActionTitle: "Ok")
                self.alertConfiguration = alertConfig
                self.isSuccessState = false
                self.isErrorState = true
            } else {
                let alertConfig = AlertConfiguration(id: .success,
                                                     title: "Success!",
                                                     message: "Enrollment successful. Please login with the email address and password provided.",
                                                     positiveActionTitle: "Ok")
                self.alertConfiguration = alertConfig
                self.isErrorState = false
                self.isSuccessState = true
            }
            
            
        } catch {
            print(error.localizedDescription)
            self.isLoading = false
            self.isErrorState = true
            //Generate error state.
        }
    }
}
