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
//    flags (I5b Story C): every item the mock returns carries canEdit and canDelete, produced by a
//           mock-only function that is consistent with the mock list's capabilities (owner and
//           co-owner: regular items; creator: their own off-list item). update / delete throw
//           .forbidden when the item's flag is false and succeed when it is true; unknown id
//           .notFound. The expected flag values below come from Docs/privacy-matrix.md, not from
//           any private name, and are read through the public repository API.
//
//  I5b Story C rewrites: memberCannotTouchRegularItem and readOnlyViewersCannotEditOrDelete no
//  longer flip the capabilities after creating the item (that pinned a derivation at call time);
//  they act on a seeded regular item under the persona's flags and assert the flag as well.
//  ownersEditAndDeleteRegularItems and memberOwnOffListItem gain flag assertions on the created
//  item. New: createdItemFlags, seededFlagsFollowTheMatrix, seededFlagsForTheCreator,
//  detailFlagsEqualListFlags, forbiddenExactlyWhenFlagIsFalse, updateAndDeleteSucceedWhenFlagIsTrue.
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
        #expect(created.canEdit && created.canDelete)
        #expect(updated.canEdit && updated.canDelete)
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
        #expect(created.canEdit && created.canDelete, "the creator may change their own off-list item")
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
        let seeded = try await ItemMockSupport.seededItems()
        let regular = try #require(seeded.first { !$0.offList }, "the mock must seed a regular item")
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.member.capabilities)

        let listed = try #require(try await repo.fetchItems(listId: regular.listId).first { $0.id == regular.id })
        #expect(!listed.canEdit)
        #expect(!listed.canDelete)
        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: regular.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: regular.id) }
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
        let seeded = try await ItemMockSupport.seededItems()
        let regular = try #require(seeded.first { !$0.offList }, "the mock must seed a regular item")
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        let detail = try await repo.fetchItemDetail(id: regular.id)
        #expect(!detail.canEdit, "\(persona)")
        #expect(!detail.canDelete, "\(persona)")
        await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: regular.id, UpdateItemInput(name: "X")) }
        await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: regular.id) }
    }

    // MARK: - Flags (I5b Story C)

    @Test("a created item carries flags consistent with the list capabilities: true for every creator",
          arguments: [ItemFixtures.Persona.owner, .blindOwner, .coOwner, .blindCoOwner, .member])
    func createdItemFlags(persona: ItemFixtures.Persona) async throws {
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        let created = try await repo.createItem(listId: listId, input())
        let listed = try #require(try await repo.fetchItems(listId: listId).first { $0.id == created.id })
        let detail = try await repo.fetchItemDetail(id: created.id)

        for item in [created, listed, detail] {
            #expect(item.canEdit, "\(persona)")
            #expect(item.canDelete, "\(persona)")
        }
    }

    @Test("seeded items carry the flags the matrix gives the persona (current user is not a seeded creator)",
          arguments: ItemFixtures.Persona.allCases)
    func seededFlagsFollowTheMatrix(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let purchased = try await purchasedSeededItemIds()
        let repo = await ItemMockSupport.makeMock(persona.capabilities)
        let flags = persona.flags
        // Owner and co-owner (blind or not) change regular items; nobody else does.
        let regularExpected = flags.canCreateItem && !flags.canAddOffList

        var seen = 0
        for id in seededIds {
            for item in try await repo.fetchItems(listId: id) {
                seen += 1
                // Off-list items seeded here are created by someone other than the test's user.
                let mayChange = item.offList ? false : regularExpected
                // P25: a caller who sees gift activity cannot delete an item that has purchases;
                // a blind caller's delete never depends on purchases; edit never does.
                let blockedByPurchases = flags.canSeeGiftActivity && purchased.contains(item.id)
                #expect(item.canEdit == mayChange, "\(persona) \(item.id) canEdit")
                #expect(item.canDelete == (mayChange && !blockedByPurchases), "\(persona) \(item.id) canDelete")
            }
        }
        #expect(seen > 0)
    }

    /// Ids of seeded items that hold purchases, read with full visibility (the owner's detail).
    private func purchasedSeededItemIds() async throws -> Set<String> {
        let owner = await ItemMockSupport.makeMock(ItemFixtures.Persona.owner.capabilities)
        var ids: Set<String> = []
        for item in try await ItemMockSupport.seededItems() {
            let detail = try await owner.fetchItemDetail(id: item.id)
            if !(detail.purchases ?? []).isEmpty || (detail.totalQuantityPurchased ?? 0) > 0 { ids.insert(item.id) }
        }
        return ids
    }

    @Test("non-blind owner and co-owner: an item with purchases can be edited but not deleted (P25)",
          arguments: [ItemFixtures.Persona.owner, .coOwner])
    func nonBlindOwnersCannotDeleteItemsWithPurchases(persona: ItemFixtures.Persona) async throws {
        let purchased = try await purchasedSeededItemIds()
        let seeded = try await ItemMockSupport.seededItems()
        let targets = seeded.filter { purchased.contains($0.id) && !$0.offList }
        #expect(!targets.isEmpty, "the seed must hold a regular item with purchases")

        for target in targets {
            let repo = await ItemMockSupport.makeMock(persona.capabilities)
            let listed = try #require(try await repo.fetchItems(listId: target.listId).first { $0.id == target.id })
            let detail = try await repo.fetchItemDetail(id: target.id)
            for item in [listed, detail] {
                #expect(item.canEdit, "\(persona) \(target.id)")
                #expect(!item.canDelete, "\(persona) \(target.id)")
            }
            await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: target.id) }
            let still = try await repo.fetchItemDetail(id: target.id)
            #expect(still.id == target.id, "a refused delete removes nothing")
            let updated = try await repo.updateItem(id: target.id, UpdateItemInput(name: "Renamed"))
            #expect(updated.name == "Renamed")
            #expect(updated.canEdit)
            #expect(!updated.canDelete, "editing does not clear the purchases")
        }
    }

    @Test("blind owner and co-owner: an item with purchases is still editable and deletable (P25)",
          arguments: [ItemFixtures.Persona.blindOwner, .blindCoOwner])
    func blindOwnersDeleteItemsWithPurchases(persona: ItemFixtures.Persona) async throws {
        let purchased = try await purchasedSeededItemIds()
        let seeded = try await ItemMockSupport.seededItems()
        let targets = seeded.filter { purchased.contains($0.id) && !$0.offList }
        #expect(!targets.isEmpty, "the seed must hold a regular item with purchases")

        for target in targets {
            let repo = await ItemMockSupport.makeMock(persona.capabilities)
            let listed = try #require(try await repo.fetchItems(listId: target.listId).first { $0.id == target.id })
            let detail = try await repo.fetchItemDetail(id: target.id)
            for item in [listed, detail] {
                #expect(item.purchases == nil, "a blind caller sees no purchases")
                #expect(item.canEdit, "\(persona) \(target.id)")
                #expect(item.canDelete, "\(persona) \(target.id)")
            }
            try await repo.deleteItem(id: target.id)
            await #expect(throws: ItemError.notFound) { _ = try await repo.fetchItemDetail(id: target.id) }
        }
    }

    @Test("the creator of a seeded off-list item can change it under member flags; nobody else's item")
    func seededFlagsForTheCreator() async throws {
        let seeded = try await ItemMockSupport.seededItems()
        let theirs = try #require(seeded.first { $0.offList }, "the mock must seed an off-list item")
        let creator = theirs.createdBy
        let repo = await ItemMockSupport.makeMock(ItemFixtures.Persona.member.capabilities, currentUser: creator)

        let fetched = try await repo.fetchItems(listId: theirs.listId)
        let mine = try #require(fetched.first { $0.id == theirs.id })
        #expect(mine.canEdit)
        #expect(mine.canDelete)
        for other in fetched where !(other.offList && other.createdBy == creator) {
            #expect(!other.canEdit, "\(other.id)")
            #expect(!other.canDelete, "\(other.id)")
        }
    }

    @Test("the detail flags equal the list flags for every visible seeded item", arguments: ItemFixtures.Persona.allCases)
    func detailFlagsEqualListFlags(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let repo = await ItemMockSupport.makeMock(persona.capabilities)

        for id in seededIds {
            for item in try await repo.fetchItems(listId: id) {
                let detail = try await repo.fetchItemDetail(id: item.id)
                #expect(detail.canEdit == item.canEdit, "\(persona) \(item.id)")
                #expect(detail.canDelete == item.canDelete, "\(persona) \(item.id)")
            }
        }
    }

    @Test("update and delete throw forbidden exactly when the item's flag is false", arguments: ItemFixtures.Persona.allCases)
    func forbiddenExactlyWhenFlagIsFalse(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let probe = await ItemMockSupport.makeMock(persona.capabilities)
        var items: [ListItem] = []
        for id in seededIds { items += try await probe.fetchItems(listId: id) }
        #expect(!items.isEmpty)

        for item in items where !item.canEdit {
            let repo = await ItemMockSupport.makeMock(persona.capabilities)
            await #expect(throws: ItemError.forbidden) { _ = try await repo.updateItem(id: item.id, UpdateItemInput(name: "X")) }
        }
        for item in items where !item.canDelete {
            let repo = await ItemMockSupport.makeMock(persona.capabilities)
            await #expect(throws: ItemError.forbidden) { try await repo.deleteItem(id: item.id) }
            let still = try await repo.fetchItemDetail(id: item.id)
            #expect(still.id == item.id, "a refused delete removes nothing")
        }
    }

    @Test("update and delete succeed when the item's flag is true", arguments: [
        ItemFixtures.Persona.owner, .blindOwner, .coOwner, .blindCoOwner
    ])
    func updateAndDeleteSucceedWhenFlagIsTrue(persona: ItemFixtures.Persona) async throws {
        let seededIds = try await ItemMockSupport.seededListIds()
        let probe = await ItemMockSupport.makeMock(persona.capabilities)
        var items: [ListItem] = []
        for id in seededIds { items += try await probe.fetchItems(listId: id) }
        let changeable = items.filter { $0.canEdit && $0.canDelete }
        #expect(!changeable.isEmpty, "\(persona) must be able to change at least one seeded item")

        for item in changeable {
            let repo = await ItemMockSupport.makeMock(persona.capabilities)
            let updated = try await repo.updateItem(id: item.id, UpdateItemInput(name: "Renamed"))
            #expect(updated.name == "Renamed")
            try await repo.deleteItem(id: item.id)
            await #expect(throws: ItemError.notFound) { _ = try await repo.fetchItemDetail(id: item.id) }
        }
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
