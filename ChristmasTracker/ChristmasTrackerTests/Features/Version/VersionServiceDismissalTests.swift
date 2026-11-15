// VersionServiceDismissalTests.swift
// ChristmasTrackerTests
//
// "Later" memory (VER1 decision 5): in memory only, per latestVersion.

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("VersionService dismissal")
@MainActor
struct VersionServiceDismissalTests {

    private func makeSUT() -> VersionService {
        let checker = FakeAppVersionChecker(result: .success(VersionTestFixtures.policy(state: .updateRecommended)))
        let clock = TestClock()
        return VersionService(
            repository: checker,
            minimumCheckInterval: 900,
            now: { clock.now },
            sequence: UpdateSequence()
        )
    }

    @Test("dismissedLatestVersion is nil on a fresh service")
    func startsNil() {
        #expect(makeSUT().dismissedLatestVersion == nil)
    }

    @Test("dismissRecommended records the latestVersion")
    func recordsLatestVersion() {
        let sut = makeSUT()
        sut.dismissRecommended(latestVersion: "2.0.0")
        #expect(sut.dismissedLatestVersion == "2.0.0")
    }

    @Test("a later dismissal replaces the earlier one")
    func laterReplacesEarlier() {
        let sut = makeSUT()
        sut.dismissRecommended(latestVersion: "2.0.0")
        sut.dismissRecommended(latestVersion: "2.1.0")
        #expect(sut.dismissedLatestVersion == "2.1.0")
    }

    @Test("dismissal survives a check")
    func survivesCheck() async {
        let sut = makeSUT()
        sut.dismissRecommended(latestVersion: "2.0.0")
        await sut.check()
        #expect(sut.dismissedLatestVersion == "2.0.0")
    }

    @Test("dismissal is in memory only: a new service does not see it")
    func inMemoryOnly() {
        let first = makeSUT()
        first.dismissRecommended(latestVersion: "2.0.0")
        let second = makeSUT()
        #expect(second.dismissedLatestVersion == nil)
    }
}
