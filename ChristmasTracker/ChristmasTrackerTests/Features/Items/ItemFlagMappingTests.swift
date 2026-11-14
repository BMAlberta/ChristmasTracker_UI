//
//  ItemFlagMappingTests.swift
//  ChristmasTrackerTests
//
//  I5b Story C: the server's per-item canEdit and canDelete flags map one to one onto
//  ListItem, for every combination of the two flags, from the list payload
//  (mapListItem(Item)) and from the getItem payload (the flags live in value1 of the allOf;
//  value2 carries only purchases and totalQuantityPurchased). The mapper never derives a flag
//  from offList, createdBy or purchases.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("Item flag mapping Tests")
struct ItemFlagMappingTests {

    nonisolated static let combinations: [(Bool, Bool)] = [(true, true), (true, false), (false, true), (false, false)]

    // MARK: - List payload

    @Test("The list payload maps canEdit and canDelete one to one", arguments: combinations)
    func listPayloadMapsFlags(canEdit: Bool, canDelete: Bool) throws {
        let item = try mapListItem(ItemFixtures.wireItem(canEdit: canEdit, canDelete: canDelete))
        #expect(item.canEdit == canEdit)
        #expect(item.canDelete == canDelete)
    }

    @Test("The flags are independent of offList, creator and status in the list payload", arguments: combinations)
    func listPayloadFlagsIgnoreOtherFields(canEdit: Bool, canDelete: Bool) throws {
        for offList in [false, true] {
            for status in Components.Schemas.ItemStatus.allCases {
                let wire = ItemFixtures.wireItem(
                    status: status, offList: offList, createdBy: ItemFixtures.wirePerson(id: "user-9"),
                    canEdit: canEdit, canDelete: canDelete, updatedAt: ItemFixtures.updatedDate
                )
                let item = try mapListItem(wire)
                #expect(item.canEdit == canEdit, "offList=\(offList) status=\(status.rawValue)")
                #expect(item.canDelete == canDelete, "offList=\(offList) status=\(status.rawValue)")
            }
        }
    }

    // MARK: - getItem payload (flags from value1)

    @Test("The getItem payload reads canEdit and canDelete from value1", arguments: combinations)
    func detailPayloadMapsFlagsFromValue1(canEdit: Bool, canDelete: Bool) throws {
        let detail = ItemFixtures.wireDetail(
            ItemFixtures.wireItem(canEdit: canEdit, canDelete: canDelete),
            purchases: [ItemFixtures.wirePurchase()], totalQuantityPurchased: 1
        )
        let item = try mapListItem(detail)
        #expect(item.canEdit == canEdit)
        #expect(item.canDelete == canDelete)
        #expect(item.purchases?.count == 1, "value2 is still mapped")
    }

    @Test("The getItem flags do not depend on value2 (purchases, totalQuantityPurchased)", arguments: combinations)
    func detailFlagsIgnoreValue2(canEdit: Bool, canDelete: Bool) throws {
        let wire = ItemFixtures.wireItem(canEdit: canEdit, canDelete: canDelete)
        let withoutPurchases = try mapListItem(ItemFixtures.wireDetail(wire))
        let emptyPurchases = try mapListItem(ItemFixtures.wireDetail(wire, purchases: [], totalQuantityPurchased: 0))
        let manyPurchases = try mapListItem(ItemFixtures.wireDetail(
            wire, purchases: [ItemFixtures.wirePurchase(id: "p-1"), ItemFixtures.wirePurchase(id: "p-2")],
            totalQuantityPurchased: 2
        ))
        for item in [withoutPurchases, emptyPurchases, manyPurchases] {
            #expect(item.canEdit == canEdit)
            #expect(item.canDelete == canDelete)
        }
    }

    @Test("The list and the detail mapping of the same flags agree", arguments: combinations)
    func listAndDetailAgree(canEdit: Bool, canDelete: Bool) throws {
        let wire = ItemFixtures.wireItem(canEdit: canEdit, canDelete: canDelete)
        let fromList = try mapListItem(wire)
        let fromDetail = try mapListItem(ItemFixtures.wireDetail(wire))
        #expect(fromList.canEdit == fromDetail.canEdit)
        #expect(fromList.canDelete == fromDetail.canDelete)
    }
}
