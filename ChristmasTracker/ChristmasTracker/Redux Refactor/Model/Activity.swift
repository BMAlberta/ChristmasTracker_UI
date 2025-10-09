//
//  Activity.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation


struct ActivityItem: Identifiable, Codable, Equatable {
    enum ActivityType: String, Codable {
        case purchase
        case retraction
        case itemAddition
        case itemRemoval
        case listAddition
        case listRemoval
    }
    
    let id: String
    let type: ActivityType
    let owner: LWUserModel
    let date: String
    let primaryDataPoint: String
    let secondaryDataPoint: String
    
}


