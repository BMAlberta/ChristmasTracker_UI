//
//  RecordPurchaseFormValidityTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the validity truth table of RecordPurchaseFormState, the draft it produces and
//  the default quantity. Bounds come from the generated createPurchase body: quantity at least 1
//  and no maximum, totalCost above 0 and at most 999999.99 with two decimals, storeName 200,
//  notes 1000, confirmationNumber 100, trackingNumber 100 (trimmed length).
//
//  Fails today because RecordPurchaseFormState and RecordPurchaseFormInput do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase form validity Tests")
struct RecordPurchaseFormValidityTests {

    // MARK: - Factory

    private func makeSUT(
        quantity: Int = 1,
        totalCost: String = "25.50",
        storeName: String = "",
        notes: String = "",
        confirmationNumber: String = "",
        trackingNumber: String = "",
        quantityRemaining: Int? = nil
    ) -> RecordPurchaseFormState {
        RecordPurchaseFormState(
            input: RecordPurchaseFormInput(
                quantity: quantity, totalCostText: totalCost, storeName: storeName, notes: notes,
                confirmationNumber: confirmationNumber, trackingNumber: trackingNumber
            ),
            quantityRemaining: quantityRemaining
        )
    }

    // MARK: - Total cost

    @Test("A valid cost makes the form valid and builds the draft with a Decimal",
          arguments: [("0.01", "0.01"), ("25.50", "25.50"), ("999999.99", "999999.99"), ("12", "12"), ("12.5", "12.5")])
    func validCosts(text: String, expected: String) throws {
        let sut = makeSUT(totalCost: text)
        #expect(sut.totalCostInvalid == false, "\(text)")
        #expect(sut.isValid, "\(text)")
        let draft = try #require(sut.draft)
        #expect(draft.totalCost == PurchaseFixtures.decimal(expected))
    }

    @Test("An invalid cost flags totalCostInvalid, makes the form invalid and gives no draft",
          arguments: ["", "   ", "0", "0.00", "-5", "-0.01", "1000000.00", "1000000", "12.345", "999999.995", "abc", "1,234.50"])
    func invalidCosts(text: String) {
        let sut = makeSUT(totalCost: text)
        #expect(sut.totalCostInvalid, "\(text)")
        #expect(sut.isValid == false, "\(text)")
        #expect(sut.draft == nil, "\(text)")
        #expect(sut.unitCostText == nil, "\(text)")
    }

    // MARK: - Quantity

    @Test("Quantity of at least 1 is valid, with no upper bound", arguments: [1, 2, 99, 1_000_000])
    func validQuantities(quantity: Int) {
        let sut = makeSUT(quantity: quantity)
        #expect(sut.quantityInvalid == false, "\(quantity)")
        #expect(sut.isValid, "\(quantity)")
        #expect(sut.draft?.quantity == quantity)
    }

    @Test("Quantity below 1 is invalid", arguments: [0, -1, -100])
    func invalidQuantities(quantity: Int) {
        let sut = makeSUT(quantity: quantity)
        #expect(sut.quantityInvalid, "\(quantity)")
        #expect(sut.isValid == false, "\(quantity)")
        #expect(sut.draft == nil, "\(quantity)")
    }

    @Test("Only the invalid field is flagged")
    func flagsAreIndependent() {
        let badQuantity = makeSUT(quantity: 0)
        #expect(badQuantity.quantityInvalid)
        #expect(badQuantity.totalCostInvalid == false)
        let badCost = makeSUT(totalCost: "")
        #expect(badCost.quantityInvalid == false)
        #expect(badCost.totalCostInvalid)
        let both = makeSUT(quantity: 0, totalCost: "")
        #expect(both.quantityInvalid && both.totalCostInvalid)
    }

    // MARK: - Optional text lengths (trimmed)

    enum TextField: CaseIterable, Sendable, CustomTestStringConvertible {
        case storeName, notes, confirmationNumber, trackingNumber

        var testDescription: String {
            switch self {
            case .storeName: "storeName"
            case .notes: "notes"
            case .confirmationNumber: "confirmationNumber"
            case .trackingNumber: "trackingNumber"
            }
        }

        var limit: Int {
            switch self {
            case .storeName: 200
            case .notes: 1000
            case .confirmationNumber, .trackingNumber: 100
            }
        }
    }

    private func makeSUT(setting field: TextField, to text: String) -> RecordPurchaseFormState {
        switch field {
        case .storeName: makeSUT(storeName: text)
        case .notes: makeSUT(notes: text)
        case .confirmationNumber: makeSUT(confirmationNumber: text)
        case .trackingNumber: makeSUT(trackingNumber: text)
        }
    }

    private func flag(_ field: TextField, in state: RecordPurchaseFormState) -> Bool {
        switch field {
        case .storeName: state.storeNameInvalid
        case .notes: state.notesInvalid
        case .confirmationNumber: state.confirmationNumberInvalid
        case .trackingNumber: state.trackingNumberInvalid
        }
    }

    @Test("Text exactly at the limit is valid; one over is invalid", arguments: TextField.allCases)
    func lengthBoundary(field: TextField) {
        let atLimit = makeSUT(setting: field, to: String(repeating: "a", count: field.limit))
        #expect(flag(field, in: atLimit) == false)
        #expect(atLimit.isValid)
        let over = makeSUT(setting: field, to: String(repeating: "a", count: field.limit + 1))
        #expect(flag(field, in: over))
        #expect(over.isValid == false)
        #expect(over.draft == nil)
    }

    @Test("The length limit applies to the trimmed text", arguments: TextField.allCases)
    func lengthIsTrimmed(field: TextField) {
        let padded = "  " + String(repeating: "a", count: field.limit) + "  "
        let sut = makeSUT(setting: field, to: padded)
        #expect(flag(field, in: sut) == false)
        #expect(sut.isValid)
    }

    // MARK: - Draft

    @Test("The draft trims the optional strings and turns blank ones into nil")
    func draftTrimsAndNilsBlanks() throws {
        let sut = makeSUT(
            quantity: 2, totalCost: "40.00", storeName: "  Fake Store  ", notes: "   ",
            confirmationNumber: "", trackingNumber: "\n TRK-1 \t"
        )
        let draft = try #require(sut.draft)
        #expect(draft.quantity == 2)
        #expect(draft.totalCost == PurchaseFixtures.decimal("40.00"))
        #expect(draft.storeName == "Fake Store")
        #expect(draft.notes == nil)
        #expect(draft.confirmationNumber == nil)
        #expect(draft.trackingNumber == "TRK-1")
    }

    @Test("All optional fields blank gives a draft with only quantity and cost")
    func draftWithOnlyRequiredFields() throws {
        let draft = try #require(makeSUT().draft)
        #expect(draft == PurchaseFixtures.draft(quantity: 1, totalCost: "25.50"))
    }

    // MARK: - Default quantity

    @Test("Default quantity is max(1, remaining) when remaining is known and above zero, otherwise 1",
          arguments: [(5, 5), (1, 1), (0, 1), (-2, 1), (100, 100)])
    func defaultQuantityKnown(remaining: Int, expected: Int) {
        #expect(RecordPurchaseFormState.defaultQuantity(quantityRemaining: remaining) == expected)
    }

    @Test("Default quantity is 1 when the remaining quantity is unknown")
    func defaultQuantityUnknown() {
        #expect(RecordPurchaseFormState.defaultQuantity(quantityRemaining: nil) == 1)
    }
}
