//
//  MockBudgetRepositoryTests.swift
//  ChristmasTrackerTests
//
//  I5a Story B: MockBudgetRepository (over the shared MockBudgetStore) behaves like the server:
//
//   - own data only, one budget per year (create or duplicate to an existing year throws
//     `.alreadyExists`);
//   - the sum rule (`.sumExceedsTotal`) on create and update, checked against the new or the existing
//     total (equal is allowed, one cent over is not);
//   - update replaces the whole recipient list when one is sent and keeps it when it is nil;
//   - delete throws `.hasPurchases` when the year has mock purchases and `.notFound` for a missing
//     budget;
//   - duplicate copies the total and the limits (spent zero) and throws `.notFound` for a missing
//     source and `.alreadyExists` for an existing target;
//   - the seed is deterministic (no real clock): two fresh stores with the same `currentYear` agree.
//
//  Seed (Gate 1 Story B, mocks): currentYear has a budget (total 1000 with two people) and spend;
//  currentYear-1 has spend and no budget; currentYear+1 is empty.
//
//  Construction assumption: MockBudgetStore(currentYear:) and MockBudgetRepository(store:).
//  Documented limitation (not tested as a feature): the mock does not move item or purchase data when
//  budgets change.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct MockBudgetSUT {
    let currentYear: Int
    let repository: MockBudgetRepository
    let stats: MockStatsRepository

    var previousYear: Int { currentYear - 1 }
    var nextYear: Int { currentYear + 1 }
}

func makeMockBudgetSUT(currentYear: Int = 2026) -> MockBudgetSUT {
    let store = MockBudgetStore(currentYear: currentYear)
    return MockBudgetSUT(
        currentYear: currentYear,
        repository: MockBudgetRepository(store: store),
        stats: MockStatsRepository(store: store)
    )
}

