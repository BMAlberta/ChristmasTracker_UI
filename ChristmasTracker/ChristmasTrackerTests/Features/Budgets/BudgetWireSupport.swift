//
//  BudgetWireSupport.swift
//  ChristmasTrackerTests
//
//  I5a Story B: shared support for the stats and budget repository tests.
//
//  - `BudgetWire`: literal, guide-accurate JSON (client guide 4, 5.4, 7.8, 7.9): the success envelope
//    `{success, data, meta}` with the FULL `meta` object, the year stats body (with and without a
//    budget, with and without spend rows), the all-time stats body, the Budget body (with and without
//    recipients) and the error envelope for every documented code. Money is written as a literal JSON
//    number so the tests prove the exact Decimal that comes out.
//  - `BudgetOp`: the seven operations, so one test can run against each of them.
//  - `makeBudgetWireSUT`: the REAL `TrackerClientFactory.make` client around the recording fake
//    transport (`ListFakeTransport`), wrapped by both repositories under test.
//
//  Construction assumption (the Story B interface signatures):
//      GeneratedClientStatsRepository(client: client)
//      GeneratedClientBudgetRepository(client: client)
//
//  All ids, names and amounts are fake.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
import TrackerAPI
@testable import ChristmasTracker

// MARK: - Wire fixtures

