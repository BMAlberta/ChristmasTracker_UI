//
//  PurchaseShippingSectionStateTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the shipping section of the purchase detail. canSave is `update != nil &&
//  !trackingTooLong`; trackingTooLong when the TRIMMED draft tracking has more than 100 UTF-16
//  units; applying(_:) resets original and draft from a returned purchase.
//
//  The construction and the `editing` copy are the assumed shape (see the story report):
//  `PurchaseShippingSectionState(purchase:)` and `editing(status:tracking:)` where an omitted
//  argument keeps the current draft value.
//
//  Fails today because PurchaseShippingSectionState does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase shipping section state Tests")
struct PurchaseShippingSectionStateTests {

    private func makeSUT(
        status: PurchaseShippingStatus = .notShipped,
        tracking: String? = "TRK-1"
    ) -> PurchaseShippingSectionState {
        PurchaseShippingSectionState(
            purchase: PurchaseFixtures.recordedPurchase(trackingNumber: tracking, shippingStatus: status)
        )
    }

    private func units(_ count: Int) -> String { String(repeating: "a", count: count) }

    @Test("A fresh section mirrors the purchase and has nothing to save")
    func fresh() {
        let sut = makeSUT(status: .shipped, tracking: "TRK-1")
        #expect(sut.draftStatus == .shipped)
        #expect(sut.draftTracking == "TRK-1")
        #expect(sut.update == nil)
        #expect(!sut.canSave)
        #expect(!sut.trackingTooLong)
    }

    @Test("A purchase without a tracking number starts with an empty draft")
    func freshWithoutTracking() {
        let sut = makeSUT(tracking: nil)
        #expect(sut.draftTracking == "")
        #expect(!sut.canSave)
    }

    @Test("Changing the status enables Save", arguments: PurchaseShippingStatus.allCases.filter { $0 != .notShipped })
    func statusChange(status: PurchaseShippingStatus) {
        let sut = makeSUT().editing(status: status)
        #expect(sut.update == PurchaseShippingUpdate(status: status, trackingChange: .unchanged))
        #expect(sut.trackingChange == .unchanged)
        #expect(sut.canSave)
    }

    @Test("Changing the tracking enables Save and sends the trimmed tracking")
    func trackingChange() {
        let sut = makeSUT().editing(tracking: "  TRK-2 ")
        #expect(sut.update == PurchaseShippingUpdate(status: .notShipped, trackingChange: .set("TRK-2")))
        #expect(sut.trackingChange == .set("TRK-2"))
        #expect(sut.canSave)
    }

    @Test("Whitespace-only differences are not a change", arguments: ["TRK-1", " TRK-1", "TRK-1 \n"])
    func whitespaceOnly(tracking: String) {
        let sut = makeSUT().editing(tracking: tracking)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Emptying a saved tracking field alone is a clear: Save is enabled and the status is carried (rewritten: the old rule was 'empty means unchanged')",
          arguments: ["", "   ", "\n"])
    func emptyTrackingClears(draft: String) {
        let sut = makeSUT().editing(tracking: draft)
        #expect(sut.trackingChange == .clear)
        #expect(sut.update == PurchaseShippingUpdate(status: .notShipped, trackingChange: .clear))
        #expect(sut.update?.wireTrackingNumber == "")
        #expect(sut.canSave)
    }

    @Test("Emptying a saved tracking field together with a status change is a clear with the new status")
    func emptyTrackingWithStatus() {
        let sut = makeSUT().editing(tracking: "").editing(status: .shipped)
        #expect(sut.update == PurchaseShippingUpdate(status: .shipped, trackingChange: .clear))
        #expect(sut.canSave)
    }

    @Test("Tracking-only set carries the current status")
    func trackingOnlySetCarriesStatus() {
        let sut = makeSUT(status: .shipped, tracking: nil).editing(tracking: "TEST123")
        #expect(sut.update == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TEST123")))
        #expect(sut.canSave)
    }

    @Test("Status and tracking both changed enables Save with both")
    func bothChanged() {
        let sut = makeSUT().editing(status: .delivered, tracking: "TEST456")
        #expect(sut.update == PurchaseShippingUpdate(status: .delivered, trackingChange: .set("TEST456")))
        #expect(sut.canSave)
    }

