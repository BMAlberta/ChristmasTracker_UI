//
//  GeneratedClientItemRepositoryErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-C: every documented failure of the five item operations, and the fallbacks, mapped
//  to the exact typed ItemError through the REAL factory-built client with a fake transport.
//
//  Mapping under test (Gate 1 addendum, no blanket default):
//    400 INVALID_PRICE (3007)            -> .invalidPrice
//    400 other                           -> .validation(message: envelope message)
//    401 (after the one refresh)         -> .unauthorized
//    403                                 -> .forbidden
//    404                                 -> .notFound
//    422 CANNOT_DELETE_ITEM_WITH_PURCHASES -> .cannotDeleteWithPurchases (delete only)
//    422 other                           -> .validation(message:)
//    429 / thrown rateLimited            -> .rateLimited(retryAfter:)
//    thrown unauthorized                 -> .unauthorized
//    500 and undocumented 5xx            -> .server
//    other undocumented, decoding        -> .invalidResponse
//    transport failure                   -> .network
//    CancellationError                   -> rethrown
//
//  The 403 ACCOUNT_DISABLED and 404 USER_NOT_FOUND session-ending cases are handled by the
//  middleware seam; here only the status mapping is pinned.
//

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientItemRepository errors", .timeLimit(.minutes(1)))
struct GeneratedClientItemRepositoryErrorTests {

    // MARK: 400

    @Test("400 INVALID_PRICE (3007) throws invalidPrice", arguments: [ItemRepoOp.createItem, .updateItem])
    func invalidPrice(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 400, json: ItemWire.invalidPrice)
        let repo = sut.repo

