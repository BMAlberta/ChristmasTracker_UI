//
//  PurchaseHistoryServiceSessionTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC7: PurchaseHistoryService is session-safe. When the session is cleared during a call:
//   - the call throws CancellationError (never a page, never a PurchaseHistoryError), whether the
//     repository answers with a page, a failure, or honors cancellation;
//   - sessionGeneration increases by exactly 1 per clear;
//   - clearForSession cancels in-flight repository calls;
//   - calls made after the clear work normally and never see the old session's result.
//
//  Teardown is driven the way the app does it (SessionManager.teardown) and directly
//  (clearForSession). Determinism: gated fakes, no sleeps.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryService session safety", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseHistoryServiceSessionTests {

    nonisolated static let reasons: [TeardownReason] = [.userLogout, .sessionExpired, .forcedUpdate, .lockFallback]

    // MARK: Clear during a call

    @Test("a page that arrives after the session was cleared is dropped as a CancellationError",
          arguments: [false, true])
    func pageAfterClearIsDropped(honorsCancellation: Bool) async throws {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row()], nextCursor: "next"), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        let result = await task.result

        expectCancellation(result)
    }

    @Test("a failure that arrives after the session was cleared is a CancellationError, not a typed error",
          arguments: [false, true], PurchaseHistoryErrorTests.allCases)
    func failureAfterClearIsDropped(honorsCancellation: Bool, error: PurchaseHistoryError) async throws {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: honorsCancellation)
        sut.loader.enqueueFailure(error, held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        let result = await task.result

        expectCancellation(result)
    }

    @Test("an untyped failure that arrives after the clear is a CancellationError, not .server")
    func untypedFailureAfterClear() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueueFailure(URLError(.timedOut), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()

        expectCancellation(await task.result)
    }

    @Test("teardown for every reason ends an in-flight call as a CancellationError", arguments: reasons)
    func everyTeardownReason(reason: TeardownReason) async {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: reason)
        sut.loader.gate.releaseAll()

        expectCancellation(await task.result)
    }

    @Test("teardown ends every in-flight call at once")
    func teardownEndsAllInFlight() async {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "one")]), held: true)
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "two")]), held: true)
        let first = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()
        let second = startPurchaseHistoryLoad(sut.service, cursor: "c")
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.gate.releaseAll()

        expectCancellation(await first.result)
        expectCancellation(await second.result)
    }

    // MARK: Cancels the repository call

    @Test("clearForSession cancels the in-flight repository call: it ends without any release")
    func clearCancelsTheRepositoryCall() async throws {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: true)
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        // No release: the call can only end because the service cancelled its repository call.
        let result = await task.result

        expectCancellation(result)
        #expect(sut.loader.cancelledCallCount == 1)
    }

    // MARK: Generation

    @Test("clearForSession raises sessionGeneration by exactly 1")
    func clearBumpsGenerationByOne() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        let before = sut.service.sessionGeneration

        try await sut.service.clearForSession()

        #expect(sut.service.sessionGeneration == before + 1)
    }

    @Test("each clear raises it by 1 again")
    func eachClearBumps() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        let before = sut.service.sessionGeneration

        try await sut.service.clearForSession()
        try await sut.service.clearForSession()
        try await sut.service.clearForSession()

        #expect(sut.service.sessionGeneration == before + 3)
    }

    @Test("a clear during a call raises the generation by 1, once")
    func clearDuringCallBumpsOnce() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let before = sut.service.sessionGeneration
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        try await sut.service.clearForSession()
        sut.loader.gate.releaseAll()
        _ = await task.result

        #expect(sut.service.sessionGeneration == before + 1)
    }

    @Test("teardown through the session manager raises the generation by 1")
    func teardownBumpsGeneration() async {
        let sut = await makePurchaseHistoryServiceSUT()
        let before = sut.service.sessionGeneration

        await sut.manager.teardown(reason: .userLogout)

        #expect(sut.service.sessionGeneration == before + 1)
    }

    @Test("a clear with nothing in flight is harmless")
    func clearWithNothingInFlight() async throws {
        let sut = await makePurchaseHistoryServiceSUT()

        try await sut.service.clearForSession()

        #expect(sut.loader.callCount == 0)
    }

    // MARK: A new session works

    @Test("a call made after the clear works normally")
    func callsAfterClearWork() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        try await sut.service.clearForSession()
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "new-session")], nextCursor: "n"))

        let page = try await sut.service.loadPage(filter: PurchaseHistoryFilter(year: 2026), cursor: nil)

        #expect(page.rows.map(\.id) == ["new-session"])
        #expect(page.nextCursor == "n")
    }

    @Test("a failure after the clear is a typed error again")
    func failuresAfterClearAreTyped() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        try await sut.service.clearForSession()
        sut.loader.enqueueFailure(PurchaseHistoryError.forbidden)

        await #expect(throws: PurchaseHistoryError.forbidden) {
            _ = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
    }

    @Test("user A's late result never reaches user B's call")
    func lateResultNeverReachesTheNextSession() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "user-a-row")]), held: true)
        let taskA = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "user-b-row")]))
        let pageB = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        sut.loader.gate.releaseAll()
        let resultA = await taskA.result

        #expect(pageB.rows.map(\.id) == ["user-b-row"])
        expectCancellation(resultA)
    }
}
