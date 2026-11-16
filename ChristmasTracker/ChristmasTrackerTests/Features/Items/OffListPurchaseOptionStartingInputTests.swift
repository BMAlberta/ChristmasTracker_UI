//
//  OffListPurchaseOptionStartingInputTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: the prefilled Record Purchase input.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase option starting input Tests")
struct OffListPurchaseOptionStartingInputTests {

    private static let memberCaps = ItemFixtures.capabilities(
        canCreateItem: true, canAddOffList: true, canSeeGiftActivity: true, canSeeOffList: true, canPurchase: true
    )

    private func makeSUT(
        priceText: String = "12.50",
        quantity: Int = 3,
        wantsPurchase: Bool = true,
        capabilities: ListCapabilities = OffListPurchaseOptionStartingInputTests.memberCaps,
        mode: OffListPurchaseFormMode = .add
    ) -> OffListPurchaseOption {
        OffListPurchaseOption(
            capabilities: capabilities,
            mode: mode,
            wantsPurchase: wantsPurchase,
            priceText: priceText,
            quantity: quantity,
            locale: Locale(identifier: "en_US")
        )
    }

    @Test("The starting input carries the quantity and total text, and empty text everywhere else")
    func fields() {
        let input = makeSUT().startingInput
        #expect(input == RecordPurchaseFormInput(
            quantity: 3,
            totalCostText: "37.50",
            storeName: "",
            notes: "",
            confirmationNumber: "",
            trackingNumber: ""
        ))
    }

    @Test("Quantity 1 with a whole-dollar price gives two decimals")
    func wholeDollar() {
        let input = makeSUT(priceText: "20", quantity: 1).startingInput
        #expect(input?.quantity == 1)
        #expect(input?.totalCostText == "20.00")
    }

    @Test("No starting input when the toggle is off")
    func toggleOff() {
        #expect(makeSUT(wantsPurchase: false).startingInput == nil)
    }

    @Test("No starting input when the toggle is hidden")
    func toggleHidden() {
        #expect(makeSUT(capabilities: ItemFixtures.capabilities(canCreateItem: true)).startingInput == nil)
        #expect(makeSUT(mode: .edit).startingInput == nil)
    }

    @Test("No starting input when the total is nil", arguments: ["", "0", "abc", "1.234"])
    func totalNil(price: String) {
        #expect(makeSUT(priceText: price).startingInput == nil)
    }

    @Test("No starting input when the total is over the cap")
    func overCap() {
        #expect(makeSUT(priceText: "500000.00", quantity: 2).startingInput == nil)
    }
}
