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
