//
//  ListServiceKeyedDetailFailureTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B0 (gap 3): the detail load failure is keyed by list id. A failure for list A is
//  never returned for list B; loading B does not clear A's entry; the keyed clear removes one id;
//  the unkeyed clear and a session reset remove every entry.
//
//  Determinism: scripted fakes only. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService keyed detail load failures", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceKeyedDetailFailureTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let manager: SessionManager
    }

    private func makeSUT() async -> SUT {
        let repo = GatedListRepository()
        let service = ListService(repository: repo, dataStore: ListDataStore())
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return SUT(service: service, repo: repo, manager: manager)
    }

    private func detail(_ id: String) -> ListDetail {
        ListFixtures.listDetail(id: id, name: "Name of \(id)")
    }

    /// list-a failed with .server and list-b failed with .network.
    private func sutWithTwoFailures() async -> SUT {
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))
        sut.repo.enqueueFetchListDetail(.failure(ListError.network))
        await sut.service.loadListDetail(id: "list-a")
        await sut.service.loadListDetail(id: "list-b")
        return sut
    }

    // MARK: - (5) keyed by id

    @Test("a failure for list A is not returned for list B")
    func failureForAIsNotReturnedForB() async {
        // Old behavior: one shared slot, so list A's failure was presented on list B.
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == .server)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == nil)
    }

    @Test("loading list B does not clear list A's failure")
    func loadingBDoesNotClearA() async {
        // Old behavior: starting any detail load cleared the single shared slot.
        let sut = await makeSUT()
        sut.repo.enqueueFetchListDetail(.failure(ListError.server))
        await sut.service.loadListDetail(id: "list-a")
        sut.repo.enqueueFetchListDetail(.success(detail("list-b")))

        await sut.service.loadListDetail(id: "list-b")

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == .server)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == nil)
    }

    @Test("each list keeps its own failure")
    func eachListKeepsItsOwnFailure() async {
        // Old behavior: the second failure overwrote the first in the single shared slot.
        let sut = await sutWithTwoFailures()

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == .server)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == .network)
    }

    @Test("a successful reload of list A clears only list A's failure")
    func successfulLoadClearsOnlyOwnEntry() async {
        // Old behavior: a detail load start cleared the single shared slot.
        let sut = await sutWithTwoFailures()
        sut.repo.enqueueFetchListDetail(.success(detail("list-a")))

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == nil)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == .network)
    }

    @Test("clearDetailLoadFailure(forListId:) removes only that id's entry")
    func keyedClearRemovesOneEntry() async {
        // Old behavior: the only clear removed the single shared slot.
        let sut = await sutWithTwoFailures()

        sut.service.clearDetailLoadFailure(forListId: "list-a")

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == nil)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == .network)
    }

    @Test("clearDetailLoadFailure(forListId:) for an id with no entry is harmless")
    func keyedClearWithoutEntryIsHarmless() async {
        // Old behavior: no keyed clear existed.
        let sut = await sutWithTwoFailures()

        sut.service.clearDetailLoadFailure(forListId: "list-unknown")

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == .server)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == .network)
    }

    @Test("clearDetailLoadFailure() removes every entry")
    func unkeyedClearRemovesAll() async {
        // Old behavior: the unkeyed clear removed the single slot; it must now remove all entries.
        let sut = await sutWithTwoFailures()

        sut.service.clearDetailLoadFailure()

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == nil)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == nil)
    }

    // MARK: - (6) session reset

    @Test("teardown through the SessionManager clears every keyed failure", arguments: [
        TeardownReason.userLogout, .sessionExpired, .forcedUpdate, .lockFallback
    ])
    func teardownClearsAllKeyedFailures(reason: TeardownReason) async {
        // Old behavior: teardown cleared the single shared slot.
        let sut = await sutWithTwoFailures()

        await sut.manager.teardown(reason: reason)

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == nil)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == nil)
    }

    @Test("clearCache clears every keyed failure")
    func clearCacheClearsAllKeyedFailures() async {
        // Old behavior: clearCache cleared the single shared slot.
        let sut = await sutWithTwoFailures()

        await sut.service.clearCache()

        #expect(sut.service.detailLoadFailure(forListId: "list-a") == nil)
        #expect(sut.service.detailLoadFailure(forListId: "list-b") == nil)
    }
}
