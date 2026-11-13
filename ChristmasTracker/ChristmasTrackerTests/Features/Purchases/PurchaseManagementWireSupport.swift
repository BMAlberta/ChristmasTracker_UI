//
//  PurchaseManagementWireSupport.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: shared support for the purchase management repository tests.
//
//  - `ManagementWire`: literal, guide-accurate JSON for getPurchase, updatePurchase,
//    updatePurchaseShipping and deletePurchase (client guide 7.6, 7.7 and 4): the success envelope
//    `{success, data: <Purchase>, meta}` with the full `meta` object and the purchase shape with
//    item {id, name, listId}, and the error envelope with the full `meta`.
//  - `ManagementOp`: the four operations, so one test can run against each of them.
//  - `makePurchaseManagementSUT`: the REAL `TrackerClientFactory.make` client around the recording
//    fake transport (`ListFakeTransport`), wrapped by the repository under test.
//
//  Construction assumption (same as the record repository):
//      GeneratedClientPurchaseManagementRepository(client: client)
//
//  All ids, names, amounts and tracking numbers are fake.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Wire fixtures

nonisolated enum ManagementWire {

    /// The id every operation targets unless a test says otherwise.
    static let purchaseId = "purchase-1"

    /// `{success: true, data: <purchase>, meta}`: the 200 body of all four operations.
    static func purchaseEnvelope(_ purchase: String = PurchaseWire.purchaseJSON()) -> String {
        ListWire.success(data: purchase)
    }

    static let purchaseNotFound = ListWire.errorJSON(
        code: 4005, errorCode: "PURCHASE_NOT_FOUND", message: "Purchase not found"
    )
    static let validationError = ListWire.errorJSON(
        code: 3001, errorCode: "VALIDATION_ERROR", message: "Notes must be at most 1000 characters"
    )
    static let invalidInput = ListWire.errorJSON(
        code: 3001, errorCode: "INVALID_INPUT", message: "Invalid purchase id"
    )
    static let forbidden = ListWire.errorJSON(
        code: 2005, errorCode: "FORBIDDEN", message: "You do not have permission to do that"
    )
    static let accountDisabled = ListWire.errorJSON(
        code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled"
    )
    static let userNotFound = ListWire.errorJSON(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    static let teapot = ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
}

// MARK: - The four operations

nonisolated enum ManagementOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case get, updateNotes, updateShipping, delete

    var testDescription: String {
        switch self {
        case .get: "getPurchase"
        case .updateNotes: "updatePurchase"
        case .updateShipping: "updatePurchaseShipping"
        case .delete: "deletePurchase"
        }
    }

    var method: HTTPRequest.Method {
        switch self {
        case .get: .get
        case .updateNotes, .updateShipping: .patch
        case .delete: .delete
        }
    }

    func path(_ id: String = ManagementWire.purchaseId) -> String {
        switch self {
        case .get, .updateNotes, .delete: "/tracker/v2/purchases/\(id)"
        case .updateShipping: "/tracker/v2/purchases/\(id)/shipping"
        }
    }

    /// True for the operations that carry a request body.
    var hasBody: Bool {
        switch self {
        case .updateNotes, .updateShipping: true
        case .get, .delete: false
        }
    }

    /// Only a GET is retried by the rate limit middleware.
    var isRetriedOn429: Bool { self == .get }

    static let defaultNotes = PurchaseNotesUpdate(change: .set("Gift wrap please"))
    static let defaultShipping = PurchaseShippingUpdate(status: .shipped, trackingNumber: "TRK-FAKE-0001")

    func call(
        _ repo: any PurchaseManaging,
        id: String = ManagementWire.purchaseId
    ) async throws -> RecordedPurchase {
        switch self {
        case .get: try await repo.fetchPurchase(id: id)
        case .updateNotes: try await repo.updateNotes(id: id, update: Self.defaultNotes)
        case .updateShipping: try await repo.updateShipping(id: id, update: Self.defaultShipping)
        case .delete: try await repo.deletePurchase(id: id)
        }
    }
}

// MARK: - SUT factory (real factory-built client, fake transport)

private let managementRepoBaseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()

let managementAccessToken = "tok-access-FAKE"

struct PurchaseManagementSUT {
    let repo: GeneratedClientPurchaseManagementRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher

    func run(_ op: ManagementOp, id: String = ManagementWire.purchaseId) async throws -> RecordedPurchase {
        try await op.call(repo, id: id)
    }

    /// Runs the operation and returns the PurchaseManagementError it threw (nil when it threw
    /// nothing or something else).
    func managementError(_ op: ManagementOp) async -> PurchaseManagementError? {
        do {
            _ = try await run(op)
            return nil
        } catch {
            return error as? PurchaseManagementError
        }
    }

    /// Runs the operation and returns whatever it threw.
    func thrown(_ op: ManagementOp) async -> (any Error)? {
        do {
            _ = try await run(op)
            return nil
        } catch {
            return error
        }
    }

    func lastRequest() async throws -> ListFakeTransport.Recorded {
        guard let request = await transport.lastRequest() else {
            throw ManagementSUTError.noRequest
        }
        return request
    }
}

enum ManagementSUTError: Error {
    case noRequest
}

func makePurchaseManagementSUT(
    token: String? = managementAccessToken,
    refreshFailure: (any Error)? = nil
) throws -> PurchaseManagementSUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: managementRepoBaseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return PurchaseManagementSUT(
        repo: GeneratedClientPurchaseManagementRepository(client: client),
        transport: transport,
        refresher: refresher
    )
}
