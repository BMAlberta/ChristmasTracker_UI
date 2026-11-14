//
//  ListServiceArchivedReadOnlyTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: a 422 CANNOT_EDIT_ARCHIVED_LIST (ListError.archivedReadOnly) is NOT "list gone".
//
//  From updateList, removeCoOwner, setCoOwner, addMember and removeMember the service
//  - refetches the list detail (repository.fetchListDetail) and writes currentListDetail (when it
//    is that list), the cache and the matching `lists` entry, so the flags refresh;
//  - does NOT drop the list and does NOT set goneListId;
//  - still throws the typed archivedReadOnly to the caller, even when the refetch fails.
//  notFound keeps dropping the list and setting goneListId (the existing gone-list tests).
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

/// The five operations that can meet the archived-list 422.
nonisolated enum ArchivedWriteOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case updateList, removeCoOwner, setCoOwner, addMember, removeMember

    var testDescription: String {
        switch self {
        case .updateList: "updateList"
        case .removeCoOwner: "removeCoOwner"
        case .setCoOwner: "setCoOwner"
        case .addMember: "addMember"
        case .removeMember: "removeMember"
        }
    }

    /// Queues the failing step of this operation on the repository it talks to.
    @MainActor
    func script(_ sut: MemberServiceHarness, failing error: ListError) {
        switch self {
        case .updateList, .setCoOwner:
            sut.lists.enqueueUpdateList(.failure(error))
        case .removeCoOwner:
            sut.lists.enqueueRemoveCoOwner(.failure(error))
        case .addMember:
            sut.members.enqueueAddMember(.failure(error))
        case .removeMember:
            sut.members.enqueueRemoveMember(.failure(error))
        }
    }

    @MainActor
    func run(_ sut: MemberServiceHarness) async throws {
        let id = MemberServiceHarness.listId
        switch self {
        case .updateList:
            try await sut.service.updateList(id: id, UpdateListInput(name: "Renamed", theme: nil, visibility: nil))
        case .removeCoOwner:
            try await sut.service.removeCoOwner(listId: id)
        case .setCoOwner:
            try await sut.service.setCoOwner(listId: id, email: MembersFixtures.coOwnerEmail)
        case .addMember:
            try await sut.service.addMember(listId: id, MemberServiceHarness.addInput)
        case .removeMember:
            try await sut.service.removeMember(listId: id, userId: MembersFixtures.memberUserId)
        }
    }
}

