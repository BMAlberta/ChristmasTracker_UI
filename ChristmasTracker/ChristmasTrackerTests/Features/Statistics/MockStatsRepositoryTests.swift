//
//  MockStatsRepositoryTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: MockStatsRepository (over the shared MockBudgetStore) answers `yearStats` the way the
//  server does: the year's spend rows and a budget block built from the store (nil when the year has
//  no budget).
//
//  Seed (Gate 1 Story B, mocks): currentYear has a budget (total 1000 with two people) and spend;
//  currentYear-1 has spend and no budget; currentYear+1 is empty.
//
//  Because the stats and the budget repository share ONE store, a budget created, updated or deleted
//  through MockBudgetRepository shows in the next stats answer. The mock does not move purchase or
//  item data when budgets change (documented limitation): the spend rows stay as seeded.
//
//  Construction assumption: MockBudgetStore(currentYear:), MockStatsRepository(store:) and
//  MockBudgetRepository(store:) (see MockBudgetRepositoryTests).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("MockStatsRepository", .timeLimit(.minutes(1)))
struct MockStatsRepositoryTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    // MARK: Seed

    @Test("the current year has spend rows and a budget block of total 1000", arguments: [2026, 2031])
    func currentYearSeed(currentYear: Int) async throws {
        let sut = makeMockBudgetSUT(currentYear: currentYear)

        let stats = try await sut.stats.yearStats(year: currentYear)

        #expect(stats.year == currentYear)
        #expect(stats.totalSpent > 0)
        #expect(stats.purchaseCount > 0)
        #expect(stats.itemsPurchased > 0)
        #expect(!stats.spendByRecipient.isEmpty)
        #expect(stats.availableYears.contains(currentYear))
        #expect(stats.availableYears.contains(currentYear - 1))
        let budget = try #require(stats.budget)
        #expect(budget.totalBudget == dec("1000"))
        #expect(budget.recipients.count == 2)
    }

    @Test("the previous year has spend and no budget")
    func previousYearSeed() async throws {
        let sut = makeMockBudgetSUT()

        let stats = try await sut.stats.yearStats(year: sut.previousYear)

        #expect(stats.year == sut.previousYear)
        #expect(stats.budget == nil)
        #expect(stats.totalSpent > 0)
        #expect(stats.purchaseCount > 0)
        #expect(!stats.spendByRecipient.isEmpty)
    }

    @Test("the next year is empty: no spend, no purchases and no budget")
    func nextYearSeed() async throws {
        let sut = makeMockBudgetSUT()

        let stats = try await sut.stats.yearStats(year: sut.nextYear)

        #expect(stats.year == sut.nextYear)
        #expect(stats.budget == nil)
        #expect(stats.totalSpent == 0)
        #expect(stats.itemsPurchased == 0)
        #expect(stats.purchaseCount == 0)
        #expect(stats.spendByRecipient.isEmpty)
    }

    @Test("the budget block is built from the store: it agrees with the budget repository")
    func budgetBlockMatchesTheStore() async throws {
        let sut = makeMockBudgetSUT()
        let budget = try await sut.repository.budget(year: sut.currentYear)

        let block = try #require(try await sut.stats.yearStats(year: sut.currentYear).budget)

        #expect(block.totalBudget == budget.totalBudget)
        #expect(block.recipients.map(\.recipientId) == budget.recipients.map(\.recipientId))
        #expect(block.recipients.map(\.budget) == budget.recipients.map(\.maxSpend))
        #expect(block.recipients.map(\.displayName) == budget.recipients.map(\.recipientName))
    }

    @Test("every row of the budget block is consistent: remaining is the limit minus the spend")
    func budgetBlockRowsAreConsistent() async throws {
        let sut = makeMockBudgetSUT()

        let block = try #require(try await sut.stats.yearStats(year: sut.currentYear).budget)

        #expect(block.remaining == block.totalBudget - block.totalSpent)
        for row in block.recipients {
            #expect(row.remaining == row.budget - row.spent)
        }
    }

    @Test("two calls for the same year give the same answer (deterministic data)")
    func answersAreStable() async throws {
        let sut = makeMockBudgetSUT()

        let first = try await sut.stats.yearStats(year: sut.currentYear)
        let second = try await sut.stats.yearStats(year: sut.currentYear)

        #expect(first == second)
    }

    // MARK: The shared store

    @Test("a budget created through the budget repository shows in the next stats answer, with no spend moved")
    func createdBudgetShowsInStats() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.create(
            CreateBudgetRequest(year: sut.nextYear, totalBudget: dec("300"), recipients: [])
        )

        let stats = try await sut.stats.yearStats(year: sut.nextYear)

        #expect(stats.budget?.totalBudget == dec("300"))
        #expect(stats.budget?.recipients.isEmpty == true)
        #expect(stats.totalSpent == 0, "the mock does not move purchase data when a budget is created")
        #expect(stats.spendByRecipient.isEmpty)
    }

    @Test("a budget updated through the budget repository shows its new total in the next stats answer")
    func updatedBudgetShowsInStats() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.update(
            UpdateBudgetRequest(year: sut.currentYear, totalBudget: dec("1500"), recipients: nil)
        )

        let stats = try await sut.stats.yearStats(year: sut.currentYear)

        #expect(stats.budget?.totalBudget == dec("1500"))
    }

    @Test("a budget deleted through the budget repository is gone from the next stats answer")
    func deletedBudgetLeavesStats() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.create(
            CreateBudgetRequest(year: sut.nextYear, totalBudget: dec("300"), recipients: [])
        )
        try await sut.repository.delete(year: sut.nextYear)

        let stats = try await sut.stats.yearStats(year: sut.nextYear)

        #expect(stats.budget == nil)
    }

    @Test("a duplicated budget shows in the stats of the new year with nothing spent")
    func duplicatedBudgetShowsInStats() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.duplicate(
            DuplicateBudgetRequest(fromYear: sut.currentYear, toYear: sut.nextYear)
        )

        let stats = try await sut.stats.yearStats(year: sut.nextYear)

        #expect(stats.budget?.totalBudget == dec("1000"))
        #expect(stats.budget?.totalSpent == 0)
    }

    @Test("a failed budget mutation changes nothing in the stats")
    func failedMutationLeavesStats() async throws {
        let sut = makeMockBudgetSUT()
        let before = try await sut.stats.yearStats(year: sut.currentYear)

        _ = try? await sut.repository.create(
            CreateBudgetRequest(year: sut.currentYear, totalBudget: dec("5"), recipients: [])
        )
        _ = try? await sut.repository.update(
            UpdateBudgetRequest(year: sut.currentYear, totalBudget: dec("0.01"), recipients: nil)
        )
        try? await sut.repository.delete(year: sut.currentYear)

        #expect(try await sut.stats.yearStats(year: sut.currentYear) == before)
    }

    @Test("stats only ever throw a BudgetError or nothing")
    func onlyTypedErrors() async {
        let sut = makeMockBudgetSUT()

        do {
            _ = try await sut.stats.yearStats(year: sut.currentYear + 40)
        } catch {
            #expect(error is BudgetError, "got \(error)")
        }
    }
}
