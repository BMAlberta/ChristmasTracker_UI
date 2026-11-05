//  LegacyTokenCleaning.swift
//  ChristmasTracker

import Foundation

internal protocol LegacyTokenCleaning {
    func cleanUpLegacyTokens()
}

internal struct LegacyTokenCleanup: LegacyTokenCleaning {
    func cleanUpLegacyTokens() {
        try? KeychainService.delete("auth.tokens")
        try? KeychainService.delete("auth.refresh_token")
    }
}
