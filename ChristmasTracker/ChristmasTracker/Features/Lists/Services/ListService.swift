//
//  ListService.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ListService {
    // MARK: - Dependencies
    private let repository: ListRepository
    private let dataStore: ListDataStore
    
    // MARK: - Publlished State
    private(set) var lists: [GiftList] = []
    private(set) var currentListDetail: ListDetail?
    private(set) var isLoading: Bool = false
    private(set) var isRefreshing: Bool = false
    private(set) var error: ListError?
    private(set) var lastUpdated: Date?
    
    // MARK: - Filtering
    
    enum FilterType {
        case all
        case owned
        case shared
    }
    
    var currentFilter: FilterType = .all
    
    var filteredLists: [GiftList] {
        switch currentFilter {
        case .all:
            return lists
        case .owned:
            return lists.filter { $0.myRole == .owner || $0.myRole == .coOwner}
        case .shared:
            return lists.filter { $0.myRole == .owner || $0.myRole == .coOwner }
        }
    }
    
    // MARK: - Initialization
    init(repository: ListRepository, dataStore: ListDataStore) {
        self.repository = repository
        self.dataStore = dataStore
    }
    // MARK: - Public Methods
    func loadLists() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            //Check cache
            let cached = await dataStore.getLists()
            if !cached.isEmpty {
                lists = cached
                isLoading = false
                
                //Background refresh
                if await dataStore.shouldRefresh() {
                    await refreshLists()
                }
                return
            }
            
            // Fetch from repository
            let fetchedLists = try await repository.fetchLists()
            
            // Update cache
            lists = fetchedLists
            lastUpdated = Date()
            
            LogInfo("Loaded \(fetchedLists.count) lists", category: .business)
            
        } catch {
            self.error = handleError(error, operation: "load lists")
        }
    }
    
    func refreshLists() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        error = nil
        
        do {
            let fetchedLists = try await repository.fetchLists()
            await dataStore.setLists(fetchedLists)
            lists = fetchedLists
            lastUpdated = Date()
            
            LogInfo("Refreshed \(fetchedLists.count) lists", category: .business)
        } catch let listError as ListError {
            error = listError
        } catch {
            self.error = handleError(error, operation: "refresh lists")
        }
        
        isRefreshing = false
    }
    
    func loadListDetail(id: String) async {
        isLoading = true
        error = nil
        currentListDetail = nil
        
        do {
            if let cached = await dataStore.getListDetail(id: id) {
                currentListDetail = cached
                isLoading = false
                return
            }
            
            let detail = try await repository.fetchListDetail(id: id)
            
            await dataStore.setListDetail(detail)
            
            currentListDetail = detail
            
            LogInfo("Loaded detail for list `\(detail.name)`", category: .business)
        } catch {
            self.error = handleError(error, operation: "load list details")
        }
        
        isLoading = false
    }
    
    func createList(_ request: CreateListRequest) async throws {
        isLoading = true
        error = nil
        
        do {
            let newList = try await repository.createList(request)
            
            await dataStore.setListDetail(newList)
            
            await refreshLists()
            
            LogInfo("Created list `\(newList.name)`", category: .business)
        } catch {
            self.error = handleError(error, operation: "create list")
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    func updateList(id: String, _ request: UpdateListRequest) async throws {
        isLoading = true
        error = nil
        
        do {
            let updated = try await repository.updateList(id: id, request)
            
            await dataStore.setListDetail(updated)
            
            if currentListDetail?.id == id {
                currentListDetail = updated
            }
            
            await refreshLists()
            
            LogInfo("Updated list '\(updated.name)'", category: .business)
        } catch {
            self.error = handleError(error, operation: "update list")
            isLoading = false
            throw error
        }
        isLoading = false
    }
    
    func deleteList(id: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await repository.deleteList(id: id)
            
            await dataStore.removeList(id: id)
            
            lists.removeAll { $0.id == id }
            
            if currentListDetail?.id == id {
                currentListDetail = nil
            }
            
            LogInfo("Deleted list \(id)", category: .business)
        } catch {
            self.error = handleError(error, operation: "delete list")
            isLoading = false
            throw error
        }
        
        isLoading = false
    }
    
    func clearCurrentDetail() {
        currentListDetail = nil
    }
    
    // MARK: - Private Functions
    
    private func handleError(_ error: Error, operation: String) -> ListError {
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let statusCode, _
            ):
                switch statusCode {
                case 401, 403:
                    LogError("\(operation): Unauthorized (HTTP \(statusCode))", category: .business)
                    return .unauthorized
                case 404:
                    LogError("\(operation): Not found (HTTP 404)", category: .business)
                    return .notFound
                case 409:
                    LogError("\(operation): Conflict (HTTP 409)", category: .business)
                    return .createFailed
                default:
                    LogError("\(operation): HTTP error \(statusCode)", category: .business)
                    return .fetchFailed
                }
            case .networkUnavailable:
                LogError("\(operation): Network unavailable", category: .business)
                return .fetchFailed
            case .decodingError(let underlying):
                LogError("\(operation): Decode error - \(underlying)", category: .business)
                return .fetchFailed
            default:
                LogError("\(operation): Unknown API error", category: .business)
                return .fetchFailed
            }
        } else if let listError = error as? ListError {
            return listError
        } else {
            LogError("\(operation): Unknown error - \(error)", category: .business)
            return .fetchFailed
        }
    }
}


