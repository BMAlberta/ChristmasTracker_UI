//
//  GeneratedClientPurchaseRequestTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-B: the REQUEST that GeneratedClientPurchaseRepository.createPurchase sends, seen
//  through the real factory-built client and the recording fake transport.
//
//  Rules under test:
//   - POST /tracker/v2/items/{itemId}/purchases, no query string, one request per call.
//   - The body is exactly the draft: quantity and totalCost always; storeName, notes,
//     confirmationNumber and trackingNumber only when non-nil (nil optionals are ABSENT, not null).
//   - confirmationToken is present only when the argument is non-nil (the resubmit); a first
//     request has no confirmationToken key, and a request after a resubmit has none again.
//   - totalCost is a JSON number with at most two decimals (79.99, 10, 0.5), converted through
//     decimalToDouble; there is no offList field.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseRepository request", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseRequestTests {

    private let createdBody = PurchaseWire.createdEnvelope()

    private func lastRequest(_ sut: PurchaseRepoSUT) async throws -> ListFakeTransport.Recorded {
        try #require(await sut.transport.lastRequest(), "no request reached the transport")
    }

    // MARK: Method, path, count

    @Test("createPurchase sends one POST to /tracker/v2/items/{itemId}/purchases with no query")
    func methodAndPath() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create(itemId: "item-9")

        let request = try await lastRequest(sut)
        #expect(request.request.method == .post)
        #expect(request.pathOnly == "/tracker/v2/items/item-9/purchases")
        #expect(request.hasQuery == false)
        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Body keys

    @Test("A minimal first request carries exactly quantity and totalCost, no token and no null keys")
    func minimalBodyHasOnlyTheRequiredKeys() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create(draft: PurchaseFixtures.draft(quantity: 2, totalCost: "25.50"), token: nil)

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(Set(body.keys) == ["quantity", "totalCost"])
        #expect(body["quantity"] as? Int == 2)
        #expect(body["confirmationToken"] == nil)
    }

    @Test("A request with every optional field carries exactly the draft's six fields")
    func fullBodyCarriesTheDraft() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)
        let draft = PurchaseFixtures.draft(
            quantity: 3, totalCost: "79.99", storeName: "Fake Store", notes: "Gift wrap please",
            confirmationNumber: "CONF-1", trackingNumber: "TRK-1"
        )

        _ = try await sut.create(draft: draft)

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(Set(body.keys) == ["quantity", "totalCost", "storeName", "notes", "confirmationNumber", "trackingNumber"])
        #expect(body["quantity"] as? Int == 3)
        #expect(body["storeName"] as? String == "Fake Store")
        #expect(body["notes"] as? String == "Gift wrap please")
        #expect(body["confirmationNumber"] as? String == "CONF-1")
        #expect(body["trackingNumber"] as? String == "TRK-1")
    }

    @Test("Nil optionals are omitted from the JSON, not sent as null", arguments: [
        ("storeName", PurchaseFixtures.draft(storeName: "Fake Store")),
        ("notes", PurchaseFixtures.draft(notes: "A note")),
        ("confirmationNumber", PurchaseFixtures.draft(confirmationNumber: "CONF-1")),
        ("trackingNumber", PurchaseFixtures.draft(trackingNumber: "TRK-1"))
    ])
    func onlyTheSetOptionalIsSent(key: String, draft: PurchaseDraft) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create(draft: draft)

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(Set(body.keys) == ["quantity", "totalCost", key])
        let raw = String(decoding: try #require(try await lastRequest(sut).bodyData), as: UTF8.self)
        #expect(!raw.contains("null"), "nil optionals must be absent, not null")
    }

    @Test("The request has no offList field")
    func noOffListField() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create()

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(body["offList"] == nil)
    }

    // MARK: Token

    @Test("The resubmit carries the confirmation token and the same draft fields")
    func resubmitCarriesTheToken() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)
        let draft = PurchaseFixtures.draft(quantity: 1, totalCost: "349.99", storeName: "Best Buy")

        _ = try await sut.create(draft: draft, token: PurchaseWire.token)

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(body["confirmationToken"] as? String == PurchaseWire.token)
        #expect(Set(body.keys) == ["quantity", "totalCost", "storeName", "confirmationToken"])
        #expect(body["quantity"] as? Int == 1)
        #expect(body["storeName"] as? String == "Best Buy")
    }

    @Test("A call after a resubmit goes out without the token again (the repository keeps none)")
    func tokenIsNotRemembered() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody, times: 2)
        let draft = PurchaseFixtures.draft()

        _ = try await sut.create(draft: draft, token: PurchaseWire.token)
        _ = try await sut.create(draft: draft, token: nil)

        let recorded = await sut.transport.recorded
        #expect(recorded.count == 2)
        #expect(recorded.first?.jsonObject?["confirmationToken"] as? String == PurchaseWire.token)
        #expect(recorded.last?.jsonObject?["confirmationToken"] == nil)
        let secondRaw = String(decoding: recorded.last?.bodyData ?? Data(), as: UTF8.self)
        #expect(!secondRaw.contains(PurchaseWire.token))
    }

    // MARK: Money in the request

    private func rawBody(_ sut: PurchaseRepoSUT) async throws -> String {
        String(decoding: try #require(try await lastRequest(sut).bodyData), as: UTF8.self)
    }

    @Test("totalCost is a JSON number with at most two decimals", arguments: [
        ("79.99", "79\\.99"), ("10", "10(\\.0)?"), ("0.5", "0\\.5"), ("0.01", "0\\.01"),
        ("999999.99", "999999\\.99"), ("12.5", "12\\.5")
    ])
    func totalCostIsATwoDecimalNumber(amount: String, pattern: String) async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create(draft: PurchaseFixtures.draft(totalCost: amount))

        let raw = try await rawBody(sut)
        let regex = try NSRegularExpression(pattern: "\"totalCost\"\\s*:\\s*\(pattern)(?![0-9])")
        let found = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw))
        #expect(found != nil, "totalCost for \(amount) was not written as a clean number: \(raw)")
    }

    @Test("totalCost is a number, not a string")
    func totalCostIsNotAString() async throws {
        let sut = try makePurchaseRepoSUT()
        await sut.transport.enqueue(status: 201, json: createdBody)

        _ = try await sut.create(draft: PurchaseFixtures.draft(totalCost: "79.99"))

        let body = try #require(try await lastRequest(sut).jsonObject)
        #expect(!(body["totalCost"] is String))
        #expect((body["totalCost"] as? Double) == 79.99)
    }
}
