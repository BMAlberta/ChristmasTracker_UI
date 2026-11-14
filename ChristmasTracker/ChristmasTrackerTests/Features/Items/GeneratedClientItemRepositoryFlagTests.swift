//
//  GeneratedClientItemRepositoryFlagTests.swift
//  ChristmasTrackerTests
//
//  I5b Story C: the repository reads the server's canEdit and canDelete flags and is strict
//  about them. Through the REAL factory-built client with a fake transport:
//   - each of the four flag combinations on list, detail, create and update responses reaches
//     the domain item unchanged;
//   - an item whose JSON lacks canEdit, or lacks canDelete (each omitted separately), fails the
//     whole response as ItemError.invalidResponse on list, detail, create and update; a missing
//     flag is never defaulted to true or false.
//  The defensive 422 CANNOT_DELETE_ITEM_WITH_PURCHASES mapping stays pinned by
//  GeneratedClientItemRepositoryErrorTests.deleteWithPurchases (unchanged).
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientItemRepository flags", .timeLimit(.minutes(1)))
struct GeneratedClientItemRepositoryFlagTests {

    nonisolated static let combinations: [(Bool, Bool)] = [(true, true), (true, false), (false, true), (false, false)]
    nonisolated static let flagOps: [ItemRepoOp] = [.fetchItems, .fetchItemDetail, .createItem, .updateItem]
    nonisolated static let flagNames = ["canEdit", "canDelete"]

    private func body(_ op: ItemRepoOp, item: String) -> String {
        switch op {
        case .fetchItems: ItemWire.listJSON([item])
        case .fetchItemDetail: ItemWire.detailEnvelope(item: item, purchases: [], totalQuantityPurchased: 0)
        case .createItem, .updateItem, .deleteItem: ItemWire.itemEnvelope(item)
        }
    }

    private func run(_ op: ItemRepoOp, _ repo: GeneratedClientItemRepository) async throws -> ListItem? {
        switch op {
        case .fetchItems: return try await repo.fetchItems(listId: "list-1").first
        case .fetchItemDetail: return try await repo.fetchItemDetail(id: "item-1")
        case .createItem: return try await repo.createItem(listId: "list-1", sampleCreateItemInput())
        case .updateItem: return try await repo.updateItem(id: "item-1", UpdateItemInput(name: "New Name"))
        case .deleteItem: return nil
        }
    }

    // MARK: Flags reach the domain item

    @Test("Every flag combination reaches the domain item on list, detail, create and update",
          arguments: flagOps, combinations)
    func flagsReachTheDomain(op: ItemRepoOp, flags: (Bool, Bool)) async throws {
        let sut = try makeItemRepoSUT()
        let item = ItemWire.itemJSON(canEdit: flags.0, canDelete: flags.1)
        await sut.transport.enqueue(status: op.successStatus, json: body(op, item: item))

        let mapped = try #require(try await run(op, sut.repo))

        #expect(mapped.canEdit == flags.0, "\(op)")
        #expect(mapped.canDelete == flags.1, "\(op)")
    }

    @Test("The flags are not derived from offList or createdBy on the wire", arguments: combinations)
    func flagsIgnoreOffListAndCreator(flags: (Bool, Bool)) async throws {
        let sut = try makeItemRepoSUT()
        let own = ItemWire.itemJSON(id: "own", offList: true, createdById: "user-1",
                                    canEdit: flags.0, canDelete: flags.1)
        let others = ItemWire.itemJSON(id: "others", offList: true, createdById: "user-2",
                                       canEdit: flags.0, canDelete: flags.1)
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([own, others]))

        let items = try await sut.repo.fetchItems(listId: "list-1")

        #expect(items.count == 2)
        for item in items {
            #expect(item.canEdit == flags.0)
            #expect(item.canDelete == flags.1)
        }
    }

    // MARK: Strictness

    @Test("An item that lacks canEdit or canDelete (each omitted separately) throws invalidResponse",
          arguments: flagOps, flagNames)
    func missingFlagIsInvalid(op: ItemRepoOp, flag: String) async throws {
        let sut = try makeItemRepoSUT()
        let item = ItemWire.itemJSON(omitting: [flag])
        #expect(!item.contains("\"\(flag)\""), "the fixture must really omit \(flag)")
        await sut.transport.enqueue(status: op.successStatus, json: body(op, item: item))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await run(op, repo)
        }
    }

    @Test("Both flags omitted throws invalidResponse", arguments: flagOps)
    func bothFlagsMissingIsInvalid(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        let item = ItemWire.itemJSON(omitting: ["canEdit", "canDelete"])
        await sut.transport.enqueue(status: op.successStatus, json: body(op, item: item))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await run(op, repo)
        }
    }

    @Test("One item without a flag fails the whole list, even beside a valid item")
    func oneBadItemFailsTheList() async throws {
        let sut = try makeItemRepoSUT()
        let good = ItemWire.itemJSON(id: "good")
        let bad = ItemWire.itemJSON(id: "bad", omitting: ["canDelete"])
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([good, bad]))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await repo.fetchItems(listId: "list-1")
        }
    }

    @Test("A flag that is not a boolean throws invalidResponse", arguments: ["\"true\"", "1", "null"])
    func nonBooleanFlagIsInvalid(raw: String) async throws {
        let sut = try makeItemRepoSUT()
        let item = ItemWire.itemJSON(extra: "\"canEdit\": \(raw)", omitting: ["canEdit"])
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([item]))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await repo.fetchItems(listId: "list-1")
        }
    }
}
