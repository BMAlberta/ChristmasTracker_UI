//
//  MockMemberRepositoryTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: the pinned behaviors of MockMemberRepository and of the member and co-owner
//  scenarios of MockListRepository (the two share ONE MockListRepository instance), so previews
//  and mock mode are trustworthy.
//
//  Delay: only MockListRepository exposes `delay` (set to 0 through its test helper). If the
//  member mock has a delay of its own it must default to no real wait or be settable; see the
//  report.
//
//  ASSUMPTION (flagged in the report): the mock's "small fake directory" must know the two
//  addresses below (they match MembersFixtures). The addendum does not name any address.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockMemberRepository", .timeLimit(.minutes(1)))
struct MockMemberRepositoryTests {

    // MARK: - Ids and addresses of the mock data

    private let childListId = "mock-list-child"        // owner list for a child: canSeeMembers, canManageMembers
    private let memberListId = "mock-list-member"      // MEMBER-role member: canLeaveList
    private let viewerListId = "mock-list-viewer"      // VIEWER-role member: members absent
    private let coOwnerListId = "mock-list-coowner"    // the current user is the co-owner
    private let meId = MockListData.currentUser.id
    private let patId = "mock-user-pat"                // owner of the member, viewer and co-owner lists
    private let jordanId = "mock-user-jordan"          // the member on the child list

    private let knownEmail = "casey.member@example.com"
    private let knownCoOwnerEmail = "cody.coowner@example.com"
    private let unknownEmail = "nobody.here@example.com"

    // MARK: - Factory

    private struct SUT {
        let lists: MockListRepository
        let members: MockMemberRepository
    }

    private func makeSUT() async -> SUT {
        let lists = MockListRepository(withMockData: true, includeAllScenarios: true)
        await lists.setDelay(0)
        return SUT(lists: lists, members: MockMemberRepository(listRepository: lists))
    }

    // MARK: - addMember

