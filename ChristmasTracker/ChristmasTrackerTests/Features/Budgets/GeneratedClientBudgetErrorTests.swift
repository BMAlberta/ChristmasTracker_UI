//
//  GeneratedClientBudgetErrorTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: every documented failure of getStats, listBudgets, getBudget, createBudget,
//  updateBudget, deleteBudget and duplicateBudget, and the fallbacks, mapped to the exact typed
//  BudgetError through the REAL factory-built client with a fake transport.
//
//  Mapping under test (Gate 1 Story B interface, every case explicit, no blanket default):
//    400 (stats, create, update, duplicate)  -> .validation(message: envelope message, empty when absent)
//                                               including 3007 INVALID_PRICE
//    401 (after the one refresh)             -> .unauthorized (a refresh then replay succeeds)
//    403 (incl. ACCOUNT_DISABLED)            -> .forbidden
//    404 (BUDGET_NOT_FOUND, any other body)  -> .notFound, never forbidden
//    409 (create, duplicate)                 -> .alreadyExists(message: envelope message)
//    422 on deleteBudget (documented)        -> .hasPurchases(message: envelope message)
//    422 on create, update, duplicate        -> .sumExceedsTotal(message: "") BY STATUS (the body is
//                                               not hand-parsed; the fixed fallback text shows)
//    422 on a read                           -> .invalidResponse
//    429 / thrown rateLimited                -> .rateLimited(retryAfter:)
//    500, undocumented 5xx                   -> .server
//    other undocumented                      -> .invalidResponse
//    URLError                                -> .network, EVERY code; .cancelled is a CancellationError
//    decoding failure                        -> .invalidResponse
//    SessionRefreshError                     -> .unauthorized (credential) or .network
//    .sessionEnded is never produced by the repository.
//
//  A 429 RESPONSE is pinned for the operations the rate limit middleware does not retry (a GET is
//  retried after a sleep, which no test waits for); the thrown rateLimited error is pinned for all.
//  Spec observation: updateBudget documents no 422 and no 409; a 422 is still the sum rule.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientBudgetRepository errors", .timeLimit(.minutes(1)))
struct GeneratedClientBudgetErrorTests {

    nonisolated static let operationsWith400: [BudgetOp] = BudgetOp.allCases.filter(\.documents400)
    nonisolated static let operationsWith409: [BudgetOp] = BudgetOp.allCases.filter(\.documents409)
    nonisolated static let sumRuleWrites: [BudgetOp] = BudgetOp.allCases.filter(\.isSumRuleWrite)
    nonisolated static let operationsNotRetriedOn429: [BudgetOp] = BudgetOp.allCases.filter { !$0.isRetriedOn429 }
    nonisolated static let readOperations: [BudgetOp] = [.stats, .list, .get]

    // MARK: 400

    @Test("400 passes the server's message through as validation", arguments: operationsWith400)
    func badRequest(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 400, json: BudgetWire.validationError)

