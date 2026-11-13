//
//  PurchaseDetailModelShippingTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: the Shipping section of the purchase detail.
//
//   - Save runs only when the section's canSave is true; the call carries the update built by
//     PurchaseShippingUpdate.make (status always, tracking only when it changed);
//   - a success updates the screen from the RETURNED purchase (no item refetch, no other call);
//   - an error goes only to shippingBanner (Try Again repeats the save, Dismiss clears it);
//   - unauthorized, an ended session and cancellation show nothing;
//   - a second tap while saving is ignored.
//
//  Fails today because PurchaseDetailModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model shipping Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelShippingTests {

    private static let trackingNumber = "TRK-FAKE-100"

    // MARK: Editing and enablement

    @Test("Editing the status or the tracking number enables Save; editing back disables it")
    func dirtyTracking() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()

        sut.setShipping(status: .shipped)
        #expect(try #require(sut.model.shipping).canSave)

        sut.setShipping(status: .notTracked)
        #expect(try #require(sut.model.shipping).canSave == false)

        sut.setShipping(tracking: Self.trackingNumber)
        #expect(try #require(sut.model.shipping).canSave)
    }

    @Test("Editing the notes does not enable the shipping Save, and the reverse")
    func sectionsAreIndependent() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()

        sut.setNotes("A new note")
        #expect(try #require(sut.model.notes).canSave)
        #expect(try #require(sut.model.shipping).canSave == false)

        sut.setNotes("")
        sut.setShipping(status: .delivered)
        #expect(try #require(sut.model.notes).canSave == false)
        #expect(try #require(sut.model.shipping).canSave)
    }

    // MARK: Save

    @Test("Saving sends the status and the changed tracking number, and updates from the returned purchase")
    func saveSuccess() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        let returned = PurchaseDetailTest.own(trackingNumber: Self.trackingNumber, status: .shipped)
        sut.management.enqueue(returned)
        sut.setShipping(status: .shipped, tracking: Self.trackingNumber)

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [
            .updateShipping(
                id: PurchaseDetailTest.purchaseId,
                update: PurchaseShippingUpdate(status: .shipped, trackingNumber: Self.trackingNumber)
            )
        ])
        #expect(sut.model.shipping == PurchaseShippingSectionState(purchase: returned))
        #expect(try #require(sut.model.shipping).canSave == false, "Save is disabled again after a save")
        #expect(sut.model.announcement == "Shipping saved.")
        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingShipping == false)
        #expect(sut.model.finish == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("A status-only change sends no tracking number")
    func statusOnlyOmitsTracking() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: "TRK-OLD-1", status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: "TRK-OLD-1", status: .delivered))
        sut.setShipping(status: .delivered)

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [
            .updateShipping(
                id: PurchaseDetailTest.purchaseId,
                update: PurchaseShippingUpdate(status: .delivered, trackingNumber: nil)
            )
        ])
    }

    @Test("The screen shows the RETURNED values, not the typed ones")
    func screenFollowsReturnedPurchase() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: "TRK-NORMALIZED", status: .shipped))
        sut.setShipping(status: .shipped, tracking: "  trk-normalized  ")

        await sut.model.saveShipping()

        #expect(sut.model.shipping?.draftTracking == "TRK-NORMALIZED")
        #expect(sut.model.shipping?.draftStatus == PurchaseShippingStatus.shipped)
    }

    @Test("Save does nothing when nothing changed")
    func saveWithoutChange() async {
        let sut = await makeLoadedPurchaseDetailSUT()

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad.isEmpty)
        #expect(sut.model.announcement == nil)
    }

    @Test("Save does nothing when the tracking number is longer than 100 units; exactly 100 is saved")
    func trackingLimit() async {
        let sut = await makeLoadedPurchaseDetailSUT()

        sut.setShipping(tracking: String(repeating: "T", count: 101))
        await sut.model.saveShipping()
        #expect(sut.callsAfterLoad.isEmpty)

        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: String(repeating: "T", count: 100)))
        sut.setShipping(tracking: String(repeating: "T", count: 100))
        await sut.model.saveShipping()
        #expect(sut.callsAfterLoad.count == 1)
    }

    @Test("An empty tracking field is never sent")
    func emptyTrackingNeverSent() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: "TRK-OLD-1", status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: "TRK-OLD-1", status: .delivered))
        sut.setShipping(status: .delivered, tracking: "")

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [
            .updateShipping(
                id: PurchaseDetailTest.purchaseId,
                update: PurchaseShippingUpdate(status: .delivered, trackingNumber: nil)
            )
        ])
    }

    // MARK: Saving flag and double taps

    @Test("isSavingShipping is true while the call runs, and a second tap is ignored")
    func secondTapIgnored() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(status: .shipped), held: true)
        sut.setShipping(status: .shipped)
        let task = Task { @MainActor in await sut.model.saveShipping() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(sut.model.isSavingShipping)
        #expect(sut.model.isSavingNotes == false)

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad.count == 1, "the second tap while saving sends nothing")

        sut.management.gate.releaseAll()
        await task.value
        #expect(sut.model.isSavingShipping == false)
        #expect(sut.callsAfterLoad.count == 1)
    }

    // MARK: Scoped errors

    @Test("A retryable error shows only in the shipping banner",
          arguments: PurchaseDetailTest.retryableErrors)
    func errorIsScoped(error: PurchaseManagementError) async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setShipping(status: .shipped)

        await sut.model.saveShipping()

        #expect(sut.model.shippingBanner == PurchaseDetailTest.retryableBanner(error))
        #expect(sut.model.notesBanner == nil)
        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.deleteBanner == nil)
        #expect(sut.model.phaseLoadedState != nil, "the purchase stays on screen")
        #expect(try #require(sut.model.shipping).canSave, "the edit is kept so Try Again can repeat it")
        #expect(sut.model.isSavingShipping == false)
        #expect(sut.model.finish == nil)
    }

    @Test("A non-retryable error shows its plain message and Dismiss in the shipping banner only",
          arguments: [PurchaseManagementError.forbidden, .validation(message: "Tracking number is not valid")])
    func nonRetryableErrorIsScoped(error: PurchaseManagementError) async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setShipping(status: .shipped)

        await sut.model.saveShipping()

        let banner = try #require(sut.model.shippingBanner)
        #expect(banner.message == error.userMessage)
        #expect(banner.actions.contains(.dismiss))
        #expect(sut.model.notesBanner == nil && sut.model.loadBanner == nil && sut.model.deleteBanner == nil)
    }

    @Test("Try Again repeats the save once and a success clears the banner")
    func tryAgainRepeatsSave() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setShipping(status: .shipped)
        await sut.model.saveShipping()
        #expect(sut.model.shippingBanner != nil)

        sut.management.enqueue(PurchaseDetailTest.own(status: .shipped))
        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad.count == 2)
        #expect(sut.callsAfterLoad.first == sut.callsAfterLoad.last, "the retry sends the identical update")
        #expect(sut.model.shippingBanner == nil)
        #expect(sut.model.announcement == "Shipping saved.")
    }

    @Test("Dismiss clears the shipping banner")
    func dismissClears() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setShipping(status: .shipped)
        await sut.model.saveShipping()
        #expect(sut.model.shippingBanner != nil)

        sut.model.dismissShippingError()

        #expect(sut.model.shippingBanner == nil)
    }

    @Test("disappear() clears the shipping banner")
    func disappearClears() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setShipping(status: .shipped)
        await sut.model.saveShipping()

        sut.model.disappear()

        #expect(sut.model.shippingBanner == nil)
    }

    @Test("The error announcement carries the error text and no purchase data")
    func errorAnnouncement() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setShipping(status: .shipped, tracking: Self.trackingNumber)

        await sut.model.saveShipping()

        let announcement = sut.model.announcement ?? ""
        #expect(announcement.contains(PurchaseManagementError.network.userMessage))
        #expect(!announcement.contains(Self.trackingNumber))
        #expect(!announcement.contains("Fake Lamp"))
    }

    @Test("Unauthorized, an ended session and a cancellation show nothing",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutShowsNothing(error: PurchaseManagementError) async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setShipping(status: .shipped)

        await sut.model.saveShipping()

        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingShipping == false)
    }

    @Test("A not-found save finishes the screen as gone and shows no banner")
    func notFoundFinishesGone() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.notFound)
        sut.setShipping(status: .shipped)

        await sut.model.saveShipping()

        #expect(sut.model.finish == .gone)
        #expect(sut.model.shippingBanner == nil)
        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingShipping == false)
        #expect(sut.model.announcement != "Shipping saved.")
    }

    @Test("A cancellation shows nothing")
    func cancellationShowsNothing() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(CancellationError())
        sut.setShipping(status: .shipped)

        await sut.model.saveShipping()

        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingShipping == false)
    }

    @Test("A teardown during the save shows nothing and applies nothing")
    func teardownMidFlight() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: Self.trackingNumber, status: .shipped), held: true)
        sut.setShipping(status: .shipped, tracking: Self.trackingNumber)
        let task = Task { @MainActor in await sut.model.saveShipping() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.hasNoBanner)
        #expect(sut.model.announcement != "Shipping saved.", "a stale result is never announced after the session ended")
        #expect(sut.model.isSavingShipping == false)
    }
}
