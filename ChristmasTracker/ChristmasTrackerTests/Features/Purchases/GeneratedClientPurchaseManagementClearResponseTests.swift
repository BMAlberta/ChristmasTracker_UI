//
//  GeneratedClientPurchaseManagementClearResponseTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-B (S15): how the purchase in a 200 body maps for `trackingNumber` and `notes`, through
//  the real factory-built client and the fake transport, for getPurchase, updatePurchase,
//  updatePurchaseShipping and deletePurchase.
//
//  Rule under test (Gate 1 Story B interface item 2): null, the key absent, "" and a whitespace-only
//  value all become nil in the domain RecordedPurchase; any other value is kept exactly as received
//  (not trimmed). The fixtures are the guide's purchase shape with item {id, name, listId} inside the
//  success envelope with the full `meta` object.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated struct TextCase: Sendable, CustomTestStringConvertible {
    let name: String
    let wire: ManagementWire.WireText
    let expected: String?

    var testDescription: String { name }

    static let all: [TextCase] = [
        TextCase(name: "null", wire: .null, expected: nil),
        TextCase(name: "empty string", wire: .text(""), expected: nil),
        TextCase(name: "spaces only", wire: .text("   "), expected: nil),
        TextCase(name: "key absent", wire: .absent, expected: nil),
        TextCase(name: "a value", wire: .text("TRK-FAKE-0001"), expected: "TRK-FAKE-0001"),
        TextCase(name: "a value with surrounding spaces is kept as received", wire: .text(" TRK-FAKE-0002 "), expected: " TRK-FAKE-0002 ")
    ]
}

@Suite("GeneratedClientPurchaseManagementRepository response mapping of cleared fields", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseManagementClearResponseTests {

    private func purchase(
        for op: ManagementOp, tracking: ManagementWire.WireText, notes: ManagementWire.WireText
    ) async throws -> RecordedPurchase {
        let sut = try makePurchaseManagementSUT()
        let json = ManagementWire.purchaseJSON(trackingNumber: tracking, notes: notes)
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope(json))
        return try await sut.run(op)
    }

    @Test("trackingNumber null, empty, blank or absent maps to nil; a value is kept",
          arguments: ManagementOp.allCases, TextCase.all)
    func trackingNumberMapping(op: ManagementOp, textCase: TextCase) async throws {
        let recorded = try await purchase(for: op, tracking: textCase.wire, notes: .null)

        #expect(recorded.trackingNumber == textCase.expected, "\(op): \(textCase.name)")
    }

    @Test("notes null, empty, blank or absent maps to nil; a value is kept",
          arguments: ManagementOp.allCases, TextCase.all)
    func notesMapping(op: ManagementOp, textCase: TextCase) async throws {
        let recorded = try await purchase(for: op, tracking: .null, notes: textCase.wire)

        #expect(recorded.notes == textCase.expected, "\(op): \(textCase.name)")
    }

    @Test("both fields empty at once map to nil independently", arguments: ManagementOp.allCases)
    func bothEmpty(op: ManagementOp) async throws {
        let recorded = try await purchase(for: op, tracking: .text(""), notes: .text(""))

        #expect(recorded.trackingNumber == nil)
        #expect(recorded.notes == nil)
    }

    @Test("an empty tracking number does not disturb a notes value, and the other way round", arguments: ManagementOp.allCases)
    func fieldsAreIndependent(op: ManagementOp) async throws {
        let trackingEmpty = try await purchase(for: op, tracking: .text(""), notes: .text("Gift wrap please"))
        let notesEmpty = try await purchase(for: op, tracking: .text("TRK-FAKE-0003"), notes: .text(""))

        #expect(trackingEmpty.trackingNumber == nil)
        #expect(trackingEmpty.notes == "Gift wrap please")
        #expect(notesEmpty.trackingNumber == "TRK-FAKE-0003")
        #expect(notesEmpty.notes == nil)
    }

    @Test("the rest of the purchase still maps when the tracking number is empty", arguments: ManagementOp.allCases)
    func restOfThePurchaseIsUnchanged(op: ManagementOp) async throws {
        let recorded = try await purchase(for: op, tracking: .text(""), notes: .text(""))

        #expect(recorded.id == "purchase-1")
        #expect(recorded.itemId == "item-1")
        #expect(recorded.shippingStatus == .shipped)
        #expect(recorded.item == PurchaseItemReference(id: "item-1", name: "Fake Lamp", listId: "list-1"))
    }

    @Test("a shipping update answered with a null tracking number returns nil (the clear round trip)")
    func clearRoundTrip() async throws {
        let sut = try makePurchaseManagementSUT()
        let json = ManagementWire.purchaseJSON(trackingNumber: .null, notes: .null)
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope(json))

        let recorded = try await sut.repo.updateShipping(
            id: "purchase-1", update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
        )

        #expect(recorded.trackingNumber == nil)
        #expect(recorded.shippingStatus == .shipped)
    }
}
