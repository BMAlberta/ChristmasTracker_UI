//
//  MockItemRepository.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/14/26.
//

import Foundation

/// Deterministic in-memory item repository for mock mode and previews. It mirrors the server's
/// privacy rules for the capability flags returned for the list a call is about (privacy matrix,
/// client guide 6.2 to 6.4): no gift activity hides status, updatedAt and purchases; no off-list
/// visibility omits off-list items; create derives offList from canAddOffList; edit and delete
/// follow the same rights as `ItemPermissions`.
// Mock repository: intentionally uninstrumented.
actor MockItemRepository: ItemRepository {

    // MARK: - Defaults

    nonisolated static let ownerCapabilities = MockListData.ownerCapabilities
    nonisolated static let defaultUser = ListItemPerson(
        id: MockListData.currentUser.id,
        displayName: MockListData.currentUser.displayName
    )

    // MARK: - State

    private let capabilitiesForList: @Sendable (_ listId: String) -> ListCapabilities
    private let currentUser: ListItemPerson
    private var items: [ListItem]
    private var nextId = 1

    // MARK: - Configuration

    var delay: TimeInterval = 0.5

    // MARK: - Initialization

    init(
        capabilities: @escaping @Sendable (_ listId: String) -> ListCapabilities = { _ in
            MockItemRepository.ownerCapabilities
        },
        currentUser: ListItemPerson = MockItemRepository.defaultUser
    ) {
        self.capabilitiesForList = capabilities
        self.currentUser = currentUser
        self.items = MockItemSeed.items
    }

    // MARK: - ItemRepository

    func fetchItems(listId: String) async throws -> [ListItem] {
        try await Task.sleep(for: .seconds(delay))
        let caps = capabilitiesForList(listId)
        let visible = items
            .filter { $0.listId == listId && (!$0.offList || caps.canSeeOffList) }
            .map { hidden($0, caps, keepingPurchases: false) }
        LogDebug("Mock: Fetched \(visible.count) items", category: .business)
        return visible
    }

    func fetchItemDetail(id: String) async throws -> ListItem {
        try await Task.sleep(for: .seconds(delay))
        guard let item = items.first(where: { $0.id == id }) else { throw ItemError.notFound }
        let caps = capabilitiesForList(item.listId)
        guard !item.offList || caps.canSeeOffList else { throw ItemError.notFound }
        return hidden(item, caps, keepingPurchases: true)
    }

    func createItem(listId: String, _ input: CreateItemInput) async throws -> ListItem {
        try await Task.sleep(for: .seconds(delay))
        let caps = capabilitiesForList(listId)
        guard caps.canCreateItem else { throw ItemError.forbidden }

        let now = Date()
        let created = ListItem(
            id: "mock-item-new-\(nextId)",
            listId: listId,
            name: input.name,
            description: input.description,
            url: input.url,
            imageUrl: input.imageUrl,
            expectedUnitPrice: input.expectedUnitPrice,
            quantityRequested: input.quantityRequested,
            priority: input.priority,
            status: .available,
            offList: caps.canAddOffList,
            createdBy: currentUser,
            createdAt: now,
            updatedAt: now
        )
        nextId += 1
        items.append(created)
        LogDebug("Mock: Created item", category: .business)
        return hidden(created, caps, keepingPurchases: true)
    }

    func updateItem(id: String, _ input: UpdateItemInput) async throws -> ListItem {
        try await Task.sleep(for: .seconds(delay))
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw ItemError.notFound }
        let existing = items[index]
        let caps = capabilitiesForList(existing.listId)
        guard mayChange(existing, caps) else { throw ItemError.forbidden }

        let updated = ListItem(
            id: existing.id,
            listId: existing.listId,
            name: input.name ?? existing.name,
            description: input.description ?? existing.description,
            url: input.url ?? existing.url,
            imageUrl: input.imageUrl ?? existing.imageUrl,
            expectedUnitPrice: input.expectedUnitPrice ?? existing.expectedUnitPrice,
            quantityRequested: input.quantityRequested ?? existing.quantityRequested,
            priority: input.priority ?? existing.priority,
            status: existing.status,
            offList: existing.offList,
            createdBy: existing.createdBy,
            createdAt: existing.createdAt,
            updatedAt: Date(),
            purchases: existing.purchases,
            totalQuantityPurchased: existing.totalQuantityPurchased
        )
        items[index] = updated
        LogDebug("Mock: Updated item", category: .business)
        return hidden(updated, caps, keepingPurchases: true)
    }

    func deleteItem(id: String) async throws {
        try await Task.sleep(for: .seconds(delay))
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw ItemError.notFound }
        guard mayChange(items[index], capabilitiesForList(items[index].listId)) else { throw ItemError.forbidden }
        items.remove(at: index)
        LogDebug("Mock: Deleted item", category: .business)
    }

    // MARK: - Rules

    /// A regular item: canCreateItem and not canAddOffList. An off-list item: its creator only.
    private func mayChange(_ item: ListItem, _ caps: ListCapabilities) -> Bool {
        if item.offList {
            return item.createdBy.id == currentUser.id
        }
        return caps.canCreateItem && !caps.canAddOffList
    }

    /// What the server sends: without gift activity every item is AVAILABLE with no updatedAt and
    /// no purchases. The list endpoint never carries purchase summaries.
    private func hidden(_ item: ListItem, _ caps: ListCapabilities, keepingPurchases: Bool) -> ListItem {
        let seesActivity = caps.canSeeGiftActivity
        let keep = seesActivity && keepingPurchases
        return ListItem(
            id: item.id,
            listId: item.listId,
            name: item.name,
            description: item.description,
            url: item.url,
            imageUrl: item.imageUrl,
            expectedUnitPrice: item.expectedUnitPrice,
            quantityRequested: item.quantityRequested,
            priority: item.priority,
            status: seesActivity ? item.status : .available,
            offList: item.offList,
            createdBy: item.createdBy,
            createdAt: item.createdAt,
            updatedAt: seesActivity ? item.updatedAt : nil,
            purchases: keep ? item.purchases : nil,
            totalQuantityPurchased: keep ? item.totalQuantityPurchased : nil
        )
    }
}

