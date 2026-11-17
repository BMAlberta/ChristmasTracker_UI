//
//  PurchaseServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch B: the step lines PurchaseService writes through ServiceLog for the record call and
//  the four management calls: started and processed on success, exactly one error on failure,
//  cancelled (never an error) when the session ends, only the failure line in a Release-style run,
//  and no secret fixture in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceLogTests {

    private struct Rig {
        let service: PurchaseService
        let recorder: GatedPurchaseRecorder
        let management: GatedPurchaseManager
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let recorder = GatedPurchaseRecorder()
        let management = GatedPurchaseManager()
        recorder.gate.honorsCancellation = honorsCancellation
        management.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        let service = PurchaseService(repository: recorder, management: management, log: log)
        return Rig(service: service, recorder: recorder, management: management, sink: sink)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    private static func opName(_ op: ManagementOp) -> String {
        switch op {
        case .get: "fetch purchase"
        case .updateNotes: "update purchase notes"
        case .updateShipping: "update purchase shipping"
        case .delete: "delete purchase"
        }
    }

    private func record(_ rig: Rig) async throws -> PurchaseOutcome {
        try await rig.service.recordPurchase(itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil)
    }

    @Test("a record call logs started then processed")
    func recordSuccess() async throws {
        let rig = makeRig()
        rig.recorder.enqueue(created: PurchaseFixtures.recordedPurchase())

        _ = try await record(rig)

        #expect(messages(rig) == ["record purchase started", "record purchase processed"])
    }

    @Test("a failed record call logs exactly one error line")
    func recordFailure() async {
        let rig = makeRig()
        rig.recorder.enqueueFailure(PurchaseError.server)

        await #expect(throws: PurchaseError.self) { _ = try await record(rig) }

        #expect(errors(rig) == ["record purchase failed"])
    }

    @Test("a session that ends mid-record logs cancelled and no error")
    func recordCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.recorder.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(rig.service)
        await rig.recorder.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(messages(rig) == ["record purchase started", "record purchase cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("each management call logs started then processed", arguments: ManagementOp.allCases)
    func managementSuccess(op: ManagementOp) async throws {
        let rig = makeRig()
        rig.management.enqueue(PurchaseFixtures.recordedPurchase())

        _ = try await op.call(on: rig.service)

        let name = Self.opName(op)
        #expect(messages(rig) == ["\(name) started", "\(name) processed"])
    }

    @Test("each failed management call logs exactly one error line", arguments: ManagementOp.allCases)
    func managementFailure(op: ManagementOp) async {
        let rig = makeRig()
        rig.management.enqueueFailure(PurchaseManagementError.server)

        await #expect(throws: PurchaseManagementError.self) { _ = try await op.call(on: rig.service) }

        #expect(errors(rig) == ["purchase management failed"])
    }

    @Test("a session that ends mid-management-call logs cancelled and no error", arguments: ManagementOp.allCases)
    func managementCancellation(op: ManagementOp) async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(rig.service, op)
        await rig.management.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        let name = Self.opName(op)
        #expect(messages(rig) == ["\(name) started", "\(name) cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async throws {
        let rig = makeRig(verbose: false)
        rig.recorder.enqueue(created: PurchaseFixtures.recordedPurchase())
        rig.recorder.enqueueFailure(PurchaseError.server)

        _ = try await record(rig)
        #expect(rig.sink.lines.isEmpty)

        _ = try? await record(rig)
        #expect(messages(rig) == ["record purchase failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("secret fixtures never appear in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let secret = PurchaseFixtures.recordedPurchase(
            id: "ZZ-secret-id", totalCost: PurchaseFixtures.decimal("987654.32"),
            storeName: "ZZ-secret-name", notes: "zz-secret@example.com note"
        )
        rig.recorder.enqueue(created: secret)
        rig.recorder.enqueueFailure(PurchaseError.server)
        rig.management.enqueue(secret)
        rig.management.enqueueFailure(PurchaseManagementError.server)
        let draft = PurchaseFixtures.draft(
            totalCost: "987654.32", storeName: "ZZ-secret-name", notes: "zz-secret@example.com note"
        )

        _ = try await rig.service.recordPurchase(itemId: "ZZ-secret-id", draft: draft, confirmationToken: "ZZ-token")
        _ = try? await rig.service.recordPurchase(itemId: "ZZ-secret-id", draft: draft, confirmationToken: "ZZ-token")
        _ = try await rig.service.fetchPurchase(id: "ZZ-secret-id")
        _ = try? await rig.service.deletePurchase(id: "ZZ-secret-id")

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
        }
    }
}
