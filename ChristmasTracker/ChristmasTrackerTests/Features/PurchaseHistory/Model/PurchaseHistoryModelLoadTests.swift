//
//  PurchaseHistoryModelLoadTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: the first page: success, failure, Try Again, silent cancellation, empty kinds.
//

import Foundation
import Testing
@testable import ChristmasTracker

@MainActor
@Suite("Purchase history model: first page", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelLoadTests {

    @Test("onAppear loads the first page once")
    func loadsOnce() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a", "b"]))

        await sut.model.onAppear()
        await sut.model.onAppear()

        #expect(sut.rowIds() == ["a", "b"])
        #expect(sut.model.loadPhase == .content)
        #expect(sut.loader.calls == [.init(filter: PurchaseHistoryFilter(year: 2026), cursor: nil)])
    }

    @Test("Rows stay in the server order")
    func serverOrder() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["z", "m", "a"]))

        await sut.model.onAppear()

        #expect(sut.rowIds() == ["z", "m", "a"])
    }

    @Test("A first page failure shows the Try Again only banner and no rows")
    func firstPageFailure() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(PurchaseHistoryError.network)

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.message == PurchaseHistoryError.network.userMessage)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])
        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.model.rows.isEmpty)
    }

    @Test("Try Again after a failure loads the first page and removes the banner")
    func tryAgainRecovers() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(PurchaseHistoryError.server)
        sut.loader.enqueue(phPage(["a"]))

        await sut.model.onAppear()
        await sut.model.tryAgain()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.rowIds() == ["a"])
        #expect(sut.loader.calls.last?.cursor == nil)
    }

    @Test("An error that is not a PurchaseHistoryError is treated as a server failure")
    func unknownErrorIsServer() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(URLError(.badServerResponse))

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.message == PurchaseHistoryError.server.userMessage)
    }

    @Test("A cancelled load shows nothing and lets onAppear load again")
    func cancellationIsSilent() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(CancellationError())
        sut.loader.enqueue(phPage(["a"]))

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanners.isEmpty)

        await sut.model.onAppear()
        #expect(sut.rowIds() == ["a"])
    }

    @Test("A notFound first page failure is a normal failure: failed phase, Try Again only, and Try Again recovers")
    func notFoundIsAFailure() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(PurchaseHistoryError.notFound)
        sut.loader.enqueue(phPage(["a"]))

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.message == PurchaseHistoryError.notFound.userMessage)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])

        await sut.model.tryAgain()
        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.rowIds() == ["a"])
    }

    @Test("A notFound refresh over saved rows shows the stale banner")
    func notFoundRefreshIsStale() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueueFailure(PurchaseHistoryError.notFound)

        await sut.model.onAppear()
        await sut.model.refresh()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.rowIds() == ["a"])
        #expect(sut.model.staleBanners.map(\.message) == [PurchaseHistoryError.notFound.userMessage])
    }

    @Test("After a first page request ends, the phase is never loading except when sign-in takes over",
          arguments: [PurchaseHistoryError.network, .server, .notFound, .forbidden, .rateLimited(retryAfter: 5),
                      .validation(message: ""), .invalidResponse])
    func phaseNeverStuckLoading(error: PurchaseHistoryError) async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(error)

        await sut.model.onAppear()

        #expect(sut.model.loadPhase == .failed)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])
    }

    @Test("A second onAppear while the first load is in flight does not load again")
    func secondOnAppearWhileHeld() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]), held: true)
        let first = sut.start { await $0.onAppear() }
        await sut.nextHeld()

        await sut.model.onAppear()
        #expect(sut.loader.callCount == 1)

        sut.loader.gate.releaseAll()
        await first.value
        #expect(sut.rowIds() == ["a"])
        #expect(sut.loader.callCount == 1)
    }

    @Test("A failure that sends the user to sign-in shows no banner and keeps the state",
          arguments: [PurchaseHistoryError.unauthorized, .sessionEnded])
    func takeoverFailuresShowNothing(error: PurchaseHistoryError) async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueueFailure(error)

        await sut.model.onAppear()

        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanners.isEmpty)
        #expect(sut.model.loadPhase == .loading)
        #expect(sut.model.rows.isEmpty)
    }

    @Test("An empty history with the default filter is noPurchasesYet")
    func emptyNoPurchasesYet() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage([]))

        await sut.model.onAppear()

        #expect(sut.model.emptyKind == .noPurchasesYet)
    }

    @Test("An empty result with an active filter is noMatches")
    func emptyNoMatches() async {
        let sut = await makePurchaseHistoryModelSUT()
        sut.loader.enqueue(phPage(["a"]))
        sut.loader.enqueue(phPage([]))

        await sut.model.onAppear()
        await sut.model.select(shipping: .shipped)

        #expect(sut.model.emptyKind == .noMatches)
    }

    @Test("emptyKind is nil with rows, while loading, after a failure and when a cursor remains")
    func emptyKindNil() async {
        let sut = await makePurchaseHistoryModelSUT()
        #expect(sut.model.emptyKind == nil)

        sut.loader.enqueueFailure(PurchaseHistoryError.network)
        await sut.model.onAppear()
        #expect(sut.model.emptyKind == nil)

        sut.loader.enqueue(phPage(["a"]))
        await sut.model.tryAgain()
        #expect(sut.model.emptyKind == nil)

        sut.loader.enqueue(phPage([], next: "c1"))
        await sut.model.refresh()
        #expect(sut.model.rows.isEmpty)
        #expect(sut.model.emptyKind == nil)
    }
}
