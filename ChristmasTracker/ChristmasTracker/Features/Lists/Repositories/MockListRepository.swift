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
    }

    // MARK: - List Repository

    func fetchLists() async throws -> [GiftList] {
        LogDebug("Mock fetchLists", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.fetchFailed
        }

        return lists.map { $0.asGiftList() }
    }

    func fetchListDetail(id: String) async throws -> ListDetail {
        LogDebug("Mock fetchListDetail", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.fetchFailed
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
            throw ListError.createFailed
        }

        let isSelfList = input.recipientId == MockListData.currentUser.id
        let recipient = isSelfList
            ? MockListData.currentUser
            : ListPerson(id: input.recipientId, displayName: "New Recipient")
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
            throw ListError.updateFailed
        }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }

        let updated = lists[index].applying(input, at: Date())
        lists[index] = updated

        return updated
    }

    func deleteList(id: String) async throws {
        LogDebug("Mock deleteList", category: .business)

        try await Task.sleep(for: .seconds(delay))

        if shouldFail {
            throw ListError.deleteFailed
        }

        guard let index = lists.firstIndex(where: { $0.id == id }) else {
            throw ListError.notFound
        }

        lists.remove(at: index)
    }
}

// MARK: - Mock Data

/// Deterministic fake lists for previews and tests. Fake ids and names only. Each list carries
/// the flag set the server would send for that privacy scenario.
nonisolated enum MockListData {

    static let currentUser = ListPerson(id: "mock-user-me", displayName: "Alex Sample")

    private static let otherOwner = ListPerson(id: "mock-user-pat", displayName: "Pat Sample")
    private static let child = ListPerson(id: "mock-child-charlie", displayName: "Charlie Sample")
    private static let otherPerson = ListPerson(id: "mock-user-jordan", displayName: "Jordan Sample")

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
        id: "mock-list-child", name: "Charlie's Wishes", theme: "Winter Wonderland", year: 2026,
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
