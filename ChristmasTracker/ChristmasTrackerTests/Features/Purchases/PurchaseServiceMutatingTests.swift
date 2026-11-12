//
//  PurchaseServiceMutatingTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: the `isMutating` flag of PurchaseService. It is true while a call runs (counted,
//  so two overlapping calls keep it true until both end) and false after success, after an error
//  and after a cancellation. Determinism: gated fakes with the nextHeldCall() handshake.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService isMutating", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceMutatingTests {

    @Test("isMutating is false before any call")
    func initiallyFalse() async {
        let sut = await makePurchaseServiceSUT()

        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is true while the call runs and false once it succeeded")
    func trueDuringFalseAfterSuccess() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isMutating == true)
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.outcome == .created(PurchaseFixtures.recordedPurchase()))
        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is true while a confirmation_required call runs and false after it", arguments: [false, true])
    func confirmationCall(honorsCancellation: Bool) async {
        let sut = await makePurchaseServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueue(.success(PurchaseServiceFix.confirmation()), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.isMutating == true)
        sut.repo.gate.releaseAll()
        _ = await task.value

        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is false after an error", arguments: PurchaseFixtures.allErrors)
    func falseAfterError(error: RecordPurchaseError) async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(error, held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition")

        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown as? RecordPurchaseError == error)
        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is false after the caller cancelled")
    func falseAfterCancel() async {
        let sut = await makePurchaseServiceSUT(honorsCancellation: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(sut.service.isMutating == false)
    }

    @Test("two overlapping calls keep isMutating true until both have ended")
    func overlappingCalls() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-b"), held: true)
        let first = startRecord(sut.service, itemId: "item-a")
        await sut.repo.gate.nextHeldCall()
        let second = startRecord(sut.service, itemId: "item-b")
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition")

        sut.repo.gate.release(at: 0)
        _ = await first.value
        #expect(sut.service.isMutating == true, "the first call ending must not clear the second call's flag")

        sut.repo.gate.release(at: 1)
        _ = await second.value
        #expect(sut.service.isMutating == false)
    }

    @Test("a failing call does not clear isMutating while another call is still running")
    func failureWhileAnotherRuns() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(RecordPurchaseError.network, held: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let failing = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        let succeeding = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        sut.repo.gate.release(at: 0)
        _ = await failing.value
        #expect(sut.service.isMutating == true)

        sut.repo.gate.release(at: 1)
        _ = await succeeding.value
        #expect(sut.service.isMutating == false)
    }
}
