//
//  GeneratedClientPurchaseManagementShippingBodyTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-B (S15): the EXACT JSON body of updatePurchaseShipping, seen through the real
//  factory-built client and the recording fake transport.
//
//  Rules under test (client guide 7.7, Gate 1 Story B interface item 1):
//   - `.clear` sends `{"shippingStatus":"<S>","trackingNumber":""}` (the empty string, never null);
//   - `.set(s)` sends the value; `.unchanged` sends only `shippingStatus` (the key is absent, not null);
//   - a tracking-only edit still carries the current status;
//   - PATCH /tracker/v2/purchases/{id}/shipping, and the id is never in the body.
//  The notes-only shapes of updatePurchase are pinned at the end (exact JSON).
//
//  The body is compared after re-serialising with sorted keys, so the assertion does not depend on
//  the encoder's key order. All data is fake.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseManagementRepository shipping and notes bodies", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseManagementShippingBodyTests {

    private let okBody = ManagementWire.purchaseEnvelope()

    private func rawBody(_ request: ListFakeTransport.Recorded) -> String {
        String(decoding: request.bodyData ?? Data(), as: UTF8.self)
    }

    private func sendShipping(_ update: PurchaseShippingUpdate, id: String = "purchase-1") async throws -> ListFakeTransport.Recorded {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)
        _ = try await sut.repo.updateShipping(id: id, update: update)
        return try await sut.lastRequest()
    }

    // MARK: Exact bodies

    @Test("a clear sends the empty string for trackingNumber, exactly")
    func clearBody() async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: .shipped, trackingChange: .clear))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"SHIPPED","trackingNumber":""}"#)
        #expect(!rawBody(request).contains("null"), "a clear must be \"\" on the wire, never null")
    }

    @Test("a set sends the value, exactly")
    func setBody() async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-FAKE-0001")))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"SHIPPED","trackingNumber":"TRK-FAKE-0001"}"#)
    }

    @Test("an unchanged tracking number sends only the status, exactly")
    func unchangedBody() async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: .delivered, trackingChange: .unchanged))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"DELIVERED"}"#)
    }

    @Test("when the tracking number is omitted the key is absent, not null")
    func omittedKeyIsAbsent() async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: .notShipped, trackingChange: .unchanged))

        #expect(request.jsonObject?["trackingNumber"] == nil)
        #expect(!rawBody(request).contains("trackingNumber"))
        #expect(!rawBody(request).contains("null"))
    }

    @Test("a status change together with a clear sends both in one body")
    func statusChangeWithClear() async throws {
        let update = PurchaseShippingUpdate.make(
            originalStatus: .shipped, originalTracking: "TRK-FAKE-0001",
            editedStatus: .delivered, editedTracking: ""
        )

        let request = try await sendShipping(try #require(update))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"DELIVERED","trackingNumber":""}"#)
    }

    @Test("a tracking-only clear built from the edit still carries the current status")
    func trackingOnlyClearCarriesStatus() async throws {
        let update = PurchaseShippingUpdate.make(
            originalStatus: .shipped, originalTracking: "TRK-FAKE-0001",
            editedStatus: .shipped, editedTracking: "   "
        )

        let request = try await sendShipping(try #require(update))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"SHIPPED","trackingNumber":""}"#)
    }

    @Test("a tracking-only set built from the edit still carries the current status")
    func trackingOnlySetCarriesStatus() async throws {
        let update = PurchaseShippingUpdate.make(
            originalStatus: .delivered, originalTracking: nil,
            editedStatus: .delivered, editedTracking: "  TRK-FAKE-0002  "
        )

        let request = try await sendShipping(try #require(update))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"DELIVERED","trackingNumber":"TRK-FAKE-0002"}"#)
    }

    @Test("a clear carries the status in its wire form for every status",
          arguments: [
        (PurchaseShippingStatus.notTracked, "NOT_TRACKED"), (PurchaseShippingStatus.notShipped, "NOT_SHIPPED"),
        (PurchaseShippingStatus.shipped, "SHIPPED"), (PurchaseShippingStatus.delivered, "DELIVERED")
    ])
    func clearPerStatus(pair: (PurchaseShippingStatus, String)) async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: pair.0, trackingChange: .clear))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"\#(pair.1)","trackingNumber":""}"#)
    }

    @Test("a clear carries no notes and the id is never in the body")
    func noNotesNoId() async throws {
        let request = try await sendShipping(PurchaseShippingUpdate(status: .shipped, trackingChange: .clear), id: "purchase-77")

        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["shippingStatus", "trackingNumber"])
        #expect(!rawBody(request).contains("purchase-77"))
        #expect(body["id"] == nil)
    }

    @Test("a clear is one PATCH to the shipping path with no query")
    func methodAndPath() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateShipping(
            id: "purchase-9", update: PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)
        )

        let request = try await sut.lastRequest()
        #expect(request.request.method == .patch)
        #expect(request.pathOnly == "/tracker/v2/purchases/purchase-9/shipping")
        #expect(request.hasQuery == false)
        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Representative errors of the shipping call, with the clear body

    private let clearUpdate = PurchaseShippingUpdate(status: .shipped, trackingChange: .clear)

    private func expectError(
        status: Int, body: String, _ expected: PurchaseManagementError
    ) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: status, json: body)

        await #expect(throws: expected) {
            _ = try await sut.repo.updateShipping(id: "purchase-1", update: clearUpdate)
        }
        let request = try await sut.lastRequest()
        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"SHIPPED","trackingNumber":""}"#)
    }

    @Test("clear: 400 keeps the server message as validation")
    func clearBadRequest() async throws {
        try await expectError(status: 400, body: ManagementWire.validationError,
                              .validation(message: "Notes must be at most 1000 characters"))
    }

    @Test("clear: 401 then a second 401 after one refresh is unauthorized and the replay resends the clear body")
    func clearUnauthorized() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 401, json: ListWire.tokenExpired, times: 2)

        await #expect(throws: PurchaseManagementError.unauthorized) {
            _ = try await sut.repo.updateShipping(id: "purchase-1", update: clearUpdate)
        }

        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        for request in requests {
            #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"shippingStatus":"SHIPPED","trackingNumber":""}"#)
        }
    }

    @Test("clear: 403 is forbidden")
    func clearForbidden() async throws {
        try await expectError(status: 403, body: ManagementWire.forbidden, .forbidden)
    }

    @Test("clear: 404 PURCHASE_NOT_FOUND is notFound, never forbidden")
    func clearNotFound() async throws {
        try await expectError(status: 404, body: ManagementWire.purchaseNotFound, .notFound)
    }

    @Test("clear: 429 carries Retry-After")
    func clearRateLimited() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 429, json: ListWire.rateLimit, retryAfter: "0.001", times: 3)

        await #expect(throws: PurchaseManagementError.rateLimited(retryAfter: 0.001)) {
            _ = try await sut.repo.updateShipping(id: "purchase-1", update: clearUpdate)
        }
    }

    @Test("clear: 500 is server")
    func clearServerError() async throws {
        try await expectError(status: 500, body: ListWire.internalError, .server)
    }

    @Test("clear: an undocumented status (418) is invalidResponse")
    func clearUndocumented() async throws {
        try await expectError(status: 418, body: ManagementWire.teapot, .invalidResponse)
    }

    @Test("clear: a transport failure is network")
    func clearTransportFailure() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueueThrow(URLError(.notConnectedToInternet))

        await #expect(throws: PurchaseManagementError.network) {
            _ = try await sut.repo.updateShipping(id: "purchase-1", update: clearUpdate)
        }
    }

    // MARK: updatePurchase (notes only), exact JSON

    private func sendNotes(_ change: PurchaseNotesChange) async throws -> ListFakeTransport.Recorded {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)
        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: change))
        return try await sut.lastRequest()
    }

    @Test("a notes set sends exactly {\"notes\":...} and no trackingNumber")
    func notesSetExact() async throws {
        let request = try await sendNotes(.set("Gift wrap please"))

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"notes":"Gift wrap please"}"#)
    }

    @Test("a notes clear sends exactly {\"notes\":\"\"}")
    func notesClearExact() async throws {
        let request = try await sendNotes(.clear)

        #expect(ManagementWire.canonicalBody(request.bodyData) == #"{"notes":""}"#)
        #expect(!rawBody(request).contains("null"))
    }

    @Test("an unchanged notes update sends exactly {}")
    func notesUnchangedExact() async throws {
        let request = try await sendNotes(.unchanged)

        #expect(ManagementWire.canonicalBody(request.bodyData) == "{}")
    }

    @Test("the notes call never has a trackingNumber key, whatever the change",
          arguments: [PurchaseNotesChange.set("A note"), PurchaseNotesChange.clear, PurchaseNotesChange.unchanged])
    func notesNeverHaveTracking(change: PurchaseNotesChange) async throws {
        let request = try await sendNotes(change)

        #expect(request.jsonObject?["trackingNumber"] == nil)
        #expect(!rawBody(request).contains("trackingNumber"))
    }
}
