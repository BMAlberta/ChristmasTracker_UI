//
//  DashboardViewModel.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/12/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    
    // MARK: - Dependencies
    
    private let apiClient: APIClient
    
    // MARK: - Public State
    
    private(set) var lists: [GiftList] = []
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: Error? = nil
    private(set) var lastUpdated: Date?
    
    // MARK: - Initialization
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Public Methods
    
    func loadLists() async {
        guard !isLoading else { return }
        
        do {
            let response: DashboardListsResponse = try await apiClient.request(.get,
                                                                              path: "/lists",
                                                                              body: .none,
                                                                              forceRefresh: false,
                                                                              cacheScope: .lists)
            
            lists = response.lists
            lastUpdated = Date()
            
            LogInfo("Loaded \(lists.count) lists", category: .business)
        } catch {
            self.error = error
            LogError("Failed to load lists: \(error)", category: .business)
        }
    }
    
    
    func refreshLists() async {
        guard !isRefreshing else { return }
        
        do {
            let response: DashboardListsResponse = try await apiClient.request(.get,
                                                                               path: "/lists",
                                                                               body: .none,
                                                                               forceRefresh: true,
                                                                               cacheScope: .lists)
            lists = response.lists
            lastUpdated = Date()
            LogInfo("Refreshed \(lists.count) lists", category: .business)
            
        } catch {
            self.error = error
            LogError("Failed refresh lists: \(error)", category: .business)
        }
    }
    
    func shouldRefreshInBackground() -> Bool {
        guard let lastUpdated = lastUpdated else {
            return true
        }
        
        let fifteenMinutes: TimeInterval = 15 * 60
        return Date().timeIntervalSince(lastUpdated) > fifteenMinutes
    }
}
