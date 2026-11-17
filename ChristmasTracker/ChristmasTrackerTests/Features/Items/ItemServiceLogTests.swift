//
//  ItemServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3 batch B: the step lines ItemService writes through ServiceLog for the loads and the
//  mutations: started and processed on success, exactly one error on failure, cancelled (never an
//  error) when the session ends, only the failure line in a Release-style run, and no secret
//  fixture in any line.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService log Tests", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceLogTests {

    private struct Rig {
        let service: ItemService
        let repo: GatedItemRepository
        let sink: CapturingOperationLog
    }

    private func makeRig(verbose: Bool = true, honorsCancellation: Bool = false) -> Rig {
        let repo = GatedItemRepository()
        repo.gate.honorsCancellation = honorsCancellation
        let sink = CapturingOperationLog()
        let log = ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose))
        let service = ItemService(repository: repo, dataStore: ItemDataStore(), log: log)
        return Rig(service: service, repo: repo, sink: sink)
    }

    private func messages(_ rig: Rig) -> [String] { rig.sink.lines.map(\.message) }

    private func errors(_ rig: Rig) -> [String] {
        rig.sink.lines.filter { $0.level == .error }.map(\.message)
    }

    @Test("a load logs started with its reason, then processed with a count")
    func loadSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchItems(.success([ItemServiceFix.item("a"), ItemServiceFix.item("b")]))

        await rig.service.loadItems(listId: "list-1", reason: .appear)

        #expect(messages(rig) == ["load items started (appear)", "load items processed (2 items)"])
    }

    @Test("a refresh logs started with its reason, then processed with a count")
    func refreshSuccess() async {
        let rig = makeRig()
        rig.repo.enqueueFetchItems(.success([ItemServiceFix.item("a")]))
        await rig.service.loadItems(listId: "list-1")
        rig.repo.enqueueFetchItems(.success([ItemServiceFix.item("a"), ItemServiceFix.item("b")]))
        let before = rig.sink.lines.count

        await rig.service.refreshItems(reason: .pull)

        let added = rig.sink.lines.dropFirst(before).map(\.message)
        #expect(added == ["refresh items started (pull)", "refresh items processed (2 items)"])
    }

    @Test("a failed load logs exactly one error line")
    func loadFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchItems(.failure(ItemError.network))

        await rig.service.loadItems(listId: "list-1")

        #expect(errors(rig) == ["load items failed"])
        #expect(messages(rig) == ["load items started (unspecified)", "load items failed"])
    }

    @Test("a failed refresh logs exactly one error line")
    func refreshFailure() async {
        let rig = makeRig()
        rig.repo.enqueueFetchItems(.success([ItemServiceFix.item("a")]))
        await rig.service.loadItems(listId: "list-1")
        rig.repo.enqueueFetchItems(.failure(ItemError.server))

        await rig.service.refreshItems()

        #expect(errors(rig) == ["refresh items failed"])
    }

    @Test("a detail load logs started then processed, and a failure logs one error")
    func detail() async {
        let rig = makeRig()
        rig.repo.enqueueFetchItemDetail(.success(ItemServiceFix.item("item-1")))
        rig.repo.enqueueFetchItemDetail(.failure(ItemError.server))

        await rig.service.loadItemDetail(id: "item-1")
        #expect(messages(rig) == ["load item detail started", "load item detail processed"])

        await rig.service.loadItemDetail(id: "item-1")
        #expect(errors(rig) == ["load item detail failed"])
    }

    @Test("a session that ends mid-load logs cancelled and no error")
    func loadCancellation() async throws {
        let rig = makeRig(honorsCancellation: true)
        rig.repo.enqueueFetchItems(.success([]), held: true)
        let task = Task { @MainActor in await rig.service.loadItems(listId: "list-1") }
        await rig.repo.gate.nextHeldCall()

        try await rig.service.clearForSession()
        await task.value

        #expect(messages(rig) == ["load items started (unspecified)", "load items cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("each mutation logs started then processed", arguments: ItemMutationOp.allCases)
    func mutationSuccess(op: ItemMutationOp) async throws {
        let rig = makeRig()
        op.enqueueSuccess(on: rig.repo)

        try await op.run(rig.service)

        let name = Self.opName(op)
        #expect(messages(rig) == ["\(name) started", "\(name) processed"])
    }

    @Test("each failed mutation logs exactly one error line", arguments: ItemMutationOp.allCases)
    func mutationFailure(op: ItemMutationOp) async {
        let rig = makeRig()
        op.enqueueFailure(ItemError.server, on: rig.repo)

        await #expect(throws: ItemError.self) { try await op.run(rig.service) }

        #expect(errors(rig) == ["\(Self.opName(op)) failed"])
    }

    @Test("a session that ends mid-mutation logs cancelled and no error", arguments: ItemMutationOp.allCases)
    func mutationCancellation(op: ItemMutationOp) async throws {
        let rig = makeRig(honorsCancellation: true)
        op.enqueueSuccess(on: rig.repo, held: true)
        let task = startOutcome { try await op.run(rig.service) }
        await rig.repo.gate.nextHeldCall()

        try await rig.service.clearForSession()
        let error = await task.value

        #expect(error is CancellationError)
        let name = Self.opName(op)
        #expect(messages(rig) == ["\(name) started", "\(name) cancelled"])
        #expect(errors(rig).isEmpty)
    }

    @Test("a Release-style run logs only the failure line")
    func nonVerbose() async {
        let rig = makeRig(verbose: false)
        rig.repo.enqueueFetchItems(.success([ItemServiceFix.item("a")]))
        rig.repo.enqueueFetchItems(.failure(ItemError.server))

        await rig.service.loadItems(listId: "list-1")
        #expect(rig.sink.lines.isEmpty)

        await rig.service.refreshItems()
        #expect(messages(rig) == ["refresh items failed"])
        #expect(rig.sink.lines.map(\.level) == [.error])
    }

    @Test("secret fixtures never appear in any line")
    func noSecrets() async throws {
        let rig = makeRig()
        let secret = ItemFixtures.item(
            id: "ZZ-secret-id", name: "ZZ-secret-name", description: "zz-secret@example.com",
            price: Decimal(string: "987654.32")
        )
        rig.repo.enqueueFetchItems(.success([secret]))
        rig.repo.enqueueFetchItemDetail(.success(secret))
        rig.repo.enqueueCreateItem(.success(secret))
        rig.repo.enqueueUpdateItem(.failure(ItemError.server))

        await rig.service.loadItems(listId: "list-1")
        await rig.service.loadItemDetail(id: "ZZ-secret-id")
        _ = try await rig.service.createItem(listId: "list-1", ItemServiceFix.input(name: "ZZ-secret-name"))
        _ = try? await rig.service.updateItem(id: "ZZ-secret-id", UpdateItemInput(name: "ZZ-secret-name"))

        #expect(!rig.sink.lines.isEmpty)
        for line in rig.sink.lines {
            #expect(!line.message.contains("ZZ-"))
            #expect(!line.message.contains("zz-secret"))
            #expect(!line.message.contains("987654"))
        }
    }

    private static func opName(_ op: ItemMutationOp) -> String {
        switch op {
        case .create: "create item"
        case .update: "update item"
        case .delete: "delete item"
        }
    }
}
