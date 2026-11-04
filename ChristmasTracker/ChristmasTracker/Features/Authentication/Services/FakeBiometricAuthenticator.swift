//
//  FakeBiometricAuthenticator.swift
//  ChristmasTracker
//
//  Test double for BiometricAuthenticating. Lives in the production module so
//  both unit tests and SwiftUI Previews can share the same fixture without
//  duplicating the type.
//
//  This file intentionally compiles against the BiometricAuthenticating protocol
//  and BiometricResult / BiometricType declared in BiometricAuthenticating.swift.
//  The file will not compile until that production file is added.
//

import Foundation

/// A configurable fake for `BiometricAuthenticating` suitable for unit tests
/// and SwiftUI Previews.
internal final class FakeBiometricAuthenticator: BiometricAuthenticating {

    // MARK: - Stubs

    var stubbedBiometryType: BiometricType = .faceID
    var stubbedIsAvailable: Bool = true
    var stubbedResult: BiometricResult = .success

    // MARK: - BiometricAuthenticating

    var biometryType: BiometricType { stubbedBiometryType }
    var isAvailable: Bool { stubbedIsAvailable }

    func authenticate(reason: String) async -> BiometricResult {
        stubbedResult
    }
}
