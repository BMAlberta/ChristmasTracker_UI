//
//  ListServiceReloadFailureRecordingTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B0 (gap 1): a reload that fails AFTER a successful mutation is recorded, not only
//  logged. The mutation still returns normally and never throws because of the reload.
//
//  - addMember / removeMember / archive: a failed detail refetch is stored under the list's id;
//  - archive: a failed lists reload sets `listsLoadFailure` and the archived list leaves `lists`;
//  - a successful refetch removes the list's keyed entry.
//
//  Determinism: scripted fakes only. No sleeps, no yield loops.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListService records reload failures after a mutation", .timeLimit(.minutes(1)))
@MainActor
struct ListServiceReloadFailureRecordingTests {

    private typealias H = MemberServiceHarness

    // MARK: - Factory

    /// A service with the list and its detail loaded (lists: [list-members]).
    private func makeSUT() async throws -> MemberServiceHarness {
        let sut = await H.make()
        try await sut.loadInitial()
        return sut
    }

    // MARK: - (1) archive

    @Test("an archive whose detail refetch fails stores a keyed failure and still returns normally")
    func archiveDetailRefetchFailureIsRecorded() async throws {
        // Old behavior: the failed post-archive detail refetch was only logged; nothing was stored.
        let sut = try await makeSUT()
        let detail = try H.detail()
        sut.lists.enqueueDeleteList(.success(()))
        sut.lists.enqueueFetchLists(.success([detail.asGiftList()]))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))

        try await sut.service.deleteList(id: H.listId)

        #expect(sut.service.detailLoadFailure(forListId: H.listId) == .network)
        #expect(sut.service.listsLoadFailure == nil, "the lists reload succeeded")
        #expect(sut.lists.deleteListCount == 1)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - (2) addMember and removeMember

    @Test("an addMember whose detail refetch fails stores a keyed failure and still returns normally")
    func addMemberRefetchFailureIsRecorded() async throws {
        // Old behavior: the failed post-addMember refetch was only logged; nothing was stored.
        let sut = try await makeSUT()
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))

        try await sut.service.addMember(listId: H.listId, H.addInput)

        #expect(sut.service.detailLoadFailure(forListId: H.listId) == .network)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("a removeMember whose detail refetch fails stores a keyed failure and still returns normally")
    func removeMemberRefetchFailureIsRecorded() async throws {
        // Old behavior: the failed post-removeMember refetch was only logged; nothing was stored.
        let sut = try await makeSUT()
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.server))

        try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)

        #expect(sut.service.detailLoadFailure(forListId: H.listId) == .server)
        #expect(sut.service.listsLoadFailure == nil)
        #expect(sut.service.isMutating == false)
    }

    // MARK: - (3) lists reload after archive

    @Test("an archive whose lists reload fails sets listsLoadFailure and removes the list from lists")
    func archiveListsReloadFailureIsRecorded() async throws {
        // Old behavior: the failed post-archive lists reload was only logged; listsLoadFailure stayed nil.
        let sut = await H.make()
        let detail = try H.detail()
        sut.lists.enqueueFetchLists(.success([detail.asGiftList()]))
        await sut.service.loadLists()
        #expect(sut.service.lists.map(\.id) == [H.listId], "precondition")
        sut.lists.enqueueDeleteList(.success(()))
        sut.lists.enqueueFetchLists(.failure(ListError.network))

        try await sut.service.deleteList(id: H.listId)

        #expect(sut.service.listsLoadFailure == .network)
        #expect(sut.service.lists.isEmpty, "the archived list is still removed from lists")
        #expect(sut.service.isMutating == false)
    }

    // MARK: - (4) a successful refetch clears the keyed entry

    @Test("a successful refetch after a member change removes the list's keyed failure")
    func successfulMemberRefetchClearsKeyedFailure() async throws {
        // Old behavior: no keyed entry existed, so a successful refetch could not clear one.
        let sut = try await makeSUT()
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))
        try await sut.service.addMember(listId: H.listId, H.addInput)
        #expect(sut.service.detailLoadFailure(forListId: H.listId) == .network, "precondition")
        sut.members.enqueueRemoveMember(.success(()))
        sut.lists.enqueueFetchListDetail(.success(try H.detail()))

        try await sut.service.removeMember(listId: H.listId, userId: MembersFixtures.memberUserId)

        #expect(sut.service.detailLoadFailure(forListId: H.listId) == nil)
    }

    @Test("a successful refetch after an archive removes the list's keyed failure")
    func successfulArchiveRefetchClearsKeyedFailure() async throws {
        // Old behavior: no keyed entry existed, so a successful refetch could not clear one.
        let sut = try await makeSUT()
        let detail = try H.detail()
        sut.members.enqueueAddMember(.success(try H.addedMember()))
        sut.lists.enqueueFetchListDetail(.failure(ListError.network))
        try await sut.service.addMember(listId: H.listId, H.addInput)
        #expect(sut.service.detailLoadFailure(forListId: H.listId) == .network, "precondition")
        sut.lists.enqueueDeleteList(.success(()))
        sut.lists.enqueueFetchLists(.success([detail.asGiftList()]))
        sut.lists.enqueueFetchListDetail(.success(detail))

        try await sut.service.deleteList(id: H.listId)

        #expect(sut.service.detailLoadFailure(forListId: H.listId) == nil)
    }
}
