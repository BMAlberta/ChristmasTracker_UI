//
//  MockPurchaseRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/16/26.
//

import Foundation

actor MockPurchaseRepository: PurchaseRepository {
    
    private var purchases: [Purchase] = []
    private var nextId = 1
    
    var shouldFail: Bool = false
    var delay: TimeInterval = 0.5
    
    init(withMockData: Bool = true) {
        if withMockData {
            purchases = MockPurchaseData.allPurchases
            nextId = 100
        }
    }
    
    func fetchPurchases(itemId: String) async throws -> [Purchase] {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw PurchaseError.fetchFailed
        }
        
        let itemPurchases = purchases.filter { $0.itemId == itemId }
        
        LogInfo("Mock: Fetched \(itemPurchases.count) purchases for item \(itemId)", category: .business)
        
        return itemPurchases
    }
    
    func createPurchase(itemId: String, _ request: CreatePurchaseRequest) async throws -> CreatePurchaseResponse {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw PurchaseError.createFailed
        }
        
        let shouldWarn = Double.random(in: 0...1) < 0.1
        
        if shouldWarn && request.confirmationToken == nil {
            LogInfo("Mock: Simulating budget overage warning", category: .business)
            
            let warning = PurchaseWarning(code: 6002,
                                          warningCode: "BUDGET_OVERAGE_WARNING",
                                          message: "This purchase will exceed your budget for Tommy by $50",
                                          severity: "warning",
                                          requiresConfirmation: true,
                                          details: WarningDetails(recipientId: "recipient-1",
                                                                  recipientName: "Tommy", budgetLimit: 300.00,
                                                                  currentSpent: 250.00,
                                                                  purchaseAmount: request.totalCost,
                                                                  overage: 50),
                                          confirmationToken: "mock_confirm_\(UUID().uuidString)")
            
            return CreatePurchaseResponse(success: true,
                                          data: CreatePurchaseData(purchaseId: nil,
                                                                   requiresConfirmation: true,
                                                                   purchase: nil),
                                          warnings: [warning])
        }
        
        let newPurchase = Purchase(
            id: "\(nextId)",
            itemId: itemId,
            quantity: request.quantity,
            totalCost: request.totalCost,
            storeName: request.storeName,
            notes: request.notes,
            confirmationNumber: request.confirmationNumber,
            trackingNumber: request.trackingNumber,
            shippingStatus: .notShipped,
            shippedAt: nil,
            deliveredAt: nil,
            purchaser: PurchasePerson(id: "current-user", displayName: "Current User"),
            recipient: PurchasePerson(id: "recipient-1", displayName: "Recipient"),
            purchasedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        nextId += 1
        purchases.append(newPurchase)
        
        LogInfo("Mock: Created purchase \(newPurchase.id)", category: .business)
        
        return CreatePurchaseResponse(success: true,
                                      data: CreatePurchaseData(purchaseId: newPurchase.id,
                                                               requiresConfirmation: false,
                                                               purchase: newPurchase),
                                      warnings: nil)
    }
    
    func updatePurchase(id: String, _ request: UpdatePurchaseRequest) async throws -> Purchase {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw PurchaseError.updateFailed
        }
        
        guard let index = purchases.firstIndex(where: { $0.id == id }) else {
            throw PurchaseError.notFound
        }
        
        let existing = purchases[index]
        
        let updated = Purchase(
            id: existing.id,
            itemId: existing.itemId,
            quantity: request.quantity ?? existing.quantity,
            totalCost: request.totalCost ?? existing.totalCost,
            storeName: request.storeName ?? existing.storeName,
            notes: request.notes ?? existing.notes,
            confirmationNumber: request.confirmationNumber ?? existing.confirmationNumber,
            trackingNumber: request.trackingNumber ?? existing.trackingNumber,
            shippingStatus: request.shippingStatus ?? existing.shippingStatus,
            shippedAt: request.shippingStatus == .shipped ? Date() : existing.shippedAt,
            deliveredAt: request.shippingStatus == .delivered ? Date() : existing.deliveredAt,
            purchaser: existing.purchaser,
            recipient: existing.recipient,
            purchasedAt: existing.purchasedAt,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        
        purchases[index] = updated
        
        LogInfo("Mock: Updated purchase \(updated.id)", category: .business)
        
        return updated
    }
    
    func deletePurchase(id: String) async throws {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw PurchaseError.deleteFailed
        }
        
        guard let index = purchases.firstIndex(where: { $0.id == id }) else {
            throw PurchaseError.notFound
        }
        
        let deleted = purchases.remove(at: index)
        
        LogInfo("Mock: Deleted purchase \(deleted.id)", category: .business)
    }
}

// MARK: - Purchase Errors

enum PurchaseError: Error, LocalizedError {
    case fetchFailed
    case notFound
    case createFailed
    case updateFailed
    case deleteFailed
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to load purchases"
        case .notFound:
            return "Purchase not found"
        case .createFailed:
            return "Failed to record purchase"
        case .updateFailed:
            return "Failed to update purchase"
        case .deleteFailed:
            return "Failed to delete purchase"
        case .unauthorized:
            return "You don't have permission to perform this action"
        }
    }
}

// MARK: - Mock Data

enum MockPurchaseData {
    static let allPurchases: [Purchase] = [
        // Purchase for Item 1 (LEGO Millennium Falcon)
        Purchase(
            id: "1",
            itemId: "1",
            quantity: 1,
            totalCost: 849.99,
            storeName: "LEGO.com",
            notes: "Used discount code for 10% off",
            confirmationNumber: "LEGO-2024-12345",
            trackingNumber: "1Z999AA10123456784",
            shippingStatus: .delivered,
            shippedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
            deliveredAt: Date().addingTimeInterval(-2 * 24 * 60 * 60),
            purchaser: PurchasePerson(id: "current-user", displayName: "Current User"),
            recipient: PurchasePerson(id: "tommy", displayName: "Tommy"),
            purchasedAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
            createdAt: Date().addingTimeInterval(-7 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
        )
    ]
}
