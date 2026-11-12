//
//  PurchaseServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: PurchaseService is session-safe exactly like ItemService and ListService. Stale
//  data from a previous session or user is impossible after teardown, a user switch or
//  cancellation, and nothing is written after the session ended.
//
//  Rules under test:
//   - the call captures a generation before its first await; after `clearForSession()` an in-flight
//     call ends with CancellationError (a stale success, confirmation or failure is discarded, a
//     typed error is NOT thrown instead) and writes nothing;
//   - cancelling the caller ends the call with CancellationError even when the repository keeps
//     running and later returns a result;
//   - `clearForSession()` bumps the generation, cancels in-flight calls and clears isMutating;
//   - after a user switch (clear, then a new call) the new call works and the old late result never
//     reaches it or its flag.
//
//  Teardown is driven the way the app does it: SessionManager.teardown(reason:). Determinism:
//  gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseService session safety", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseServiceSessionSafetyTests {

    enum Scripted: CaseIterable, Sendable, CustomTestStringConvertible {
        case created, confirmation, networkError, notFoundError, forbiddenError

        var testDescription: String {
            switch self {
            case .created: "created"
            case .confirmation: "confirmationRequired"
            case .networkError: "network error"
            case .notFoundError: "notFound error"
            case .forbiddenError: "forbidden error"
            }
        }

        @MainActor
        func enqueue(on repo: GatedPurchaseRecorder, held: Bool) {
            switch self {
            case .created: repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-stale"), held: held)
            case .confirmation: repo.enqueue(.success(PurchaseServiceFix.confirmation(token: "tok-stale")), held: held)
            case .networkError: repo.enqueueFailure(PurchaseError.network, held: held)
            case .notFoundError: repo.enqueueFailure(PurchaseError.notFound, held: held)
            case .forbiddenError: repo.enqueueFailure(PurchaseError.forbidden, held: held)
            }
        }
    }

    // MARK: - Teardown during a call

    @Test("a call that finishes after teardown throws CancellationError, whatever it returned or threw",
          arguments: Scripted.allCases, [false, true])
    func completesAfterTeardown(scripted: Scripted, honorsCancellation: Bool) async {
        let sut = await makePurchaseServiceSUT(honorsCancellation: honorsCancellation)
        scripted.enqueue(on: sut.repo, held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError, "a stale result ends as a cancellation, not as data or a typed error")
        #expect(result.outcome == nil, "a stale outcome must not reach the caller")
        #expect(sut.service.isMutating == false)
    }

    @Test("teardown resets isMutating at once, before the stale call is released")
    func teardownResetsIsMutating() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition")

        await sut.manager.teardown(reason: .sessionExpired)

        #expect(sut.service.isMutating == false)
        sut.repo.gate.releaseAll()
        _ = await task.value
        #expect(sut.service.isMutating == false)
    }

    @Test("clearForSession directly ends an in-flight call with CancellationError and clears the flag",
          arguments: [false, true])
    func clearForSessionEndsTheCall(honorsCancellation: Bool) async throws {
        let sut = await makePurchaseServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        try await sut.service.clearForSession()
        #expect(sut.service.isMutating == false)
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(sut.service.isMutating == false)
    }

    @Test("clearForSession on an idle service is harmless and repeatable")
    func clearForSessionIdle() async throws {
        let sut = await makePurchaseServiceSUT()

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()

        #expect(sut.service.isMutating == false)
    }

    // MARK: - User switch

    @Test("user switch: A's result, released late, never reaches B and B's call works")
    func userSwitchLateResult() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)   // user A
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-b"))               // user B
        let userA = startRecord(sut.service, itemId: "item-1")
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let outcomeB = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        sut.repo.gate.releaseAll()
        let resultA = await userA.value

        #expect(outcomeB == .created(PurchaseFixtures.recordedPurchase(id: "purchase-b")))
        #expect(resultA.thrown is CancellationError)
        #expect(resultA.outcome == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("user switch: A's late failure is a cancellation, not an error for B")
    func userSwitchLateFailure() async throws {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueueFailure(PurchaseError.forbidden, held: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-b"))
        let userA = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let outcomeB = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )
        sut.repo.gate.releaseAll()
        let resultA = await userA.value

        #expect(outcomeB == .created(PurchaseFixtures.recordedPurchase(id: "purchase-b")))
        #expect(resultA.thrown is CancellationError)
    }

    @Test("A's late call does not clear the isMutating flag of B's running call")
    func staleCallDoesNotResetBsFlag() async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-a"), held: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-b"), held: true)
        let userA = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let userB = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition: B is running")

        sut.repo.gate.release(at: 0)
        _ = await userA.value
        #expect(sut.service.isMutating == true, "A finishing must not turn off B's flag")

        sut.repo.gate.release(at: 1)
        let resultB = await userB.value
        #expect(resultB.outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-b")))
        #expect(sut.service.isMutating == false)
    }

    @Test("a call after teardown works normally in the new session")
    func callAfterTeardownWorks() async throws {
        let sut = await makePurchaseServiceSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-new"))

        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-new")))
        #expect(sut.service.isMutating == false)
    }

    @Test("teardown for every reason ends an in-flight call", arguments: [
        TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback
    ])
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makePurchaseServiceSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Cancellation

    @Test("cancelling the caller ends the call with CancellationError even if the repository still returns a result",
          arguments: [false, true])
    func cancellingTheCaller(honorsCancellation: Bool) async {
        let sut = await makePurchaseServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        let result = await task.value

        #expect(result.thrown is CancellationError)
        #expect(result.outcome == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("a cancelled call does not break the next call")
    func nextCallAfterCancellation() async throws {
        let sut = await makePurchaseServiceSUT(honorsCancellation: true)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-cancelled"), held: true)
        let task = startRecord(sut.service)
        await sut.repo.gate.nextHeldCall()
        task.cancel()
        sut.repo.gate.releaseAll()
        _ = await task.value
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-next"))

        let outcome = try await sut.service.recordPurchase(
            itemId: "item-1", draft: PurchaseFixtures.draft(), confirmationToken: nil
        )

        #expect(outcome == .created(PurchaseFixtures.recordedPurchase(id: "purchase-next")))
        #expect(sut.service.isMutating == false)
    }
}
