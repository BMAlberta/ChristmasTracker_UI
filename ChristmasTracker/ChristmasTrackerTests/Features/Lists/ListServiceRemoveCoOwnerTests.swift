//
//  ListServiceRemoveCoOwnerTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-2 R2: ListService.removeCoOwner(listId:).
//
//  - The returned detail (flags included) replaces currentListDetail (same id), the lists entry
//    and the cache entry; NO refetch.
//  - isMutating is true only while the call runs.
//  - Errors are rethrown, recorded, and leave the state alone, except notFound and
//    archivedReadOnly, which drop the list through the gone-list path.
//  - Session safety: a result or failure that arrives after teardown or a user switch writes
//    nothing; cancellation sets no error.
//  - The removal-sequence guard: a list dropped while the call was in flight is not written back.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//
//  Story I3c-A changes (named; reason: decision "a 422 CANNOT_EDIT_ARCHIVED_LIST is NOT list gone"
//  and "an archive records no removal"):
//  - goneListIsDropped is parameterized over notFound only (archivedReadOnly now refetches, see
//    ListServiceArchivedReadOnlyTests).
//  - The two removal-sequence tests that used deleteList as the removal now use leaveList.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService removeCoOwner", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceRemoveCoOwnerTests {

    private typealias H = MemberServiceHarness

    // MARK: - Factory and fixtures

    private func makeSUT(honorsCancellation: Bool = false) async throws -> MemberServiceHarness {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        try await sut.loadInitial(try withCoOwner())
        return sut
    }

    /// The loaded detail: the owner's view, a co-owner exists, the owner may set it.
    private func withCoOwner() throws -> ListDetail {
        try MembersFixtures.detail(
            flags: H.managerFlags,
            roster: [MembersFixtures.ownerRow(), MembersFixtures.coOwnerRow(), MembersFixtures.memberRow()],
            hasCoOwner: true,
            memberCount: 3
        )
    }

    /// What the server returns after the removal: no co-owner, flags recomputed (deliberately
    /// different from the loaded ones so the returned flags must win).
    private func withoutCoOwner() throws -> ListDetail {
        try MembersFixtures.detail(
            flags: MembersFixtures.SectionFlags(
                canSeeMembers: true, canManageMembers: false, canLeaveList: false, canSetCoOwner: false
            ),
            roster: [MembersFixtures.ownerRow(), MembersFixtures.memberRow()],
            hasCoOwner: false,
            memberCount: 2
        )
    }

    private func expectCleared(_ sut: MemberServiceHarness) async {
        #expect(sut.service.lists.isEmpty, "lists must stay empty")
        #expect(sut.service.currentListDetail == nil, "currentListDetail must stay nil")
        #expect(sut.service.listsLoadFailure == nil, "no failure may be set after the session ended")
        #expect(sut.service.detailLoadFailure == nil, "no failure may be set after the session ended")
        #expect(sut.service.goneListId == nil, "a stale call must not mark a list gone")
        #expect(sut.service.isMutating == false)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty, "the cache must not receive a stale result")
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil, "the cache must not hold a stale detail")
    }

    // MARK: - Success

    @Test("removeCoOwner calls the list repository once with the list id")
    func callsRepositoryOnce() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()))

        try await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.lists.removeCoOwnerCount == 1)
        #expect(sut.lists.removedCoOwnerListIds == [H.listId])
        #expect(sut.lists.updateListCount == 0, "clearing must not go through updateList")
        #expect(sut.members.addMemberCount == 0)
        #expect(sut.members.removeMemberCount == 0)
    }

    @Test("removeCoOwner uses the returned detail, flags included, for the service, the lists entry and the cache; no refetch")
    func usesReturnedDetail() async throws {
        let sut = try await makeSUT()
        let returned = try withoutCoOwner()
        sut.lists.enqueueRemoveCoOwner(.success(returned))
        let fetchesBefore = sut.lists.fetchListDetailCount
        let listFetchesBefore = sut.lists.fetchListsCount

        try await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.service.currentListDetail == returned)
        #expect(sut.service.currentListDetail?.coOwner == nil)
        #expect(sut.service.currentListDetail?.capabilities == returned.capabilities)
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == returned)
        #expect(sut.service.lists.first(where: { $0.id == H.listId }) == returned.asGiftList())
        #expect(sut.lists.fetchListDetailCount == fetchesBefore, "removeCoOwner must not refetch the detail")
        #expect(sut.lists.fetchListsCount == listFetchesBefore, "removeCoOwner must not refetch the lists")
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("removeCoOwner for a list that is not the open one leaves currentListDetail alone")
    func otherListKeepsCurrent() async throws {
        let sut = try await makeSUT()
        let initial = sut.service.currentListDetail
        let returned = ListFixtures.listDetail(id: H.otherListId)
        sut.lists.enqueueRemoveCoOwner(.success(returned))

        try await sut.service.removeCoOwner(listId: H.otherListId)

        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.currentListDetail?.id == H.listId)
        #expect(sut.service.lists.map(\.id) == [H.listId], "an unknown list is not added to the lists")
    }

    // REWRITTEN (UX1a U2): the failure is thrown (never stored), so a retry that succeeds has
    // nothing to clear; neither step publishes a load failure.
    @Test("removeCoOwner failing then succeeding publishes nothing at either step")
    func clearsPreviousError() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.failure(ListError.network))
        await #expect(throws: ListError.network) {
            try await sut.service.removeCoOwner(listId: H.listId)
        }
        #expect(sut.service.anyLoadFailure == nil, "precondition: the failure was only thrown")
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()))

        try await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.service.anyLoadFailure == nil)
    }

    // MARK: - Failure

    // REWRITTEN (UX1a U2): throws the typed error, publishes nothing.
    @Test("removeCoOwner failing rethrows, publishes nothing and leaves the state alone", arguments: [
        ListError.forbidden, .network, .server, .unauthorized, .invalidResponse, .rateLimited(retryAfter: 3)
    ])
    func failureLeavesStateAlone(error: ListError) async throws {
        let sut = try await makeSUT()
        let initial = sut.service.currentListDetail
        sut.lists.enqueueRemoveCoOwner(.failure(error))

        await #expect(throws: error) {
            try await sut.service.removeCoOwner(listId: H.listId)
        }

        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.detailLoadFailure == nil)
        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.goneListId == nil)
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == initial)
        #expect(sut.service.isMutating == false)
        #expect(sut.lists.fetchListDetailCount == 1, "no refetch after a failure either")
    }

    // CHANGED (I3c-A): archivedReadOnly removed from the arguments (it no longer drops the list).
    @Test("notFound drops the list through the gone-list path", arguments: [
        ListError.notFound
    ])
    func goneListIsDropped(error: ListError) async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.failure(error))

        await #expect(throws: error) {
            try await sut.service.removeCoOwner(listId: H.listId)
        }

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == H.listId)
        #expect(sut.service.anyLoadFailure == nil, "a mutation publishes nothing, even when it drops the list")
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
        #expect(sut.service.isMutating == false)
    }

    @Test("a different failing list is the one dropped; other lists stay")
    func goneListDropsOnlyThatList() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueFetchLists(.success([
            ListFixtures.giftList(id: H.listId, name: "Name of list"),
            ListFixtures.giftList(id: H.otherListId, name: "Name of other")
        ]))
        await sut.service.refreshLists()
        sut.lists.enqueueRemoveCoOwner(.failure(ListError.notFound))

        await #expect(throws: ListError.notFound) {
            try await sut.service.removeCoOwner(listId: H.otherListId)
        }

        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail?.id == H.listId)
        #expect(sut.service.goneListId == H.otherListId)
    }

    // MARK: - isMutating

    @Test("isMutating is true only while the call runs; the load flags stay false")
    func isMutatingOnlyDuringCall() async throws {
        let sut = try await makeSUT()
        #expect(sut.service.isMutating == false, "precondition")
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)

        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        #expect(sut.service.isMutating == true)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)

        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.isMutating == false)
    }

    @Test("isMutating is false again after a failed call")
    func isMutatingFalseAfterFailure() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.failure(ListError.server))

        _ = try? await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.service.isMutating == false)
    }

    // MARK: - Session safety

    @Test("a call that completes after teardown writes nothing", arguments: [false, true])
    func inFlightSuccessAfterTeardown(honorsCancellation: Bool) async throws {
        let sut = try await makeSUT(honorsCancellation: honorsCancellation)
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.lists.releaseAll()
        await task.value

        await expectCleared(sut)
    }

    @Test("a call that fails after teardown sets no error and marks nothing gone", arguments: [
        ListError.server, .network, .forbidden, .notFound, .archivedReadOnly
    ])
    func inFlightFailureAfterTeardown(error: ListError) async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.failure(error), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        await sut.manager.teardown(reason: .sessionExpired)
        sut.lists.releaseAll()
        await task.value
        await expectCleared(sut)

        // The next session sees the same list id: the stale failure must not have poisoned the guard.
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: H.listId, name: "Name of list")]))
        await sut.service.loadLists()
        #expect(sut.service.lists.map(\.id) == [H.listId])
    }

    @Test("after a call discarded by teardown, the next load goes to the repository")
    func nextLoadAfterDiscardedCall() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()
        await sut.manager.teardown(reason: .userLogout)
        sut.lists.releaseAll()
        await task.value
        let before = sut.lists.fetchListsCount
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: "list-b", name: "Name of list-b")]))

        await sut.service.loadLists()

        #expect(sut.lists.fetchListsCount == before + 1)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.anyLoadFailure == nil)
    }

    @Test("user switch: A's late result never touches B's lists, cache or error")
    func userSwitch() async throws {
        let sut = try await makeSUT()                                                  // user A
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: "list-b", name: "Name of list-b")]))
        await sut.service.loadLists()                                                  // user B
        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's data must not replace or join B's")
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.goneListId == nil)
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
    }

    @Test("user switch: A's late result does not overwrite a list B happens to share by id")
    func userSwitchSharedId() async throws {
        let sut = try await makeSUT()                                                  // user A
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        await sut.manager.teardown(reason: .userLogout)
        let sameId = ListFixtures.giftList(id: H.listId, name: "Name of list")
        sut.lists.enqueueFetchLists(.success([sameId]))
        await sut.service.loadLists()                                                  // user B sees the same id
        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.lists == [sameId], "B's entry is untouched by A's late result")
        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
    }

    @Test("cancelling the caller sets no error and leaves the state alone")
    func cancellationSetsNoError() async throws {
        let sut = try await makeSUT(honorsCancellation: true)
        let initial = sut.service.currentListDetail
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        task.cancel()
        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.anyLoadFailure == nil, "cancellation is not shown to the user")
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail == initial)
    }

    @Test("a repository that fails with CancellationError sets no error and leaves the state alone")
    func repositoryCancellationErrorSetsNoError() async throws {
        let sut = try await makeSUT()
        let initial = sut.service.currentListDetail
        sut.lists.enqueueRemoveCoOwner(.failure(CancellationError()))

        _ = try? await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.service.anyLoadFailure == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail == initial)
    }

    // MARK: - Removal-sequence guard

    // CHANGED (I3c-A): the removal is a leave (was a delete); an archive records no removal.
    @Test("a list left while removeCoOwner was in flight is not written back")
    func listDroppedWhileInFlightIsNotWrittenBack() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        sut.members.enqueueRemoveMember(.success(()))
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        try await sut.service.leaveList(id: H.listId, userId: "user-me")
        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil, "the late detail must not be cached for a removed list")
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
    }

    @Test("a list dropped by a gone-list failure while removeCoOwner was in flight is not written back")
    func listGoneWhileInFlightIsNotWrittenBack() async throws {
        let sut = try await makeSUT()
        sut.lists.enqueueRemoveCoOwner(.success(try withoutCoOwner()), held: true)
        sut.lists.enqueueUpdateList(.failure(ListError.notFound))
        let task = Task { _ = try? await sut.service.removeCoOwner(listId: H.listId) }
        await sut.lists.nextHeldCall()

        await #expect(throws: ListError.notFound) {
            try await sut.service.updateList(id: H.listId, UpdateListInput(name: "Other Name", theme: nil, visibility: nil))
        }
        sut.lists.releaseAll()
        await task.value

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
    }

    @Test("a removal that completed before removeCoOwner started does not filter its result")
    func earlierRemovalDoesNotFilter() async throws {
        let sut = try await makeSUT()
        sut.members.enqueueRemoveMember(.success(()))
        try await sut.service.leaveList(id: H.listId, userId: "user-me")
        // The list is back (for example the member was re-added): a later load shows it.
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: H.listId, name: "Name of list")]))
        await sut.service.loadLists()
        let returned = try withoutCoOwner()
        sut.lists.enqueueRemoveCoOwner(.success(returned))

        try await sut.service.removeCoOwner(listId: H.listId)

        #expect(sut.service.lists.first(where: { $0.id == H.listId }) == returned.asGiftList())
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == returned)
        #expect(sut.service.anyLoadFailure == nil)
    }
}
