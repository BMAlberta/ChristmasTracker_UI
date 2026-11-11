//
//  ItemServiceSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: ItemService is session-safe exactly like ListService. Stale data from a previous
//  session or user is impossible after teardown, a user switch or cancellation, and the service
//  never sets an error after the session ended.
//
//  Rules under test (Gate 1 addendum, rule 5):
//   - every operation captures a generation before its first await; after `clearForSession()`
//     an in-flight operation writes NOTHING, sets no error (no loadError, no goneItemId) and, for
//     a mutation, throws CancellationError;
//   - Task cancellation sets no loadError;
//   - loading flags are only reset by the same generation;
//   - `clearForSession()` empties items, currentItem, currentListId, loadError, goneItemId, the
//     mutation counter and the cache.
//
//  Teardown is driven the way the app does it: the service is registered with a SessionManager
//  and `SessionManager.teardown(reason:)` runs. Determinism: gated fakes with the
//  nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService session safety", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceSessionSafetyTests {

    private func item(_ id: String, listId: String = "list-1", name: String? = nil) -> ListItem {
        ItemServiceFix.item(id, listId: listId, name: name)
    }

    private func expectCleared(_ sut: ItemServiceSUT, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(sut.service.items.isEmpty, "items must stay empty", sourceLocation: sourceLocation)
        #expect(sut.service.currentItem == nil, "currentItem must stay nil", sourceLocation: sourceLocation)
        #expect(sut.service.currentListId == nil, "currentListId must stay nil", sourceLocation: sourceLocation)
        #expect(sut.service.loadError == nil, "no error may be set after the session ended", sourceLocation: sourceLocation)
        #expect(sut.service.goneItemId == nil, sourceLocation: sourceLocation)
        #expect(sut.service.isLoadingItems == false, sourceLocation: sourceLocation)
        #expect(sut.service.isLoadingDetail == false, sourceLocation: sourceLocation)
        #expect(sut.service.isMutating == false, sourceLocation: sourceLocation)
        for id in ["list-1", "list-a", "list-b"] {
            let cached = await sut.store.getItems(listId: id)
            #expect(cached.isEmpty, "the cache must not receive a stale result for \(id)", sourceLocation: sourceLocation)
        }
    }

    private func makeLoadedSUT(honorsCancellation: Bool = false) async -> ItemServiceSUT {
        let sut = await makeItemServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))
        await sut.service.loadItems(listId: "list-1")
        return sut
    }

    // MARK: - Teardown during a load

    @Test("a load that completes after teardown writes nothing", arguments: [false, true])
    func loadCompletesAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeItemServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a load that fails after teardown sets no error", arguments: [ItemError.network, .server, .notFound, .forbidden])
    func loadFailsAfterTeardown(error: ItemError) async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(error), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.gate.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a refresh that completes or fails after teardown writes nothing", arguments: [false, true])
    func refreshAfterTeardown(fails: Bool) async {
        let sut = await makeLoadedSUT()
        let outcome: Result<[ListItem], any Error> = fails ? .failure(ItemError.server) : .success([item("item-9")])
        sut.repo.enqueueFetchItems(outcome, held: true)
        let task = Task { await sut.service.refreshItems() }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a detail load that completes after teardown publishes nothing", arguments: [false, true])
    func detailCompletesAfterTeardown(honorsCancellation: Bool) async {
        let sut = await makeItemServiceSUT(honorsCancellation: honorsCancellation)
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a detail load that fails after teardown sets no error, not even for a 404", arguments: [ItemError.network, .notFound])
    func detailFailsAfterTeardown(error: ItemError) async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.failure(error), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.gate.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    // MARK: - Teardown during a mutation

    @Test("a mutation that completes after teardown throws CancellationError and writes nothing", arguments: ItemMutationOp.allCases, [false, true])
    func mutationCompletesAfterTeardown(op: ItemMutationOp, honorsCancellation: Bool) async {
        let sut = await makeItemServiceSUT(honorsCancellation: honorsCancellation)
        op.enqueueSuccess(on: sut.repo, held: true)
        let task = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect(error is CancellationError, "a stale mutation ends as a cancellation, not as a success or an ItemError")
        await expectCleared(sut)
    }

    @Test("a mutation that fails after teardown throws CancellationError, sets no error and drops nothing as gone", arguments: ItemMutationOp.allCases, [ItemError.server, .notFound, .forbidden])
    func mutationFailsAfterTeardown(op: ItemMutationOp, failure: ItemError) async {
        let sut = await makeItemServiceSUT()
        op.enqueueFailure(failure, on: sut.repo, held: true)
        let task = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect(error is CancellationError)
        await expectCleared(sut)
    }

    @Test("teardown resets isMutating at once, before the stale mutation is released")
    func teardownResetsIsMutating() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueCreateItem(.success(item("item-new")), held: true)
        let task = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition")

        await sut.manager.teardown(reason: .userLogout)

        #expect(sut.service.isMutating == false)
        sut.repo.gate.releaseAll()
        _ = await task.value
        #expect(sut.service.isMutating == false)
    }

    // MARK: - User switch

    @Test("user switch: A's load, released late, never touches B's items, cache or error")
    func userSwitchLoadReleasedLate() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-a1", listId: "list-1")]), held: true)   // user A
        sut.repo.enqueueFetchItems(.success([item("item-b1", listId: "list-1")]))               // user B, same list id
        let userA = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadItems(listId: "list-1")                                            // user B
        #expect(sut.service.items.map(\.id) == ["item-b1"], "precondition")
        sut.repo.gate.releaseAll()
        await userA.value

        #expect(sut.service.items.map(\.id) == ["item-b1"], "A's data must not replace or join B's")
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached.map(\.id) == ["item-b1"])
        #expect(sut.service.loadError == nil)
        #expect(sut.service.currentListId == "list-1")
    }

    @Test("user switch: A's failing load, released late, does not put an error on B")
    func userSwitchFailingLoadReleasedLate() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server), held: true)
        sut.repo.enqueueFetchItems(.success([item("item-b1")]))
        let userA = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadItems(listId: "list-1")
        sut.repo.gate.releaseAll()
        await userA.value

        #expect(sut.service.loadError == nil)
        #expect(sut.service.items.map(\.id) == ["item-b1"])
    }

    @Test("user switch: A's mutation, released after B loaded the same list, does not alter B's items or cache", arguments: ItemMutationOp.allCases)
    func userSwitchMutationReleasedLate(op: ItemMutationOp) async {
        let sut = await makeItemServiceSUT()
        op.enqueueSuccess(on: sut.repo, held: true)
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))                  // user B, same ids
        let userA = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadItems(listId: "list-1")
        sut.repo.gate.releaseAll()
        let error = await userA.value

        #expect(error is CancellationError)
        #expect(sut.service.items == [item("item-1"), item("item-2")], "B's items are untouched")
        let cached = await sut.store.getItems(listId: "list-1")
        #expect(cached == [item("item-1"), item("item-2")])
        #expect(sut.service.goneItemId == nil)
        #expect(sut.service.loadError == nil)
    }

    @Test("user switch: A's 404 on a mutation does not mark B's item as gone")
    func userSwitchNotFoundDoesNotDropBsItem() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueDeleteItem(.failure(ItemError.notFound), held: true)
        sut.repo.enqueueFetchItems(.success([item("item-1")]))
        let userA = startOutcome { try await sut.service.deleteItem(id: "item-1", listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadItems(listId: "list-1")
        sut.repo.gate.releaseAll()
        _ = await userA.value

        #expect(sut.service.items == [item("item-1")])
        #expect(sut.service.goneItemId == nil)
    }

    // MARK: - Loading flags belong to their generation

    @Test("A's late load does not reset isLoadingItems of B's load")
    func staleLoadDoesNotResetBsFlag() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.success([item("item-a1")]), held: true)
        sut.repo.enqueueFetchItems(.success([item("item-b1")]), held: true)
        let userA = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let userB = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isLoadingItems == true, "precondition: B is loading")

        sut.repo.gate.release(at: 0)
        await userA.value
        #expect(sut.service.isLoadingItems == true, "A finishing must not turn off B's flag")

        sut.repo.gate.release(at: 1)
        await userB.value
        #expect(sut.service.isLoadingItems == false)
        #expect(sut.service.items.map(\.id) == ["item-b1"])
    }

    @Test("A's late detail load does not reset isLoadingDetail of B's detail load")
    func staleDetailDoesNotResetBsFlag() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.success(item("item-a1")), held: true)
        sut.repo.enqueueFetchItemDetail(.success(item("item-b1")), held: true)
        let userA = Task { await sut.service.loadItemDetail(id: "item-a1") }
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let userB = Task { await sut.service.loadItemDetail(id: "item-b1") }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isLoadingDetail == true, "precondition")

        sut.repo.gate.release(at: 0)
        await userA.value
        #expect(sut.service.isLoadingDetail == true)

        sut.repo.gate.release(at: 1)
        await userB.value
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.currentItem?.id == "item-b1")
    }

    @Test("A's late mutation does not decrement the mutation counter of B's mutation")
    func staleMutationDoesNotResetBsCounter() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueCreateItem(.success(item("item-a")), held: true)
        sut.repo.enqueueCreateItem(.success(item("item-b")), held: true)
        let userA = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        let userB = startOutcome { _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input()) }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.isMutating == true, "precondition: B is mutating")

        sut.repo.gate.release(at: 0)
        _ = await userA.value
        #expect(sut.service.isMutating == true, "A finishing must not turn off B's flag")

        sut.repo.gate.release(at: 1)
        let errorB = await userB.value
        #expect(errorB == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - Cancellation

    @Test("cancelling the caller during a load sets no loadError and leaves no flag set")
    func cancellationDuringLoad() async {
        let sut = await makeItemServiceSUT(honorsCancellation: true)
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.loadError == nil, "cancellation is not shown to the user")
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("cancelling the caller during a refresh sets no loadError")
    func cancellationDuringRefresh() async {
        let sut = await makeLoadedSUT(honorsCancellation: true)
        sut.repo.enqueueFetchItems(.success([item("item-9")]), held: true)
        let task = Task { await sut.service.refreshItems() }
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.loadError == nil)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("cancelling the caller during a detail load sets no loadError and does not mark the item gone")
    func cancellationDuringDetail() async {
        let sut = await makeItemServiceSUT(honorsCancellation: true)
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.loadError == nil)
        #expect(sut.service.goneItemId == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("cancelling the caller during a mutation throws CancellationError, sets no loadError and resets isMutating", arguments: ItemMutationOp.allCases)
    func cancellationDuringMutation(op: ItemMutationOp) async {
        let sut = await makeLoadedSUT(honorsCancellation: true)
        op.enqueueSuccess(on: sut.repo, held: true)
        let task = startOutcome { try await op.run(sut.service) }
        await sut.repo.gate.nextHeldCall()

        task.cancel()
        sut.repo.gate.releaseAll()
        let error = await task.value

        #expect(error is CancellationError)
        #expect(sut.service.loadError == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.items == [item("item-1"), item("item-2")], "a cancelled mutation writes nothing")
    }

    @Test("a repository that fails a load with CancellationError sets no loadError")
    func repositoryCancellationOnLoad() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(CancellationError()))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.loadError == nil)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("a repository that fails a detail load with CancellationError sets no loadError")
    func repositoryCancellationOnDetail() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItemDetail(.failure(CancellationError()))

        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.loadError == nil)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a repository that fails a mutation with CancellationError makes the mutation throw CancellationError", arguments: ItemMutationOp.allCases)
    func repositoryCancellationOnMutation(op: ItemMutationOp) async {
        let sut = await makeLoadedSUT()
        op.enqueueFailure(CancellationError(), on: sut.repo)

        await #expect(throws: CancellationError.self) { try await op.run(sut.service) }

        #expect(sut.service.loadError == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.items == [item("item-1"), item("item-2")])
    }

    // MARK: - clearForSession

    @Test("clearForSession empties everything: items, detail, list id, load error, gone id, counter and cache")
    func clearForSessionEmptiesEverything() async throws {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")))
        await sut.service.loadItemDetail(id: "item-1")
        sut.repo.enqueueDeleteItem(.failure(ItemError.notFound))
        await #expect(throws: ItemError.notFound) { try await sut.service.deleteItem(id: "item-1", listId: "list-1") }
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-2")
        sut.repo.enqueueUpdateItem(.success(item("item-2", name: "Updated")), held: true)
        let held = startOutcome { _ = try await sut.service.updateItem(id: "item-2", UpdateItemInput(name: "Updated")) }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.service.items.isEmpty == false, "precondition")
        #expect(sut.service.loadError == .network, "precondition")
        #expect(sut.service.goneItemId == "item-1", "precondition")
        #expect(sut.service.isMutating == true, "precondition")

        try await sut.service.clearForSession()

        await expectCleared(sut)
        sut.repo.gate.releaseAll()
        _ = await held.value
        await expectCleared(sut)
    }

    @Test("clearForSession clears the cache even when the data store is not registered separately")
    func clearForSessionClearsTheCache() async throws {
        let sut = await makeLoadedSUT()
        let before = await sut.store.getItems(listId: "list-1")
        #expect(before.isEmpty == false, "precondition")

        try await sut.service.clearForSession()

        let after = await sut.store.getItems(listId: "list-1")
        #expect(after.isEmpty)
    }

    @Test("after teardown the next session starts clean: the next load goes to the repository")
    func nextLoadAfterTeardownGoesToTheRepository() async {
        let sut = await makeLoadedSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchItems(.success([item("item-3")]))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.repo.fetchItemsCount == 2, "the cache of the ended session must not answer")
        #expect(sut.service.items == [item("item-3")])
        #expect(sut.service.loadError == nil)
    }

    @Test("a mutation after teardown works normally in the new session")
    func mutationAfterTeardownWorks() async throws {
        let sut = await makeLoadedSUT()
        await sut.manager.teardown(reason: .userLogout)
        sut.repo.enqueueFetchItems(.success([item("item-3")]))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueCreateItem(.success(item("item-4")))

        _ = try await sut.service.createItem(listId: "list-1", ItemServiceFix.input())

        #expect(sut.service.items == [item("item-3"), item("item-4")])
        #expect(sut.service.isMutating == false)
    }
}
