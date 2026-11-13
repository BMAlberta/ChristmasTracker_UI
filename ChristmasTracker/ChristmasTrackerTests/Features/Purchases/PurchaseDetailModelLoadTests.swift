//
//  PurchaseDetailModelLoadTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: loading the purchase detail.
//
//   - load() fetches through the service and fills phase, shipping and notes from the purchase;
//   - a 404 (and a purchase that is not the signed-in user's) means gone: finish == .gone, nothing shown;
//   - a load error has its own banner (Try Again and Dismiss), cleared by a new load, by Dismiss and
//     by disappear(); unauthorized, a ended session and cancellation show nothing.
//
//  Fails today because PurchaseDetailModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model load Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelLoadTests {

    @Test("Before the load the phase is loading and nothing else is set")
    func initialState() async {
        let sut = await makePurchaseDetailSUT()
        #expect(sut.model.phaseIsLoading)
        #expect(sut.model.shipping == nil)
        #expect(sut.model.notes == nil)
        #expect(sut.model.finish == nil)
        #expect(sut.model.announcement == nil)
        #expect(sut.hasNoBanner)
        #expect(!sut.model.isSavingShipping && !sut.model.isSavingNotes && !sut.model.isDeleting)
    }

    @Test("A loaded own purchase fills the core state and both sections")
    func loadsOwnPurchase() async {
        let sut = await makePurchaseDetailSUT()
        let purchase = PurchaseDetailTest.own(notes: "Gift wrap please", trackingNumber: "TRK-FAKE-1", status: .shipped)
        sut.management.enqueue(purchase)

        await sut.model.load()

        #expect(sut.management.calls == [.fetch(id: PurchaseDetailTest.purchaseId)])
        #expect(sut.model.phaseLoadedState == PurchaseDetailState(
            purchase: purchase, currencyCode: "USD", locale: PurchaseDetailTest.locale
        ))
        #expect(sut.model.shipping == PurchaseShippingSectionState(purchase: purchase))
        #expect(sut.model.notes == PurchaseNotesSectionState(purchase: purchase))
        #expect(sut.model.finish == nil)
        #expect(sut.hasNoBanner)
    }

    @Test("A freshly loaded purchase has Save disabled in both sections")
    func saveDisabledAfterLoad() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        #expect(try #require(sut.model.shipping).canSave == false)
        #expect(try #require(sut.model.notes).canSave == false)
    }

    @Test("The phase is loading while the fetch is in flight")
    func loadingWhileInFlight() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.load() }
        _ = await sut.management.gate.nextHeldCall()

        #expect(sut.model.phaseIsLoading)

        sut.management.gate.releaseAll()
        await task.value
        #expect(sut.model.phaseLoadedState != nil)
    }

    // MARK: Gone

    @Test("A 404 means gone: finish is .gone, no banner, nothing shown")
    func notFoundIsGone() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.notFound)

        await sut.model.load()

        #expect(sut.model.finish == .gone)
        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.phaseLoadedState == nil)
        #expect(sut.model.shipping == nil)
        #expect(sut.model.notes == nil)
    }

    @Test("A purchase made by somebody else behaves as gone and shows nothing (defense in depth)")
    func foreignPurchaseIsGone() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.foreign())

        await sut.model.load()

        #expect(sut.model.finish == .gone)
        #expect(sut.model.phaseLoadedState == nil)
        #expect(sut.model.shipping == nil)
        #expect(sut.model.notes == nil)
        #expect(sut.hasNoBanner)
    }

    @Test("Without a signed-in user the purchase behaves as gone")
    func noCurrentUserIsGone() async {
        let sut = await makePurchaseDetailSUT(currentUserId: nil)
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.load()

        #expect(sut.model.finish == .gone)
        #expect(sut.model.phaseLoadedState == nil)
    }

    @Test("The user id comparison is exact: a different case is somebody else's purchase")
    func differentCaseIsGone() async {
        let sut = await makePurchaseDetailSUT(currentUserId: "USER-3")
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.load()

        #expect(sut.model.finish == .gone)
    }

    // MARK: Load error banner

    @Test("A retryable load error shows its own banner with Try Again and Dismiss and no content",
          arguments: PurchaseDetailTest.retryableErrors)
    func retryableLoadError(error: PurchaseManagementError) async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.load()

        #expect(sut.model.loadBanner == PurchaseDetailTest.retryableBanner(error))
        #expect(sut.model.phaseIsFailed)
        #expect(sut.model.shipping == nil)
        #expect(sut.model.notes == nil)
        #expect(sut.model.finish == nil)
        #expect(sut.model.shippingBanner == nil && sut.model.notesBanner == nil && sut.model.deleteBanner == nil)
    }

    @Test("A non-retryable load error shows its plain message and Dismiss",
          arguments: [PurchaseManagementError.forbidden, .validation(message: "That purchase id is malformed")])
    func nonRetryableLoadError(error: PurchaseManagementError) async throws {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.load()

        let banner = try #require(sut.model.loadBanner)
        #expect(banner.message == error.userMessage)
        #expect(banner.actions.contains(.dismiss))
        #expect(sut.model.finish == nil)
    }

    @Test("Unauthorized and an ended session show no banner (the sign-in flow takes over)",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutShowsNothing(error: PurchaseManagementError) async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.load()

        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.finish == nil)
        #expect(sut.model.phaseLoadedState == nil)
    }

    @Test("A cancellation shows no banner")
    func cancellationShowsNothing() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(CancellationError())

        await sut.model.load()

        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.finish == nil)
    }

    @Test("A teardown during the fetch shows nothing and loads nothing")
    func teardownMidFlight() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.load() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.hasNoBanner)
        #expect(sut.model.phaseLoadedState == nil, "a stale purchase is never shown after the session ended")
        #expect(sut.model.finish == nil)
    }

    @Test("dismissLoadError clears the load banner")
    func dismissLoadError() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        await sut.model.load()
        #expect(sut.model.loadBanner != nil)

        sut.model.dismissLoadError()

        #expect(sut.model.loadBanner == nil)
    }

    @Test("retryLoad clears the banner when it starts and loads the purchase on success")
    func retryLoad() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        await sut.model.load()
        #expect(sut.model.loadBanner != nil)

        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.retryLoad() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(sut.model.loadBanner == nil, "a new load clears the load error")

        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.management.calls == [.fetch(id: PurchaseDetailTest.purchaseId), .fetch(id: PurchaseDetailTest.purchaseId)])
        #expect(sut.model.phaseLoadedState != nil)
        #expect(sut.model.loadBanner == nil)
    }

    @Test("A new load() clears an earlier load error")
    func newLoadClearsError() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        await sut.model.load()
        #expect(sut.model.loadBanner != nil)

        sut.management.enqueue(PurchaseDetailTest.own())
        await sut.model.load()

        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.phaseLoadedState != nil)
    }

    @Test("disappear() clears the load banner")
    func disappearClearsLoadError() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        await sut.model.load()
        #expect(sut.model.loadBanner != nil)

        sut.model.disappear()

        #expect(sut.model.loadBanner == nil)
    }

    @Test("A load never touches PurchaseService.isMutating")
    func loadLeavesIsMutatingAlone() async {
        let sut = await makePurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.load() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(sut.service.isMutating == false)
        sut.management.gate.releaseAll()
        await task.value
        #expect(sut.service.isMutating == false)
    }
}
