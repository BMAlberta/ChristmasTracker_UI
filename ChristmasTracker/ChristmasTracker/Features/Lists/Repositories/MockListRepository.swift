//
//  MockListRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

actor MockListRepository: ListRepository {

    // MARK: - Mock Data Storage
    private var lists: [ListDetail] = []
    private var nextId = 1

    // Shared with MockMemberRepository and MockChildRepository, which work on this one instance.
    private var children: [Child] = []
    private var nextChildNumber = 1
    private var nextMemberNumber = 1

    // MARK: - Configuration
    var shouldFail: Bool = false
    var delay: TimeInterval = 0.5

    // MARK: - Initialization

    /// - Parameters:
    ///   - withMockData: seed the repository with the three default lists.
    ///   - includeAllScenarios: seed with every privacy scenario (adds viewer-role member,
    ///     public non-member, blind co-owner and an archived list). Used by previews.
    init(withMockData: Bool = true, includeAllScenarios: Bool = false) {
        if includeAllScenarios {
            lists = MockListData.allScenarios
        } else if withMockData {
            lists = MockListData.allLists
        }
        if !lists.isEmpty {
            children = [MockListData.seedChild]
        }
    }

    /// The flags the mock shows for one of its scenario lists, or nil for an unknown id. The item
    /// mock reads this so mock mode never disagrees with itself.
    nonisolated static func capabilities(forListId id: String) -> ListCapabilities? {
        MockListData.allScenarios.first { $0.id == id }?.capabilities
    }

    // MARK: - List Repository

    // Mock repository: intentionally uninstrumented.
    func fetchLists() async throws -> [GiftList] {
        LogDebug("Mock fetchLists", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        return lists.map { $0.asGiftList() }
    }

    // Mock repository: intentionally uninstrumented.
    func fetchListDetail(id: String) async throws -> ListDetail {
        LogDebug("Mock fetchListDetail", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        guard let list = lists.first(where: { $0.id == id }) else {
            throw ListError.notFound
        }

        return list
    }

    // Mock repository: intentionally uninstrumented.
    func createList(_ input: CreateListInput) async throws -> ListDetail {
        LogDebug("Mock createList", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        let isSelfList = input.recipientId == MockListData.currentUser.id
        // A registered child is shown by name; any other id is an unnamed recipient (the mock does
        // not reject unknown recipients). Only a list for yourself is blind.
        let knownChild = children.first(where: { $0.id == input.recipientId })
        let recipient = isSelfList
            ? MockListData.currentUser
            : ListPerson(id: input.recipientId, displayName: knownChild?.shownName ?? "New Recipient")
        let now = Date()

        // The creator owns the new list. A list for yourself is blind: no counts, no gift activity.
        let newList = ListDetail(
            id: "mock-created-\(nextId)",
            name: input.name,
            theme: input.theme,
            year: input.year,
            visibility: input.visibility ?? .private,
            status: .active,
            recipient: recipient,
            owner: MockListData.currentUser,
            coOwner: nil,
            myRole: .owner,
            capabilities: isSelfList ? MockListData.blindOwnerCapabilities : MockListData.ownerCapabilities,
            memberCount: 1,
            itemCount: isSelfList ? nil : 0,
            purchasedCount: isSelfList ? nil : 0,
            createdAt: now,
            updatedAt: now,
            members: []
        )

        nextId += 1
        lists.append(newList)

        return newList
    }

    // Mock repository: intentionally uninstrumented.
    func updateList(id: String, _ input: UpdateListInput) async throws -> ListDetail {
        LogDebug("Mock updateList", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }

        // Like the server: an archived list rejects every update with the 422.
        guard lists[index].status != .archived else {
            throw ListError.archivedReadOnly
        }

        var updated = lists[index].applying(input, at: Date())
        if case .set(let email) = input.coOwner {
            guard updated.capabilities.canSetCoOwner else {
                throw ListError.forbidden
            }
            guard let person = MockListData.person(forEmail: email) else {
                throw ListError.memberEmailNotFound
            }
            // The owner and the recipient cannot be the co-owner.
            guard person.id != updated.owner.id, person.id != updated.recipient.id else {
                throw ListError.forbidden
            }
            updated = updated.replacing(coOwner: person)
        }
        lists[index] = updated

        return updated
    }

    // Mock repository: intentionally uninstrumented.
    func removeCoOwner(listId: String) async throws -> ListDetail {
        LogDebug("Mock removeCoOwner", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        guard let index = lists.firstIndex(where: { $0.id == listId }) else {
            throw ListError.notFound
        }
        let list = lists[index]
        guard list.status != .archived else {
            throw ListError.archivedReadOnly
        }
        guard list.capabilities.canSetCoOwner else {
            throw ListError.forbidden
        }
        // Idempotent: with no co-owner the unchanged detail comes back.
        guard list.coOwner != nil else {
            return list
        }
        let updated = list.replacing(coOwner: nil)
        lists[index] = updated
        return updated
    }

    // Mock repository: intentionally uninstrumented.
    func deleteList(id: String) async throws {
        LogDebug("Mock deleteList", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.server
        }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }

        // Archiving keeps the list: the status becomes ARCHIVED and the management flags go false.
        lists[index] = lists[index].archived()
    }

    // MARK: - Shared state for MockMemberRepository and MockChildRepository

    // Mock helpers: intentionally uninstrumented, like the rest of this test double. They share
    // this repository's delay and failure switch.

    func addMemberToList(id: String, _ input: AddMemberInput) async throws -> ListMember {
        try await Task.sleep(for: .seconds(delay))
        if shouldFail { throw ListError.server }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }
        let list = lists[index]
        guard list.capabilities.canManageMembers else { throw ListError.forbidden }
        guard let person = MockListData.person(forEmail: input.email) else {
            throw ListError.memberEmailNotFound
        }
        let isOwnerOrCoOwner = person.id == list.owner.id || person.id == list.coOwner?.id
        let isRosterMember = list.members?.contains(where: { $0.userId == person.id && $0.status == .active }) == true
        guard !isOwnerOrCoOwner, !isRosterMember else { throw ListError.alreadyMember }

        let now = Date()
        let member = ListMember(
            id: "mock-mem-added-\(nextMemberNumber)", userId: person.id, displayName: person.displayName,
            email: input.email, role: input.role, status: .active, invitedAt: now, acceptedAt: now, expiresAt: nil
        )
        nextMemberNumber += 1
        // The roster is only kept where the viewer may see it; it stays absent otherwise.
        let roster = list.capabilities.canSeeMembers ? (list.members ?? []) + [member] : list.members
        lists[index] = list.replacing(memberCount: list.memberCount + 1, members: roster)
        return member
    }

    /// Removes another member, or the caller itself (leaving), which drops the list.
    func removeMemberFromList(id: String, userId: String) async throws {
        try await Task.sleep(for: .seconds(delay))
        if shouldFail { throw ListError.server }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }
        let list = lists[index]
        // The owner and the co-owner can never be removed.
        guard userId != list.owner.id, userId != list.coOwner?.id else { throw ListError.forbidden }

        if userId == MockListData.currentUser.id {
            guard list.capabilities.canLeaveList else { throw ListError.forbidden }
            lists.remove(at: index)
            return
        }
        guard list.capabilities.canManageMembers else { throw ListError.forbidden }
        guard let roster = list.members, roster.contains(where: { $0.userId == userId }) else {
            throw ListError.membershipNotFound
        }
        lists[index] = list.replacing(
            memberCount: max(list.memberCount - 1, 1),
            members: roster.filter { $0.userId != userId }
        )
    }

    func childrenOfUser() async throws -> [Child] {
        try await Task.sleep(for: .seconds(delay))
        if shouldFail { throw ChildError.server }
        return children
    }

    func addChild(_ input: CreateChildInput) async throws -> Child {
        try await Task.sleep(for: .seconds(delay))
        if shouldFail { throw ChildError.server }

        let child = Child(
            id: "mock-child-new-\(nextChildNumber)", firstName: input.firstName, lastName: input.lastName,
            displayName: input.displayName, relationship: input.relationship
        )
        nextChildNumber += 1
        children.append(child)
        return child
    }

    func removeChild(id: String) async throws {
        try await Task.sleep(for: .seconds(delay))
        if shouldFail { throw ChildError.server }

        guard let index = children.firstIndex(where: { $0.id == id }) else {
            throw ChildError.childNotFound
        }
        // A child that has a list cannot be deleted.
        guard !lists.contains(where: { $0.recipient.id == id }) else {
            throw ChildError.childHasLists
        }
        children.remove(at: index)
    }
}

// MARK: - Mock copies

nonisolated private extension ListDetail {
    func replacing(coOwner: ListPerson?) -> ListDetail {
        rebuilt(coOwner: coOwner, memberCount: memberCount, members: members)
    }

    func replacing(memberCount: Int, members: [ListMember]?) -> ListDetail {
        rebuilt(coOwner: coOwner, memberCount: memberCount, members: members)
    }

    /// What the server sends after archiving: status ARCHIVED, the four management flags false,
    /// every other flag unchanged.
    func archived() -> ListDetail {
        let flags = ListCapabilities(
            isRecipient: capabilities.isRecipient, canSeeGiftActivity: capabilities.canSeeGiftActivity,
            canPurchase: capabilities.canPurchase, canAddOffList: capabilities.canAddOffList,
            canSeeOffList: capabilities.canSeeOffList, canCreateItem: capabilities.canCreateItem,
            canSeeMembers: capabilities.canSeeMembers, canEditList: false, canDeleteList: false,
            canManageMembers: false, canSetCoOwner: false, canLeaveList: capabilities.canLeaveList
        )
        return rebuilt(
            coOwner: coOwner, memberCount: memberCount, members: members,
            status: .archived, capabilities: flags
        )
    }

    private func rebuilt(
        coOwner: ListPerson?,
        memberCount: Int,
        members: [ListMember]?,
        status: ListStatus? = nil,
        capabilities: ListCapabilities? = nil
    ) -> ListDetail {
        ListDetail(
            id: id, name: name, theme: theme, year: year, visibility: visibility, status: status ?? self.status,
            recipient: recipient, owner: owner, coOwner: coOwner, myRole: myRole,
            capabilities: capabilities ?? self.capabilities, memberCount: memberCount, itemCount: itemCount,
            purchasedCount: purchasedCount, createdAt: createdAt, updatedAt: updatedAt,
            members: members
        )
    }
}

// MARK: - Mock Data

/// Deterministic fake lists for previews and tests. Fake ids and names only. Each list carries
/// the flag set the server would send for that privacy scenario.
nonisolated enum MockListData {

    static let currentUser = ListPerson(id: "mock-user-me", displayName: "Alex Sample")

    private static let otherOwner = ListPerson(id: "mock-user-pat", displayName: "Pat Sample")
    private static let child = ListPerson(id: "mock-child-charlie", displayName: "Tommy D.")
    private static let otherPerson = ListPerson(id: "mock-user-jordan", displayName: "Jordan Sample")

    /// The child the mock children start with: the recipient of the owner's child list.
    static let seedChild = Child(
        id: child.id, firstName: "Tommy", lastName: "D.", displayName: "Tommy D.", relationship: .parent
    )

    // MARK: Directory

    /// The fake accounts an email can be resolved to (adding a member or a co-owner). Any other
    /// address is unknown. Fake addresses only.
    private static let directory: [String: ListPerson] = [
        "alex.sample@example.com": currentUser,
        "pat.sample@example.com": otherOwner,
        "jordan.sample@example.com": otherPerson,
        "casey.member@example.com": ListPerson(id: "mock-user-casey", displayName: "Casey Member"),
        "cody.coowner@example.com": ListPerson(id: "mock-user-cody", displayName: "Cody Coowner")
    ]

    static func person(forEmail email: String) -> ListPerson? {
        directory[email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    private static let created = Date(timeIntervalSince1970: 1_767_225_600)
    private static let updated = Date(timeIntervalSince1970: 1_767_312_000)

    // MARK: Flag scenarios

    /// Owner of a self list: blind. Manages the list, sees no gift activity.
    static let blindOwnerCapabilities = ListCapabilities(
        isRecipient: true, canSeeGiftActivity: false, canPurchase: false,
        canAddOffList: false, canSeeOffList: false, canCreateItem: true,
        canSeeMembers: true, canEditList: true, canDeleteList: true,
        canManageMembers: true, canSetCoOwner: true, canLeaveList: false
    )

    /// Owner of a list for someone else: sees gift activity.
    static let ownerCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: true, canPurchase: true,
        canAddOffList: false, canSeeOffList: true, canCreateItem: true,
        canSeeMembers: true, canEditList: true, canDeleteList: true,
        canManageMembers: true, canSetCoOwner: true, canLeaveList: false
    )

    static let memberCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: true, canPurchase: true,
        canAddOffList: true, canSeeOffList: true, canCreateItem: true,
        canSeeMembers: true, canEditList: false, canDeleteList: false,
        canManageMembers: false, canSetCoOwner: false, canLeaveList: true
    )

    private static let viewerMemberCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: false, canPurchase: false,
        canAddOffList: false, canSeeOffList: false, canCreateItem: false,
        canSeeMembers: false, canEditList: false, canDeleteList: false,
        canManageMembers: false, canSetCoOwner: false, canLeaveList: true
    )

    private static let publicNonMemberCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: false, canPurchase: false,
        canAddOffList: false, canSeeOffList: false, canCreateItem: false,
        canSeeMembers: false, canEditList: false, canDeleteList: false,
        canManageMembers: false, canSetCoOwner: false, canLeaveList: false
    )

    private static let blindCoOwnerCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: false, canPurchase: false,
        canAddOffList: false, canSeeOffList: false, canCreateItem: true,
        canSeeMembers: true, canEditList: true, canDeleteList: true,
        canManageMembers: true, canSetCoOwner: false, canLeaveList: false
    )

    private static let archivedOwnerCapabilities = ListCapabilities(
        isRecipient: false, canSeeGiftActivity: true, canPurchase: true,
        canAddOffList: false, canSeeOffList: true, canCreateItem: true,
        canSeeMembers: true, canEditList: false, canDeleteList: false,
        canManageMembers: false, canSetCoOwner: false, canLeaveList: false
    )

    // MARK: Members

    private static func member(
        _ id: String, _ person: ListPerson, role: ListMemberRole, status: ListMemberStatus = .active
    ) -> ListMember {
        ListMember(
            id: id, userId: person.id, displayName: person.displayName, email: nil,
            role: role, status: status, invitedAt: created,
            acceptedAt: status == .active ? updated : nil, expiresAt: nil
        )
    }

    // MARK: Lists

    /// Owner of a list for a child: counts present.
    static let ownerOfChildList = ListDetail(
        id: "mock-list-child", name: "Tommy's Wishes", theme: "Winter Wonderland", year: 2026,
        visibility: .private, status: .active, recipient: child, owner: currentUser, coOwner: nil,
        myRole: .owner, capabilities: ownerCapabilities, memberCount: 2, itemCount: 12, purchasedCount: 8,
        createdAt: created, updatedAt: updated,
        members: [member("mock-mem-1", otherPerson, role: .member)]
    )

    /// Blind owner of a list for yourself: no counts.
    static let blindOwnerOfSelfList = ListDetail(
        id: "mock-list-self", name: "My Wish List", theme: nil, year: 2026,
        visibility: .inviteOnly, status: .active, recipient: currentUser, owner: currentUser, coOwner: nil,
        myRole: .owner, capabilities: blindOwnerCapabilities, memberCount: 1, itemCount: nil, purchasedCount: nil,
        createdAt: created, updatedAt: updated,
        members: [member("mock-mem-2", currentUser, role: .member)]
    )

    /// MEMBER-role member of someone else's list: counts present, may leave.
    static let memberList = ListDetail(
        id: "mock-list-member", name: "Pat's Holiday List", theme: "Festive Fun", year: 2026,
        visibility: .friendsOnly, status: .active, recipient: otherPerson, owner: otherOwner, coOwner: nil,
        myRole: .member, capabilities: memberCapabilities, memberCount: 3, itemCount: 5, purchasedCount: 2,
        createdAt: created, updatedAt: updated,
        members: [member("mock-mem-3", currentUser, role: .member), member("mock-mem-4", otherOwner, role: .member)]
    )

    /// VIEWER-role member: no counts, no members, may leave.
    static let viewerMemberList = ListDetail(
        id: "mock-list-viewer", name: "Viewer Sample List", theme: nil, year: 2026,
        visibility: .inviteOnly, status: .active, recipient: otherPerson, owner: otherOwner, coOwner: nil,
        myRole: .viewer, capabilities: viewerMemberCapabilities, memberCount: 4, itemCount: nil, purchasedCount: nil,
        createdAt: created, updatedAt: updated, members: nil
    )

    /// PUBLIC list seen by a non-member: myRole viewer, no counts, cannot leave.
    static let publicNonMemberList = ListDetail(
        id: "mock-list-public", name: "Public Sample List", theme: nil, year: 2026,
        visibility: .public, status: .active, recipient: otherPerson, owner: otherOwner, coOwner: nil,
        myRole: .viewer, capabilities: publicNonMemberCapabilities, memberCount: 1, itemCount: nil,
        purchasedCount: nil, createdAt: created, updatedAt: updated, members: nil
    )

    /// Blind co-owner: manages the list, no counts, cannot change the co-owner.
    static let blindCoOwnerList = ListDetail(
        id: "mock-list-coowner", name: "Co-Owned Sample List", theme: nil, year: 2026,
        visibility: .private, status: .active, recipient: otherPerson, owner: otherOwner, coOwner: currentUser,
        myRole: .coOwner, capabilities: blindCoOwnerCapabilities, memberCount: 2, itemCount: nil,
        purchasedCount: nil, createdAt: created, updatedAt: updated,
        members: [member("mock-mem-5", currentUser, role: .member)]
    )

    /// ARCHIVED list as its owner: every management flag is false.
    static let archivedList = ListDetail(
        id: "mock-list-archived", name: "Archived Sample List", theme: nil, year: 2025,
        visibility: .private, status: .archived, recipient: child, owner: currentUser, coOwner: nil,
        myRole: .owner, capabilities: archivedOwnerCapabilities, memberCount: 1, itemCount: 6, purchasedCount: 6,
        createdAt: created, updatedAt: updated, members: []
    )

    /// The default seed: an owner list for a child, a blind self list and a member list.
    static let allLists: [ListDetail] = [ownerOfChildList, blindOwnerOfSelfList, memberList]

    /// Every privacy scenario, for previews.
    static let allScenarios: [ListDetail] = [
        ownerOfChildList, blindOwnerOfSelfList, memberList, viewerMemberList,
        publicNonMemberList, blindCoOwnerList, archivedList
    ]
}
