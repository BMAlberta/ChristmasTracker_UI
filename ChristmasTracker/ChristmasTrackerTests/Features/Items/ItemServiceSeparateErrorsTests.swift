//
//  ItemServiceSeparateErrorsTests.swift
//  ChristmasTrackerTests
//
//  Fix pass F1: ItemService keeps one load error per screen. `listLoadError` belongs to the list
//  screen (loadItems / refreshItems), `detailLoadError` to the item screen (loadItemDetail). The
//  two never touch each other, so leaving one screen cannot wipe the other screen's error.
//
//  Rules under test:
//   - a failed loadItemDetail sets detailLoadError only; a failed loadItems / refreshItems sets
//     listLoadError only;
//   - each error is cleared by its own clear call and at the start of its own loads, never by
//     the other screen's clear call or loads;
//   - clearForSession() clears both; a stale result after teardown writes neither;
//   - a superseded detail load (item A finishing after item B started) neither sets the error
//     nor clears isLoadingDetail;
//   - mutation errors reach neither property.
//
//  Determinism: gated fake with the nextHeldCall() / release(at:) handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService separate load errors", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceSeparateErrorsTests {

    private func item(_ id: String, listId: String = "list-1", name: String? = nil) -> ListItem {
        ItemServiceFix.item(id, listId: listId, name: name)
    }

    private func makeSUT() async -> ItemServiceSUT {
        await makeItemServiceSUT()
    }

    private func makeLoadedSUT() async -> ItemServiceSUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.success([item("item-1"), item("item-2")]))
        await sut.service.loadItems(listId: "list-1")
        return sut
    }

    // MARK: - Which load sets which error

    @Test("a failed loadItemDetail sets detailLoadError only", arguments: [
        ItemError.network, .server, .forbidden, .notFound, .invalidResponse, .rateLimited(retryAfter: 2)
    ])
    func detailFailureSetsDetailOnly(error: ItemError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItemDetail(.failure(error))

        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.detailLoadError == error)
        #expect(sut.service.listLoadError == nil)
    }

    @Test("a failed loadItems sets listLoadError only", arguments: [
        ItemError.network, .server, .forbidden, .notFound, .invalidResponse, .rateLimited(retryAfter: 2)
    ])
    func listFailureSetsListOnly(error: ItemError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(error))

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.listLoadError == error)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("a failed refreshItems sets listLoadError only", arguments: [
        ItemError.network, .server, .rateLimited(retryAfter: 5)
    ])
    func refreshFailureSetsListOnly(error: ItemError) async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(error))

        await sut.service.refreshItems()

        #expect(sut.service.listLoadError == error)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("both loads can fail at once and each keeps its own error")
    func bothErrorsCoexist() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.network))
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.server))

        await sut.service.loadItems(listId: "list-1")
        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.listLoadError == .network)
        #expect(sut.service.detailLoadError == .server)
    }

    // MARK: - Clearing (the failing sequence from the real-mode check)

    @Test("failed detail load, then clearListLoadError(): detailLoadError stays")
    func clearListLeavesDetailError() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .network, "precondition")

        sut.service.clearListLoadError()

        #expect(sut.service.detailLoadError == .network, "the list screen disappearing must not wipe the item screen's error")
        #expect(sut.service.listLoadError == nil)
    }

    @Test("failed list load, then clearDetailLoadError(): listLoadError stays")
    func clearDetailLeavesListError() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        #expect(sut.service.listLoadError == .server, "precondition")

        sut.service.clearDetailLoadError()

        #expect(sut.service.listLoadError == .server)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("clearListLoadError clears the list error and nothing else")
    func clearListClearsListOnly() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        #expect(sut.service.listLoadError == .server, "precondition")

        sut.service.clearListLoadError()

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.currentListId == "list-1")
        #expect(sut.service.goneItemId == nil)
    }

    @Test("clearDetailLoadError clears the detail error and nothing else")
    func clearDetailClearsDetailOnly() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.server))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .server, "precondition")

        sut.service.clearDetailLoadError()

        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.items == [item("item-1"), item("item-2")])
        #expect(sut.service.currentListId == "list-1")
        #expect(sut.service.goneItemId == nil)
    }

    // MARK: - Loads of the other screen leave the error alone

    @Test("a new loadItems does not clear detailLoadError, success or failure", arguments: [false, true])
    func listLoadLeavesDetailError(fails: Bool) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .network, "precondition")
        let outcome: Result<[ListItem], any Error> = fails ? .failure(ItemError.server) : .success([item("item-1")])
        sut.repo.enqueueFetchItems(outcome)

        await sut.service.loadItems(listId: "list-1")

        #expect(sut.service.detailLoadError == .network)
    }

    @Test("a refreshItems does not clear detailLoadError, success or failure", arguments: [false, true])
    func refreshLeavesDetailError(fails: Bool) async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .network, "precondition")
        let outcome: Result<[ListItem], any Error> = fails ? .failure(ItemError.server) : .success([item("item-1")])
        sut.repo.enqueueFetchItems(outcome)

        await sut.service.refreshItems()

        #expect(sut.service.detailLoadError == .network)
    }

    @Test("a new loadItemDetail does not clear listLoadError, success or failure", arguments: [false, true])
    func detailLoadLeavesListError(fails: Bool) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        #expect(sut.service.listLoadError == .server, "precondition")
        let outcome: Result<ListItem, any Error> = fails ? .failure(ItemError.network) : .success(item("item-1"))
        sut.repo.enqueueFetchItemDetail(outcome)

        await sut.service.loadItemDetail(id: "item-1")

        #expect(sut.service.listLoadError == .server)
    }

    @Test("a loadItemDetail clears its own previous error at its start, and only that one")
    func detailLoadClearsOwnErrorAtStart() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.detailLoadError == .network, "precondition")
        sut.repo.enqueueFetchItemDetail(.success(item("item-1")), held: true)
        let task = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.detailLoadError == nil, "cleared as soon as the new detail load starts")
        #expect(sut.service.listLoadError == .server)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.listLoadError == .server)
    }

    @Test("a loadItems clears its own previous error at its start, and only that one")
    func listLoadClearsOwnErrorAtStart() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        #expect(sut.service.listLoadError == .server, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-1")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.listLoadError == nil, "cleared as soon as the new list load starts")
        #expect(sut.service.detailLoadError == .network)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == .network)
    }

    // MARK: - Teardown

    @Test("clearForSession clears both errors")
    func teardownClearsBoth() async throws {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.listLoadError == .server, "precondition")
        #expect(sut.service.detailLoadError == .network, "precondition")

        try await sut.service.clearForSession()

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("SessionManager teardown clears both errors")
    func managerTeardownClearsBoth() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-1")
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.network))
        await sut.service.loadItemDetail(id: "item-1")

        await sut.manager.teardown(reason: .userLogout)

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("a failure released after teardown writes neither error", arguments: [ItemError.network, .server, .notFound, .forbidden])
    func staleFailureAfterTeardownWritesNeither(error: ItemError) async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItems(.failure(error), held: true)
        sut.repo.enqueueFetchItemDetail(.failure(error), held: true)
        let listTask = Task { await sut.service.loadItems(listId: "list-1") }
        await sut.repo.gate.nextHeldCall()
        let detailTask = Task { await sut.service.loadItemDetail(id: "item-1") }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.gate.releaseAll()
        await listTask.value
        await detailTask.value

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.isLoadingItems == false)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("a refresh failure released after teardown writes neither error")
    func staleRefreshFailureAfterTeardown() async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server), held: true)
        let task = Task { await sut.service.refreshItems() }
        await sut.repo.gate.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.repo.gate.releaseAll()
        await task.value

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }

    // MARK: - Superseded detail load (same generation)

    private func makeTwoDetailLoads(
        aOutcome: Result<ListItem, any Error>,
        bOutcome: Result<ListItem, any Error>
    ) async -> (sut: ItemServiceSUT, taskA: Task<Void, Never>, taskB: Task<Void, Never>) {
        let sut = await makeSUT()
        sut.repo.enqueueFetchItemDetail(aOutcome, held: true)
        sut.repo.enqueueFetchItemDetail(bOutcome, held: true)
        let taskA = Task { await sut.service.loadItemDetail(id: "item-a") }
        await sut.repo.gate.nextHeldCall()
        let taskB = Task { await sut.service.loadItemDetail(id: "item-b") }
        await sut.repo.gate.nextHeldCall()
        return (sut, taskA, taskB)
    }

    @Test("item A fails after item B started: no error is set and isLoadingDetail stays true")
    func supersededDetailFailureWritesNothing() async {
        let (sut, taskA, taskB) = await makeTwoDetailLoads(
            aOutcome: .failure(ItemError.network),
            bOutcome: .success(item("item-b"))
        )
        #expect(sut.service.isLoadingDetail == true, "precondition")

        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.detailLoadError == nil, "item A's failure must not be shown on item B")
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.isLoadingDetail == true, "B is still loading")

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.currentItem?.id == "item-b")
    }

    @Test("item A fails late after B succeeded: still no error")
    func supersededDetailFailureAfterBSucceeded() async {
        let (sut, taskA, taskB) = await makeTwoDetailLoads(
            aOutcome: .failure(ItemError.forbidden),
            bOutcome: .success(item("item-b"))
        )

        sut.repo.gate.release(at: 1)
        await taskB.value
        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.detailLoadError == nil)
        #expect(sut.service.currentItem?.id == "item-b")
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("B's own failure still sets detailLoadError, and a late A failure does not replace it")
    func newestDetailFailureWins() async {
        let (sut, taskA, taskB) = await makeTwoDetailLoads(
            aOutcome: .failure(ItemError.network),
            bOutcome: .failure(ItemError.server)
        )

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.detailLoadError == .server, "precondition")
        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.detailLoadError == .server)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("item A succeeds late while B is loading: A is not published and the flag stays true")
    func supersededDetailSuccessWritesNothing() async {
        let (sut, taskA, taskB) = await makeTwoDetailLoads(
            aOutcome: .success(item("item-a")),
            bOutcome: .success(item("item-b"))
        )

        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.currentItem?.id != "item-a")
        #expect(sut.service.isLoadingDetail == true)
        #expect(sut.service.detailLoadError == nil)

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.currentItem?.id == "item-b")
        #expect(sut.service.isLoadingDetail == false)
    }

    // MARK: - Mutation errors reach neither property

    @Test("a failed mutation sets neither load error", arguments: ItemMutationOp.allCases)
    func mutationFailureSetsNeither(op: ItemMutationOp) async {
        let sut = await makeLoadedSUT()
        op.enqueueFailure(ItemError.server, on: sut.repo)

        await #expect(throws: ItemError.server) { try await op.run(sut.service) }

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }

    @Test("a failed mutation leaves both existing load errors as they were", arguments: ItemMutationOp.allCases)
    func mutationFailureLeavesBothAlone(op: ItemMutationOp) async {
        let sut = await makeLoadedSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.network))
        await sut.service.refreshItems()
        sut.repo.enqueueFetchItemDetail(.failure(ItemError.rateLimited(retryAfter: 4)))
        await sut.service.loadItemDetail(id: "item-1")
        #expect(sut.service.listLoadError == .network, "precondition")
        #expect(sut.service.detailLoadError == .rateLimited(retryAfter: 4), "precondition")
        op.enqueueFailure(ItemError.server, on: sut.repo)

        await #expect(throws: ItemError.server) { try await op.run(sut.service) }

        #expect(sut.service.listLoadError == .network)
        #expect(sut.service.detailLoadError == .rateLimited(retryAfter: 4))
    }

    // MARK: - Initial state

    @Test("a new service has neither error")
    func initialState() async {
        let sut = await makeSUT()

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.detailLoadError == nil)
    }
}
