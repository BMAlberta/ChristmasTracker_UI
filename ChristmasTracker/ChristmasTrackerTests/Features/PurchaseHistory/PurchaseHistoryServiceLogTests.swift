//
//  PurchaseHistoryServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3: the step lines PurchaseHistoryService writes through ServiceLog: started and processed on
//  success, exactly one error on failure, cancelled (never an error) when the session ends, only the
//  failure line in a Release-style run, and no secret fixture in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseHistoryServiceLogTests {

    private struct Rig {
        let service: PurchaseHistoryService
        let loader: GatedPurchaseHistoryLoader
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let loader = GatedPurchaseHistoryLoader()
        loader.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        return Rig(service: PurchaseHistoryService(repository: loader, log: log), loader: loader, sink: sink)
    }

    @Test("a page load logs started with its reason, then processed with a row count")
    func success() async throws {
        let rig = makeRig()
        rig.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(), PurchaseHistoryFix.row(id: "purchase-2")]))

        _ = try await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil, reason: .pull)

        #expect(rig.sink.lines.map(\.message) == [
            "load purchase history started (pull)", "load purchase history processed (2 rows)"
        ])
        #expect(rig.sink.lines.allSatisfy { $0.level == .debug })
    }

    @Test("a failed page load logs exactly one error line and throws the typed error")
    func failure() async {
        let rig = makeRig()
        rig.loader.enqueueFailure(PurchaseHistoryError.network)

        await #expect(throws: PurchaseHistoryError.self) {
            _ = try await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }

        #expect(rig.sink.lines.filter { $0.level == .error }.map(\.message) == ["load purchase history failed"])
        #expect(rig.sink.lines.count == 2)
    }

    @Test("a session that ends mid-load logs cancelled and no error")
    func cancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(rig.service)
        await rig.loader.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let result = await task.result

        expectCancellation(result)
        #expect(rig.sink.lines.map(\.message) == [
            "load purchase history started (unspecified)", "load purchase history cancelled"
        ])
        #expect(!rig.sink.lines.contains { $0.level == .error })
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async throws {
        let rig = makeRig(verbose: false)
        rig.loader.enqueue(PurchaseHistoryFix.page())
        rig.loader.enqueueFailure(PurchaseHistoryError.server)

        _ = try await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        #expect(rig.sink.lines.isEmpty)

        _ = try? await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        #expect(rig.sink.lines.map(\.message) == ["load purchase history failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("secret fixtures in the page and the cursor never appear in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let row = PurchaseHistoryFix.row(
            id: "ZZ-secret-id", itemName: "ZZ-secret-name", recipientName: "zz-secret@example.com",
            totalCost: PurchaseHistoryFix.dec("987654.32")
        )
        rig.loader.enqueue(PurchaseHistoryFix.page([row], nextCursor: "ZZ-secret-cursor"))
        rig.loader.enqueueFailure(PurchaseHistoryError.server)

        _ = try await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: "ZZ-secret-cursor")
        _ = try? await rig.service.loadPage(filter: PurchaseHistoryFilter(), cursor: "ZZ-secret-cursor")

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-secret"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
        }
    }
}
