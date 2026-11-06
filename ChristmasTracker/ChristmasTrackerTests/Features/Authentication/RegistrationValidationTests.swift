// RegistrationValidationTests.swift
// ChristmasTrackerTests
//
// Story C2 — Group B: Registration form validation tests.
//
// Expected interface (implementer must conform to this):
//
//   enum RegistrationFormValidator {
//       static func isValid(
//           firstName: String,
//           lastName: String,
//           email: String,
//           password: String,
//           confirmPassword: String,
//           registrationCode: String
//       ) -> Bool
//   }
//
// Validation rules:
//   firstName:        non-empty after trimming whitespace
//   lastName:         non-empty after trimming whitespace
//   email:            contains "@" and "."
//   password:         >= 8 chars, has uppercase, lowercase, digit, special char (not letter/digit)
//   confirmPassword:  equals password exactly
//   registrationCode: non-empty after trimming whitespace

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("RegistrationFormValidator")
struct RegistrationValidationTests {

    // Convenience: a set of known-valid field values used as the base for each test.
    private let validFirstName = "Alice"
    private let validLastName = "Smith"
    private let validEmail = "alice@example.test"
    private let validPassword = "P@ssword1-FAKE"   // uppercase, lowercase, digit, special char, >= 8
    private let validConfirmPassword = "P@ssword1-FAKE"
    private let validRegistrationCode = "CODE-FAKE"

    // MARK: - B1: All valid → isValid returns true

    @Test("All 6 fields valid returns true")
    func allFieldsValidReturnsTrue() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == true
        )
    }

    // MARK: - B2: Empty firstName → false

    @Test("Empty firstName returns false")
    func emptyFirstNameReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: "",
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    @Test("Whitespace-only firstName returns false")
    func whitespaceOnlyFirstNameReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: "   ",
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B3: Empty lastName → false

    @Test("Empty lastName returns false")
    func emptyLastNameReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: "",
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    @Test("Whitespace-only lastName returns false")
    func whitespaceOnlyLastNameReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: "   ",
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B4: Email without "@" → false

    @Test("Email without at-sign returns false")
    func emailWithoutAtSignReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: "aliceexample.test",
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    @Test("Email without dot returns false")
    func emailWithoutDotReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: "alice@exampletest",
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B5: Password < 8 chars → false

    @Test("Password shorter than 8 characters returns false")
    func passwordTooShortReturnsFalse() {
        // "P@ss1X" is 6 chars — has uppercase, lowercase, digit, special char but too short
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: "P@ss1X",
                confirmPassword: "P@ss1X",
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B6: Password missing uppercase → false

    @Test("Password missing uppercase returns false")
    func passwordMissingUppercaseReturnsFalse() {
        // "p@ssword1" — lowercase, digit, special char, no uppercase, >= 8 chars
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: "p@ssword1",
                confirmPassword: "p@ssword1",
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B7: Password missing digit → false

    @Test("Password missing digit returns false")
    func passwordMissingDigitReturnsFalse() {
        // "P@sswordX" — uppercase, lowercase, special char, no digit, >= 8 chars
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: "P@sswordX",
                confirmPassword: "P@sswordX",
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B8: Password missing special char → false

    @Test("Password missing special character returns false")
    func passwordMissingSpecialCharReturnsFalse() {
        // "Password1" — uppercase, lowercase, digit, no special char, >= 8 chars
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: "Password1",
                confirmPassword: "Password1",
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B9: confirmPassword mismatch → false

    @Test("Mismatched confirmPassword returns false")
    func mismatchedConfirmPasswordReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validPassword + "X",
                registrationCode: validRegistrationCode
            ) == false
        )
    }

    // MARK: - B10: Empty registrationCode → false

    @Test("Empty registrationCode returns false")
    func emptyRegistrationCodeReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: ""
            ) == false
        )
    }

    @Test("Whitespace-only registrationCode returns false")
    func whitespaceOnlyRegistrationCodeReturnsFalse() {
        #expect(
            RegistrationFormValidator.isValid(
                firstName: validFirstName,
                lastName: validLastName,
                email: validEmail,
                password: validPassword,
                confirmPassword: validConfirmPassword,
                registrationCode: "   "
            ) == false
        )
    }

    // MARK: - B11: Valid then one invalid field flips the result

    @Test("All valid then empty registrationCode makes form invalid")
    func allValidThenEmptyRegistrationCodeMakesFormInvalid() {
        let allValid = RegistrationFormValidator.isValid(
            firstName: validFirstName,
            lastName: validLastName,
            email: validEmail,
            password: validPassword,
            confirmPassword: validConfirmPassword,
            registrationCode: validRegistrationCode
        )
        #expect(allValid == true)

        let oneInvalid = RegistrationFormValidator.isValid(
            firstName: validFirstName,
            lastName: validLastName,
            email: validEmail,
            password: validPassword,
            confirmPassword: validConfirmPassword,
            registrationCode: ""
        )
        #expect(oneInvalid == false)
    }
}
