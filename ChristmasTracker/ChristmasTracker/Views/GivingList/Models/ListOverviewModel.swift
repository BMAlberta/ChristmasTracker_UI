//
//  ListOverviewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation


struct ListOverview: Decodable, Identifiable {
    
    /// Trimmed down user summary
    let user: SlimUserModel
    
    /// Total number of items in the list.
    let totalItems: Int
    
    /// Total number of items purchased from the list.
    let purchasedItems: Int
    
    /// List identifier
    var id: String
    
    enum CodingKeys: String, CodingKey {
        case user
        case totalItems
        case purchasedItems
        case id = "_id"
    }
}

struct UserListOverviewResponse: Decodable {
    let listOverviews: [ListOverview]
}


enum ListStatus: String, Decodable {
    case active = "active"
    case archive = "archive"
    case expired = "expired"
}

struct ListOverviewDetails: Decodable, Identifiable {
    
    /// Name of the list.
    let listName: String
    
    /// Total number of items in the list.
    let totalItems: Int
    
    /// Total purchased items in the list.
    let purchasedItems: Int
    
    /// List identifier
    var id: String
    
    /// Date on which the list was last updated.
    var lastUpdateDate: String
    
    /// Enumeration denoting the status of the list.
    var listStatus: ListStatus
    
    /// Trimmed down user model for the list owner.
    let ownerInfo: SlimUserModel
    
    /// List of users who are members of the list.
    let memberDetails: [MemberDetail]
    
    enum CodingKeys: String, CodingKey {
        case listName
        case totalItems
        case purchasedItems
        case ownerInfo
        case listStatus
        case lastUpdateDate
        case id = "_id"
        case memberDetails
    }
}

struct MemberDetail: Decodable {
    
    /// User's first name.
    let firstName: String
    
    /// User's last name.
    let lastName: String
    
    /// User identifier.
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case id
    }
}
struct ListDetailModel: Decodable {
    
    /// List name.
    let name: String
    
    /// List owner.
    let owner: String
    
    /// List of member ids.
    let members: [String]
    
    /// List identifier.
    let id: String
    
    /// Date on which the list was created.
    let creationDate: String
    
    /// Date on which the list was last updated.
    let lastUpdateDate: String
    
    /// Stats of the list.
    var status: ListStatus
    
    /// List of items.
    let items: [Item]
    var __v: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case owner
        case members
        case id = "_id"
        case creationDate
        case lastUpdateDate
        case items
        case status
        case __v
    }
}

struct ListDetailResponse: Decodable {
    let detail: ListDetailModel
}

struct ListOverviewResponse: Decodable {
    let listOverviews: [ListOverviewDetails]
}

struct OwnedListResponse: Decodable {
    let ownedLists: [OwnedListModel]
}

struct OwnedListModel: Decodable {
    
    /// Name of the list
    let name: String
    
    /// List of members.
    let members: [String]
    
    /// List identifier.
    let id: String
    
    /// Date on which the list was created.
    let creationDate: String
    
    /// List status.
    var status: ListStatus = .archive
    
    /// Date on which the list was last updated.
    let lastUpdateDate: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case members
        case id = "_id"
        case creationDate
        case lastUpdateDate
        case status
    }
}

typealias ListInfo = (listId: String, listStatus: ListStatus)
