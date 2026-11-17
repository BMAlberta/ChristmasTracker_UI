// VersionServiceLogTests.swift
// ChristmasTrackerTests
//
// LG1-L3 batch C: the step lines VersionService writes through ServiceLog for a version check: started and
// processed on success, exactly one error on a failure, cancelled (never an error) for a cancelled check,
// nothing for a checkIfDue that makes no call, only the failure line in a Release-style run, and no policy
// text (URL, release notes) in any line.

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("VersionService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct VersionServiceLogTests {

    private struct Rig {
        let service: VersionService
        let checker: FakeAppVersionChecker
        let sink: CapturingOperationLog
        let clock: TestClock
    }

    private func makeRig(
        result: Result<VersionPolicy, Error> = .success(VersionTestFixtures.policy(state: .ok)),
        verbose: Bool = true
    ) -> Rig {
        let checker = FakeAppVersionChecker(result: result)
        let sink = CapturingOperationLog()
        let clock = TestClock()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        let service = VersionService(repository: checker, now: { clock.now }, log: log)
        return Rig(service: service, checker: checker, sink: sink, clock: clock)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    @Test("a check logs started then processed")
    func success() async {
        let rig = makeRig()

        await rig.service.check()

        #expect(messages(rig) == ["check version started", "check version processed"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a failed check logs exactly one error line")
    func apiFailure() async {
        let rig = makeRig(result: .failure(TrackerAPIError.server(500)))

        await rig.service.check()

        #expect(errors(rig) == ["check version failed"])
        #expect(messages(rig) == ["check version started", "check version failed"])
    }

    @Test("an unexpected error logs exactly one error line")
    func unexpectedFailure() async {
        let rig = makeRig(result: .failure(URLError(.notConnectedToInternet)))

        await rig.service.check()

        #expect(errors(rig) == ["check version failed"])
    }

    @Test("a cancelled check logs cancelled and no error")
    func cancellation() async {
        let rig = makeRig(result: .failure(CancellationError()))

        await rig.service.check()

        #expect(messages(rig) == ["check version started", "check version cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("checkIfDue inside the interval makes no call and logs nothing more")
    func skippedMakesNoCall() async {
        let rig = makeRig()
        await rig.service.check()
        let before = messages(rig)

        await rig.service.checkIfDue()

        #expect(rig.checker.callCount == 1)
        #expect(messages(rig) == before)
    }

    @Test("checkIfDue while a check is in flight makes no second call and logs nothing")
    func inFlightMakesNoCall() async {
        let rig = makeRig()
        rig.checker.holdFirstCall = true
        let first = Task { @MainActor in await rig.service.check() }
        var spins = 0
        while rig.checker.callCount == 0 && spins < 1000 {
            await Task.yield()
            spins += 1
        }

        await rig.service.checkIfDue()
        rig.checker.release()
        await first.value

        #expect(rig.checker.callCount == 1)
        #expect(messages(rig) == ["check version started", "check version processed"])
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async {
        let rig = makeRig(verbose: false)
        await rig.service.check()
        #expect(rig.sink.lines.isEmpty)

        rig.checker.result = .failure(TrackerAPIError.server(500))
        await rig.service.check()

        #expect(messages(rig) == ["check version failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("no policy text or error text appears in any line")
    func noSecrets() async {
        let rig = makeRig(result: .failure(URLError(.cannotFindHost)))
        await rig.service.check()
        rig.checker.result = .success(VersionTestFixtures.policy(state: .ok))
        await rig.service.check()

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("http"))
            #expect(!line.message.contains("URLError"))
        }
    }
}
