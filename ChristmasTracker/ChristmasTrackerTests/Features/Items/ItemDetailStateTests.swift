//
//  ItemDetailStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the pure view state of the item detail screen for every persona.
//
//  Privacy rule under test: status, purchases, progress, remaining quantity and updatedAt
//  show only when canSeeGiftActivity is true. For blind owners, blind co-owners, VIEWER-role
//  members and PUBLIC non-members they are nil/empty EVEN IF the item carries them (defence in
//  depth: the server omits them, the client must not show them if one slips through).
//  The purchase entry point is the canPurchase flag exactly.
//
//  I5b Story C: showsEdit and showsDelete read only the item's canEdit and canDelete flags.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item detail state Tests")
struct ItemDetailStateTests {

    // MARK: - Factory

    private func makeSUT(
        _ item: ListItem,
        capabilities: ListCapabilities,
        currentUserId: String? = ItemFixtures.currentUserId,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) -> ItemDetailState {
        ItemDetailState(item: item, capabilities: capabilities, currentUserId: currentUserId,
                        currencyCode: currencyCode, locale: locale, now: ItemFixtures.nowDate)
    }

    /// A fully populated detail item, as an owner would receive it.
    private var richItem: ListItem {
        ItemFixtures.item(
            id: "item-rich", name: "Fake Lamp", description: "A fake lamp",
            price: ItemFixtures.decimal("19.99"), quantity: 4, priority: 8,
            status: .partial, offList: false,
            updatedAt: ItemFixtures.updatedDate,
            purchases: [
                ItemFixtures.purchase(id: "p-1", quantity: 1, totalCost: ItemFixtures.decimal("19.99")),
                ItemFixtures.purchase(id: "p-2", quantity: 1, totalCost: ItemFixtures.decimal("1234.50"),
                                      purchaser: ItemFixtures.person(id: "user-4", displayName: "Alex Buyer"))
            ],
            totalQuantityPurchased: 2,
            quantityPurchased: 2,
            quantityRemaining: 2
        )
    }

    // MARK: - Text fields

    @Test("Title, description, price, quantity and priority texts")
    func basicTexts() {
        let sut = makeSUT(richItem, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.title == "Fake Lamp")
        #expect(sut.descriptionText == "A fake lamp")
        #expect(sut.priceText == "$19.99")
        #expect(sut.quantityText.contains("4"))
        #expect(sut.priorityText.contains("8"))
    }

    @Test("A blank description gives nil", arguments: ["", "   ", "\n\t "])
    func blankDescription(text: String) {
        let sut = makeSUT(ItemFixtures.item(description: text), capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.descriptionText == nil)
    }

    @Test("A missing price gives nil price text")
    func missingPrice() {
        let sut = makeSUT(ItemFixtures.item(price: nil), capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.priceText == nil)
    }

    @Test("Large and small prices format with the grouping and two decimals",
          arguments: [("1234.50", "$1,234.50"), ("0.10", "$0.10")])
    func priceFormats(price: String, expected: String) {
        let sut = makeSUT(ItemFixtures.item(price: ItemFixtures.decimal(price)),
                          capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.priceText == expected)
    }

    // MARK: - Gift activity shown (owner, co-owner, member)

    @Test("Owner sees status, purchases, progress, remaining and updatedAt",
          arguments: [ItemFixtures.Persona.owner, .coOwner, .member])
    func giftActivityShown(persona: ItemFixtures.Persona) {
        let sut = makeSUT(richItem, capabilities: persona.capabilities)
        #expect(sut.statusMarker == .partial, "\(persona)")
        #expect(sut.progress == 0.5, "\(persona)")
        #expect(sut.remainingQuantity == 2, "\(persona)")
        #expect(sut.updatedText != nil, "\(persona)")
        #expect(sut.purchases.map(\.id) == ["p-1", "p-2"], "\(persona)")
    }

    @Test("Purchase rows carry quantity, formatted total and the purchaser name")
    func purchaseRows() {
        let sut = makeSUT(richItem, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.purchases.count == 2)
        #expect(sut.purchases[0].quantity == 1)
        #expect(sut.purchases[0].totalCostText == "$19.99")
        #expect(sut.purchases[0].purchaserName == "Sam Buyer")
        #expect(sut.purchases[1].totalCostText == "$1,234.50")
        #expect(sut.purchases[1].purchaserName == "Alex Buyer")
    }

