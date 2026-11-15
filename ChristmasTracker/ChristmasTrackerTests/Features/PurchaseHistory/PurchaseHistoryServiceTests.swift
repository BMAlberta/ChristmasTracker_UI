//
//  PurchaseHistoryServiceTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1: PurchaseHistoryService pass-through and error mapping. The service returns the repository's
//  page, rethrows a PurchaseHistoryError as is, turns any other non-cancellation error into .server, and
//  throws CancellationError for a cancelled caller. It has no cache and publishes nothing.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("PurchaseHistoryService", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseHistoryServiceTests {

    private struct UnknownFailure: Error {}

    nonisolated static let typedErrors: [PurchaseHistoryError] = [
        .unauthorized, .forbidden, .notFound, .validation(message: "Year is invalid"),
        .rateLimited(retryAfter: 12), .network, .server, .invalidResponse, .sessionEnded
    ]

    // MARK: Pass-through

    @Test("the service returns the repository's page")
    func returnsThePage() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        let expected = PurchaseHistoryFix.page(
            [PurchaseHistoryFix.row(id: "a"), PurchaseHistoryFix.row(id: "b")], nextCursor: "next"
        )
        sut.loader.enqueue(expected)

        let page = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(page == expected)
    }

    @Test("an empty page comes back empty")
    func returnsAnEmptyPage() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([], nextCursor: nil))

        let page = try await sut.service.loadPage(filter: PurchaseHistoryFilter(year: 2026), cursor: nil)

        #expect(page.rows.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test("the filter and the cursor reach the repository unchanged")
    func passesArguments() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page())
        let filter = PurchaseHistoryFilter(year: 2025, recipientId: "user-9", shippingStatus: .delivered)

        _ = try await sut.service.loadPage(filter: filter, cursor: "cursor-1")

        #expect(sut.loader.calls == [GatedPurchaseHistoryLoader.Call(filter: filter, cursor: "cursor-1")])
    }

    @Test("each call goes to the repository: the service keeps no cache")
    func noCache() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "first")]))
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "second")]))

        let one = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        let two = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(one.rows.map(\.id) == ["first"])
        #expect(two.rows.map(\.id) == ["second"])
        #expect(sut.loader.callCount == 2)
    }

    @Test("a successful call does not change the session generation")
    func successKeepsGeneration() async throws {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueue(PurchaseHistoryFix.page())
        let before = sut.service.sessionGeneration

        _ = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(sut.service.sessionGeneration == before)
    }

    // MARK: Error mapping

    @Test("a PurchaseHistoryError from the repository is rethrown as is", arguments: typedErrors)
    func rethrowsTypedErrors(error: PurchaseHistoryError) async {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueueFailure(error)

        await #expect(throws: error) {
            _ = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
    }

    @Test("any other error becomes .server")
    func otherErrorsBecomeServer() async {
        let failures: [any Error] = [
            UnknownFailure(), URLError(.notConnectedToInternet), ConfigurationError.clientUnavailable,
            BudgetError.network, NSError(domain: "fake", code: 7)
        ]
        for failure in failures {
            let sut = await makePurchaseHistoryServiceSUT()
            sut.loader.enqueueFailure(failure)

            await #expect(throws: PurchaseHistoryError.server, "\(failure)") {
                _ = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
            }
        }
    }

    @Test("a CancellationError from the repository stays a CancellationError")
    func repositoryCancellationPassesThrough() async {
        let sut = await makePurchaseHistoryServiceSUT()
        sut.loader.enqueueFailure(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)
        }
    }

    // MARK: Caller cancellation

    @Test("a cancelled caller throws CancellationError when the repository honors cancellation")
    func cancelledCallerHonored() async {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: true)
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        let result = await task.result

        expectCancellation(result)
        #expect(sut.loader.cancelledCallCount == 1)
    }

    @Test("a cancelled caller gets no page even when the repository ignores cancellation and answers")
    func cancelledCallerIgnored() async {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: false)
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row()]), held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        let result = await task.result

        expectCancellation(result)
    }

    @Test("a cancelled caller gets CancellationError, not a typed error, when the repository then fails")
    func cancelledCallerThenFailure() async {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: false)
        sut.loader.enqueueFailure(PurchaseHistoryError.network, held: true)
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()

        task.cancel()
        sut.loader.gate.releaseAll()
        let result = await task.result

        expectCancellation(result)
    }

    @Test("a cancelled call does not change the session generation, and the next call works")
    func cancellationKeepsServiceUsable() async throws {
        let sut = await makePurchaseHistoryServiceSUT(honorsCancellation: true)
        sut.loader.enqueue(PurchaseHistoryFix.page(), held: true)
        let before = sut.service.sessionGeneration
        let task = startPurchaseHistoryLoad(sut.service)
        await sut.loader.gate.nextHeldCall()
        task.cancel()
        _ = await task.result
        sut.loader.enqueue(PurchaseHistoryFix.page([PurchaseHistoryFix.row(id: "after")]))

        let page = try await sut.service.loadPage(filter: PurchaseHistoryFilter(), cursor: nil)

        #expect(sut.service.sessionGeneration == before)
        #expect(page.rows.map(\.id) == ["after"])
    }
}
