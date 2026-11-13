//
//  PurchaseDetailModelDeleteTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: deleting the purchase from the detail.
//
//   - confirmDelete() calls the service once; success OR a 404 (already removed) gives .deleted;
//   - any other error sets deleteBanner and keeps the purchase on screen; Try Again deletes once more;
//   - unauthorized, an ended session and cancellation show nothing and do not finish;
//   - a second confirm while deleting is ignored; the other banners are never touched.
//
//  These tests build the model without a refresh dependency (the default does nothing). The refresh
//  after a delete is covered by PurchaseDetailModelDeleteRefreshTests (I4c-C).
//
//  These tests pin the delete behavior of PurchaseDetailModel.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model delete Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelDeleteTests {

    private var deleteCall: GatedPurchaseManager.Call { .delete(id: PurchaseDetailTest.purchaseId) }

    @Test("A successful delete finishes with .deleted, announces it and shows no error")
    func deleteSuccess() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own())

        await sut.model.confirmDelete()

        #expect(sut.callsAfterLoad == [deleteCall])
        #expect(sut.model.finish == .deleted)
        #expect(sut.model.announcement == "Purchase deleted.")
        #expect(sut.hasNoBanner)
        #expect(sut.model.isDeleting == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("A 404 on delete counts as deleted: finish .deleted, no error")
    func deleteNotFoundIsDeleted() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.notFound)

        await sut.model.confirmDelete()

        #expect(sut.callsAfterLoad == [deleteCall])
        #expect(sut.model.finish == .deleted)
        #expect(sut.hasNoBanner)
        #expect(sut.model.isDeleting == false)
    }

    @Test("A failed delete keeps the purchase on screen and shows the delete banner only",
          arguments: PurchaseDetailTest.retryableErrors)
    func deleteFailureKeepsPurchase(error: PurchaseManagementError) async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.confirmDelete()

        #expect(sut.model.deleteBanner == PurchaseDetailTest.retryableBanner(error))
        #expect(sut.model.finish == nil)
        #expect(sut.model.phaseLoadedState != nil)
        #expect(sut.model.shipping != nil && sut.model.notes != nil)
        #expect(sut.model.shippingBanner == nil && sut.model.notesBanner == nil && sut.model.loadBanner == nil)
        #expect(sut.model.isDeleting == false)
    }

    @Test("A non-retryable delete error shows its plain message and Dismiss",
          arguments: [PurchaseManagementError.forbidden, .validation(message: "That purchase can't be deleted")])
    func nonRetryableDeleteError(error: PurchaseManagementError) async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.confirmDelete()

        let banner = try #require(sut.model.deleteBanner)
        #expect(banner.message == error.userMessage)
        #expect(banner.actions.contains(.dismiss))
        #expect(sut.model.finish == nil)
    }

    @Test("Try Again deletes exactly once more and a success finishes with .deleted")
    func tryAgainDeletesOnce() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        await sut.model.confirmDelete()
        #expect(sut.model.deleteBanner != nil)
        #expect(sut.callsAfterLoad == [deleteCall])

        sut.management.enqueue(PurchaseDetailTest.own())
        await sut.model.confirmDelete()

        #expect(sut.callsAfterLoad == [deleteCall, deleteCall])
        #expect(sut.model.deleteBanner == nil)
        #expect(sut.model.finish == .deleted)
    }

    @Test("Dismiss clears the delete banner and keeps the purchase")
    func dismissClears() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        await sut.model.confirmDelete()
        #expect(sut.model.deleteBanner != nil)

        sut.model.dismissDeleteError()

        #expect(sut.model.deleteBanner == nil)
        #expect(sut.model.phaseLoadedState != nil)
        #expect(sut.model.finish == nil)
    }

    @Test("disappear() clears the load, shipping, notes and delete banners")
    func disappearClearsEveryBanner() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setShipping(status: .shipped)
        sut.setNotes("A note")
        await sut.model.saveShipping()
        await sut.model.saveNotes()
        await sut.model.confirmDelete()
        #expect(sut.model.shippingBanner != nil && sut.model.notesBanner != nil && sut.model.deleteBanner != nil)

        sut.model.disappear()

        #expect(sut.hasNoBanner)
    }

    @Test("A delete error is not shown in the shipping or notes sections")
    func deleteErrorIsScoped() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.rateLimited(retryAfter: 30))

        await sut.model.confirmDelete()

        #expect(sut.model.deleteBanner != nil)
        #expect(sut.model.shippingBanner == nil)
        #expect(sut.model.notesBanner == nil)
    }

    @Test("The error announcement carries the error text and no purchase data")
    func errorAnnouncement() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)

        await sut.model.confirmDelete()

        let announcement = sut.model.announcement ?? ""
        #expect(announcement.contains(PurchaseManagementError.server.userMessage))
        #expect(!announcement.contains("Fake Lamp"))
        #expect(!announcement.contains("Fake Store"))
    }

    @Test("Unauthorized and an ended session show nothing and do not finish",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutShowsNothing(error: PurchaseManagementError) async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)

        await sut.model.confirmDelete()

        #expect(sut.hasNoBanner)
        #expect(sut.model.finish == nil)
        #expect(sut.model.isDeleting == false)
    }

    @Test("A cancellation shows nothing and does not finish")
    func cancellationShowsNothing() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(CancellationError())

        await sut.model.confirmDelete()

        #expect(sut.hasNoBanner)
        #expect(sut.model.finish == nil)
        #expect(sut.model.isDeleting == false)
    }

    @Test("A teardown during the delete shows nothing and does not finish")
    func teardownMidFlight() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.hasNoBanner)
        #expect(sut.model.finish == nil, "a stale delete result is never acted on after the session ended")
        #expect(sut.model.announcement != "Purchase deleted.")
        #expect(sut.model.isDeleting == false)
    }

    @Test("isDeleting is true while the call runs, and a second confirm is ignored")
    func secondConfirmIgnored() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(sut.model.isDeleting)
        #expect(sut.model.finish == nil)

        await sut.model.confirmDelete()

        #expect(sut.callsAfterLoad == [deleteCall], "the second confirm while deleting sends nothing")

        sut.management.gate.releaseAll()
        await task.value
        #expect(sut.model.finish == .deleted)
        #expect(sut.callsAfterLoad == [deleteCall])
    }

    @Test("Saving a section does not set isDeleting, and deleting does not set the saving flags")
    func flagsAreSeparate() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(), held: true)
        let task = Task { @MainActor in await sut.model.confirmDelete() }
        _ = await sut.management.gate.nextHeldCall()

        #expect(sut.model.isSavingShipping == false)
        #expect(sut.model.isSavingNotes == false)

        sut.management.gate.releaseAll()
        await task.value
    }
}
