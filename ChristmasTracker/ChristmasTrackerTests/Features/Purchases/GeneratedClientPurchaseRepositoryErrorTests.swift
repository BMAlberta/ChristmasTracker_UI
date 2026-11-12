//
//  GeneratedClientPurchaseRepositoryErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: every documented failure of createPurchase, and the fallbacks, mapped to the exact
//  typed RecordPurchaseError through the REAL factory-built client with a fake transport.
//
//  Mapping under test (Gate 1, every case explicit, no blanket default):
//    200 with a wrong shape                  -> .invalidResponse
//    201 whose body cannot be read or mapped -> .unconfirmed (I4b: the purchase exists on the server)
//    400 errorCode INVALID_PRICE or 3007     -> .invalidPrice
//    400 other                               -> .validation(message: server message, blank when absent)
//    400 undecodable envelope                -> .validation(message: "")
//    401 (after the one refresh)             -> .unauthorized
//    403 errorCode CANNOT_PURCHASE_OWN_LIST or 6104 -> .cannotPurchaseOwnList
//    403 other (incl. ACCOUNT_DISABLED)      -> .forbidden
//    404 (incl. USER_NOT_FOUND)              -> .notFound
//    422 (the spec documents none)           -> .invalidResponse
//    429 / thrown rateLimited                -> .rateLimited(retryAfter:)
//    500, undocumented 5xx                   -> .server
//    other undocumented, decoding            -> .invalidResponse
//    transport failure                       -> .network when definitive, .unconfirmed otherwise
//                                               (the full table is in GeneratedClientPurchaseUnconfirmedTests)
//    CancellationError                      -> rethrown
//    .sessionEnded is never produced by the repository.
//
//  The 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND session-ending cases are handled by the
//  middleware seam; here only the status mapping is pinned.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseRepository errors", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseRepositoryErrorTests {

    // MARK: 400

    @Test("400 INVALID_PRICE (3007) throws invalidPrice")
    func invalidPrice() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 400, json: PurchaseWire.invalidPrice)

        await #expect(throws: RecordPurchaseError.invalidPrice) {
            _ = try await sut.create()
        }
    }

    @Test("400 is invalidPrice when either the errorCode or the numeric code says so",
          arguments: [PurchaseWire.invalidPriceByCodeOnly, PurchaseWire.invalidPriceByErrorCodeOnly])
    func invalidPriceByEitherField(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 400, json: body)

        await #expect(throws: RecordPurchaseError.invalidPrice) {
            _ = try await sut.create()
        }
    }

    @Test("400 with another code passes the server's message through as validation")
    func otherBadRequest() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 400, json: PurchaseWire.validationError)

        await #expect(throws: RecordPurchaseError.validation(message: "Store name must be at most 200 characters")) {
            _ = try await sut.create()
        }
    }

    @Test("400 with a blank message throws validation carrying the message as sent")
    func blankValidationMessage() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 400, json: PurchaseWire.blankMessageValidation)

        let thrown = await captureError { _ = try await sut.create() }

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage.isEmpty == false, "a blank server message still yields a readable user message")
    }

    @Test("400 with no message at all throws validation with a blank message")
    func absentValidationMessage() async throws {
        let sut = try makePurchaseRepoSUT()
        let body = """
        { "success": false, "error": { "code": 3001, "errorCode": "VALIDATION_ERROR" }, "meta": \(ListWire.metaJSON) }
        """
        await sut.transport.enqueue(status: 400, json: body)

        let thrown = await captureError { _ = try await sut.create() }

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage.isEmpty == false)
    }

    @Test("400 whose envelope cannot be decoded throws validation with an empty message")
    func undecodableBadRequest() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 400, json: "{ this is not json")

        await #expect(throws: RecordPurchaseError.validation(message: "")) {
            _ = try await sut.create()
        }
    }

    // MARK: 401

    @Test("401 then a second 401 after one refresh throws unauthorized")
    func unauthorizedAfterRefreshAttempt() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        await #expect(throws: RecordPurchaseError.unauthorized) {
            _ = try await sut.create()
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized and does not replay")
    func unauthorizedWhenRefreshCredentialFails() async throws {
        let sut = try makePurchaseRepoSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        await #expect(throws: RecordPurchaseError.unauthorized) {
            _ = try await sut.create()
        }
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed result, with the same body and token")
    func refreshThenReplaySucceeds() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope())

        let outcome = try await sut.create(token: PurchaseWire.token)

        guard case .created = outcome else {
            Issue.record("expected .created after the replay, got \(outcome)")
            return
        }
        #expect(await sut.refresher.callCount == 1)
        let recorded = await sut.transport.recorded
        #expect(recorded.count == 2)
        #expect(recorded.first?.bodyData == recorded.last?.bodyData, "the replay resends the identical body")
    }

    @Test("a thrown TrackerAPIError.unauthorized throws unauthorized")
    func thrownUnauthorized() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.unauthorized)

        await #expect(throws: RecordPurchaseError.unauthorized) {
            _ = try await sut.create()
        }
    }

    // MARK: 403

    @Test("403 CANNOT_PURCHASE_OWN_LIST (6104) throws cannotPurchaseOwnList")
    func ownList() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 403, json: PurchaseWire.cannotPurchaseOwnList)

        await #expect(throws: RecordPurchaseError.cannotPurchaseOwnList) {
            _ = try await sut.create()
        }
    }

    @Test("403 is cannotPurchaseOwnList when either the errorCode or the numeric code says so",
          arguments: [PurchaseWire.ownListByCodeOnly, PurchaseWire.ownListByErrorCodeOnly])
    func ownListByEitherField(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 403, json: body)

        await #expect(throws: RecordPurchaseError.cannotPurchaseOwnList) {
            _ = try await sut.create()
        }
    }

    @Test("any other 403 (including ACCOUNT_DISABLED) throws forbidden, never cannotPurchaseOwnList",
          arguments: [PurchaseWire.forbidden, PurchaseWire.accountDisabled])
    func otherForbidden(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 403, json: body)

        await #expect(throws: RecordPurchaseError.forbidden) {
            _ = try await sut.create()
        }
    }

    // MARK: 404

    @Test("404 ITEM_NOT_FOUND, LIST_NOT_FOUND and USER_NOT_FOUND all throw notFound (never forbidden)",
          arguments: [PurchaseWire.itemNotFound, ListWire.listNotFound, PurchaseWire.userNotFound])
    func notFound(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 404, json: body)

        await #expect(throws: RecordPurchaseError.notFound) {
            _ = try await sut.create()
        }
    }

    // MARK: 422 (undocumented by the spec)

    @Test("422 is not documented for createPurchase and throws invalidResponse")
    func unprocessable() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 422, json: PurchaseWire.unprocessable)

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value")
    func rateLimited() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)

        await #expect(throws: RecordPurchaseError.rateLimited(retryAfter: 0.001)) {
            _ = try await sut.create()
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited keeps its retryAfter")
    func thrownRateLimited() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 7))

        await #expect(throws: RecordPurchaseError.rateLimited(retryAfter: 7)) {
            _ = try await sut.create()
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server")
    func serverError() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)

        await #expect(throws: RecordPurchaseError.server) {
            _ = try await sut.create()
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: [502, 503])
    func undocumented5xx(status: Int) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)

        await #expect(throws: RecordPurchaseError.server) {
            _ = try await sut.create()
        }
    }

    @Test("an undocumented non-5xx status (418, 405) throws invalidResponse", arguments: [418, 405])
    func undocumentedOther(status: Int) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: status, json: ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
        )

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    // MARK: Wrong shapes and malformed bodies

    @Test("a 200 confirmation_required with empty warnings throws invalidResponse and creates nothing")
    func confirmationWithoutWarnings() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: []))

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    @Test("a 200 confirmation_required whose warnings carry no token throws invalidResponse")
    func confirmationWithoutToken() async throws {
        let sut = try makePurchaseRepoSUT()
        let warning = PurchaseWire.warningJSON(token: "")
        await sut.transport.enqueue(status: 200, json: PurchaseWire.confirmationEnvelope(warnings: [warning]))

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    // I4b CHANGE (spec item 3): a 201 means the server created the purchase, so a 201 body that
    // cannot be read or mapped is `.unconfirmed` (was `.invalidResponse`).
    @Test("a 201 that carries confirmation_required throws unconfirmed (the purchase exists)")
    func createdStatusWithConfirmationBody() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: 201, json: PurchaseWire.confirmationInCreatedEnvelope(warnings: [PurchaseWire.warningJSON()])
        )

        await #expect(throws: RecordPurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    // I4b CHANGE: split by status. A malformed 200 stays `.invalidResponse`; a malformed 201 is
    // `.unconfirmed`.
    @Test("a malformed 200 body (decoding failure) throws invalidResponse",
          arguments: ["{ this is not json", "{ \"success\": true }"])
    func malformedOkBody(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 200, json: body)

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    @Test("a malformed 201 body (decoding failure) throws unconfirmed (the purchase exists)",
          arguments: ["{ this is not json", "{ \"success\": true }"])
    func malformedCreatedBody(body: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: body)

        await #expect(throws: RecordPurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    // I4b CHANGE: was `.invalidResponse`; the 201 says the purchase exists.
    @Test("a created purchase missing a required field throws unconfirmed")
    func purchaseMissingRequiredField() async throws {
        let sut = try makePurchaseRepoSUT()
        let broken = "{ \"id\": \"purchase-1\", \"itemId\": \"item-1\" }"
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope(purchase: broken))

        await #expect(throws: RecordPurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    // I4b CHANGE: was `.invalidResponse`; the 201 says the purchase exists.
    @Test("a created purchase with an unknown shipping status throws unconfirmed")
    func unknownShippingStatus() async throws {
        let sut = try makePurchaseRepoSUT()
        let purchase = PurchaseWire.purchaseJSON(shippingStatus: "TELEPORTED")
        await sut.transport.enqueue(status: 201, json: PurchaseWire.createdEnvelope(purchase: purchase))

        await #expect(throws: RecordPurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    // I4b CHANGE: was `.invalidResponse`; the 201 says the purchase exists.
    @Test("a 201 with no body at all throws unconfirmed")
    func emptySuccessBody() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueEmpty(status: 201)

        await #expect(throws: RecordPurchaseError.unconfirmed) {
            _ = try await sut.create()
        }
    }

    @Test("a thrown TrackerAPIError.decoding throws invalidResponse")
    func thrownDecoding() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.decoding(URLError(.cannotParseResponse)))

        await #expect(throws: RecordPurchaseError.invalidResponse) {
            _ = try await sut.create()
        }
    }

    // MARK: Thrown errors from the middleware

    @Test("thrown TrackerAPIError values map like the item repository: forbidden, notFound, validation, server, undocumented")
    func thrownTrackerErrors() async throws {
        let cases: [(TrackerAPIError, RecordPurchaseError)] = [
            (.forbidden, .forbidden),
            (.notFound, .notFound),
            (.validation("Total cost must be positive"), .validation(message: "Total cost must be positive")),
            (.server(500), .server),
            (.undocumented(status: 503), .server),
            (.undocumented(status: 418), .invalidResponse)
        ]
        for (thrown, expected) in cases {
            let sut = try makePurchaseRepoSUT()
            await sut.transport.enqueueThrow(thrown)

            let result = await captureError { _ = try await sut.create() }

            #expect(result == expected, "\(thrown) should map to \(expected), got \(String(describing: result))")
        }
    }

    @Test("a transport failure (URLError) throws network")
    func transportFailure() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))

        await #expect(throws: RecordPurchaseError.network) {
            _ = try await sut.create()
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network")
    func middlewareNetworkError() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))

        await #expect(throws: RecordPurchaseError.network) {
            _ = try await sut.create()
        }
    }

    @Test("a refresh that fails for a non-credential reason throws network")
    func nonCredentialRefreshFailure() async throws {
        let sut = try makePurchaseRepoSUT(refreshFailure: SessionRefreshError.other(URLError(.notConnectedToInternet)))
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        let result = await captureError { _ = try await sut.create() }

        #expect(result == .network)
    }

    @Test("a URLError.cancelled becomes CancellationError, never a RecordPurchaseError")
    func urlCancelledIsCancellation() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.create()
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to a RecordPurchaseError")
    func cancellationIsRethrown() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.create()
        }
    }

    @Test("the repository never produces sessionEnded, whatever the failure",
          arguments: [400, 401, 403, 404, 422, 429, 500, 503, 418])
    func neverSessionEnded(status: Int) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(
            status: status, json: ListWire.errorJSON(code: 1000, errorCode: "ANY", message: "Any"), times: 3
        )

        let result = await captureError { _ = try await sut.create() }

        #expect(result != .sessionEnded)
    }

    // MARK: Helper

    /// Runs the call and returns the RecordPurchaseError it threw (nil when it threw nothing or
    /// something else).
    private func captureError(_ body: () async throws -> Void) async -> RecordPurchaseError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? RecordPurchaseError
        }
    }
}
