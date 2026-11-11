//
//  ItemWireSupport.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: shared support for the generated item repository tests.
//
//  - `ItemWire`: literal, guide-accurate JSON for the item operations (client guide sections 4,
//    5.4, 6.2 to 6.4 and 7.5) wrapped in the full envelope with the full `meta` object. The
//    envelope helpers (`success`, `errorJSON`, `metaJSON`) are the ones the list tests use
//    (`ListWire`), and the recording fake transport is `ListFakeTransport`.
//  - `ItemRepoOp`: the five operations, for the cross-cutting tests.
//  - `makeItemRepoSUT`: the REAL `TrackerClientFactory.make` client around the fake transport.
//
//  Money is written as literal JSON numbers (never through a Double), so a fixture says exactly
//  what the server says. All ids, names and addresses are fake (example.com).
//
//  Construction assumption (same as the list repository):
//      GeneratedClientItemRepository(client: client)    // client from TrackerClientFactory.make
//
//  Rate-limit note: RateLimitMiddleware retries a 429 on GET (twice) with a REAL sleeper. The 429
//  fixtures use `Retry-After: 0.001`, so the retries cost about a millisecond, and the mapped
//  value is asserted exactly (0.001) so a repository that drops it fails.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Wire fixtures

nonisolated enum ItemWire {

    /// One `Item` as the server sends it. Optional fields are ABSENT (not null) when nil.
    /// `price` is literal JSON number text, e.g. "19.99".
    static func itemJSON(
        id: String = "item-1",
        listId: String = "list-1",
        name: String = "Fake Gift",
        description: String = "A fake description",
        url: String? = nil,
        imageUrl: String? = nil,
        price: String? = nil,
        quantity: Int = 1,
        priority: Int = 5,
        status: String = "AVAILABLE",
        offList: Bool = false,
        createdById: String = "user-2",
        createdByName: String = "Casey Member",
        createdAt: String = "2026-01-05T08:30:00.000Z",
        updatedAt: String? = nil,
        extra: String? = nil
    ) -> String {
        var fields: [String] = [
            "\"id\": \"\(id)\"",
            "\"listId\": \"\(listId)\"",
            "\"name\": \"\(name)\"",
            "\"description\": \"\(description)\"",
            "\"quantityRequested\": \(quantity)",
            "\"priority\": \(priority)",
            "\"status\": \"\(status)\"",
            "\"offList\": \(offList ? "true" : "false")",
            "\"createdBy\": { \"id\": \"\(createdById)\", \"displayName\": \"\(createdByName)\" }",
            "\"createdAt\": \"\(createdAt)\""
        ]
        if let url { fields.append("\"url\": \"\(url)\"") }
        if let imageUrl { fields.append("\"imageUrl\": \"\(imageUrl)\"") }
        if let price { fields.append("\"expectedUnitPrice\": \(price)") }
        if let updatedAt { fields.append("\"updatedAt\": \"\(updatedAt)\"") }
        if let extra { fields.append(extra) }
        return "{ " + fields.joined(separator: ", ") + " }"
    }

    /// A purchase summary inside the getItem response.
    static func purchaseJSON(
        id: String = "purchase-1",
        quantity: Int = 1,
        totalCost: String = "19.99",
        purchaserId: String = "user-3",
        purchaserName: String = "Sam Buyer",
        shippingStatus: String = "NOT_TRACKED",
        purchasedAt: String = "2026-01-07T10:00:00.000Z"
    ) -> String {
        """
        { "id": "\(id)", "quantity": \(quantity), "totalCost": \(totalCost), \
        "purchaser": { "id": "\(purchaserId)", "displayName": "\(purchaserName)" }, \
        "shippingStatus": "\(shippingStatus)", "purchasedAt": "\(purchasedAt)" }
        """
    }

    /// 200 body of GET /lists/{listId}/items.
    static func listJSON(_ items: [String]) -> String {
        ListWire.success(data: "[" + items.joined(separator: ",") + "]")
    }

    /// 200/201 body carrying one `Item` (getItem, createItem, updateItem).
    static func itemEnvelope(_ item: String) -> String {
        ListWire.success(data: item)
    }

    /// 200 body of GET /items/{id}: the item plus `purchases` and `totalQuantityPurchased`.
    static func detailEnvelope(item: String, purchases: [String]? = nil, totalQuantityPurchased: Int? = nil) -> String {
        var extra: [String] = []
        if let purchases { extra.append("\"purchases\": [" + purchases.joined(separator: ",") + "]") }
        if let totalQuantityPurchased { extra.append("\"totalQuantityPurchased\": \(totalQuantityPurchased)") }
        var merged = item
        if !extra.isEmpty, let closing = merged.lastIndex(of: "}") {
            merged.replaceSubrange(closing..<merged.endIndex, with: ", " + extra.joined(separator: ", ") + " }")
        }
        return ListWire.success(data: merged)
    }

    /// 200 body of DELETE /items/{id}: only a message.
    static func deletedJSON() -> String {
        ListWire.success(data: "{ \"message\": \"Item deleted\" }")
    }

    // MARK: Documented error bodies (Docs/error-codes.md)

    static let invalidPrice = ListWire.errorJSON(
        code: 3007, errorCode: "INVALID_PRICE", message: "Invalid price",
        details: "{ \"field\": \"expectedUnitPrice\" }"
    )
    static let validationError = ListWire.errorJSON(
        code: 3001, errorCode: "VALIDATION_ERROR", message: "Name must be between 1 and 200 characters"
    )
    static let blankMessageValidation = ListWire.errorJSON(code: 3001, errorCode: "VALIDATION_ERROR", message: "   ")
    static let itemNotFound = ListWire.errorJSON(code: 4004, errorCode: "ITEM_NOT_FOUND", message: "Item not found")
    static let userNotFound = ListWire.errorJSON(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    static let accountDisabled = ListWire.errorJSON(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled")
    static let forbidden = ListWire.errorJSON(code: 2005, errorCode: "FORBIDDEN", message: "You do not have permission to do that")
    static let cannotDeleteWithPurchases = ListWire.errorJSON(
        code: 6201, errorCode: "CANNOT_DELETE_ITEM_WITH_PURCHASES", message: "Cannot delete item with existing purchases"
    )
    /// A 422 that is NOT the documented purchases conflict.
    static let otherUnprocessable = ListWire.errorJSON(
        code: 6999, errorCode: "SOMETHING_ELSE", message: "Cannot process this request"
    )
}

// MARK: - SUT factory (real factory-built client, fake transport)

private let itemRepoBaseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()

let itemRepoAccessToken = "tok-access-FAKE"

struct ItemRepoSUT {
    let repo: GeneratedClientItemRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher
}

func makeItemRepoSUT(token: String? = itemRepoAccessToken, refreshFailure: (any Error)? = nil) throws -> ItemRepoSUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: itemRepoBaseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return ItemRepoSUT(repo: GeneratedClientItemRepository(client: client), transport: transport, refresher: refresher)
}

nonisolated func sampleCreateItemInput(
    price: Decimal? = nil,
    url: String? = nil,
    imageUrl: String? = nil
) -> CreateItemInput {
    CreateItemInput(
        name: "Fake Lamp", description: "A fake lamp", url: url, imageUrl: imageUrl,
        expectedUnitPrice: price, quantityRequested: 2, priority: 7
    )
}

// MARK: - The five operations, for cross-cutting tests

nonisolated enum ItemRepoOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case fetchItems, fetchItemDetail, createItem, updateItem, deleteItem

    var testDescription: String {
        switch self {
        case .fetchItems: "fetchItems"
        case .fetchItemDetail: "fetchItemDetail"
        case .createItem: "createItem"
        case .updateItem: "updateItem"
        case .deleteItem: "deleteItem"
        }
    }

    var successStatus: Int { self == .createItem ? 201 : 200 }

    var method: HTTPRequest.Method {
        switch self {
        case .fetchItems, .fetchItemDetail: .get
        case .createItem: .post
        case .updateItem: .patch
        case .deleteItem: .delete
        }
    }

    var path: String {
        switch self {
        case .fetchItems, .createItem: "/tracker/v2/lists/list-1/items"
        case .fetchItemDetail, .updateItem, .deleteItem: "/tracker/v2/items/item-1"
        }
    }

    /// Operations that take a request body (the ones that can answer 400).
    var hasBody: Bool { self == .createItem || self == .updateItem }

    func successJSON() -> String {
        switch self {
        case .fetchItems: ItemWire.listJSON([ItemWire.itemJSON()])
        case .fetchItemDetail: ItemWire.detailEnvelope(item: ItemWire.itemJSON())
        case .createItem, .updateItem: ItemWire.itemEnvelope(ItemWire.itemJSON())
        case .deleteItem: ItemWire.deletedJSON()
        }
    }

    func run(_ repo: GeneratedClientItemRepository) async throws {
        switch self {
        case .fetchItems:
            _ = try await repo.fetchItems(listId: "list-1")
        case .fetchItemDetail:
            _ = try await repo.fetchItemDetail(id: "item-1")
        case .createItem:
            _ = try await repo.createItem(listId: "list-1", sampleCreateItemInput())
        case .updateItem:
            _ = try await repo.updateItem(id: "item-1", UpdateItemInput(name: "New Name"))
        case .deleteItem:
            try await repo.deleteItem(id: "item-1")
        }
    }
}

nonisolated enum ItemMalformedBody: CaseIterable, Sendable, CustomTestStringConvertible {
    case notJSON, missingData, emptyData

    var testDescription: String {
        switch self {
        case .notJSON: "not JSON"
        case .missingData: "data missing"
        case .emptyData: "data is an empty object"
        }
    }

    var json: String {
        switch self {
        case .notJSON: "{ this is not json"
        case .missingData: "{ \"success\": true, \"meta\": \(ListWire.metaJSON) }"
        case .emptyData: "{ \"success\": true, \"data\": {}, \"meta\": \(ListWire.metaJSON) }"
        }
    }
}