    // MARK: - Gift activity hidden

    @Test("Blind owner, blind co-owner, VIEWER and PUBLIC see no status, purchases, progress or updatedAt even if present",
          arguments: [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember])
    func giftActivityHidden(persona: ItemFixtures.Persona) {
        let sut = makeSUT(richItem, capabilities: persona.capabilities)
        #expect(sut.statusMarker == nil, "\(persona)")
        #expect(sut.progress == nil, "\(persona)")
        #expect(sut.remainingQuantity == nil, "\(persona)")
        #expect(sut.updatedText == nil, "\(persona)")
        #expect(sut.purchases.isEmpty, "\(persona)")
        // Fields that are not gift activity still show.
        #expect(sut.title == "Fake Lamp", "\(persona)")
        #expect(sut.priceText == "$19.99", "\(persona)")
    }

    @Test("A bare item as the server sends it to a blind viewer shows only the plain fields")
    func bareItemForBlindViewer() {
        let bare = ItemFixtures.item(status: .available, updatedAt: nil, purchases: nil, totalQuantityPurchased: nil)
        let sut = makeSUT(bare, capabilities: ItemFixtures.Persona.viewer.capabilities)
        #expect(sut.statusMarker == nil)
        #expect(sut.purchases.isEmpty)
        #expect(sut.progress == nil)
        #expect(sut.remainingQuantity == nil)
        #expect(sut.updatedText == nil)
    }

    // MARK: - Progress, remaining, updatedText with gift activity

    @Test("Progress is purchased over requested, clamped to 0...1",
          arguments: [(0, 4, 0.0), (1, 4, 0.25), (2, 4, 0.5), (4, 4, 1.0), (7, 4, 1.0)])
    func progressValues(purchased: Int, requested: Int, expected: Double) {
        let item = ItemFixtures.item(quantity: requested, totalQuantityPurchased: purchased)
        let sut = makeSUT(item, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.progress == expected)
    }

    @Test("Progress is nil when the requested quantity is zero")
    func progressNilForZeroRequested() {
        let item = ItemFixtures.item(quantity: 0, totalQuantityPurchased: 0)
        let sut = makeSUT(item, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.progress == nil)
    }

    @Test("Progress and remaining are nil when the purchased and remaining quantities are absent")
    func progressNilWithoutPurchasedQuantity() {
        let item = ItemFixtures.item(quantity: 4, totalQuantityPurchased: nil, quantityPurchased: nil, quantityRemaining: nil)
        let sut = makeSUT(item, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.progress == nil)
        #expect(sut.remainingQuantity == nil)
    }

    @Test("Remaining quantity is the server's quantityRemaining, not a client computation")
    func remaining() {
        let item = ItemFixtures.item(quantity: 5, totalQuantityPurchased: 2, quantityPurchased: 2, quantityRemaining: 3)
        let sut = makeSUT(item, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.remainingQuantity == 3)
    }

    @Test("updatedText is nil when updatedAt is absent and present when it is there")
    func updatedText() {
        let capabilities = ItemFixtures.Persona.owner.capabilities
        #expect(makeSUT(ItemFixtures.item(updatedAt: nil), capabilities: capabilities).updatedText == nil)
        #expect(makeSUT(ItemFixtures.item(updatedAt: ItemFixtures.updatedDate), capabilities: capabilities).updatedText != nil)
    }

    @Test("Purchases absent with gift activity gives an empty purchase list")
    func purchasesAbsentGivesEmpty() {
        let sut = makeSUT(ItemFixtures.item(purchases: nil), capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.purchases.isEmpty)
    }

    // MARK: - Edit and delete controls

    // I5b Story C: showsEdit == item.canEdit and showsDelete == item.canDelete, nothing else.
    // Removed (derivation from list capabilities, createdBy and the current user): editDeleteRegularItem,
    // editDeleteMemberOffListItem, ownerNoEditOnMemberOffListItem, nilUserOffListItem. They are
    // replaced by the flag-driven tests below (editDeleteFollowTheItemFlags, handoffCases,
    // listCapabilitiesAndUserDoNotChangeTheFlags, flagsIgnoreOffListCreatorPurchasesAndListStatus).

