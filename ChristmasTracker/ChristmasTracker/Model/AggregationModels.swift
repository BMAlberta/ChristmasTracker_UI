//
//  HomeListData.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation
import SwiftUI


struct AppDataResponse: Codable, Equatable {
    var appData: AppData
}

struct AppData: Codable, Equatable {
    let userMetadata: UserMetadata
    var listOverviews: [ListSummary]
    let activity: [ActivityItem]
}

struct HomeOverview: Codable, Equatable {
    let listOverviews: [ListSummary]
    let recentActivity: [ActivityItem]
}

struct HomeFeedResponse: Decodable {
    let feed: HomeOverview
}


