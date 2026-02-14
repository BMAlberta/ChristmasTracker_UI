//
//  ListDetail.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

nonisolated struct ListDetail: Codable, Identifiable, Sendable {
    
    // MARK: - Basic Info
    
    let id: String
    let name: String
    let theme: String?
    let year: Int
    let description: String?
    
    // MARK: - Settings
    
    let visibility: ListVisibility
    let status: ListStatus
    
    // MARK: - People
    
    let recipient: ListPerson
    let owner: ListPerson
    let coOwner: ListPerson?
    let myRole: ListRole

    // MARK: - Statistics

    let itemCount: Int?
    let purchasedCount: Int?
    let totalBudget: Double?
    let totalSpent: Double?
    
    // MARK: - Members
    
    let members: [ListMember]
    
    // MARK: - Metadata
    
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard let itemCount = itemCount,
              let purchasedCount = purchasedCount,
              itemCount > 0 else {
            return 0
        }
        return Double(purchasedCount) / Double(itemCount)
    }
    
    var isOwner: Bool {
        myRole == .owner
    }
    
    var canEdit: Bool {
        myRole == .owner || myRole == .coOwner
    }
    
    var recipientName: String {
        recipient.displayName
    }
    
    var ownerName: String {
        owner.displayName
    }
}

// MARK: - Request/Response Types

nonisolated struct CreateListRequest: Codable, Sendable {
    let name: String
    let theme: String?
    let year: Int
    let recipientId: String
    let description: String?
    let visibility: ListVisibility
    let coOwnerId: String?
    
    enum CodingKeys: String, CodingKey {
        case name, theme, year, description, visibility
        case recipientId = "recipient_id"
        case coOwnerId = "co_owner_id"
        
    }
}

nonisolated struct UpdateListRequest: Codable, Sendable {
    let name: String?
    let theme: String?
    let description: String?
    let visibility: ListVisibility?
    
    enum CodingKeys: String, CodingKey {
        case name, theme, description, visibility
    }
}

nonisolated struct ListResponse<T: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let data: T
}
