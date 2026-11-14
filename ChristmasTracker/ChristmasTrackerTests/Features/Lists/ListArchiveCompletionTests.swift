//
//  ListArchiveCompletionTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A fix pass, rewritten for UX1a Story U3.
//
//  History: these tests once covered a helper that decided what the detail screen did after
//  deleteList returned normally, based on a shared service error. Both the helper and the shared
//  error no longer exist.
//
//  Now: deleteList that returns normally IS the completion, so the screen dismisses. The follow-up
//  reload failure is published nowhere, so neither the dashboard nor the list detail load state shows
//  it, and a thrown archive failure is the screen's own MutationBanner. Equivalent service-level
//  coverage also lives in ListServiceArchiveTests. Fake data only.
//
//  ASSUMPTION (reported): DashboardLoadState.make and ListDetailLoadState.make return a
//  ScreenLoadPresentation.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("List archive completion", .timeLimit(.minutes(1)))
@MainActor
struct ListArchiveCompletionTests {

    private typealias H = MemberServiceHarness

    private func makeSUT() async throws -> MemberServiceHarness {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        return sut
    }

    private func loadStates(_ sut: MemberServiceHarness) -> [ScreenLoadPresentation] {
        [
            DashboardLoadState.make(
                hasCachedLists: !sut.service.lists.isEmpty,
                listsFailure: sut.service.listsLoadFailure,
                archiveFailure: nil,
                dismissed: DismissedLoads()
            ),
            ListDetailLoadState.make(
                hasDetail: sut.service.currentListDetail != nil,
                detailFailure: sut.service.detailLoadFailure(forListId: H.listId),
                refreshFailure: nil,
                itemsFailure: nil,
                dismissed: DismissedLoads()
            )
        ]
    }

    @Test("an archive that returns normally leaves both load states empty: the screen simply dismisses")
    func normalReturnShowsNothing() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueDeleteList(.success(()))
        sut.lists.enqueueFetchLists(.success([]))
        // UX1b B0: an unscripted detail refetch fails and is now recorded, so script a good one.
        sut.lists.enqueueFetchListDetail(.success(try H.detail(flags: H.managerFlags)))

        try await sut.service.deleteList(id: H.listId)

        for state in loadStates(sut) {
            #expect(state.banners.isEmpty)
            #expect(state.fullError == nil)
        }
    }

    // REWRITTEN (UX1b B0): the failed lists reload is now recorded as the dashboard's lists failure
    // (it is not shown by the list detail screen) and still does not block the dismissal.
    @Test("a failed reload after a successful archive is recorded for the dashboard only and does not block the dismissal",
          arguments: [ListError.network, .server, .rateLimited(retryAfter: 3), .invalidResponse, .unauthorized])
    func reloadFailureIsRecordedForTheDashboardOnly(error: ListError) async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueDeleteList(.success(()))
        sut.lists.enqueueFetchLists(.failure(error))
        // UX1b B0: an unscripted detail refetch fails and is now recorded, so script a good one.
        sut.lists.enqueueFetchListDetail(.success(try H.detail(flags: H.managerFlags)))

        try await sut.service.deleteList(id: H.listId)   // must not throw: the screen dismisses

        #expect(sut.service.listsLoadFailure == error)
        #expect(sut.service.detailLoadFailure(forListId: H.listId) == nil)
        let detailState = loadStates(sut)[1]
        #expect(detailState.banners.isEmpty)
        #expect(detailState.fullError == nil)
        #expect(detailState.leavesScreen == false)
        #expect(detailState.signInTakesOver == false)
    }

    @Test("a thrown archive failure is the screen's own mutation banner and stays out of the load states",
          arguments: [ListError.network, .server, .forbidden, .archivedReadOnly])
    func thrownFailureIsAMutationBanner(error: ListError) async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueDeleteList(.failure(error))
        var thrown: ListError?

        do {
            try await sut.service.deleteList(id: H.listId)
        } catch let caught as ListError {
            thrown = caught
        }

        let failure = try #require(thrown)
        #expect(MutationBanner.state(for: failure)?.message == error.userMessage)
        for state in loadStates(sut) {
            #expect(state.banners.isEmpty)
            #expect(state.fullError == nil)
        }
    }
}
