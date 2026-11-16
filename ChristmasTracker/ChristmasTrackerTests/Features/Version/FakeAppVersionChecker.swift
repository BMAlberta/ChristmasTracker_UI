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
    // EDITED (CL1-C2): added a one-shot gate so a test can hold the first call open (in flight).
    // Off by default, so existing tests behave exactly as before.
    var holdFirstCall = false
    private var gate: CheckedContinuation<Void, Never>?

    init(result: Result<VersionPolicy, Error>) {
        self.result = result
    }

    /// Resumes a call being held by `holdFirstCall`.
    func release() {
        gate?.resume()
        gate = nil
    }

    private func begin() async {
        callCount += 1
        if holdFirstCall {
            holdFirstCall = false
            await withCheckedContinuation { gate = $0 }
        }
    }

    nonisolated func checkVersion() async throws -> VersionPolicy {
        await begin()
        return try await MainActor.run { try result.get() }
    }
}
