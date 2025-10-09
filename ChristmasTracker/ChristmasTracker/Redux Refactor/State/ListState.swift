//
//  ListState.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/4/25.
//

import Foundation

struct ListState: Equatable, Codable {
    var isLoading: Bool
    var listSummaries: [ListSummary]
    var error: ListError?
    var teaser: Teaser
    
    static let initialState = ListState(
        isLoading: false,
        listSummaries: [],
        error: nil,
        teaser: Teaser(type: .greeting, name: "<name>", message: "Sample teaser message here"))
}


enum ListError: Error, Equatable, LocalizedError, Codable {
    case networkError(String)
    case parsingError
    case noListAvailable
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Failed to load lists: \(error)"
        case .parsingError:
            return "Failed to process list data"
        case .noListAvailable:
            return "No lists available at the moment"
        }
    }
}

