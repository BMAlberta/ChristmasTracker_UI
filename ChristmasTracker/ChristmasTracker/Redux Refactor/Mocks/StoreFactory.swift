//
//  StoreFactory.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 10/2/25.
//

import Foundation
import UIKit

final class StoreFactory {
    @MainActor static func createProductionStore() -> Store<AppState> {
        let apiService = APIService() // Real API service
//        let persistenceService = PersistenceService()
        
//        return createStore(apiService: apiService, persistenceService: persistenceService)
        
//        for family in UIFont.familyNames.sorted() {
//            let names = UIFont.fontNames(forFamilyName: family)
//            print("XXXX: Family: \(family) Font names: \(names)")
//        }
        
        return createStore(apiService: apiService)
    }
    
    @MainActor static func createMockStore(shouldSimulateErrors: Bool = false) -> Store<AppState> {
//        let apiService = MockAPIService(delay: 0.5, shouldSimulateErrors: shouldSimulateErrors)
        
//        let persistenceService = PersistenceService()
        
//        return createStore(apiService: apiService, persistenceService: persistenceService)
        return createStore(apiService: MockAPIService())
    }
    
    @MainActor private static func createStore(
        apiService: APIServiceProviding,
//        persistenceService: PersistenceService
    ) -> Store<AppState> {
        let middleware: [any Middleware<AppState>] = [
//            AsyncMiddleware(apiService: apiService, persistenceService: persistenceService),
            AsyncMiddleware(apiService: apiService),
            AnalyticsMiddleware()
//            PersistenceMiddleware(),
        ]
        
        // Load persisted state if available
//        let initialState = loadPersistedState() ?? AppState.initial
        let initialState = AppState.initialState
        
        return Store(
            initialState: initialState,
            reducer: appReducer,
            middleware: middleware
        )
    }
    
//    private static func loadPersistedState() -> AppState? {
//        return PersistenceMiddleware<AppState>.loadPersistedState()
//    }
    
    private static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
