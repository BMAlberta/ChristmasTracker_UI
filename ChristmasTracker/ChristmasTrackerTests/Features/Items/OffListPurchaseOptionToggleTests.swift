//
//  OffListPurchaseOptionToggleTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: when the "I already bought this" toggle is shown. Flags only, never a role,
//  and only on the Add form.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase option toggle Tests")
struct OffListPurchaseOptionToggleTests {

    private func makeSUT(
        canAddOffList: Bool,
        canPurchase: Bool,
        mode: OffListPurchaseFormMode = .add,
        wantsPurchase: Bool = true
    ) -> OffListPurchaseOption {
        OffListPurchaseOption(
            capabilities: ItemFixtures.capabilities(
                canCreateItem: true,
                canAddOffList: canAddOffList,
                canSeeGiftActivity: true,
                canSeeOffList: true,
                canPurchase: canPurchase
            ),
            mode: mode,
            wantsPurchase: wantsPurchase,
            priceText: "12.50",
            quantity: 1,
            locale: Locale(identifier: "en_US")
        )
    }

    @Test("Toggle visibility follows the flags and the mode", arguments: [
        // (canAddOffList, canPurchase, mode, expected)
        (true, true, OffListPurchaseFormMode.add, true),
        (true, false, OffListPurchaseFormMode.add, false),
        (false, true, OffListPurchaseFormMode.add, false),
        (false, false, OffListPurchaseFormMode.add, false),
        (true, true, OffListPurchaseFormMode.edit, false),
        (true, false, OffListPurchaseFormMode.edit, false),
        (false, true, OffListPurchaseFormMode.edit, false)
    ])
    func visibilityTable(canAddOffList: Bool, canPurchase: Bool, mode: OffListPurchaseFormMode, expected: Bool) {
        let sut = makeSUT(canAddOffList: canAddOffList, canPurchase: canPurchase, mode: mode)
        #expect(sut.isToggleShown == expected)
    }

    @Test("An owner list (no off-list add) hides the toggle")
    func ownerListHidden() {
        let sut = OffListPurchaseOption(
            capabilities: ItemFixtures.capabilities(canCreateItem: true, canSeeGiftActivity: false, canPurchase: false),
            mode: .add, wantsPurchase: true, priceText: "10.00", quantity: 1
        )
        #expect(sut.isToggleShown == false)
        #expect(sut.isPurchaseRequested == false)
    }

    @Test("A co-owner without the off-list flag hides the toggle")
    func coOwnerHidden() {
        let sut = OffListPurchaseOption(
            capabilities: ItemFixtures.capabilities(canCreateItem: true, canSeeGiftActivity: true, canPurchase: true),
            mode: .add, wantsPurchase: true, priceText: "10.00", quantity: 1
        )
        #expect(sut.isToggleShown == false)
    }

    @Test("A member on an off-list-capable list shows the toggle")
    func memberShown() {
        let sut = makeSUT(canAddOffList: true, canPurchase: true)
        #expect(sut.isToggleShown == true)
    }

    @Test("A purchase is requested only when the toggle is shown and on")
    func purchaseRequested() {
        #expect(makeSUT(canAddOffList: true, canPurchase: true, wantsPurchase: true).isPurchaseRequested == true)
        #expect(makeSUT(canAddOffList: true, canPurchase: true, wantsPurchase: false).isPurchaseRequested == false)
        #expect(makeSUT(canAddOffList: true, canPurchase: false, wantsPurchase: true).isPurchaseRequested == false)
        #expect(
            makeSUT(canAddOffList: true, canPurchase: true, mode: .edit, wantsPurchase: true)
                .isPurchaseRequested == false
        )
    }
}