// MARK: - Seed

/// Fake items on the `MockListData` lists. Fake ids and names only; fixed dates.
nonisolated enum MockItemSeed {

    private static let created = Date(timeIntervalSince1970: 1_767_225_600)
    private static let updated = Date(timeIntervalSince1970: 1_767_312_000)

    private static let me = MockItemRepository.defaultUser
    private static let casey = ListItemPerson(id: "mock-user-casey", displayName: "Casey Member")
    private static let pat = ListItemPerson(id: "mock-user-pat", displayName: "Pat Sample")

    private static func money(_ cents: Int) -> Decimal { Decimal(cents) / 100 }

    private static func item(
        _ id: String, _ listId: String, _ name: String, cents: Int?, quantity: Int = 1, priority: Int = 5,
        status: ItemStatus = .available, offList: Bool = false, by creator: ListItemPerson = me,
        purchasedBy buyer: ListItemPerson? = nil, purchased: Int = 0
    ) -> ListItem {
        let purchases = buyer.map { person in
            [ListItemPurchaseSummary(
                id: "\(id)-purchase", quantity: purchased, totalCost: money((cents ?? 0) * purchased),
                purchaser: person, purchasedAt: updated
            )]
        }
        return ListItem(
            id: id, listId: listId, name: name, description: "A fake description for \(name)",
            url: nil, imageUrl: nil, expectedUnitPrice: cents.map(money),
            quantityRequested: quantity, priority: priority, status: status, offList: offList,
            createdBy: creator, createdAt: created, updatedAt: updated,
            purchases: purchases, totalQuantityPurchased: buyer == nil ? nil : purchased
        )
    }

    static let items: [ListItem] = [
        // Owner of a list for a child: full visibility, one member's surprise item.
        item("mock-item-child-1", "mock-list-child", "Toy Rocket", cents: 2499, priority: 9,
             status: .purchased, purchasedBy: casey, purchased: 1),
        item("mock-item-child-2", "mock-list-child", "Picture Book", cents: 1299, quantity: 3, priority: 6,
             status: .partial, purchasedBy: casey, purchased: 1),
        item("mock-item-child-3", "mock-list-child", "Building Blocks", cents: 3999, priority: 8),
        item("mock-item-child-4", "mock-list-child", "Surprise Scooter", cents: 5999, status: .wrapped,
             offList: true, by: casey),
        // Blind owner of a self list: the raw status is hidden from the caller.
        item("mock-item-self-1", "mock-list-self", "Warm Scarf", cents: 2999, priority: 8,
             status: .purchased, purchasedBy: casey, purchased: 1),
        item("mock-item-self-2", "mock-list-self", "Coffee Grinder", cents: 4500, priority: 7),
        item("mock-item-self-3", "mock-list-self", "Hidden Surprise", cents: 1500, status: .gifted,
             offList: true, by: casey),
        // MEMBER of someone else's list: own surprise item and another member's.
        item("mock-item-member-1", "mock-list-member", "Garden Gloves", cents: 1899, priority: 6),
        item("mock-item-member-2", "mock-list-member", "Cookbook", cents: 3200, priority: 7,
             status: .purchased, purchasedBy: pat, purchased: 1),
        item("mock-item-member-3", "mock-list-member", "My Surprise Gift", cents: 4000, offList: true, by: me),
        item("mock-item-member-4", "mock-list-member", "Casey's Surprise Gift", cents: 2500, status: .wrapped,
             offList: true, by: casey),
        // VIEWER, PUBLIC and blind co-owner lists.
        item("mock-item-viewer-1", "mock-list-viewer", "Desk Lamp", cents: 3500, status: .purchased,
             purchasedBy: casey, purchased: 1),
        item("mock-item-viewer-2", "mock-list-viewer", "Notebook Set", cents: 1200),
        item("mock-item-public-1", "mock-list-public", "Board Game", cents: 4400, status: .partial),
        item("mock-item-coowner-1", "mock-list-coowner", "Tea Sampler", cents: 2200, status: .gifted),
        item("mock-item-coowner-2", "mock-list-coowner", "Surprise Candle", cents: 1800, offList: true, by: casey),
        // Archived list: items are still recorded there.
        item("mock-item-archived-1", "mock-list-archived", "Winter Hat", cents: 1900, status: .purchased,
             purchasedBy: casey, purchased: 1),
        item("mock-item-archived-2", "mock-list-archived", "Puzzle", cents: 2700, status: .gifted)
    ]
}
