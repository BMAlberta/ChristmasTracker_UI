//
//  GiftList.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import Foundation
import SwiftUI

/// List summary returned by GET /lists
/// Matches backend ListSummary schema
nonisolated struct GiftList: Codable, Identifiable, Sendable {
    // MARK: - Basic Info
    let id: String
    let name: String
    let theme: String?
    let year: Int
    
    // MARK: - Settings
    let visibility: ListVisibility
    let status: ListStatus
    
    // MARK: - Nested Objects
    let recipient: ListPerson
    let owner: ListPerson
    let coOwner: ListPerson?
    
    // MARK: - Current User's Role
    let myRole: ListRole
    
    // MARK: - Statistics
    /// Note: Omitted for list owners to prevent revealing surprise gifts
    let itemCount: Int?
    
    /// Note: Omitted for list owners
    let purchasedCount: Int?
    
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
    
    /// Display name for recipient
    var recipientName: String {
        recipient.displayName
    }
    
    /// Display name for owner
    var ownerName: String {
        owner.displayName
    }
}

// MARK: - ListPerson (Nested Object)

struct ListPerson: Codable, Sendable, Identifiable {
    let id: String
    let displayName: String
}

// MARK: - Enums

enum ListRole: String, Codable, Sendable {
    case owner = "owner"
    case coOwner = "co-owner"
    case member = "member"
    case viewer = "viewer"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .coOwner: return "Co-Owner"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }
    
    var color: Color {
        switch self {
        case .owner: return .primaryColor
        case .coOwner: return .accentColor
        case .member: return Color.blue
        case .viewer: return Color.gray
        }
    }
}

enum ListVisibility: String, Codable, Sendable {
    case `private` = "PRIVATE"
    case inviteOnly = "INVITE_ONLY"
    case `public` = "PUBLIC"
}

enum ListStatus: String, Codable, Sendable {
    case draft = "DRAFT"
    case active = "ACTIVE"
    case archived = "ARCHIVED"
}
