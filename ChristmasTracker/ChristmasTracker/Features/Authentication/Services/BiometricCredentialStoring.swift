//
//  BiometricCredentialStoring.swift
//  ChristmasTracker
//
//  Protocol and implementations for storing the biometric-protected refresh token.
//  KeychainBiometricCredentialStore is the production implementation.
//  InMemoryBiometricCredentialStore is used in unit tests and SwiftUI Previews.
//

import Foundation
import Security
import LocalAuthentication
import TrackerInstrumentation

// MARK: - BiometricCredentialError

internal enum BiometricCredentialError: Error, Equatable {
    case userCancelled
    case biometricFailed
    case lockedOut
    case itemNotFound
    case itemInvalidated
    case other
}

// MARK: - BiometricCredentialStoring

internal protocol BiometricCredentialStoring: Sendable {
    func enrolledUser() -> (userId: String, firstName: String)?
    func enroll(refreshToken: String, userId: String, firstName: String) throws
    func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String
    func updateRefreshToken(_ newToken: String) throws
    func delete() throws
}

// MARK: - KeychainBiometricCredentialStore

/// Production implementation backed by the system Keychain.
/// The refresh token is stored with biometric access control.
/// Non-secret metadata (userId, firstName) is stored in plain attributes.
/// @unchecked Sendable: no instance state; all operations call thread-safe Security framework APIs.
internal final class KeychainBiometricCredentialStore: BiometricCredentialStoring, @unchecked Sendable {

    private static let key = "biometric.credential.v1"

    /// Injectable policy evaluator; non-nil only in tests.
    /// Production path (nil) calls `context.evaluatePolicy` directly.
    /// nonisolated(unsafe): written once per test instance before any async call; never mutated concurrently.
    nonisolated(unsafe) var policyEvaluator: ((LAPolicy, String) async throws -> Void)? = nil

    func enrolledUser() -> (userId: String, firstName: String)? {
        // Use interactionNotAllowed so this read never triggers a biometric prompt.
        // errSecInteractionNotAllowed means the item exists but requires interaction;
        // treat it as "not enrolled" for this call without deleting the item.
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: Self.key,
            kSecReturnAttributes: true,
            kSecReturnData: false,
            kSecUseAuthenticationContext: context,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess,
              let attrs = result as? [CFString: Any],
              let userId = attrs[kSecAttrService] as? String,
              let firstName = attrs[kSecAttrComment] as? String else {
            return nil
        }
        return (userId: userId, firstName: firstName)
    }

    func enroll(refreshToken: String, userId: String, firstName: String) throws {
        // Delete any existing entry first (ignore not-found error)
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: Self.key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw BiometricCredentialError.other
        }

        guard let tokenData = refreshToken.data(using: .utf8) else {
            throw BiometricCredentialError.other
        }

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: Self.key,
            kSecAttrService: userId,
            kSecAttrComment: firstName,
            kSecValueData: tokenData,
            kSecAttrAccessControl: access,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            throw BiometricCredentialError.other
        }
    }

    @Instrumented
    func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        do {
            if let evaluator = policyEvaluator {
                try await evaluator(.deviceOwnerAuthenticationWithBiometrics, reason)
            } else {
                try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            }
        } catch let laError as LAError {
            switch laError.code {
            case .authenticationFailed:
                throw BiometricCredentialError.biometricFailed
            case .systemCancel, .appCancel:
                throw BiometricCredentialError.userCancelled
            case .userCancel, .biometryLockout:
                throw BiometricCredentialError.lockedOut
            default:
                throw BiometricCredentialError.other
            }
        } catch {
            throw BiometricCredentialError.other
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: Self.key,
            kSecReturnData: true,
            kSecUseAuthenticationContext: context,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                throw BiometricCredentialError.other
            }
            return token
        case errSecItemNotFound:
            throw BiometricCredentialError.itemNotFound
        case errSecUserCanceled:
            throw BiometricCredentialError.userCancelled
        case errSecAuthFailed:
            throw BiometricCredentialError.biometricFailed
        default:
            throw BiometricCredentialError.other
        }
    }

    func updateRefreshToken(_ newToken: String) throws {
        guard let attrs = enrolledUser() else {
            throw BiometricCredentialError.itemNotFound
        }
        try delete()
        try enroll(refreshToken: newToken, userId: attrs.userId, firstName: attrs.firstName)
    }

    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: Self.key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // Ignore not-found — idempotent delete
        if status != errSecSuccess && status != errSecItemNotFound {
            throw BiometricCredentialError.other
        }
    }
}

// MARK: - InMemoryBiometricCredentialStore

/// In-memory test double for `BiometricCredentialStoring`.
/// Each instance is completely isolated — suitable for unit tests and SwiftUI Previews.
/// Uses `nonisolated` on all synchronous methods to satisfy Swift 6 strict concurrency
/// without requiring callers to use `await`.
internal final class InMemoryBiometricCredentialStore: BiometricCredentialStoring, @unchecked Sendable {

    // MARK: - Private storage (protected by a lock for thread safety)

    nonisolated(unsafe) private var stored: (refreshToken: String, userId: String, firstName: String)? // protected by lock
    private let lock = NSLock()

    // MARK: - Test configuration

    /// Set to a non-nil value to have `readRefreshToken` throw this error instead of returning the token.
    nonisolated(unsafe) var stubbedReadError: BiometricCredentialError? // protected by lock

    // MARK: - BiometricCredentialStoring

    nonisolated func enrolledUser() -> (userId: String, firstName: String)? {
        lock.withLock {
            stored.map { (userId: $0.userId, firstName: $0.firstName) }
        }
    }

    nonisolated func enroll(refreshToken: String, userId: String, firstName: String) throws {
        lock.withLock {
            stored = (refreshToken: refreshToken, userId: userId, firstName: firstName)
        }
    }

    nonisolated func readRefreshToken(reason: String) async throws(BiometricCredentialError) -> String {
        if let error = stubbedReadError {
            throw error
        }
        guard let entry = lock.withLock({ stored }) else {
            throw BiometricCredentialError.itemNotFound
        }
        return entry.refreshToken
    }

    nonisolated func updateRefreshToken(_ newToken: String) throws {
        try lock.withLock {
            guard var entry = stored else {
                throw BiometricCredentialError.itemNotFound
            }
            entry.refreshToken = newToken
            stored = entry
        }
    }

    nonisolated func delete() throws {
        lock.withLock {
            stored = nil
        }
    }
}
