//
//  GeneratedClientPurchaseManagementErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: every documented failure of getPurchase, updatePurchase, updatePurchaseShipping and
//  deletePurchase, and the fallbacks, mapped to the exact typed PurchaseManagementError through the
//  REAL factory-built client with a fake transport.
//
//  Mapping under test (Gate 1 Story B interface item 2, every case explicit, no blanket default):
//    200 with a wrong shape                  -> .invalidResponse (in GeneratedClientPurchaseManagementRepositoryTests)
//    400 (the three operations that document it) -> .validation(message: envelope message, blank when absent)
//    401 (after the one refresh)             -> .unauthorized
//    403 (incl. ACCOUNT_DISABLED)            -> .forbidden
//    404 PURCHASE_NOT_FOUND                  -> .notFound
//    429 / thrown rateLimited                -> .rateLimited(retryAfter:)
//    500, undocumented 5xx                   -> .server
//    other undocumented, decoding            -> .invalidResponse
//    thrown TrackerAPIError                  -> as listed in the table in `thrownTrackerErrors`
//    any URLError (transport failure)        -> .network, EVERY code (no unconfirmed rule here);
//                                               .cancelled is a CancellationError
//    SessionRefreshError                     -> .network
//    CancellationError                       -> rethrown
//    .sessionEnded is never produced by the repository.
//
//  getPurchase documents no 400 in the contract, so a 400 is only pinned for the other three.
//  A 429 RESPONSE is pinned for the operations the rate limit middleware does not retry (a GET is
//  retried after a sleep, which no test waits for); the thrown rateLimited error is pinned for all.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseManagementRepository errors", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseManagementErrorTests {

    nonisolated static let operationsWith400: [ManagementOp] = [.updateNotes, .updateShipping, .delete]
    nonisolated static let operationsNotRetriedOn429: [ManagementOp] = [.updateNotes, .updateShipping, .delete]

    // MARK: 400

    @Test("400 passes the server's message through as validation", arguments: operationsWith400)
    func badRequest(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 400, json: ManagementWire.validationError)

        await #expect(throws: PurchaseManagementError.validation(message: "Notes must be at most 1000 characters")) {
            _ = try await sut.run(op)
        }
    }

    @Test("400 INVALID_INPUT also throws validation with its message", arguments: operationsWith400)
    func badRequestInvalidInput(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 400, json: ManagementWire.invalidInput)

        await #expect(throws: PurchaseManagementError.validation(message: "Invalid purchase id")) {
            _ = try await sut.run(op)
        }
    }

    @Test("400 with no message at all throws validation and still reads as a plain message", arguments: operationsWith400)
    func absentValidationMessage(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        let body = """
        { "success": false, "error": { "code": 3001, "errorCode": "VALIDATION_ERROR" }, "meta": \(ListWire.metaJSON) }
        """
        await sut.transport.enqueue(status: 400, json: body)

        let thrown = await sut.managementError(op)

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage.isEmpty == false)
    }

    @Test("400 whose envelope cannot be decoded throws validation with an empty message", arguments: operationsWith400)
    func undecodableBadRequest(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 400, json: "{ this is not json")

        await #expect(throws: PurchaseManagementError.validation(message: "")) {
            _ = try await sut.run(op)
        }
    }

    // MARK: 401

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: ManagementOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        await #expect(throws: PurchaseManagementError.unauthorized) {
            _ = try await sut.run(op)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized and does not replay",
          arguments: ManagementOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        await #expect(throws: PurchaseManagementError.unauthorized) {
            _ = try await sut.run(op)
        }
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed purchase", arguments: ManagementOp.allCases)
    func refreshThenReplaySucceeds(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: 200, json: ManagementWire.purchaseEnvelope())

        let recorded = try await sut.run(op)

        #expect(recorded.id == "purchase-1")
        #expect(await sut.refresher.callCount == 1)
        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        #expect(requests.first?.bodyData == requests.last?.bodyData, "the replay resends the identical body")
    }

    // MARK: 403

    @Test("any 403 (including ACCOUNT_DISABLED) throws forbidden",
          arguments: ManagementOp.allCases, [ManagementWire.forbidden, ManagementWire.accountDisabled])
    func forbidden(op: ManagementOp, body: String) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 403, json: body)

        await #expect(throws: PurchaseManagementError.forbidden) {
            _ = try await sut.run(op)
        }
    }

    // MARK: 404

    @Test("404 PURCHASE_NOT_FOUND throws notFound, never forbidden", arguments: ManagementOp.allCases)
    func notFound(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 404, json: ManagementWire.purchaseNotFound)

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.run(op)
        }
    }

    @Test("any other 404 body throws notFound too", arguments: ManagementOp.allCases,
          [ManagementWire.userNotFound, ListWire.listNotFound, "{ this is not json"])
    func otherNotFoundBodies(op: ManagementOp, body: String) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 404, json: body)

        await #expect(throws: PurchaseManagementError.notFound) {
            _ = try await sut.run(op)
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: operationsNotRetriedOn429)
    func rateLimited(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)

        await #expect(throws: PurchaseManagementError.rateLimited(retryAfter: 0.001)) {
            _ = try await sut.run(op)
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited keeps its retryAfter", arguments: ManagementOp.allCases)
    func thrownRateLimited(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 7))

        await #expect(throws: PurchaseManagementError.rateLimited(retryAfter: 7)) {
            _ = try await sut.run(op)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: ManagementOp.allCases)
    func serverError(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)

        await #expect(throws: PurchaseManagementError.server) {
            _ = try await sut.run(op)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: ManagementOp.allCases, [502, 503])
    func undocumented5xx(op: ManagementOp, status: Int) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)

        await #expect(throws: PurchaseManagementError.server) {
            _ = try await sut.run(op)
        }
    }

    @Test("an undocumented non-5xx status (418, 405, 422, 409) throws invalidResponse",
          arguments: ManagementOp.allCases, [418, 405, 422, 409])
    func undocumentedOther(op: ManagementOp, status: Int) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: status, json: ManagementWire.teapot)

        await #expect(throws: PurchaseManagementError.invalidResponse) {
            _ = try await sut.run(op)
        }
    }

    // MARK: Thrown errors from the middleware

    @Test("thrown TrackerAPIError values map: unauthorized, forbidden, notFound, validation, server, undocumented, conflict, invalidServerURL, versionOutdated, decoding, network",
          arguments: ManagementOp.allCases)
    func thrownTrackerErrors(op: ManagementOp) async throws {
        let details = VersionOutdatedDetails(
            minimumVersion: "9.0.0", minimumBuild: nil, latestVersion: nil, latestBuild: nil,
            manifestUrl: nil, ipaUrl: nil
        )
        let cases: [(TrackerAPIError, PurchaseManagementError)] = [
            (.unauthorized, .unauthorized),
            (.forbidden, .forbidden),
            (.notFound, .notFound),
            (.validation("Notes are too long"), .validation(message: "Notes are too long")),
            (.rateLimited(retryAfter: 3), .rateLimited(retryAfter: 3)),
            (.server(500), .server),
            (.undocumented(status: 503), .server),
            (.undocumented(status: 418), .invalidResponse),
            (.conflict, .server),
            (.invalidServerURL, .invalidResponse),
            (.versionOutdated(details), .server),
            (.decoding(URLError(.cannotParseResponse)), .invalidResponse),
            (.network(URLError(.notConnectedToInternet)), .network)
        ]
        for (thrown, expected) in cases {
            let sut = try makePurchaseManagementSUT()
            await sut.transport.enqueueThrow(thrown)

            let result = await sut.managementError(op)

            #expect(result == expected, "\(op): \(thrown) should map to \(expected), got \(String(describing: result))")
        }
    }

    // MARK: Transport failures

    @Test("any URLError from the transport throws network, whatever the code (no unconfirmed rule here)",
          arguments: ManagementOp.allCases, [
        URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed, .badServerResponse,
        .cannotParseResponse, .zeroByteResource, .dataNotAllowed, .internationalRoamingOff, .callIsActive
    ])
    func transportFailure(op: ManagementOp, code: URLError.Code) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: PurchaseManagementError.network) {
            _ = try await sut.run(op)
        }
    }

    @Test("a URLError with a code outside the list still throws network", arguments: ManagementOp.allCases)
    func unknownURLErrorCode(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(URLError(URLError.Code(rawValue: -99_999)))

        await #expect(throws: PurchaseManagementError.network) {
            _ = try await sut.run(op)
        }
    }

    @Test("a refresh that fails for a non-credential reason throws network", arguments: ManagementOp.allCases)
    func nonCredentialRefreshFailure(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT(refreshFailure: SessionRefreshError.other(URLError(.notConnectedToInternet)))
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        let result = await sut.managementError(op)

        #expect(result == .network)
    }

    // MARK: Cancellation

    @Test("a URLError.cancelled becomes CancellationError, never a PurchaseManagementError",
          arguments: ManagementOp.allCases)
    func urlCancelledIsCancellation(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.run(op)
        }
    }

    @Test("cancellation is rethrown as CancellationError", arguments: ManagementOp.allCases)
    func cancellationIsRethrown(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.run(op)
        }
    }

    // MARK: Contract

    @Test("the repository never produces sessionEnded, whatever the failure",
          arguments: ManagementOp.allCases, [400, 401, 403, 404, 422, 429, 500, 503, 418])
    func neverSessionEnded(op: ManagementOp, status: Int) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(
            status: status, json: ListWire.errorJSON(code: 1000, errorCode: "ANY", message: "Any"), times: 3
        )

        let result = await sut.managementError(op)

        #expect(result != .sessionEnded)
    }

    @Test("every failure is a PurchaseManagementError or a CancellationError, nothing else",
          arguments: ManagementOp.allCases, [400, 401, 403, 404, 429, 500, 502, 418])
    func onlyTypedErrors(op: ManagementOp, status: Int) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError, times: 3)

        let thrown = await sut.thrown(op)

        #expect(thrown is PurchaseManagementError || thrown is CancellationError, "\(String(describing: thrown))")
    }
}