    @Test("Edit and delete follow the item's two flags exactly",
          arguments: [(true, true), (true, false), (false, true), (false, false)])
    func editDeleteFollowTheItemFlags(canEdit: Bool, canDelete: Bool) {
        let item = ItemFixtures.item(canEdit: canEdit, canDelete: canDelete)
        for persona in ItemFixtures.Persona.allCases {
            let sut = makeSUT(item, capabilities: persona.capabilities)
            #expect(sut.showsEdit == canEdit, "\(persona) edit")
            #expect(sut.showsDelete == canDelete, "\(persona) delete")
        }
    }

    /// The API-handoff cases, expressed as the flag values the server sends for each caller.
    nonisolated struct HandoffCase: Sendable, CustomTestStringConvertible {
        let name: String
        let persona: ItemFixtures.Persona
        let offList: Bool
        let withPurchases: Bool
        let canEdit: Bool
        let canDelete: Bool
        var testDescription: String { name }
    }

    nonisolated static let handoffScenarios: [HandoffCase] = [
        HandoffCase(name: "owner, regular item", persona: .owner, offList: false,
                    withPurchases: false, canEdit: true, canDelete: true),
        HandoffCase(name: "co-owner, regular item", persona: .coOwner, offList: false,
                    withPurchases: false, canEdit: true, canDelete: true),
        HandoffCase(name: "creator of an off-list item", persona: .member, offList: true,
                    withPurchases: false, canEdit: true, canDelete: true),
        HandoffCase(name: "member, normal item", persona: .member, offList: false,
                    withPurchases: false, canEdit: false, canDelete: false),
        HandoffCase(name: "non-blind caller, item with purchases (edit yes, delete no)", persona: .owner,
                    offList: false, withPurchases: true, canEdit: true, canDelete: false),
        HandoffCase(name: "blind caller, item with purchases (both yes)", persona: .blindOwner,
                    offList: false, withPurchases: true, canEdit: true, canDelete: true)
    ]

    @Test("The API-handoff cases show Edit and Delete exactly as the item flags say", arguments: handoffScenarios)
    func handoffCases(_ scenario: HandoffCase) {
        let purchases = scenario.withPurchases ? [ItemFixtures.purchase()] : nil
        let item = ItemFixtures.item(
            offList: scenario.offList, canEdit: scenario.canEdit, canDelete: scenario.canDelete,
            purchases: purchases, totalQuantityPurchased: scenario.withPurchases ? 1 : nil
        )
        let sut = makeSUT(item, capabilities: scenario.persona.capabilities)
        #expect(sut.showsEdit == scenario.canEdit)
        #expect(sut.showsDelete == scenario.canDelete)
    }

    @Test("Edit hidden when canEdit is false and Delete hidden when canDelete is false, both shown when both true")
    func hiddenAndShown() {
        let capabilities = ItemFixtures.Persona.owner.capabilities
        let noEdit = makeSUT(ItemFixtures.item(canEdit: false, canDelete: true), capabilities: capabilities)
        #expect(!noEdit.showsEdit)
        #expect(noEdit.showsDelete)
        let noDelete = makeSUT(ItemFixtures.item(canEdit: true, canDelete: false), capabilities: capabilities)
        #expect(noDelete.showsEdit)
        #expect(!noDelete.showsDelete)
        let both = makeSUT(ItemFixtures.item(canEdit: true, canDelete: true), capabilities: capabilities)
        #expect(both.showsEdit)
        #expect(both.showsDelete)
    }

