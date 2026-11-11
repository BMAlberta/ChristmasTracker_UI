//
//  MockItemRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: MockItemRepository mirrors the server's privacy rules for the capability flags
//  returned for the list (Docs/privacy-matrix.md item rows, client guide 6.2 to 6.4):
//
//    fetch: no canSeeGiftActivity -> every item AVAILABLE, updatedAt / purchases /
//           totalQuantityPurchased nil; no canSeeOffList -> off-list items omitted.
//    create: !canCreateItem -> .forbidden; otherwise offList = canAddOffList (the input has no
//           offList), with the same hiding applied to the result.
//    update / delete: a regular item needs canCreateItem && !canAddOffList; an off-list item needs
//           its creator to be the mock's current user; otherwise .forbidden; unknown id .notFound.
//
//  The tests derive the behavior from FLAGS (named personas are bundles of flags), never a role.
//  The Gate 1 addendum fixes no seed content, so tests that need a seeded item discover it
//  through the public API (ItemMockSupport.seededItems) and #require the shape they need.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("MockItemRepository", .timeLimit(.minutes(1)))
@MainActor
struct MockItemRepositoryTests {

    private let listId = "list-test"

    private func input(name: String = "Fake Lamp") -> CreateItemInput {
        CreateItemInput(
            name: name, description: "A fake lamp", url: "https://example.com/lamp",
            imageUrl: "https://example.com/lamp.png", expectedUnitPrice: ItemFixtures.decimal("19.99"),
            quantityRequested: 2, priority: 7
        )
    }

    // MARK: - Default init

    @Test("MockItemRepository() still works: owner flags, the default user, a regular available item")
    func defaultInitStillWorks() async throws {
        let repo = MockItemRepository()
        await repo.setDelay(0)

        let created = try await repo.createItem(listId: listId, input())

        #expect(created.offList == false)
        #expect(created.createdBy == MockItemRepository.defaultUser)
        #expect(created.listId == listId)
        let fetched = try await repo.fetchItems(listId: listId)
        #expect(fetched.map(\.id).contains(created.id))
    }

    // MARK: - Create applies the input and derives offList from the flags

