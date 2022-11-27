//
//  ListOverviewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 1/8/22.
//

import Foundation


struct ListOverview: Decodable, Identifiable {
    let user: SlimUserModel
    let totalItems: Int
    let purchasedItems: Int
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

struct ListOverviewDetails: Decodable, Identifiable {
    let listName: String
    let totalItems: Int
    let purchasedItems: Int
    var id: String
    var lastUpdateDate: String
    let ownerInfo: SlimUserModel
    let memberDetails: [MemberDetail]
    
    enum CodingKeys: String, CodingKey {
        case listName
        case totalItems
        case purchasedItems
        case ownerInfo
        case lastUpdateDate
        case id = "_id"
        case memberDetails
    }
}

struct MemberDetail: Decodable {
    let firstName: String
    let lastName: String
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case firstName
        case lastName
        case id
    }
}
struct ListDetailModel: Decodable {
    let name: String
    let owner: String
    let members: [String]
    let id: String
    let creationDate: String
    let lastUpdateDate: String
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
    let name: String
    let members: [String]
    let id: String
    let creationDate: String
    let lastUpdateDate: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case members
        case id = "_id"
        case creationDate
        case lastUpdateDate
    }
}