        await #expect(throws: BudgetError.validation(message: "Year must be between 2000 and 2100")) {
            try await sut.run(op)
        }
    }

    @Test("400 INVALID_PRICE (3007) throws validation with the server's message", arguments: operationsWith400)
    func badRequestInvalidPrice(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 400, json: BudgetWire.invalidPrice)

        await #expect(throws: BudgetError.validation(message: "Invalid price")) {
            try await sut.run(op)
        }
    }

    @Test("400 with surrounding blanks reads as the trimmed message", arguments: operationsWith400)
    func badRequestIsTrimmed(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: 400, json: ListWire.errorJSON(code: 3007, errorCode: "INVALID_PRICE", message: "  Invalid price  ")
        )

        let thrown = await sut.budgetError(op)

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage == "Invalid price")
    }

    @Test("400 with no message at all throws validation and still reads as a plain message", arguments: operationsWith400)
    func absentValidationMessage(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        let body = """
        { "success": false, "error": { "code": 3001, "errorCode": "VALIDATION_ERROR" }, "meta": \(ListWire.metaJSON) }
        """
        await sut.transport.enqueue(status: 400, json: body)

        let thrown = await sut.budgetError(op)

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage.isEmpty == false)
    }

    @Test("400 whose envelope cannot be decoded throws validation with an empty message", arguments: operationsWith400)
    func undecodableBadRequest(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 400, json: "{ this is not json")

        await #expect(throws: BudgetError.validation(message: "")) {
            try await sut.run(op)
        }
    }

    // MARK: 401

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: BudgetOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        await #expect(throws: BudgetError.unauthorized) {
            try await sut.run(op)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized and does not replay",
          arguments: BudgetOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        await #expect(throws: BudgetError.unauthorized) {
            try await sut.run(op)
        }
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh replays the request and succeeds", arguments: BudgetOp.allCases)
    func refreshThenReplaySucceeds(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await sut.run(op)

        #expect(await sut.refresher.callCount == 1)
        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        #expect(requests.first?.bodyData == requests.last?.bodyData, "the replay resends the identical body")
        #expect(requests.first?.request.path == requests.last?.request.path)
    }

    // MARK: 403

    @Test("any 403 (including ACCOUNT_DISABLED) throws forbidden",
          arguments: BudgetOp.allCases, [BudgetWire.forbidden, BudgetWire.accountDisabled])
    func forbidden(op: BudgetOp, body: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 403, json: body)

        await #expect(throws: BudgetError.forbidden) {
            try await sut.run(op)
        }
    }

    // MARK: 404

    @Test("404 BUDGET_NOT_FOUND throws notFound, never forbidden", arguments: BudgetOp.allCases)
    func notFound(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 404, json: BudgetWire.budgetNotFound)

        await #expect(throws: BudgetError.notFound) {
            try await sut.run(op)
        }
    }

    @Test("any other 404 body throws notFound too", arguments: BudgetOp.allCases,
          [BudgetWire.userNotFound, ListWire.listNotFound, "{ this is not json"])
    func otherNotFoundBodies(op: BudgetOp, body: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 404, json: body)

        await #expect(throws: BudgetError.notFound) {
            try await sut.run(op)
        }
    }

    // MARK: 409

    @Test("409 BUDGET_ALREADY_EXISTS throws alreadyExists with the server's message", arguments: operationsWith409)
    func conflict(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 409, json: BudgetWire.budgetAlreadyExists)

        await #expect(throws: BudgetError.alreadyExists(message: "Budget already exists")) {
            try await sut.run(op)
        }
    }

    @Test("409 with no readable message throws alreadyExists and reads as the fixed fallback", arguments: operationsWith409)
    func conflictWithoutMessage(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 409, json: "{ this is not json")

        let thrown = await sut.budgetError(op)

        guard case .alreadyExists = thrown else {
            Issue.record("expected .alreadyExists, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage == "You already have a budget for that year.")
    }

    // MARK: 422

    @Test("deleteBudget 422 throws hasPurchases with the server's message")
    func deleteWithPurchases() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 422, json: BudgetWire.cannotDeleteWithPurchases)

        await #expect(throws: BudgetError.hasPurchases(message: "Cannot delete budget with existing purchases")) {
            try await sut.budgets.delete(year: 2026)
        }
    }

    @Test("deleteBudget 422 with no readable message is hasPurchases and reads as the fixed fallback")
    func deleteWithPurchasesNoMessage() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 422, json: "{ this is not json")

        let thrown = await sut.budgetError(.delete)

        guard case .hasPurchases = thrown else {
            Issue.record("expected .hasPurchases, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage == "A budget with purchases can't be deleted.")
    }

    @Test("an undocumented 422 on create, update or duplicate is sumExceedsTotal by status, with no hand-parsed message",
          arguments: sumRuleWrites)
    func undocumented422IsTheSumRule(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 422, json: BudgetWire.sumExceedsTotal)

        await #expect(throws: BudgetError.sumExceedsTotal(message: "")) {
            try await sut.run(op)
        }
    }

    @Test("the sum rule error reads as the fixed fallback text", arguments: sumRuleWrites)
    func sumRuleMessage(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 422, json: BudgetWire.sumExceedsTotal)

        let thrown = await sut.budgetError(op)

        #expect(thrown?.userMessage == "Limits add up to more than the total")
    }

    @Test("a 422 on a read is not the sum rule: it throws invalidResponse", arguments: readOperations)
    func undocumented422OnReads(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 422, json: BudgetWire.sumExceedsTotal)

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: operationsNotRetriedOn429)
    func rateLimited(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)

        await #expect(throws: BudgetError.rateLimited(retryAfter: 0.001)) {
            try await sut.run(op)
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited keeps its retryAfter", arguments: BudgetOp.allCases)
    func thrownRateLimited(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 7))

        await #expect(throws: BudgetError.rateLimited(retryAfter: 7)) {
            try await sut.run(op)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: BudgetOp.allCases)
    func serverError(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)

        await #expect(throws: BudgetError.server) {
            try await sut.run(op)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: BudgetOp.allCases, [502, 503])
    func undocumented5xx(op: BudgetOp, status: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)

        await #expect(throws: BudgetError.server) {
            try await sut.run(op)
        }
    }

    @Test("an undocumented non-5xx status (418, 405) throws invalidResponse", arguments: BudgetOp.allCases, [418, 405])
    func undocumentedOther(op: BudgetOp, status: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: status, json: BudgetWire.teapot)

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }

    // MARK: Thrown errors from the middleware

    @Test("thrown TrackerAPIError values map: unauthorized, forbidden, notFound, validation, server, undocumented, decoding, network",
          arguments: BudgetOp.allCases)
    func thrownTrackerErrors(op: BudgetOp) async throws {
        let cases: [(TrackerAPIError, BudgetError)] = [
            (.unauthorized, .unauthorized),
            (.forbidden, .forbidden),
            (.notFound, .notFound),
            (.validation("Invalid price"), .validation(message: "Invalid price")),
            (.rateLimited(retryAfter: 3), .rateLimited(retryAfter: 3)),
            (.server(500), .server),
            (.undocumented(status: 503), .server),
            (.undocumented(status: 418), .invalidResponse),
            (.decoding(URLError(.cannotParseResponse)), .invalidResponse),
            (.network(URLError(.notConnectedToInternet)), .network)
        ]
        for (thrown, expected) in cases {
            let sut = try makeBudgetWireSUT()
            await sut.transport.enqueueThrow(thrown)

            let result = await sut.budgetError(op)

            #expect(result == expected, "\(op): \(thrown) should map to \(expected), got \(String(describing: result))")
        }
    }

    // MARK: Transport failures

    @Test("any URLError from the transport throws network, whatever the code",
          arguments: BudgetOp.allCases, [
        URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .secureConnectionFailed, .badServerResponse,
        .cannotParseResponse, .zeroByteResource, .dataNotAllowed, .internationalRoamingOff, .callIsActive
    ])
    func transportFailure(op: BudgetOp, code: URLError.Code) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueThrow(URLError(code))

        await #expect(throws: BudgetError.network) {
            try await sut.run(op)
        }
    }

    @Test("a URLError with a code outside the list still throws network", arguments: BudgetOp.allCases)
    func unknownURLErrorCode(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueThrow(URLError(URLError.Code(rawValue: -99_999)))

        await #expect(throws: BudgetError.network) {
            try await sut.run(op)
        }
    }

    @Test("a refresh that fails for a non-credential reason throws network", arguments: BudgetOp.allCases)
    func nonCredentialRefreshFailure(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT(refreshFailure: SessionRefreshError.other(URLError(.notConnectedToInternet)))
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)

        let result = await sut.budgetError(op)

        #expect(result == .network)
    }

    // MARK: Decoding

    @Test("a decoding failure of the success body throws invalidResponse", arguments: [
        BudgetOp.stats, .list, .get, .create, .update, .duplicate
    ])
    func decodingFailure(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: "[1, 2, 3]")

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }

    // MARK: Cancellation

    @Test("a URLError.cancelled becomes CancellationError, never a BudgetError", arguments: BudgetOp.allCases)
    func urlCancelledIsCancellation(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueThrow(URLError(.cancelled))

        await #expect(throws: CancellationError.self) {
            try await sut.run(op)
        }
    }

    @Test("cancellation is rethrown as CancellationError", arguments: BudgetOp.allCases)
    func cancellationIsRethrown(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueThrow(CancellationError())

        await #expect(throws: CancellationError.self) {
            try await sut.run(op)
        }
    }

    // MARK: Contract

    @Test("the repository never produces sessionEnded, whatever the failure",
          arguments: BudgetOp.allCases, [400, 401, 403, 404, 409, 422, 429, 500, 503, 418])
    func neverSessionEnded(op: BudgetOp, status: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: status, json: ListWire.errorJSON(code: 1000, errorCode: "ANY", message: "Any"), times: 3
        )

        let result = await sut.budgetError(op)

        #expect(result != .sessionEnded)
    }

    @Test("every failure is a BudgetError or a CancellationError, nothing else",
          arguments: BudgetOp.allCases, [400, 401, 403, 404, 409, 422, 429, 500, 502, 418])
    func onlyTypedErrors(op: BudgetOp, status: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError, times: 3)

        let thrown = await sut.thrown(op)

        #expect(thrown is BudgetError || thrown is CancellationError, "\(String(describing: thrown))")
    }
}
