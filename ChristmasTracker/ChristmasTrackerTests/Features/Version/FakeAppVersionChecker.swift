// FakeAppVersionChecker.swift
// ChristmasTrackerTests
//
// Counting fake for AppVersionChecking. No network.

import Foundation
@testable import ChristmasTracker

@MainActor
final class FakeAppVersionChecker: AppVersionChecking {
    var result: Result<VersionPolicy, Error>
    private(set) var callCount = 0

    init(result: Result<VersionPolicy, Error>) {
        self.result = result
    }

    nonisolated func checkVersion() async throws -> VersionPolicy {
        try await MainActor.run {
            callCount += 1
            return try result.get()
        }
    }
}
