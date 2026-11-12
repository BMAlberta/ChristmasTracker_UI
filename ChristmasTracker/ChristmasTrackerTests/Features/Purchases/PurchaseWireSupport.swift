//
//  PurchaseWireSupport.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: shared support for the generated purchase repository tests.
//
//  - `PurchaseWire`: literal, guide-accurate JSON for createPurchase (client guide 7.6) wrapped in
//    the full envelope with the full `meta` object. The envelope helpers (`success`, `errorJSON`,
//    `metaJSON`) are the ones the list and item tests use (`ListWire`), and the recording fake
//    transport is `ListFakeTransport`.
//  - `makePurchaseRepoSUT`: the REAL `TrackerClientFactory.make` client around the fake transport.
//
//  Money is written as literal JSON numbers (never through a Double), so a fixture says exactly
//  what the server says. The 200 body carries `purchase: null`, as the guide shows. All ids,
//  names and amounts are fake; the confirmation token is the distinctive fake below.
//
//  Construction assumption (same as the item repository):
//      GeneratedClientPurchaseRepository(client: client)    // client from TrackerClientFactory.make
//
//  Rate-limit note: a POST is not retried by the middleware, so one queued 429 is enough. The 429
//  fixtures use `Retry-After: 0.001` and the mapped value is asserted exactly.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Wire fixtures

