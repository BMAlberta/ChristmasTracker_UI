//
//  MockData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

enum MockData {
    // MARK: - Users

    static let user1 = User (
        id: "user-1",
        email: "john.doe@example.com",
        name: "John Doe",
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )
    static let user2 = User (
        id: "user-2",
        email: "jane.doe@example.com",
        name: "Jane Doe",
        role: .user,
        createdAt: Date(),
        updatedAt: Date()
    )
    // MARK: - Gift Lists
    static let allLists = [sampleGiftList, sampleOwnedList]
    // MARK: - Gift Items
}

extension MockData {
    /// A list for someone else: counts present.
    static let sampleGiftList = GiftList(
        id: "1",
        name: "Christmas 2024",
        theme: "Winter Wonderland",
        year: 2024,
        visibility: .private,
        status: .active,
        recipient: ListPerson(id: "recipient-1", displayName: "Tommy"),
        owner: ListPerson(id: "owner-1", displayName: "John Doe"),
        coOwner: nil,
        myRole: .member,
        capabilities: MockListData.memberCapabilities,
        memberCount: 3,
        itemCount: 12,
        purchasedCount: 8,
        createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
        updatedAt: Date()
    )

    /// A blind list for yourself: counts absent.
    static let sampleOwnedList = GiftList(
        id: "2",
        name: "Birthday Gifts",
        theme: nil,
        year: 2024,
        visibility: .inviteOnly,
        status: .active,
        recipient: ListPerson(id: "recipient-2", displayName: "Sarah"),
        owner: ListPerson(id: "owner-1", displayName: "John Doe"),
        coOwner: nil,
        myRole: .owner,
        capabilities: MockListData.blindOwnerCapabilities,
        memberCount: 1,
        itemCount: nil,
        purchasedCount: nil,
        createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
        updatedAt: Date()
    )
}
