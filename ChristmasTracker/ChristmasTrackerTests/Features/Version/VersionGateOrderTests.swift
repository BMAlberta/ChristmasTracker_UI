// VersionGateOrderTests.swift
// ChristmasTrackerTests

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("VersionGate outdatedOrder")
@MainActor
struct VersionGateOrderTests {

    @Test("outdatedOrder is 0 until a 426 arrives")
    func zeroBeforeAny426() {
        let sut = VersionGate(sequence: UpdateSequence())
        #expect(sut.outdatedOrder == 0)
    }

    @Test("handleVersionOutdated takes a positive order from the sequence")
    func firstOutdatedGetsOrder() async {
        let sut = VersionGate(sequence: UpdateSequence())
        await sut.handleVersionOutdated(VersionTestFixtures.outdated())
        #expect(sut.outdatedOrder > 0)
        #expect(sut.latestDetails?.minimumVersion == "3.0.0")
    }

    @Test("each handleVersionOutdated advances outdatedOrder")
    func eachOutdatedAdvances() async {
        let sut = VersionGate(sequence: UpdateSequence())
        await sut.handleVersionOutdated(VersionTestFixtures.outdated())
        let first = sut.outdatedOrder
        await sut.handleVersionOutdated(VersionTestFixtures.outdated())
        #expect(sut.outdatedOrder > first)
    }

    @Test("a 426 after a successful policy check is newer than that policy (shared sequence)")
    func sharedSequenceOrdersOutdatedAfterPolicy() async {
        let sequence = UpdateSequence()
        let gate = VersionGate(sequence: sequence)
        let checker = FakeAppVersionChecker(result: .success(VersionTestFixtures.policy(state: .ok)))
        let service = VersionService(repository: checker, sequence: sequence)

        await service.check()
        await gate.handleVersionOutdated(VersionTestFixtures.outdated())

        #expect(gate.outdatedOrder > service.policyOrder)
    }
}
