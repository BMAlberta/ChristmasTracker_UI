//
//  BiometricReadinessTests.swift
//  ChristmasTrackerTests
//
//  Tests for Story I2b-2a (S1): BiometricReadiness enum and pure mapping functions.
//
//  Contract (from Gate 1 spec, S1):
//
//    enum BiometricReadiness: Equatable {
//        case noHardware
//        case ready
//        case needsSetup(reason: BiometricSetupReason)
//    }
//    enum BiometricSetupReason: Equatable {
//        case passcodeNotSet
//        case notEnrolled
//        case disabledForApp
//        case lockedOut
//    }
//
//    func biometricReadiness(
//        biometryPresent: Bool,
//        canEvaluate: Bool,
//        errorCode: Int?
//    ) -> BiometricReadiness
//
//    func biometricReadinessMessage(
//        for readiness: BiometricReadiness,
//        biometryTypeName: String
//    ) -> (message: String, opensSettings: Bool)
//
//  Will fail to compile until:
//    - BiometricReadiness and BiometricSetupReason enums are defined
//    - biometricReadiness(biometryPresent:canEvaluate:errorCode:) free function is added
//    - biometricReadinessMessage(for:biometryTypeName:) free function is added
//

import Testing
import Foundation
import LocalAuthentication
@testable import ChristmasTracker

// MARK: - Suite

@Suite("BiometricReadiness mapping")
struct BiometricReadinessTests {

    // MARK: - biometricReadiness(biometryPresent:canEvaluate:errorCode:) mapping

    @Test("biometryPresent=false → .noHardware regardless of canEvaluate")
    func noHardwareWhenBiometryNotPresent() {
        let result = biometricReadiness(biometryPresent: false, canEvaluate: false, errorCode: nil)
        #expect(result == .noHardware)
    }

    @Test("biometryPresent=false, canEvaluate=true → .noHardware (canEvaluate is ignored)")
    func noHardwareWhenBiometryNotPresentEvenIfCanEvaluateTrue() {
        let result = biometricReadiness(biometryPresent: false, canEvaluate: true, errorCode: nil)
        #expect(result == .noHardware)
    }

    @Test("biometryPresent=true, canEvaluate=true → .ready")
    func readyWhenBiometryPresentAndCanEvaluate() {
        let result = biometricReadiness(biometryPresent: true, canEvaluate: true, errorCode: nil)
        #expect(result == .ready)
    }

    @Test(
        "biometryPresent=true, canEvaluate=false, known error codes map to needsSetup",
        arguments: [
            (LAError.Code.passcodeNotSet.rawValue, BiometricSetupReason.passcodeNotSet),
            (LAError.Code.biometryNotEnrolled.rawValue, BiometricSetupReason.notEnrolled),
            (LAError.Code.biometryNotAvailable.rawValue, BiometricSetupReason.disabledForApp),
            (LAError.Code.biometryLockout.rawValue, BiometricSetupReason.lockedOut),
        ]
    )
    func knownErrorCodesMapsToNeedsSetup(errorCode: Int, expectedReason: BiometricSetupReason) {
        let result = biometricReadiness(biometryPresent: true, canEvaluate: false, errorCode: errorCode)
        #expect(result == .needsSetup(reason: expectedReason))
    }

    @Test("biometryPresent=true, canEvaluate=false, errorCode=nil → .needsSetup(.notEnrolled) fallback")
    func nilErrorCodeFallsBackToNotEnrolled() {
        let result = biometricReadiness(biometryPresent: true, canEvaluate: false, errorCode: nil)
        #expect(result == .needsSetup(reason: .notEnrolled))
    }

    @Test("biometryPresent=true, canEvaluate=false, unknown errorCode=99 → .needsSetup(.notEnrolled) fallback")
    func unknownErrorCodeFallsBackToNotEnrolled() {
        let result = biometricReadiness(biometryPresent: true, canEvaluate: false, errorCode: 99)
        #expect(result == .needsSetup(reason: .notEnrolled))
    }

    // MARK: - biometricReadinessMessage(for:biometryTypeName:) mapping

    @Test(".noHardware → opensSettings=false")
    func noHardwareOpensSettingsFalse() {
        let (_, opensSettings) = biometricReadinessMessage(for: .noHardware, biometryTypeName: "Face ID")
        #expect(opensSettings == false)
    }

    @Test(".ready → opensSettings=false")
    func readyOpensSettingsFalse() {
        let (_, opensSettings) = biometricReadinessMessage(for: .ready, biometryTypeName: "Face ID")
        #expect(opensSettings == false)
    }

    @Test(".needsSetup(.passcodeNotSet) → opensSettings=true")
    func passcodeNotSetOpensSettingsTrue() {
        let (_, opensSettings) = biometricReadinessMessage(for: .needsSetup(reason: .passcodeNotSet), biometryTypeName: "Face ID")
        #expect(opensSettings == true)
    }

    @Test(".needsSetup(.notEnrolled) → opensSettings=true")
    func notEnrolledOpensSettingsTrue() {
        let (_, opensSettings) = biometricReadinessMessage(for: .needsSetup(reason: .notEnrolled), biometryTypeName: "Face ID")
        #expect(opensSettings == true)
    }

    @Test(".needsSetup(.disabledForApp) → opensSettings=true and message mentions biometryTypeName")
    func disabledForAppOpensSettingsTrueAndMentionsBiometryTypeName() {
        let typeName = "Face ID"
        let (message, opensSettings) = biometricReadinessMessage(for: .needsSetup(reason: .disabledForApp), biometryTypeName: typeName)
        #expect(opensSettings == true)
        #expect(message.contains(typeName),
                "Message for .disabledForApp must mention the biometryTypeName '\(typeName)' (got: \"\(message)\")")
    }

    @Test(".needsSetup(.lockedOut) → opensSettings=true")
    func lockedOutOpensSettingsTrue() {
        let (_, opensSettings) = biometricReadinessMessage(for: .needsSetup(reason: .lockedOut), biometryTypeName: "Face ID")
        #expect(opensSettings == true)
    }

    @Test(".needsSetup(.passcodeNotSet) message is non-empty")
    func passcodeNotSetMessageIsNonEmpty() {
        let (message, _) = biometricReadinessMessage(for: .needsSetup(reason: .passcodeNotSet), biometryTypeName: "Face ID")
        #expect(message.isEmpty == false)
    }

    @Test(".needsSetup(.notEnrolled) message is non-empty")
    func notEnrolledMessageIsNonEmpty() {
        let (message, _) = biometricReadinessMessage(for: .needsSetup(reason: .notEnrolled), biometryTypeName: "Face ID")
        #expect(message.isEmpty == false)
    }

    @Test(".needsSetup(.lockedOut) message is non-empty")
    func lockedOutMessageIsNonEmpty() {
        let (message, _) = biometricReadinessMessage(for: .needsSetup(reason: .lockedOut), biometryTypeName: "Touch ID")
        #expect(message.isEmpty == false)
    }

    @Test(".needsSetup(.disabledForApp) message mentions Touch ID when biometryTypeName is Touch ID")
    func disabledForAppMessageMentionsTouchID() {
        let typeName = "Touch ID"
        let (message, _) = biometricReadinessMessage(for: .needsSetup(reason: .disabledForApp), biometryTypeName: typeName)
        #expect(message.contains(typeName),
                "Message must reference '\(typeName)' (got: \"\(message)\")")
    }
}
