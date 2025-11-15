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
    var purchaseSuccess: Bool
    var retractedPurchaseSuccess: Bool
    var listIdInContext: String
    var addItemInProgress: Bool
    var addItemSuccess: Bool
    var addListInProgress: Bool
    var addListSuccess: Bool
    var deleteListSuccess: Bool
    var updateItemSuccess: Bool
    
    
    static let initialState = ListState(
        isLoading: false,
        listSummaries: [MockData.sampleListDetail],
        error: nil,
        purchaseSuccess: false,
        retractedPurchaseSuccess: false,
        listIdInContext: "",
        addItemInProgress: false,
        addItemSuccess: false,
        addListInProgress: false,
        addListSuccess: false,
        deleteListSuccess: false,
        updateItemSuccess: false
        )
}


enum ListError: Error, Equatable, LocalizedError, Codable {
    case networkError(String)
    case parsingError
    case noListAvailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Failed to load lists: \(error)"
        case .parsingError:
            return "Failed to process list data"
        case .noListAvailable:
            return "No lists available at the moment"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct ListUtility {
    static func mapIdToIndex(id: String, appState: AppState) -> Int {
        
        let lists = appState.list.listSummaries
        
        guard let listIndex = lists.firstIndex(where: { $0.id == id }) else {
            #if DEBUG
            return 0
            #endif
        }
        return listIndex
    }
    
    static func mapItemIdToItemToIndex(itemId: String, listIdInContext: String, appState: AppState) -> Int {
        
        let listIndex = ListUtility.mapIdToIndex(id: appState.list.listIdInContext, appState: appState)
        let listInContext = appState.list.listSummaries[listIndex]
        
        guard let itemIndexInContext = listInContext.items.firstIndex(where: { $0.id == itemId }) else {
        #if DEBUG
        return 0
        #endif
        }
        
        return itemIndexInContext
    }
}

extension String {
    func containsNonNumericOrPeriod() -> Bool {
        // Create a CharacterSet containing allowed characters: digits and period.
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))

        // Find if there's any character in the string that is NOT in the allowed set.
        // The `inverted` property creates a CharacterSet with all characters *not* in the original set.
        return self.rangeOfCharacter(from: allowedCharacters.inverted) != nil
    }
}
