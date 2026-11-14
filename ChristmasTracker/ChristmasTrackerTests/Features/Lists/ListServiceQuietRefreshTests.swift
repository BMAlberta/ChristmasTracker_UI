//
//  ListServiceQuietRefreshTests.swift
//  ChristmasTrackerTests
//
//  I5b Story B (scope amendment): `refreshLists(reportingFailure:)`. With false the refresh returns its
//  failure and neither sets nor clears `listsLoadFailure`; the default still sets and clears it as before.
//
//  Determinism: gated fakes, plain enqueue. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService quiet refresh", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceQuietRefreshTests {

    private struct SUT {
        let service: ListService
        let repo: GatedListRepository
    }

    private func makeSUT() -> SUT {
        let repo = GatedListRepository()
        let service = ListService(repository: repo, dataStore: ListDataStore())
        return SUT(service: service, repo: repo)
    }

    private func list(_ id: String) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)")
    }

    @Test("refreshLists(reportingFailure: false) returns the failure and stores it nowhere")
    func quietFailureStoresNothing() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.refreshLists(reportingFailure: false)

        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == nil)
    }

    @Test("a quiet failing refresh leaves an existing lists failure unchanged")
    func quietFailureKeepsExistingFailure() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == .server, "precondition")
        sut.repo.enqueueFetchLists(.failure(ListError.network))

        let failure = await sut.service.refreshLists(reportingFailure: false)

        #expect(failure == .network)
        #expect(sut.service.listsLoadFailure == .server)
    }

    @Test("a quiet successful refresh updates the lists but does not clear an existing lists failure")
    func quietSuccessKeepsExistingFailure() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))
        await sut.service.refreshLists()
        #expect(sut.service.listsLoadFailure == .server, "precondition")
        sut.repo.enqueueFetchLists(.success([list("list-a")]))

        let failure = await sut.service.refreshLists(reportingFailure: false)

        #expect(failure == nil)
        #expect(sut.service.lists.map(\.id) == ["list-a"])
        #expect(sut.service.listsLoadFailure == .server)
    }

    @Test("the quiet refresh does not clear the lists failure when it starts")
    func quietRefreshDoesNotClearAtStart() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))
        await sut.service.refreshLists()
        sut.repo.enqueueFetchLists(.success([list("list-a")]), held: true)

        let task = Task { await sut.service.refreshLists(reportingFailure: false) }
        await sut.repo.nextHeldCall()

        #expect(sut.service.listsLoadFailure == .server)
        sut.repo.releaseAll()
        await task.value
        #expect(sut.service.listsLoadFailure == .server)
    }

    @Test("refreshLists() with the default still sets the failure and clears it on success")
    func defaultStillReports() async {
        let sut = makeSUT()
        sut.repo.enqueueFetchLists(.failure(ListError.server))
        let failure = await sut.service.refreshLists()
        #expect(failure == .server)
        #expect(sut.service.listsLoadFailure == .server)

        sut.repo.enqueueFetchLists(.success([list("list-a")]))
        await sut.service.refreshLists(reportingFailure: true)
        #expect(sut.service.listsLoadFailure == nil)
    }
}