nonisolated enum BudgetWire {

    /// The year every operation targets unless a test says otherwise.
    static let year = 2026

    // MARK: Budget body

    struct RecipientSpec: Sendable {
        var id = "rb-1"
        var recipientId = "user-t"
        var name = "Tommy"
        var maxSpend = "200"
        var spent = "79.99"
        var remaining = "120.01"
        var isOver = false
        var overage = "0"

        var json: String {
            """
            { "id": "\(id)", "recipientId": "\(recipientId)", "recipientName": "\(name)", \
            "maxSpend": \(maxSpend), "spent": \(spent), "remaining": \(remaining), \
            "isOverBudget": \(isOver), "overage": \(overage) }
            """
        }
    }

    static let tommy = RecipientSpec()
    static let mike = RecipientSpec(
        id: "rb-2", recipientId: "user-m", name: "Mike", maxSpend: "100", spent: "0.01",
        remaining: "99.99", isOver: false, overage: "0"
    )
    static let overJohn = RecipientSpec(
        id: "rb-3", recipientId: "user-j", name: "John", maxSpend: "600", spent: "619.98",
        remaining: "-19.98", isOver: true, overage: "19.98"
    )

    /// One Budget body (the `data` of getBudget, createBudget, updateBudget, duplicateBudget).
    static func budgetJSON(
        id: String = "budget-1",
        year: Int = BudgetWire.year,
        total: String = "1000",
        spent: String = "79.99",
        remaining: String = "920.01",
        isOver: Bool = false,
        recipients: [RecipientSpec] = [tommy, mike]
    ) -> String {
        """
        { "id": "\(id)", "year": \(year), "totalBudget": \(total), "totalSpent": \(spent), \
        "remaining": \(remaining), "isOverBudget": \(isOver), \
        "recipients": [\(recipients.map(\.json).joined(separator: ", "))], \
        "createdAt": "2026-01-05T08:30:00.000Z", "updatedAt": "2026-01-06T09:00:00.000Z" }
        """
    }

    static let createdAt = PurchaseWire.date("2026-01-05T08:30:00.000Z")
    static let updatedAt = PurchaseWire.date("2026-01-06T09:00:00.000Z")

    static func budgetEnvelope(_ budget: String = budgetJSON()) -> String {
        ListWire.success(data: budget)
    }

    static func budgetsEnvelope(_ budgets: [String]) -> String {
        ListWire.success(data: "[" + budgets.joined(separator: ", ") + "]")
    }

    /// The 200 body of deleteBudget: only a message.
    static let deletedEnvelope = ListWire.messageJSON("Budget deleted successfully")

    // MARK: Stats body

    struct SpendSpec: Sendable {
        var recipientId = "user-t"
        var name = "Tommy"
        var spent = "450.5"
        var items = 7

        var json: String {
            """
            { "recipientId": "\(recipientId)", "displayName": "\(name)", "spent": \(spent), \
            "itemsPurchased": \(items) }
            """
        }
    }

    struct StatsRecipientSpec: Sendable {
        var recipientId = "user-t"
        var name = "Tommy"
        var budget = "400"
        var spent = "450.5"
        var remaining = "-50.5"

        var json: String {
            """
            { "recipientId": "\(recipientId)", "displayName": "\(name)", "budget": \(budget), \
            "spent": \(spent), "remaining": \(remaining) }
            """
        }
    }

    struct StatsBudgetSpec: Sendable {
        var total = "1000"
        var spent = "850"
        var remaining = "150"
        var recipients: [StatsRecipientSpec] = [StatsRecipientSpec()]

        var json: String {
            """
            { "totalBudget": \(total), "totalSpent": \(spent), "remaining": \(remaining), \
            "recipients": [\(recipients.map(\.json).joined(separator: ", "))] }
            """
        }
    }

    /// One StatsYearResponse body (scope "year"). `budget` nil is an explicit JSON null.
    static func statsYearJSON(
        year: Int = BudgetWire.year,
        totalSpent: String = "850",
        itemsPurchased: Int = 12,
        purchaseCount: Int = 9,
        spend: [SpendSpec] = [SpendSpec()],
        budget: StatsBudgetSpec? = StatsBudgetSpec(),
        availableYears: [Int] = [2025, 2026]
    ) -> String {
        """
        { "scope": "year", "year": \(year), "totalSpent": \(totalSpent), "itemsPurchased": \(itemsPurchased), \
        "purchaseCount": \(purchaseCount), "spendByRecipient": [\(spend.map(\.json).joined(separator: ", "))], \
        "budget": \(budget?.json ?? "null"), "availableYears": [\(availableYears.map(String.init).joined(separator: ", "))] }
        """
    }

    static func statsEnvelope(_ stats: String = statsYearJSON()) -> String {
        ListWire.success(data: stats)
    }

    /// A StatsAllResponse body (scope "all"), which a year request must never accept.
    static let statsAllJSON = """
    { "scope": "all", "totalSpent": 2500, "itemsPurchased": 30, "purchaseCount": 22, \
    "byYear": [ { "year": 2026, "totalSpent": 850, "itemsPurchased": 12, "purchaseCount": 9, "totalBudget": 1000 } ], \
    "availableYears": [2025, 2026] }
    """

    // MARK: Error bodies

    static let invalidPrice = ListWire.errorJSON(
        code: 3007, errorCode: "INVALID_PRICE", message: "Invalid price", details: "{ \"field\": \"totalBudget\" }"
    )
    static let validationError = ListWire.errorJSON(
        code: 3001, errorCode: "VALIDATION_ERROR", message: "Year must be between 2000 and 2100"
    )
    static let budgetNotFound = ListWire.errorJSON(
        code: 4007, errorCode: "BUDGET_NOT_FOUND", message: "Budget not found"
    )
    static let budgetAlreadyExists = ListWire.errorJSON(
        code: 5003, errorCode: "BUDGET_ALREADY_EXISTS", message: "Budget already exists"
    )
    static let sumExceedsTotal = ListWire.errorJSON(
        code: 6003, errorCode: "RECIPIENT_BUDGET_SUM_EXCEEDS_TOTAL", message: "Recipient budget sum exceeds total budget"
    )
    static let cannotDeleteWithPurchases = ListWire.errorJSON(
        code: 6004, errorCode: "CANNOT_DELETE_BUDGET_WITH_PURCHASES",
        message: "Cannot delete budget with existing purchases"
    )
    static let forbidden = ListWire.errorJSON(
        code: 2005, errorCode: "FORBIDDEN", message: "You do not have permission to do that"
    )
    static let accountDisabled = ListWire.errorJSON(
        code: 1008, errorCode: "ACCOUNT_DISABLED", message: "This account has been disabled"
    )
    static let userNotFound = ListWire.errorJSON(code: 4002, errorCode: "USER_NOT_FOUND", message: "User not found")
    static let teapot = ListWire.errorJSON(code: 9999, errorCode: "TEAPOT", message: "I am a teapot")

    /// The request body decoded as a JSON object with its raw text, for the exact key set assertions.
    static func rawBody(_ request: ListFakeTransport.Recorded) -> String {
        String(decoding: request.bodyData ?? Data(), as: UTF8.self)
    }
}

// MARK: - The seven operations

