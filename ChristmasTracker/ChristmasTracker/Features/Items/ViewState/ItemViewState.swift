//
//  ItemViewState.swift
//  ChristmasTracker
//
//  Pure display state for the item screens. Views read these values and nothing else: every
//  visibility decision comes from the capability flags (through ItemPermissions). When
//  canSeeGiftActivity is false every item is a plain available entry: no status marker, no
//  completion, no purchases, no progress, no updatedAt, and the copy hints at nothing hidden.
//

import Foundation

// MARK: - Formatting helpers

private nonisolated func itemPriceText(_ price: Decimal, currencyCode: String, locale: Locale) -> String {
    price.formatted(Decimal.FormatStyle.Currency(code: currencyCode, locale: locale))
}

private nonisolated func itemQuantityText(_ quantity: Int) -> String { "Qty \(quantity)" }

private nonisolated func itemPriorityText(_ priority: Int) -> String { "Priority \(priority)" }

// MARK: - Context

/// The list-level flags the item screens need, taken from the open list. The screens hand this
/// value on; they never look inside it for a role.
nonisolated struct ItemListContext: Equatable, Sendable {
    let capabilities: ListCapabilities

    init(capabilities: ListCapabilities) {
        self.capabilities = capabilities
    }

    init(detail: ListDetail) {
        self.capabilities = detail.capabilities
    }
}

// MARK: - Row

nonisolated struct ItemRowState: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let priceText: String?
    let quantityText: String
    let priorityText: String
    let statusMarker: ItemStatus?
    let showsOffListBadge: Bool
    let isCompleted: Bool

    init(
        id: String,
        name: String,
        priceText: String?,
        quantityText: String,
        priorityText: String,
        statusMarker: ItemStatus?,
        showsOffListBadge: Bool,
        isCompleted: Bool
    ) {
        self.id = id
        self.name = name
        self.priceText = priceText
        self.quantityText = quantityText
        self.priorityText = priorityText
        self.statusMarker = statusMarker
        self.showsOffListBadge = showsOffListBadge
        self.isCompleted = isCompleted
    }

    fileprivate init(
        item: ListItem,
        permissions: ItemPermissions,
        currencyCode: String,
        locale: Locale
    ) {
        let showsActivity = permissions.canSeeGiftActivity
        let completed: Bool
        switch item.status {
        case .purchased, .wrapped, .gifted: completed = showsActivity
        case .available, .partial: completed = false
        }
        self.init(
            id: item.id,
            name: item.name,
            priceText: item.expectedUnitPrice.map { itemPriceText($0, currencyCode: currencyCode, locale: locale) },
            quantityText: itemQuantityText(item.quantityRequested),
            priorityText: itemPriorityText(item.priority),
            statusMarker: showsActivity ? item.status : nil,
            showsOffListBadge: item.offList && permissions.canSeeOffListItems,
            isCompleted: completed
        )
    }
}

// MARK: - List

nonisolated enum ItemSectionKind: Equatable, Sendable {
    case all
    case available
    case purchased
    case offList
}

nonisolated struct ItemSectionState: Equatable, Sendable {
    let kind: ItemSectionKind
    let title: String
    let rows: [ItemRowState]
}

