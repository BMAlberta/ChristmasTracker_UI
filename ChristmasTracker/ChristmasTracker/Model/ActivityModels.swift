//
//  Activity.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation
import SwiftUI

struct ActivityItem: Identifiable, Codable, Equatable {
    enum ActivityType: String, Codable {
        case purchase
        case retraction
        case itemAddition
        case itemRemoval
        case listAddition
        case listRemoval
        
        
        var imageName: String {
            switch self {
            case .purchase:
                return "cart.fill.badge.plus"
            case .retraction:
                return "cart.fill.badge.minus"
            case .itemAddition:
                return "tag.fill"
            case .itemRemoval:
                return "tag.slash.fill"
            case .listAddition:
                return "document.badge.plus.fill"
            case .listRemoval:
                return "document.on.trash.fill"
                
            }
        }
        
        var imageTint: Color {
            switch self {
                
            case .purchase:
                return .primaryGreen
            case .retraction:
                return .primaryRed
            case .itemAddition:
                return .primaryGreen
            case .itemRemoval:
                return .primaryRed
            case .listAddition:
                return .primaryGreen
            case .listRemoval:
                return .primaryRed
            }
        }
    }
    
    let id: String
    let type: ActivityType
    let owner: LWUserModel
    let date: String
    let userName: String
    let itemName: String
    let listName: String
    
}


