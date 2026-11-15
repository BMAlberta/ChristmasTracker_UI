//
//  GeneratedClientPurchaseHistoryRequestTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC1: the REQUEST loadPage sends, seen through the real factory-built client and the
//  recording fake transport. One GET /tracker/v2/purchases, no body; year, recipientId, shippingStatus,
//  limit=20 and cursor are query keys exactly when set; listId and itemId are never sent; a nil filter
//  or a nil cursor puts no such key in the URL.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientPurchaseHistoryRepository request", .timeLimit(.minutes(1)))
struct GeneratedClientPurchaseHistoryRequestTests {

    private let okBody = PurchaseHistoryWire.envelope([PurchaseHistoryWire.rowJSON()], nextCursor: nil)

    private func dictionary(_ items: [URLQueryItem]) -> [String: String] {
        Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Method, path, headers

    @Test("one GET /tracker/v2/purchases with no body")
    func methodPathBody() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load()

        let request = try await sut.lastRequest()
        #expect(request.request.method == .get)
        #expect(request.pathOnly == "/tracker/v2/purchases")
        #expect((request.bodyData ?? Data()).isEmpty)
        #expect(await sut.transport.requestCount == 1)
    }

    @Test("the request carries the bearer token and the four client headers")
    func headers() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load()

        let fields = try await sut.lastRequest().request.headerFields
        #expect(fields[.authorization] == "Bearer \(purchaseHistoryAccessToken)")
        for name in ["X-Platform", "X-Build", "X-App-Version", "X-Client-Platform"] {
            let header = try #require(HTTPField.Name(name))
            #expect(fields[header]?.isEmpty == false, "missing \(name)")
        }
        let clientPlatform = try #require(HTTPField.Name("X-Client-Platform"))
        #expect(fields[clientPlatform] == "ios")
    }

    // MARK: The default request

    @Test("the default filter with no cursor sends only limit=20")
    func defaultRequestSendsOnlyLimit() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load(PurchaseHistoryFilter(), cursor: nil)

        let request = try await sut.lastRequest()
        #expect(request.request.path == "/tracker/v2/purchases?limit=20")
        #expect(try await sut.lastQueryItems().map(\.name) == ["limit"])
    }

    // MARK: Every combination

    @Test("each filter combination, with and without a cursor, sends exactly its set keys",
          arguments: PurchaseHistoryFix.allFilterCombinations, [String?.none, "cursor-abc"])
    func everyCombination(filter: PurchaseHistoryFilter, cursor: String?) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load(filter, cursor: cursor)

        let items = try await sut.lastQueryItems()
        let query = dictionary(items)
        var expected: [String: String] = ["limit": "20"]
        if let year = filter.year { expected["year"] = String(year) }
        if let recipient = filter.recipientId { expected["recipientId"] = recipient }
        if let status = filter.shippingStatus {
            expected["shippingStatus"] = PurchaseHistoryFix.shippingPairs.first { $0.0 == status }?.2
        }
        if let cursor { expected["cursor"] = cursor }
        #expect(query == expected)
        #expect(items.count == expected.count, "no key is sent twice")
        #expect(query["listId"] == nil)
        #expect(query["itemId"] == nil)
        let path = try await sut.lastRequest().request.path ?? ""
        for absent in ["listId", "itemId"] {
            #expect(!path.contains(absent), "\(absent) must never be in the request line")
        }
        if filter.year == nil { #expect(!path.contains("year="), "all years sends no year") }
        if filter.recipientId == nil { #expect(!path.contains("recipientId")) }
        if filter.shippingStatus == nil { #expect(!path.contains("shippingStatus")) }
        if cursor == nil { #expect(!path.contains("cursor")) }
    }

    @Test("each shipping status is sent in its wire form", arguments: [0, 1, 2, 3])
    func shippingWireValues(index: Int) async throws {
        let pair = PurchaseHistoryFix.shippingPairs[index]
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load(PurchaseHistoryFilter(shippingStatus: pair.0))

        #expect(dictionary(try await sut.lastQueryItems())["shippingStatus"] == pair.2)
    }

    @Test("the year is sent as a decimal integer", arguments: [2026, 2000, 2100, 1000, 9999])
    func yearIsDecimal(year: Int) async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load(PurchaseHistoryFilter(year: year))

        #expect(dictionary(try await sut.lastQueryItems())["year"] == String(year))
    }

    @Test("an opaque base64 cursor arrives at the server unchanged")
    func cursorRoundTrips() async throws {
        let cursor = "eyJwIjoiMjAyNi0wMS0wNSIsImlkIjoiYWJjIn0="
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody)

        _ = try await sut.load(PurchaseHistoryFilter(), cursor: cursor)

        #expect(dictionary(try await sut.lastQueryItems())["cursor"] == cursor)
    }

    @Test("two calls send two independent requests, each with its own query")
    func callsAreIndependent() async throws {
        let sut = try makePurchaseHistorySUT()
        await sut.transport.enqueue(status: 200, json: okBody, times: 2)

        _ = try await sut.load(PurchaseHistoryFilter(year: 2025))
        _ = try await sut.load(PurchaseHistoryFilter(), cursor: "next-1")

        let paths = await sut.transport.recorded.map { $0.request.path ?? "" }
        #expect(paths.count == 2)
        #expect(paths.first?.contains("year=2025") == true)
        #expect(paths.last?.contains("year") == false, "the second call remembers nothing of the first")
        #expect(paths.last?.contains("cursor=next-1") == true)
    }
}
