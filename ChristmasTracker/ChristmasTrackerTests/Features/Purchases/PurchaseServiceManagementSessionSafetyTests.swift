//
//  PurchaseServiceManagementSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: the management methods of PurchaseService are session-safe exactly like
//  recordPurchase (one generation counter, one in-flight registry, one ensureCurrent check). Stale
//  data from a previous session or user is impossible after teardown, a user switch or caller
//  cancellation, and nothing is written after the session ended.
//
//  Rules under test:
//   - after `clearForSession()` an in-flight management call ends with CancellationError whatever
//     the repository returned or threw (a stale success or a stale typed error is dropped, a typed
//     error is NOT thrown instead);
//   - cancelling the caller ends the call with CancellationError even when the repository keeps
//     running and later returns a result;
//   - after a user switch (clear, then a new call) the new call works and the old late result never
//     reaches it;
//   - a call in a second session after teardown works;
//   - teardown for every reason ends every in-flight management call, together with a record call.
//
//  Teardown is driven the way the app does it: SessionManager.teardown(reason:). Determinism: gated
//  fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService management session safety", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceManagementSessionSafetyTests {

    enum Scripted: CaseIterable, Sendable, CustomTestStringConvertible {
        case purchase, notFoundError, networkError, forbiddenError, serverError

        var testDescription: String {
            switch self {
            case .purchase: "purchase"
            case .notFoundError: "notFound error"
            case .networkError: "network error"
            case .forbiddenError: "forbidden error"
            case .serverError: "server error"
            }
        }

        @MainActor
        func enqueue(on management: GatedPurchaseManager, held: Bool) {
            switch self {
            case .purchase: management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-stale"), held: held)
            case .notFoundError: management.enqueueFailure(PurchaseManagementError.notFound, held: held)
            case .networkError: management.enqueueFailure(PurchaseManagementError.network, held: held)
            case .forbiddenError: management.enqueueFailure(PurchaseManagementError.forbidden, held: held)
            case .serverError: management.enqueueFailure(PurchaseManagementError.server, held: held)
            }
        }
    }

    // MARK: - Teardown during a call

    @Test("a call that finishes after teardown throws CancellationError, whatever it returned or threw",
          arguments: ManagementOp.allCases, Scripted.allCases)
    func completesAfterTeardown(op: ManagementOp, scripted: Scripted) async {
        await assertCompletesAfterTeardown(op: op, scripted: scripted, honorsCancellation: false)
    }

    @Test("the same holds when the repository honors cancellation and ends early",
          arguments: Scripted.allCases, [false, true])
    func completesAfterTeardownWhetherOrNotCancellationIsHonored(scripted: Scripted, honorsCancellation: Bool) async {
        await assertCompletesAfterTeardown(op: .updateShipping, scripted: scripted, honorsCancellation: honorsCancellation)
    }

    private func assertCompletesAfterTeardown(op: ManagementOp, scripted: Scripted, honorsCancellation: Bool) async {
        let sut = await makeManagementServiceSUT(honorsCancellation: honorsCancellation)
        scripted.enqueue(on: sut.management, held: true)
        let task = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError, "a stale result ends as a cancellation, not as data or a typed error")
        #expect(result.managementValue == nil, "a stale purchase must not reach the caller")
        #expect(sut.service.isMutating == false)
    }

    @Test("clearForSession directly ends an in-flight management call with CancellationError",
          arguments: ManagementOp.allCases, [false, true])
    func clearForSessionEndsTheCall(op: ManagementOp, honorsCancellation: Bool) async throws {
        let sut = await makeManagementServiceSUT(honorsCancellation: honorsCancellation)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        #expect(result.managementValue == nil)
    }

    @Test("teardown for every reason ends an in-flight management call", arguments: [
        TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback
    ])
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.service, .get)
        await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        #expect(result.managementValue == nil)
    }

    @Test("teardown ends every in-flight management call at once")
    func teardownEndsAllInFlightCalls() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-b"), held: true)
        let first = startManagement(sut.service, .get, id: "purchase-a")
        await sut.management.gate.nextHeldCall()
        let second = startManagement(sut.service, .delete, id: "purchase-b")
        await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult.managementThrown is CancellationError)
        #expect(secondResult.managementThrown is CancellationError)
    }

    @Test("teardown ends a management call and a record call that run together")
    func teardownEndsManagementAndRecordTogether() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        sut.recorder.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-record"), held: true)
        let managed = startManagement(sut.service, .updateNotes)
        await sut.management.gate.nextHeldCall()
        let record = startRecord(sut.service)
        await sut.recorder.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.management.gate.releaseAll()
        sut.recorder.gate.releaseAll()
        let managedResult = await managed.value
        let recordResult = await record.value

        #expect(managedResult.managementThrown is CancellationError)
        #expect(recordResult.thrown is CancellationError)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - User switch

    @Test("user switch: A's result, released late, never reaches B and B's call works",
          arguments: ManagementOp.allCases)
    func userSwitchLateResult(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)   // user A
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-b"))               // user B
        let userA = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let purchaseB = try await op.call(on: sut.service)
        sut.management.gate.releaseAll()
        let resultA = await userA.value

        #expect(purchaseB.id == "purchase-b")
        #expect(resultA.managementThrown is CancellationError)
        #expect(resultA.managementValue == nil)
    }

    @Test("user switch: A's late typed error is a cancellation, not an error for B")
    func userSwitchLateFailure() async throws {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(PurchaseManagementError.forbidden, held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-b"))
        let userA = startManagement(sut.service, .get)
        await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let purchaseB = try await sut.service.fetchPurchase(id: "purchase-b")
        sut.management.gate.releaseAll()
        let resultA = await userA.value

        #expect(purchaseB.id == "purchase-b")
        #expect(resultA.managementThrown is CancellationError)
    }

    @Test("a call after teardown works normally in the new session", arguments: ManagementOp.allCases)
    func callAfterTeardownWorks(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-new"))

        let purchase = try await op.call(on: sut.service)

        #expect(purchase.id == "purchase-new")
    }

    @Test("a typed error in the new session after teardown is thrown as the typed error")
    func typedErrorAfterTeardown() async {
        let sut = await makeManagementServiceSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.management.enqueueFailure(PurchaseManagementError.notFound)

        do {
            _ = try await sut.service.fetchPurchase(id: "purchase-1")
            Issue.record("expected notFound")
        } catch let error as PurchaseManagementError {
            #expect(error == .notFound)
        } catch {
            Issue.record("expected a PurchaseManagementError, got \(error)")
        }
    }

    @Test("clearForSession on an idle service is harmless and repeatable, and calls still work")
    func clearForSessionIdle() async throws {
        let sut = await makeManagementServiceSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-after"))
        let purchase = try await sut.service.fetchPurchase(id: "purchase-after")

        #expect(purchase.id == "purchase-after")
    }

    // MARK: - Cancellation

    @Test("cancelling the caller ends the call with CancellationError even if the repository still returns a result",
          arguments: ManagementOp.allCases, [false, true])
    func cancellingTheCaller(op: ManagementOp, honorsCancellation: Bool) async {
        let sut = await makeManagementServiceSUT(honorsCancellation: honorsCancellation)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(), held: true)
        let task = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()

        task.cancel()
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
        #expect(result.managementValue == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("cancelling the caller turns a late typed error into CancellationError too")
    func cancellingTheCallerDropsALateError() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server, held: true)
        let task = startManagement(sut.service, .delete)
        await sut.management.gate.nextHeldCall()

        task.cancel()
        sut.management.gate.releaseAll()
        let result = await task.value

        #expect(result.managementThrown is CancellationError)
    }

    @Test("a cancelled call does not break the next call", arguments: ManagementOp.allCases)
    func nextCallAfterCancellation(op: ManagementOp) async throws {
        let sut = await makeManagementServiceSUT(honorsCancellation: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-cancelled"), held: true)
        let task = startManagement(sut.service, op)
        await sut.management.gate.nextHeldCall()
        task.cancel()
        sut.management.gate.releaseAll()
        _ = await task.value
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-next"))

        let purchase = try await op.call(on: sut.service)

        #expect(purchase.id == "purchase-next")
    }

    @Test("cancelling one caller does not cancel another running management call")
    func cancellingOneCallerLeavesTheOther() async {
        let sut = await makeManagementServiceSUT()
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)
        sut.management.enqueue(PurchaseFixtures.recordedPurchase(id: "purchase-b"), held: true)
        let first = startManagement(sut.service, .get, id: "purchase-a")
        await sut.management.gate.nextHeldCall()
        let second = startManagement(sut.service, .get, id: "purchase-b")
        await sut.management.gate.nextHeldCall()

        first.cancel()
        sut.management.gate.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult.managementThrown is CancellationError)
        #expect(secondResult.managementValue?.id == "purchase-b")
    }
}
