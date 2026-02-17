//
//  MockItemRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//

import Foundation

actor MockItemRepository: ItemRepository {
    
    // MARK: - Mock Data Storage
    
    private var items: [GiftItem] = []
    private var nextId = 1
    
    // MARK: - Configuration
    
    var shouldFail = false
    var delay: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    init(withMockData: Bool = true) {
        if withMockData {
            items = MockItemData.allItems
            nextId = 100
        }
    }
    
    // MARK: - ItemRepository Implementation
    func fetchItems(listId: String) async throws -> [GiftItem] {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ItemError.fetchFailed
        }
        
        let listItems = items.filter { $0.listId == listId }
        LogInfo("Mock: Fetched \(listItems.count) items for list \(listId)", category: .business)
        return listItems
    }
    
    func createItem(listId: String, _ request: CreateItemRequest) async throws -> GiftItem {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ItemError.createFailed
        }
        
        let newItem = GiftItem(id: "\(nextId)",
                               listId: listId,
                               name: request.name,
                               description: request.description,
                               url: request.url,
                               imageUrl: request.imageUrl,
                               expectedUnitPrice: request.expectedUnitPrice,
                               quantityRequested: request.quantityRequested,
                               priority: request.priority,
                               status: .available,
                               offList: request.offList,
                               createdBy: ItemPerson(id: "current-user", displayName: "Current User"),
                               createdAt: Date(),
                               updatedAt: Date(),
                               purchases: nil,
                               totalQuantityPurchased: nil
        )
        
        nextId += 1
        items.append(newItem)
        
        LogInfo("Mock: Created item '\(newItem.name)'", category: .business)
        
        return newItem
    }
    
    func updateItem(id: String, _ request: UpdateItemRequest) async throws -> GiftItem {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ItemError.updateFailed
        }
        
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ItemError.notFound
        }
        
        let existing = items[index]
        
        let updated = GiftItem(id: existing.id,
                               listId: existing.listId,
                               name: request.name ?? existing.name,
                               description: request.description ?? existing.description,
                               url: request.url ?? existing.url,
                               imageUrl: request.imageUrl ?? existing.url,
                               expectedUnitPrice: request.expectedUnitPrice ?? existing.expectedUnitPrice,
                               quantityRequested: request.quantityRequested ?? existing.quantityRequested,
                               priority: request.priority ?? existing.priority,
                               status: existing.status,
                               offList: existing.offList,
                               createdBy: existing.createdBy,
                               createdAt: existing.createdAt,
                               updatedAt: Date(),
                               purchases: nil,
                               totalQuantityPurchased: nil)
        items[index] = updated
        LogInfo("Mock: Updated item '\(updated.name)'", category: .business)
        return updated
    }
    
    func deleteItem(id: String) async throws {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ItemError.deleteFailed
        }
        
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ItemError.notFound
        }
        
        let deleted = items.remove(at: index)
        
        LogInfo("Mock: Deleted item '\(deleted.name)'", category: .business)
    }
    
    func fetchItemDetail(id: String) async throws -> GiftItem {
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw ItemError.fetchFailed
        }
        
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ItemError.notFound
        }
        
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw ItemError.notFound
        }
        
        return items[index]
    }
}

// MARK: - Item Errors

enum ItemError: Error, LocalizedError {
    case fetchFailed
    case notFound
    case createFailed
    case updateFailed
    case deleteFailed
    case purchaseFailed
    case unauthorized
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to load items"
        case .notFound:
            return "Item not found"
        case .createFailed:
            return "Failed to create item"
        case .updateFailed:
            return "Failed to update item"
        case .deleteFailed:
            return "Failed to delete item"
        case .purchaseFailed:
            return "Failed to update purchase status"
        case .unauthorized:
            return "You don't have permission to perform this action"
        }
    }
}

// MARK: - Mock Data

