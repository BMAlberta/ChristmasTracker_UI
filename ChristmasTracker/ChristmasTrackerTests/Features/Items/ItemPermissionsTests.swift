//
//  ItemPermissionsTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the one pure function that decides item rights from the list's capability
//  flags, the item's offList and createdBy id, and the current user's id.
//
//  TRUTH-TABLE REDUCTION (stated here as the Gate 1 addendum requires):
//  The edit/delete result depends only on (canCreateItem, canAddOffList, item.offList,
//  creator relation). canSeeGiftActivity, canSeeOffList and canPurchase only drive the display
//  outputs (canSeeGiftActivity, canSeeOffListItems, canPurchase, visibleItems). So the table
//  enumerates all 2^4 combinations of (canCreateItem, canAddOffList, canSeeGiftActivity,
//  canSeeOffList) x offList {false, true} x creator relation {is the current user, is someone
//  else, current user id is nil} against an independent oracle written from
//  Docs/privacy-matrix.md (item rows), not from the production rule. canPurchase is
//  enumerated separately over both values in every combination. The named personas are then
//  checked as concrete fixtures on an ACTIVE and an ARCHIVED list, with identical results
//  (the list status is not an input).
//
//  Fails today because ItemPermissions and ListItem do not exist yet.
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

    private enum Creator: CaseIterable {
        case currentUser
        case someoneElse
        case currentUserIdIsNil

        var currentUserId: String? {
            self == .currentUserIdIsNil ? nil : ItemFixtures.currentUserId
        }

        var creatorId: String {
            self == .someoneElse ? ItemFixtures.otherUserId : ItemFixtures.currentUserId
        }
    }

    /// Independent oracle from the privacy matrix: the owner or co-owner (blind or not) edits
    /// and deletes regular items; a member edits and deletes only the off-list items they
    /// created; the owner, co-owner, viewers and PUBLIC non-members never touch a member's
    /// off-list item. In flag terms: canCreateItem without canAddOffList identifies the
    /// owner/co-owner write role, canAddOffList the member write role.
    private func oracle(canCreateItem: Bool, canAddOffList: Bool, offList: Bool, creator: Creator) -> Bool {
        if offList {
            return creator == .currentUser
        }
        return canCreateItem && !canAddOffList
    }

    // MARK: - Full truth table

    @Test("Edit and delete over every flag combination, offList and creator relation",
          arguments: 0..<16)
    func fullTruthTable(bits: Int) {
        let canCreateItem = bits & 1 != 0
        let canAddOffList = bits & 2 != 0
        let canSeeGiftActivity = bits & 4 != 0
        let canSeeOffList = bits & 8 != 0

        for offList in [false, true] {
            for creator in Creator.allCases {
                let capabilities = ItemFixtures.capabilities(
                    canCreateItem: canCreateItem,
                    canAddOffList: canAddOffList,
                    canSeeGiftActivity: canSeeGiftActivity,
                    canSeeOffList: canSeeOffList
                )
                let sut = makeSUT(capabilities, currentUserId: creator.currentUserId)
                let item = ItemFixtures.item(
                    offList: offList,
                    createdBy: ItemFixtures.person(id: creator.creatorId)
                )
                let expected = oracle(canCreateItem: canCreateItem, canAddOffList: canAddOffList,
                                      offList: offList, creator: creator)
                let context = "create=\(canCreateItem) addOff=\(canAddOffList) gift=\(canSeeGiftActivity) "
                    + "seeOff=\(canSeeOffList) offList=\(offList) creator=\(creator)"
                #expect(sut.canEdit(item) == expected, "canEdit: \(context)")
                #expect(sut.canDelete(item) == expected, "canDelete: \(context)")
            }
        }
    }

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

    @Test("A nil current user id never matches a creator, even an empty creator id")
    func nilCurrentUserIdNeverMatches() {
        let capabilities = ItemFixtures.capabilities(canCreateItem: true, canAddOffList: true)
        let sut = makeSUT(capabilities, currentUserId: nil)
        let own = ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.currentUserId))
        let empty = ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ""))
        #expect(!sut.canEdit(own))
        #expect(!sut.canDelete(own))
        #expect(!sut.canEdit(empty))
        #expect(!sut.canDelete(empty))
    }

    @Test("A nil current user id still lets the owner edit a regular item")
    func nilCurrentUserIdRegularItem() {
        let sut = makeSUT(ItemFixtures.Persona.owner.capabilities, currentUserId: nil)
        let regular = ItemFixtures.item(offList: false)
        #expect(sut.canEdit(regular))
        #expect(sut.canDelete(regular))
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
        let editsRegularItem: Bool
        let editsOwnOffListItem: Bool
        let editsOthersOffListItem: Bool
    }

    private func expectation(for persona: ItemFixtures.Persona) -> Expectation {
        switch persona {
        case .owner, .coOwner:
            return Expectation(canAddItem: true, canSeeGiftActivity: true, canSeeOffListItems: true,
                               canPurchase: true, showsOffListNotice: false,
                               editsRegularItem: true, editsOwnOffListItem: true, editsOthersOffListItem: false)
        case .blindOwner, .blindCoOwner:
            return Expectation(canAddItem: true, canSeeGiftActivity: false, canSeeOffListItems: false,
                               canPurchase: false, showsOffListNotice: false,
                               editsRegularItem: true, editsOwnOffListItem: true, editsOthersOffListItem: false)
        case .member:
            return Expectation(canAddItem: true, canSeeGiftActivity: true, canSeeOffListItems: true,
                               canPurchase: true, showsOffListNotice: true,
                               editsRegularItem: false, editsOwnOffListItem: true, editsOthersOffListItem: false)
        case .viewer, .publicNonMember:
            return Expectation(canAddItem: false, canSeeGiftActivity: false, canSeeOffListItems: false,
                               canPurchase: false, showsOffListNotice: false,
                               editsRegularItem: false, editsOwnOffListItem: true, editsOthersOffListItem: false)
        }
    }

    @Test("Named personas get the documented rights on an active and an archived list",
          arguments: ItemFixtures.Persona.allCases)
    func personasOnActiveAndArchivedLists(persona: ItemFixtures.Persona) {
        let expected = expectation(for: persona)
        let regular = ItemFixtures.item(id: "regular", offList: false)
        let ownOffList = ItemFixtures.item(
            id: "own", offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.currentUserId)
        )
        let othersOffList = ItemFixtures.item(
            id: "others", offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.otherUserId)
        )

        let active = makeSUT(persona.capabilities)
        let archived = makeSUT(persona.archivedCapabilities)
        for (label, sut) in [("active", active), ("archived", archived)] {
            #expect(sut.canAddItem == expected.canAddItem, "\(persona) \(label) canAddItem")
            #expect(sut.canSeeGiftActivity == expected.canSeeGiftActivity, "\(persona) \(label) gift")
            #expect(sut.canSeeOffListItems == expected.canSeeOffListItems, "\(persona) \(label) seeOff")
            #expect(sut.canPurchase == expected.canPurchase, "\(persona) \(label) canPurchase")
            #expect(sut.showsOffListNotice == expected.showsOffListNotice, "\(persona) \(label) notice")
            #expect(sut.canEdit(regular) == expected.editsRegularItem, "\(persona) \(label) edit regular")
            #expect(sut.canDelete(regular) == expected.editsRegularItem, "\(persona) \(label) delete regular")
            #expect(sut.canEdit(ownOffList) == expected.editsOwnOffListItem, "\(persona) \(label) edit own off-list")
            #expect(sut.canDelete(ownOffList) == expected.editsOwnOffListItem, "\(persona) \(label) delete own off-list")
            #expect(sut.canEdit(othersOffList) == expected.editsOthersOffListItem, "\(persona) \(label) edit other off-list")
            #expect(sut.canDelete(othersOffList) == expected.editsOthersOffListItem, "\(persona) \(label) delete other off-list")
        }
        #expect(active == archived, "\(persona): the list status is not an input")
    }

    @Test("A MEMBER cannot edit or delete a regular item, only their own off-list item")
    func memberRights() {
        let sut = makeSUT(ItemFixtures.Persona.member.capabilities)
        #expect(!sut.canEdit(ItemFixtures.item(offList: false)))
        #expect(sut.canEdit(ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.currentUserId))))
        #expect(!sut.canEdit(ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.otherUserId))))
    }

    @Test("The owner and co-owner (blind or not) get no rights over a member's off-list item")
    func ownersCannotTouchMemberOffListItems() {
        let memberItem = ItemFixtures.item(offList: true, createdBy: ItemFixtures.person(id: ItemFixtures.otherUserId))
        for persona in [ItemFixtures.Persona.owner, .blindOwner, .coOwner, .blindCoOwner] {
            let sut = makeSUT(persona.capabilities)
            #expect(!sut.canEdit(memberItem), "\(persona) edit")
            #expect(!sut.canDelete(memberItem), "\(persona) delete")
        }
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
