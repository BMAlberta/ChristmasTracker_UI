//
//  BiometricUnlockPreference.swift
//  ChristmasTracker
//
//  Stores user preference for biometric unlock. Backed by UserDefaults.
//

import Foundation

// MARK: - Protocol

internal protocol BiometricUnlockPreferring: Sendable {
    nonisolated var biometricUnlockEnabled: Bool { get set }
    nonisolated var biometricSetupOfferShown: Bool { get set }
}

// MARK: - Concrete

internal struct BiometricUnlockPreference: BiometricUnlockPreferring {

    // nonisolated(unsafe): UserDefaults is thread-safe; stored once during init and never reassigned.
    nonisolated(unsafe) internal static let enabledKey = "biometricUnlock.enabled"
    // nonisolated(unsafe): same reasoning as enabledKey.
    nonisolated(unsafe) internal static let offerShownKey = "biometricUnlock.offerShown"

    // nonisolated(unsafe): UserDefaults is internally thread-safe; we only store the reference once.
    nonisolated(unsafe) private let defaults: UserDefaults

    nonisolated internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    nonisolated internal var biometricUnlockEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    nonisolated internal var biometricSetupOfferShown: Bool {
        get { defaults.bool(forKey: Self.offerShownKey) }
        set { defaults.set(newValue, forKey: Self.offerShownKey) }
    }
}
