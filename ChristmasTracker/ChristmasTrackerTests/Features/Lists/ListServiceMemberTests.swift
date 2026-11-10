//
//  ListServiceMemberTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: ListService.addMember, removeMember, leaveList and setCoOwner (behavior).
//
//  - add and remove refetch the detail through the LIST repository after the member repository
//    succeeded; the roster always comes from the refetched detail, never from the add response.
//  - leaveList drops the list everywhere and feeds the deleted-list guard.
//  - setCoOwner uses the detail the update returns (flags included), no refetch.
//  - notFound / archivedReadOnly from add, remove and setCoOwner drop the list (gone path).
//  - isMutating is true only while these run.
//
//  Determinism: gated fakes with the nextHeldCall() handshake. No sleeps, no yield loops.
//  Session safety lives in ListServiceMemberSessionSafetyTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService member operations", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceMemberTests {

    private typealias H = MemberServiceHarness

    private func giftList(_ id: String, memberCount: Int = 2) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", memberCount: memberCount)
    }

    // MARK: - addMember

    @Test("addMember calls the member repository, then refetches the detail (in that order)")
    func addMemberRefetchesInOrder() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.success(try H.detail(
            roster: [MembersFixtures.ownerRow(), MembersFixtures.memberRow(), MembersFixtures.viewerRow()], memberCount: 3
        )))
        let before = sut.log.events.count

        try await sut.service.addMember(listId: H.listId, H.addInput)

        #expect(Array(sut.log.events.dropFirst(before)) == ["addMember:\(H.listId)", "fetchListDetail:\(H.listId)"])
        #expect(sut.members.addMemberCount == 1)
        #expect(sut.lists.fetchListDetailCount == 2, "the initial load plus exactly one refetch")
        #expect(sut.members.addedRequests.first?.listId == H.listId)
        #expect(sut.members.addedRequests.first?.input == H.addInput)
    }

    @Test("addMember takes the roster from the refetched detail, never from the add response")
    func addMemberRosterComesFromRefetch() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let added = try H.addedMember()
        let refetchedRoster = [MembersFixtures.ownerRow(), MembersFixtures.memberRow(), MembersFixtures.viewerRow()]
        sut.members.enqueueAddMember(.success(added))
        sut.lists.enqueueFetchListDetail(.success(try H.detail(roster: refetchedRoster, memberCount: 3)))

        try await sut.service.addMember(listId: H.listId, H.addInput)

        let userIds = try #require(sut.service.currentListDetail?.members).map(\.userId)
        #expect(userIds == [MembersFixtures.ownerId, MembersFixtures.memberUserId, MembersFixtures.viewerUserId])
        #expect(!userIds.contains(added.userId), "the add response must not be spliced into the roster")
    }

    @Test("addMember updates currentListDetail, the cached detail and the lists entry memberCount")
    func addMemberUpdatesState() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let refetched = try H.detail(
            roster: [MembersFixtures.ownerRow(), MembersFixtures.memberRow(), MembersFixtures.viewerRow()], memberCount: 3
        )
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.success(refetched))

        try await sut.service.addMember(listId: H.listId, H.addInput)

        #expect(sut.service.currentListDetail == refetched)
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == refetched)
        #expect(sut.service.lists.first(where: { $0.id == H.listId })?.memberCount == 3)
        #expect(sut.service.error == nil)
    }

    @Test("addMember to a list that is not the open one leaves currentListDetail alone")
    func addMemberOtherListKeepsCurrent() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: H.otherListId, memberCount: 5)))

        try await sut.service.addMember(listId: H.otherListId, H.addInput)

        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.currentListDetail?.id == H.listId)
    }

    @Test("addMember that fails rethrows the error, does not refetch and leaves the state alone", arguments: [
        ListError.memberEmailNotFound, .alreadyMember, .forbidden, .network, .server,
        .validation(message: "Invalid email address"), .rateLimited(retryAfter: 3)
    ])
    func addMemberFailure(error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueAddMember(.failure(error))

        await #expect(throws: error) {
            try await sut.service.addMember(listId: H.listId, H.addInput)
        }

        #expect(sut.lists.fetchListDetailCount == 1, "no refetch after a failed add")
        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.isMutating == false)
    }

    @Test("addMember that succeeds but whose refetch fails returns normally and sets the refetch error")
    func addMemberRefetchFailure() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))

        try await sut.service.addMember(listId: H.listId, H.addInput)

        #expect(sut.service.error == .network)
        #expect(sut.service.currentListDetail == initial, "a failed refetch must not blank or alter the detail")
        #expect(sut.service.isMutating == false)
    }

    // MARK: - removeMember

    @Test("removeMember calls the member repository, then refetches the detail (in that order)")
    func removeMemberRefetchesInOrder() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.success(try H.detail(roster: [MembersFixtures.ownerRow()], memberCount: 1)))
        let before = sut.log.events.count

        try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)

        #expect(Array(sut.log.events.dropFirst(before)) == [
            "removeMember:\(H.listId):\(MembersFixtures.memberUserId)", "fetchListDetail:\(H.listId)"
        ])
        #expect(sut.members.removedRequests.first?.userId == MembersFixtures.memberUserId)
        #expect(sut.members.removedRequests.first?.listId == H.listId)
        #expect(sut.lists.fetchListDetailCount == 2)
    }

    @Test("removeMember updates currentListDetail, the cached detail and the lists entry from the refetch")
    func removeMemberUpdatesState() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let refetched = try H.detail(roster: [MembersFixtures.ownerRow()], memberCount: 1)
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.success(refetched))

        try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)

        #expect(sut.service.currentListDetail == refetched)
        #expect(sut.service.currentListDetail?.members?.map(\.userId) == [MembersFixtures.ownerId])
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == refetched)
        #expect(sut.service.lists.first(where: { $0.id == H.listId })?.memberCount == 1)
        #expect(sut.service.error == nil)
    }

    @Test("removeMember that succeeds but whose refetch fails returns normally and sets the refetch error")
    func removeMemberRefetchFailure() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.server))

        try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)

        #expect(sut.service.error == .server)
        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.isMutating == false)
    }

    @Test("removeMember failing with membershipNotFound refetches best-effort and rethrows")
    func removeMemberMembershipNotFound() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let refetched = try H.detail(roster: [MembersFixtures.ownerRow()], memberCount: 1)
        sut.members.enqueueRemoveMember(.failure(ListError.membershipNotFound))
        sut.lists.enqueueFetchListDetail(.success(refetched))

        await #expect(throws: ListError.membershipNotFound) {
            try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)
        }

        #expect(sut.lists.fetchListDetailCount == 2, "the roster is refetched even though the remove failed")
        #expect(sut.service.currentListDetail == refetched)
        #expect(sut.service.lists.map(\.id) == [H.listId], "the list itself is not dropped")
    }

    @Test("removeMember membershipNotFound still rethrows membershipNotFound when the best-effort refetch fails")
    func removeMemberMembershipNotFoundRefetchFails() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueRemoveMember(.failure(ListError.membershipNotFound))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))

        await #expect(throws: ListError.membershipNotFound) {
            try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)
        }

        #expect(sut.lists.fetchListDetailCount == 2)
        #expect(sut.service.currentListDetail == initial)
    }

    @Test("removeMember failing with another error rethrows it and does not refetch", arguments: [
        ListError.forbidden, .network, .server, .rateLimited(retryAfter: 3), .unauthorized
    ])
    func removeMemberOtherFailure(error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.members.enqueueRemoveMember(.failure(error))

        await #expect(throws: error) {
            try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)
        }

        #expect(sut.lists.fetchListDetailCount == 1)
        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.lists.map(\.id) == [H.listId])
    }

    // MARK: - leaveList

    @Test("leaveList sends the caller's own user id to the member repository and does not refetch")
    func leaveListCallsRemoveMemberWithOwnId() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        sut.members.enqueueRemoveMember(.success(()))

        try await sut.service.leaveList(id: H.listId, userId: "user-me")

        #expect(sut.members.removedRequests.first?.listId == H.listId)
        #expect(sut.members.removedRequests.first?.userId == "user-me")
        #expect(sut.members.removeMemberCount == 1)
        #expect(sut.lists.fetchListDetailCount == 1, "a left list is not refetched")
    }

    @Test("leaveList success drops the list from lists, the cache and currentListDetail and sets goneListId")
    func leaveListSuccessDropsList() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        sut.members.enqueueRemoveMember(.success(()))

        try await sut.service.leaveList(id: H.listId, userId: "user-me")

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == H.listId)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
        #expect(sut.service.isMutating == false)
    }

    @Test("leaveList removes only the left list when another list is open")
    func leaveListKeepsOtherLists() async throws {
        let sut = await H.make()
        sut.lists.enqueueFetchLists(.success([giftList(H.listId), giftList(H.otherListId)]))
        sut.lists.enqueueFetchListDetail(.success(ListFixtures.listDetail(id: H.otherListId)))
        await sut.service.loadLists()
        await sut.service.loadListDetail(id: H.otherListId)
        sut.members.enqueueRemoveMember(.success(()))

        try await sut.service.leaveList(id: H.listId, userId: "user-me")

        #expect(sut.service.lists.map(\.id) == [H.otherListId])
        #expect(sut.service.currentListDetail?.id == H.otherListId)
    }

    @Test("a loadLists already in flight when the leave completes does not bring the left list back")
    func leaveListGuardsInFlightLoad() async throws {
        let sut = await H.make()
        sut.lists.enqueueFetchLists(.success([giftList(H.listId), giftList(H.otherListId)]), held: true)
        sut.members.enqueueRemoveMember(.success(()))
        let load = Task { await sut.service.loadLists() }
        await sut.lists.nextHeldCall()

        try await sut.service.leaveList(id: H.listId, userId: "user-me")
        sut.lists.releaseAll()
        await load.value

        #expect(sut.service.lists.map(\.id) == [H.otherListId])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == [H.otherListId])
    }

    @Test("a later refreshLists that still returns the left list does not bring it back")
    func leaveListGuardsLaterRefresh() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchLists(.success([giftList(H.listId), giftList(H.otherListId)]))

        try await sut.service.leaveList(id: H.listId, userId: "user-me")
        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == [H.otherListId])
        let cached = await sut.store.getLists()
        #expect(cached.map(\.id) == [H.otherListId])
    }

    @Test("loadListDetail of a left list does not show it and reports notFound")
    func leaveListGuardsDetailLoad() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.success(try H.detail(flags: H.memberFlags)))

        try await sut.service.leaveList(id: H.listId, userId: "user-me")
        await sut.service.loadListDetail(id: H.listId)

        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.error == .notFound)
        #expect(sut.service.goneListId == H.listId)
    }

    @Test("leaveList failing with membershipNotFound drops the list locally and rethrows")
    func leaveListMembershipNotFound() async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        sut.members.enqueueRemoveMember(.failure(ListError.membershipNotFound))

        await #expect(throws: ListError.membershipNotFound) {
            try await sut.service.leaveList(id: H.listId, userId: "user-me")
        }

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == H.listId)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
    }

    @Test("leaveList failing with any other error drops nothing and rethrows", arguments: [
        ListError.forbidden, .network, .server, .rateLimited(retryAfter: 3), .unauthorized, .invalidResponse
    ])
    func leaveListOtherFailureDropsNothing(error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial(try H.detail(flags: H.memberFlags))
        let initial = sut.service.currentListDetail
        sut.members.enqueueRemoveMember(.failure(error))

        await #expect(throws: error) {
            try await sut.service.leaveList(id: H.listId, userId: "user-me")
        }

        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.goneListId == nil)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == initial)
    }

    // MARK: - setCoOwner

    @Test("setCoOwner sends .set(email) through updateList with no other field")
    func setCoOwnerSendsSetInput() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        sut.lists.enqueueUpdateList(.success(try H.detail()))

        try await sut.service.setCoOwner(listId: H.listId, email: MembersFixtures.coOwnerEmail)

        #expect(sut.lists.updateListCount == 1)
        #expect(sut.lists.updatedInputs.first == UpdateListInput(
            name: nil, theme: nil, visibility: nil, coOwner: .set(email: MembersFixtures.coOwnerEmail)
        ))
    }

    @Test("setCoOwner uses the returned detail, flags included, for the service and the cache; no refetch")
    func setCoOwnerUsesReturnedDetail() async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        // The returned detail carries different flags than the loaded one: they must win.
        let returned = try MembersFixtures.detail(
            flags: MembersFixtures.SectionFlags(
                canSeeMembers: true, canManageMembers: false, canLeaveList: true, canSetCoOwner: false
            ),
            roster: [MembersFixtures.ownerRow(), MembersFixtures.coOwnerRow()],
            hasCoOwner: true,
            memberCount: 2
        )
        sut.lists.enqueueUpdateList(.success(returned))

        try await sut.service.setCoOwner(listId: H.listId, email: MembersFixtures.coOwnerEmail)

        #expect(sut.service.currentListDetail == returned)
        #expect(sut.service.currentListDetail?.capabilities == returned.capabilities)
        #expect(sut.service.currentListDetail?.coOwner?.id == MembersFixtures.coOwnerId)
        let cached = await sut.store.getListDetail(id: H.listId)
        #expect(cached == returned)
        #expect(sut.service.lists.first(where: { $0.id == H.listId }) == returned.asGiftList())
        #expect(sut.lists.fetchListDetailCount == 1, "setCoOwner must not refetch")
        #expect(sut.service.error == nil)
    }

    @Test("setCoOwner failing rethrows and leaves the state alone", arguments: [
        ListError.memberEmailNotFound, .forbidden, .network, .server, .validation(message: "Invalid email address")
    ])
    func setCoOwnerFailure(error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        let initial = sut.service.currentListDetail
        sut.lists.enqueueUpdateList(.failure(error))

        await #expect(throws: error) {
            try await sut.service.setCoOwner(listId: H.listId, email: MembersFixtures.coOwnerEmail)
        }

        #expect(sut.service.currentListDetail == initial)
        #expect(sut.service.lists.map(\.id) == [H.listId])
        #expect(sut.service.goneListId == nil)
    }

    // MARK: - Gone list (notFound / archivedReadOnly)

    @Test(
        "notFound or archivedReadOnly from add, remove and setCoOwner drops the list via the gone-list path",
        arguments: [MemberServiceOp.addMember, .removeMember, .setCoOwner], [ListError.notFound, .archivedReadOnly]
    )
    func goneListIsDropped(op: MemberServiceOp, error: ListError) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: error, held: false)

        await #expect(throws: error) {
            try await op.runThrowing(sut)
        }

        #expect(sut.service.lists.isEmpty)
        #expect(sut.service.currentListDetail == nil)
        #expect(sut.service.goneListId == H.listId)
        let cachedDetail = await sut.store.getListDetail(id: H.listId)
        #expect(cachedDetail == nil)
        let cachedLists = await sut.store.getLists()
        #expect(cachedLists.isEmpty)
        #expect(sut.service.isMutating == false)
    }

    @Test(
        "a list dropped by the gone-list path is not resurrected by a later load",
        arguments: [MemberServiceOp.addMember, .removeMember, .setCoOwner]
    )
    func goneListIsNotResurrected(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: .notFound, held: false)
        _ = try? await op.runThrowing(sut)
        sut.lists.enqueueFetchLists(.success([giftList(H.listId), giftList(H.otherListId)]))

        await sut.service.refreshLists()

        #expect(sut.service.lists.map(\.id) == [H.otherListId])
    }

    // MARK: - isMutating

    @Test("isMutating is true only while the operation runs; the load flags stay false", arguments: MemberServiceOp.allCases)
    func isMutatingOnlyDuringOperation(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        #expect(sut.service.isMutating == false, "precondition")
        try op.script(sut, failing: nil, held: true)

        let task = Task { await op.run(sut) }
        await op.awaitHeld(sut)

        #expect(sut.service.isMutating == true)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)

        op.releaseAll(sut)
        await task.value

        #expect(sut.service.isMutating == false)
        #expect(sut.service.isLoadingLists == false)
        #expect(sut.service.isLoadingDetail == false)
    }

    @Test("isMutating is false again after a failed operation", arguments: MemberServiceOp.allCases)
    func isMutatingFalseAfterFailure(op: MemberServiceOp) async throws {
        let sut = await H.make()
        try await sut.loadInitial()
        try op.script(sut, failing: .server, held: false)

        await op.run(sut)

        #expect(sut.service.isMutating == false)
    }
}
