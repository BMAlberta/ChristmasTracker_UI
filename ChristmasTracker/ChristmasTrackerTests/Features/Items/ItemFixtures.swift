//
//  ItemFixtures.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: shared, fake-data fixtures for the item domain tests.
//
//  Domain side: the ONLY call site of the memberwise initialiser of `ListItem` in the test
//  target lives in `item(...)`, so a change of argument order is a one-file fix.
//  Wire side: generated `Components.Schemas.Item` values built with the generated memberwise
//  initialisers (no JSON needed; dates are plain `Date` values).
//
//  Personas: the capability flags a viewer of each kind receives, taken from the
//  `ListFixtures` scenarios (which follow Docs/privacy-matrix.md). Item rights are NEVER
//  derived from a role in the tests either: a persona is only a named bundle of flags.
//
//  All ids, names and addresses are fake (example.com).
//

import Foundation
import TrackerAPI
@testable import ChristmasTracker

nonisolated enum ItemFixtures {

    // MARK: - Constants

    static let currentUserId = "user-1"
    static let otherUserId = "user-2"
    static let thirdUserId = "user-3"
    static let createdDate = Date(timeIntervalSince1970: 1_767_600_000)
    static let updatedDate = Date(timeIntervalSince1970: 1_767_686_400)
    static let purchasedDate = Date(timeIntervalSince1970: 1_767_650_000)
    static let nowDate = Date(timeIntervalSince1970: 1_767_700_000)

    static func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? Decimal.nan
    }

    // MARK: - Domain construction (the only memberwise call site of ListItem)

    static func person(id: String = otherUserId, displayName: String = "Casey Member") -> ListItemPerson {
        ListItemPerson(id: id, displayName: displayName)
    }

    static func item(
        id: String = "item-1",
        listId: String = "list-1",
        name: String = "Fake Gift",
        description: String = "A fake description",
        url: String? = nil,
        imageUrl: String? = nil,
        price: Decimal? = nil,
        quantity: Int = 1,
        priority: Int = 5,
        status: ItemStatus = .available,
        offList: Bool = false,
        createdBy: ListItemPerson = person(),
        createdAt: Date = createdDate,
        updatedAt: Date? = nil,
        purchases: [ListItemPurchaseSummary]? = nil,
        totalQuantityPurchased: Int? = nil
    ) -> ListItem {
        ListItem(
            id: id,
            listId: listId,
            name: name,
            description: description,
            url: url,
            imageUrl: imageUrl,
            expectedUnitPrice: price,
            quantityRequested: quantity,
            priority: priority,
            status: status,
            offList: offList,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt,
            purchases: purchases,
            totalQuantityPurchased: totalQuantityPurchased
        )
    }

    static func purchase(
        id: String = "purchase-1",
        quantity: Int = 1,
        totalCost: Decimal = decimal("19.99"),
        purchaser: ListItemPerson = person(id: thirdUserId, displayName: "Sam Buyer"),
        purchasedAt: Date = purchasedDate
    ) -> ListItemPurchaseSummary {
        ListItemPurchaseSummary(
            id: id,
            quantity: quantity,
            totalCost: totalCost,
            purchaser: purchaser,
            purchasedAt: purchasedAt
        )
    }

    // MARK: - Wire construction

    static func wirePerson(id: String = otherUserId, displayName: String = "Casey Member") -> Components.Schemas.PersonRef {
        Components.Schemas.PersonRef(id: id, displayName: displayName)
    }

    static func wireItem(
        id: String = "item-1",
        listId: String = "list-1",
        name: String = "Fake Gift",
        description: String = "A fake description",
        url: String? = nil,
        imageUrl: String? = nil,
        price: Double? = nil,
        quantity: Int = 1,
        priority: Int = 5,
        status: Components.Schemas.ItemStatus = .available,
        offList: Bool = false,
        createdBy: Components.Schemas.PersonRef = wirePerson(),
        createdAt: Date = createdDate,
        updatedAt: Date? = nil
    ) -> Components.Schemas.Item {
        Components.Schemas.Item(
            id: id,
            listId: listId,
            name: name,
            description: description,
            url: url,
            imageUrl: imageUrl,
            expectedUnitPrice: price,
            quantityRequested: quantity,
            priority: priority,
            status: status,
            offList: offList,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func wirePurchase(
        id: String = "purchase-1",
        quantity: Int = 1,
        totalCost: Double = 19.99,
        purchaser: Components.Schemas.PersonRef = wirePerson(id: thirdUserId, displayName: "Sam Buyer"),
        purchasedAt: Date = purchasedDate
    ) -> Components.Schemas.PurchaseSummary {
        Components.Schemas.PurchaseSummary(
            id: id,
            quantity: quantity,
            totalCost: totalCost,
            purchaser: purchaser,
            shippingStatus: .notTracked,
            purchasedAt: purchasedAt
        )
    }

    static func wireDetail(
        _ item: Components.Schemas.Item,
        purchases: [Components.Schemas.PurchaseSummary]? = nil,
        totalQuantityPurchased: Int? = nil
    ) -> Operations.GetItem.Output.Ok.Body.JsonPayload.DataPayload {
        Operations.GetItem.Output.Ok.Body.JsonPayload.DataPayload(
            value1: item,
            value2: .init(purchases: purchases, totalQuantityPurchased: totalQuantityPurchased)
        )
    }

    // MARK: - Personas (named bundles of flags)

    enum Persona: String, CaseIterable, Sendable {
        case owner
        case blindOwner
        case coOwner
        case blindCoOwner
        case member
        case viewer
        case publicNonMember

        /// The flags the server sends for this viewer on an ACTIVE list.
        var flags: ListFixtures.Flags {
            switch self {
            case .owner:
                return ListFixtures.ownerOfChildList().flags
            case .blindOwner:
                return ListFixtures.blindOwnerOfSelfList().flags
            case .coOwner:
                var flags = ListFixtures.ownerOfChildList().flags
                flags.canSetCoOwner = false
                return flags
            case .blindCoOwner:
                return ListFixtures.blindCoOwner().flags
            case .member:
                return ListFixtures.memberRoleMember().flags
            case .viewer:
                return ListFixtures.viewerRoleMember().flags
            case .publicNonMember:
                return ListFixtures.publicNonMember().flags
            }
        }

        /// The same viewer on an ARCHIVED list: the four list-management flags are false, the item
        /// flags are unchanged (the flags do not depend on the list status).
        var archivedFlags: ListFixtures.Flags {
            var flags = self.flags
            flags.canEditList = false
            flags.canDeleteList = false
            flags.canManageMembers = false
            flags.canSetCoOwner = false
            return flags
        }

        var capabilities: ListCapabilities { ListFixtures.capabilities(flags) }
        var archivedCapabilities: ListCapabilities { ListFixtures.capabilities(archivedFlags) }
    }

    /// Capabilities with only the item-relevant flags set, everything else false.
    static func capabilities(
        canCreateItem: Bool = false,
        canAddOffList: Bool = false,
        canSeeGiftActivity: Bool = false,
        canSeeOffList: Bool = false,
        canPurchase: Bool = false
    ) -> ListCapabilities {
        var flags = ListFixtures.Flags()
        flags.canCreateItem = canCreateItem
        flags.canAddOffList = canAddOffList
        flags.canSeeGiftActivity = canSeeGiftActivity
        flags.canSeeOffList = canSeeOffList
        flags.canPurchase = canPurchase
        return ListFixtures.capabilities(flags)
    }
}
