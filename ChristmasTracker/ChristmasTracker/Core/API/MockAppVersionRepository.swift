// MockAppVersionRepository.swift
// ChristmasTracker

import Foundation

@MainActor final class MockAppVersionRepository: AppVersionChecking {
    var stubbedResult: Result<VersionPolicy, Error> = .success(
        VersionPolicy(
            state: .ok,
            minimumVersion: "1.0.0",
            recommendedVersion: "1.0.0",
            latestVersion: "2.0.0",
            minimumBuild: 1,
            latestBuild: 10,
            manifestURL: nil,
            ipaURL: nil,
            releaseNotes: nil,
            enabled: true,
            updatedAt: Date()
        )
    )

    nonisolated func checkVersion() async throws -> VersionPolicy {
        // Hop to MainActor to read stubbedResult (MainActor-isolated property)
        try await MainActor.run { try stubbedResult.get() }
    }
}
