//
//  StatsServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3: the step lines StatsService writes through ServiceLog: started and processed on success,
//  exactly one error on failure, cancelled (never an error) when the session ends, only the failure
//  line in a Release-style run, and no secret fixture in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsServiceLogTests {

    private struct Rig {
        let service: StatsService
        let loader: GatedStatsLoader
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let loader = GatedStatsLoader()
        loader.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        return Rig(service: StatsService(repository: loader, log: log), loader: loader, sink: sink)
    }

    @Test("a load logs started with its reason, then processed")
    func loadSuccess() async {
        let rig = makeRig()
        rig.loader.enqueue(StatsFix.year())

        await rig.service.load(year: 2026, reason: .appear)

        #expect(rig.sink.lines.map(\.message) == ["load stats started (appear)", "load stats processed"])
        #expect(rig.sink.lines.allSatisfy { $0.level == .debug })
    }

    @Test("a refresh logs started with its reason, then processed")
    func refreshSuccess() async {
        let rig = makeRig()
        rig.loader.enqueue(StatsFix.year())

        await rig.service.refresh(year: 2026, reason: .pull)

        #expect(rig.sink.lines.map(\.message) == ["refresh stats started (pull)", "refresh stats processed"])
    }

    @Test("a failed fetch logs exactly one error line")
    func failure() async {
        let rig = makeRig()
        rig.loader.enqueueFailure(BudgetError.network)

        await rig.service.load(year: 2026)

        let errors = rig.sink.lines.filter { $0.level == .error }
        #expect(errors.map(\.message) == ["load stats failed"])
        #expect(rig.sink.lines.map(\.message) == ["load stats started (unspecified)", "load stats failed"])
    }

    @Test("a session that ends mid-fetch logs cancelled and no error")
    func cancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.loader.enqueue(StatsFix.year(), held: true)
        let task = startStats(rig.service)
        await rig.loader.gate.nextHeldCall()

        try await rig.service.clearForSession()
        await task.value

        #expect(rig.sink.lines.map(\.message) == ["load stats started (unspecified)", "load stats cancelled"])
        #expect(!rig.sink.lines.contains { $0.level == .error })
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async {
        let rig = makeRig(verbose: false)
        rig.loader.enqueue(StatsFix.year())
        rig.loader.enqueueFailure(BudgetError.server)

        await rig.service.refresh(year: 2026)
        #expect(rig.sink.lines.isEmpty)

        await rig.service.refresh(year: 2026)
        #expect(rig.sink.lines.map(\.message) == ["load stats failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("secret fixtures in the stats never appear in any line")
    func noSecrets() async {
        let rig = makeRig()
        let stats = BudgetFixtures.statsYear(
            year: 2031, totalSpent: "987654.32", itemsPurchased: 3, purchaseCount: 2,
            spend: [
                BudgetFixtures.spend(id: "ZZ-secret-id", name: "ZZ-secret-name", spent: "987654.32", items: 3),
                BudgetFixtures.spend(id: "ZZ-secret-id2", name: "zz-secret@example.com", spent: "987654.32", items: 1)
            ],
            budget: BudgetFixtures.statsBudget(total: "987654.32", spent: "987654.32"),
            availableYears: [2031]
        )
        rig.loader.enqueue(stats)
        rig.loader.enqueueFailure(BudgetError.server)

        await rig.service.load(year: 2031)
        await rig.service.refresh(year: 2031)

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-secret"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
            #expect(!line.message.contains("2031"))
        }
    }
}