    @Test("add with an unknown email throws memberEmailNotFound")
    func addUnknownEmail() async {
        let sut = await makeSUT()

        await #expect(throws: ListError.memberEmailNotFound) {
            _ = try await sut.members.addMember(listId: childListId, AddMemberInput(email: unknownEmail, role: .member))
        }
    }

    @Test("add a known email returns the ACTIVE member, shows it in fetchListDetail and increments memberCount")
    func addKnownEmail() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchListDetail(id: childListId)

        let added = try await sut.members.addMember(listId: childListId, AddMemberInput(email: knownEmail, role: .viewer))

        #expect(added.status == .active)
        #expect(added.role == .viewer)
        let after = try await sut.lists.fetchListDetail(id: childListId)
        let roster = try #require(after.members)
        #expect(roster.map(\.userId).contains(added.userId))
        #expect(roster.count == (before.members?.count ?? 0) + 1)
        #expect(after.memberCount == before.memberCount + 1)
    }

    @Test("add with the member role keeps the member role", arguments: [ListMemberRole.member, .viewer])
    func addKeepsRole(role: ListMemberRole) async throws {
        let sut = await makeSUT()

        let added = try await sut.members.addMember(listId: childListId, AddMemberInput(email: knownEmail, role: role))

        #expect(added.role == role)
    }

    @Test("add an existing member throws alreadyMember")
    func addExistingMember() async throws {
        let sut = await makeSUT()
        _ = try await sut.members.addMember(listId: childListId, AddMemberInput(email: knownEmail, role: .member))

        await #expect(throws: ListError.alreadyMember) {
            _ = try await sut.members.addMember(listId: childListId, AddMemberInput(email: knownEmail, role: .member))
        }

        let after = try await sut.lists.fetchListDetail(id: childListId)
        #expect(after.members?.filter { $0.status == .active }.count == 2, "the failed second add changes nothing")
    }

    @Test("add shows the member only where canSeeMembers is true: members stay absent otherwise")
    func addKeepsMembersAbsentWhereNotVisible() async throws {
        let sut = await makeSUT()

        // The mock may refuse (the viewer cannot manage members) or accept; either way the
        // viewer's detail must never start carrying a roster.
        _ = try? await sut.members.addMember(listId: viewerListId, AddMemberInput(email: knownEmail, role: .member))

        let detail = try await sut.lists.fetchListDetail(id: viewerListId)
        #expect(detail.capabilities.canSeeMembers == false)
        #expect(detail.members == nil)
    }

    @Test("add to an unknown list throws notFound")
    func addUnknownList() async {
        let sut = await makeSUT()

        await #expect(throws: ListError.notFound) {
            _ = try await sut.members.addMember(listId: "mock-list-missing", AddMemberInput(email: knownEmail, role: .member))
        }
    }

    // MARK: - removeMember

    @Test("remove updates the roster and memberCount")
    func removeUpdatesRosterAndCount() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchListDetail(id: childListId)
        #expect(before.members?.contains(where: { $0.userId == jordanId }) == true, "precondition")

        try await sut.members.removeMember(listId: childListId, userId: jordanId)

        let after = try await sut.lists.fetchListDetail(id: childListId)
        #expect(after.members?.contains(where: { $0.userId == jordanId }) == false)
        #expect(after.memberCount == before.memberCount - 1)
    }

    @Test("remove the owner throws forbidden and changes nothing")
    func removeOwnerForbidden() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchListDetail(id: childListId)

        await #expect(throws: ListError.forbidden) {
            try await sut.members.removeMember(listId: childListId, userId: meId)
        }

        let after = try await sut.lists.fetchListDetail(id: childListId)
        #expect(after == before)
    }

    @Test("remove the co-owner throws forbidden")
    func removeCoOwnerForbidden() async {
        let sut = await makeSUT()

        // On the co-owner list the current user is the co-owner and Pat the owner.
        await #expect(throws: ListError.forbidden) {
            try await sut.members.removeMember(listId: coOwnerListId, userId: meId)
        }
        await #expect(throws: ListError.forbidden) {
            try await sut.members.removeMember(listId: coOwnerListId, userId: patId)
        }
    }

    @Test("remove an unknown user throws membershipNotFound")
    func removeUnknownUser() async {
        let sut = await makeSUT()

        await #expect(throws: ListError.membershipNotFound) {
            try await sut.members.removeMember(listId: childListId, userId: "mock-user-nobody")
        }
    }

    @Test("remove from an unknown list throws notFound")
    func removeUnknownList() async {
        let sut = await makeSUT()

        await #expect(throws: ListError.notFound) {
            try await sut.members.removeMember(listId: "mock-list-missing", userId: jordanId)
        }
    }

    // MARK: - Leave (remove self)

    @Test("leave removes the list from fetchLists and makes fetchListDetail throw notFound")
    func leaveRemovesList() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchLists()
        #expect(before.contains(where: { $0.id == memberListId }), "precondition")

        try await sut.members.removeMember(listId: memberListId, userId: meId)

        let after = try await sut.lists.fetchLists()
        #expect(after.contains(where: { $0.id == memberListId }) == false)
        #expect(after.count == before.count - 1, "only the left list disappears")
        await #expect(throws: ListError.notFound) {
            _ = try await sut.lists.fetchListDetail(id: memberListId)
        }
    }

    @Test("the member repository shares the list repository's state: a leave is visible through it")
    func sharedState() async throws {
        let sut = await makeSUT()

        try await sut.members.removeMember(listId: memberListId, userId: meId)

        let lists = try await sut.lists.fetchLists()
        #expect(lists.map(\.id).contains(memberListId) == false)
    }

    // MARK: - Co-owner through MockListRepository.updateList

    @Test("updateList with .set(email) sets the co-owner with a display name and keeps it")
    func setCoOwner() async throws {
        let sut = await makeSUT()

        let updated = try await sut.lists.updateList(
            id: childListId,
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: knownCoOwnerEmail))
        )

        let coOwner = try #require(updated.coOwner)
        #expect(coOwner.id.isEmpty == false)
        #expect(coOwner.displayName.isEmpty == false, "the display name comes from the fake directory")
        let fetched = try await sut.lists.fetchListDetail(id: childListId)
        #expect(fetched.coOwner == coOwner)
    }

    @Test("a co-owner set through updateList cannot be removed as a member (forbidden)")
    func setCoOwnerThenRemoveForbidden() async throws {
        let sut = await makeSUT()
        let updated = try await sut.lists.updateList(
            id: childListId,
            UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: knownCoOwnerEmail))
        )
        let coOwner = try #require(updated.coOwner)

        await #expect(throws: ListError.forbidden) {
            try await sut.members.removeMember(listId: childListId, userId: coOwner.id)
        }
    }

    @Test("updateList with .set and an unknown email throws memberEmailNotFound and changes nothing")
    func setCoOwnerUnknownEmail() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchListDetail(id: childListId)

        await #expect(throws: ListError.memberEmailNotFound) {
            _ = try await sut.lists.updateList(
                id: childListId,
                UpdateListInput(name: nil, theme: nil, visibility: nil, coOwner: .set(email: unknownEmail))
            )
        }

        let after = try await sut.lists.fetchListDetail(id: childListId)
        #expect(after.coOwner == before.coOwner)
    }

    @Test("updateList with .unchanged leaves the co-owner alone")
    func unchangedCoOwner() async throws {
        let sut = await makeSUT()
        let before = try await sut.lists.fetchListDetail(id: coOwnerListId)

        let updated = try await sut.lists.updateList(
            id: coOwnerListId,
            UpdateListInput(name: "Renamed Co-Owned List", theme: nil, visibility: nil)
        )

        #expect(updated.coOwner == before.coOwner)
        #expect(updated.name == "Renamed Co-Owned List")
    }
}
