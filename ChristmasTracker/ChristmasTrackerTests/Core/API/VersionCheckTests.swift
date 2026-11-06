// VersionCheckTests.swift
// ChristmasTrackerTests
//
// Tests for Story B3 VersionService — covers success, failure-with-preserved-policy,
// and initial state. Repository tests live in TrackerAPITests/VersionCheckRepositoryTests.swift.

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - VersionService Suite

@Suite("VersionService")
@MainActor
struct VersionServiceTests {

    private func makeDefaultPolicy() -> VersionPolicy {
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
    }

    // MARK: N — check() sets lastPolicy on success

    @Test("check() sets lastPolicy after a successful repository call")
    func checkSetsLastPolicyOnSuccess() async {
        let policy = makeDefaultPolicy()
        let repo = MockAppVersionRepository()
        repo.stubbedResult = .success(policy)
        let sut = VersionService(repository: repo)

        await sut.check()

        #expect(sut.lastPolicy != nil)
    }

    // MARK: O — check() does not crash on error; lastPolicy unchanged after prior success

    @Test("check() preserves lastPolicy and sets lastErrorCategory when repository throws")
    func checkPreservesLastPolicyOnError() async {
        let policy = makeDefaultPolicy()
        let repo = MockAppVersionRepository()
        repo.stubbedResult = .success(policy)
        let sut = VersionService(repository: repo)

        await sut.check()
        #expect(sut.lastPolicy != nil)

        repo.stubbedResult = .failure(TrackerAPIError.server(500))
        await sut.check()

        #expect(sut.lastPolicy != nil)
        #expect(sut.lastErrorCategory != nil)
    }

    // MARK: P — VersionService lastPolicy starts nil and populates after check

    @Test("VersionService lastPolicy is nil on init and non-nil after a successful check")
    func versionServiceStartsNilAndPopulatesAfterCheck() async {
        let policy = makeDefaultPolicy()
        let repo = MockAppVersionRepository()
        repo.stubbedResult = .success(policy)
        let sut = VersionService(repository: repo)

        #expect(sut.lastPolicy == nil)

        await sut.check()

        #expect(sut.lastPolicy != nil)
    }
}
