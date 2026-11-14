//
//  StatsScreenModelSheetTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the sheets of StatsScreenModel: presenting create, edit and duplicate (edit and duplicate
//  are no-ops without a budget), the sheet models it builds, and the follow-up after a save or a
//  duplicate: close the sheet, select the saved year, show the returned budget at once and refresh the
//  stats for that year.
//
//  The tests mirror the app: the sheet's service call stores the budget in the BudgetService, then the
//  screen model's didSave / didDuplicate runs with the returned value.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenModel sheet Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelSheetTests {

    // MARK: Presenting

    @Test("presentCreate presents the create sheet, even without a budget")
    func presentCreate() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.emptyStats(), budgets: [])

        sut.model.presentCreate()

        #expect(sut.model.presentedSheet == .create)
    }

    @Test("presentEdit presents the edit sheet for the selected year's budget")
    func presentEdit() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])

        // EDITED (UX1a U2): `await` because presentEdit may now load the budget first (finding A).
        await sut.model.presentEdit()

        #expect(sut.model.presentedSheet == .edit(budget))
    }

    @Test("presentDuplicate presents the duplicate sheet for the selected year's budget")
    func presentDuplicate() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])

        // EDITED (UX1a U2): `await`, see presentEdit.
        await sut.model.presentDuplicate()

        #expect(sut.model.presentedSheet == .duplicate(budget))
    }

    @Test("presentEdit and presentDuplicate do nothing when the selected year has no budget")
    func editAndDuplicateNeedABudget() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.statsWithoutBudget(), budgets: [])
        // EDITED (UX1a U2): `await`, and a scripted empty budget list so the test is deterministic
        // whether or not the model asks the server first: the answer still has no budget.
        sut.manager.enqueueList([])
        sut.manager.enqueueList([])

        await sut.model.presentEdit()
        #expect(sut.model.presentedSheet == nil)

        await sut.model.presentDuplicate()
        #expect(sut.model.presentedSheet == nil)
    }

    // MARK: Sheet models

    @Test("the create editor offers the years without a budget and defaults to the first free year after the current one")
    func createEditorModel() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])

        let editor = sut.editorModel(for: .create)

        #expect(editor?.title == "New Budget")
        #expect(editor?.isYearEditable == true)
        #expect(editor?.availableYears == [2025, 2027, 2028, 2029])
        #expect(editor?.draft.year == 2027, "2026 already has a budget, so the next free year is the default")
    }

    @Test("the create editor defaults to the current year when it has no budget")
    func createEditorDefaultsToCurrentYear() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.emptyStats(), budgets: [])

        let editor = sut.editorModel(for: .create)

        #expect(editor?.availableYears == [2025, 2026, 2027, 2028, 2029])
        #expect(editor?.draft.year == 2026)
    }

    @Test("the edit editor is read-only on the year and titled with it")
    func editEditorModel() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])

        let editor = sut.editorModel(for: .edit(budget))

        #expect(editor?.title == "2026 Budget")
        #expect(editor?.isYearEditable == false)
        #expect(editor?.availableYears == [])
    }

    @Test("the duplicate sheet has no editor model")
    func duplicateSheetHasNoEditor() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])

        #expect(sut.editorModel(for: .duplicate(budget)) == nil)
    }

    @Test("the duplicate model offers the years after the current one that have no budget")
    func duplicateModelYears() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget])

        let duplicate = sut.model.makeDuplicateModel(for: budget)

        #expect(duplicate.years == [2027, 2028, 2029])
        #expect(duplicate.selectedYear == 2027)
        #expect(duplicate.canDuplicate == true)
    }

    @Test("the duplicate model skips years that already have a budget")
    func duplicateModelSkipsBudgetYears() async {
        let budget = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [budget, BudgetServiceFix.budget(2027)])

        let duplicate = sut.model.makeDuplicateModel(for: budget)

        #expect(duplicate.years == [2028, 2029])
        #expect(duplicate.selectedYear == 2028)
    }

    // MARK: After a save

    @Test("after an edit save the sheet closes, the returned budget shows at once and the stats refresh")
    func didSaveShowsReturnedBudgetImmediately() async throws {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"), budgets: [BudgetServiceFix.budget(2026)])
        await sut.model.presentEdit()
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "1200"))
        let saved = try await sut.budgets.update(BudgetServiceFix.updateRequest(year: 2026, total: "1200"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "100"), held: true)

        let follow = Task { @MainActor in await sut.model.didSave(saved) }
        await sut.loader.gate.nextHeldCall()

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.selectedYear == 2026)
        #expect(sut.model.screenState?.budgetCard?.totalText == "$1,200.00", "the returned budget shows before the refresh lands")
        #expect(sut.loader.callCount == 2, "the stats for the year are being refreshed")

        sut.loader.gate.releaseAll()
        await follow.value
        #expect(sut.model.screenState?.budgetCard?.totalText == "$1,200.00")
    }

    @Test("after a create save the new year is selected and shows the returned budget even when the stats have none")
    func didSaveSelectsNewYear() async throws {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsScreenTest.emptyStats(), budgets: [])
        sut.model.presentCreate()
        sut.manager.enqueue(BudgetServiceFix.budget(2027, total: "500"))
        let saved = try await sut.budgets.create(BudgetServiceFix.createRequest(year: 2027, total: "500"))
        sut.loader.enqueue(StatsScreenTest.emptyStats(year: 2027))

        await sut.model.didSave(saved)

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.selectedYear == 2027)
        #expect(sut.loader.calls.last == .yearStats(year: 2027))
        #expect(sut.model.screenState?.year == 2027)
        #expect(sut.model.screenState?.kind == .budgeted, "the cached budget wins over the stats of the year")
        #expect(sut.model.screenState?.budgetCard?.totalText == "$500.00")
        #expect(sut.model.yearChoices.contains(2027))
    }

    @Test("didSave refreshes even when the saved year's stats are cached and fresh")
    func didSaveForcesTheRefresh() async throws {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"), budgets: [BudgetServiceFix.budget(2026)])
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "900"))
        let saved = try await sut.budgets.update(BudgetServiceFix.updateRequest(year: 2026, total: "900"))
        sut.loader.enqueue(StatsFix.year(2026, spent: "175"))

        await sut.model.didSave(saved)

        #expect(sut.loader.callCount == 2)
        let expected = StatsScreenTest.expectedState(
            year: 2026, stats: StatsFix.year(2026, spent: "175"), budget: BudgetServiceFix.budget(2026, total: "900")
        )
        #expect(sut.model.screenState == expected)
    }

    // MARK: After a duplicate

    @Test("after a duplicate the sheet closes, the target year is selected and shows the returned budget")
    func didDuplicateSelectsTargetYear() async throws {
        let source = BudgetServiceFix.budget(2026)
        let sut = await makeLoadedStatsScreenSUT(budgets: [source])
        await sut.model.presentDuplicate()
        sut.manager.enqueue(BudgetServiceFix.budget(2027, total: "1000"))
        let copy = try await sut.budgets.duplicate(BudgetServiceFix.duplicateRequest(from: 2026, to: 2027))
        sut.loader.enqueue(StatsScreenTest.emptyStats(year: 2027))

        await sut.model.didDuplicate(copy)

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.selectedYear == 2027)
        #expect(sut.loader.calls.last == .yearStats(year: 2027))
        #expect(sut.model.screenState?.kind == .budgeted)
        #expect(sut.model.screenState?.budgetCard?.year == 2027)
    }

    @Test("a refresh that fails after a save leaves the sheet closed and the returned budget on screen")
    func didSaveFailureKeepsReturnedBudget() async throws {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"), budgets: [BudgetServiceFix.budget(2026)])
        await sut.model.presentEdit()
        sut.manager.enqueue(BudgetServiceFix.budget(2026, total: "1200"))
        let saved = try await sut.budgets.update(BudgetServiceFix.updateRequest(year: 2026, total: "1200"))
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.model.didSave(saved)

        #expect(sut.model.presentedSheet == nil)
        #expect(sut.model.screenState?.budgetCard?.totalText == "$1,200.00")
        #expect(sut.model.loadPhase == .content)
    }
}
