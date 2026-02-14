//
//  NetworkListRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/13/26.
//

import Foundation

actor NetworkListRepository: ListRepository {
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - ListRepository
    func fetchLists() async throws -> [GiftList] {
        LogDebug("Fetching lists from API", category: .business)
        
        do {
            let response: ListResponse<ListsData> = try await apiClient.request(.get,
                                                                                path: "/lists",
                                                                                body: .none,
                                                                                forceRefresh: false,
                                                                                cacheScope: .lists)
            
            LogInfo("Fetched \(response.data.lists.count) lists from API", category: .business)
            return response.data.lists
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "Fetch lists")
        }
    }
    
    func fetchListDetail(id: String) async throws -> ListDetail {
        LogDebug("Fetching detail for list \(id)", category: .business)
        
        do {
            let response: ListResponse<ListDetail> = try await apiClient.request(.get,
                                                                               path: "/lists/\(id)",
                                                                               body: .none,
                                                                               forceRefresh: false,
                                                                               cacheScope: .lists)
            LogInfo("Fetched detail for '\(response.data.name)'", category: .business)
            return response.data
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "Fetch list detail")
        }
    }
    
    func createList(_ request: CreateListRequest) async throws -> ListDetail {
        LogDebug("Creating list '\(request.name)'", category: .business)
        
        do {
            let response: ListResponse<ListDetail> = try await apiClient.request(.post,
                                                                                 path: "/lists",
                                                                                 body: request,
                                                                                 forceRefresh: true,
                                                                                 cacheScope: .lists)
            
            LogInfo("Created list '\(response.data.name)'", category: .business)
            return response.data
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "Create list")
        }
    }
    
    func updateList(id: String, _ request: UpdateListRequest) async throws -> ListDetail {
        LogDebug("Updating list \(id)", category: .business)
        
        do {
            let response: ListResponse<ListDetail> = try await apiClient.request(.put,
                                                                                 path: "/lists/\(id)",
                                                                                 body: request,
                                                                                 forceRefresh: true,
                                                                                 cacheScope: .lists)
            LogInfo("Updated lists '\(response.data.name)'", category: .business)
            return response.data
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "Update list")
        }
    }
    
    func deleteList(id: String) async throws {
        LogDebug("Deleting list \(id)", category: .business)
        
        do {
            struct EmptyData: Codable {}
            let _ : ListResponse<EmptyData> = try await apiClient.request(.delete,
                                                                          path: "/lists/\(id)",
                                                                          body: .none,
                                                                          forceRefresh: true,
                                                                          cacheScope: .lists)
            
            LogInfo("Deleted lists \(id)", category: .business)
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "Delete list")
        }
    }
    
    // MARK: - Error Mapping
    private func mapAPIError(
        _ error: APIError, operation: String) -> ListError {
            switch error {
            case .httpError(let statusCode, _
            ):
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
    
    // MARK: - Supporting Types
    struct ListsData: Codable, Sendable {
        let lists: [GiftList]
    }
}
