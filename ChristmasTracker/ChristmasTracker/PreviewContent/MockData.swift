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

/// Placeholder ListMember model (will be replaced in Phase 5)
struct ListMember: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let userEmail: String?
    let role: ListRole
    let joinedAt: Date?
    let invitationStatus: InvitationStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userName = "user_name"
        case userEmail = "user_email"
        case role
        case joinedAt = "joined_at"
        case invitationStatus
    }
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
