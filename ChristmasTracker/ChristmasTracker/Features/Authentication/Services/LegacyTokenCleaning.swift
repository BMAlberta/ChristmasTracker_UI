//  LegacyTokenCleaning.swift
//  ChristmasTracker

import Foundation

internal protocol LegacyTokenCleaning {
    func cleanUpLegacyTokens()
    func clearStoredSessionTokens()
}

internal struct LegacyTokenCleanup: LegacyTokenCleaning {
    func cleanUpLegacyTokens() {
        try? KeychainService.delete("auth.tokens")
        try? KeychainService.delete("auth.refresh_token")
        try? KeychainService.delete("auth.biometric_token")
        try? KeychainService.delete("auth.user_id")
    }

    func clearStoredSessionTokens() {
        do {
            try KeychainService.delete("auth.tokens")
            try KeychainService.delete("auth.refresh_token")
            LogDebug("Stored tokens cleared", category: .auth)
        } catch {
            LogError("Failed to clear tokens: \(error)", category: .auth)
        }
    }
}
