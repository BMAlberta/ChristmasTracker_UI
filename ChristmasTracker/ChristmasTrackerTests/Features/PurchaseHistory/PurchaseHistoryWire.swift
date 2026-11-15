//
//  PurchaseHistoryWire.swift
//  ChristmasTrackerTests
//
//  PH1-H1: literal, contract-accurate JSON for GET /tracker/v2/purchases (listPurchases): the success
//  envelope `{success, data: [PurchaseHistoryRow], meta}` where `meta` carries the base Meta fields plus
//  filteredCount, filteredTotal and nextCursor (string or null), and a row with item {id, name,
//  imageUrl?}, list {id, name, year}, recipient {id, displayName}, quantity, totalCost, purchasedAt and
//  shippingStatus. Error bodies reuse `ListWire.errorJSON`.
//
//  All ids, names and amounts are fake.
//

import Foundation

nonisolated enum PurchaseHistoryWire {

    static let purchasedAtText = "2026-01-05T08:30:00.000Z"

    /// The Date that `purchasedAtText` (or any fractional-seconds ISO 8601 text) decodes to.
    static func date(_ text: String = purchasedAtText) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? Date(timeIntervalSince1970: 0)
    }

    /// One PurchaseHistoryRow body. `totalCost` is JSON number text so 19.99 reaches the client as a number.
    static func rowJSON(
        id: String = "purchase-1",
        itemId: String = "item-1",
        itemName: String = "Fake Lamp",
        imageUrl: String? = "https://img.example.com/lamp.png",
        listId: String = "list-1",
        listName: String = "Fake List",
        listYear: Int = 2026,
        recipientId: String = "user-r1",
        recipientName: String = "Pat Recipient",
        quantity: Int = 1,
        totalCost: String = "19.99",
        purchasedAt: String = purchasedAtText,
        shippingStatus: String = "NOT_TRACKED"
    ) -> String {
        let image = imageUrl.map { ", \"imageUrl\": \"\($0)\"" } ?? ""
        return """
        { "id": "\(id)", \
        "item": { "id": "\(itemId)", "name": "\(itemName)"\(image) }, \
        "list": { "id": "\(listId)", "name": "\(listName)", "year": \(listYear) }, \
        "recipient": { "id": "\(recipientId)", "displayName": "\(recipientName)" }, \
        "quantity": \(quantity), "totalCost": \(totalCost), \
        "purchasedAt": "\(purchasedAt)", "shippingStatus": "\(shippingStatus)" }
        """
    }

    /// `{success: true, data: [rows], meta}` with the history meta and the cursor (nil writes JSON null).
    static func envelope(_ rows: [String], nextCursor: String?) -> String {
        let cursor = nextCursor.map { "\"\($0)\"" } ?? "null"
        return """
        { "success": true, "data": [\(rows.joined(separator: ","))], \
        "meta": { "timestamp": "2026-11-02T00:00:00.000Z", "requestId": "req-00000001", \
        "sessionId": "sess-00000001", "filteredCount": \(rows.count), "filteredTotal": 0, \
        "nextCursor": \(cursor) } }
        """
    }

    /// The same envelope with the `nextCursor` key left out entirely (the schema marks it optional).
    static func envelopeWithoutCursorKey(_ rows: [String]) -> String {
        """
        { "success": true, "data": [\(rows.joined(separator: ","))], \
        "meta": { "timestamp": "2026-11-02T00:00:00.000Z", "requestId": "req-00000001", \
        "sessionId": "sess-00000001", "filteredCount": \(rows.count), "filteredTotal": 0 } }
        """
    }

    // EDITED (PH1-H1): the trailing newline was a raw control character inside a JSON string (invalid JSON,
    // so the body could not be decoded); it is now the JSON escape \n. The expectation (trimmed) is unchanged.
    static let validationError = ListWire.errorJSON(
        code: 3001, errorCode: "VALIDATION_ERROR", message: "  Year must be between 1000 and 9999\\n"
    )
    static let forbidden = ListWire.errorJSON(
        code: 2005, errorCode: "FORBIDDEN", message: "You do not have permission to do that"
    )
    static let notFound = ListWire.errorJSON(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    static let teapot = ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
}