    @Test("createItem keeps every supplied field and starts available, created by the current user")
    func createKeepsInput() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)

        let created = try await repo.createItem(listId: listId, input(name: "Keep Me"))

        #expect(created.name == "Keep Me")
        #expect(created.description == "A fake lamp")
        #expect(created.url == "https://example.com/lamp")
        #expect(created.imageUrl == "https://example.com/lamp.png")
        #expect(created.expectedUnitPrice == ItemFixtures.decimal("19.99"))
        #expect(created.quantityRequested == 2)
        #expect(created.priority == 7)
        #expect(created.status == .available)
        #expect(created.createdBy == ItemMockSupport.me)
        #expect(!created.id.isEmpty)
    }

    @Test("createItem derives offList from canAddOffList (the input has no offList)", arguments: [false, true])
    func createDerivesOffList(canAddOffList: Bool) async throws {
        let caps = ItemFixtures.capabilities(
            canCreateItem: true, canAddOffList: canAddOffList, canSeeGiftActivity: true, canSeeOffList: true
        )
        let repo = await ItemMockSupport.makeMock(caps)

        let created = try await repo.createItem(listId: listId, input())

        #expect(created.offList == canAddOffList)
    }

    @Test("createItem returns distinct ids")
    func createReturnsDistinctIds() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)

        let first = try await repo.createItem(listId: listId, input())
        let second = try await repo.createItem(listId: listId, input())

        #expect(first.id != second.id)
    }

    @Test("a created item is returned by fetchItems for its own list only")
    func createdItemScopedToList() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)

        let created = try await repo.createItem(listId: "list-a", input())

        let inA = try await repo.fetchItems(listId: "list-a")
        let inB = try await repo.fetchItems(listId: "list-b")
        #expect(inA.map(\.id).contains(created.id))
        #expect(!inB.map(\.id).contains(created.id))
    }

    // MARK: - Blind owner: hiding

    @Test("blind owner: a created item shows available, no updatedAt, no purchases, in the list and the detail")
    func blindOwnerHidesGiftActivity() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.blindOwner.capabilities)

        let created = try await repo.createItem(listId: listId, input())
        let listed = try #require(try await repo.fetchItems(listId: listId).first { $0.id == created.id })
        let detail = try await repo.fetchItemDetail(id: created.id)

        #expect(created.offList == false)
        for item in [created, listed, detail] {
            #expect(item.status == .available)
            #expect(item.updatedAt == nil, "a blind viewer never receives updatedAt")
            #expect(item.purchases == nil)
            #expect(item.totalQuantityPurchased == nil)
        }
    }

    @Test("blind owner: update returns the item with the hiding applied")
    func blindOwnerUpdateHides() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.blindOwner.capabilities)
        let created = try await repo.createItem(listId: listId, input())

        let updated = try await repo.updateItem(id: created.id, UpdateItemInput(name: "Renamed"))

        #expect(updated.name == "Renamed")
        #expect(updated.status == .available)
        #expect(updated.updatedAt == nil)
        #expect(updated.purchases == nil)
    }

    // MARK: - Owner / co-owner

    @Test("owner and co-owner (blind or not) create regular items", arguments: [
        ItemFixtures.Persona.owner, .blindOwner, .coOwner, .blindCoOwner
    ])
    func ownersCreateRegularItems(persona: ItemFixtures.Persona) async throws {
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        let created = try await repo.createItem(listId: listId, input())

        #expect(created.offList == false)
    }

    @Test("owner and co-owner (blind or not) can edit and delete a regular item", arguments: [
        ItemFixtures.Persona.owner, .blindOwner, .coOwner, .blindCoOwner
    ])
    func ownersEditAndDeleteRegularItems(persona: ItemFixtures.Persona) async throws {
        let repo = await ItemMockSupport.makeMock(persona.capabilities)
        let created = try await repo.createItem(listId: listId, input())

        let updated = try await repo.updateItem(id: created.id, UpdateItemInput(name: "Renamed"))
        try await repo.deleteItem(id: created.id)

        #expect(updated.name == "Renamed")
        let remaining = try await repo.fetchItems(listId: listId)
        #expect(!remaining.map(\.id).contains(created.id))
    }

    @Test("updateItem changes only the supplied fields and keeps identity")
    func updateChangesOnlySuppliedFields() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)
        let created = try await repo.createItem(listId: listId, input())

        let updated = try await repo.updateItem(id: created.id, UpdateItemInput(name: "Renamed", priority: 3))

        #expect(updated.id == created.id)
        #expect(updated.listId == created.listId)
        #expect(updated.name == "Renamed")
        #expect(updated.priority == 3)
        #expect(updated.description == created.description)
        #expect(updated.url == created.url)
        #expect(updated.imageUrl == created.imageUrl)
        #expect(updated.expectedUnitPrice == created.expectedUnitPrice)
        #expect(updated.quantityRequested == created.quantityRequested)
        #expect(updated.offList == created.offList)
        #expect(updated.createdBy == created.createdBy)
        let fetched = try await repo.fetchItemDetail(id: created.id)
        #expect(fetched.name == "Renamed")
    }

    @Test("deleteItem removes the item: it disappears from the list and the detail is not found")
    func deleteRemovesItem() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)
        let created = try await repo.createItem(listId: listId, input())

        try await repo.deleteItem(id: created.id)

        let listed = try await repo.fetchItems(listId: listId)
        #expect(!listed.map(\.id).contains(created.id))
        await #expect(throws: ItemError.notFound) { _ = try await repo.fetchItemDetail(id: created.id) }
        await #expect(throws: ItemError.notFound) { try await repo.deleteItem(id: created.id) }
    }

    @Test("an unknown item id is notFound for detail, update and delete")
    func unknownIdIsNotFound() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)

        await #expect(throws: ItemError.notFound) { _ = try await repo.fetchItemDetail(id: "no-such-item") }
        await #expect(throws: ItemError.notFound) { _ = try await repo.updateItem(id: "no-such-item", UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.notFound) { try await repo.deleteItem(id: "no-such-item") }
    }

    // MARK: - MEMBER

    @Test("MEMBER: create makes an off-list item created by the current user, who can edit and delete it")
    func memberOwnOffListItem() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.member.capabilities)

        let created = try await repo.createItem(listId: listId, input())
        let updated = try await repo.updateItem(id: created.id, UpdateItemInput(name: "Renamed"))
        try await repo.deleteItem(id: created.id)

        #expect(created.offList == true)
        #expect(created.createdBy == ItemMockSupport.me)
        #expect(updated.name == "Renamed")
        let remaining = try await repo.fetchItems(listId: listId)
        #expect(!remaining.map(\.id).contains(created.id))
    }

    @Test("MEMBER sees their own off-list item in the list (canSeeOffList) with real status")
    func memberSeesOwnOffListItem() async throws {
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.member.capabilities)

        let created = try await repo.createItem(listId: listId, input())

        let listed = try #require(try await repo.fetchItems(listId: listId).first { $0.id == created.id })
        #expect(listed.offList == true)
    }

    @Test("MEMBER cannot edit or delete a regular item (403)")
    func memberCannotTouchRegularItem() async throws {
        let flags = CapabilitySwitch(ItemFixtures.Persona.owner.capabilities)
        let repo = await ItemMockSupport.makeMock(flags)
        let regular = try await repo.createItem(listId: listId, input())
        #expect(regular.offList == false, "precondition: created under owner flags")
        flags.current = ItemFixtures.Persona.member.capabilities

        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: regular.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: regular.id) }
        flags.current = ItemFixtures.Persona.owner.capabilities
        let still = try await repo.fetchItemDetail(id: regular.id)
        #expect(still.name == regular.name, "a refused update changes nothing")
    }

    @Test("MEMBER cannot edit or delete another user's off-list item (403)")
    func memberCannotTouchAnothersOffListItem() async throws {
        let seeded = try await ItemMockSupport.seededItems()
        let theirs = try #require(
            seeded.first { $0.offList && $0.createdBy.id != ItemMockSupport.me.id },
            "the mock must seed an off-list item created by someone else (privacy scenario: MEMBER, another's off-list item)"
        )
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.member.capabilities)

        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: theirs.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: theirs.id) }
    }

    @Test("owner and co-owner cannot edit or delete a MEMBER's off-list item (403)", arguments: [
        ItemFixtures.Persona.owner, .coOwner
    ])
    func ownersCannotTouchMembersOffListItem(persona: ItemFixtures.Persona) async throws {
        let seeded = try await ItemMockSupport.seededItems()
        let theirs = try #require(
            seeded.first { $0.offList && $0.createdBy.id != ItemMockSupport.me.id },
            "the mock must seed an off-list item created by someone else"
        )
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: theirs.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: theirs.id) }
    }

    // MARK: - VIEWER and PUBLIC non-member

    @Test("VIEWER-role member and PUBLIC non-member cannot create (403)", arguments: [
        ItemFixtures.Persona.viewer, .publicNonMember
    ])
    func readOnlyViewersCannotCreate(persona: ItemFixtures.Persona) async throws {
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        await #expect(throws: ItemError.forbidden) { _ = try await repo.createItem(listId: listId, input()) }
        let listed = try await repo.fetchItems(listId: listId)
        #expect(listed.isEmpty, "a refused create adds nothing")
    }

    @Test("VIEWER-role member and PUBLIC non-member cannot edit or delete a regular item (403)", arguments: [
        ItemFixtures.Persona.viewer, .publicNonMember
    ])
    func readOnlyViewersCannotEditOrDelete(persona: ItemFixtures.Persona) async throws {
        let flags = CapabilitySwitch(ItemFixtures.Persona.owner.capabilities)
        let repo = await ItemMockSupport.makeMock(flags)
        let regular = try await repo.createItem(listId: listId, input())
        flags.current = persona.capabilities

        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: regular.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: regular.id) }
    }

    // MARK: - Hiding on seeded data

    @Test("the seeded data exercises the hiding: some non-available status, some off-list item, some updatedAt")
    func seedExercisesHiding() async throws {
        let seeded = try await ItemMockSupport.seededItems()

        #expect(!seeded.isEmpty, "the mock must ship with items on the MockListData lists")
        #expect(seeded.contains { $0.status != .available }, "needed to prove status hiding")
        #expect(seeded.contains { $0.offList }, "needed to prove off-list hiding")
        #expect(seeded.contains { $0.updatedAt != nil }, "needed to prove updatedAt hiding")
    }

    @Test("no gift activity: every item is AVAILABLE with no updatedAt, purchases or purchased quantity", arguments: [
        ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember
    ])
    func noGiftActivityHidesEverything(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        var seen = 0
        for id in seededIds {
            let items = try await repo.fetchItems(listId: id)
            for item in items {
                seen += 1
                #expect(item.status == .available)
                #expect(item.updatedAt == nil)
                #expect(item.purchases == nil)
                #expect(item.totalQuantityPurchased == nil)
                let detail = try await repo.fetchItemDetail(id: item.id)
                #expect(detail.status == .available)
                #expect(detail.updatedAt == nil)
                #expect(detail.purchases == nil)
                #expect(detail.totalQuantityPurchased == nil)
            }
        }
        #expect(seen > 0, "the persona must see at least one seeded item or the test proves nothing")
    }

    @Test("no canSeeOffList: off-list items are omitted from the list", arguments: [
        ItemFixtures.Persona.blindOwner, .blindCoOwner, .viewer, .publicNonMember
    ])
    func noOffListVisibility(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let full = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)
        let restricted = await ItemMockSupport.makeMock(persona.capabilities)

        var sawOffListInFullView = false
        for id in seededIds {
            let all = try await full.fetchItems(listId: id)
            let visible = try await restricted.fetchItems(listId: id)
            sawOffListInFullView = sawOffListInFullView || all.contains { $0.offList }
            #expect(visible.allSatisfy { !$0.offList })
            #expect(visible.map(\.id) == all.filter { !$0.offList }.map(\.id), "only off-list items are dropped, order kept")
        }
        #expect(sawOffListInFullView, "the seed must hold an off-list item for this to prove anything")
    }

    // MARK: - Capabilities are asked per list

    @Test("the capabilities closure is asked for the list the call is about")
    func capabilitiesAreAskedPerList() async throws {
        let ownerCaps = ItemFixtures.Persona.owner.capabilities
        let viewerCaps = ItemFixtures.Persona.viewer.capabilities
        let repo = MockItemRepository(
            capabilities: { $0 == "list-viewer" ? viewerCaps : ownerCaps },
            currentUser: ItemMockSupport.me
        )
        await repo.setDelay(0)

        await #expect(throws: ItemError.forbidden) { _ = try await repo.createItem(listId: "list-viewer", input()) }
        let created = try await repo.createItem(listId: "list-owner", input())

        #expect(created.listId == "list-owner")
    }
}
