//
//  NetworkItemRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

actor NetworkItemRepository: ItemRepository {

    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - ItemRepository
    func fetchItems(listId: String) async throws -> [GiftItem] {
        LogDebug("Fetching items for list \(listId)", category: .business)
        
        do {
            let itemResponse: ItemsResponse = try await apiClient.request(.get,
                                                                         path: "/lists/\(listId)/items",
                                                                         body: .none,
                                                                         forceRefresh: false,
                                                                         cacheScope: .items)
            
            LogInfo("Fetched \(itemResponse.data.items.count) items for list \(listId)", category: .business)
            return itemResponse.data.items
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "fetch items")
        }
    }
    
    func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem {
        LogDebug("Creating item '\(request.name)' in list \(listId)", category: .business)
        
        do {
            let itemResponse: ItemResponse = try await apiClient.request(.post,
                                                                         path: "/lists/\(listId)/items",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .items)
            
            LogInfo("Created item '\(itemResponse.data.name)' with ID \(itemResponse.data.id)")
            return itemResponse.data
        } catch let error as APIError {
            throw mapAPIError(error, operation: "create item")
        }
    }
    
    func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem {
        LogDebug("Updating item \(id)", category: .business)
        
        do {
            let itemResponse: ItemResponse = try await apiClient.request(.put,
                                                                         path: "items/\(id)",
                                                                         body: request,
                                                                         forceRefresh: true,
                                                                         cacheScope: .items)
            
            LogInfo("Updated item '\(itemResponse.data.name)'", category: .business)
            return itemResponse.data
        } catch let error as APIError {
            throw mapAPIError(error, operation: "update item")
        }
    }
    
    func deleteItem(id: String) async throws {
        LogDebug("Deleting item \(id)", category: .business)
        
        do {
            struct EmptyData: Codable {}
            let _: ItemResponse = try await apiClient.request(.delete,
                                                              path: "/items/\(id)",
                                                              body: .none,
                                                              forceRefresh: true,
                                                              cacheScope: .items)
            
            LogInfo("Deleted item \(id)", category: .business)
        } catch let error as APIError {
            throw mapAPIError(error, operation: "delete item")
        }
    }
    
    func fetchItemDetail(id: String) async throws -> GiftItem {
        LogDebug("Fetching item details: \(id)", category: .business)
        
        do {
            let itemResponse: ItemResponse = try await apiClient.request(.get,
                                                               path: "/items/\(id)",
                                                               body: .none,
                                                               forceRefresh: false,
                                                               cacheScope: .items)

            LogInfo("Fetched item details: \(itemResponse.data.id)", category: .business)
            
            return itemResponse.data
        } catch let error as APIError {
            throw mapAPIError(error, operation: "fetch item details")
        }
    }
    
    
//    struct ItemResponse: Codable, Sendable {
//    let success: Bool
//    let data: GiftItem
//    }
    // MARK: - Error Mapping
    private func mapAPIError(
        _ error: APIError, operation: String) -> ItemError {
            switch error {
            case .httpError(let statusCode, _):
                switch statusCode {
                case 401, 403:
                    LogError("\(operation): Unauthorized", category: .business)
                    return .unauthorized
                case 404:
                    LogError("\(operation): Not found", category: .business)
                    return .notFound
                default:
                    LogError("\(operation): HTTP \(statusCode)", category: .business)
                    return .fetchFailed
                }
            case .networkUnavailable:
                LogError("\(operation): Network unavailable", category: .business)
                return .fetchFailed
            case .decodingError(let underlyingError):
                LogError("\(operation): Decode error - \(underlyingError)", category: .business)
                return .fetchFailed
            default:
                LogError("\(operation): Unknown API error", category: .business)
                return .fetchFailed
            }
        }
}
