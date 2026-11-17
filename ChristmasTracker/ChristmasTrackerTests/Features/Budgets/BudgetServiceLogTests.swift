//
//  BudgetServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3: the step lines BudgetService writes through ServiceLog for the load and the mutations:
//  started and processed on success, exactly one error on failure, cancelled (never an error) when
//  the session ends, only the failure line in a Release-style run, and no secret fixture in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetServiceLogTests {

    private struct Rig {
        let service: BudgetService
        let manager: GatedBudgetManager
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let manager = GatedBudgetManager()
        manager.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        return Rig(service: BudgetService(repository: manager, log: log), manager: manager, sink: sink)
    }

    @Test("a load logs started with its reason, then processed with a count")
    func loadSuccess() async {
        let rig = makeRig()
        rig.manager.enqueueList([BudgetServiceFix.budget(2026), BudgetServiceFix.budget(2027)])

        let failure = await rig.service.loadBudgets(force: true, reason: .pull)

        #expect(failure == nil)
        #expect(rig.sink.lines.map(\.message) == ["load budgets started (pull)", "load budgets processed (2 budgets)"])
    }

    @Test("a cache hit does no call and logs nothing")
    func cacheHitIsSilent() async {
        let rig = makeRig()
        rig.manager.enqueueList([BudgetServiceFix.budget()])
        await rig.service.loadBudgets(force: false)
        let before = rig.sink.lines.count

        await rig.service.loadBudgets(force: false)

        #expect(rig.sink.lines.count == before)
        #expect(rig.manager.callCount == 1)
    }

    @Test("a failed load logs exactly one error line")
    func loadFailure() async {
        let rig = makeRig()
        rig.manager.enqueueFailure(BudgetError.network)

        let failure = await rig.service.loadBudgets(force: true)

        #expect(failure == .network)
        #expect(rig.sink.lines.filter { $0.level == .error }.map(\.message) == ["load budgets failed"])
        #expect(rig.sink.lines.map(\.message) == ["load budgets started (unspecified)", "load budgets failed"])
    }

    @Test("a session that ends mid-load logs cancelled and no error")
    func loadCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.manager.enqueueList([], held: true)
        let task = startLoadBudgets(rig.service, force: true)
        await rig.manager.gate.nextHeldCall()

        try await rig.service.clearForSession()
        _ = await task.value

        #expect(rig.sink.lines.map(\.message) == ["load budgets started (unspecified)", "load budgets cancelled"])
        #expect(!rig.sink.lines.contains { $0.level == .error })
    }

    @Test("each mutation logs started then processed", arguments: BudgetMutation.allCases)
    func mutationSuccess(mutation: BudgetMutation) async throws {
        let rig = makeRig()
        mutation.enqueueSuccess(on: rig.manager)

        try await mutation.call(on: rig.service)

        let name = mutation.testDescription
        #expect(rig.sink.lines.map(\.message) == ["\(name) budget started", "\(name) budget processed"])
    }

    @Test("each failed mutation logs exactly one error line", arguments: BudgetMutation.allCases)
    func mutationFailure(mutation: BudgetMutation) async {
        let rig = makeRig()
        rig.manager.enqueueFailure(BudgetError.server)

        await #expect(throws: BudgetError.self) { try await mutation.call(on: rig.service) }

        #expect(rig.sink.lines.filter { $0.level == .error }.map(\.message) == ["budget mutation failed"])
    }

    @Test("deleting a budget that is already gone is a success, not an error")
    func deleteGoneIsNotAnError() async throws {
        let rig = makeRig()
        rig.manager.enqueueFailure(BudgetError.notFound)

        try await rig.service.delete(year: 2026)

        #expect(!rig.sink.lines.contains { $0.level == .error })
        #expect(rig.sink.lines.map(\.message) == ["delete budget started", "delete budget processed"])
    }

    @Test("a session that ends mid-mutation logs cancelled and no error", arguments: BudgetMutation.allCases)
    func mutationCancellation(mutation: BudgetMutation) async throws {
        let rig = makeRig(honorsCancellation: true)
        mutation.enqueueSuccess(on: rig.manager, held: true)
        let task = startMutation(rig.service, mutation)
        await rig.manager.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let error = await task.value

        #expect(error is CancellationError)
        let name = mutation.testDescription
        #expect(rig.sink.lines.map(\.message) == ["\(name) budget started", "\(name) budget cancelled"])
        #expect(!rig.sink.lines.contains { $0.level == .error })
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async throws {
        let rig = makeRig(verbose: false)
        rig.manager.enqueueList([BudgetServiceFix.budget()])
        rig.manager.enqueueFailure(BudgetError.server)

        await rig.service.loadBudgets(force: true)
        #expect(rig.sink.lines.isEmpty)

        await rig.service.loadBudgets(force: true)
        #expect(rig.sink.lines.map(\.message) == ["load budgets failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("secret fixtures in the budgets never appear in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let secret = BudgetFixtures.budget(
            year: 2031, total: "987654.32", spent: "987654.32",
            recipients: [
                BudgetFixtures.recipientBudget(id: "ZZ-secret-id", name: "ZZ-secret-name", max: "987654.32", spent: "1"),
                BudgetFixtures.recipientBudget(id: "ZZ-id2", name: "zz-secret@example.com", max: "987654.32", spent: "1")
            ]
        )
        rig.manager.enqueueList([secret])
        rig.manager.enqueue(secret)
        rig.manager.enqueueFailure(BudgetError.server)

        await rig.service.loadBudgets(force: true)
        _ = try await rig.service.update(UpdateBudgetRequest(year: 2031, totalBudget: nil, recipients: nil))
        _ = try? await rig.service.create(BudgetServiceFix.createRequest(year: 2031, total: "987654.32"))

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
            #expect(!line.message.contains("2031"))
        }
    }
}
