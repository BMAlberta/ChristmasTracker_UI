//
//  RecordPurchaseOverPurchasePromptTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the SOFT over-purchase prompt. It exists only when quantityRemaining is known,
//  the quantity exceeds it and the form is valid. It never changes isValid or draft (the server
//  accepts any quantity of at least 1), and an unknown remaining quantity never produces a prompt
//  or any computed value.
//
//  Fails today because RecordPurchaseFormState and OverPurchasePrompt do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase over-purchase prompt Tests")
struct RecordPurchaseOverPurchasePromptTests {

    private func makeSUT(
        quantity: Int,
        quantityRemaining: Int?,
        totalCost: String = "25.50"
    ) -> RecordPurchaseFormState {
        RecordPurchaseFormState(
            input: RecordPurchaseFormInput(
                quantity: quantity, totalCostText: totalCost, storeName: "", notes: "",
                confirmationNumber: "", trackingNumber: ""
            ),
            quantityRemaining: quantityRemaining
        )
    }

    @Test("Exceeding a positive remaining quantity prompts with the remaining count in the message")
    func exceededWithRemaining() throws {
        let prompt = try #require(makeSUT(quantity: 5, quantityRemaining: 3).overPurchasePrompt)
        #expect(prompt.title == "Record anyway?")
        #expect(prompt.message == "Only 3 remaining. You're recording 5.")
        #expect(prompt.confirmButtonTitle == "Continue Anyway")
    }

    @Test("One over a remaining of 1 prompts", arguments: [(2, 1), (10, 9), (100, 1)])
    func exceededByAny(quantity: Int, remaining: Int) throws {
        let prompt = try #require(makeSUT(quantity: quantity, quantityRemaining: remaining).overPurchasePrompt)
        #expect(prompt.message == "Only \(remaining) remaining. You're recording \(quantity).")
    }

    @Test("Zero remaining prompts with its own wording that says the item was already fully purchased")
    func zeroRemaining() throws {
        let prompt = try #require(makeSUT(quantity: 1, quantityRemaining: 0).overPurchasePrompt)
        #expect(prompt.title == "Record anyway?")
        #expect(prompt.message == "This item has already been fully purchased, and others may have bought it too.")
        #expect(prompt.confirmButtonTitle == "Continue Anyway")
    }

    @Test("No prompt when the quantity equals or is below the remaining quantity",
          arguments: [(3, 3), (1, 3), (2, 3), (1, 1)])
    func noPromptWithinRemaining(quantity: Int, remaining: Int) {
        #expect(makeSUT(quantity: quantity, quantityRemaining: remaining).overPurchasePrompt == nil)
    }

    @Test("No prompt and no computed value when the remaining quantity is unknown", arguments: [1, 5, 1_000])
    func noPromptWhenUnknown(quantity: Int) {
        #expect(makeSUT(quantity: quantity, quantityRemaining: nil).overPurchasePrompt == nil)
    }

    @Test("No prompt when the form is invalid, even if the quantity exceeds the remaining one",
          arguments: ["", "0", "12.345", "abc"])
    func noPromptWhenInvalid(cost: String) {
        let sut = makeSUT(quantity: 5, quantityRemaining: 3, totalCost: cost)
        #expect(sut.isValid == false)
        #expect(sut.overPurchasePrompt == nil)
    }

    @Test("A prompt never blocks: the form stays valid and the draft keeps the exceeding quantity")
    func promptNeverBlocks() throws {
        let sut = makeSUT(quantity: 5, quantityRemaining: 0)
        #expect(sut.overPurchasePrompt != nil)
        #expect(sut.isValid)
        let draft = try #require(sut.draft)
        #expect(draft.quantity == 5)
    }
}
