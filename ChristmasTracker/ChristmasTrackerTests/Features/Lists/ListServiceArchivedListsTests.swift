//
//  ListServiceArchivedListsTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListService keeps ALL non-removed lists in `lists` (ACTIVE, DRAFT and ARCHIVED)
//  and derives `activeLists` (ACTIVE and DRAFT) and `archivedLists` (ARCHIVED), both in the order
//  of `lists`. Loads, refreshes and cached loads no longer drop ARCHIVED lists. `filteredLists`
//  keeps its owned/shared filter over `lists`.
//
//  Determinism: scripted GatedListRepository, no sleeps. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService archived lists", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchivedListsTests {

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

    private func list(
        _ id: String,
        status: ListStatus = .active,
        flags: ListFixtures.Flags = ListFixtures.Flags()
    ) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: status, flags: flags)
    }

    private var mixed: [GiftList] {
        [
            list("list-a1"), list("list-z1", status: .archived), list("list-d1", status: .draft),
            list("list-z2", status: .archived), list("list-a2")
        ]
    }

    // MARK: - Derived lists

    @Test("activeLists and archivedLists start empty")
    func startEmpty() {
        let sut = makeSUT()
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.activeLists.isEmpty)
        #expect(sut.service.archivedLists.isEmpty)
    }

    @Test("loadLists keeps every list; activeLists holds ACTIVE and DRAFT, archivedLists holds ARCHIVED, in order")
    func loadKeepsAllAndDerives() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success(mixed))

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-a1", "list-z1", "list-d1", "list-z2", "list-a2"])
        #expect(sut.service.activeLists.map(\.id) == ["list-a1", "list-d1", "list-a2"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-z1", "list-z2"])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-a1", "list-z1", "list-d1", "list-z2", "list-a2"])
        #expect(sut.service.error == nil)
    }

    @Test("refreshLists keeps every list and derives the two groups")
    func refreshKeepsAllAndDerives() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a1")]))
        sut.repo.enqueueFetchLists(.success(mixed))
        await sut.service.loadLists()

        await sut.service.refreshLists()

        #expect(sut.service.activeLists.map(\.id) == ["list-a1", "list-d1", "list-a2"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-z1", "list-z2"])
        let cached = await sut.store.getLists()
        #expect(cached.count == 5)
    }

    @Test("a cached load keeps the archived lists too and does not fetch")
    func cachedLoadKeepsArchived() async {
        let sut = makeSUT()
        await sut.store.setLists(mixed)

        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == ["list-a1", "list-z1", "list-d1", "list-z2", "list-a2"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-z1", "list-z2"])
        #expect(sut.repo.fetchListsCount == 0)
    }

    @Test("a response with only ARCHIVED lists leaves activeLists empty and archivedLists full, without an error")
    func onlyArchived() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-z1", status: .archived)]))

        await sut.service.loadLists()

        #expect(sut.service.activeLists.isEmpty)
        #expect(sut.service.archivedLists.map(\.id) == ["list-z1"])
        #expect(sut.service.error == nil)
    }

    @Test("DRAFT counts as active and never as archived")
    func draftIsActive() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-d1", status: .draft)]))

        await sut.service.loadLists()

        #expect(sut.service.activeLists.map(\.id) == ["list-d1"])
        #expect(sut.service.archivedLists.isEmpty)
    }

    @Test("a status change in a later refresh moves the list between the two groups")
    func statusChangeMovesList() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a"), list("list-b")]))
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived), list("list-b")]))
        await sut.service.loadLists()
        #expect(sut.service.activeLists.map(\.id) == ["list-a", "list-b"], "precondition")

        await sut.service.refreshLists()

        #expect(sut.service.activeLists.map(\.id) == ["list-b"])
        #expect(sut.service.archivedLists.map(\.id) == ["list-a"])
    }

    @Test("every list is in exactly one of the two groups")
    func groupsPartitionLists() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success(mixed))

        await sut.service.loadLists()

        let union = Set(sut.service.activeLists.map(\.id)).union(sut.service.archivedLists.map(\.id))
        #expect(union == Set(sut.service.lists.map(\.id)))
        #expect(sut.service.activeLists.count + sut.service.archivedLists.count == sut.service.lists.count)
    }

    // MARK: - filteredLists keeps its owned/shared filter over all lists

    @Test("filteredLists applies owned and shared over ALL lists, archived included")
    func filteredListsOverAllLists() async {
        let sut = makeSUT()
        let managing = ListFixtures.Flags(canEditList: true, canDeleteList: true, canManageMembers: true)
        // An archived list has the management flags false, so it is "shared" by the flags.
        sut.repo.enqueueFetchLists(.success([
            list("list-owned", flags: managing),
            list("list-archived", status: .archived),
            list("list-shared")
        ]))
        await sut.service.loadLists()

        sut.service.currentFilter = .all
        #expect(sut.service.filteredLists.map(\.id) == ["list-owned", "list-archived", "list-shared"])
        sut.service.currentFilter = .owned
        #expect(sut.service.filteredLists.map(\.id) == ["list-owned"])
        sut.service.currentFilter = .shared
        #expect(sut.service.filteredLists.map(\.id) == ["list-archived", "list-shared"])
    }

    // MARK: - Detail of an archived list is shown normally

    @Test("loadListDetail of an archived list shows it, caches it and updates its summary")
    func archivedDetailIsShown() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.success([list("list-a", status: .archived)]))
        let detail = ListFixtures.listDetail(
            id: "list-a", name: "Name of list-a", status: .archived, flags: ListFixtures.Flags(canCreateItem: true)
        )
        sut.repo.enqueueFetchListDetail(.success(detail))
        await sut.service.loadLists()

        await sut.service.loadListDetail(id: "list-a")

        #expect(sut.service.currentListDetail == detail)
        #expect(sut.service.error == nil)
        #expect(sut.service.goneListId == nil)
        let cachedDetail = await sut.store.getListDetail(id: "list-a")
        #expect(cachedDetail == detail)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.first == detail.asGiftList(), "an archived detail no longer skips the summary cache")
        #expect(sut.service.lists.map(\.id) == ["list-a"])
    }
}
