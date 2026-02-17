//
//  NetworkPurchaseRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

actor NetworkPurchaseRepository: PurchaseRepository {
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func fetchPurchases(itemId: String) async throws -> [Purchase] {
        LogDebug("Fetching purchases for item \(itemId)", category: .business)
        
        do {
            let response: PurchasesResponse = try await apiClient.request(
                .get,
                path: "/items/\(itemId)/purchases",
                body: Optional<String>.none,
                forceRefresh: false,
                cacheScope: .none
            )
            
            LogInfo("Fetched \(response.data.purchases.count) purchases", category: .business)
            return response.data.purchases
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "fetch purchases")
        }
    }
    
    func createPurchase(itemId: String, _ request: CreatePurchaseRequest) async throws -> CreatePurchaseResponse {
        LogDebug("Creating purchase for item \(itemId)", category: .business)
        
        do {
            let response: CreatePurchaseResponse = try await apiClient.request(
                .post,
                path: "/items/\(itemId)/purchases",
                body: request,
                forceRefresh: true,
                cacheScope: .items  // Invalidate items cache
            )
            
            if response.data.requiresConfirmation {
                LogInfo("Purchase requires confirmation (budget warning)", category: .business)
            } else {
                LogInfo("Created purchase \(response.data.purchaseId ?? "NO_ID")", category: .business)
            }
            
            return response
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "create purchase")
        }
    }
    
    func updatePurchase(id: String, _ request: UpdatePurchaseRequest) async throws -> Purchase {
        LogDebug("Updating purchase \(id)", category: .business)
        
        do {
            let response: PurchaseResponse = try await apiClient.request(
                .put,
                path: "/purchases/\(id)",
                body: request,
                forceRefresh: true,
                cacheScope: .items
            )
            
            LogInfo("Updated purchase \(id)", category: .business)
            return response.data
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "update purchase")
        }
    }
    
    func deletePurchase(id: String) async throws {
        LogDebug("Deleting purchase \(id)", category: .business)
        
        do {
            struct EmptyData: Codable {}
            let _: PurchaseResponse = try await apiClient.request(
                .delete,
                path: "/purchases/\(id)",
                body: Optional<String>.none,
                forceRefresh: true,
                cacheScope: .items
            )
            
            LogInfo("Deleted purchase \(id)", category: .business)
            
        } catch let apiError as APIError {
            throw mapAPIError(apiError, operation: "delete purchase")
        }
    }
    
    private func mapAPIError(_ error: APIError, operation: String) -> PurchaseError {
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
        default:
            LogError("\(operation): Unknown API error", category: .business)
            return .fetchFailed
        }
    }
}
