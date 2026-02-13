//
//  DeviceFIngerprintService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

// Core/Security/DeviceFingerprintService.swift
import Foundation
import UIKit

/// Generates and persists unique device fingerprint
/// CLASS (not actor): Stateless, delegates to KeychainService
enum DeviceFingerprintService: Sendable {

    private static let keychainKey = "com.christmastracker.deviceFingerprintUUID"
        
    /// Get device fingerprint (synchronous!)
    static func getFingerprint() throws -> String {
        let uuid = try Self.getOrCreateUUID()
        let model = UIDevice.current.model
        let version = UIDevice.current.systemVersion
        
        let fingerprint = "\(uuid)-\(model)-\(version)"
        LogDebug("Device fingerprint: \(fingerprint)", category: .auth)
        
        return fingerprint
    }
    
    private static func getOrCreateUUID() throws -> String {
        do {
            let existing = try KeychainService.get(Self.keychainKey)
            LogDebug("Retrieved existing device UUID", category: .auth)
            return existing
        } catch KeychainService.KeychainError.itemNotFound {
            let uuid = UUID().uuidString
            try KeychainService.set(uuid, for: Self.keychainKey, accessControl: .afterFirstUnlock)
            LogDebug("Generated new device UUID", category: .auth)
            return uuid
        }
    }
}