        await #expect(throws: ItemError.invalidPrice) {
            try await op.run(repo)
        }
    }

    @Test("400 with another code passes the envelope message through as validation", arguments: [ItemRepoOp.createItem, .updateItem])
    func otherBadRequest(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 400, json: ItemWire.validationError)
        let repo = sut.repo

        await #expect(throws: ItemError.validation(message: "Name must be between 1 and 200 characters")) {
            try await op.run(repo)
        }
    }

    @Test("400 with a code that is not INVALID_PRICE is never invalidPrice, even with a price field detail")
    func otherBadRequestWithDetailsIsNotInvalidPrice() async throws {
        let sut = try makeItemRepoSUT()
        let body = ListWire.errorJSON(
            code: 3001, errorCode: "VALIDATION_ERROR", message: "Request validation failed",
            details: "{ \"errors\": [ { \"field\": \"expectedUnitPrice\", \"message\": \"Required\", \"code\": \"invalid_type\" } ] }"
        )
        await sut.transport.enqueue(status: 400, json: body)
        let repo = sut.repo

        await #expect(throws: ItemError.validation(message: "Request validation failed")) {
            _ = try await repo.createItem(listId: "list-1", sampleCreateItemInput())
        }
    }

    @Test("400 with a blank message throws validation whose user message is the generic text")
    func blankValidationMessage() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 400, json: ItemWire.blankMessageValidation)

        let thrown = await captureItemError { _ = try await sut.repo.createItem(listId: "list-1", sampleCreateItemInput()) }

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage == "Please check the item details and try again.")
    }

    @Test("400 with no message at all throws validation whose user message is the generic text")
    func absentValidationMessage() async throws {
        let sut = try makeItemRepoSUT()
        let body = """
        { "success": false, "error": { "code": 3001, "errorCode": "VALIDATION_ERROR" }, "meta": \(ListWire.metaJSON) }
        """
        await sut.transport.enqueue(status: 400, json: body)

        let thrown = await captureItemError { _ = try await sut.repo.updateItem(id: "item-1", UpdateItemInput(name: "N")) }

        guard case .validation = thrown else {
            Issue.record("expected .validation, got \(String(describing: thrown))")
            return
        }
        #expect(thrown?.userMessage == "Please check the item details and try again.")
    }

    // MARK: 401 (after the middleware's refresh attempt)

    @Test("401 then a second 401 after one refresh throws unauthorized", arguments: ItemRepoOp.allCases)
    func unauthorizedAfterRefreshAttempt(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)
        let repo = sut.repo

        await #expect(throws: ItemError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1, "exactly one refresh attempt")
        #expect(await sut.transport.requestCount == 2, "the original request and one replay")
    }

    @Test("401 whose refresh fails with a credential failure throws unauthorized", arguments: ItemRepoOp.allCases)
    func unauthorizedWhenRefreshCredentialFails(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT(refreshFailure: SessionRefreshError.credentialFailure)
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        let repo = sut.repo

        await #expect(throws: ItemError.unauthorized) {
            try await op.run(repo)
        }
        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 1, "no replay after a failed refresh")
    }

    @Test("401 then success after one refresh returns the replayed result", arguments: ItemRepoOp.allCases)
    func refreshThenReplaySucceeds(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired)
        await sut.transport.enqueue(status: op.successStatus, json: op.successJSON())

        try await op.run(sut.repo)

        #expect(await sut.refresher.callCount == 1)
        #expect(await sut.transport.requestCount == 2)
    }

    @Test("a thrown TrackerAPIError.unauthorized throws unauthorized", arguments: ItemRepoOp.allCases)
    func thrownUnauthorized(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.unauthorized)
        let repo = sut.repo

        await #expect(throws: ItemError.unauthorized) {
            try await op.run(repo)
        }
    }

    // MARK: 403

    @Test("403 throws forbidden", arguments: ItemRepoOp.allCases)
    func forbidden(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 403, json: ItemWire.forbidden)
        let repo = sut.repo

        await #expect(throws: ItemError.forbidden) {
            try await op.run(repo)
        }
    }

    @Test("403 ACCOUNT_DISABLED maps by status to forbidden (the middleware ends the session)", arguments: ItemRepoOp.allCases)
    func accountDisabled(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 403, json: ItemWire.accountDisabled)
        let repo = sut.repo

        await #expect(throws: ItemError.forbidden) {
            try await op.run(repo)
        }
    }

    // MARK: 404

    @Test("404 ITEM_NOT_FOUND throws notFound", arguments: ItemRepoOp.allCases)
    func itemNotFound(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 404, json: ItemWire.itemNotFound)
        let repo = sut.repo

        await #expect(throws: ItemError.notFound) {
            try await op.run(repo)
        }
    }

    @Test("404 LIST_NOT_FOUND on the list-scoped operations throws notFound", arguments: [ItemRepoOp.fetchItems, .createItem])
    func listNotFound(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 404, json: ListWire.listNotFound)
        let repo = sut.repo

        await #expect(throws: ItemError.notFound) {
            try await op.run(repo)
        }
    }

    @Test("404 USER_NOT_FOUND maps by status to notFound (the middleware ends the session)", arguments: ItemRepoOp.allCases)
    func userNotFound(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 404, json: ItemWire.userNotFound)
        let repo = sut.repo

        await #expect(throws: ItemError.notFound) {
            try await op.run(repo)
        }
    }

    // MARK: 422 (delete only)

    @Test("deleteItem 422 CANNOT_DELETE_ITEM_WITH_PURCHASES throws cannotDeleteWithPurchases")
    func deleteWithPurchases() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 422, json: ItemWire.cannotDeleteWithPurchases)
        let repo = sut.repo

        await #expect(throws: ItemError.cannotDeleteWithPurchases) {
            try await repo.deleteItem(id: "item-1")
        }
    }

    @Test("deleteItem 422 with any other code throws validation with the envelope message")
    func deleteOtherUnprocessable() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 422, json: ItemWire.otherUnprocessable)
        let repo = sut.repo

        await #expect(throws: ItemError.validation(message: "Cannot process this request")) {
            try await repo.deleteItem(id: "item-1")
        }
    }

    // MARK: 429

    @Test("429 with Retry-After throws rateLimited carrying that value", arguments: ItemRepoOp.allCases)
    func rateLimited(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        // GET is retried twice by the middleware, so queue three; other verbs use only the first.
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)
        let repo = sut.repo

        await #expect(throws: ItemError.rateLimited(retryAfter: 0.001)) {
            try await op.run(repo)
        }
    }

    @Test("a thrown TrackerAPIError.rateLimited keeps its retryAfter", arguments: ItemRepoOp.allCases)
    func thrownRateLimited(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.rateLimited(retryAfter: 7))
        let repo = sut.repo

        await #expect(throws: ItemError.rateLimited(retryAfter: 7)) {
            try await op.run(repo)
        }
    }

    // MARK: 500 and undocumented

    @Test("500 throws server", arguments: ItemRepoOp.allCases)
    func serverError(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 500, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ItemError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented 5xx (502, 503) throws server", arguments: ItemRepoOp.allCases, [502, 503])
    func undocumented5xx(op: ItemRepoOp, status: Int) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: status, json: ListWire.internalError)
        let repo = sut.repo

        await #expect(throws: ItemError.server) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented non-5xx status (418) throws invalidResponse", arguments: ItemRepoOp.allCases)
    func undocumented418(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(
            status: 418,
            json: ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")
        )
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("an undocumented 409 on createItem throws invalidResponse (no blanket default to server or validation)")
    func undocumentedForThisOperation() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 409, json: ListWire.errorJSON(code: 5002, errorCode: "CONFLICT", message: "Conflict"))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await repo.createItem(listId: "list-1", sampleCreateItemInput())
        }
    }

    // MARK: Malformed and transport

    @Test("a malformed 200/201 body throws invalidResponse", arguments: ItemRepoOp.allCases, ItemMalformedBody.allCases)
    func malformedSuccessBody(op: ItemRepoOp, malformed: ItemMalformedBody) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: op.successStatus, json: malformed.json)
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a success body with an item missing a required field throws invalidResponse", arguments: ItemRepoOp.allCases.filter { $0 != .deleteItem })
    func itemMissingRequiredField(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        let broken = "{ \"id\": \"item-1\", \"listId\": \"list-1\", \"name\": \"Fake Gift\" }"
        let json: String = switch op {
        case .fetchItems: ItemWire.listJSON([broken])
        case .fetchItemDetail: ItemWire.detailEnvelope(item: broken)
        default: ItemWire.itemEnvelope(broken)
        }
        await sut.transport.enqueue(status: op.successStatus, json: json)
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("an item with an unknown status value throws invalidResponse")
    func unknownStatus() async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueue(status: 200, json: ItemWire.listJSON([ItemWire.itemJSON(status: "ARCHIVED_FOREVER")]))
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            _ = try await repo.fetchItems(listId: "list-1")
        }
    }

    @Test("a 200 with no body at all throws invalidResponse", arguments: ItemRepoOp.allCases)
    func emptySuccessBody(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueEmpty(status: op.successStatus)
        let repo = sut.repo

        await #expect(throws: ItemError.invalidResponse) {
            try await op.run(repo)
        }
    }

    @Test("a transport failure (URLError) throws network", arguments: ItemRepoOp.allCases)
    func transportFailure(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))
        let repo = sut.repo

        await #expect(throws: ItemError.network) {
            try await op.run(repo)
        }
    }

    @Test("a middleware network error (TrackerAPIError.network) throws network", arguments: ItemRepoOp.allCases)
    func middlewareNetworkError(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueThrow(TrackerAPIError.network(URLError(.timedOut)))
        let repo = sut.repo

        await #expect(throws: ItemError.network) {
            try await op.run(repo)
        }
    }

    @Test("cancellation is rethrown as CancellationError, never mapped to an ItemError", arguments: ItemRepoOp.allCases)
    func cancellationIsRethrown(op: ItemRepoOp) async throws {
        let sut = try makeItemRepoSUT()
        await sut.transport.enqueueThrow(CancellationError())
        let repo = sut.repo

        await #expect(throws: CancellationError.self) {
            try await op.run(repo)
        }
    }

    // MARK: Helper

    /// Runs the call and returns the ItemError it threw (nil when it threw nothing or something else).
    private func captureItemError(_ body: () async throws -> Void) async -> ItemError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? ItemError
        }
    }
}
