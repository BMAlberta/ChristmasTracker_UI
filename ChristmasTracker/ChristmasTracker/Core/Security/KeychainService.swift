//
//  KeychainService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation
import Security
import LocalAuthentication

/// Thread-safe keychain operations
/// CLASS (not actor): Keychain APIs are already thread-safe, no mutable state
enum KeychainService {

    enum AccessControl {
        case afterFirstUnlock
        case biometry
    }
    
    enum KeychainError: Error, LocalizedError {
        case unableToStore
        case itemNotFound
        case unableToDelete
        case biometricNotAvailable
        case biometricFailed
        
        var errorDescription: String? {
            switch self {
            case .unableToStore: return "Failed to store item in keychain"
            case .itemNotFound: return "Item not found in keychain"
            case .unableToDelete: return "Failed to delete item from keychain"
            case .biometricNotAvailable: return "Biometric authentication not available"
            case .biometricFailed: return "Biometric authentication failed"
            }
        }
    }
    
    /// Store value (synchronous - no await needed!)
    static func set(_ value: String, for key: String, accessControl: AccessControl = .afterFirstUnlock) throws {
        let data = value.data(using: .utf8)!
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        switch accessControl {
        case .afterFirstUnlock:
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            
        case .biometry:
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            ) else {
                throw KeychainError.biometricNotAvailable
            }
            query[kSecAttrAccessControl as String] = access
        }
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            LogError("Keychain store failed: \(status)", category: .auth)
            throw KeychainError.unableToStore
        }
        
        LogDebug("Keychain stored: \(key)", category: .auth)
    }
    
    /// Retrieve value (synchronous - no await!)
    static func get(_ key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            LogError("Keychain get failed: \(status)", category: .auth)
            throw KeychainError.itemNotFound
        }
        
        LogDebug("Keychain retrieved: \(key)", category: .auth)
        return string
    }
    
    /// Retrieve with biometric prompt (async for biometric prompt, not actor)
    static func getWithBiometric(_ key: String, reason: String = "Authenticate to access Christmas Tracker") async throws -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw KeychainError.biometricNotAvailable
        }
        
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        
        guard success else {
            throw KeychainError.biometricFailed
        }
        
        return try get(key)
    }
    
    static func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            LogError("Keychain delete failed: \(status)", category: .auth)
            throw KeychainError.unableToDelete
        }
        
        LogDebug("Keychain deleted: \(key)", category: .auth)
    }
    
    static func clear() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        SecItemDelete(query as CFDictionary)
        LogDebug("Keychain cleared", category: .auth)
    }
}