    @Test("Changing the list capabilities or the current user alone never changes showsEdit or showsDelete",
          arguments: [(true, true), (true, false), (false, true), (false, false)])
    func listCapabilitiesAndUserDoNotChangeTheFlags(canEdit: Bool, canDelete: Bool) {
        let item = ItemFixtures.item(
            offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.currentUserId),
            canEdit: canEdit, canDelete: canDelete
        )
        let users: [String?] = [ItemFixtures.currentUserId, ItemFixtures.otherUserId, nil]
        for persona in ItemFixtures.Persona.allCases {
            for user in users {
                let sut = makeSUT(item, capabilities: persona.capabilities, currentUserId: user)
                #expect(sut.showsEdit == canEdit, "\(persona) \(String(describing: user))")
                #expect(sut.showsDelete == canDelete, "\(persona) \(String(describing: user))")
            }
        }
    }

    @Test("The flags ignore offList, createdBy, purchases and the list status")
    func flagsIgnoreOffListCreatorPurchasesAndListStatus() {
        let flagPairs = [(true, true), (true, false), (false, true), (false, false)]
        for (canEdit, canDelete) in flagPairs {
            for offList in [false, true] {
                for creator in [ItemFixtures.currentUserId, ItemFixtures.otherUserId] {
                    for withPurchases in [false, true] {
                        let item = ItemFixtures.item(
                            offList: offList, createdBy: ItemFixtures.person(id: creator),
                            canEdit: canEdit, canDelete: canDelete,
                            purchases: withPurchases ? [ItemFixtures.purchase()] : nil,
                            totalQuantityPurchased: withPurchases ? 1 : nil
                        )
                        for persona in ItemFixtures.Persona.allCases {
                            let active = makeSUT(item, capabilities: persona.capabilities)
                            let archived = makeSUT(item, capabilities: persona.archivedCapabilities)
                            #expect(active.showsEdit == canEdit)
                            #expect(active.showsDelete == canDelete)
                            #expect(archived.showsEdit == canEdit)
                            #expect(archived.showsDelete == canDelete)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Purchase entry

    @Test("The purchase entry is the canPurchase flag exactly", arguments: [true, false])
    func purchaseEntryIsTheFlag(canPurchase: Bool) {
        for canSeeGiftActivity in [true, false] {
            for canCreateItem in [true, false] {
                let capabilities = ItemFixtures.capabilities(
                    canCreateItem: canCreateItem, canSeeGiftActivity: canSeeGiftActivity, canPurchase: canPurchase
                )
                let sut = makeSUT(richItem, capabilities: capabilities)
                #expect(sut.showsPurchaseEntry == canPurchase)
            }
        }
    }

    @Test("Purchase entry per persona")
    func purchaseEntryPerPersona() {
        let expected: [ItemFixtures.Persona: Bool] = [
            .owner: true, .blindOwner: false, .coOwner: true, .blindCoOwner: false,
            .member: true, .viewer: false, .publicNonMember: false
        ]
        for persona in ItemFixtures.Persona.allCases {
            let sut = makeSUT(richItem, capabilities: persona.capabilities)
            #expect(sut.showsPurchaseEntry == expected[persona], "\(persona)")
        }
    }

    // MARK: - Off-list badge

    @Test("The off-list badge shows for an off-list item only when canSeeOffList is true")
    func offListBadge() {
        let surprise = ItemFixtures.item(offList: true)
        #expect(makeSUT(surprise, capabilities: ItemFixtures.Persona.member.capabilities).showsOffListBadge)
        #expect(!makeSUT(surprise, capabilities: ItemFixtures.Persona.viewer.capabilities).showsOffListBadge)
        #expect(!makeSUT(ItemFixtures.item(offList: false), capabilities: ItemFixtures.Persona.member.capabilities).showsOffListBadge)
    }

    // MARK: - Archived list

    @Test("An archived list yields exactly the same detail state as an active one for the same item flags",
          arguments: ItemFixtures.Persona.allCases)
    func archivedMatchesActive(persona: ItemFixtures.Persona) {
        let ownOffList = ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.currentUserId))
        for item in [richItem, ownOffList] {
            let active = makeSUT(item, capabilities: persona.capabilities)
            let archived = makeSUT(item, capabilities: persona.archivedCapabilities)
            #expect(active == archived, "\(persona)")
        }
    }

    // MARK: - Currency

    @Test("The currency code is applied to the price and purchase totals")
    func currencyCode() {
        let sut = makeSUT(richItem, capabilities: ItemFixtures.Persona.owner.capabilities, currencyCode: "EUR")
        #expect(sut.priceText?.contains("19.99") == true)
        #expect(sut.priceText?.contains("$") == false)
        #expect(sut.purchases.first?.totalCostText.contains("$") == false)
    }
}
