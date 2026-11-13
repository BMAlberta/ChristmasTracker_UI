//
//  PurchaseServiceManagementTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: PurchaseService.fetchPurchase / updateNotes / updateShipping / deletePurchase
//  (Gate 1 Story B interface item 6) with a scripted management fake.
//
//  Rules under test:
//   - each method passes its arguments to the management repository and returns its purchase;
//   - a typed PurchaseManagementError is thrown unchanged; nothing else escapes (a raw error
//     becomes a typed one); the recorder is never touched;
//   - the calls publish NOTHING: `isMutating` stays the Record screen's flag and a management call
//     neither raises nor clears it;
//   - concurrent calls each get their own result or error;
//   - `PurchaseService(repository:)` still works and its management calls fail with a typed error
//     (the management dependency defaults to the inert manager).
//
//  Session safety (teardown, user switch, cancellation) is in
//  PurchaseServiceManagementSessionSafetyTests. Determinism: gated fakes with the nextHeldCall()
//  handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService management", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceManagementTests {

    // MARK: - Pass-through

    @Test("each method passes its arguments to the management repository and returns its purchase",
          arguments: ManagementOp.allCases)
    func passThrough(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT()
        let purchase = PurchaseFixtures.recordedPurchase(
            id: "purchase-9", item: PurchaseFixtures.fakeItemReference
        )
        sut.management.enqueue(purchase)

        let result = try await op.call(on: sut.service, id: "purchase-9")

        #expect(result == purchase)
        #expect(sut.management.calls == [op.expectedCall(id: "purchase-9")])
        #expect(sut.recorder.callCount == 0, "a management call never reaches the recorder")
    }

    @Test("the notes update reaches the repository unchanged: set, clear and unchanged",
          arguments: [PurchaseNotesChange.set("A note"), .clear, .unchanged])
    func notesUpdateIsPassedThrough(change: PurchaseNotesChange) async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase())
        let update = PurchaseNotesUpdate(change: change)

        _ = try await sut.service.updateNotes(id: "purchase-1", update: update)

        #expect(sut.management.calls == [.updateNotes(id: "purchase-1", update: update)])
    }

    @Test("the shipping update reaches the repository unchanged, with and without a tracking number",
          arguments: [
        PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-FAKE-0001")),
        PurchaseShippingUpdate(status: .notShipped, trackingChange: .unchanged),
        PurchaseShippingUpdate(status: .delivered, trackingChange: .unchanged)
    ])
    func shippingUpdateIsPassedThrough(update: PurchaseShippingUpdate) async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase())

        _ = try await sut.service.updateShipping(id: "purchase-1", update: update)

        #expect(sut.management.calls == [.updateShipping(id: "purchase-1", update: update)])
    }

    @Test("a call makes exactly one repository call")
    func oneCallPerMethod() async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase())

        _ = try await sut.service.deletePurchase(id: "purchase-1")

        #expect(sut.management.callCount == 1)
    }

    // MARK: - Typed errors

    @Test("a typed PurchaseManagementError is thrown unchanged",
          arguments: ManagementOp.allCases, [
        PurchaseManagementError.notFound, .unauthorized, .forbidden,
        .validation(message: "Notes must be at most 1000 characters"),
        .rateLimited(retryAfter: 30), .sessionEnded, .network, .invalidResponse, .server
    ])
    func typedErrorsPassThrough(op: ManagementOp, error: PurchaseManagementError) async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(error)

        do {
            _ = try await op.call(on: sut.service)
            Issue.record("expected \(error) to be thrown")
        } catch let thrown as PurchaseManagementError {
            #expect(thrown == error)
        } catch {
            Issue.record("expected a PurchaseManagementError, got \(error)")
        }
    }

    @Test("an error that is not a PurchaseManagementError reaches the caller as a typed error, never raw",
          arguments: ManagementOp.allCases)
    func rawErrorsBecomeTyped(op: ManagementOp) async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(URLError(.timedOut))

        do {
            _ = try await op.call(on: sut.service)
            Issue.record("expected an error to be thrown")
        } catch is PurchaseManagementError {
            // expected
        } catch is CancellationError {
            Issue.record("a raw error is not a cancellation")
        } catch {
            Issue.record("a raw error escaped the service: \(error)")
        }
    }

    @Test("a failed call does not break the next one", arguments: ManagementOp.allCases)
    func nextCallAfterFailure(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-next"))

        _ = try? await op.call(on: sut.service)
        let result = try await op.call(on: sut.service)

        #expect(result.id == "purchase-next")
    }

    // MARK: - Nothing published, isMutating untouched

    @Test("a management call never raises isMutating, even while it is held", arguments: ManagementOp.allCases)
    func isMutatingStaysFalseDuringACall(op: ManagementOp) async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()

        #expect(sut.service.isMutating == false, "isMutating is the Record screen's flag")
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementValue != nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("a failing management call leaves isMutating false", arguments: ManagementOp.allCases)
    func isMutatingStaysFalseAfterAFailure(op: ManagementOp) async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)

        _ = try? await op.call(on: sut.service)

        #expect(sut.service.isMutating == false)
    }

    @Test("a management call does not clear the flag of a record call that is running",
          arguments: ManagementOp.allCases)
    func managementDoesNotClearTheRecordFlag(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT()
        sut.recorder.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-record"), held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-managed"))
        let record = startRecord(sut.service)
        await sut.recorder.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition: the record call is running")

        let managed = try await op.call(on: sut.service)

        #expect(managed.id == "purchase-managed")
        #expect(sut.service.isMutating == true, "a finished management call must not turn the record flag off")
        sut.recorder.gate.releaseAll()
        let result = await record.value
        #expect(result.outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-record")))
        #expect(sut.service.isMutating == false)
    }

    @Test("a record call does not change what a running management call returns")
    func recordDoesNotDisturbManagement() async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-managed"), held: true)
        sut.recorder.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-record"))
        let managed = startManagement(sut.service, .get)
        await sut.management.gate.nextHeldCall()

        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        sut.management.gate.releaseAll()
        let result = await managed.value

        #expect(outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-record")))
        #expect(result.managementValue?.id == "purchase-managed")
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Concurrency

    @Test("two concurrent calls each receive their own purchase, whatever the release order")
    func concurrentCallsKeepTheirOwnResults() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-first"), held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-second"), held: true)
        let first = startManagement(sut.service, .get, id: "purchase-first")
        await sut.management.gate.nextHeldCall()
        let second = startManagement(sut.service, .delete, id: "purchase-second")
        await sut.management.gate.nextHeldCall()

        sut.management.gate.release(at: 1)
        let secondResult = await second.value
        sut.management.gate.release(at: 0)
        let firstResult = await first.value

        #expect(firstResult.managementValue?.id == "purchase-first")
        #expect(secondResult.managementValue?.id == "purchase-second")
    }

    @Test("a failure in one concurrent call does not affect the other")
    func concurrentFailureIsIsolated() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(PurchaseManagementError.notFound, held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-ok"), held: true)
        let failing = startManagement(sut.service, .delete)
        await sut.management.gate.nextHeldCall()
        let succeeding = startManagement(sut.service, .updateNotes)
        await sut.management.gate.nextHeldCall()

        sut.management.gate.releaseAll()
        let failingResult = await failing.value
        let succeedingResult = await succeeding.value

        #expect((failingResult.managementThrown as? PurchaseManagementError) == .notFound)
        #expect(succeedingResult.managementValue?.id == "purchase-ok")
    }

    // MARK: - The existing initializer

    @Test("PurchaseService(repository:) still records, and its management calls fail with a typed error",
          arguments: ManagementOp.allCases)
    func defaultManagementIsInert(op: ManagementOp) async throws {
        let recorder = GatedPurchaseRecorder()
        recorder.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-record"))
        let service = PurchaseService(repository: recorder)

        let outcome = try await service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        #expect(outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-record")))

        do {
            _ = try await op.call(on: service)
            Issue.record("the inert default must not return a purchase")
        } catch is PurchaseManagementError {
            // expected
        } catch {
            Issue.record("expected a typed PurchaseManagementError, got \(error)")
        }
        #expect(recorder.callCount == 1, "management calls never reach the recorder")
    }
}
