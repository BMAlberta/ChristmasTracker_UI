//
//  ItemPermissionsTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B, narrowed by I5b Story C: the pure function that maps the list's capability
//  flags to the display outputs (canAddItem, showsOffListNotice, visibleItems,
//  canSeeGiftActivity, canSeeOffListItems, canPurchase).
//
//  Edit and delete rights are no longer derived here: the server sends canEdit and canDelete
//  on every item. Those are pinned by ItemDetailStateTests (showsEdit and showsDelete read the
//  item's flags), ItemFlagMappingTests and MockItemRepositoryTests.
//
//  Removed in I5b Story C (equivalent coverage in the files named above):
//  fullTruthTable, nilCurrentUserIdNeverMatches, nilCurrentUserIdRegularItem, memberRights,
//  ownersCannotTouchMemberOffListItems. Rewritten: personasOnActiveAndArchivedLists (edit and
//  delete assertions dropped, the rest kept); the Expectation edit fields and the Creator
//  oracle were removed with them.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item permissions Tests")
struct ItemPermissionsTests {

    // MARK: - Factory

    private func makeSUT(
        _ capabilities: ListCapabilities,
        currentUserId: String? = ItemFixtures.currentUserId
    ) -> ItemPermissions {
        ItemPermissions(capabilities: capabilities, currentUserId: currentUserId)
    }

    // MARK: - Display outputs

    @Test("Display outputs are the flags and nothing else, over every combination",
          arguments: 0..<32)
    func displayOutputsAreTheFlags(bits: Int) {
        let canCreateItem = bits & 1 != 0
        let canAddOffList = bits & 2 != 0
        let canSeeGiftActivity = bits & 4 != 0
        let canSeeOffList = bits & 8 != 0
        let canPurchase = bits & 16 != 0
        let sut = makeSUT(ItemFixtures.capabilities(
            canCreateItem: canCreateItem,
            canAddOffList: canAddOffList,
            canSeeGiftActivity: canSeeGiftActivity,
            canSeeOffList: canSeeOffList,
            canPurchase: canPurchase
        ))
        #expect(sut.canAddItem == canCreateItem)
        #expect(sut.canSeeGiftActivity == canSeeGiftActivity)
        #expect(sut.canSeeOffListItems == canSeeOffList)
        #expect(sut.canPurchase == canPurchase)
        #expect(sut.showsOffListNotice == canAddOffList)
    }

    @Test("canPurchase is the flag exactly, whatever the other flags and the user say")
    func canPurchaseIsTheFlagOnly() {
        for canPurchase in [false, true] {
            for other in [false, true] {
                let capabilities = ItemFixtures.capabilities(
                    canCreateItem: other, canAddOffList: other,
                    canSeeGiftActivity: other, canSeeOffList: other, canPurchase: canPurchase
                )
                #expect(makeSUT(capabilities).canPurchase == canPurchase)
                #expect(makeSUT(capabilities, currentUserId: nil).canPurchase == canPurchase)
            }
        }
    }

    // MARK: - visibleItems

    @Test("visibleItems drops off-list items when canSeeOffList is false and keeps the order")
    func visibleItemsFiltersOffList() {
        let items = [
            ItemFixtures.item(id: "a", offList: false),
            ItemFixtures.item(id: "b", offList: true),
            ItemFixtures.item(id: "c", offList: false),
            ItemFixtures.item(id: "d", offList: true)
        ]
        let hidden = makeSUT(ItemFixtures.capabilities(canSeeOffList: false))
        #expect(hidden.visibleItems(items).map(\.id) == ["a", "c"])
    }

    @Test("visibleItems keeps every item in the given order when canSeeOffList is true")
    func visibleItemsKeepsAllWhenAllowed() {
        let items = [
            ItemFixtures.item(id: "z", offList: true),
            ItemFixtures.item(id: "a", offList: false),
            ItemFixtures.item(id: "m", offList: true)
        ]
        let shown = makeSUT(ItemFixtures.capabilities(canSeeOffList: true))
        #expect(shown.visibleItems(items).map(\.id) == ["z", "a", "m"])
    }

    @Test("visibleItems of an empty list is empty and of only off-list items (hidden) is empty")
    func visibleItemsEdgeCases() {
        let hidden = makeSUT(ItemFixtures.capabilities(canSeeOffList: false))
        #expect(hidden.visibleItems([]).isEmpty)
        #expect(hidden.visibleItems([ItemFixtures.item(offList: true)]).isEmpty)
    }

    // MARK: - Named personas, active and archived

    private struct Expectation {
        let canAddItem: Bool
        let canSeeGiftActivity: Bool
        let canSeeOffListItems: Bool
        let canPurchase: Bool
        let showsOffListNotice: Bool
    }

    private func expectation(for persona: ItemFixtures.Persona) -> Expectation {
        switch persona {
        case .owner, .coOwner:
            return Expectation(canAddItem: true, canSeeGiftActivity: true, canSeeOffListItems: true,
                               canPurchase: true, showsOffListNotice: false)
        case .blindOwner, .blindCoOwner:
            return Expectation(canAddItem: true, canSeeGiftActivity: false, canSeeOffListItems: false,
                               canPurchase: false, showsOffListNotice: false)
        case .member:
            return Expectation(canAddItem: true, canSeeGiftActivity: true, canSeeOffListItems: true,
                               canPurchase: true, showsOffListNotice: true)
        case .viewer, .publicNonMember:
            return Expectation(canAddItem: false, canSeeGiftActivity: false, canSeeOffListItems: false,
                               canPurchase: false, showsOffListNotice: false)
        }
    }

    @Test("Named personas get the documented display rules on an active and an archived list",
          arguments: ItemFixtures.Persona.allCases)
    func personasOnActiveAndArchivedLists(persona: ItemFixtures.Persona) {
        let expected = expectation(for: persona)

        let active = makeSUT(persona.capabilities)
        let archived = makeSUT(persona.archivedCapabilities)
        for (label, sut) in [("active", active), ("archived", archived)] {
            #expect(sut.canAddItem == expected.canAddItem, "\(persona) \(label) canAddItem")
            #expect(sut.canSeeGiftActivity == expected.canSeeGiftActivity, "\(persona) \(label) gift")
            #expect(sut.canSeeOffListItems == expected.canSeeOffListItems, "\(persona) \(label) seeOff")
            #expect(sut.canPurchase == expected.canPurchase, "\(persona) \(label) canPurchase")
            #expect(sut.showsOffListNotice == expected.showsOffListNotice, "\(persona) \(label) notice")
        }
        #expect(active == archived, "\(persona): the list status is not an input")
    }

    @Test("Personas see off-list items in visibleItems exactly as their flag says",
          arguments: ItemFixtures.Persona.allCases)
    func personaVisibleItems(persona: ItemFixtures.Persona) {
        let items = [
            ItemFixtures.item(id: "regular", offList: false),
            ItemFixtures.item(id: "surprise", offList: true)
        ]
        let sut = makeSUT(persona.capabilities)
        let expected = persona.flags.canSeeOffList ? ["regular", "surprise"] : ["regular"]
        #expect(sut.visibleItems(items).map(\.id) == expected)
    }

    @Test("ItemPermissions is Equatable on its inputs")
    func equatable() {
        let owner = ItemFixtures.Persona.owner.capabilities
        #expect(makeSUT(owner) == makeSUT(owner))
        #expect(makeSUT(owner) != makeSUT(ItemFixtures.Persona.member.capabilities))
        #expect(makeSUT(owner, currentUserId: "user-1") != makeSUT(owner, currentUserId: "user-9"))
    }
}