@Suite("MockBudgetRepository", .timeLimit(.minutes(1)))
struct MockBudgetRepositoryTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    private func limit(_ id: String, _ amount: String) -> BudgetLimit {
        BudgetLimit(recipientId: id, maxSpend: dec(amount))
    }

    /// The ids of the two people the seeded budget has a limit for (known to the mock).
    private func seedIds(_ sut: MockBudgetSUT) async throws -> [String] {
        try await sut.repository.budget(year: sut.currentYear).recipients.map(\.recipientId)
    }

    /// The error a call threw, nil when it succeeded or threw something else.
    private func budgetError(_ body: () async throws -> Void) async -> BudgetError? {
        do {
            try await body()
            return nil
        } catch {
            return error as? BudgetError
        }
    }

    // MARK: Seed

    @Test("the seed has exactly one budget, in the current year, total 1000 with two people", arguments: [2026, 2031])
    func seedBudget(currentYear: Int) async throws {
        let sut = makeMockBudgetSUT(currentYear: currentYear)

        let budgets = try await sut.repository.listBudgets()

        #expect(budgets.map(\.year) == [currentYear])
        let budget = try #require(budgets.first)
        #expect(budget.totalBudget == dec("1000"))
        #expect(budget.recipients.count == 2)
        let limitsSum = budget.recipients.reduce(Decimal(0)) { $0 + $1.maxSpend }
        #expect(limitsSum <= budget.totalBudget, "the seed obeys the sum rule")
        #expect(Set(budget.recipients.map(\.recipientId)).count == 2, "two different people")
        #expect(budget.recipients.allSatisfy { !$0.recipientName.isEmpty })
    }

    @Test("budget(year:) returns the seeded budget and notFound for years without one")
    func seedLookup() async throws {
        let sut = makeMockBudgetSUT()

        let current = try await sut.repository.budget(year: sut.currentYear)

        #expect(current.year == sut.currentYear)
        #expect(try await sut.repository.listBudgets() == [current])
        await #expect(throws: BudgetError.notFound) { _ = try await sut.repository.budget(year: sut.previousYear) }
        await #expect(throws: BudgetError.notFound) { _ = try await sut.repository.budget(year: sut.nextYear) }
    }

    @Test("two fresh stores with the same current year agree: the seed does not read the clock")
    func seedIsDeterministic() async throws {
        let one = makeMockBudgetSUT(currentYear: 2026)
        let two = makeMockBudgetSUT(currentYear: 2026)

        let budgetsOne = try await one.repository.listBudgets()
        let budgetsTwo = try await two.repository.listBudgets()
        let statsOne = try await one.stats.yearStats(year: 2026)
        let statsTwo = try await two.stats.yearStats(year: 2026)

        #expect(budgetsOne == budgetsTwo)
        #expect(statsOne == statsTwo)
    }

    @Test("a seeded budget row is consistent: remaining is the limit minus the spend and over means spent above the limit")
    func seedRowsAreConsistent() async throws {
        let sut = makeMockBudgetSUT()

        let budget = try await sut.repository.budget(year: sut.currentYear)

        #expect(budget.remaining == budget.totalBudget - budget.totalSpent)
        for row in budget.recipients {
            #expect(row.remaining == row.maxSpend - row.spent)
            #expect(row.isOverBudget == (row.spent > row.maxSpend))
        }
    }

    // MARK: create

    @Test("create files a new year with the requested total and limits, spent zero, and stores it")
    func createStoresTheBudget() async throws {
        let sut = makeMockBudgetSUT()
        let seeded = try await sut.repository.budget(year: sut.currentYear)
        let ids = seeded.recipients.map(\.recipientId)

        let created = try await sut.repository.create(CreateBudgetRequest(
            year: sut.nextYear, totalBudget: dec("500"),
            recipients: [limit(ids[0], "200"), limit(ids[1], "100.50")]
        ))

        #expect(created.year == sut.nextYear)
        #expect(created.totalBudget == dec("500"))
        #expect(created.totalSpent == 0)
        #expect(created.remaining == dec("500"))
        #expect(created.isOverBudget == false)
        #expect(created.recipients.map(\.recipientId) == ids)
        #expect(created.recipients.map(\.maxSpend) == [dec("200"), dec("100.50")])
        #expect(created.recipients.allSatisfy { $0.spent == 0 && $0.overage == 0 && !$0.isOverBudget })
        #expect(created.recipients.map(\.remaining) == [dec("200"), dec("100.50")])
        #expect(try await sut.repository.budget(year: sut.nextYear) == created)
        #expect(try await sut.repository.listBudgets().count == 2)
    }

    @Test("create with no recipients is a valid total-only budget")
    func createTotalOnly() async throws {
        let sut = makeMockBudgetSUT()

        let created = try await sut.repository.create(
            CreateBudgetRequest(year: sut.nextYear, totalBudget: dec("250"), recipients: [])
        )

        #expect(created.recipients.isEmpty)
        #expect(created.totalBudget == dec("250"))
    }

    @Test("create for a year that has a budget throws alreadyExists and changes nothing")
    func createExistingYear() async throws {
        let sut = makeMockBudgetSUT()
        let before = try await sut.repository.listBudgets()

        let error = await budgetError {
            _ = try await sut.repository.create(
                CreateBudgetRequest(year: sut.currentYear, totalBudget: dec("10"), recipients: [])
            )
        }

        guard case .alreadyExists = error else {
            Issue.record("expected .alreadyExists, got \(String(describing: error))")
            return
        }
        #expect(try await sut.repository.listBudgets() == before)
    }

    @Test("the create sum rule: equal to the total is allowed, one cent over throws sumExceedsTotal")
    func createSumRule() async throws {
        let sut = makeMockBudgetSUT()
        let ids = try await seedIds(sut)

        let equal = try await sut.repository.create(CreateBudgetRequest(
            year: sut.nextYear, totalBudget: dec("300"), recipients: [limit(ids[0], "200"), limit(ids[1], "100")]
        ))
        #expect(equal.recipients.count == 2)

        let over = await budgetError {
            _ = try await sut.repository.create(CreateBudgetRequest(
                year: sut.nextYear + 1, totalBudget: dec("300"),
                recipients: [self.limit(ids[0], "200"), self.limit(ids[1], "100.01")]
            ))
        }
        guard case .sumExceedsTotal = over else {
            Issue.record("expected .sumExceedsTotal, got \(String(describing: over))")
            return
        }
        await #expect(throws: BudgetError.notFound) { _ = try await sut.repository.budget(year: sut.nextYear + 1) }
    }

    @Test("a single limit over the total throws sumExceedsTotal on create")
    func createSingleLimitOverTotal() async {
        let sut = makeMockBudgetSUT()
        let ids = try? await seedIds(sut)

        let error = await budgetError {
            _ = try await sut.repository.create(CreateBudgetRequest(
                year: sut.nextYear, totalBudget: self.dec("100"), recipients: [self.limit(ids?.first ?? "", "100.01")]
            ))
        }

        guard case .sumExceedsTotal = error else {
            Issue.record("expected .sumExceedsTotal, got \(String(describing: error))")
            return
        }
    }

    @Test("the sum error carries a message that is not blank")
    func sumErrorHasAMessage() async {
        let sut = makeMockBudgetSUT()
        let ids = try? await seedIds(sut)

        let error = await budgetError {
            _ = try await sut.repository.create(CreateBudgetRequest(
                year: sut.nextYear, totalBudget: self.dec("100"), recipients: [self.limit(ids?.first ?? "", "200")]
            ))
        }

        #expect(error?.userMessage.isEmpty == false)
    }

    // MARK: update

    @Test("update with only the total keeps the limits and recomputes the remaining")
    func updateTotalOnly() async throws {
        let sut = makeMockBudgetSUT()
        let before = try await sut.repository.budget(year: sut.currentYear)

        let updated = try await sut.repository.update(
            UpdateBudgetRequest(year: sut.currentYear, totalBudget: dec("1200"), recipients: nil)
        )

        #expect(updated.totalBudget == dec("1200"))
        #expect(updated.recipients == before.recipients, "limits and spend are kept")
        #expect(updated.remaining == updated.totalBudget - updated.totalSpent)
        #expect(try await sut.repository.budget(year: sut.currentYear) == updated)
    }

    @Test("update with recipients REPLACES the whole allocation and keeps the total")
    func updateRecipientsReplaces() async throws {
        let sut = makeMockBudgetSUT()
        let before = try await sut.repository.budget(year: sut.currentYear)
        let keptId = try #require(before.recipients.first?.recipientId)
        let droppedId = try #require(before.recipients.last?.recipientId)

        let updated = try await sut.repository.update(UpdateBudgetRequest(
            year: sut.currentYear, totalBudget: nil, recipients: [limit(keptId, "50")]
        ))

        #expect(updated.totalBudget == before.totalBudget)
        #expect(updated.recipients.map(\.recipientId) == [keptId])
        #expect(updated.recipients.map(\.maxSpend) == [dec("50")])
        #expect(!updated.recipients.contains { $0.recipientId == droppedId }, "a person that is not sent is removed")
    }

    @Test("update with an empty recipient list clears the allocation")
    func updateEmptyRecipients() async throws {
        let sut = makeMockBudgetSUT()

        let updated = try await sut.repository.update(
            UpdateBudgetRequest(year: sut.currentYear, totalBudget: nil, recipients: [])
        )

        #expect(updated.recipients.isEmpty)
        #expect(updated.totalBudget == dec("1000"))
    }

    @Test("the update sum rule is checked against the NEW total when one is sent")
    func updateSumAgainstNewTotal() async throws {
        let sut = makeMockBudgetSUT()
        let before = try await sut.repository.budget(year: sut.currentYear)

        let error = await budgetError {
            _ = try await sut.repository.update(
                UpdateBudgetRequest(year: sut.currentYear, totalBudget: dec("0.01"), recipients: nil)
            )
        }

        guard case .sumExceedsTotal = error else {
            Issue.record("expected .sumExceedsTotal, got \(String(describing: error))")
            return
        }
        #expect(try await sut.repository.budget(year: sut.currentYear) == before, "a refused update changes nothing")
    }

    @Test("the update sum rule is checked against the EXISTING total when only recipients are sent")
    func updateSumAgainstExistingTotal() async throws {
        let sut = makeMockBudgetSUT()
        let ids = try await seedIds(sut)

        let ok = try await sut.repository.update(UpdateBudgetRequest(
            year: sut.currentYear, totalBudget: nil, recipients: [limit(ids[0], "600"), limit(ids[1], "400")]
        ))
        #expect(ok.recipients.count == 2, "equal to the existing total of 1000 is allowed")

        let error = await budgetError {
            _ = try await sut.repository.update(UpdateBudgetRequest(
                year: sut.currentYear, totalBudget: nil, recipients: [self.limit(ids[0], "600"), self.limit(ids[1], "400.01")]
            ))
        }
        guard case .sumExceedsTotal = error else {
            Issue.record("expected .sumExceedsTotal, got \(String(describing: error))")
            return
        }
    }

    @Test("update with a new total and matching recipients checks the new pair together")
    func updateBothFields() async throws {
        let sut = makeMockBudgetSUT()
        let ids = try await seedIds(sut)

        let updated = try await sut.repository.update(UpdateBudgetRequest(
            year: sut.currentYear, totalBudget: dec("2000"), recipients: [limit(ids[0], "1500"), limit(ids[1], "500")]
        ))

        #expect(updated.totalBudget == dec("2000"))
        #expect(updated.recipients.count == 2)
    }

    @Test("update of a year without a budget throws notFound")
    func updateMissingYear() async {
        let sut = makeMockBudgetSUT()

        await #expect(throws: BudgetError.notFound) {
            _ = try await sut.repository.update(
                UpdateBudgetRequest(year: sut.nextYear, totalBudget: self.dec("10"), recipients: nil)
            )
        }
    }

    // MARK: delete

    @Test("delete of a year that has mock purchases throws hasPurchases and keeps the budget")
    func deleteWithPurchases() async throws {
        let sut = makeMockBudgetSUT()

        let error = await budgetError { try await sut.repository.delete(year: sut.currentYear) }

        guard case .hasPurchases = error else {
            Issue.record("expected .hasPurchases, got \(String(describing: error))")
            return
        }
        #expect(error?.userMessage.isEmpty == false)
        #expect(try await sut.repository.budget(year: sut.currentYear).year == sut.currentYear)
    }

    @Test("delete of a year without purchases removes the budget")
    func deleteWithoutPurchases() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.create(
            CreateBudgetRequest(year: sut.nextYear, totalBudget: dec("100"), recipients: [])
        )

        try await sut.repository.delete(year: sut.nextYear)

        await #expect(throws: BudgetError.notFound) { _ = try await sut.repository.budget(year: sut.nextYear) }
        #expect(try await sut.repository.listBudgets().map(\.year) == [sut.currentYear])
    }

    @Test("delete of a year without a budget throws notFound", arguments: [-1, 1, 5])
    func deleteMissingYear(offset: Int) async {
        let sut = makeMockBudgetSUT()

        await #expect(throws: BudgetError.notFound) { try await sut.repository.delete(year: sut.currentYear + offset) }
    }

    // MARK: duplicate

    @Test("duplicate copies the total and the limits to the new year with spent zero")
    func duplicateCopiesTheStructure() async throws {
        let sut = makeMockBudgetSUT()
        let source = try await sut.repository.budget(year: sut.currentYear)

        let copy = try await sut.repository.duplicate(
            DuplicateBudgetRequest(fromYear: sut.currentYear, toYear: sut.nextYear)
        )

        #expect(copy.year == sut.nextYear)
        #expect(copy.totalBudget == source.totalBudget)
        #expect(copy.recipients.map(\.recipientId) == source.recipients.map(\.recipientId))
        #expect(copy.recipients.map(\.maxSpend) == source.recipients.map(\.maxSpend))
        #expect(copy.totalSpent == 0)
        #expect(copy.remaining == source.totalBudget)
        #expect(copy.isOverBudget == false)
        #expect(copy.recipients.allSatisfy { $0.spent == 0 && $0.overage == 0 && !$0.isOverBudget })
        #expect(copy.recipients.map(\.remaining) == source.recipients.map(\.maxSpend))
        #expect(try await sut.repository.budget(year: sut.nextYear) == copy)
        #expect(try await sut.repository.budget(year: sut.currentYear) == source, "the source is untouched")
    }

    @Test("duplicate of a missing source throws notFound")
    func duplicateMissingSource() async {
        let sut = makeMockBudgetSUT()

        await #expect(throws: BudgetError.notFound) {
            _ = try await sut.repository.duplicate(
                DuplicateBudgetRequest(fromYear: sut.previousYear, toYear: sut.nextYear)
            )
        }
    }

    @Test("duplicate to a year that has a budget throws alreadyExists and changes nothing")
    func duplicateExistingTarget() async throws {
        let sut = makeMockBudgetSUT()
        _ = try await sut.repository.create(
            CreateBudgetRequest(year: sut.nextYear, totalBudget: dec("10"), recipients: [])
        )
        let before = try await sut.repository.listBudgets()

        let error = await budgetError {
            _ = try await sut.repository.duplicate(
                DuplicateBudgetRequest(fromYear: sut.currentYear, toYear: sut.nextYear)
            )
        }

        guard case .alreadyExists = error else {
            Issue.record("expected .alreadyExists, got \(String(describing: error))")
            return
        }
        #expect(try await sut.repository.listBudgets() == before)
    }

    @Test("duplicate onto the source year itself throws alreadyExists")
    func duplicateOntoItself() async {
        let sut = makeMockBudgetSUT()

        let error = await budgetError {
            _ = try await sut.repository.duplicate(
                DuplicateBudgetRequest(fromYear: sut.currentYear, toYear: sut.currentYear)
            )
        }

        guard case .alreadyExists = error else {
            Issue.record("expected .alreadyExists, got \(String(describing: error))")
            return
        }
    }

    // MARK: Only typed errors

    @Test("every failure of the mock is a BudgetError")
    func onlyTypedErrors() async {
        let sut = makeMockBudgetSUT()
        let calls: [() async throws -> Void] = [
            { _ = try await sut.repository.budget(year: sut.nextYear) },
            { _ = try await sut.repository.create(CreateBudgetRequest(year: sut.currentYear, totalBudget: 1, recipients: [])) },
            { _ = try await sut.repository.update(UpdateBudgetRequest(year: sut.nextYear, totalBudget: 1, recipients: nil)) },
            { try await sut.repository.delete(year: sut.nextYear) },
            { _ = try await sut.repository.duplicate(DuplicateBudgetRequest(fromYear: sut.nextYear, toYear: sut.currentYear)) }
        ]

        for call in calls {
            do {
                try await call()
                Issue.record("expected a failure")
            } catch {
                #expect(error is BudgetError, "got \(error)")
            }
        }
    }
}
