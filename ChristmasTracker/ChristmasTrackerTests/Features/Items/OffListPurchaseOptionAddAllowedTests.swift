//
//  OffListPurchaseOptionAddAllowedTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: the Add button rule (form validity AND the price requirement).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase option add-allowed Tests")
struct OffListPurchaseOptionAddAllowedTests {

    private static let memberCaps = ItemFixtures.capabilities(
        canCreateItem: true, canAddOffList: true, canSeeGiftActivity: true, canSeeOffList: true, canPurchase: true
    )
    private static let ownerCaps = ItemFixtures.capabilities(canCreateItem: true)

    private func makeSUT(
        priceText: String,
        wantsPurchase: Bool = true,
        quantity: Int = 1,
        capabilities: ListCapabilities = OffListPurchaseOptionAddAllowedTests.memberCaps
    ) -> OffListPurchaseOption {
        OffListPurchaseOption(
            capabilities: capabilities,
            mode: .add,
            wantsPurchase: wantsPurchase,
            priceText: priceText,
            quantity: quantity,
            locale: Locale(identifier: "en_US")
        )
    }

    @Test("Toggle on: Add needs a valid price above zero", arguments: [
        ("", false), ("0", false), ("0.00", false), ("abc", false), ("-1", false),
        ("1.234", false), ("1,5", false), ("12.50", true), ("12", true), ("0.01", true)
    ])
    func toggleOn(priceText: String, expected: Bool) {
        let sut = makeSUT(priceText: priceText)
        #expect(sut.allowsAdd(formIsValid: true) == expected, "price \(priceText)")
        #expect(sut.priceRequirementMet == expected, "price \(priceText)")
    }

    @Test("Toggle off: an empty price is allowed")
    func toggleOffEmptyPrice() {
        let sut = makeSUT(priceText: "", wantsPurchase: false)
        #expect(sut.priceRequirementMet == true)
        #expect(sut.allowsAdd(formIsValid: true) == true)
    }

    @Test("Toggle off: the form validity decides, even with an invalid price")
    func toggleOffFollowsFormValidity() {
        let sut = makeSUT(priceText: "abc", wantsPurchase: false)
        #expect(sut.priceRequirementMet == true)
        #expect(sut.allowsAdd(formIsValid: false) == false)
    }

    @Test("Toggle on with a valid price: a form that is not valid still blocks Add")
    func toggleOnFormInvalid() {
        let sut = makeSUT(priceText: "12.50")
        #expect(sut.allowsAdd(formIsValid: false) == false)
    }

    @Test("Toggle hidden (owner) with wantsPurchase true behaves as not requested")
    func hiddenToggleIgnoresWants() {
        let sut = makeSUT(priceText: "", wantsPurchase: true, capabilities: Self.ownerCaps)
        #expect(sut.isToggleShown == false)
        #expect(sut.priceRequirementMet == true)
        #expect(sut.allowsAdd(formIsValid: true) == true)
        #expect(sut.allowsAdd(formIsValid: false) == false)
    }

    @Test("Toggle on: a total above the cap keeps Add disabled")
    func overCapBlocksAdd() {
        let sut = makeSUT(priceText: "500000.00", quantity: 2)
        #expect(sut.totalCents == nil)
        #expect(sut.allowsAdd(formIsValid: true) == false)
    }

    @Test("Toggle off: a total above the cap does not block Add")
    func overCapIgnoredWhenOff() {
        let sut = makeSUT(priceText: "500000.00", wantsPurchase: false, quantity: 2)
        #expect(sut.allowsAdd(formIsValid: true) == true)
    }
}