nonisolated struct ItemListState: Equatable, Sendable {
    let sections: [ItemSectionState]
    let showsAddButton: Bool
    let emptyTitle: String
    let emptyMessage: String

    var isEmpty: Bool { sections.isEmpty }

    init(items: [ListItem], context: ItemListContext, currentUserId: String?) {
        self.init(items: items, capabilities: context.capabilities, currentUserId: currentUserId)
    }

    init(
        items: [ListItem],
        capabilities: ListCapabilities,
        currentUserId: String?,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US")
    ) {
        let permissions = ItemPermissions(capabilities: capabilities, currentUserId: currentUserId)
        let visible = permissions.visibleItems(items)
        func row(_ item: ListItem) -> ItemRowState {
            ItemRowState(item: item, permissions: permissions, currencyCode: currencyCode, locale: locale)
        }

        var built: [ItemSectionState] = []
        if permissions.canSeeGiftActivity {
            let regular = visible.filter { !$0.offList }
            let available = regular.filter { $0.status == .available || $0.status == .partial }
            let purchased = regular.filter { $0.status == .purchased || $0.status == .wrapped || $0.status == .gifted }
            let offList = visible.filter(\.offList)
            built.append(ItemSectionState(kind: .available, title: "Available", rows: available.map(row)))
            built.append(ItemSectionState(kind: .purchased, title: "Purchased", rows: purchased.map(row)))
            built.append(ItemSectionState(kind: .offList, title: "Off-List", rows: offList.map(row)))
        } else {
            built.append(ItemSectionState(kind: .all, title: "Items", rows: visible.map(row)))
        }
        sections = built.filter { !$0.rows.isEmpty }

        showsAddButton = permissions.canAddItem
        emptyTitle = "No items yet"
        let base = "Items added to this list will appear here."
        emptyMessage = permissions.canAddItem ? base + " Tap Add Item to add the first one." : base
    }
}

// MARK: - Detail

nonisolated struct PurchaseRowState: Equatable, Identifiable, Sendable {
    let id: String
    let quantity: Int
    let totalCostText: String
    let purchaserName: String
}

nonisolated struct ItemDetailState: Equatable, Sendable {
    let title: String
    let descriptionText: String?
    let priceText: String?
    let quantityText: String
    let priorityText: String
    let showsOffListBadge: Bool
    let statusMarker: ItemStatus?
    let progress: Double?
    let remainingQuantity: Int?
    let purchases: [PurchaseRowState]
    let updatedText: String?
    let showsEdit: Bool
    let showsDelete: Bool
    let showsPurchaseEntry: Bool
    /// The product link, only for an absolute http or https URL.
    let linkURL: URL?

    init(item: ListItem, context: ItemListContext, currentUserId: String?, now: Date) {
        self.init(item: item, capabilities: context.capabilities, currentUserId: currentUserId, now: now)
    }

    init(
        item: ListItem,
        capabilities: ListCapabilities,
        currentUserId: String?,
        currencyCode: String = "USD",
        locale: Locale = Locale(identifier: "en_US"),
        now: Date
    ) {
        let permissions = ItemPermissions(capabilities: capabilities, currentUserId: currentUserId)
        let showsActivity = permissions.canSeeGiftActivity

        title = item.name
        let trimmed = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
        descriptionText = trimmed.isEmpty ? nil : item.description
        priceText = item.expectedUnitPrice.map { itemPriceText($0, currencyCode: currencyCode, locale: locale) }
        quantityText = itemQuantityText(item.quantityRequested)
        priorityText = itemPriorityText(item.priority)
        showsOffListBadge = item.offList && permissions.canSeeOffListItems

        statusMarker = showsActivity ? item.status : nil
        let purchased = showsActivity ? item.totalQuantityPurchased : nil
        if let purchased, item.quantityRequested > 0 {
            progress = min(max(Double(purchased) / Double(item.quantityRequested), 0), 1)
        } else {
            progress = nil
        }
        // Never negative: an over-purchase leaves nothing remaining.
        remainingQuantity = purchased.map { max(0, item.quantityRequested - $0) }
        purchases = showsActivity
            ? (item.purchases ?? []).map { purchase in
                PurchaseRowState(
                    id: purchase.id,
                    quantity: purchase.quantity,
                    totalCostText: itemPriceText(purchase.totalCost, currencyCode: currencyCode, locale: locale),
                    purchaserName: purchase.purchaser.displayName
                )
            }
            : []
        if showsActivity, let updatedAt = item.updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = locale
            formatter.unitsStyle = .full
            updatedText = "Updated " + formatter.localizedString(for: updatedAt, relativeTo: now)
        } else {
            updatedText = nil
        }

        showsEdit = permissions.canEdit(item)
        showsDelete = permissions.canDelete(item)
        showsPurchaseEntry = permissions.canPurchase
        linkURL = item.url.flatMap(URL.init(string:)).flatMap { link in
            let scheme = link.scheme?.lowercased()
            return (scheme == "http" || scheme == "https") && link.host() != nil ? link : nil
        }
    }
}
