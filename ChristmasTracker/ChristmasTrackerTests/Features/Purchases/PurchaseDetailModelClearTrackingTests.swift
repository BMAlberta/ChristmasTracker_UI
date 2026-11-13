//
//  PurchaseDetailModelClearTrackingTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-C: the Shipping section clears a saved tracking number (decision S15).
//
//   - clearing the field enables Save; the save sends a .clear update; the screen follows the RETURNED
//     purchase (empty draft, Save disabled);
//   - the announcement is "Tracking number cleared." when the saved change was .clear (with or without a
//     status change), otherwise "Shipping saved.";
//   - a returned "" (legacy row) also shows an empty draft and a disabled Save;
//   - a failed clear keeps the draft empty and uses only the shipping banner.
//
//  All tracking numbers are fake.
//
//  These tests pin the announcement for each kind of shipping save, including a cleared tracking number.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model clear tracking Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelClearTrackingTests {

    private static let saved = "TRK-FAKE-777"

    private func shippingCall(_ status: PurchaseShippingStatus, _ change: PurchaseTrackingChange) -> GatedPurchaseManager.Call {
        .updateShipping(
            id: PurchaseDetailTest.purchaseId,
            update: PurchaseShippingUpdate(status: status, trackingChange: change)
        )
    }

    // MARK: Clear

    @Test("Clearing the tracking field enables Save; saving sends a clear and the screen shows it empty with Save disabled")
    func clearTracking() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: nil, status: .shipped))
        let countBefore = sut.model.announcementCount

        sut.setShipping(tracking: "")
        #expect(try #require(sut.model.shipping).canSave)
        #expect(try #require(sut.model.shipping).trackingChange == .clear)

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.shipped, .clear)])
        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave == false)
        #expect(sut.model.announcement == "Tracking number cleared.")
        #expect(sut.model.announcementCount == countBefore + 1)
        #expect(sut.model.announcementIsError == false)
        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingShipping == false)
        #expect(sut.model.finish == nil)
    }

    @Test("A whitespace-only edit of a saved tracking number is a clear")
    func whitespaceEditIsClear() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: nil, status: .shipped))
        sut.setShipping(tracking: "   ")

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.shipped, .clear)])
        #expect(sut.model.announcement == "Tracking number cleared.")
    }

    @Test("A status change and a clear in the same save is one call with the new status and a clear")
    func statusChangeAndClear() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: nil, status: .delivered))
        let countBefore = sut.model.announcementCount
        sut.setShipping(status: .delivered, tracking: "")

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.delivered, .clear)])
        #expect(sut.model.announcement == "Tracking number cleared.")
        #expect(sut.model.announcementCount == countBefore + 1)
        #expect(sut.model.shipping?.draftStatus == PurchaseShippingStatus.delivered)
        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave == false)
    }

    // MARK: Not a clear

    @Test("A status-only save sends an unchanged tracking number and announces Shipping saved.")
    func statusOnly() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: Self.saved, status: .delivered))
        sut.setShipping(status: .delivered)

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.delivered, .unchanged)])
        #expect(sut.model.announcement == "Shipping saved.")
        #expect(sut.model.shipping?.draftTracking == Self.saved)
    }

    @Test("A tracking-only set carries the current status and announces Shipping saved.")
    func trackingOnlySet() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: "TRK-FAKE-888", status: .shipped))
        sut.setShipping(tracking: "TRK-FAKE-888")

        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.shipped, .set("TRK-FAKE-888"))])
        #expect(sut.model.announcement == "Shipping saved.")
        #expect(sut.model.shipping?.draftTracking == "TRK-FAKE-888")
    }

    @Test("A whitespace-only edit of an empty tracking number changes nothing and saves nothing")
    func whitespaceAgainstEmptyIsNothing() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.setShipping(tracking: "   ")

        #expect(try #require(sut.model.shipping).canSave == false)
        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad.isEmpty)
        #expect(sut.model.announcement == nil)
    }

    // MARK: Legacy rows

    @Test("A returned purchase with an empty-string tracking number shows an empty draft and a disabled Save")
    func legacyEmptyStringReturned() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: "", status: .shipped))
        sut.setShipping(tracking: "")

        await sut.model.saveShipping()

        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave == false)
        #expect(sut.model.announcement == "Tracking number cleared.")
    }

    @Test("A loaded purchase with an empty-string tracking number shows an empty draft and a disabled Save")
    func legacyEmptyStringLoaded() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: "", status: .shipped))

        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave == false)
        #expect(try #require(sut.model.shipping).trackingChange == .unchanged)
    }

    // MARK: A failed clear

    @Test("A failed clear keeps the draft empty and shows the shipping banner only; Try Again repeats the save once and succeeds")
    func failedClearThenTryAgain() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setShipping(tracking: "")

        await sut.model.saveShipping()

        #expect(sut.model.shippingBanner == PurchaseDetailTest.retryableBanner(.network))
        #expect(sut.model.notesBanner == nil && sut.model.deleteBanner == nil && sut.model.loadBanner == nil)
        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave, "the clear is kept so Try Again can repeat it")
        #expect(sut.model.announcement != "Tracking number cleared.")
        #expect(sut.model.finish == nil)

        sut.management.enqueue(PurchaseDetailTest.own(trackingNumber: nil, status: .shipped))
        await sut.model.saveShipping()

        #expect(sut.callsAfterLoad == [shippingCall(.shipped, .clear), shippingCall(.shipped, .clear)])
        #expect(sut.model.shippingBanner == nil)
        #expect(sut.model.announcement == "Tracking number cleared.")
        #expect(try #require(sut.model.shipping).canSave == false)
    }

    @Test("Dismiss clears the banner of a failed clear and keeps the empty draft")
    func dismissAfterFailedClear() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setShipping(tracking: "")
        await sut.model.saveShipping()
        #expect(sut.model.shippingBanner != nil)

        sut.model.dismissShippingError()

        #expect(sut.model.shippingBanner == nil)
        #expect(sut.model.shipping?.draftTracking == "")
        #expect(try #require(sut.model.shipping).canSave)
    }

    @Test("Unauthorized and an ended session show nothing after a clear",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutShowsNothing(error: PurchaseManagementError) async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueueFailure(error)
        sut.setShipping(tracking: "")

        await sut.model.saveShipping()

        #expect(sut.hasNoBanner)
        #expect(sut.model.announcement != "Tracking number cleared.")
        #expect(sut.model.isSavingShipping == false)
    }

    @Test("A cancellation shows nothing after a clear")
    func cancellationShowsNothing() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueueFailure(CancellationError())
        sut.setShipping(tracking: "")

        await sut.model.saveShipping()

        #expect(sut.hasNoBanner)
        #expect(sut.model.announcement != "Tracking number cleared.")
        #expect(sut.model.isSavingShipping == false)
    }

    @Test("disappear() clears the banner of a failed clear")
    func disappearClearsFailedClear() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setShipping(tracking: "")
        await sut.model.saveShipping()
        #expect(sut.model.shippingBanner != nil)

        sut.model.disappear()

        #expect(sut.hasNoBanner)
    }

    // MARK: Notes are untouched

    @Test("Saving notes after a clear still announces Notes saved. and never sends a tracking number")
    func notesUnchanged() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(trackingNumber: Self.saved, status: .shipped))
        sut.management.enqueue(PurchaseDetailTest.own(notes: "A note", trackingNumber: Self.saved, status: .shipped))
        sut.setNotes("A note")

        await sut.model.saveNotes()

        #expect(sut.model.announcement == "Notes saved.")
        #expect(sut.callsAfterLoad.count == 1)
        if case .updateNotes = sut.callsAfterLoad.first {} else {
            Issue.record("the notes save must call updateNotes only")
        }
    }
}
