//
//  ListServiceLoadFailureTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2: ListService holds two SCOPED load failures instead of one shared `error`.
//
//  - listsLoadFailure is set only by loadLists / refreshLists and cleared when a lists load or
//    refresh starts, by clearListsLoadFailure() and at teardown;
//  - detailLoadFailure is set only by loadListDetail (also for a failed revalidation while cached
//    data is shown) and cleared when a detail load starts, by clearDetailLoadFailure() and at teardown;
//  - `loadLists(reportingFailure: false)` returns its failure and stores it nowhere;
//  - a load inside the cache window fetches nothing and records nothing;
//  - a stale result after teardown or a user switch writes nothing.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService scoped load failures", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceLoadFailureTests {

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

    private func detail(_ id: String) -> ListDetail {
        ListFixtures.listDetail(id: id, name: "Name of \(id)")
    }

    /// A service whose lists load failed with .network and whose detail load failed with .server.
    private func sutWithBothFailures() async -> SUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        return sut
    }

    // MARK: - Each failure is set only by its own load

    @Test("a failed loadLists returns the failure and stores it in listsLoadFailure only")
    func loadListsFailureIsScoped() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.loadLists()

        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == .network)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a failed refreshLists returns the failure and stores it in listsLoadFailure only")
    func refreshListsFailureIsScoped() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))

        let failure = await sut.service.refreshLists()

        #expect(failure == .server)
        #expect(sut.service.listsLoadFailure == .server)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a failed loadListDetail stores the failure in detailLoadFailure only")
    func loadListDetailFailureIsScoped() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.detailLoadFailure == .server)
        #expect(sut.service.listsLoadFailure == nil)
    }

    @Test("a successful load of one kind leaves the failure of the other kind alone")
    func successfulLoadDoesNotTouchTheOtherFailure() async {
        let sut = await sutWithBothFailures()
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        #expect(sut.service.detailLoadFailure == .server, "precondition")

        // A successful DETAIL load clears the detail failure and leaves the lists failure.
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.listsLoadFailure == .network)

        // A successful LISTS refresh clears the lists failure.
        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == nil)
    }

    @Test("a failed detail load does not replace a lists failure, and the reverse")
    func failuresDoNotOverwriteEachOther() async {
        let sut = await sutWithBothFailures()

        sut.repo.enqueueFetchListDetail(.failure(ListError.rateLimited(retryAfter: 3)))
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.listsLoadFailure == .network)
        #expect(sut.service.detailLoadFailure == .rateLimited(retryAfter: 3))

        sut.repo.enqueueFetchLists(.failure(ListError.invalidResponse))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == .invalidResponse)
        #expect(sut.service.detailLoadFailure == .rateLimited(retryAfter: 3))
    }

    // MARK: - reportingFailure: false

    @Test("loadLists(reportingFailure: false) returns the failure and stores it nowhere")
    func notReportingStoresNothing() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.loadLists(reportingFailure: false)

        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("loadLists(reportingFailure: false) returns nil on success and does not clear an existing lists failure")
    func notReportingSuccessLeavesExistingFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        sut.repo.enqueueFetchLists(.success([list("list-a")]))

        let failure = await sut.service.loadLists(reportingFailure: false)

        #expect(failure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.listsLoadFailure == .network, "a quiet load neither sets nor clears the failure")
    }

    @Test("a quiet failing load does not replace or clear a pre-set lists failure")
    func notReportingFailureLeavesExistingFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))
        await sut.service.refreshLists()
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.loadLists(reportingFailure: false)

        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == .server)
    }

    @Test("loadLists with the default reports the failure, like reportingFailure: true")
    func defaultReports() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))

        await sut.service.loadLists(reportingFailure: true)

        #expect(sut.service.listsLoadFailure == .server)
    }

    // MARK: - Cleared when its own load starts

    @Test("the lists failure is cleared when the next loadLists starts")
    func listsFailureClearedWhenLoadStarts() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        await sut.service.loadLists()
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)

        let task = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        #expect(sut.service.listsLoadFailure == nil, "cleared at the START of the load, before it ends")
        sut.repo.releaseAll()
        await task.value
        #expect(sut.service.listsLoadFailure == nil)
    }

    @Test("the lists failure is cleared when the next refreshLists starts")
    func listsFailureClearedWhenRefreshStarts() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == .network, "precondition")
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)

        let task = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()

        #expect(sut.service.listsLoadFailure == nil, "cleared at the START of the refresh, before it ends")
        sut.repo.releaseAll()
        await task.value
    }

    @Test("a new load that fails again stores the new failure")
    func newFailureReplacesOld() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))
        sut.repo.enqueueFetchLists(.failure(ListError.server))

        await sut.service.refreshLists()
        await sut.service.refreshLists()

        #expect(sut.service.listsLoadFailure == .server)
    }

    @Test("the detail failure is cleared when the next loadListDetail starts")
    func detailFailureClearedWhenLoadStarts() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.detailLoadFailure == .server, "precondition")
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")), held: true)

        let task = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        #expect(sut.service.detailLoadFailure == nil, "cleared at the START of the load, before it ends")
        sut.repo.releaseAll()
        await task.value
        #expect(sut.service.currentListDetail?.id == "list-a")
        #expect(sut.service.detailLoadFailure == nil)
    }

    // MARK: - Clear methods and teardown

    @Test("clearListsLoadFailure clears only the lists failure")
    func clearListsLoadFailureIsScoped() async {
        let sut = await sutWithBothFailures()

        sut.service.clearListsLoadFailure()

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == .server)
    }

    @Test("clearDetailLoadFailure clears only the detail failure")
    func clearDetailLoadFailureIsScoped() async {
        let sut = await sutWithBothFailures()

        sut.service.clearDetailLoadFailure()

        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.listsLoadFailure == .network)
    }

    @Test("the clear methods are harmless when there is nothing to clear")
    func clearWithoutFailureIsHarmless() async {
        let sut = await makeSUT()

        sut.service.clearListsLoadFailure()
        sut.service.clearDetailLoadFailure()

        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("clearForSession clears both load failures")
    func clearForSessionClearsBoth() async throws {
        let sut = await sutWithBothFailures()

        try await sut.service.clearForSession()

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("clearCache clears both load failures")
    func clearCacheClearsBoth() async {
        let sut = await sutWithBothFailures()

        await sut.service.clearCache()

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("teardown through the SessionManager clears both load failures for every reason", arguments: [
        TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback
    ])
    func teardownClearsBoth(reason: TeardownReason) async {
        let sut = await sutWithBothFailures()

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    // MARK: - Revalidation with cached data

    @Test("a lists revalidation that fails while cached lists are shown is recorded and the cached lists stay")
    func staleListsRevalidationFailureIsRecorded() async {
        let sut = await makeSUT()
        // addList does not stamp the fetch time, so the cache counts as stale and loadLists revalidates.
        await sut.store.addList(list("list-a"))
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.loadLists()

        #expect(sut.repo.fetchListsCount == 1, "a stale cache is revalidated")
        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == .network)
        #expect(sut.service.lists.map(\.id) == ["list-a"], "the cached lists stay visible")
    }

    @Test("a load inside the cache window fetches nothing and records nothing")
    func freshCacheRecordsNothing() async {
        let sut = await makeSUT()
        await sut.store.setLists([list("list-a")])
        sut.repo.enqueueFetchLists(.failure(ListError.network))   // must never be consumed

        let failure = await sut.service.loadLists()

        #expect(sut.repo.fetchListsCount == 0)
        #expect(failure == nil)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    @Test("a detail revalidation that fails while cached data is shown is recorded and the cached detail stays",
          arguments: [ListError.network, .server, .rateLimited(retryAfter: 3)])
    func detailRevalidationFailureIsRecorded(error: ListError) async {
        let sut = await makeSUT()
        let cached = detail("list-a")
        await sut.store.setListDetail(cached)
        sut.repo.enqueueFetchListDetail(.failure(error))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.repo.fetchListDetailCount == 1, "the cached detail is always revalidated")
        #expect(sut.service.detailLoadFailure == error)
        #expect(sut.service.currentListDetail == cached, "the cached detail stays visible")
        #expect(sut.service.listsLoadFailure == nil)
    }

    // MARK: - Stale results write nothing

    @Test("a load that fails after teardown stores no failure", arguments: [ListServiceOp.loadLists, .refreshLists, .loadListDetail])
    func failureAfterTeardownStoresNothing(op: ListServiceOp) async {
        let sut = await makeSUT()
        op.script(sut.repo, failing: .server)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a load that fails after a user switch stores no failure and does not touch the new user's failure")
    func userSwitchLateFailureDoesNotTouchNewSession() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server), held: true)   // user A, fails late
        sut.repo.enqueueFetchLists(.failure(ListError.network))              // user B, fails at once
        let loadA = Task { await sut.service.loadLists() }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadLists()
        #expect(sut.service.listsLoadFailure == .network, "precondition: B's own failure")
        sut.repo.releaseAll()
        await loadA.value

        #expect(sut.service.listsLoadFailure == .network, "A's late failure must not replace B's")
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a detail load that fails after a user switch does not set a failure for the new user")
    func userSwitchLateDetailFailure() async {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server), held: true)   // user A, fails late
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))               // user B
        let loadA = Task { await sut.service.loadListDetail(id: "list-a") }
        await sut.repo.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        await sut.service.loadListDetail(id: "list-a")
        sut.repo.releaseAll()
        await loadA.value

        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.currentListDetail?.id == "list-a")
    }

    @Test("a cancelled load stores no failure", arguments: [ListServiceOp.loadLists, .refreshLists, .loadListDetail])
    func cancelledLoadStoresNothing(op: ListServiceOp) async {
        let sut = await makeSUT()
        sut.repo.honorsCancellation = true
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        task.cancel()
        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }
}
