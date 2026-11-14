//
//  GeneratedClientBudgetRequestTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: the REQUEST each budget operation sends, seen through the real factory-built client
//  and the recording fake transport. Request bodies are decoded and the KEY SET is asserted exactly.
//
//  Rules under test (Gate 1 Story B interface):
//   - listBudgets GET /budgets, getBudget GET /budgets/{year}, deleteBudget DELETE /budgets/{year}:
//     no body, no query;
//   - createBudget POST /budgets: the body carries year, totalBudget and recipients (an EMPTY array
//     when there are none) and nothing else;
//   - updateBudget PATCH /budgets/{year}: only the non-nil fields are sent (total only: only
//     totalBudget; recipients only: only recipients, the full list; both: both; the year is only in
//     the path, never in the body);
//   - duplicateBudget POST /budgets/{from}/duplicate: the body carries toYear only;
//   - money is a JSON number with at most two decimals, never a string, never IEEE drift;
//   - every request carries the bearer token and the four client headers.
//
//  All ids and names are fake.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientBudgetRepository request", .timeLimit(.minutes(1)))
struct GeneratedClientBudgetRequestTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    private func limit(_ id: String, _ amount: String) -> BudgetLimit {
        BudgetLimit(recipientId: id, maxSpend: dec(amount))
    }

    private func limits(_ body: [String: Any]?) -> [[String: Any]] {
        (body?["recipients"] as? [[String: Any]]) ?? []
    }

    // MARK: Method, path, count

    @Test("each operation sends one request with the right method and path", arguments: BudgetOp.allCases)
    func methodAndPath(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await sut.run(op)

        let request = try await sut.lastRequest()
        #expect(request.request.method == op.method)
        #expect(request.pathOnly == op.path())
        #expect(await sut.transport.requestCount == 1)
    }

    @Test("the year of getBudget and deleteBudget is the year in the path", arguments: [BudgetOp.get, .delete], [2000, 2029, 2100])
    func yearIsInThePath(op: BudgetOp, year: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await op.call(sut, year: year)

        #expect(try await sut.lastRequest().pathOnly == "/tracker/v2/budgets/\(year)")
    }

    @Test("every operation except the stats read carries no query string",
          arguments: [BudgetOp.list, .get, .create, .update, .delete, .duplicate])
    func noQuery(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await sut.run(op)

        #expect(try await sut.lastRequest().hasQuery == false)
    }

    @Test("every operation sends the bearer token and the four client headers", arguments: BudgetOp.allCases)
    func headers(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await sut.run(op)

        let fields = try await sut.lastRequest().request.headerFields
        #expect(fields[.authorization] == "Bearer \(budgetAccessToken)")
        for name in ["X-Platform", "X-Build", "X-App-Version", "X-Client-Platform"] {
            let header = try #require(HTTPField.Name(name))
            #expect(fields[header]?.isEmpty == false, "missing \(name)")
        }
        let clientPlatform = try #require(HTTPField.Name("X-Client-Platform"))
        #expect(fields[clientPlatform] == "ios")
    }

    @Test("the operations without a request body send none",
          arguments: [BudgetOp.stats, .list, .get, .delete])
    func noBody(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: op.okBody)

        try await sut.run(op)

        let request = try await sut.lastRequest()
        #expect((request.bodyData ?? Data()).isEmpty, "unexpected body: \(BudgetWire.rawBody(request))")
    }

    // MARK: createBudget

    @Test("create sends year, totalBudget and recipients, and nothing else")
    func createKeySet() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.create(CreateBudgetRequest(
            year: 2027, totalBudget: dec("1000"), recipients: [limit("user-t", "400"), limit("user-m", "100.5")]
        ))

        let body = try #require(try await sut.lastRequest().jsonObject)
        #expect(Set(body.keys) == ["year", "totalBudget", "recipients"])
        #expect(body["year"] as? Int == 2027)
        #expect(body["totalBudget"] as? Double == 1000)
        let rows = limits(body)
        #expect(rows.map { $0["recipientId"] as? String } == ["user-t", "user-m"], "draft order is kept")
        #expect(rows.map { $0["maxSpend"] as? Double } == [400, 100.5])
        #expect(rows.allSatisfy { Set($0.keys) == ["recipientId", "maxSpend"] })
    }

    @Test("create with no limits sends an EMPTY recipients array, never null and never a missing key")
    func createEmptyRecipients() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope(BudgetWire.budgetJSON(recipients: [])))

        _ = try await sut.budgets.create(CreateBudgetRequest(year: 2027, totalBudget: dec("250"), recipients: []))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["year", "totalBudget", "recipients"])
        let array = try #require(body["recipients"] as? [Any], "recipients must be a JSON array")
        #expect(array.isEmpty)
        #expect(!BudgetWire.rawBody(request).contains("null"))
    }

    @Test("create carries no offList, no id and no other field a budget does not have")
    func createHasNoExtraKeys() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.create(BudgetOp.defaultCreate)

        let raw = BudgetWire.rawBody(try await sut.lastRequest())
        for forbidden in ["offList", "\"id\"", "toYear", "totalSpent", "createdAt"] {
            #expect(!raw.contains(forbidden), "unexpected \(forbidden) in \(raw)")
        }
    }

    // MARK: updateBudget

    @Test("update with only the total sends only totalBudget")
    func updateTotalOnly() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.update(UpdateBudgetRequest(year: 2026, totalBudget: dec("1200"), recipients: nil))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["totalBudget"])
        #expect(body["totalBudget"] as? Double == 1200)
        #expect(request.pathOnly == "/tracker/v2/budgets/2026")
        #expect(!BudgetWire.rawBody(request).contains("null"), "a nil field is omitted, never sent as null")
    }

    @Test("update with only recipients sends only recipients, the full list")
    func updateRecipientsOnly() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.update(UpdateBudgetRequest(
            year: 2026, totalBudget: nil, recipients: [limit("user-t", "500"), limit("user-j", "250")]
        ))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["recipients"])
        let rows = limits(body)
        #expect(rows.map { $0["recipientId"] as? String } == ["user-t", "user-j"])
        #expect(rows.map { $0["maxSpend"] as? Double } == [500, 250])
        #expect(!BudgetWire.rawBody(request).contains("null"))
    }

    @Test("update with an empty recipients list sends an empty array (clears the allocation) and no total")
    func updateEmptyRecipients() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.update(UpdateBudgetRequest(year: 2026, totalBudget: nil, recipients: []))

        let body = try #require(try await sut.lastRequest().jsonObject)
        #expect(Set(body.keys) == ["recipients"])
        #expect((body["recipients"] as? [Any])?.isEmpty == true)
    }

    @Test("update with both fields sends both and never the year")
    func updateBothFields() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetEnvelope())

        _ = try await sut.budgets.update(UpdateBudgetRequest(
            year: 2028, totalBudget: dec("900"), recipients: [limit("user-t", "300")]
        ))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["totalBudget", "recipients"])
        #expect(request.pathOnly == "/tracker/v2/budgets/2028", "the year travels in the path")
        #expect(request.request.method == .patch)
    }

    // MARK: duplicateBudget

    @Test("duplicate sends only toYear and puts the source year in the path")
    func duplicateKeySet() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope(BudgetWire.budgetJSON(year: 2028)))

        _ = try await sut.budgets.duplicate(DuplicateBudgetRequest(fromYear: 2026, toYear: 2028))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        #expect(Set(body.keys) == ["toYear"])
        #expect(body["toYear"] as? Int == 2028)
        #expect(request.pathOnly == "/tracker/v2/budgets/2026/duplicate")
        #expect(request.request.method == .post)
    }

    // MARK: Money encoding

    @Test("money is encoded as a JSON number with at most two decimals",
          arguments: ["79.99", "0.01", "999999.99", "0", "10", "0.5", "19.9", "1234.56", "0.1"])
    func moneyEncoding(text: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope())
        let amount = dec(text)

        _ = try await sut.budgets.create(CreateBudgetRequest(
            year: 2027, totalBudget: amount, recipients: [BudgetLimit(recipientId: "user-t", maxSpend: amount)]
        ))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        let raw = BudgetWire.rawBody(request)
        let expected = (text as NSString).doubleValue
        #expect(body["totalBudget"] is NSNumber, "money is a number, not a string")
        #expect(body["totalBudget"] as? Double == expected, "\(text) must not drift")
        #expect(limits(body).first?["maxSpend"] as? Double == expected)
        #expect(raw.range(of: #"\d+\.\d{3,}"#, options: .regularExpression) == nil, "more than two decimals in \(raw)")
        #expect(!raw.contains("e-") && !raw.contains("E-"), "exponent notation in \(raw)")
    }

    @Test("a limit and a total sent through update are numbers with at most two decimals too",
          arguments: ["79.99", "0.01", "999999.99"])
    func updateMoneyEncoding(text: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetEnvelope())
        let amount = dec(text)

        _ = try await sut.budgets.update(UpdateBudgetRequest(
            year: 2026, totalBudget: amount, recipients: [BudgetLimit(recipientId: "user-t", maxSpend: amount)]
        ))

        let request = try await sut.lastRequest()
        let body = try #require(request.jsonObject)
        let expected = (text as NSString).doubleValue
        #expect(body["totalBudget"] as? Double == expected)
        #expect(limits(body).first?["maxSpend"] as? Double == expected)
        #expect(BudgetWire.rawBody(request).range(of: #"\d+\.\d{3,}"#, options: .regularExpression) == nil)
    }

    // MARK: Nothing is remembered between calls

    @Test("two calls in a row send two independent requests with their own bodies")
    func callsAreIndependent() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 201, json: BudgetWire.budgetEnvelope(), times: 2)

        _ = try await sut.budgets.create(CreateBudgetRequest(year: 2027, totalBudget: dec("100"), recipients: []))
        _ = try await sut.budgets.duplicate(DuplicateBudgetRequest(fromYear: 2027, toYear: 2028))

        let requests = await sut.transport.recorded
        #expect(requests.count == 2)
        #expect(Set((requests.first?.jsonObject ?? [:]).keys) == ["year", "totalBudget", "recipients"])
        #expect(Set((requests.last?.jsonObject ?? [:]).keys) == ["toYear"])
        #expect(requests.last?.pathOnly == "/tracker/v2/budgets/2027/duplicate")
    }
}
