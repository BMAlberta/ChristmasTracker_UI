//
//  BiometricAuthenticating.swift
//  ChristmasTracker
//
//  Protocol seam for biometric authentication. LocalAuthenticationService is the
//  production implementation; FakeBiometricAuthenticator (same module) is used in
//  unit tests and SwiftUI Previews.
//

import Foundation
import LocalAuthentication
import TrackerInstrumentation

// MARK: - BiometricReadiness

/// Describes whether the device hardware can service a biometric authentication request.
internal enum BiometricReadiness: Equatable {
    case noHardware
    case ready
    case needsSetup(reason: BiometricSetupReason)
}

/// The specific reason a device with biometric hardware cannot evaluate biometrics right now.
internal enum BiometricSetupReason: Equatable {
    case passcodeNotSet
    case notEnrolled
    case disabledForApp
    case lockedOut
}

/// Maps raw `LAContext` probe results to `BiometricReadiness`.
internal nonisolated func biometricReadiness(
    biometryPresent: Bool,
    canEvaluate: Bool,
    errorCode: Int?
) -> BiometricReadiness {
    guard biometryPresent else { return .noHardware }
    guard !canEvaluate else { return .ready }
    guard let code = errorCode else { return .needsSetup(reason: .notEnrolled) }
    switch code {
    case LAError.Code.passcodeNotSet.rawValue:
        return .needsSetup(reason: .passcodeNotSet)
    case LAError.Code.biometryNotEnrolled.rawValue:
        return .needsSetup(reason: .notEnrolled)
    case LAError.Code.biometryNotAvailable.rawValue:
        return .needsSetup(reason: .disabledForApp)
    case LAError.Code.biometryLockout.rawValue:
        return .needsSetup(reason: .lockedOut)
    default:
        return .needsSetup(reason: .notEnrolled)
    }
}

/// Returns a user-facing message and whether tapping the action should open Settings.
internal nonisolated func biometricReadinessMessage(
    for readiness: BiometricReadiness,
    biometryTypeName: String
) -> (message: String, opensSettings: Bool) {
    switch readiness {
    case .noHardware:
        return ("", false)
    case .ready:
        return ("", false)
    case .needsSetup(let reason):
        switch reason {
        case .passcodeNotSet:
            return (
                "A passcode is required to use biometric sign-in. Set a passcode in Face ID & Passcode in Settings.",
                true
            )
        case .notEnrolled:
            return (
                "No biometric data is enrolled on this device. Add biometrics in Face ID & Passcode in Settings.",
                true
            )
        case .disabledForApp:
            return (
                "\(biometryTypeName) is turned off for Christmas Tracker. Check \(biometryTypeName) & Passcode in Settings.",
                true
            )
        case .lockedOut:
            return (
                "Biometrics are locked out due to too many failed attempts. Re-enable them in Face ID & Passcode in Settings.",
                true
            )
        }
    }
}

// MARK: - BiometricResult

/// The outcome of a single biometric authentication attempt.
internal enum BiometricResult: Equatable {
    case success
    case userCancelled
    case systemCancelled
    case userFallback
    case lockedOut
    case unavailable
    case failed
}

// MARK: - BiometricAuthenticating

/// Protocol seam for biometric authentication. Use `LocalAuthenticationService` in
/// production; inject `FakeBiometricAuthenticator` in tests and previews.
internal protocol BiometricAuthenticating: Sendable {
    var biometryType: BiometricType { get }
    var biometryTypeName: String { get }
    var isAvailable: Bool { get }
    var readiness: BiometricReadiness { get }
    func authenticate(reason: String) async -> BiometricResult
}

// MARK: - LocalAuthenticationService

/// Production implementation backed by `LAContext`. Creates a fresh context per attempt.
internal final class LocalAuthenticationService: BiometricAuthenticating {

    // MARK: - BiometricAuthenticating

    var biometryType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType == .faceID ? .faceID : .touchID
    }

    var biometryTypeName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometrics"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var readiness: BiometricReadiness {
        let context = LAContext()
        var nsError: NSError?
        let canEval = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError)
        let biometryPresent = context.biometryType != .none
        return biometricReadiness(
            biometryPresent: biometryPresent,
            canEvaluate: canEval,
            errorCode: nsError.map { Int($0.code) }
        )
    }

    @Instrumented
    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .success : .failed
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel:
                return .userCancelled
            case .systemCancel:
                return .systemCancelled
            case .userFallback:
                return .userFallback
            case .biometryLockout:
                return .lockedOut
            case .biometryNotAvailable, .biometryNotEnrolled:
                return .unavailable
            default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}
