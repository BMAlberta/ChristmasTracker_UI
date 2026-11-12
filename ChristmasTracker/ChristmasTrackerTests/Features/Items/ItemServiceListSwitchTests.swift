//
//  ItemServiceListSwitchTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D, carried Story C finding (a): a load of list A that fails or finishes after a
//  load of list B started (same session generation) must not touch B's state. Specifically it
//  must not set `listLoadError`, clear `isLoadingItems`, or write items / currentListId.
//
//  Determinism: gated fake with the arrival-index handshake (release(at:)); no sleeps.
//  Arrival index 0 is always the load of list A, index 1 the load of list B.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemService list switch (same generation)", .timeLimit(.minutes(1)))
@MainActor
struct ItemServiceListSwitchTests {

    private func item(_ id: String, listId: String) -> ListItem {
        ItemServiceFix.item(id, listId: listId)
    }

    /// Starts load A (held), then load B (held), both in flight.
    private func makeSUT(
        aOutcome: Result<[ListItem], any Error>,
        bOutcome: Result<[ListItem], any Error>
    ) async -> (sut: ItemServiceSUT, taskA: Task<Void, Never>, taskB: Task<Void, Never>) {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(aOutcome, held: true)
        sut.repo.enqueueFetchItems(bOutcome, held: true)
        let taskA = Task { await sut.service.loadItems(listId: "list-a") }
        await sut.repo.gate.nextHeldCall()
        let taskB = Task { await sut.service.loadItems(listId: "list-b") }
        await sut.repo.gate.nextHeldCall()
        return (sut, taskA, taskB)
    }

    @Test("A fails while B is still loading: listLoadError stays nil and isLoadingItems stays true")
    func staleFailureDoesNotTouchB() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .failure(ItemError.network),
            bOutcome: .success([item("item-b", listId: "list-b")])
        )

        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.listLoadError == nil, "list A's failure must not be shown on list B")
        #expect(sut.service.isLoadingItems == true, "B is still loading")
        #expect(sut.service.currentListId == "list-b")

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("A succeeds late while B is still loading: items and currentListId are not A's")
    func staleSuccessWhileBLoading() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .success([item("item-a", listId: "list-a")]),
            bOutcome: .success([item("item-b", listId: "list-b")])
        )

        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.items.isEmpty, "list A's items must never show under list B")
        #expect(sut.service.currentListId == "list-b")
        #expect(sut.service.isLoadingItems == true)

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.service.currentListId == "list-b")
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("A succeeds late after B finished: B's items and list id are kept")
    func staleSuccessAfterBFinished() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .success([item("item-a", listId: "list-a")]),
            bOutcome: .success([item("item-b", listId: "list-b")])
        )

        sut.repo.gate.release(at: 1)
        await taskB.value
        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.service.currentListId == "list-b")
        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("A fails late after B succeeded: listLoadError stays nil")
    func staleFailureAfterBSucceeded() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .failure(ItemError.forbidden),
            bOutcome: .success([item("item-b", listId: "list-b")])
        )

        sut.repo.gate.release(at: 1)
        await taskB.value
        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.listLoadError == nil)
        #expect(sut.service.items == [item("item-b", listId: "list-b")])
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("B's own failure still sets listLoadError")
    func bFailureSetsListLoadError() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .success([item("item-a", listId: "list-a")]),
            bOutcome: .failure(ItemError.server)
        )

        sut.repo.gate.release(at: 0)
        await taskA.value
        sut.repo.gate.release(at: 1)
        await taskB.value

        #expect(sut.service.listLoadError == .server)
        #expect(sut.service.items.isEmpty)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("B fails first, then A fails late: B's error is kept, not replaced by A's")
    func bErrorNotReplacedByStaleA() async {
        let (sut, taskA, taskB) = await makeSUT(
            aOutcome: .failure(ItemError.network),
            bOutcome: .failure(ItemError.server)
        )

        sut.repo.gate.release(at: 1)
        await taskB.value
        #expect(sut.service.listLoadError == .server, "precondition")
        sut.repo.gate.release(at: 0)
        await taskA.value

        #expect(sut.service.listLoadError == .server)
        #expect(sut.service.isLoadingItems == false)
    }

    @Test("A starting a new load clears an earlier listLoadError at its start")
    func newLoadClearsEarlierError() async {
        let sut = await makeItemServiceSUT()
        sut.repo.enqueueFetchItems(.failure(ItemError.server))
        await sut.service.loadItems(listId: "list-a")
        #expect(sut.service.listLoadError == .server, "precondition")
        sut.repo.enqueueFetchItems(.success([item("item-b", listId: "list-b")]), held: true)
        let task = Task { await sut.service.loadItems(listId: "list-b") }
        await sut.repo.gate.nextHeldCall()

        #expect(sut.service.listLoadError == nil)

        sut.repo.gate.releaseAll()
        await task.value
    }
}
