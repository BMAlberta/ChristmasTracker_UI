//
//  BiometricUtilities.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 12/1/22.
//

import Foundation
import LocalAuthentication

struct BiometricUtility {
    
    enum BiometricKeychainError: Error {
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        case noUsernameStored
        case unexpectedUsernameData
        case usernameMismatch
        case unknownError
    }
    
    static var isBiometricSupported: Bool {
        switch LAContext().biometricType {
        case .faceID, .touchID:
            return true
        case .none, .opticID:
            return false
        }
    }
    
    static var biometricName: String {
        switch LAContext().biometricType {
        case .touchID:
            return "Touch ID®"
        case .faceID:
            return "Face ID®"
        case .none, .opticID:
            return ""
        }
    }
    
    static var biometricStatus: BiometricState {
        
        guard Self.isBiometricSupported else {
            return .unavailable
        }
        
        guard let _ = Self.getStoredUsername() else {
            return .unenrolled
        }
        return .enrolled
    }
    
    enum BiometricState: Codable {
        case unenrolled
        case enrolled
        case unavailable
    }
    
    static func handleBiometricEnrollment(_ creds: Credentials) throws {
        // Store username and password in the keychain
        let access = SecAccessControlCreateWithFlags(nil,
                                                     kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                     .biometryCurrentSet,
                                                     nil)
        
        guard let encodedPassword = creds.password.data(using: String.Encoding.utf8) else {
            throw BiometricKeychainError.unexpectedPasswordData
        }
        
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: creds.username,
                                    kSecAttrService as String: "ChristmasTrackerAPI_Biometric",
                                    kSecAttrAccessControl as String: access as Any,
                                    kSecUseAuthenticationContext as String: LAContext(),
                                    kSecValueData as String: encodedPassword]
        
        print(query)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print(status.description)
            throw BiometricKeychainError.unhandledError(status: status)
        }
        
        do {
            try Self.storeUsername(username: creds.username)
        } catch {
            try Self.deleteStoredCredentials()
            throw BiometricKeychainError.unknownError
        }
    }
    
    
    
    static func getStoredUsername() -> String? {
        
        let fetchQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrLabel as String: "ChristmasTracker_username",
                                         kSecReturnAttributes as String: true,
                                         kSecReturnData as String: true]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(fetchQuery as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let fetchedItem = item as? [String: Any],
              let usernameData = fetchedItem[kSecValueData as String] as? Data,
              let username = String(data: usernameData, encoding: String.Encoding.utf8) else {
            return nil
        }
        return username
    }
    
    
    static func clearStoredUsername() {
        
        let deleteQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrLabel as String: "ChristmasTracker_username"]
        
        SecItemDelete(deleteQuery as CFDictionary)
    }
    
    static func storeUsername(username: String) throws {
        
        guard let encodedUsername = username.data(using: String.Encoding.utf8) else {
            throw BiometricKeychainError.unexpectedUsernameData
        }
        
        let addquery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                       kSecAttrLabel as String: "ChristmasTracker_username",
                                       kSecValueData as String: encodedUsername]
        
        let status = SecItemAdd(addquery as CFDictionary, nil)
        guard status == errSecSuccess else {
            print(status.description)
            throw BiometricKeychainError.unhandledError(status: status)
        }
    }
    
    static func getStoredCredentials() throws -> Credentials {
        
        guard let storedUsername = Self.getStoredUsername() else {
            throw BiometricKeychainError.noUsernameStored
        }
        
        let context = LAContext()
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                     kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                     .biometryCurrentSet,
                                                           nil) else {
            throw BiometricKeychainError.unhandledError(status: -1)
        }
        context.localizedReason = "Access your login credentials."
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecAttrService as String: "ChristmasTrackerAPI_Biometric",
                                    kSecAttrAccessControl as String: access,
                                    kSecUseAuthenticationContext as String: context,
                                    kSecReturnData as String: true]
        
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw BiometricKeychainError.noPassword
        }
        guard status == errSecSuccess else {
            throw BiometricKeychainError.unhandledError(status: status)
        }
        
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8),
            let account = existingItem[kSecAttrAccount as String] as? String
        else {
            throw BiometricKeychainError.unexpectedPasswordData
        }
        
        guard account == storedUsername else {
            throw BiometricKeychainError.usernameMismatch
        }
        let credentials = Credentials(username: account, password: password)
        return credentials
    }
    
    static func deleteStoredCredentials() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "ChristmasTrackerAPI_Biometric"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BiometricKeychainError.unhandledError(status: status)
        }
        
        Self.clearStoredUsername()
        UserDefaults.standard.removeObject(forKey: "biometricUser")
    }
    
}

extension LAContext {
    enum BiometricType: String {
        case none
        case touchID
        case faceID
        case opticID
    }
    
    var biometricType: BiometricType {
        var error: NSError?
        
        guard self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch self.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
}