    @Test("Neither changed leaves Save disabled")
    func neitherChanged() {
        let sut = makeSUT()
        #expect(sut.trackingChange == .unchanged)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Editing the tracking back to the original disables Save again")
    func trackingRevert() {
        let sut = makeSUT().editing(tracking: "TEST999").editing(tracking: "TRK-1")
        #expect(sut.trackingChange == .unchanged)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("Clearing and then retyping the original disables Save again")
    func clearThenRetype() {
        let sut = makeSUT().editing(tracking: "").editing(tracking: "TRK-1")
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("A whitespace-only draft against an empty original is not a change", arguments: [nil, "", "   "])
    func whitespaceDraftAgainstEmptyOriginal(original: String?) {
        let sut = makeSUT(tracking: original).editing(tracking: "   \n")
        #expect(sut.trackingChange == .unchanged)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    @Test("A too-long set is blocked but the derived change is still a set")
    func tooLongSetBlocked() {
        let sut = makeSUT(tracking: nil).editing(tracking: units(101))
        #expect(sut.trackingChange == .set(units(101)))
        #expect(sut.trackingTooLong)
        #expect(!sut.canSave)
    }

    @Test("Clearing a too-long original is allowed")
    func tooLongOriginalCleared() {
        let cleared = makeSUT(tracking: units(150)).editing(tracking: "")
        #expect(cleared.trackingChange == .clear)
        #expect(!cleared.trackingTooLong)
        #expect(cleared.canSave)
    }

    // MARK: - Display normalization

    @Test("The draft tracking is built from the display text", arguments: [
        (nil, ""), ("", ""), ("   ", ""), ("TEST123", "TEST123"), ("  TEST123 ", "  TEST123 ")
    ] as [(String?, String)])
    func draftFromPurchase(stored: String?, expected: String) {
        #expect(makeSUT(tracking: stored).draftTracking == expected)
    }

    @Test("An empty or null stored tracking number starts with Save disabled", arguments: [nil, "", "   "])
    func emptyStoredStartsDisabled(stored: String?) {
        let sut = makeSUT(tracking: stored)
        #expect(sut.draftTracking == "")
        #expect(sut.trackingChange == .unchanged)
        #expect(!sut.canSave)
    }

    @Test("Setting the status back to the original disables Save again")
    func revert() {
        let sut = makeSUT().editing(status: .shipped).editing(status: .notShipped)
        #expect(sut.update == nil)
        #expect(!sut.canSave)
    }

    // MARK: - Limit (100 UTF-16 units, trimmed)

    @Test("Exactly 100 units is allowed, 101 is too long and blocks Save", arguments: [
        (100, false), (101, true), (99, false), (200, true)
    ])
    func limit(count: Int, tooLong: Bool) {
        let sut = makeSUT(tracking: nil).editing(tracking: units(count))
        #expect(sut.trackingTooLong == tooLong)
        #expect(sut.canSave == !tooLong)
    }

    @Test("A too-long tracking blocks Save even when the status also changed")
    func tooLongWithStatusChange() {
        let sut = makeSUT().editing(status: .shipped, tracking: units(101))
        #expect(sut.update != nil)
        #expect(sut.trackingTooLong)
        #expect(!sut.canSave)
    }

    @Test("The limit applies to the trimmed text")
    func limitIsTrimmed() {
        let sut = makeSUT(tracking: nil).editing(tracking: "  " + units(100) + " \n")
        #expect(!sut.trackingTooLong)
        #expect(sut.canSave)
    }

    @Test("An emoji counts as two UTF-16 units at the boundary")
    func emojiBoundary() {
        let atLimit = makeSUT(tracking: nil).editing(tracking: units(98) + "\u{1F600}")
        #expect(!atLimit.trackingTooLong)
        #expect(atLimit.canSave)
        let overLimit = makeSUT(tracking: nil).editing(tracking: units(99) + "\u{1F600}")
        #expect(overLimit.trackingTooLong)
        #expect(!overLimit.canSave)
    }

    // MARK: - applying

    @Test("Applying a returned purchase resets original and draft, leaving nothing to save")
    func applyingResets() {
        let edited = makeSUT().editing(status: .shipped, tracking: "TRK-2")
        #expect(edited.canSave)
        let returned = PurchaseFixtures.recordedPurchase(trackingNumber: "TRK-2", shippingStatus: .shipped)
        let applied = edited.applying(returned)
        #expect(applied.draftStatus == .shipped)
        #expect(applied.draftTracking == "TRK-2")
        #expect(applied.update == nil)
        #expect(!applied.canSave)
    }

    @Test("Applying a purchase with no tracking resets the draft tracking to empty")
    func applyingNoTracking() {
        let applied = makeSUT().editing(tracking: "TRK-9")
            .applying(PurchaseFixtures.recordedPurchase(trackingNumber: nil, shippingStatus: .delivered))
        #expect(applied.draftStatus == .delivered)
        #expect(applied.draftTracking == "")
        #expect(applied.update == nil)
    }

    @Test("After applying, the returned purchase is the new baseline for the next change")
    func applyingNewBaseline() {
        let applied = makeSUT().editing(status: .shipped)
            .applying(PurchaseFixtures.recordedPurchase(trackingNumber: "TRK-1", shippingStatus: .shipped))
        let next = applied.editing(status: .delivered)
        #expect(next.update == PurchaseShippingUpdate(status: .delivered, trackingChange: .unchanged))
    }

    @Test("Applying a returned purchase with null or empty tracking gives an empty draft and a disabled Save",
          arguments: [nil, ""])
    func applyingReturnedEmptyTracking(returnedTracking: String?) {
        let applied = makeSUT().editing(tracking: "")
            .applying(PurchaseFixtures.recordedPurchase(trackingNumber: returnedTracking, shippingStatus: .notShipped))
        #expect(applied.draftTracking == "")
        #expect(applied.trackingChange == .unchanged)
        #expect(applied.update == nil)
        #expect(!applied.canSave)
    }

    @Test("Applying a returned purchase with a whitespace-only tracking gives an empty draft")
    func applyingReturnedWhitespaceTracking() {
        let applied = makeSUT()
            .applying(PurchaseFixtures.recordedPurchase(trackingNumber: "   ", shippingStatus: .notShipped))
        #expect(applied.draftTracking == "")
        #expect(!applied.canSave)
    }

    // MARK: - Empty value display text

    @Test("The display text of an empty value is empty; any other value is unchanged", arguments: [
        (nil, ""), ("", ""), ("   ", ""), ("\n\t", ""), ("TEST123", "TEST123"), (" TEST123 ", " TEST123 ")
    ] as [(String?, String)])
    func displayText(value: String?, expected: String) {
        #expect(PurchaseEmptyValue.displayText(value) == expected)
    }

    @Test("The notes draft is built from the display text", arguments: [
        (nil, ""), ("", ""), ("   ", ""), ("Gift wrap", "Gift wrap")
    ] as [(String?, String)])
    func notesDraftFromPurchase(stored: String?, expected: String) {
        let sut = PurchaseNotesSectionState(purchase: PurchaseFixtures.recordedPurchase(notes: stored))
        #expect(sut.draftText == expected)
    }
}