//enum MockItemData {
//    static let allItems: [GiftItem] = [
//        // Items for List "1" (Christmas 2024 - Tommy)
//        GiftItem(
//            id: "1",
//            listId: "1",
//            name: "LEGO Star Wars Millennium Falcon",
//            description: "Ultimate Collector's Edition - 7,541 pieces",
//            url: "https://www.lego.com/en-us/product/millennium-falcon-75192",
//            imageUrl: nil,
//            expectedUnitPrice: 849.99,
//            quantityRequested: 1,
//            priority: 10,
//            status: .purchased,
//            offList: false,
//            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
//            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
//            updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60),
//            purchases: nil
//        ),
//        GiftItem(
//            id: "2",
//            listId: "1",
//            name: "Nintendo Switch OLED",
//            description: "With Mario Kart 8 Deluxe bundle",
//            url: nil,
//            imageUrl: nil,
//            expectedUnitPrice: 349.99,
//            quantityRequested: 1,
//            priority: 9,
//            status: .available,
//            offList: false,
//            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
//            createdAt: Date().addingTimeInterval(-25 * 24 * 60 * 60),
//            updatedAt: Date().addingTimeInterval(-25 * 24 * 60 * 60),
//            purchases: nil
//        ),
//        GiftItem(
//            id: "3",
//            listId: "1",
//            name: "AirPods Pro",
//            description: "2nd Generation with MagSafe charging",
//            url: "https://www.apple.com/airpods-pro/",
//            imageUrl: nil,
//            expectedUnitPrice: 249.00,
//            quantityRequested: 1,
//            priority: 8,
//            status: .wrapped,
//            offList: false,
//            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
//            createdAt: Date().addingTimeInterval(-20 * 24 * 60 * 60),
//            updatedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
//            purchases: nil
//        ),
//        // Items for List "2" (My Birthday List)
//        GiftItem(
//            id: "10",
//            listId: "2",
//            name: "Surprise Gift",
//            description: "Something special!",
//            url: nil,
//            imageUrl: nil,
//            expectedUnitPrice: 150.00,
//            quantityRequested: 1,
//            priority: 5,
//            status: .gifted,
//            offList: true, // Hidden from list owner
//            createdBy: ItemPerson(id: "friend-1", displayName: "Best Friend"),
//            createdAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
//            updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
//            purchases: nil
//        ),
//        // Items for List "3" (Holiday Shopping - Mom)
//        GiftItem(
//            id: "20",
//            listId: "3",
//            name: "Kindle Paperwhite",
//            description: "16GB, with special offers",
//            url: "https://www.amazon.com/dp/B08KTZ8249",
//            imageUrl: nil,
//            expectedUnitPrice: 139.99,
//            quantityRequested: 1,
//            priority: 7,
//            status: .purchased,
//            offList: false,
//            createdBy: ItemPerson(id: "o2", displayName: "Dad"),
//            createdAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
//            updatedAt: Date().addingTimeInterval(-14 * 24 * 60 * 60),
//            purchases: nil
//        )
//    ]
//}


