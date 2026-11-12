//
//  PurchaseUpdateBuilderTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the pure builders of the two update inputs and their wire values.
//  Notes: compare after trimming both ends (nil original is ""); equal gives nil; a trimmed empty
//  edit of a non-empty original is `.clear` (wire ""), never null; otherwise `.set(trimmed)`. The
//  notes update has no tracking field of any kind.
//  Shipping: nil when status and tracking are both unchanged; the status is always the edited
//  status; the tracking number is sent only when non-empty AND different from the trimmed
//  original; an empty edited tracking is "unchanged" and is never sent (never an empty string).
//
//  Fails today because the update types do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase update builder Tests")
struct PurchaseUpdateBuilderTests {

    // MARK: - Notes

    private func notes(_ original: String?, _ edited: String) -> PurchaseNotesUpdate? {
        PurchaseNotesUpdate.make(original: original, edited: edited)
    }

    @Test("Unchanged notes give no update", arguments: [
        ("Gift wrap", "Gift wrap"), ("Gift wrap", "  Gift wrap\n"), ("", ""), ("", "   \n\t ")
    ])
    func notesUnchanged(original: String, edited: String) {
        #expect(notes(original, edited) == nil)
    }

    @Test("A nil original is treated as empty")
    func nilOriginal() {
        #expect(notes(nil, "") == nil)
        #expect(notes(nil, "  \n ") == nil)
        #expect(notes(nil, "New note")?.change == .set("New note"))
    }

    @Test("A changed note is set with the trimmed text")
    func notesSet() {
        #expect(notes("Old", "  New note \n")?.change == .set("New note"))
        #expect(notes("", "Hello")?.change == .set("Hello"))
    }

    @Test("Interior whitespace and newlines are kept")
    func notesInteriorKept() {
        #expect(notes("x", "Line one\n\nLine  two")?.change == .set("Line one\n\nLine  two"))
    }

    @Test("Emptying a non-empty note is a clear", arguments: ["", "   ", "\n\t \n"])
    func notesClear(edited: String) {
        #expect(notes("Old", edited)?.change == .clear)
    }

    @Test("A whitespace-only original is empty, so a whitespace-only edit is unchanged")
    func whitespaceOriginal() {
        #expect(notes("   ", "") == nil)
        #expect(notes("   ", "Real")?.change == .set("Real"))
    }

    @Test("The notes wire value: unchanged omits, set sends the text, clear sends an empty string never null")
    func notesWire() {
        #expect(PurchaseNotesUpdate(change: .unchanged).wireNotes == nil)
        #expect(PurchaseNotesUpdate(change: .set("Hi")).wireNotes == "Hi")
        let cleared = PurchaseNotesUpdate(change: .clear).wireNotes
        #expect(cleared == "")
        #expect(cleared != nil)
    }

    @Test("Built clear carries the empty-string wire value")
    func builtClearWire() {
        #expect(notes("Old", "")?.wireNotes == "")
    }

    @Test("A notes update has no tracking member of any kind")
    func notesHasNoTracking() {
        let update = PurchaseNotesUpdate(change: .set("Hi"))
        let labels = Mirror(reflecting: update).children.compactMap(\.label).map { $0.lowercased() }
        #expect(labels.allSatisfy { !$0.contains("track") }, "\(labels)")
    }

    // MARK: - Shipping

    private func shipping(
        _ originalStatus: PurchaseShippingStatus, _ originalTracking: String?,
        _ editedStatus: PurchaseShippingStatus, _ editedTracking: String
    ) -> PurchaseShippingUpdate? {
        PurchaseShippingUpdate.make(
            originalStatus: originalStatus, originalTracking: originalTracking,
            editedStatus: editedStatus, editedTracking: editedTracking
        )
    }

    @Test("Nothing changed gives no update")
    func shippingUnchanged() {
        #expect(shipping(.shipped, "TRK-1", .shipped, "TRK-1") == nil)
        #expect(shipping(.shipped, "TRK-1", .shipped, "  TRK-1  ") == nil)
        #expect(shipping(.notTracked, nil, .notTracked, "") == nil)
        #expect(shipping(.notTracked, nil, .notTracked, "   ") == nil)
    }

    @Test("An empty edited tracking is unchanged and never sent",
          arguments: PurchaseShippingStatus.allCases, ["", "  ", "\n"])
    func emptyTrackingNeverSent(status: PurchaseShippingStatus, edited: String) {
        let update = shipping(.notTracked, "TRK-1", status, edited)
        if status == .notTracked {
            #expect(update == nil)
        } else {
            #expect(update == PurchaseShippingUpdate(status: status, trackingNumber: nil))
        }
        #expect(update?.trackingNumber != "")
    }

    @Test("A status change alone sends the new status and no tracking")
    func statusOnly() {
        #expect(shipping(.notShipped, "TRK-1", .shipped, "TRK-1") == PurchaseShippingUpdate(status: .shipped, trackingNumber: nil))
        #expect(shipping(.notTracked, nil, .delivered, "") == PurchaseShippingUpdate(status: .delivered, trackingNumber: nil))
    }

    @Test("A tracking change alone still carries the (unchanged) edited status")
    func trackingOnly() {
        #expect(shipping(.shipped, "TRK-1", .shipped, "TRK-2") == PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-2"))
        #expect(shipping(.shipped, nil, .shipped, "TRK-2") == PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-2"))
    }

    @Test("Both changed sends the status and the trimmed tracking")
    func both() {
        #expect(shipping(.notShipped, nil, .shipped, "  TRK-9 \n") == PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-9"))
    }

    @Test("The tracking is sent only when different from the TRIMMED original")
    func trackingComparedToTrimmedOriginal() {
        #expect(shipping(.shipped, "  TRK-1 ", .delivered, "TRK-1") == PurchaseShippingUpdate(status: .delivered, trackingNumber: nil))
        #expect(shipping(.shipped, "  TRK-1 ", .shipped, "TRK-1") == nil)
    }

    @Test("A tracking number differing only by case is a change")
    func trackingCaseSensitive() {
        #expect(shipping(.shipped, "trk-1", .shipped, "TRK-1") == PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-1"))
    }
}
