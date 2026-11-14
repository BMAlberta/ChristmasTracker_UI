//
//  ScopedMutationErrorStateTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3 (scoped errors): a failed MUTATION (add member and every other ListService mutation)
//  never reaches the load presentation of another screen. After a failed mutation the service holds no
//  load failure, so the dashboard and the list detail states built from the service's values are both
//  empty, while the thrown error becomes the initiating view's own MutationBanner. Fake data only.
//
//  ASSUMPTION (reported): DashboardLoadState.make and ListDetailLoadState.make return a
//  ScreenLoadPresentation (see their tests).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Scoped mutation error state Tests", .timeLimit(.minutes(1)))
@MainActor
struct ScopedMutationErrorStateTests {

    private typealias H = MemberServiceHarness

    private func makeSUT() async throws -> MemberServiceHarness {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.managerFlags))
        return sut
    }

    private func dashboardState(_ sut: MemberServiceHarness) -> ScreenLoadPresentation {
        DashboardLoadState.make(
            hasCachedLists: !sut.service.lists.isEmpty,
            listsFailure: sut.service.listsLoadFailure,
            archiveFailure: nil,
            dismissed: DismissedLoads()
        )
    }

    private func detailState(_ sut: MemberServiceHarness) -> ScreenLoadPresentation {
        ListDetailLoadState.make(
            hasDetail: sut.service.currentListDetail != nil,
            detailFailure: sut.service.detailLoadFailure,
            refreshFailure: nil,
            itemsFailure: nil,
            dismissed: DismissedLoads()
        )
    }

    private func expectEmpty(_ state: ScreenLoadPresentation, _ screen: String) {
        #expect(state.banners.isEmpty, "\(screen) banners")
        #expect(state.fullError == nil, "\(screen) fullError")
        #expect(state.leavesScreen == false, "\(screen) leavesScreen")
        #expect(state.signInTakesOver == false, "\(screen) signInTakesOver")
    }

    @Test("a failed add-member leaves the dashboard and the list detail load states empty")
    func failedAddMemberShowsOnNeitherLoadState() async throws {
        let sut = try await makeSUT()
        sut.members.enqueueAddMember(.failure(ListError.alreadyMember))

        await #expect(throws: ListError.alreadyMember) {
            try await sut.service.addMember(listId: H.listId, H.addInput)
        }

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        expectEmpty(dashboardState(sut), "dashboard")
        expectEmpty(detailState(sut), "list detail")
    }

    @Test("a failed add-member becomes the sheet's own banner with the typed error's message")
    func failedAddMemberIsTheSheetsBanner() async throws {
        let sut = try await makeSUT()
        sut.members.enqueueAddMember(.failure(ListError.memberEmailNotFound))
        var thrown: ListError?

        do {
            try await sut.service.addMember(listId: H.listId, H.addInput)
        } catch let error as ListError {
            thrown = error
        }

        let error = try #require(thrown)
        let banner = try #require(MutationBanner.state(for: error))
        #expect(banner.message == ListError.memberEmailNotFound.userMessage)
        expectEmpty(dashboardState(sut), "dashboard")
        expectEmpty(detailState(sut), "list detail")
    }

    @Test("a failed mutation of every kind leaves both load states empty",
          arguments: ListMutation.allCases,
          [ListError.network, .server, .forbidden, .rateLimited(retryAfter: 3), .validation(message: "Fake")])
    func everyMutationLeavesLoadStatesEmpty(op: ListMutation, error: ListError) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: error)

        await #expect(throws: error) {
            try await op.run(sut)
        }

        expectEmpty(dashboardState(sut), "dashboard")
        expectEmpty(detailState(sut), "list detail")
    }

    @Test("an existing dashboard failure is not changed by a failed add-member")
    func addMemberDoesNotTouchTheDashboardFailure() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueFetchLists(.failure(ListError.network))
        await sut.service.refreshLists()
        let before = dashboardState(sut)
        sut.members.enqueueAddMember(.failure(ListError.server))

        _ = try? await sut.service.addMember(listId: H.listId, H.addInput)

        #expect(dashboardState(sut) == before)
        #expect(before.banners.count == 1, "precondition: the dashboard shows its own load failure")
        expectEmpty(detailState(sut), "list detail")
    }

    @Test("a failed archive is the dashboard's own mutation banner and never a load banner")
    func failedArchiveIsNotALoadBanner() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueDeleteList(.failure(ListError.network))
        var thrown: ListError?

        do {
            try await sut.service.deleteList(id: H.listId)
        } catch let error as ListError {
            thrown = error
        }

        let error = try #require(thrown)
        let load = DashboardLoadState.make(
            hasCachedLists: true,
            listsFailure: sut.service.listsLoadFailure,
            archiveFailure: error,
            dismissed: DismissedLoads()
        )
        expectEmpty(load, "dashboard load presentation")
        #expect(MutationBanner.state(for: error)?.message == ListError.network.userMessage)
    }
}
