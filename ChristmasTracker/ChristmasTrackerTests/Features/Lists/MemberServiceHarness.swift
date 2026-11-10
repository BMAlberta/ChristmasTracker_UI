//
//  MemberServiceHarness.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: shared setup for the ListService member-operation tests. Builds a ListService
//  over the gated list and member fakes, a real ListDataStore and a SessionManager that has the
//  service registered (teardown is driven the way the app does it).
//
//  All ids, names and addresses are fake (example.com).
//

import Foundation
@testable import ChristmasTracker

@MainActor
struct MemberServiceHarness {

    static let listId = "list-members"
    static let otherListId = "list-other"

    let service: ListService
    let lists: GatedListRepository
    let members: GatedMemberRepository
    let store: ListDataStore
    let manager: SessionManager
    let log: RepositoryCallLog

    static func make(honorsCancellation: Bool = false) async -> MemberServiceHarness {
        let log = RepositoryCallLog()
        let lists = GatedListRepository()
        let members = GatedMemberRepository()
        lists.callLog = log
        members.callLog = log
        lists.honorsCancellation = honorsCancellation
        members.honorsCancellation = honorsCancellation
        let store = ListDataStore()
        let service = ListService(repository: lists, memberRepository: members, dataStore: store)
        let manager = SessionManager(initialClearables: [])
        await manager.register(service)
        return MemberServiceHarness(service: service, lists: lists, members: members, store: store, manager: manager, log: log)
    }

    // MARK: Fixtures

    /// The manager's view: sees and manages members, may set the co-owner, cannot leave.
    static let managerFlags = MembersFixtures.SectionFlags(
        canSeeMembers: true, canManageMembers: true, canLeaveList: false, canSetCoOwner: true
    )

    /// A MEMBER-role member's view: sees members, may leave.
    static let memberFlags = MembersFixtures.SectionFlags(
        canSeeMembers: true, canManageMembers: false, canLeaveList: true, canSetCoOwner: false
    )

    /// A detail of `listId` (the fixed list id of MembersFixtures.detail) with the given roster.
    static func detail(
        flags: MembersFixtures.SectionFlags = managerFlags,
        roster: [ListFixtures.MemberSpec]? = [MembersFixtures.ownerRow(), MembersFixtures.memberRow()],
        memberCount: Int = 2
    ) throws -> ListDetail {
        try MembersFixtures.detail(flags: flags, roster: roster, hasCoOwner: false, memberCount: memberCount)
    }

    /// The member the add call returns (an ACTIVE `member` named in the roster fixtures).
    static func addedMember() throws -> ListMember {
        let spec = ListFixtures.MemberSpec(
            id: "mem-new", userId: "user-new", displayName: "Nora Newcomer",
            email: "nora.newcomer@example.com", role: "member"
        )
        return mapMemberSummary(try MembersFixtures.memberSummary(spec))
    }

    static let addInput = AddMemberInput(email: "nora.newcomer@example.com", role: .member)

    /// Loads the list and its detail so the service, its lists entry and the cache all hold
    /// `initial` (memberCount 2, roster owner and member).
    func loadInitial(_ initial: ListDetail? = nil) async throws {
        let detail = try initial ?? Self.detail()
        lists.enqueueFetchLists(.success([detail.asGiftList()]))
        lists.enqueueFetchListDetail(.success(detail))
        await service.loadLists()
        await service.loadListDetail(id: detail.id)
    }
}