enum MockItemData {
    static let allItems: [GiftItem] = [
        // Items for List "1" (Christmas 2024 - Tommy)
        GiftItem(
            id: "1",
            listId: "1",
            name: "LEGO Star Wars Millennium Falcon",
            description: "Ultimate Collector's Edition - 7,541 pieces",
            url: "https://www.lego.com/en-us/product/millennium-falcon-75192",
            imageUrl: nil,
            expectedUnitPrice: 849.99,
            quantityRequested: 1,
            priority: 10,
            status: .purchased,
            offList: false,
            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60),
            // ✅ NEW - Purchase data
            purchases: [
                PurchaseSummary(
                    id: "purchase-1",
                    quantity: 1,
                    totalCost: 849.99,
                    purchaser: PurchasePerson(id: "user-2", displayName: "John Smith"),
                    shippingStatus: .shipped,
                    purchasedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 1
        ),
        
        GiftItem(
            id: "2",
            listId: "1",
            name: "Nintendo Switch OLED",
            description: "With Mario Kart 8 Deluxe bundle",
            url: nil,
            imageUrl: nil,
            expectedUnitPrice: 349.99,
            quantityRequested: 1,
            priority: 9,
            status: .available,
            offList: false,
            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
            createdAt: Date().addingTimeInterval(-25 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-25 * 24 * 60 * 60),
            // ✅ No purchases yet
            purchases: nil,
            totalQuantityPurchased: nil
        ),
        
        GiftItem(
            id: "3",
            listId: "1",
            name: "AirPods Pro",
            description: "2nd Generation with MagSafe charging",
            url: "https://www.apple.com/airpods-pro/",
            imageUrl: nil,
            expectedUnitPrice: 249.00,
            quantityRequested: 1,
            priority: 8,
            status: .wrapped,
            offList: false,
            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
            createdAt: Date().addingTimeInterval(-20 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-5 * 24 * 60 * 60),
            // ✅ Purchased and wrapped
            purchases: [
                PurchaseSummary(
                    id: "purchase-3",
                    quantity: 1,
                    totalCost: 249.00,
                    purchaser: PurchasePerson(id: "user-3", displayName: "Sarah Johnson"),
                    shippingStatus: .delivered,
                    purchasedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 1
        ),
        
        // ✅ NEW - Item with PARTIAL purchases (demonstrating multiple purchases)
        GiftItem(
            id: "4",
            listId: "1",
            name: "Magic: The Gathering Booster Packs",
            description: "Latest set booster boxes",
            url: nil,
            imageUrl: nil,
            expectedUnitPrice: 4.99,
            quantityRequested: 5,
            priority: 6,
            status: .partial,
            offList: false,
            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
            createdAt: Date().addingTimeInterval(-15 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-3 * 24 * 60 * 60),
            // ✅ Two partial purchases
            purchases: [
                PurchaseSummary(
                    id: "purchase-4a",
                    quantity: 2,
                    totalCost: 9.98,
                    purchaser: PurchasePerson(id: "user-2", displayName: "John Smith"),
                    shippingStatus: .notShipped,
                    purchasedAt: Date().addingTimeInterval(-7 * 24 * 60 * 60)
                ),
                PurchaseSummary(
                    id: "purchase-4b",
                    quantity: 1,
                    totalCost: 4.99,
                    purchaser: PurchasePerson(id: "user-3", displayName: "Sarah Johnson"),
                    shippingStatus: .shipped,
                    purchasedAt: Date().addingTimeInterval(-3 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 3  // 2 + 1 = 3 of 5 requested
        ),
        
        // ✅ NEW - Item with OVER-purchase (optimistic concurrency example)
        GiftItem(
            id: "5",
            listId: "1",
            name: "Pokémon Cards - Rare Charizard",
            description: "Holographic first edition",
            url: nil,
            imageUrl: nil,
            expectedUnitPrice: 200.00,
            quantityRequested: 1,
            priority: 9,
            status: .purchased,
            offList: false,
            createdBy: ItemPerson(id: "owner-1", displayName: "Jane Doe"),
            createdAt: Date().addingTimeInterval(-18 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
            // ✅ TWO purchases (both bought it!) - optimistic concurrency
            purchases: [
                PurchaseSummary(
                    id: "purchase-5a",
                    quantity: 1,
                    totalCost: 200.00,
                    purchaser: PurchasePerson(id: "user-2", displayName: "John Smith"),
                    shippingStatus: .shipped,
                    purchasedAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
                ),
                PurchaseSummary(
                    id: "purchase-5b",
                    quantity: 1,
                    totalCost: 195.00,
                    purchaser: PurchasePerson(id: "user-3", displayName: "Sarah Johnson"),
                    shippingStatus: .delivered,
                    purchasedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 2  // Over-purchased! (requested 1, got 2)
        ),
        
        // Items for List "2" (My Birthday List)
        GiftItem(
            id: "10",
            listId: "2",
            name: "Surprise Gift",
            description: "Something special!",
            url: nil,
            imageUrl: nil,
            expectedUnitPrice: 150.00,
            quantityRequested: 1,
            priority: 5,
            status: .gifted,
            offList: true,  // Hidden from list owner
            createdBy: ItemPerson(id: "friend-1", displayName: "Best Friend"),
            createdAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
            // ✅ Already gifted
            purchases: [
                PurchaseSummary(
                    id: "purchase-10",
                    quantity: 1,
                    totalCost: 150.00,
                    purchaser: PurchasePerson(id: "friend-1", displayName: "Best Friend"),
                    shippingStatus: .delivered,
                    purchasedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 1
        ),
        
        // Items for List "3" (Holiday Shopping - Mom)
        GiftItem(
            id: "20",
            listId: "3",
            name: "Kindle Paperwhite",
            description: "16GB, with special offers",
            url: "https://www.amazon.com/dp/B08KTZ8249",
            imageUrl: nil,
            expectedUnitPrice: 139.99,
            quantityRequested: 1,
            priority: 7,
            status: .purchased,
            offList: false,
            createdBy: ItemPerson(id: "owner-2", displayName: "Dad"),
            createdAt: Date().addingTimeInterval(-60 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-14 * 24 * 60 * 60),
            // ✅ Purchased by Dad
            purchases: [
                PurchaseSummary(
                    id: "purchase-20",
                    quantity: 1,
                    totalCost: 139.99,
                    purchaser: PurchasePerson(id: "owner-2", displayName: "Dad"),
                    shippingStatus: .notShipped,
                    purchasedAt: Date().addingTimeInterval(-14 * 24 * 60 * 60)
                )
            ],
            totalQuantityPurchased: 1
        ),
        
        // ✅ NEW - Item with no price (optional field)
        GiftItem(
            id: "21",
            listId: "3",
            name: "Handmade Scarf",
            description: "Custom knitted scarf in mom's favorite colors",
            url: nil,
            imageUrl: nil,
            expectedUnitPrice: nil,  // No price set
            quantityRequested: 1,
            priority: 10,
            status: .available,
            offList: false,
            createdBy: ItemPerson(id: "owner-2", displayName: "Dad"),
            createdAt: Date().addingTimeInterval(-45 * 24 * 60 * 60),
            updatedAt: Date().addingTimeInterval(-45 * 24 * 60 * 60),
            purchases: nil,
            totalQuantityPurchased: nil
        )
    ]
}
