//
//  HomeListData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

struct HomeOverview: Codable, Equatable {
    
    let listSummaries: [ListSummary]
    let recentActivity: [ActivityItem]
    
}

struct ListSummary: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let owner: LWUserModel
    let status: ListStatus
    let creationDate: String
    let lastUpdateDate: String
    let totalItems: Int
    let purchasedItems: Int
    let members: [LWUserModel]
}


struct LWUserModel: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
}

struct HomeFeedResponse: Decodable {
    let feed: HomeOverview
}

