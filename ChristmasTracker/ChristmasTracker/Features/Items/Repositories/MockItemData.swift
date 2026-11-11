//
//  MockItemData.swift
//  ChristmasTracker
//
//  LEGACY preview fixtures: the purchase screens (untouched until package I4) take the legacy
//  item type, so their previews build from these. Deleted in I4 with the legacy type.
//

import Foundation

enum MockItemData {
    private static func day(_ days: Double) -> Date {
        Date().addingTimeInterval(-days * 24 * 60 * 60)
    }

    private static let jane = ItemPerson(id: "owner-1", displayName: "Jane Doe")
    private static let dad = ItemPerson(id: "owner-2", displayName: "Dad")
    private static let john = PurchasePerson(id: "user-2", displayName: "John Smith")
    private static let sarah = PurchasePerson(id: "user-3", displayName: "Sarah Johnson")

    static let allItems: [GiftItem] = [
        GiftItem(
            id: "1", listId: "1", name: "LEGO Star Wars Millennium Falcon",
            description: "Ultimate Collector's Edition - 7,541 pieces",
            url: "https://www.lego.com/en-us/product/millennium-falcon-75192", imageUrl: nil,
            expectedUnitPrice: 849.99, quantityRequested: 1, priority: 10, status: .purchased, offList: false,
            createdBy: jane, createdAt: day(30), updatedAt: day(2),
            purchases: [
                PurchaseSummary(
                    id: "purchase-1", quantity: 1, totalCost: 849.99, purchaser: john,
                    shippingStatus: .shipped, purchasedAt: day(5)
                )
            ],
            totalQuantityPurchased: 1
        ),
        GiftItem(
            id: "2", listId: "1", name: "Nintendo Switch OLED", description: "With Mario Kart 8 Deluxe bundle",
            url: nil, imageUrl: nil, expectedUnitPrice: 349.99, quantityRequested: 1, priority: 9,
            status: .available, offList: false, createdBy: jane, createdAt: day(25), updatedAt: day(25),
            purchases: nil, totalQuantityPurchased: nil
        ),
        GiftItem(
            id: "3", listId: "1", name: "AirPods Pro", description: "2nd Generation with MagSafe charging",
            url: "https://www.apple.com/airpods-pro/", imageUrl: nil, expectedUnitPrice: 249.00,
            quantityRequested: 1, priority: 8, status: .wrapped, offList: false,
            createdBy: jane, createdAt: day(20), updatedAt: day(5),
            purchases: [
                PurchaseSummary(
                    id: "purchase-3", quantity: 1, totalCost: 249.00, purchaser: sarah,
                    shippingStatus: .delivered, purchasedAt: day(10)
                )
            ],
            totalQuantityPurchased: 1
        ),
        GiftItem(
            id: "4", listId: "1", name: "Magic: The Gathering Booster Packs",
            description: "Latest set booster boxes", url: nil, imageUrl: nil, expectedUnitPrice: 4.99,
            quantityRequested: 5, priority: 6, status: .partial, offList: false,
            createdBy: jane, createdAt: day(15), updatedAt: day(3),
            purchases: [
                PurchaseSummary(
                    id: "purchase-4a", quantity: 2, totalCost: 9.98, purchaser: john,
                    shippingStatus: .notShipped, purchasedAt: day(7)
                ),
                PurchaseSummary(
                    id: "purchase-4b", quantity: 1, totalCost: 4.99, purchaser: sarah,
                    shippingStatus: .shipped, purchasedAt: day(3)
                )
            ],
            totalQuantityPurchased: 3
        ),
        GiftItem(
            id: "5", listId: "1", name: "Pokémon Cards - Rare Charizard", description: "Holographic first edition",
            url: nil, imageUrl: nil, expectedUnitPrice: 200.00, quantityRequested: 1, priority: 9,
            status: .purchased, offList: false, createdBy: jane, createdAt: day(18), updatedAt: day(1),
            purchases: [
                PurchaseSummary(
                    id: "purchase-5a", quantity: 1, totalCost: 200.00, purchaser: john,
                    shippingStatus: .shipped, purchasedAt: day(2)
                ),
                PurchaseSummary(
                    id: "purchase-5b", quantity: 1, totalCost: 195.00, purchaser: sarah,
                    shippingStatus: .delivered, purchasedAt: day(1)
                )
            ],
            totalQuantityPurchased: 2
        ),
        GiftItem(
            id: "10", listId: "2", name: "Surprise Gift", description: "Something special!",
            url: nil, imageUrl: nil, expectedUnitPrice: 150.00, quantityRequested: 1, priority: 5,
            status: .gifted, offList: true,
            createdBy: ItemPerson(id: "friend-1", displayName: "Best Friend"),
            createdAt: day(10), updatedAt: day(1),
            purchases: [
                PurchaseSummary(
                    id: "purchase-10", quantity: 1, totalCost: 150.00,
                    purchaser: PurchasePerson(id: "friend-1", displayName: "Best Friend"),
                    shippingStatus: .delivered, purchasedAt: day(8)
                )
            ],
            totalQuantityPurchased: 1
        ),
        GiftItem(
            id: "20", listId: "3", name: "Kindle Paperwhite", description: "16GB, with special offers",
            url: "https://www.amazon.com/dp/B08KTZ8249", imageUrl: nil, expectedUnitPrice: 139.99,
            quantityRequested: 1, priority: 7, status: .purchased, offList: false,
            createdBy: dad, createdAt: day(60), updatedAt: day(14),
            purchases: [
                PurchaseSummary(
                    id: "purchase-20", quantity: 1, totalCost: 139.99,
                    purchaser: PurchasePerson(id: "owner-2", displayName: "Dad"),
                    shippingStatus: .notShipped, purchasedAt: day(14)
                )
            ],
            totalQuantityPurchased: 1
        ),
        GiftItem(
            id: "21", listId: "3", name: "Handmade Scarf",
            description: "Custom knitted scarf in mom's favorite colors", url: nil, imageUrl: nil,
            expectedUnitPrice: nil, quantityRequested: 1, priority: 10, status: .available, offList: false,
            createdBy: dad, createdAt: day(45), updatedAt: day(45),
            purchases: nil, totalQuantityPurchased: nil
        )
    ]
}
