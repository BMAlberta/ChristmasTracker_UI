//
//  ListServiceLoadingFlagsTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: ListService exposes three independent busy flags instead of one `isLoading`:
//  `isLoadingLists` (loadLists only), `isLoadingDetail` (loadListDetail only) and `isMutating`
//  (createList, updateList, deleteList). refreshLists keeps using `isRefreshing`.
//
//  Determinism: every in-flight call is held by GatedListRepository; the test waits on
//  `nextHeldCall()` (continuation handshake), reads the flags while the call is inside the
//  repository, then releases it. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService loading flags", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceLoadingFlagsTests {

    // MARK: - Factory

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
        let store: ListDataStore
    }

    private func makeSUT() -> SUT {
        let repo = GatedListRepository()
        let store = ListDataStore()
        return SUT(service: ListService(repository: repo, dataStore: store), repo: repo, store: store)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    nonisolated static let mutatingOps: [ListServiceOp] = [.createList, .updateList, .deleteList]

    // MARK: - Mutations

    @Test("during an in-flight create, update or delete only isMutating is true", arguments: ListServiceLoadingFlagsTests.mutatingOps)
    func mutatingFlagOnly(op: ListServiceOp) async {
        let sut = makeSUT()
        op.script(sut.repo, failing: nil)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isMutating == true)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isRefreshing == false)

        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is reset after a failed in-flight mutation", arguments: ListServiceLoadingFlagsTests.mutatingOps)
    func mutatingFlagResetsOnFailure(op: ListServiceOp) async {
        let sut = makeSUT()
        op.script(sut.repo, failing: .server)
        let task = Task { await op.run(sut.service) }
        await sut.repo.nextHeldCall()
        #expect(sut.service.isMutating == true)

        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isMutating == false)
        #expect(sut.service.anyLoadFailure == nil, "a mutation failure is thrown, never published")
    }

    // MARK: - Detail

    @Test("during an in-flight loadListDetail only isLoadingDetail is true")
    func detailFlagOnly() async {
        let sut = makeSUT()
        ListServiceOp.loadListDetail.script(sut.repo, failing: nil)
        let task = Task { await ListServiceOp.loadListDetail.run(sut.service) }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isLoadingDetail == true)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.isRefreshing == false)

        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.currentListDetail?.id == "list-a")
    }

    // MARK: - Lists

    @Test("during an in-flight loadLists only isLoadingLists is true")
    func listsFlagOnly() async {
        let sut = makeSUT()
        ListServiceOp.loadLists.script(sut.repo, failing: nil)
        let task = Task { await ListServiceOp.loadLists.run(sut.service) }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isLoadingLists == true)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.isRefreshing == false)

        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }

    // MARK: - Refresh

    @Test("during a refreshLists isLoadingDetail stays false and currentListDetail is not cleared")
    func refreshDoesNotBlankDetail() async {
        let sut = makeSUT()
        let detail = ListFixtures.listDetail(id: "list-a", name: "Name of list-a")
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchListDetail(.success(detail))
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]), held: true)
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: "list-a")
        #expect(sut.service.currentListDetail == detail, "precondition")

        let task = Task { await sut.service.refreshLists() }
        await sut.repo.nextHeldCall()

        #expect(sut.service.isRefreshing == true)
        #expect(sut.service.isLoadingDetail == false)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.currentListDetail == detail, "a refresh must not blank the open detail")

        sut.repo.releaseAll()
        await task.value

        #expect(sut.service.isRefreshing == false)
        #expect(sut.service.currentListDetail == detail)
    }
}
