//
//  RegistrationFormValidator.swift
//  ChristmasTracker
//
//  Created for Story C2.
//

import Foundation

nonisolated struct RegistrationFormValidator {
    nonisolated static func isValid(
        firstName: String,
        lastName: String,
        email: String,
        password: String,
        confirmPassword: String,
        registrationCode: String
    ) -> Bool {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard isValidEmail(email) else { return false }
        guard isValidPassword(password) else { return false }
        guard password == confirmPassword else { return false }
        guard !registrationCode.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return true
    }

    nonisolated static func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }

    nonisolated static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        guard password.contains(where: { $0.isUppercase }) else { return false }
        guard password.contains(where: { $0.isLowercase }) else { return false }
        guard password.contains(where: { $0.isNumber }) else { return false }
        guard password.contains(where: { !$0.isLetter && !$0.isNumber }) else { return false }
        return true
    }
}
