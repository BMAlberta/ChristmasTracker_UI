//
//  LockPolicy.swift
//  ChristmasTracker
//
//  Provides the inactivity lock timeout, resolved in priority order:
//  1. UserDefaults override (inactivityLockMinutesOverride)
//  2. Info.plist (INACTIVITY_LOCK_MINUTES)
//  3. Hardcoded fallback: 10
//
//  Explicitly nonisolated — used from both @MainActor and nonisolated contexts.
//

import Foundation

/// Provides the inactivity lock timeout in minutes.
internal protocol LockTimeoutProviding {
    nonisolated var timeoutMinutes: Int { get }
}

/// Resolves the inactivity lock timeout from UserDefaults, Info.plist, or the hardcoded default.
/// Explicitly nonisolated so it can be constructed and read from any concurrency context.
nonisolated internal struct LockPolicy: LockTimeoutProviding {

    nonisolated private static let overrideKey = "inactivityLockMinutesOverride"
    nonisolated private static let infoPlistKey = "INACTIVITY_LOCK_MINUTES"
    nonisolated private static let hardcodedDefault = 10

    private let defaults: UserDefaults
    private let infoDictionary: [String: Any]?

    nonisolated internal init(
        defaults: UserDefaults = .standard,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) {
        self.defaults = defaults
        self.infoDictionary = infoDictionary
    }

    nonisolated internal var timeoutMinutes: Int {
        // 1. UserDefaults override
        if let overrideValue = resolveOverride() {
            return overrideValue
        }
        // 2. Info.plist
        if let plistValue = resolvePlist() {
            return plistValue
        }
        // 3. Hardcoded fallback
        return Self.hardcodedDefault
    }

    // MARK: - Static Helpers

    /// Clamps `value` to the range 1...30.
    nonisolated internal static func clamp(_ value: Int) -> Int {
        min(30, max(1, value))
    }

    /// Parses a string into a valid timeout value (1...30), returning nil for
    /// blank, non-numeric, zero, negative, or out-of-range (>30) inputs.
    nonisolated internal static func parse(_ raw: String?) -> Int? {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let parsed = Int(raw) else { return nil }
        guard parsed >= 1, parsed <= 30 else { return nil }
        return parsed
    }

    // MARK: - Private

    nonisolated private func resolveOverride() -> Int? {
        let raw: String?
        if let string = defaults.string(forKey: Self.overrideKey) {
            raw = string
        } else {
            let intValue = defaults.integer(forKey: Self.overrideKey)
            raw = intValue == 0 ? nil : String(intValue)
        }
        return Self.parse(raw)
    }

    nonisolated private func resolvePlist() -> Int? {
        guard let raw = infoDictionary?[Self.infoPlistKey] as? String else { return nil }
        return Self.parse(raw)
    }
}
