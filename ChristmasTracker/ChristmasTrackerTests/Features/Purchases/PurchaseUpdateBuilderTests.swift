//
//  PurchaseUpdateBuilderTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the pure builders of the two update inputs and their wire values.
//  Notes: compare after trimming both ends (nil original is ""); equal gives nil; a trimmed empty
//  edit of a non-empty original is `.clear` (wire ""), never null; otherwise `.set(trimmed)`. The
//  notes update has no tracking field of any kind.
//  Shipping (decision S15): nil when status and tracking change are both unchanged; the status is
//  always the edited status; the tracking change is derived (unchanged, set, clear). The wire value
//  omits an unchanged tracking number, sends the value for set and "" for clear (never null).
//
//  Fails today because PurchaseShippingUpdate has no trackingChange member yet.
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

    @Test("An empty edited tracking against a non-empty original is a clear (rewritten: the old rule was 'empty means unchanged')",
          arguments: PurchaseShippingStatus.allCases, ["", "  ", "\n"])
    func emptyTrackingClears(status: PurchaseShippingStatus, edited: String) {
        let update = shipping(.notTracked, "TRK-1", status, edited)
        #expect(update == PurchaseShippingUpdate(status: status, trackingChange: .clear))
        #expect(update?.wireTrackingNumber == "")
    }

    @Test("A status change alone sends the new status and no tracking")
    func statusOnly() {
        let update = shipping(.notShipped, "TRK-1", .shipped, "TRK-1")
        #expect(update == PurchaseShippingUpdate(status: .shipped, trackingChange: .unchanged))
        #expect(update?.trackingChange == .unchanged)
        #expect(update?.wireTrackingNumber == nil)
        #expect(shipping(.notTracked, nil, .delivered, "") == PurchaseShippingUpdate(status: .delivered, trackingChange: .unchanged))
    }

    @Test("A tracking set alone still carries the (unchanged) edited status")
    func trackingOnlySet() {
        #expect(shipping(.shipped, "TRK-1", .shipped, "TRK-2") == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-2")))
        #expect(shipping(.shipped, nil, .shipped, "TRK-2") == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-2")))
        #expect(shipping(.shipped, "", .shipped, "TRK-2") == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-2")))
    }

    @Test("A tracking clear alone still carries the (unchanged) edited status and the empty-string wire value")
    func trackingOnlyClear() {
        let update = shipping(.shipped, "TRK-1", .shipped, "")
        #expect(update == PurchaseShippingUpdate(status: .shipped, trackingChange: .clear))
        #expect(update?.wireTrackingNumber == "")
        #expect(update?.wireTrackingNumber != nil)
    }

    @Test("Both changed (set) sends the new status and the trimmed tracking")
    func bothSet() {
        let update = shipping(.notShipped, nil, .shipped, "  TRK-9 \n")
        #expect(update == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-9")))
        #expect(update?.wireTrackingNumber == "TRK-9")
    }

    @Test("Both changed (clear) sends the new status and the empty string")
    func bothClear() {
        let update = shipping(.notShipped, "TRK-1", .delivered, "   ")
        #expect(update == PurchaseShippingUpdate(status: .delivered, trackingChange: .clear))
        #expect(update?.wireTrackingNumber == "")
    }

    @Test("Neither changed gives no update")
    func neither() {
        #expect(shipping(.delivered, "TRK-1", .delivered, "TRK-1") == nil)
        #expect(shipping(.delivered, nil, .delivered, "") == nil)
    }

    @Test("A whitespace-only edit against an empty original is no update", arguments: [nil, "", "   "])
    func whitespaceAgainstEmptyOriginal(original: String?) {
        #expect(shipping(.shipped, original, .shipped, " \n\t ") == nil)
    }

    @Test("A whitespace-only edit against a non-empty original is a clear")
    func whitespaceAgainstNonEmptyOriginal() {
        #expect(shipping(.shipped, "TEST123", .shipped, "   ") == PurchaseShippingUpdate(status: .shipped, trackingChange: .clear))
    }

    @Test("The tracking is compared to the TRIMMED original")
    func trackingComparedToTrimmedOriginal() {
        #expect(shipping(.shipped, "  TRK-1 ", .delivered, "TRK-1") == PurchaseShippingUpdate(status: .delivered, trackingChange: .unchanged))
        #expect(shipping(.shipped, "  TRK-1 ", .shipped, "TRK-1") == nil)
    }

    @Test("A tracking number differing only by case is a change")
    func trackingCaseSensitive() {
        #expect(shipping(.shipped, "trk-1", .shipped, "TRK-1") == PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-1")))
    }

    // MARK: - Wire value

    @Test("The wire tracking number: unchanged omits, set sends the value, clear sends an empty string never null")
    func wireTrackingNumber() {
        #expect(PurchaseShippingUpdate(status: .shipped, trackingChange: .unchanged).wireTrackingNumber == nil)
        #expect(PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TEST123")).wireTrackingNumber == "TEST123")
        let cleared = PurchaseShippingUpdate(status: .shipped, trackingChange: .clear).wireTrackingNumber
        #expect(cleared == "")
        #expect(cleared != nil)
    }
}
