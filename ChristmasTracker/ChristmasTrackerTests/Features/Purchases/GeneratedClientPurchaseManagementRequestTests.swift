//
//  GeneratedClientPurchaseManagementRequestTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-B: the REQUEST each management operation sends, seen through the real factory-built
//  client and the recording fake transport.
//
//  Rules under test (Gate 1 Story B interface item 2):
//   - getPurchase:            one GET /tracker/v2/purchases/{id}, no body, no query.
//   - updatePurchase:         one PATCH /tracker/v2/purchases/{id}; the body carries `notes` ONLY
//                             (set(s) -> s, clear -> "" and never null, unchanged -> `{}`);
//                             `trackingNumber` is NEVER in this body.
//   - updatePurchaseShipping: one PATCH /tracker/v2/purchases/{id}/shipping; `shippingStatus` always
//                             (wire value), `trackingNumber` only when the update carries it.
//   - deletePurchase:         one DELETE /tracker/v2/purchases/{id}, no body, no query.
//   - every request carries the bearer token and the four client headers; the id is the only
//     thing in the path besides the fixed segments.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseManagementRepository request", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseManagementRequestTests {

    private let okBody = ManagementWire.purchaseEnvelope()

    private func rawBody(_ request: ListFakeTransport.Recorded) -> String {
        String(decoding: request.bodyData ?? Data(), as: UTF8.self)
    }

    // MARK: Method, path, count

    @Test("each operation sends one request with the right method and path and no query",
          arguments: ManagementOp.allCases)
    func methodAndPath(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.run(op, id: "purchase-9")

        let request = try await sut.lastRequest()
        #expect(request.request.method == op.method)
        #expect(request.pathOnly == op.path("purchase-9"))
        #expect(request.hasQuery == false)
        #expect(await sut.transport.requestCount == 1)
    }

    @Test("the id in the call is the id in the path", arguments: ManagementOp.allCases, ["purchase-1", "purchase-abc-42"])
    func idIsInThePath(op: ManagementOp, id: String) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.run(op, id: id)

        let request = try await sut.lastRequest()
        #expect(request.pathOnly == op.path(id))
    }

    // MARK: Headers

    @Test("every operation sends the bearer token and the four client headers", arguments: ManagementOp.allCases)
    func headers(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.run(op)

        let fields = try await sut.lastRequest().request.headerFields
        #expect(fields[.authorization] == "Bearer \(managementAccessToken)")
        for name in ["X-Platform", "X-Build", "X-App-Version", "X-Client-Platform"] {
            let header = try #require(HTTPField.Name(name))
            #expect(fields[header]?.isEmpty == false, "missing \(name)")
        }
        let clientPlatform = try #require(HTTPField.Name("X-Client-Platform"))
        #expect(fields[clientPlatform] == "ios")
    }

    // MARK: No body

    @Test("getPurchase and deletePurchase send no body", arguments: [ManagementOp.get, .delete])
    func noBody(op: ManagementOp) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.run(op)

        let request = try await sut.lastRequest()
        #expect((request.bodyData ?? Data()).isEmpty, "unexpected body: \(rawBody(request))")
    }

    // MARK: updatePurchase (notes only)

    @Test("a notes set sends exactly the notes and nothing else")
    func notesSet() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .set("Gift wrap please")))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["notes"])
        #expect(body["notes"] as? String == "Gift wrap please")
        #expect(!rawBody(request).contains("null"))
    }

    @Test("a notes clear sends the empty string, never null")
    func notesClear() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .clear))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["notes"])
        #expect(body["notes"] as? String == "")
        #expect(!rawBody(request).contains("null"), "a clear must be \"\" on the wire, never null")
    }

    @Test("an unchanged notes update sends an empty object")
    func notesUnchanged() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .unchanged))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject, "the body must be a JSON object: \(rawBody(request))")
        #expect(body.isEmpty)
    }

    @Test("the notes call never carries trackingNumber, whatever the change",
          arguments: [PurchaseNotesChange.set("A note"), PurchaseNotesChange.clear, PurchaseNotesChange.unchanged])
    func notesNeverCarryTracking(change: PurchaseNotesChange) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: change))

        let request = try await sut.lastRequest()
        #expect(request.jsonObject?["trackingNumber"] == nil)
        #expect(!rawBody(request).contains("trackingNumber"))
        #expect(!rawBody(request).contains("shippingStatus"))
    }

    @Test("notes text crosses the wire unchanged, newlines and emoji included")
    func notesTextIsPreserved() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)
        let text = "Line one\nLine two \u{1F381} \"quoted\""

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .set(text)))

        let body = try #require(try await sut.lastRequest().jsonObject)
        #expect(body["notes"] as? String == text)
    }

    @Test("a notes text of exactly 1000 characters is sent whole")
    func notesAtTheLimit() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)
        let text = String(repeating: "n", count: 1000)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .set(text)))

        let body = try #require(try await sut.lastRequest().jsonObject)
        #expect((body["notes"] as? String)?.count == 1000)
    }

    // MARK: updatePurchaseShipping

    @Test("the shipping call always carries the status in its wire form, and no tracking number when the update has none",
          arguments: [
        (PurchaseShippingStatus.notTracked, "NOT_TRACKED"), (PurchaseShippingStatus.notShipped, "NOT_SHIPPED"),
        (PurchaseShippingStatus.shipped, "SHIPPED"), (PurchaseShippingStatus.delivered, "DELIVERED")
    ])
    func shippingStatusOnly(pair: (PurchaseShippingStatus, String)) async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateShipping(
            id: "purchase-1", update: PurchaseShippingUpdate(status: pair.0, trackingChange: .unchanged)
        )

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["shippingStatus"], "no trackingNumber key when the update has none")
        #expect(body["shippingStatus"] as? String == pair.1)
        #expect(!rawBody(request).contains("null"))
    }

    @Test("the shipping call carries the tracking number when the update has one")
    func shippingWithTracking() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateShipping(
            id: "purchase-1", update: PurchaseShippingUpdate(status: .shipped, trackingChange: .set("TRK-FAKE-0001"))
        )

        let body = try #require(try await sut.lastRequest().jsonObject)
        #expect(Set(body.keys) == ["shippingStatus", "trackingNumber"])
        #expect(body["shippingStatus"] as? String == "SHIPPED")
        #expect(body["trackingNumber"] as? String == "TRK-FAKE-0001")
    }

    @Test("the shipping call carries no notes")
    func shippingCarriesNoNotes() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.repo.updateShipping(
            id: "purchase-1", update: PurchaseShippingUpdate(status: .delivered, trackingChange: .set("TRK-FAKE-0002"))
        )

        #expect(try await sut.lastRequest().jsonObject?["notes"] == nil)
    }

    // MARK: Nothing is remembered between calls

    @Test("two calls in a row send two independent requests with their own bodies")
    func callsAreIndependent() async throws {
        let sut = try makePurchaseManagementSUT()
        await sut.transport.enqueue(status: 200, json: okBody, times: 2)

        _ = try await sut.repo.updateNotes(id: "purchase-1", update: PurchaseNotesUpdate(change: .set("First note")))
        _ = try await sut.repo.updateNotes(id: "purchase-2", update: PurchaseNotesUpdate(change: .clear))

        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        #expect(requests.first?.jsonObject?["notes"] as? String == "First note")
        #expect(requests.last?.jsonObject?["notes"] as? String == "")
        #expect(requests.last?.pathOnly == "/tracker/v2/purchases/purchase-2")
    }
}
