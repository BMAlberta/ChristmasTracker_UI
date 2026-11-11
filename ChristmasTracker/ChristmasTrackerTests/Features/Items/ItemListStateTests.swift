//
//  ItemListStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: the pure view state of the item list inside the list detail (sections,
//  add button, empty copy) for every persona. Views are not unit-tested; this is their oracle.
//
//  Privacy rule under test: when canSeeGiftActivity is false (blind owner, blind co-owner,
//  VIEWER-role member, PUBLIC non-member) the list is ONE "Items" section with no status
//  marker, no completion state and no off-list section; the empty copy hints at nothing.
//
//  Fails today because ItemListState, ItemSectionKind and ItemSectionState do not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item list state Tests")
struct ItemListStateTests {

    // MARK: - Factory

    private func makeSUT(
        items: [ListItem],
        capabilities: ListCapabilities,
        currentUserId: String? = ItemFixtures.currentUserId,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) -> ItemListState {
        ItemListState(items: items, capabilities: capabilities, currentUserId: currentUserId,
                      currencyCode: currencyCode, locale: locale)
    }

    /// A mixed bag in an interleaved order, so grouping and order preservation are both visible.
    private var mixedItems: [ListItem] {
        [
            ItemFixtures.item(id: "available-1", status: .available),
            ItemFixtures.item(id: "purchased-1", status: .purchased),
            ItemFixtures.item(id: "surprise-1", status: .available, offList: true),
            ItemFixtures.item(id: "partial-1", status: .partial),
            ItemFixtures.item(id: "wrapped-1", status: .wrapped),
            ItemFixtures.item(id: "surprise-2", status: .purchased, offList: true),
            ItemFixtures.item(id: "gifted-1", status: .gifted),
            ItemFixtures.item(id: "available-2", status: .available)
        ]
    }

    private func rowIds(_ section: ItemSectionState) -> [String] { section.rows.map(\.id) }

    // MARK: - Sections with gift activity

    @Test("Owner: Available, Purchased and Off-List sections, off-list items not repeated, order kept")
    func ownerSections() {
        let sut = makeSUT(items: mixedItems, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.sections.map(\.kind) == [.available, .purchased, .offList])
        #expect(sut.sections.map(\.title) == ["Available", "Purchased", "Off-List"])
        #expect(rowIds(sut.sections[0]) == ["available-1", "partial-1", "available-2"])
        #expect(rowIds(sut.sections[1]) == ["purchased-1", "wrapped-1", "gifted-1"])
        #expect(rowIds(sut.sections[2]) == ["surprise-1", "surprise-2"])
        #expect(sut.showsAddButton == true)
        #expect(sut.isEmpty == false)
    }

    @Test("Member: same three sections, add button shown")
    func memberSections() {
        let sut = makeSUT(items: mixedItems, capabilities: ItemFixtures.Persona.member.capabilities)
        #expect(sut.sections.map(\.kind) == [.available, .purchased, .offList])
        #expect(sut.showsAddButton == true)
    }

    @Test("Empty sections are omitted")
    func emptySectionsOmitted() {
        let items = [ItemFixtures.item(id: "only", status: .purchased)]
        let sut = makeSUT(items: items, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.sections.map(\.kind) == [.purchased])
        #expect(rowIds(sut.sections[0]) == ["only"])
    }

