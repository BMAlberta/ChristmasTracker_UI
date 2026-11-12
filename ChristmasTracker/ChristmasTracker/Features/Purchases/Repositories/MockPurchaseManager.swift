//
//  MockPurchaseManager.swift
//  ChristmasTracker
//
//  Deterministic in-memory purchase management for mock mode and previews. It behaves like the
//  server: own purchases only (another user's purchase, an unknown id and a missing signed-in user
//  are all not-found, never forbidden), immutability (only notes and shipping change), a notes
//  clear ("") makes the notes nil, an unchanged update is a no-op that answers the current purchase,
//  delete answers the deleted purchase and removes it, and a second delete is not-found.
//
//  Documented limitation: the mock never moves the mock items' counts or statuses.
//
//  Mock store and manager are intentionally uninstrumented (an actor, and a mock).
//

import Foundation

/// The purchases of mock mode, shared by the mock recorder (which appends) and the mock manager.
actor MockPurchaseStore {

    private var purchases: [String: RecordedPurchase] = [:]

    init(seed: [RecordedPurchase] = []) {
        for purchase in seed { purchases[purchase.id] = purchase }
    }

    func add(_ purchase: RecordedPurchase) {
        purchases[purchase.id] = purchase
    }

    /// The purchase, only when `ownerId` is the purchaser (decided by `PurchasePermissions`).
    func purchase(id: String, ownerId: String?) -> RecordedPurchase? {
        guard let purchase = purchases[id],
              PurchasePermissions.canManage(purchasePurchaserId: purchase.purchaser.id, currentUserId: ownerId) else {
            return nil
        }
        return purchase
    }

    /// Replaces the purchase with the transformed one and answers it; nil when it is not the owner's.
    func update(
        id: String,
        ownerId: String?,
        _ transform: @Sendable (RecordedPurchase) -> RecordedPurchase
    ) -> RecordedPurchase? {
        guard let current = purchase(id: id, ownerId: ownerId) else { return nil }
        let changed = transform(current)
        purchases[id] = changed
        return changed
    }

    /// Removes the purchase and answers it; nil when it is not the owner's or already gone.
    func remove(id: String, ownerId: String?) -> RecordedPurchase? {
        guard let current = purchase(id: id, ownerId: ownerId) else { return nil }
        purchases[id] = nil
        return current
    }
}

nonisolated extension MockPurchaseStore {
    /// The purchases the mock item data shows for `user`, so their summary rows can be opened.
    static func seedPurchases(from items: [ListItem], for user: ListItemPerson) -> [RecordedPurchase] {
        items.flatMap { item in
            (item.purchases ?? []).filter { $0.purchaser.id == user.id }.map { summary in
                let recipient: ListItemPerson
                if case .allowed(let person) = MockPurchaseAccess.fromMockSeed(itemId: item.id) {
                    recipient = person
                } else {
                    recipient = ListItemPerson(id: "mock-recipient-\(item.listId)", displayName: "List Recipient")
                }
                return RecordedPurchase(
                    id: summary.id,
                    itemId: item.id,
                    quantity: summary.quantity,
                    totalCost: summary.totalCost,
                    storeName: nil,
                    notes: nil,
                    confirmationNumber: nil,
                    trackingNumber: nil,
                    shippingStatus: .notTracked,
                    shippedAt: nil,
                    deliveredAt: nil,
                    purchaser: summary.purchaser,
                    recipient: recipient,
                    item: PurchaseItemReference(id: item.id, name: item.name, listId: item.listId),
                    purchasedAt: summary.purchasedAt,
                    createdAt: summary.purchasedAt,
                    updatedAt: summary.purchasedAt
                )
            }
        }
    }
}

nonisolated final class MockPurchaseManager: PurchaseManaging, Sendable {

    private let store: MockPurchaseStore
    private let currentUserId: @Sendable () -> String?

    init(store: MockPurchaseStore, currentUserId: @escaping @Sendable () -> String?) {
        self.store = store
        self.currentUserId = currentUserId
    }

    func fetchPurchase(id: String) async throws -> RecordedPurchase {
        guard let purchase = await store.purchase(id: id, ownerId: currentUserId()) else {
            throw PurchaseManagementError.notFound
        }
        return purchase
    }

    func updateNotes(id: String, update: PurchaseNotesUpdate) async throws -> RecordedPurchase {
        let wireNotes = update.wireNotes
        let updated = await store.update(id: id, ownerId: currentUserId()) { current in
            // nil leaves the notes alone; "" clears them to nil.
            guard let wireNotes else { return current }
            return current.replacing(notes: .some(wireNotes.isEmpty ? nil : wireNotes))
        }
        guard let updated else { throw PurchaseManagementError.notFound }
        return updated
    }

    func updateShipping(id: String, update: PurchaseShippingUpdate) async throws -> RecordedPurchase {
        let updated = await store.update(id: id, ownerId: currentUserId()) { current in
            // Decision S3: leaving DELIVERED clears deliveredAt; NOT_SHIPPED and NOT_TRACKED clear
            // both; DELIVERED sets deliveredAt only when there is none. No other timestamp is invented.
            var shippedAt = current.shippedAt
            var deliveredAt = current.deliveredAt
            switch update.status {
            case .notTracked, .notShipped:
                shippedAt = nil
                deliveredAt = nil
            case .shipped:
                deliveredAt = nil
            case .delivered:
                deliveredAt = deliveredAt ?? Date()
            }
            return current.replacing(
                trackingNumber: update.trackingNumber.map { .some($0) },
                shippingStatus: update.status,
                shippedAt: .some(shippedAt),
                deliveredAt: .some(deliveredAt)
            )
        }
        guard let updated else { throw PurchaseManagementError.notFound }
        return updated
    }

    func deletePurchase(id: String) async throws -> RecordedPurchase {
        guard let deleted = await store.remove(id: id, ownerId: currentUserId()) else {
            throw PurchaseManagementError.notFound
        }
        return deleted
    }
}

private nonisolated extension RecordedPurchase {
    /// A copy with the given fields replaced. A nil argument keeps the field; `.some(nil)` sets it to nil.
    func replacing(
        notes: String?? = nil,
        trackingNumber: String?? = nil,
        shippingStatus: PurchaseShippingStatus? = nil,
        shippedAt: Date?? = nil,
        deliveredAt: Date?? = nil
    ) -> RecordedPurchase {
        RecordedPurchase(
            id: id,
            itemId: itemId,
            quantity: quantity,
            totalCost: totalCost,
            storeName: storeName,
            notes: notes ?? self.notes,
            confirmationNumber: confirmationNumber,
            trackingNumber: trackingNumber ?? self.trackingNumber,
            shippingStatus: shippingStatus ?? self.shippingStatus,
            shippedAt: shippedAt ?? self.shippedAt,
            deliveredAt: deliveredAt ?? self.deliveredAt,
            purchaser: purchaser,
            recipient: recipient,
            item: item,
            purchasedAt: purchasedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
