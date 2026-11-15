//
//  GeneratedClientPurchaseHistoryErrorTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC3 and AC4: every documented failure of listPurchases, the fallbacks, transport failures and
//  cancellation, mapped to the typed PurchaseHistoryError through the REAL factory-built client with a
//  fake transport.
//
//    400 -> .validation(message: envelope message trimmed, "" when unreadable)
//    401 (after the one refresh) -> .unauthorized     403 -> .forbidden     404 -> .notFound
//    429 -> .rateLimited      500 -> .server
//    undocumented 5xx -> .server; any other undocumented status -> .invalidResponse
//    a documented status with an undecodable body still maps by status
//    URLError -> .network; URLError.cancelled and CancellationError -> CancellationError
//    .sessionEnded is never produced by the repository
//
//  A 429 RESPONSE on a GET is retried by the rate limit middleware, which throws a rateLimited error
//  carrying the wait once it gives up; the test scripts enough 429 answers (0.001 s waits) to reach
//  that point and pins the case, and a thrown rate limit keeps its delay.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseHistoryRepository errors", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseHistoryErrorTests {

    private let garbage = "{ this is not json"

    // MARK: 400

    @Test("400 passes the server's message through trimmed")
    func badRequest() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 400, json: PurchaseHistoryWire.validationError)

        await #expect(throws: PurchaseHistoryError.validation(message: "Year must be between 1000 and 9999")) {
            _ = try await sut.load()
        }
    }

    @Test("400 whose envelope cannot be decoded throws validation with an empty message")
    func undecodableBadRequest() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 400, json: garbage)

        await #expect(throws: PurchaseHistoryError.validation(message: "")) {
            _ = try await sut.load()
        }
    }

    @Test("400 with no message in the envelope is still a validation error with a readable user message")
    func absentValidationMessage() async throws {
        let sut = try makePurchaseHistorySUT()
        let body = """
        { "success": false, "error": { "code": 3001, "errorCode": "VALIDATION_ERROR" }, "meta": \(ListWire.metaJSON) }
        """
        await sut.transport.enqueue(status: 400, json: body)

        let error = await sut.historyError()

        guard case .validation = error else {
            Issue.record("expected .validation, got \(String(describing: error))")
            return
        }
        #expect(error?.userMessage.isEmpty == false)
    }

    // MARK: 401

    @Test("401 then a second 401 after one refresh throws unauthorized")
    func unauthorizedAfterRefresh() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        await #expect(throws: PurchaseHistoryError.unauthorized) {
            _ = try await sut.load()
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized and does not replay")
    func unauthorizedWhenRefreshFails() async throws {
        let sut = try makePurchaseHistorySUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        await #expect(throws: PurchaseHistoryError.unauthorized) {
            _ = try await sut.load()
        }
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed page, with the same query")
    func refreshThenReplay() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(
            status: 200, json: PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON(id: "p1")], nextCursor: nil)
        )

        let page = try await sut.load(PurchaseHistoryFilter(year: 2026), cursor: "c1")

        #expect(page.rows.map(\.id) == ["p1"])
        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        #expect(requests.first?.request.path == requests.last?.request.path, "the replay resends the identical query")
    }

    @Test("a refresh that fails for a non-credential reason throws network")
    func nonCredentialRefreshFailure() async throws {
        let sut = try makePurchaseHistorySUT(refreshFailure: SessionRefreshError.other(URLError(.notConnectedToInternet)))
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        #expect(await sut.historyError() == .network)
    }

    // MARK: 403, 404

    @Test("any 403 throws forbidden", arguments: [PurchaseHistoryWire.forbidden, "{ this is not json"])
    func forbidden(body: String) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 403, json: body)

        await #expect(throws: PurchaseHistoryError.forbidden) {
            _ = try await sut.load()
        }
    }

    @Test("any 404 throws notFound, never forbidden", arguments: [PurchaseHistoryWire.notFound, ListWire.listNotFound, "{ this is not json"])
    func notFound(body: String) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 404, json: body)

        await #expect(throws: PurchaseHistoryError.notFound) {
            _ = try await sut.load()
        }
    }

    // MARK: 429

    @Test("429 answers (after the middleware gives up retrying) throw rateLimited")
    func rateLimited() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 12)

        let error = await sut.historyError()

        guard case .rateLimited = error else {
            Issue.record("expected .rateLimited, got \(String(describing: error))")
            return
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited keeps its retryAfter")
    func thrownRateLimited() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 7))

        await #expect(throws: PurchaseHistoryError.rateLimited(retryAfter: 7)) {
            _ = try await sut.load()
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: [ListWire.internalError, "{ this is not json"])
    func serverError(body: String) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 500, json: body)

        await #expect(throws: PurchaseHistoryError.server) {
            _ = try await sut.load()
        }
    }

    @Test("an undocumented 5xx throws server", arguments: [502, 503, 504, 599])
    func undocumented5xx(status: Int) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)

        await #expect(throws: PurchaseHistoryError.server) {
            _ = try await sut.load()
        }
    }

    @Test("an undocumented non-5xx status throws invalidResponse", arguments: [418, 405, 422, 409, 302])
    func undocumentedOther(status: Int) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: status, json: PurchaseHistoryWire.teapot)

        await #expect(throws: PurchaseHistoryError.invalidResponse) {
            _ = try await sut.load()
        }
    }

    // MARK: Transport failures

    @Test("any URLError from the transport throws network, whatever the code", arguments: [
        URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed, .badServerResponse,
        .cannotParseResponse, .zeroByteResource, .dataNotAllowed, .internationalRoamingOff, .callIsActive
    ])
    func transportFailure(code: URLError.Code) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: PurchaseHistoryError.network) {
            _ = try await sut.load()
        }
    }

    @Test("a URLError code outside the known list still throws network")
    func unknownURLErrorCode() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueThrow(URLError(URLError.Code(rawValue: -99_999)))

        await #expect(throws: PurchaseHistoryError.network) {
            _ = try await sut.load()
        }
    }

    // MARK: Cancellation

    @Test("a URLError.cancelled becomes CancellationError, never a PurchaseHistoryError")
    func urlCancelledIsCancellation() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            _ = try await sut.load()
        }
    }

    @Test("a CancellationError is rethrown as CancellationError")
    func cancellationIsRethrown() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await sut.load()
        }
    }

    // MARK: Contract

    @Test("the repository never produces sessionEnded, whatever the failure", arguments: [400, 401, 403, 404, 422, 429, 500, 503, 418])
    func neverSessionEnded(status: Int) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(
            status: status, json: ListWire.errorJSON(code: 1000, errorCode: "ANY", message: "Any"), times: 12
        )

        #expect(await sut.historyError() != .sessionEnded)
    }

    @Test("every failure is a PurchaseHistoryError or a CancellationError, nothing else", arguments: [400, 401, 403, 404, 429, 500, 502, 418])
    func onlyTypedErrors(status: Int) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError, times: 12)

        let thrown = await sut.thrown()

        #expect(thrown is PurchaseHistoryError || thrown is CancellationError, "\(String(describing: thrown))")
    }
}
