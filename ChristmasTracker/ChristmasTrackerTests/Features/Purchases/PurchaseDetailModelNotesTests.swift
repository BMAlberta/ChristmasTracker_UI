//
//  PurchaseDetailModelNotesTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: the Notes section of the purchase detail.
//
//   - Save runs only when the section's canSave is true; the call carries the update built by
//     PurchaseNotesUpdate.make (a set, or a clear which is the empty string on the wire);
//   - the notes call never carries a tracking number or a shipping status (the update type has no
//     such member, and the shipping section is not touched by a notes save);
//   - a success updates the notes section from the RETURNED purchase;
//   - an error goes only to notesBanner.
//
//  Fails today because PurchaseDetailModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase detail model notes Tests", .timeLimit(.minutes(1)))
@MainActor
struct PurchaseDetailModelNotesTests {

    // MARK: Save

    @Test("Saving new notes sends a set update and updates from the returned purchase")
    func saveSet() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        let returned = PurchaseDetailTest.own(notes: "Wrap in blue paper")
        sut.management.enqueue(returned)
        sut.setNotes("Wrap in blue paper")

        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad == [
            .updateNotes(
                id: PurchaseDetailTest.purchaseId,
                update: PurchaseNotesUpdate(change: .set("Wrap in blue paper"))
            )
        ])
        #expect(sut.model.notes == PurchaseNotesSectionState(purchase: returned))
        #expect(try #require(sut.model.notes).canSave == false)
        #expect(sut.model.announcement == "Notes saved.")
        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingNotes == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("Clearing the notes sends a clear update, which is the empty string on the wire")
    func saveClear() async throws {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(notes: "Old note"))
        let returned = PurchaseDetailTest.own(notes: nil)
        sut.management.enqueue(returned)
        sut.setNotes("")

        await sut.model.saveNotes()

        let call = try #require(sut.callsAfterLoad.first)
        #expect(sut.callsAfterLoad.count == 1)
        guard case .updateNotes(_, let update) = call else {
            Issue.record("the call was not an updateNotes")
            return
        }
        #expect(update.change == .clear)
        #expect(update.wireNotes == "")
        #expect(sut.model.notes == PurchaseNotesSectionState(purchase: returned))
    }

    @Test("Notes are trimmed in the update")
    func savesTrimmedText() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(notes: "Padded"))
        sut.setNotes("  Padded \n")

        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad == [
            .updateNotes(id: PurchaseDetailTest.purchaseId, update: PurchaseNotesUpdate(change: .set("Padded")))
        ])
    }

    @Test("A notes save never sends a tracking number and leaves unsaved shipping edits alone")
    func notesSaveIsIndependentOfShipping() async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.setShipping(status: .shipped, tracking: "TRK-UNSAVED-1")
        sut.management.enqueue(PurchaseDetailTest.own(notes: "Only a note"))
        sut.setNotes("Only a note")

        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad == [
            .updateNotes(id: PurchaseDetailTest.purchaseId, update: PurchaseNotesUpdate(change: .set("Only a note")))
        ], "exactly one notes call and no shipping call")
        let shipping = try #require(sut.model.shipping)
        #expect(shipping.draftStatus == PurchaseShippingStatus.shipped)
        #expect(shipping.draftTracking == "TRK-UNSAVED-1")
        #expect(shipping.canSave, "the shipping section is still dirty")
    }

    @Test("Save does nothing when the text did not change (whitespace-only edits included)")
    func saveWithoutChange() async {
        let sut = await makeLoadedPurchaseDetailSUT(purchase: PurchaseDetailTest.own(notes: "Same"))

        await sut.model.saveNotes()
        sut.setNotes("  Same  ")
        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad.isEmpty)
        #expect(sut.model.announcement == nil)
    }

    @Test("Save does nothing above 1000 units; exactly 1000 is saved")
    func notesLimit() async {
        let sut = await makeLoadedPurchaseDetailSUT()

        sut.setNotes(String(repeating: "n", count: 1001))
        await sut.model.saveNotes()
        #expect(sut.callsAfterLoad.isEmpty)
        #expect(sut.model.notes?.tooLong == true)

        sut.management.enqueue(PurchaseDetailTest.own(notes: String(repeating: "n", count: 1000)))
        sut.setNotes(String(repeating: "n", count: 1000))
        await sut.model.saveNotes()
        #expect(sut.callsAfterLoad.count == 1)
    }

    // MARK: Saving flag and double taps

    @Test("isSavingNotes is true while the call runs, and a second tap is ignored")
    func secondTapIgnored() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(notes: "Held note"), held: true)
        sut.setNotes("Held note")
        let task = Task { @MainActor in await sut.model.saveNotes() }
        _ = await sut.management.gate.nextHeldCall()
        #expect(sut.model.isSavingNotes)
        #expect(sut.model.isSavingShipping == false)

        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad.count == 1, "the second tap while saving sends nothing")

        sut.management.gate.releaseAll()
        await task.value
        #expect(sut.model.isSavingNotes == false)
        #expect(sut.callsAfterLoad.count == 1)
    }

    // MARK: Scoped errors

    @Test("A retryable error shows only in the notes banner",
          arguments: PurchaseDetailTest.retryableErrors)
    func errorIsScoped(error: PurchaseManagementError) async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setNotes("A note that fails")

        await sut.model.saveNotes()

        #expect(sut.model.notesBanner == PurchaseDetailTest.retryableBanner(error))
        #expect(sut.model.shippingBanner == nil)
        #expect(sut.model.loadBanner == nil)
        #expect(sut.model.deleteBanner == nil)
        #expect(sut.model.phaseLoadedState != nil, "the purchase stays on screen")
        #expect(try #require(sut.model.notes).canSave, "the edit is kept so Try Again can repeat it")
        #expect(sut.model.isSavingNotes == false)
        #expect(sut.model.finish == nil)
    }

    @Test("A non-retryable error shows its plain message and Dismiss in the notes banner only",
          arguments: [PurchaseManagementError.forbidden, .validation(message: "Notes are not valid")])
    func nonRetryableErrorIsScoped(error: PurchaseManagementError) async throws {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setNotes("A note that fails")

        await sut.model.saveNotes()

        let banner = try #require(sut.model.notesBanner)
        #expect(banner.message == error.userMessage)
        #expect(banner.actions.contains(.dismiss))
        #expect(sut.model.shippingBanner == nil && sut.model.loadBanner == nil && sut.model.deleteBanner == nil)
    }

    @Test("A shipping error and a notes error are held separately")
    func separateBanners() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setShipping(status: .shipped)
        sut.setNotes("A note")

        await sut.model.saveShipping()
        await sut.model.saveNotes()

        #expect(sut.model.shippingBanner == PurchaseDetailTest.retryableBanner(.network))
        #expect(sut.model.notesBanner == PurchaseDetailTest.retryableBanner(.server))

        sut.model.dismissNotesError()
        #expect(sut.model.notesBanner == nil)
        #expect(sut.model.shippingBanner != nil, "dismissing one section leaves the other alone")
    }

    @Test("Try Again repeats the save once and a success clears the banner")
    func tryAgainRepeatsSave() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setNotes("Retry me")
        await sut.model.saveNotes()
        #expect(sut.model.notesBanner != nil)

        sut.management.enqueue(PurchaseDetailTest.own(notes: "Retry me"))
        await sut.model.saveNotes()

        #expect(sut.callsAfterLoad.count == 2)
        #expect(sut.callsAfterLoad.first == sut.callsAfterLoad.last, "the retry sends the identical update")
        #expect(sut.model.notesBanner == nil)
        #expect(sut.model.announcement == "Notes saved.")
    }

    @Test("Dismiss clears the notes banner")
    func dismissClears() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setNotes("A note")
        await sut.model.saveNotes()
        #expect(sut.model.notesBanner != nil)

        sut.model.dismissNotesError()

        #expect(sut.model.notesBanner == nil)
    }

    @Test("disappear() clears the notes banner")
    func disappearClears() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.server)
        sut.setNotes("A note")
        await sut.model.saveNotes()

        sut.model.disappear()

        #expect(sut.model.notesBanner == nil)
    }

    @Test("The error announcement carries no note text")
    func errorAnnouncement() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.network)
        sut.setNotes("Private gift idea")

        await sut.model.saveNotes()

        let announcement = sut.model.announcement ?? ""
        #expect(announcement.contains(PurchaseManagementError.network.userMessage))
        #expect(!announcement.contains("Private gift idea"))
    }

    @Test("Unauthorized and an ended session show nothing",
          arguments: [PurchaseManagementError.unauthorized, .sessionEnded])
    func signedOutShowsNothing(error: PurchaseManagementError) async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(error)
        sut.setNotes("A note")

        await sut.model.saveNotes()

        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingNotes == false)
    }

    @Test("A not-found save finishes the screen as gone and shows no banner")
    func notFoundFinishesGone() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(PurchaseManagementError.notFound)
        sut.setNotes("A note")

        await sut.model.saveNotes()

        #expect(sut.model.finish == .gone)
        #expect(sut.model.notesBanner == nil)
        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingNotes == false)
        #expect(sut.model.announcement != "Notes saved.")
    }

    @Test("A cancellation shows nothing")
    func cancellationShowsNothing() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueueFailure(CancellationError())
        sut.setNotes("A note")

        await sut.model.saveNotes()

        #expect(sut.hasNoBanner)
        #expect(sut.model.isSavingNotes == false)
    }

    @Test("A teardown during the save shows nothing and applies nothing")
    func teardownMidFlight() async {
        let sut = await makeLoadedPurchaseDetailSUT()
        sut.management.enqueue(PurchaseDetailTest.own(notes: "Stale"), held: true)
        sut.setNotes("Stale")
        let task = Task { @MainActor in await sut.model.saveNotes() }
        _ = await sut.management.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.management.gate.releaseAll()
        await task.value

        #expect(sut.hasNoBanner)
        #expect(sut.model.announcement != "Notes saved.", "a stale result is never announced after the session ended")
        #expect(sut.model.isSavingNotes == false)
    }
}
