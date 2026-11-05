//
//  RememberedEmailStoring.swift
//  ChristmasTracker

import Foundation

internal protocol RememberedEmailStoring {
    nonisolated var rememberedEmail: String? { get set }
}

internal struct RememberedEmailStore: RememberedEmailStoring {
    nonisolated static let key = "login.rememberedEmail"

    // UserDefaults is documented as thread-safe for the read/write operations performed here.
    // Stored nonisolated(unsafe) so this struct can be used from synchronous, nonisolated contexts
    // (matches the pattern in FirstLaunchWipe.swift).
    private nonisolated(unsafe) let defaults: UserDefaults

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    nonisolated var rememberedEmail: String? {
        get { defaults.string(forKey: Self.key) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