nonisolated enum BudgetOp: CaseIterable, Sendable, CustomTestStringConvertible {
    case stats, list, get, create, update, delete, duplicate

    var testDescription: String {
        switch self {
        case .stats: "getStats"
        case .list: "listBudgets"
        case .get: "getBudget"
        case .create: "createBudget"
        case .update: "updateBudget"
        case .delete: "deleteBudget"
        case .duplicate: "duplicateBudget"
        }
    }

    var method: HTTPRequest.Method {
        switch self {
        case .stats, .list, .get: .get
        case .create, .duplicate: .post
        case .update: .patch
        case .delete: .delete
        }
    }

    func path(year: Int = BudgetWire.year) -> String {
        switch self {
        case .stats: "/tracker/v2/stats"
        case .list, .create: "/tracker/v2/budgets"
        case .get, .update, .delete: "/tracker/v2/budgets/\(year)"
        case .duplicate: "/tracker/v2/budgets/\(year)/duplicate"
        }
    }

    /// The status a success carries (the two creating operations answer 201).
    var successStatus: Int {
        switch self {
        case .create, .duplicate: 201
        case .stats, .list, .get, .update, .delete: 200
        }
    }

    /// The success body for this operation.
    var okBody: String {
        switch self {
        case .stats: BudgetWire.statsEnvelope()
        case .list: BudgetWire.budgetsEnvelope([BudgetWire.budgetJSON()])
        case .get, .create, .update, .duplicate: BudgetWire.budgetEnvelope()
        case .delete: BudgetWire.deletedEnvelope
        }
    }

    /// Operations whose contract documents a 400.
    var documents400: Bool {
        switch self {
        case .stats, .create, .update, .duplicate: true
        case .list, .get, .delete: false
        }
    }

    /// Operations whose contract documents a 409.
    var documents409: Bool {
        switch self {
        case .create, .duplicate: true
        case .stats, .list, .get, .update, .delete: false
        }
    }

    /// Operations that document no 422 (an undocumented 422 is the sum rule for the three writes).
    var isSumRuleWrite: Bool {
        switch self {
        case .create, .update, .duplicate: true
        case .stats, .list, .get, .delete: false
        }
    }

    /// True when the operation carries a request body.
    var hasBody: Bool {
        switch self {
        case .create, .update, .duplicate: true
        case .stats, .list, .get, .delete: false
        }
    }

    /// Only a GET is retried by the rate limit middleware.
    var isRetriedOn429: Bool {
        switch self {
        case .stats, .list, .get: true
        case .create, .update, .delete, .duplicate: false
        }
    }

    static let defaultCreate = CreateBudgetRequest(
        year: BudgetWire.year, totalBudget: BudgetFixtures.dec("1000"),
        recipients: [BudgetLimit(recipientId: "user-t", maxSpend: BudgetFixtures.dec("400"))]
    )
    static let defaultUpdate = UpdateBudgetRequest(
        year: BudgetWire.year, totalBudget: BudgetFixtures.dec("1200"), recipients: nil
    )
    static let defaultDuplicate = DuplicateBudgetRequest(fromYear: BudgetWire.year, toYear: 2027)

    func call(_ sut: BudgetWireSUT, year: Int = BudgetWire.year) async throws {
        switch self {
        case .stats: _ = try await sut.stats.yearStats(year: year)
        case .list: _ = try await sut.budgets.listBudgets()
        case .get: _ = try await sut.budgets.budget(year: year)
        case .create: _ = try await sut.budgets.create(Self.defaultCreate)
        case .update: _ = try await sut.budgets.update(Self.defaultUpdate)
        case .delete: try await sut.budgets.delete(year: year)
        case .duplicate: _ = try await sut.budgets.duplicate(Self.defaultDuplicate)
        }
    }
}

// MARK: - SUT factory (real factory-built client, fake transport)

private let budgetRepoBaseURL: URL = {
    guard let url = URL(string: "https://api.example.com") else {
        preconditionFailure("fixture URL is invalid")
    }
    return url
}()

let budgetAccessToken = "tok-access-FAKE"

struct BudgetWireSUT {
    let stats: GeneratedClientStatsRepository
    let budgets: GeneratedClientBudgetRepository
    let transport: ListFakeTransport
    let refresher: ListFakeRefresher

    func run(_ op: BudgetOp) async throws {
        try await op.call(self)
    }

    /// Runs the operation and returns the BudgetError it threw (nil when it threw nothing or something else).
    func budgetError(_ op: BudgetOp) async -> BudgetError? {
        do {
            try await run(op)
            return nil
        } catch {
            return error as? BudgetError
        }
    }

    /// Runs the operation and returns whatever it threw.
    func thrown(_ op: BudgetOp) async -> (any Error)? {
        do {
            try await run(op)
            return nil
        } catch {
            return error
        }
    }

    func lastRequest() async throws -> ListFakeTransport.Recorded {
        guard let request = await transport.lastRequest() else {
            throw BudgetWireSUTError.noRequest
        }
        return request
    }
}

enum BudgetWireSUTError: Error {
    case noRequest
}

func makeBudgetWireSUT(
    token: String? = budgetAccessToken,
    refreshFailure: (any Error)? = nil
) throws -> BudgetWireSUT {
    let transport = ListFakeTransport()
    let refresher = ListFakeRefresher(failure: refreshFailure)
    let client = try TrackerClientFactory.make(
        serverURL: budgetRepoBaseURL,
        info: AppClientInfo(platform: "ios", clientPlatform: "ios", build: "1", version: "1.0.0"),
        tokenProvider: ListFakeTokenProvider(token: token),
        sessionRefresher: refresher,
        versionOutdatedHandler: ListFakeVersionHandler(),
        transport: transport
    )
    return BudgetWireSUT(
        stats: GeneratedClientStatsRepository(client: client),
        budgets: GeneratedClientBudgetRepository(client: client),
        transport: transport,
        refresher: refresher
    )
}
