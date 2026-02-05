//
//  MockData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

enum MockData {
    // MARK: - Users
    static let user1 = User(
        id: "user-1",
        email: "john@example.com",
        name: "John Doe",
        avatarUrl: nil,
        createdAt: Date()
    )
    static let user2 = User(
        id: "user-2",
        email: "jane@example.com",
        name: "Jane Smith",
        avatarUrl: nil,
        createdAt: Date()
    )
    // MARK: - Gift Lists
    static let list1 = GiftList(
        id: "list-1",
        name: "John's Christmas List",
        description: "Gifts for John",
        ownerId: user1.id,
        ownerName: user1.name,
        members: [
            ListMember(
                id: "member-1",
                userId: user1.id,
                userName: user1.name,
                role: .owner,
                invitationStatus: .accepted
            ),
            ListMember(
                id: "member-2",
                userId: user2.id,
                userName: user2.name,
                role: .member,
                invitationStatus: .accepted
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
    static let list2 = GiftList(
        id: "list-2",
        name: "Jane's Wishlist",
        description: "Gifts for Jane",
        ownerId: user2.id,
        ownerName: user2.name,
        members: [
            ListMember(
                id: "member-3",
                userId: user2.id,
                userName: user2.name,
                role: .owner,
                invitationStatus: .accepted
            )
        ],
        createdAt: Date(),
        updatedAt: Date()
    )
    static let allLists = [list1, list2]
    // MARK: - Gift Items
    static let item1 = GiftItem(
        id: "item-1",
        listId: list1.id,
        name: "Book: Swift Programming",
        description: "Latest edition",
        url: "https://example.com/book",
        imageUrl: nil,
        price: 29.99,
        quantity: 1,
        isPurchased: false,
        isPending: false,
        isOffList: false,
        purchasedBy: nil,
        purchasedAt: nil,
        createdBy: user1.id,
        createdAt: Date(),
        updatedAt: Date()
    )
    static let item2 = GiftItem(
        id: "item-2",
        listId: list1.id,
        name: "Headphones",
        description: "Noise cancelling",
        url: nil,
        imageUrl: nil,
        price: 199.99,
        quantity: 1,
        isPurchased: true,
        isPending: false,
        isOffList: false,
        purchasedBy: user2.id,
        purchasedAt: Date(),
        createdBy: user1.id,
        createdAt: Date(),
        updatedAt: Date()
    )
    static let allItems = [item1, item2]
}
// MARK: - Placeholder Models (Phase 1 only)
/// Placeholder User model (will be replaced in Phase 3)
struct User: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let email: String
    let name: String
    let avatarUrl: String?
    let createdAt: Date
}
/// Placeholder GiftList model (will be replaced in Phase 5)
struct GiftList: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let name: String
    let description: String?
    let ownerId: String
    let ownerName: String
    let members: [ListMember]
    let createdAt: Date
    let updatedAt: Date
}
/// Placeholder ListMember model (will be replaced in Phase 5)
struct ListMember: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let role: MemberRole
    let invitationStatus: InvitationStatus
}
enum MemberRole: String, Codable, Sendable {
    case owner
    case coOwner
    case member
    case viewer
}
enum InvitationStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined
}
/// Placeholder GiftItem model (will be replaced in Phase 6)
struct GiftItem: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let listId: String
    let name: String
    let description: String?
    let url: String?
    let imageUrl: String?
    let price: Decimal?
    let quantity: Int
    let isPurchased: Bool
    let isPending: Bool
    let isOffList: Bool
    let purchasedBy: String?
    let purchasedAt: Date?
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
}
