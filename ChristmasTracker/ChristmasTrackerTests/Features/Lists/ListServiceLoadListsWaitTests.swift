//
//  ListServiceLoadListsWaitTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2, finding D: loadLists called while a lists load is already in flight WAITS for that
//  load's result instead of returning at once. It never starts a second fetch, it returns the in-flight
//  load's result, and teardown resumes every waiter with nil.
//
//  Determinism (no sleeps, no yield loops): the in-flight load is held by the gated repository and the
//  test waits for nextHeldCall(). The waiter is created as a Task BEFORE the release call and the test
//  does not suspend between creating it and releasing, so the waiter's job is queued on the main actor
//  ahead of the held load's resumption: it reaches the "load in flight" check first. Teardown is
//  awaited, which lets the queued waiter run before the clear.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService loadLists waits for an in-flight load", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceLoadListsWaitTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
        let manager: SessionManager
    }

    private func makeSUT() async -> SUT {
        let repo = GatedListRepository()
        let store = ListDataStore()
        let service = ListService(repository: repo, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, store: store, manager: manager)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    // MARK: - Same result, one fetch

    @Test("a second loadLists waits, returns the same success and the repository is called once")
    func waiterGetsSameSuccess() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        let second = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult == nil)
        #expect(secondResult == nil)
        #expect(sut.repo.fetchListsCount == 1, "a waiter never starts a second fetch")
        #expect(sut.service.lists.map(\.id) == ["list-a"], "the waiter returns when the lists are there")
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a second loadLists waits, returns the same failure and the repository is called once")
    func waiterGetsSameFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        let second = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult == .network)
        #expect(secondResult == .network, "the waiter returns that load's result, not a second attempt's")
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.listsLoadFailure == .network)
    }

    @Test("several waiters all get the one result")
    func severalWaiters() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        let second = Task { await sut.service.loadLists() }
        let third = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()
        let results = [await first.value, await second.value, await third.value]

        #expect(results == [.server, .server, .server])
        #expect(sut.repo.fetchListsCount == 1)
    }

    @Test("a waiter does not block a later load: after the in-flight load ended, a failed one can be retried")
    func laterLoadFetchesAgain() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let second = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()
        _ = await first.value
        _ = await second.value
        sut.repo.enqueueFetchLists(.success([list("list-a")]))

        let retry = await sut.service.loadLists()

        #expect(retry == nil)
        #expect(sut.repo.fetchListsCount == 2)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.listsLoadFailure == nil)
    }

    // MARK: - reportingFailure

    @Test("a waiter with reportingFailure: false stores nothing itself, the in-flight load stores by its own flag")
    func waiterNotReportingInFlightReporting() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)
        let first = Task { await sut.service.loadLists() }                       // reports
        await sut.repo.nextHeldCall()

        let second = Task { await sut.service.loadLists(reportingFailure: false) }
        sut.repo.releaseAll()
        _ = await first.value
        let secondResult = await second.value

        #expect(secondResult == .network, "the waiter still gets the result")
        #expect(sut.service.listsLoadFailure == .network, "stored by the in-flight load, which reports")
        #expect(sut.repo.fetchListsCount == 1)
    }

    @Test("a waiter with reportingFailure: true does not make a non-reporting in-flight load store its failure")
    func waiterReportingInFlightNotReporting() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network), held: true)
        let first = Task { await sut.service.loadLists(reportingFailure: false) }   // does not report
        await sut.repo.nextHeldCall()

        let second = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value

        #expect(firstResult == .network)
        #expect(secondResult == .network)
        #expect(sut.service.listsLoadFailure == nil, "the in-flight load stores according to its own flag")
        #expect(sut.repo.fetchListsCount == 1)
    }

    // MARK: - Teardown

    @Test("teardown resumes a waiter with nil without anyone releasing the held load")
    func teardownResumesWaiter() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }

        await sut.manager.teardown(reason: .userLogout)
        // The held load is NOT released yet: the waiter must come back by itself (the suite time limit
        // turns a hang into a failure).
        let waiterResult = await waiter.value
        sut.repo.releaseAll()
        let firstResult = await first.value

        #expect(waiterResult == nil)
        #expect(firstResult == nil)
        #expect(sut.service.lists.isEmpty, "nothing is written for the old session")
        #expect(sut.service.anyLoadFailure == nil)
        let cached = await sut.store.getLists()
        #expect(cached.isEmpty)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.repo.fetchListsCount == 1, "a waiter resumed by teardown does not refetch")
    }

    // F1 (UX1a U2 review): a waiter resumed with nil only because the in-flight load was CANCELLED
    // (lists still empty, same session, the waiter itself not cancelled, no failure) loads once itself.
    @Test("a waiter whose in-flight load was cancelled starts its own load once and gets the lists")
    func cancelledInFlightLoadWaiterLoadsItself() async {
        let sut = await makeSUT()
        sut.repo.honorsCancellation = true
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)    // cancelled
        sut.repo.enqueueFetchLists(.success([list("list-b")]))                // the waiter's own load
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }

        first.cancel()
        let firstResult = await first.value
        let waiterResult = await waiter.value

        #expect(firstResult == nil)
        #expect(waiterResult == nil)
        #expect(sut.repo.fetchListsCount == 2, "exactly one extra fetch, started by the waiter")
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isLoadingLists == false)
    }

    @Test("a waiter of a cancelled in-flight load whose own load fails returns that failure and stores it")
    func cancelledInFlightWaiterOwnLoadFails() async {
        let sut = await makeSUT()
        sut.repo.honorsCancellation = true
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }

        first.cancel()
        _ = await first.value
        let waiterResult = await waiter.value

        #expect(waiterResult == .network)
        #expect(sut.repo.fetchListsCount == 2, "it retries once, not in a loop")
    }

    @Test("a waiter that is itself cancelled does not start a load")
    func cancelledWaiterDoesNotLoad() async {
        let sut = await makeSUT()
        sut.repo.honorsCancellation = true
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)
        sut.repo.enqueueFetchLists(.success([list("list-b")]))                // must never be consumed
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }

        waiter.cancel()
        first.cancel()
        _ = await first.value
        let waiterResult = await waiter.value

        #expect(waiterResult == nil)
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.lists.isEmpty)
    }

    @Test("a waiter resumed after a REAL failure returns it and does not refetch")
    func realFailureWaiterDoesNotRefetch() async {
        let sut = await makeSUT()
        sut.repo.honorsCancellation = true
        sut.repo.enqueueFetchLists(.failure(ListError.server), held: true)
        sut.repo.enqueueFetchLists(.success([list("list-b")]))                // must never be consumed
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }
        sut.repo.releaseAll()

        let firstResult = await first.value
        let waiterResult = await waiter.value

        #expect(firstResult == .server)
        #expect(waiterResult == .server)
        #expect(sut.repo.fetchListsCount == 1)
        #expect(sut.service.lists.isEmpty)
    }

    @Test("a waiter whose in-flight load fails after teardown returns nil and nothing is stored")
    func teardownThenLateFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server), held: true)
        let first = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiter = Task { await sut.service.loadLists() }

        await sut.manager.teardown(reason: .sessionExpired)
        let waiterResult = await waiter.value
        sut.repo.releaseAll()
        let firstResult = await first.value

        #expect(waiterResult == nil)
        #expect(firstResult == nil)
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("user switch: a waiter of user A is resumed with nil and user B's load is not affected")
    func userSwitchWaiter() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)   // user A
        sut.repo.enqueueFetchLists(.success([list("list-b")]))               // user B
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()
        let waiterA = Task { await sut.service.loadLists() }

        await sut.manager.teardown(reason: .userLogout)
        let waiterResult = await waiterA.value
        let userB = await sut.service.loadLists()
        sut.repo.releaseAll()
        _ = await loadA.value

        #expect(waiterResult == nil)
        #expect(userB == nil)
        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's data never shows")
        #expect(sut.repo.fetchListsCount == 2, "A's waiter started no fetch of its own")
    }
}
