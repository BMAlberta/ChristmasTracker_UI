// VersionTestFixtures.swift
// ChristmasTrackerTests
//
// Shared value fixtures for the VER1 update-gate tests.

import Foundation
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum VersionTestFixtures {
    static func policy(
        state: VersionPolicyState,
        minimumVersion: String = "1.2.0",
        minimumBuild: Int = 20,
        latestVersion: String = "2.0.0",
        latestBuild: Int = 30,
        manifestURL: URL? = URL(string: "https://example.com/app/manifest.plist"),
        releaseNotes: String? = "Fixes and polish"
    ) -> VersionPolicy {
        VersionPolicy(
            state: state,
            minimumVersion: minimumVersion,
            recommendedVersion: latestVersion,
            latestVersion: latestVersion,
            minimumBuild: minimumBuild,
            latestBuild: latestBuild,
            manifestURL: manifestURL,
            ipaURL: nil,
            releaseNotes: releaseNotes,
            enabled: true,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func outdated(
        minimumVersion: String = "3.0.0",
        minimumBuild: Int? = 99,
        manifestUrl: String? = "https://example.com/app/manifest.plist"
    ) -> VersionOutdatedDetails {
        VersionOutdatedDetails(
            minimumVersion: minimumVersion,
            minimumBuild: minimumBuild,
            latestVersion: nil,
            latestBuild: nil,
            manifestUrl: manifestUrl,
            ipaUrl: nil
        )
    }
}