    @Test("No Off-List section when no off-list item exists")
    func noOffListSectionWithoutOffListItems() {
        let items = [ItemFixtures.item(id: "a", status: .available), ItemFixtures.item(id: "b", status: .gifted)]
        let sut = makeSUT(items: items, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(sut.sections.map(\.kind) == [.available, .purchased])
    }

    @Test("With gift activity but without canSeeOffList, off-list items are filtered defensively everywhere")
    func offListFilteredWhenNotAllowed() {
        let capabilities = ItemFixtures.capabilities(canCreateItem: true, canSeeGiftActivity: true, canSeeOffList: false)
        let sut = makeSUT(items: mixedItems, capabilities: capabilities)
        #expect(sut.sections.map(\.kind) == [.available, .purchased])
        let allIds = sut.sections.flatMap(\.rows).map(\.id)
        #expect(!allIds.contains("surprise-1"))
        #expect(!allIds.contains("surprise-2"))
        #expect(allIds.count == 6)
    }

    // MARK: - Sections without gift activity

    @Test("Without gift activity there is one Items section in the given order, no off-list section",
          arguments: [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember])
    func blindViewerSections(persona: ItemFixtures.Persona) {
        let sut = makeSUT(items: mixedItems, capabilities: persona.capabilities)
        #expect(sut.sections.count == 1)
        #expect(sut.sections.first?.kind == .all)
        #expect(sut.sections.first?.title == "Items")
        // None of the personas sees off-list items, so they are dropped; the rest keeps its order.
        #expect(sut.sections.first.map(rowIds) == [
            "available-1", "purchased-1", "partial-1", "wrapped-1", "gifted-1", "available-2"
        ])
    }

    @Test("Without gift activity every row is a plain available entry, even for a purchased item",
          arguments: [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember])
    func blindViewerRowsShowNoStatus(persona: ItemFixtures.Persona) {
        let sut = makeSUT(items: mixedItems, capabilities: persona.capabilities)
        let rows = sut.sections.flatMap(\.rows)
        #expect(!rows.isEmpty)
        for row in rows {
            #expect(row.statusMarker == nil, "\(persona) \(row.id) marker")
            #expect(row.isCompleted == false, "\(persona) \(row.id) completed")
            #expect(row.showsOffListBadge == false, "\(persona) \(row.id) badge")
        }
    }

    @Test("Gift activity false with canSeeOffList true: one Items section, off-list items inline with a badge, no marker")
    func noGiftActivityButOffListAllowed() {
        let capabilities = ItemFixtures.capabilities(canCreateItem: true, canAddOffList: true,
                                                     canSeeGiftActivity: false, canSeeOffList: true)
        let items = [
            ItemFixtures.item(id: "regular", status: .purchased),
            ItemFixtures.item(id: "surprise", status: .purchased, offList: true)
        ]
        let sut = makeSUT(items: items, capabilities: capabilities)
        #expect(sut.sections.map(\.kind) == [.all])
        let rows = sut.sections.flatMap(\.rows)
        #expect(rows.map(\.id) == ["regular", "surprise"])
        #expect(rows.allSatisfy { $0.statusMarker == nil && $0.isCompleted == false })
        #expect(rows[0].showsOffListBadge == false)
        #expect(rows[1].showsOffListBadge == true)
    }

    // MARK: - Add button

    @Test("The add button follows canCreateItem only", arguments: [true, false])
    func addButtonFollowsFlag(canCreateItem: Bool) {
        let capabilities = ItemFixtures.capabilities(canCreateItem: canCreateItem, canAddOffList: !canCreateItem)
        #expect(makeSUT(items: [], capabilities: capabilities).showsAddButton == canCreateItem)
    }

    @Test("Add button per persona")
    func addButtonPerPersona() {
        let expected: [ItemFixtures.Persona: Bool] = [
            .owner: true, .blindOwner: true, .coOwner: true, .blindCoOwner: true,
            .member: true, .viewer: false, .publicNonMember: false
        ]
        for persona in ItemFixtures.Persona.allCases {
            let sut = makeSUT(items: [], capabilities: persona.capabilities)
            #expect(sut.showsAddButton == expected[persona], "\(persona)")
        }
    }

    // MARK: - Empty state

    @Test("An empty list is empty with the generic copy and no sections")
    func emptyCopy() {
        let sut = makeSUT(items: [], capabilities: ItemFixtures.Persona.viewer.capabilities)
        #expect(sut.isEmpty)
        #expect(sut.sections.isEmpty)
        #expect(sut.emptyTitle == "No items yet")
        #expect(sut.emptyMessage == "Items added to this list will appear here.")
    }

    @Test("The add hint is appended only when the add button is shown")
    func emptyCopyAddHint() {
        let withAdd = makeSUT(items: [], capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(withAdd.emptyTitle == "No items yet")
        #expect(withAdd.emptyMessage.hasPrefix("Items added to this list will appear here."))
        #expect(withAdd.emptyMessage.contains("Tap Add Item to add the first one."))

        let withoutAdd = makeSUT(items: [], capabilities: ItemFixtures.Persona.publicNonMember.capabilities)
        #expect(withoutAdd.emptyMessage == "Items added to this list will appear here.")
        #expect(!withoutAdd.emptyMessage.contains("Tap Add Item"))
    }

    @Test("Hidden off-list items leave the list empty with copy identical to a really empty list")
    func hiddenItemsHintAtNothing() {
        for persona in [ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember] {
            let onlyHidden = makeSUT(
                items: [ItemFixtures.item(id: "s1", offList: true), ItemFixtures.item(id: "s2", offList: true)],
                capabilities: persona.capabilities
            )
            let reallyEmpty = makeSUT(items: [], capabilities: persona.capabilities)
            #expect(onlyHidden.isEmpty, "\(persona)")
            #expect(onlyHidden.sections.isEmpty, "\(persona)")
            #expect(onlyHidden.emptyTitle == reallyEmpty.emptyTitle, "\(persona)")
            #expect(onlyHidden.emptyMessage == reallyEmpty.emptyMessage, "\(persona)")
        }
    }

    @Test("Empty copy is the same for blind owner, viewer and public apart from the add hint")
    func emptyCopyUniform() {
        let viewer = makeSUT(items: [], capabilities: ItemFixtures.Persona.viewer.capabilities)
        let publicViewer = makeSUT(items: [], capabilities: ItemFixtures.Persona.publicNonMember.capabilities)
        #expect(viewer.emptyTitle == publicViewer.emptyTitle)
        #expect(viewer.emptyMessage == publicViewer.emptyMessage)
        let blindOwner = makeSUT(items: [], capabilities: ItemFixtures.Persona.blindOwner.capabilities)
        #expect(blindOwner.emptyTitle == viewer.emptyTitle)
        #expect(blindOwner.emptyMessage.hasPrefix(viewer.emptyMessage))
        for text in [blindOwner.emptyTitle, blindOwner.emptyMessage, viewer.emptyMessage] {
            let lowered = text.lowercased()
            for word in ["hidden", "private", "surprise", "purchase", "gift", "status"] {
                #expect(!lowered.contains(word), "empty copy hints at hidden state: \(word)")
            }
        }
    }

    // MARK: - Currency

    @Test("The currency code and locale are passed through to the rows")
    func currencyPassThrough() {
        let items = [ItemFixtures.item(id: "priced", price: ItemFixtures.decimal("19.99"))]
        let usd = makeSUT(items: items, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(usd.sections.flatMap(\.rows).first?.priceText == "$19.99")
        let euro = makeSUT(items: items, capabilities: ItemFixtures.Persona.owner.capabilities,
                           currencyCode: "EUR", locale: Locale(identifier: "en_US"))
        #expect(euro.sections.flatMap(\.rows).first?.priceText?.contains("19.99") == true)
        #expect(euro.sections.flatMap(\.rows).first?.priceText?.contains("$") == false)
    }

    // MARK: - Archived list

    @Test("An archived list yields exactly the same state as an active one for the same item flags",
          arguments: ItemFixtures.Persona.allCases)
    func archivedMatchesActive(persona: ItemFixtures.Persona) {
        let active = makeSUT(items: mixedItems, capabilities: persona.capabilities)
        let archived = makeSUT(items: mixedItems, capabilities: persona.archivedCapabilities)
        #expect(active == archived)
    }

    // MARK: - Equatable

    @Test("Equal inputs give equal states and a different persona gives a different state")
    func equatable() {
        let owner = makeSUT(items: mixedItems, capabilities: ItemFixtures.Persona.owner.capabilities)
        #expect(owner == makeSUT(items: mixedItems, capabilities: ItemFixtures.Persona.owner.capabilities))
        #expect(owner != makeSUT(items: mixedItems, capabilities: ItemFixtures.Persona.viewer.capabilities))
    }
}