@Suite("ListService archived read-only (422)", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceArchivedReadOnlyTests {

    private typealias H = MemberServiceHarness

    // MARK: - Fixtures

    /// What the server sends after the list was archived behind the client's back: status
    /// ARCHIVED, the four management flags false, the item flags unchanged.
    private func archivedDetail() -> ListDetail {
        ListFixtures.listDetail(
            id: H.listId, name: "Name of list", status: .archived,
            flags: ListFixtures.Flags(
                canSeeGiftActivity: true, canPurchase: true, canSeeOffList: true, canCreateItem: true,
                canSeeMembers: true
            ),
            memberCount: 2
        )
    }

    /// The service holds the list, its (active, manageable) detail and the cache entry.
    private func makeSUT() async throws -> MemberServiceHarness {
        let sut = await H.make()
        try await sut.loadInitial()
        #expect(sut.service.currentListDetail?.status == .active, "precondition")
        #expect(sut.service.currentListDetail?.capabilities.canManageMembers == true, "precondition")
        return sut
    }

    // MARK: - The refetch refreshes the flags

    @Test("a 422 refetches the detail and refreshes currentListDetail, the cache and the lists entry; still throws archivedReadOnly",
          arguments: ArchivedWriteOp.allCases)
    func refetchRefreshesFlags(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        let fresh = archivedDetail()
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.success(fresh))

        await #expect(throws: ListError.archivedReadOnly) {
            try await op.run(sut)
        }

        #expect(sut.lists.fetchListDetailCount == 2, "the initial load plus exactly one refetch")
        #expect(sut.service.currentListDetail == fresh)
        #expect(sut.service.currentListDetail?.capabilities.canManageMembers == false)
        #expect(sut.service.currentListDetail?.capabilities.canCreateItem == true)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == fresh)
        let entry = try #require(sut.service.lists.first { $0.id == H.listId })
        #expect(entry == fresh.asGiftList())
        #expect(entry.status == .archived)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.first { $0.id == H.listId } == fresh.asGiftList())
        #expect(sut.service.isMutating == false)
    }

    @Test("a 422 does not drop the list and does not set goneListId", arguments: ArchivedWriteOp.allCases)
    func listIsNotDropped(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.success(archivedDetail()))

        _ = try? await op.run(sut)

        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail?.id == H.listId)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail != nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.map(\.id) == [H.listId])
    }

    // REPLACED (UX1a U2): was "a 422 is recorded in error when the refetch succeeds". The 422 is
    // thrown to the initiating view (asserted in refetchRefreshesFlags) and published nowhere.
    @Test("a 422 is thrown and not published as a load failure when the refetch succeeds", arguments: ArchivedWriteOp.allCases)
    func errorIsNotPublished(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.success(archivedDetail()))

        await #expect(throws: ListError.archivedReadOnly) {
            try await op.run(sut)
        }

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
    }

    @Test("a later load of the list is not filtered: the 422 recorded no removal", arguments: ArchivedWriteOp.allCases)
    func laterLoadNotFiltered(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.success(archivedDetail()))
        _ = try? await op.run(sut)
        sut.lists.enqueueFetchLists(.success([archivedDetail().asGiftList()]))

        await sut.service.refreshLists()

        #expect(sut.service.archivedLists.map(\.id) == [H.listId])
    }

    // MARK: - The refetch fails

    @Test("when the refetch fails the original archivedReadOnly is still thrown and the list is not dropped",
          arguments: ArchivedWriteOp.allCases, [ListError.network, .server, .notFound])
    func refetchFailureStillThrowsArchivedReadOnly(op: ArchivedWriteOp, refetchError: ListError) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.failure(refetchError))

        await #expect(throws: ListError.archivedReadOnly) {
            try await op.run(sut)
        }

        #expect(sut.lists.fetchListDetailCount == 2, "the refetch was attempted")
        #expect(sut.service.isMutating == false)
    }

    @Test("when the refetch fails with a transient error the list and its detail stay as they were",
          arguments: ArchivedWriteOp.allCases, [ListError.network, .server])
    func refetchFailureLeavesState(op: ArchivedWriteOp, refetchError: ListError) async throws {
        let sut = try await makeSUT()
        let before = sut.service.currentListDetail
        op.script(sut, failing: .archivedReadOnly)
        sut.lists.enqueueFetchListDetail(.failure(refetchError))

        _ = try? await op.run(sut)

        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail == before)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == before)
    }

    // MARK: - Only the 422 refetches

    @Test("another error does not refetch the detail", arguments: ArchivedWriteOp.allCases, [ListError.forbidden, .network, .server])
    func otherErrorsDoNotRefetch(op: ArchivedWriteOp, error: ListError) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: error)

        _ = try? await op.run(sut)

        #expect(sut.lists.fetchListDetailCount == 1, "only the initial load")
    }

    // MARK: - notFound is still gone

    @Test("notFound still drops the list and sets goneListId", arguments: ArchivedWriteOp.allCases)
    func notFoundStillDrops(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        op.script(sut, failing: .notFound)

        await #expect(throws: ListError.notFound) {
            try await op.run(sut)
        }

        #expect(sut.service.goneListId == H.listId)
        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
        #expect(sut.lists.fetchListDetailCount == 1, "a gone list is not refetched")
    }

    // MARK: - A different list is open

    @Test("a 422 on a list that is not the open one leaves currentListDetail alone", arguments: [ArchivedWriteOp.updateList, .removeCoOwner])
    func otherOpenDetailUntouched(op: ArchivedWriteOp) async throws {
        let sut = try await makeSUT()
        let open = sut.service.currentListDetail
        switch op {
        case .removeCoOwner:
            sut.lists.enqueueRemoveCoOwner(.failure(ListError.archivedReadOnly))
        default:
            sut.lists.enqueueUpdateList(.failure(ListError.archivedReadOnly))
        }
        sut.lists.enqueueFetchListDetail(.success(
            ListFixtures.listDetail(id: H.otherListId, name: "Other", status: .archived)
        ))

        switch op {
        case .removeCoOwner:
            _ = try? await sut.service.removeCoOwner(listId: H.otherListId)
        default:
            _ = try? await sut.service.updateList(
                id: H.otherListId, UpdateListInput(name: "X", theme: nil, visibility: nil)
            )
        }

        #expect(sut.service.currentListDetail == open)
        #expect(sut.service.goneListId == nil)
    }
}
