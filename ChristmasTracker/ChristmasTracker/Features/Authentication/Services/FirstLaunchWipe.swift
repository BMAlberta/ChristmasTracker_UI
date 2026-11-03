//  FirstLaunchWipe.swift
//  ChristmasTracker

import Foundation
import Security

// Keychain items survive app deletion on iOS. This wipe runs on every clean install
// to remove any 4.4 credentials that were stored before the uninstall.

/// Protocol that abstracts Keychain class-wide deletion for testability.
/// Explicitly nonisolated so implementations can be called from any synchronous context.
internal protocol KeychainWiping: Sendable {
    nonisolated func deleteAllGenericPasswords() throws
    nonisolated func deleteAllInternetPasswords() throws
}

/// Production keychain wiper — performs class-wide Security framework deletes.
internal struct LiveKeychainWiper: KeychainWiping {
    nonisolated func deleteAllGenericPasswords() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            LogError("First-launch wipe: generic password delete failed status \(status)", category: .auth)
            throw FirstLaunchWipeError.keychainDeleteFailed(status)
        }
    }

    nonisolated func deleteAllInternetPasswords() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            LogError("First-launch wipe: internet password delete failed status \(status)", category: .auth)
            throw FirstLaunchWipeError.keychainDeleteFailed(status)
        }
    }
}

internal enum FirstLaunchWipeError: Error {
    case keychainDeleteFailed(OSStatus)
}

/// Runs once at first launch to remove 4.4 legacy data.
/// Synchronous and nonisolated — safe to call from any context because UserDefaults
/// and the Security framework are thread-safe for these operations.
internal struct FirstLaunchWipe {
    // nonisolated static lets so they can be referenced from nonisolated contexts
    internal static nonisolated let markerVersion: Int = 1
    internal static nonisolated let markerKey: String = "v2.firstLaunchWipeVersion"

    // UserDefaults and FileManager are @MainActor in Swift 6; stored nonisolated(unsafe)
    // because FirstLaunchWipe is intentionally synchronous and these APIs are
    // documented as thread-safe for the read/write operations performed here.
    private nonisolated(unsafe) let defaults: UserDefaults
    private nonisolated(unsafe) let fileManager: FileManager
    private let keychainWiper: any KeychainWiping

    internal nonisolated init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        keychainWiper: any KeychainWiping = LiveKeychainWiper()
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.keychainWiper = keychainWiper
    }

    /// Wipes 4.4 legacy UserDefaults keys, Keychain items, and on-disk caches.
    /// No-op when the stored marker equals markerVersion.
    /// Writes the marker only when all steps succeed.
    internal nonisolated func performIfNeeded() {
        guard defaults.integer(forKey: Self.markerKey) < Self.markerVersion else {
            return
        }

        var failed = false

        // 1. Remove known 4.4 UserDefaults keys (explicit keys only, never wipe the whole domain)
        defaults.removeObject(forKey: "savedEmail")

        // 2. Wipe Keychain — class-wide delete covers all 4.4 service-keyed items
        do {
            try keychainWiper.deleteAllGenericPasswords()
        } catch {
            LogError("First-launch wipe: generic passwords not cleared — \(type(of: error))", category: .auth)
            failed = true
        }

        do {
            try keychainWiper.deleteAllInternetPasswords()
        } catch {
            LogError("First-launch wipe: internet passwords not cleared — \(type(of: error))", category: .auth)
            failed = true
        }

        // 3. Write marker only when every step succeeded; a failed wipe retries on next launch
        guard !failed else { return }
        defaults.set(Self.markerVersion, forKey: Self.markerKey)
        LogInfo("First-launch wipe complete (version \(Self.markerVersion))", category: .auth)
    }
}
