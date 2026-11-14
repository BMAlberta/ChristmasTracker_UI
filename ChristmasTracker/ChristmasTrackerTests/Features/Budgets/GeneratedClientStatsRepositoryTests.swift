//
//  GeneratedClientStatsRepositoryTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: the 200 outcomes of getStats through the REAL factory-built client with a fake
//  transport and guide-accurate literal JSON (client guide 7.8, full `meta`).
//
//  Rules under test:
//   - a 200 year body maps through `mapStatsYear`: every field, the budget block, the spend rows;
//   - `budget: null` maps to nil and an empty `spendByRecipient` to an empty list;
//   - money is an exact Decimal (79.99, 0.01, 999999.99), never a drifting Double;
//   - a 200 whose scope is "all" is `.invalidResponse` (a year request never accepts it);
//   - a 200 body that cannot be read is `.invalidResponse`;
//   - the request is GET /tracker/v2/stats with the year as a decimal string and no body.
//
//  These tests do not compile until the implementer adds StatsLoading and GeneratedClientStatsRepository.
//

import Foundation
import HTTPTypes
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientStatsRepository", .timeLimit(.minutes(1)))
struct GeneratedClientStatsRepositoryTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    // MARK: 200 year scope

    @Test("200 with a budget maps every field of the year, the spend rows and the budget block")
    func okWithBudget() async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.statsYearJSON(
            year: 2026, totalSpent: "850", itemsPurchased: 12, purchaseCount: 9,
            spend: [
                BudgetWire.SpendSpec(recipientId: "user-t", name: "Tommy", spent: "450.5", items: 7),
                BudgetWire.SpendSpec(recipientId: "user-m", name: "Mike", spent: "399.5", items: 5)
            ],
            budget: BudgetWire.StatsBudgetSpec(
                total: "1000", spent: "850", remaining: "150",
                recipients: [BudgetWire.StatsRecipientSpec(
                    recipientId: "user-t", name: "Tommy", budget: "400", spent: "450.5", remaining: "-50.5"
                )]
            ),
            availableYears: [2024, 2025, 2026]
        )
        await sut.transport.enqueue(status: 200, json: BudgetWire.statsEnvelope(body))

        let stats = try await sut.stats.yearStats(year: 2026)

        #expect(stats.year == 2026)
        #expect(stats.totalSpent == dec("850"))
        #expect(stats.itemsPurchased == 12)
        #expect(stats.purchaseCount == 9)
        #expect(stats.availableYears == [2024, 2025, 2026])
        #expect(stats.spendByRecipient == [
            RecipientSpend(recipientId: "user-t", displayName: "Tommy", spent: dec("450.5"), itemsPurchased: 7),
            RecipientSpend(recipientId: "user-m", displayName: "Mike", spent: dec("399.5"), itemsPurchased: 5)
        ])
        #expect(stats.budget == StatsBudget(
            totalBudget: dec("1000"), totalSpent: dec("850"), remaining: dec("150"),
            recipients: [StatsRecipientBudget(
                recipientId: "user-t", displayName: "Tommy", budget: dec("400"), spent: dec("450.5"), remaining: dec("-50.5")
            )]
        ))
    }

    @Test("200 with budget null maps the budget to nil and keeps the spend rows")
    func okWithoutBudget() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: 200, json: BudgetWire.statsEnvelope(BudgetWire.statsYearJSON(budget: nil))
        )

        let stats = try await sut.stats.yearStats(year: 2026)

        #expect(stats.budget == nil)
        #expect(stats.spendByRecipient.count == 1)
        #expect(stats.totalSpent == dec("850"))
    }

    @Test("200 with no spend rows and no budget maps an empty year")
    func okEmptyYear() async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.statsYearJSON(
            totalSpent: "0", itemsPurchased: 0, purchaseCount: 0, spend: [], budget: nil, availableYears: []
        )
        await sut.transport.enqueue(status: 200, json: BudgetWire.statsEnvelope(body))

        let stats = try await sut.stats.yearStats(year: 2026)

        #expect(stats.spendByRecipient.isEmpty)
        #expect(stats.budget == nil)
        #expect(stats.totalSpent == 0)
        #expect(stats.itemsPurchased == 0)
        #expect(stats.purchaseCount == 0)
        #expect(stats.availableYears.isEmpty)
    }

    @Test("200 with a budget that has no recipient rows maps an empty recipient list")
    func okBudgetWithoutRecipients() async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.statsYearJSON(budget: BudgetWire.StatsBudgetSpec(recipients: []))
        await sut.transport.enqueue(status: 200, json: BudgetWire.statsEnvelope(body))

        let stats = try await sut.stats.yearStats(year: 2026)

        #expect(stats.budget?.recipients.isEmpty == true)
        #expect(stats.budget?.totalBudget == dec("1000"))
    }

    @Test("The returned year is the year of the body, not an invented one")
    func yearComesFromTheBody() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: 200, json: BudgetWire.statsEnvelope(BudgetWire.statsYearJSON(year: 2031))
        )

        let stats = try await sut.stats.yearStats(year: 2031)

        #expect(stats.year == 2031)
    }

    // MARK: Money

    @Test("Money crosses the boundary as an exact Decimal", arguments: ["79.99", "0.01", "999999.99", "0", "10", "0.5", "19.9"])
    func moneyIsExactDecimal(text: String) async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.statsYearJSON(
            totalSpent: text,
            spend: [BudgetWire.SpendSpec(spent: text)],
            budget: BudgetWire.StatsBudgetSpec(
                total: text, spent: text, remaining: text,
                recipients: [BudgetWire.StatsRecipientSpec(budget: text, spent: text, remaining: text)]
            )
        )
        await sut.transport.enqueue(status: 200, json: BudgetWire.statsEnvelope(body))

        let stats = try await sut.stats.yearStats(year: 2026)

        #expect(stats.totalSpent == dec(text))
        #expect(stats.spendByRecipient.first?.spent == dec(text))
        #expect(stats.budget?.totalBudget == dec(text))
        #expect(stats.budget?.totalSpent == dec(text))
        #expect(stats.budget?.remaining == dec(text))
        #expect(stats.budget?.recipients.first?.budget == dec(text))
        #expect(stats.budget?.recipients.first?.spent == dec(text))
        #expect(stats.budget?.recipients.first?.remaining == dec(text))
    }

    // MARK: Scope all and unreadable bodies

    @Test("a 200 whose scope is all throws invalidResponse")
    func scopeAllIsInvalid() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.statsEnvelope(BudgetWire.statsAllJSON))

        await #expect(throws: BudgetError.invalidResponse) {
            _ = try await sut.stats.yearStats(year: 2026)
        }
    }

    @Test("a 200 whose body cannot be read throws invalidResponse", arguments: [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": { \"scope\": \"year\", \"year\": 2026 }, \"meta\": \(ListWire.metaJSON) }",
        "{ \"success\": true, \"data\": { \"scope\": \"quarter\" }, \"meta\": \(ListWire.metaJSON) }"
    ])
    func unreadableOkBody(body: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: body)

        await #expect(throws: BudgetError.invalidResponse) {
            _ = try await sut.stats.yearStats(year: 2026)
        }
    }

    @Test("a 200 with no body at all throws invalidResponse")
    func emptyOkBody() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueEmpty(status: 200)

        await #expect(throws: BudgetError.invalidResponse) {
            _ = try await sut.stats.yearStats(year: 2026)
        }
    }

    // MARK: Request

    @Test("the request is one GET /tracker/v2/stats with the year as a decimal string and no body",
          arguments: [2026, 2000, 2100, 2031])
    func requestShape(year: Int) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: 200, json: BudgetWire.statsEnvelope(BudgetWire.statsYearJSON(year: year))
        )

        _ = try await sut.stats.yearStats(year: year)

        let request = try await sut.lastRequest()
        #expect(request.request.method == .get)
        #expect(request.pathOnly == "/tracker/v2/stats")
        #expect(request.request.path == "/tracker/v2/stats?year=\(year)", "the year is the decimal string, nothing else")
        #expect((request.bodyData ?? Data()).isEmpty)
        #expect(await sut.transport.requestCount == 1)
    }

    @Test("the request carries the bearer token and the four client headers")
    func headers() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetOp.stats.okBody)

        _ = try await sut.stats.yearStats(year: 2026)

        let fields = try await sut.lastRequest().request.headerFields
        #expect(fields[.authorization] == "Bearer \(budgetAccessToken)")
        for name in ["X-Platform", "X-Build", "X-App-Version", "X-Client-Platform"] {
            let header = try #require(HTTPField.Name(name))
            #expect(fields[header]?.isEmpty == false, "missing \(name)")
        }
    }

    @Test("two calls send two independent requests, each with its own year")
    func callsAreIndependent() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetOp.stats.okBody, times: 2)

        _ = try await sut.stats.yearStats(year: 2025)
        _ = try await sut.stats.yearStats(year: 2026)

        let requests = await sut.transport.recorded
        #expect(requests.map { $0.request.path } == ["/tracker/v2/stats?year=2025", "/tracker/v2/stats?year=2026"])
    }
}
