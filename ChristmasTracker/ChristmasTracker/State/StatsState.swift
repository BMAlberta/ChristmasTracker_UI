//
//  StatsState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/8/25.
//

import Foundation
struct StatsState: Equatable, Codable {
    var isLoading: Bool
    var error: StatsError?
    var stats: [String]
    
    static let initialState = StatsState(isLoading: false,
                                            error: nil,
                                         stats: [])
}

enum StatsError: Error, Equatable, LocalizedError, Codable {
    case networkError(String)
    case parsingError
    case noStatsError
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Failed to load stats: \(error)"
        case .parsingError:
            return "Failed to process stats data"
        case .noStatsError:
            return "No stats available at the moment"
        }
    }
}
