//
//  GeneratedClientBudgetRepositoryTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: the success outcomes of listBudgets, getBudget, createBudget, updateBudget,
//  deleteBudget and duplicateBudget through the REAL factory-built client with a fake transport and
//  guide-accurate literal JSON (client guide 7.9, full `meta`).
//
//  Rules under test:
//   - a 200 or 201 Budget maps through `mapBudget`: every field and every recipient row;
//   - a budget with and without recipients, an empty list, a list with several budgets;
//   - money is an exact Decimal (79.99, 0.01, 999999.99);
//   - an over-budget recipient keeps its overage and its flag;
//   - deleteBudget returns nothing on a 200 and does not read the body;
//   - a success body that cannot be read is `.invalidResponse`.
//
//  Requests are in GeneratedClientBudgetRequestTests and every failure in GeneratedClientBudgetErrorTests.
//
//  These tests do not compile until the implementer adds BudgetManaging and GeneratedClientBudgetRepository.
//

import Foundation
import Testing
import TrackerAPI
@testable import ChristmasTracker

@Suite("GeneratedClientBudgetRepository", .timeLimit(.minutes(1)))
struct GeneratedClientBudgetRepositoryTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    /// The operations that return one Budget, with the status each answers.
    nonisolated static let budgetOps: [BudgetOp] = [.get, .create, .update, .duplicate]

    private func callReturningBudget(_ op: BudgetOp, _ sut: BudgetWireSUT) async throws -> Budget {
        switch op {
        case .get: return try await sut.budgets.budget(year: 2026)
        case .create: return try await sut.budgets.create(BudgetOp.defaultCreate)
        case .update: return try await sut.budgets.update(BudgetOp.defaultUpdate)
        case .duplicate: return try await sut.budgets.duplicate(BudgetOp.defaultDuplicate)
        case .stats, .list, .delete:
            throw BudgetWireSUTError.noRequest
        }
    }

    // MARK: A budget maps every field

    @Test("200 or 201 maps every field of a budget with recipients", arguments: budgetOps)
    func okMapsEveryField(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.budgetJSON(
            id: "budget-7", year: 2026, total: "1000", spent: "79.99", remaining: "920.01",
            recipients: [BudgetWire.tommy, BudgetWire.mike]
        )
        await sut.transport.enqueue(status: op.successStatus, json: BudgetWire.budgetEnvelope(body))

        let budget = try await callReturningBudget(op, sut)

        #expect(budget.id == "budget-7")
        #expect(budget.year == 2026)
        #expect(budget.totalBudget == dec("1000"))
        #expect(budget.totalSpent == dec("79.99"))
        #expect(budget.remaining == dec("920.01"))
        #expect(budget.isOverBudget == false)
        #expect(budget.createdAt == BudgetWire.createdAt)
        #expect(budget.updatedAt == BudgetWire.updatedAt)
        #expect(budget.recipients == [
            RecipientBudget(
                id: "rb-1", recipientId: "user-t", recipientName: "Tommy", maxSpend: dec("200"),
                spent: dec("79.99"), remaining: dec("120.01"), overage: 0, isOverBudget: false
            ),
            RecipientBudget(
                id: "rb-2", recipientId: "user-m", recipientName: "Mike", maxSpend: dec("100"),
                spent: dec("0.01"), remaining: dec("99.99"), overage: 0, isOverBudget: false
            )
        ])
    }

    @Test("200 or 201 maps a budget without recipients to an empty recipient list", arguments: budgetOps)
    func okWithoutRecipients(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(
            status: op.successStatus, json: BudgetWire.budgetEnvelope(BudgetWire.budgetJSON(recipients: []))
        )

        let budget = try await callReturningBudget(op, sut)

        #expect(budget.recipients.isEmpty)
        #expect(budget.totalBudget == dec("1000"))
    }

    @Test("an over-budget budget and recipient keep their overage and flags", arguments: budgetOps)
    func overBudgetMaps(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        let body = BudgetWire.budgetJSON(
            total: "600", spent: "619.98", remaining: "-19.98", isOver: true, recipients: [BudgetWire.overJohn]
        )
        await sut.transport.enqueue(status: op.successStatus, json: BudgetWire.budgetEnvelope(body))

        let budget = try await callReturningBudget(op, sut)

        #expect(budget.isOverBudget)
        #expect(budget.remaining == dec("-19.98"))
        #expect(budget.recipients.first?.isOverBudget == true)
        #expect(budget.recipients.first?.overage == dec("19.98"))
        #expect(budget.recipients.first?.remaining == dec("-19.98"))
    }

    @Test("Money crosses the boundary as an exact Decimal", arguments: budgetOps, ["79.99", "0.01", "999999.99", "0", "19.9"])
    func moneyIsExactDecimal(op: BudgetOp, text: String) async throws {
        let sut = try makeBudgetWireSUT()
        let recipient = BudgetWire.RecipientSpec(maxSpend: text, spent: text, remaining: text, overage: text)
        let body = BudgetWire.budgetJSON(total: text, spent: text, remaining: text, recipients: [recipient])
        await sut.transport.enqueue(status: op.successStatus, json: BudgetWire.budgetEnvelope(body))

        let budget = try await callReturningBudget(op, sut)

        #expect(budget.totalBudget == dec(text), "\(op) \(text)")
        #expect(budget.totalSpent == dec(text))
        #expect(budget.remaining == dec(text))
        #expect(budget.recipients.first?.maxSpend == dec(text))
        #expect(budget.recipients.first?.spent == dec(text))
        #expect(budget.recipients.first?.remaining == dec(text))
        #expect(budget.recipients.first?.overage == dec(text))
    }

    // MARK: listBudgets

    @Test("listBudgets maps an empty list")
    func listEmpty() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetsEnvelope([]))

        let budgets = try await sut.budgets.listBudgets()

        #expect(budgets.isEmpty)
    }

    @Test("listBudgets maps several budgets in order, with and without recipients")
    func listSeveral() async throws {
        let sut = try makeBudgetWireSUT()
        let withRecipients = BudgetWire.budgetJSON(id: "budget-26", year: 2026, recipients: [BudgetWire.tommy, BudgetWire.mike])
        let withoutRecipients = BudgetWire.budgetJSON(
            id: "budget-25", year: 2025, total: "500", spent: "0", remaining: "500", recipients: []
        )
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetsEnvelope([withRecipients, withoutRecipients]))

        let budgets = try await sut.budgets.listBudgets()

        #expect(budgets.map(\.id) == ["budget-26", "budget-25"])
        #expect(budgets.map(\.year) == [2026, 2025])
        #expect(budgets.first?.recipients.count == 2)
        #expect(budgets.last?.recipients.isEmpty == true)
        #expect(budgets.last?.totalBudget == dec("500"))
    }

    @Test("listBudgets with one over-budget entry keeps the flag on that entry only")
    func listKeepsFlagsPerEntry() async throws {
        let sut = try makeBudgetWireSUT()
        let over = BudgetWire.budgetJSON(
            id: "budget-26", total: "600", spent: "619.98", remaining: "-19.98", isOver: true, recipients: [BudgetWire.overJohn]
        )
        let under = BudgetWire.budgetJSON(id: "budget-25", year: 2025)
        await sut.transport.enqueue(status: 200, json: BudgetWire.budgetsEnvelope([over, under]))

        let budgets = try await sut.budgets.listBudgets()

        #expect(budgets.map(\.isOverBudget) == [true, false])
    }

    // MARK: deleteBudget

    @Test("deleteBudget returns normally on a 200 with the message body")
    func deleteOk() async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: 200, json: BudgetWire.deletedEnvelope)

        try await sut.budgets.delete(year: 2026)

        #expect(await sut.transport.requestCount == 1)
    }

    // MARK: Unreadable success bodies

    @Test("a success whose body cannot be read throws invalidResponse", arguments: [
        BudgetOp.list, .get, .create, .update, .duplicate
    ], [
        "{ this is not json",
        "{ \"success\": true }",
        "{ \"success\": true, \"data\": { \"id\": \"budget-1\", \"year\": 2026 }, \"meta\": \(ListWire.metaJSON) }"
    ])
    func unreadableOkBody(op: BudgetOp, body: String) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueue(status: op.successStatus, json: body)

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }

    @Test("a success with no body at all throws invalidResponse", arguments: [
        BudgetOp.stats, .list, .get, .create, .update, .duplicate
    ])
    func emptyOkBody(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        await sut.transport.enqueueEmpty(status: op.successStatus)

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }

    @Test("a budget with a date that cannot be read throws invalidResponse", arguments: budgetOps)
    func unreadableDate(op: BudgetOp) async throws {
        let sut = try makeBudgetWireSUT()
        let broken = BudgetWire.budgetJSON().replacingOccurrences(of: "2026-01-05T08:30:00.000Z", with: "yesterday")
        await sut.transport.enqueue(status: op.successStatus, json: BudgetWire.budgetEnvelope(broken))

        await #expect(throws: BudgetError.invalidResponse) {
            try await sut.run(op)
        }
    }
}