nonisolated enum PurchaseWire {

    /// A distinctive fake confirmation token (never a real one).
    static let token = "tok-fixture-ABC123"
    static let secondToken = "tok-fixture-XYZ789"

    /// ISO 8601 with fractional seconds, as the server sends dates.
    static func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? .distantPast
    }

    private static func quoted(_ value: String?) -> String {
        guard let value else { return "null" }
        return "\"\(value)\""
    }

    /// One `Purchase` as the server sends it: the nullable fields are explicit JSON null.
    /// `totalCost` is literal JSON number text, e.g. "79.99".
    static func purchaseJSON(
        id: String = "purchase-1",
        itemId: String = "item-1",
        quantity: Int = 1,
        totalCost: String = "79.99",
        storeName: String? = nil,
        notes: String? = nil,
        confirmationNumber: String? = nil,
        trackingNumber: String? = nil,
        shippingStatus: String = "NOT_TRACKED",
        shippedAt: String? = nil,
        deliveredAt: String? = nil,
        purchasedAt: String = "2026-01-05T08:30:00.000Z"
    ) -> String {
        """
        { "id": "\(id)", "itemId": "\(itemId)", "quantity": \(quantity), "totalCost": \(totalCost), \
        "storeName": \(quoted(storeName)), "notes": \(quoted(notes)), \
        "confirmationNumber": \(quoted(confirmationNumber)), "trackingNumber": \(quoted(trackingNumber)), \
        "shippingStatus": "\(shippingStatus)", "shippedAt": \(quoted(shippedAt)), \
        "deliveredAt": \(quoted(deliveredAt)), \
        "purchaser": { "id": "user-3", "displayName": "Sam Buyer" }, \
        "recipient": { "id": "user-1", "displayName": "Pat Recipient" }, \
        "item": { "id": "\(itemId)", "name": "Fake Lamp", "listId": "list-1" }, \
        "purchasedAt": "\(purchasedAt)", "createdAt": "2026-01-05T08:30:01.000Z", \
        "updatedAt": "2026-01-05T08:30:02.000Z" }
        """
    }

    /// One `BudgetOverageWarning`. Level "recipient" carries recipientId and recipientName; level
    /// "total" carries the year instead. Money is literal JSON number text.
    static func warningJSON(
        level: String = "recipient",
        recipientName: String = "Tommy",
        token: String = PurchaseWire.token,
        limit: String = "500",
        spent: String = "450",
        amount: String = "349.99",
        overage: String = "299.99"
    ) -> String {
        let scope = level == "recipient"
            ? "\"recipientId\": \"user-1\", \"recipientName\": \"\(recipientName)\", "
            : "\"year\": 2026, "
        return """
        { "code": 6002, "warningCode": "BUDGET_OVERAGE_WARNING", "level": "\(level)", \
        "message": "This purchase would put you over budget", "severity": "warning", \
        "requiresConfirmation": true, "confirmationToken": "\(token)", \
        "details": { \(scope)"budgetLimit": \(limit), "currentSpent": \(spent), \
        "purchaseAmount": \(amount), "overage": \(overage) } }
        """
    }

    /// Body of the 201 (and of a 200 that carries `created`): the purchase exists.
    static func createdEnvelope(purchase: String = PurchaseWire.purchaseJSON()) -> String {
        ListWire.success(
            data: "{ \"status\": \"created\", \"purchase\": \(purchase), \"requiresConfirmation\": false }"
        )
    }

    /// Body of the 200 confirmation_required: `purchase` is null and `warnings` is top level.
    static func confirmationEnvelope(warnings: [String]) -> String {
        """
        {
          "success": true,
          "data": { "status": "confirmation_required", "purchase": null, "requiresConfirmation": true },
          "warnings": [\(warnings.joined(separator: ","))],
          "meta": \(ListWire.metaJSON)
        }
        """
    }

    /// The same data member inside a 201 (a confirmation_required that must never arrive on a 201).
    static func confirmationInCreatedEnvelope(warnings: [String]) -> String {
        confirmationEnvelope(warnings: warnings)
    }

    // MARK: Documented error bodies (Docs/error-codes.md)

    static let invalidPrice = ListWire.errorJSON(
        code: 3007, errorCode: "INVALID_PRICE", message: "Invalid price",
        details: "{ \"field\": \"totalCost\" }"
    )
    /// Code 3007 under another errorCode: the code alone decides.
    static let invalidPriceByCodeOnly = ListWire.errorJSON(code: 3007, errorCode: "SOMETHING_ELSE", message: "Bad price")
    /// errorCode INVALID_PRICE under another code: the errorCode alone decides.
    static let invalidPriceByErrorCodeOnly = ListWire.errorJSON(code: 3999, errorCode: "INVALID_PRICE", message: "Bad price")
    static let validationError = ListWire.errorJSON(
        code: 3001, errorCode: "VALIDATION_ERROR", message: "Store name must be at most 200 characters"
    )
    static let blankMessageValidation = ListWire.errorJSON(code: 3001, errorCode: "VALIDATION_ERROR", message: "   ")
    static let cannotPurchaseOwnList = ListWire.errorJSON(
        code: 6104, errorCode: "CANNOT_PURCHASE_OWN_LIST", message: "You cannot purchase items from your own list"
    )
    /// Code 6104 under another errorCode.
    static let ownListByCodeOnly = ListWire.errorJSON(code: 6104, errorCode: "SOMETHING_ELSE", message: "Not allowed")
    /// errorCode CANNOT_PURCHASE_OWN_LIST under another code.
    static let ownListByErrorCodeOnly = ListWire.errorJSON(
        code: 6999, errorCode: "CANNOT_PURCHASE_OWN_LIST", message: "Not allowed"
    )
    static let forbidden = ListWire.errorJSON(code: 2005, errorCode: "FORBIDDEN", message: "You do not have permission to do that")
    static let accountDisabled = ListWire.errorJSON(code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled")
    static let itemNotFound = ListWire.errorJSON(code: 4004, errorCode: "ITEM_NOT_FOUND", message: "Item not found")
    static let userNotFound = ListWire.errorJSON(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    /// A 422: the spec documents none for createPurchase.
    static let unprocessable = ListWire.errorJSON(code: 6999, errorCode: "SOMETHING_ELSE", message: "Cannot process this request")
}

// MARK: - SUT factory (real factory-built client, fake transport)

private let purchaseRepoBaseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()

let purchaseRepoAccessToken = "tok-access-FAKE"

struct PurchaseRepoSUT {
    let repo: GeneratedClientPurchaseRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher

    /// One createPurchase call with sensible defaults.
    func create(
        itemId: String = "item-1",
        draft: PurchaseDraft = PurchaseFixtures.draft(),
        token: String? = nil
    ) async throws -> PurchaseOutcome {
        try await repo.createPurchase(itemId: itemId, draft: draft, confirmationToken: token)
    }
}

func makePurchaseRepoSUT(token: String? = purchaseRepoAccessToken, refreshFailure: (any Error)? = nil) throws -> PurchaseRepoSUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: purchaseRepoBaseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return PurchaseRepoSUT(repo: GeneratedClientPurchaseRepository(client: client), transport: transport, refresher: refresher)
}
