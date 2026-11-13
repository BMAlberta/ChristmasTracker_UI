//
//  MockBudgetStore.swift
//  ChristmasTracker
//
//  The in-memory data of mock mode for budgets and year statistics, shared by MockBudgetRepository
//  and MockStatsRepository. It behaves like the server for the caller's own data: one budget per
//  year, the sum rule checked against the new or the existing total, an update that replaces the
//  whole recipient list when one is sent, a delete that is refused while the year has purchases,
//  and a duplicate that copies the total and the limits.
//
//  Deterministic: the seed is built from the `currentYear` argument and fixed values, and no clock
//  is read (timestamps are a fixed reference date). Seed: the current year has a budget (total 1000,
//  two people) and spend; the year before has spend and no budget; the year after is empty.
//
//  Documented limitation: the mock does not move item or purchase data when budgets change, so the
//  spend rows stay as seeded. Spending is read from the seed; a budget only shows it.
//
//  An actor, and a mock: intentionally uninstrumented.
//

import Foundation

actor MockBudgetStore {

    private struct StoredBudget {
        let id: String
        let year: Int
        var totalBudget: Decimal
        var limits: [BudgetLimit]
    }

    private struct YearData {
        let spend: [RecipientSpend]
        let purchaseCount: Int
    }

    private var budgets: [Int: StoredBudget] = [:]
    private let spendByYear: [Int: YearData]
    private let names: [String: String]

    /// A fixed reference date (2026-01-01 UTC): the mock never reads the clock.
    private let stamp = Date(timeIntervalSince1970: 1_767_225_600)

    init(currentYear: Int) {
        let tommy = (id: "mock-child-charlie", name: "Tommy D.")
        let jordan = (id: "mock-user-jordan", name: "Jordan Sample")
        let pat = (id: "mock-user-pat", name: "Pat Sample")
        names = [tommy.id: tommy.name, jordan.id: jordan.name, pat.id: pat.name]

        func row(_ person: (id: String, name: String), cents: Int, items: Int) -> RecipientSpend {
            RecipientSpend(
                recipientId: person.id, displayName: person.name, spent: Decimal(cents) / 100, itemsPurchased: items
            )
        }
        spendByYear = [
            currentYear: YearData(
                spend: [row(tommy, cents: 15_050, items: 2), row(jordan, cents: 7_999, items: 1), row(pat, cents: 2_500, items: 1)],
                purchaseCount: 4
            ),
            currentYear - 1: YearData(
                spend: [row(tommy, cents: 30_000, items: 2), row(jordan, cents: 12_000, items: 1)],
                purchaseCount: 3
            )
        ]
        budgets[currentYear] = StoredBudget(
            id: "mock-budget-\(currentYear)",
            year: currentYear,
            totalBudget: 1000,
            limits: [
                BudgetLimit(recipientId: tommy.id, maxSpend: 600),
                BudgetLimit(recipientId: jordan.id, maxSpend: 300)
            ]
        )
    }

    // MARK: Budgets

    func allBudgets() -> [Budget] {
        budgets.keys.sorted(by: >).compactMap { budgets[$0] }.map(view)
    }

    func budget(year: Int) throws -> Budget {
        guard let stored = budgets[year] else { throw BudgetError.notFound }
        return view(stored)
    }

    func create(_ request: CreateBudgetRequest) throws -> Budget {
        guard budgets[request.year] == nil else {
            throw BudgetError.alreadyExists(message: "You already have a budget for that year.")
        }
        try checkSum(total: request.totalBudget, limits: request.recipients)
        let stored = StoredBudget(
            id: "mock-budget-\(request.year)", year: request.year,
            totalBudget: request.totalBudget, limits: request.recipients
        )
        budgets[request.year] = stored
        return view(stored)
    }

    func update(_ request: UpdateBudgetRequest) throws -> Budget {
        guard var stored = budgets[request.year] else { throw BudgetError.notFound }
        let total = request.totalBudget ?? stored.totalBudget
        let limits = request.recipients ?? stored.limits
        try checkSum(total: total, limits: limits)
        stored.totalBudget = total
        stored.limits = limits
        budgets[request.year] = stored
        return view(stored)
    }

    func delete(year: Int) throws {
        guard budgets[year] != nil else { throw BudgetError.notFound }
        if (spendByYear[year]?.purchaseCount ?? 0) > 0 {
            throw BudgetError.hasPurchases(message: "A budget with purchases can't be deleted.")
        }
        budgets[year] = nil
    }

    func duplicate(_ request: DuplicateBudgetRequest) throws -> Budget {
        guard let source = budgets[request.fromYear] else { throw BudgetError.notFound }
        guard budgets[request.toYear] == nil else {
            throw BudgetError.alreadyExists(message: "You already have a budget for that year.")
        }
        let copy = StoredBudget(
            id: "mock-budget-\(request.toYear)", year: request.toYear,
            totalBudget: source.totalBudget, limits: source.limits
        )
        budgets[request.toYear] = copy
        return view(copy)
    }

    // MARK: Statistics

    func yearStats(year: Int) -> StatsYear {
        let spend = spendByYear[year]?.spend ?? []
        let totalSpent = spend.reduce(Decimal(0)) { $0 + $1.spent }
        let statsBudget = budgets[year].map { stored -> StatsBudget in
            let rows = stored.limits.map { limit -> StatsRecipientBudget in
                let spent = spend.first { $0.recipientId == limit.recipientId }?.spent ?? 0
                return StatsRecipientBudget(
                    recipientId: limit.recipientId, displayName: name(of: limit.recipientId),
                    budget: limit.maxSpend, spent: spent, remaining: limit.maxSpend - spent
                )
            }
            return StatsBudget(
                totalBudget: stored.totalBudget, totalSpent: totalSpent,
                remaining: stored.totalBudget - totalSpent, recipients: rows
            )
        }
        let purchaseYears = spendByYear.filter { $0.value.purchaseCount > 0 }.keys.sorted(by: >)
        return StatsYear(
            year: year,
            totalSpent: totalSpent,
            itemsPurchased: spend.reduce(0) { $0 + $1.itemsPurchased },
            purchaseCount: spendByYear[year]?.purchaseCount ?? 0,
            spendByRecipient: spend,
            budget: statsBudget,
            availableYears: purchaseYears
        )
    }

    // MARK: Private

    private func name(of recipientId: String) -> String {
        names[recipientId] ?? "Recipient"
    }

    /// The sum of the limits must not exceed the total (equal is allowed).
    private func checkSum(total: Decimal, limits: [BudgetLimit]) throws {
        let sum = limits.reduce(Decimal(0)) { $0 + $1.maxSpend }
        if sum > total {
            throw BudgetError.sumExceedsTotal(message: "Limits add up to more than the total")
        }
    }

    /// The budget as the server answers it, with the real-time spend of its year.
    private func view(_ stored: StoredBudget) -> Budget {
        let spend = spendByYear[stored.year]?.spend ?? []
        let totalSpent = spend.reduce(Decimal(0)) { $0 + $1.spent }
        let rows = stored.limits.map { limit -> RecipientBudget in
            let spent = spend.first { $0.recipientId == limit.recipientId }?.spent ?? 0
            let over = spent > limit.maxSpend
            return RecipientBudget(
                id: "mock-recipient-budget-\(stored.year)-\(limit.recipientId)",
                recipientId: limit.recipientId,
                recipientName: name(of: limit.recipientId),
                maxSpend: limit.maxSpend,
                spent: spent,
                remaining: limit.maxSpend - spent,
                overage: over ? spent - limit.maxSpend : 0,
                isOverBudget: over
            )
        }
        return Budget(
            id: stored.id, year: stored.year, totalBudget: stored.totalBudget, totalSpent: totalSpent,
            remaining: stored.totalBudget - totalSpent, isOverBudget: totalSpent > stored.totalBudget,
            recipients: rows, createdAt: stamp, updatedAt: stamp
        )
    }
}
