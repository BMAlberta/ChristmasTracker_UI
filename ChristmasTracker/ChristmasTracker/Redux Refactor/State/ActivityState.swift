//
//  ActivityState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

struct ActivityState: Equatable, Codable {
    var isLoading: Bool
    var error: ActivityError?
    var currentActivity: [ActivityItem]
    
    static let initialState = ActivityState(isLoading: false,
                                            error: nil,
                                            currentActivity: [])
}

enum ActivityError: Error, Equatable, LocalizedError, Codable {
    case networkError(String)
    case parsingError
    case noActivityError
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Failed to load lists: \(error)"
        case .parsingError:
            return "Failed to process list data"
        case .noActivityError:
            return "No lists available at the moment"
        }
    }
}

