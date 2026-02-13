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
//    static let list1 = GiftList(
//        id: "list-1",
//        name: "John's Christmas List",
//        description: "Gifts for John",
//        ownerId: user1.id,
//        ownerName: user1.name,
//        members: [
//            ListMember(
//                id: "member-1",
//                userId: user1.id,
//                userName: user1.name,
//                role: .owner,
//                invitationStatus: .accepted
//            ),
//            ListMember(
//                id: "member-2",
//                userId: user2.id,
//                userName: user2.name,
//                role: .member,
//                invitationStatus: .accepted
//            )
//        ],
//        createdAt: Date(),
//        updatedAt: Date()
//    )
//    static let list2 = GiftList(
//        id: "list-2",
//        name: "Jane's Wishlist",
//        description: "Gifts for Jane",
//        ownerId: user2.id,
//        ownerName: user2.name,
//        members: [
//            ListMember(
//                id: "member-3",
//                userId: user2.id,
//                userName: user2.name,
//                role: .owner,
//                invitationStatus: .accepted
//            )
//        ],
//        createdAt: Date(),
//        updatedAt: Date()
//    )
    static let allLists = [sampleGiftList, sampleOwnedList]
    // MARK: - Gift Items
    static let item1 = GiftItem(
        id: "item-1",
        listId: sampleGiftList.id,
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
        listId: sampleGiftList.id,
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

extension MockData {
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
        myRole: .member,  // Not owner, so we can see stats
        itemCount: 12,
        purchasedCount: 8,
        createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
        updatedAt: Date()
    )
    
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
        myRole: .owner,  // I'm the owner
        itemCount: nil,  // ✅ Hidden from owner
        purchasedCount: nil,  // ✅ Hidden from owner
        createdAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
        updatedAt: Date()
    )
}
// MARK: - Placeholder Models (Phase 1 only)

//
//// Explicitly declare nonisolated Codable conformance
//extension GiftList: Codable {
//    nonisolated init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try container.decode(String.self, forKey: .id)
//        self.name = try container.decode(String.self, forKey: .name)
//        self.description = try container.decodeIfPresent(String.self, forKey: .description)
//        self.ownerId = try container.decode(String.self, forKey: .ownerId)
//        self.ownerName = try container.decode(String.self, forKey: .ownerName)
//        self.members = try container.decode([ListMember].self, forKey: .members)
//        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
//        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
//    }
//    
//    nonisolated func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(id, forKey: .id)
//        try container.encode(name, forKey: .name)
//        try container.encodeIfPresent(description, forKey: .description)
//        try container.encode(ownerId, forKey: .ownerId)
//        try container.encode(ownerName, forKey: .ownerName)
//        try container.encode(members, forKey: .members)
//        try container.encode(createdAt, forKey: .createdAt)
//        try container.encode(updatedAt, forKey: .updatedAt)
//    }
//    
//    private enum CodingKeys: String, CodingKey {
//        case id, name, description, ownerId, ownerName, members, createdAt, updatedAt
//    }
//}
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
