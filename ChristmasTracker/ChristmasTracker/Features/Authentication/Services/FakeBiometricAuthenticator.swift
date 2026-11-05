//
//  FakeBiometricAuthenticator.swift
//  ChristmasTracker
//
//  Test double for BiometricAuthenticating. Lives in the production module so
//  both unit tests and SwiftUI Previews can share the same fixture without
//  duplicating the type.
//

import Foundation

/// A configurable fake for `BiometricAuthenticating` suitable for unit tests
/// and SwiftUI Previews.
internal final class FakeBiometricAuthenticator: BiometricAuthenticating {

    // MARK: - Stubs

    var stubbedBiometryType: BiometricType = .faceID
    var stubbedIsAvailable: Bool = true
    var stubbedResult: BiometricResult = .success
    var stubbedBiometryTypeName: String = "Face ID"
    var stubbedReadiness: BiometricReadiness = .ready

    // MARK: - Observation

    /// Incremented on every call to `authenticate(_:)`. Lets tests assert how many
    /// times a biometric prompt was triggered without inspecting private state.
    private(set) var evaluationCount: Int = 0

    /// Resets `evaluationCount` to zero. Useful when a test needs to isolate a
    /// specific phase of a multi-step scenario.
    func resetEvaluationCount() {
        evaluationCount = 0
    }

    // MARK: - BiometricAuthenticating

    var biometryType: BiometricType { stubbedBiometryType }
    var biometryTypeName: String { stubbedBiometryTypeName }
    var isAvailable: Bool { stubbedIsAvailable }
    var readiness: BiometricReadiness { stubbedReadiness }

    func authenticate(reason: String) async -> BiometricResult {
        evaluationCount += 1
        return stubbedResult
    }
}
