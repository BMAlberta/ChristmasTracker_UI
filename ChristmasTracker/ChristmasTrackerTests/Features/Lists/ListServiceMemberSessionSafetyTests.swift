//
//  ListServiceMemberSessionSafetyTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the member operations of ListService are safe against sign-out, user switching
//  and cancellation. Teardown runs the way the app does it: SessionManager.teardown(reason:)
//  calls ListService.clearForSession().
//
//  Determinism: every in-flight call is held by a gated fake; the test waits for the handshake
//  before it tears the session down, and releases the held call explicitly. No sleeps, no yield
//  loops. A suite time limit turns a hang into a failure.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService member operations session safety", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceMemberSessionSafetyTests {

    private typealias H = MemberServiceHarness

    private func expectCleared(_ sut: MemberServiceHarness) async {
        #expect(sut.service.lists.isEmpty, "lists must stay empty")
        #expect(sut.service.currentListDetail == nil, "currentListDetail must stay nil")
        #expect(sut.service.error == nil, "no error may be set after the session ended")
        #expect(sut.service.goneListId == nil, "a stale call must not mark a list gone")
        #expect(sut.service.isMutating == false)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty, "the cache must not receive a stale result")
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil, "the cache must not hold a stale detail")
    }

    // MARK: - Teardown during an in-flight operation

    @Test(
        "an operation that completes after teardown writes nothing",
        arguments: MemberServiceOp.allCases, [false, true]
    )
    func inFlightSuccessAfterTeardown(op: MemberServiceOp, honorsCancellation: Bool) async throws {
        let sut = await H.make(honorsCancellation: honorsCancellation)
        try await sut.loadInitial()
        try op.script(sut, failing: nil)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        await sut.manager.teardown(reason: .userLogout)
        op.releaseAll(sut)
        await task.value

        await expectCleared(sut)
    }

    @Test(
        "an operation that fails after teardown sets no error",
        arguments: MemberServiceOp.allCases, [ListError.server, .network, .membershipNotFound, .memberEmailNotFound]
    )
    func inFlightFailureAfterTeardown(op: MemberServiceOp, error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: error)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        await sut.manager.teardown(reason: .sessionExpired)
        op.releaseAll(sut)
        await task.value

        await expectCleared(sut)
    }

    @Test(
        "a notFound or archived failure after teardown does not mark the list gone",
        arguments: [MemberServiceOp.addMember, .removeMember, .setCoOwner], [ListError.notFound, .archivedReadOnly]
    )
    func goneFailureAfterTeardownIsIgnored(op: MemberServiceOp, error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: error)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        await sut.manager.teardown(reason: .userLogout)
        op.releaseAll(sut)
        await task.value
        await expectCleared(sut)

        // The next session sees the same list id: the stale call must not have poisoned the guard.
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: H.listId, name: "Name of list")]))
        await sut.service.loadLists()
        #expect(sut.service.lists.map(\.id) == [H.listId])
    }

    @Test("a leave that completes after teardown adds nothing to the deleted-list guard of the next session")
    func leaveAfterTeardownDoesNotGuardNextSession() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        try MemberServiceOp.leaveList.script(sut, failing: nil)
        let task = Task { await MemberServiceOp.leaveList.run(sut) }
        await MemberServiceOp.leaveList.awaitHeld(sut)

        await sut.manager.teardown(reason: .userLogout)
        MemberServiceOp.leaveList.releaseAll(sut)
        await task.value
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: H.listId, name: "Name of list")]))
        await sut.service.loadLists()

        #expect(sut.service.lists.map(\.id) == [H.listId], "the new session must still see the list")
        #expect(sut.service.goneListId == nil)
    }

    @Test("after an operation discarded by teardown, the next load goes to the repository", arguments: MemberServiceOp.allCases)
    func nextLoadAfterDiscardedOperation(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: nil)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)
        await sut.manager.teardown(reason: .userLogout)
        op.releaseAll(sut)
        await task.value
        let before = sut.lists.fetchListsCount
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: "list-b", name: "Name of list-b")]))

        await sut.service.loadLists()

        #expect(sut.lists.fetchListsCount == before + 1)
        #expect(sut.service.lists.map(\.id) == ["list-b"])
        #expect(sut.service.error == nil)
    }

    // MARK: - User switch

    @Test("user switch: A's late result never touches B's lists, cache or error", arguments: MemberServiceOp.allCases)
    func userSwitch(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()                                                  // user A
        try op.script(sut, failing: nil)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        await sut.manager.teardown(reason: .userLogout)
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: "list-b", name: "Name of list-b")]))
        await sut.service.loadLists()                                                // user B
        op.releaseAll(sut)
        await task.value

        #expect(sut.service.lists.map(\.id) == ["list-b"], "A's data must not replace or join B's")
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.error == nil)
        #expect(sut.service.goneListId == nil)
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == ["list-b"])
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
    }

    @Test("user switch: A's leave finishing late does not remove a list B happens to share by id")
    func userSwitchLeave() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))               // user A
        try MemberServiceOp.leaveList.script(sut, failing: nil)
        let task = Task { await MemberServiceOp.leaveList.run(sut) }
        await MemberServiceOp.leaveList.awaitHeld(sut)

        await sut.manager.teardown(reason: .userLogout)
        sut.lists.enqueueFetchLists(.success([ListFixtures.giftList(id: H.listId, name: "Name of list")]))
        await sut.service.loadLists()                                                // user B sees the same id
        MemberServiceOp.leaveList.releaseAll(sut)
        await task.value

        #expect(sut.service.lists.map(\.id) == [H.listId])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == [H.listId])
        #expect(sut.service.goneListId == nil)
    }

    // MARK: - Cancellation

    @Test("cancelling the caller sets no error and leaves the state alone", arguments: MemberServiceOp.allCases)
    func cancellationSetsNoError(op: MemberServiceOp) async throws {
        let sut = await H.make(honorsCancellation: true)
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        try op.script(sut, failing: nil)
        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        task.cancel()
        op.releaseAll(sut)
        await task.value

        #expect(sut.service.error == nil, "cancellation is not shown to the user")
        #expect(sut.service.isMutating == false)
        #expect(sut.service.goneListId == nil)
        #expect(sut.service.lists.map(\.id) == [H.listId], "a cancelled operation drops nothing")
        #expect(sut.service.currentListDetail == initial)
    }

    @Test("a repository that fails with CancellationError sets no error", arguments: MemberServiceOp.allCases)
    func repositoryCancellationErrorSetsNoError(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        switch op {
        case .addMember: sut.members.enqueueAddMember(.failure(CancellationError()))
        case .removeMember, .leaveList: sut.members.enqueueRemoveMember(.failure(CancellationError()))
        case .setCoOwner: sut.lists.enqueueUpdateList(.failure(CancellationError()))
        }

        await op.run(sut)

        #expect(sut.service.error == nil)
        #expect(sut.service.isMutating == false)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail == initial)
    }
}
