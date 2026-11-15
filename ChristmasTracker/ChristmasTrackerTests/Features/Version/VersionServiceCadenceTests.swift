// VersionServiceCadenceTests.swift
// ChristmasTrackerTests
//
// Cadence, policyOrder and failed-check behavior of VersionService (VER1 decision 7).

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("VersionService cadence")
@MainActor
struct VersionServiceCadenceTests {

    private struct Harness {
        let sut: VersionService
        let checker: FakeAppVersionChecker
        let clock: TestClock
    }

    private func makeSUT(
        result: Result<VersionPolicy, Error> = .success(VersionTestFixtures.policy(state: .ok)),
        interval: TimeInterval = 900
    ) -> Harness {
        let checker = FakeAppVersionChecker(result: result)
        let clock = TestClock()
        let sut = VersionService(
            repository: checker,
            minimumCheckInterval: interval,
            now: { clock.now },
            sequence: UpdateSequence()
        )
        return Harness(sut: sut, checker: checker, clock: clock)
    }

    // MARK: check() always runs

    @Test("check() always calls the repository, even twice in a row")
    func checkAlwaysRuns() async {
        let h = makeSUT()
        await h.sut.check()
        await h.sut.check()
        #expect(h.checker.callCount == 2)
    }

    // MARK: checkIfDue()

    @Test("checkIfDue() runs when no attempt has been made")
    func checkIfDueFirstRuns() async {
        let h = makeSUT()
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 1)
        #expect(h.sut.lastPolicy != nil)
    }

    @Test("checkIfDue() after the launch check() inside the interval makes no second call")
    func checkIfDueSkipsAfterLaunchCheck() async {
        let h = makeSUT()
        await h.sut.check()
        h.clock.advance(by: 899)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 1)
    }

    @Test("checkIfDue() calls again once the interval has elapsed")
    func checkIfDueRunsAfterInterval() async {
        let h = makeSUT()
        await h.sut.check()
        h.clock.advance(by: 900)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 2)
    }

    @Test("checkIfDue() after 15 minutes plus runs, then skips again inside the next window")
    func checkIfDueWindowRestarts() async {
        let h = makeSUT()
        await h.sut.checkIfDue()
        h.clock.advance(by: 901)
        await h.sut.checkIfDue()
        h.clock.advance(by: 60)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 2)
    }

    @Test("minimumCheckInterval is injectable")
    func intervalIsInjectable() async {
        let h = makeSUT(interval: 10)
        await h.sut.checkIfDue()
        h.clock.advance(by: 11)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 2)
    }

    @Test("a failed attempt counts against the interval")
    func failedAttemptCounts() async {
        let h = makeSUT(result: .failure(TrackerAPIError.server(500)))
        await h.sut.checkIfDue()
        h.clock.advance(by: 60)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 1)
    }

    @Test("a failed attempt is retried after the interval")
    func failedAttemptRetriesAfterInterval() async {
        let h = makeSUT(result: .failure(TrackerAPIError.server(500)))
        await h.sut.checkIfDue()
        h.clock.advance(by: 900)
        await h.sut.checkIfDue()
        #expect(h.checker.callCount == 2)
    }

    // MARK: policyOrder

    @Test("policyOrder is 0 until a successful check")
    func policyOrderStartsZero() {
        let h = makeSUT()
        #expect(h.sut.policyOrder == 0)
    }

    @Test("each successful check moves policyOrder forward")
    func policyOrderAdvancesOnSuccess() async {
        let h = makeSUT()
        await h.sut.check()
        let first = h.sut.policyOrder
        await h.sut.check()
        #expect(first > 0)
        #expect(h.sut.policyOrder > first)
    }

    @Test("a failure before any success leaves policyOrder 0 and lastPolicy nil")
    func failureBeforeSuccess() async {
        let h = makeSUT(result: .failure(TrackerAPIError.server(500)))
        await h.sut.check()
        #expect(h.sut.policyOrder == 0)
        #expect(h.sut.lastPolicy == nil)
    }

    @Test("a failed check keeps lastPolicy and policyOrder")
    func failedCheckKeepsPolicyAndOrder() async {
        let policy = VersionTestFixtures.policy(state: .updateRecommended)
        let h = makeSUT(result: .success(policy))
        await h.sut.check()
        let order = h.sut.policyOrder

        h.checker.result = .failure(TrackerAPIError.server(503))
        await h.sut.check()

        #expect(h.sut.lastPolicy == policy)
        #expect(h.sut.policyOrder == order)
    }

    @Test("a failed check does not change the gate decision")
    func failedCheckDoesNotChangeDecision() async {
        let policy = VersionTestFixtures.policy(state: .forceUpdate)
        let h = makeSUT(result: .success(policy))
        await h.sut.check()
        let before = UpdateGate.decide(
            policy: h.sut.lastPolicy, policyOrder: h.sut.policyOrder,
            outdated: nil, outdatedOrder: 0, dismissedLatestVersion: nil
        )

        h.checker.result = .failure(TrackerAPIError.server(500))
        await h.sut.check()
        let after = UpdateGate.decide(
            policy: h.sut.lastPolicy, policyOrder: h.sut.policyOrder,
            outdated: nil, outdatedOrder: 0, dismissedLatestVersion: nil
        )

        guard case .required(let beforeRequired) = before,
              case .required(let afterRequired) = after else {
            Issue.record("expected required before and after a failed check")
            return
        }
        #expect(beforeRequired == afterRequired)
    }

    @Test("a failed check with no prior policy leaves the gate decision at none")
    func failedCheckNoPolicyIsNone() async {
        let h = makeSUT(result: .failure(TrackerAPIError.server(500)))
        await h.sut.check()
        let decision = UpdateGate.decide(
            policy: h.sut.lastPolicy, policyOrder: h.sut.policyOrder,
            outdated: nil, outdatedOrder: 0, dismissedLatestVersion: nil
        )
        guard case .none = decision else {
            Issue.record("expected none")
            return
        }
    }
}
