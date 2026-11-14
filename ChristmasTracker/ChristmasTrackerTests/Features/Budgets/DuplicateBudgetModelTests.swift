//
//  DuplicateBudgetModelTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: DuplicateBudgetModel, the small sheet that copies a budget to a year without one. The
//  years and the default come from the caller, the call goes through the BudgetService, an error is held
//  only in the model's banner, cancellation returns nil without a banner, and a second tap while
//  duplicating is ignored.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("DuplicateBudgetModel Tests", .timeLimit(.minutes(1)))
@MainActor
struct DuplicateBudgetModelTests {

    private struct SUT {
        let model: DuplicateBudgetModel
        let budgets: BudgetService
        let manager: GatedBudgetManager
    }

    private func makeSUT(years: [Int] = [2027, 2028, 2029], defaultYear: Int? = 2027) -> SUT {
        let manager = GatedBudgetManager()
        let budgets = BudgetService(repository: manager)
        let model = DuplicateBudgetModel(
            source: BudgetServiceFix.budget(2026), budgetService: budgets, years: years, defaultYear: defaultYear
        )
        return SUT(model: model, budgets: budgets, manager: manager)
    }

    // MARK: State

    @Test("the model offers the given years and selects the default year")
    func initialState() {
        let sut = makeSUT()

        #expect(sut.model.years == [2027, 2028, 2029])
        #expect(sut.model.selectedYear == 2027)
        #expect(sut.model.canDuplicate == true)
        #expect(sut.model.isDuplicating == false)
        #expect(sut.model.banner == nil)
    }

    @Test("a default other than the first year is selected")
    func nonFirstDefault() {
        let sut = makeSUT(years: [2027, 2028, 2029], defaultYear: 2028)

        #expect(sut.model.selectedYear == 2028)
    }

    @Test("with no free year nothing is selected and Duplicate is disabled")
    func noFreeYear() async {
        let sut = makeSUT(years: [], defaultYear: nil)

        #expect(sut.model.years.isEmpty)
        #expect(sut.model.selectedYear == nil)
        #expect(sut.model.canDuplicate == false)

        let result = await sut.model.duplicate()
        #expect(result == nil)
        #expect(sut.manager.callCount == 0)
    }

    // MARK: Success

    @Test("success returns the new budget and sends the source and the target year")
    func success() async {
        let sut = makeSUT()
        let copy = BudgetServiceFix.budget(2027, total: "1000")
        sut.manager.enqueue(copy)

        let result = await sut.model.duplicate()

        #expect(result == copy)
        #expect(sut.manager.calls == [.duplicate(DuplicateBudgetRequest(fromYear: 2026, toYear: 2027))])
        #expect(sut.model.banner == nil)
        #expect(sut.model.isDuplicating == false)
        #expect(sut.budgets.budget(for: 2027) == copy)
    }

    @Test("the chosen year is the target year")
    func chosenYear() async {
        let sut = makeSUT()
        sut.model.selectedYear = 2029
        sut.manager.enqueue(BudgetServiceFix.budget(2029))

        let result = await sut.model.duplicate()

        #expect(result?.year == 2029)
        #expect(sut.manager.calls == [.duplicate(DuplicateBudgetRequest(fromYear: 2026, toYear: 2029))])
    }

    // MARK: Errors

    @Test("a failed duplicate returns nil and shows the banner with the message and actions of the error",
          arguments: MutationFailureCases.all)
    func failureBanner(failure: MutationFailureCase) async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(failure.error)

        let result = await sut.model.duplicate()

        #expect(result == nil)
        #expect(sut.model.banner == InlineErrorBannerState(message: failure.message, actions: failure.actions))
        #expect(sut.model.isDuplicating == false)
        #expect(sut.budgets.budgetsByYear.isEmpty)
    }

    @Test("a 409 shows the server's message inside the sheet")
    func conflictMessage() async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(BudgetError.alreadyExists(message: "You already have a budget for 2027."))

        _ = await sut.model.duplicate()

        #expect(sut.model.banner?.message == "You already have a budget for 2027.")
    }

    @Test("a 404 on the source shows the not-found message")
    func notFoundMessage() async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(BudgetError.notFound)

        _ = await sut.model.duplicate()

        #expect(sut.model.banner?.message == "That budget could not be found.")
        #expect(sut.model.banner?.actions == [.dismiss])
    }

    @Test("Dismiss removes the banner")
    func dismissBanner() async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(BudgetError.network)
        _ = await sut.model.duplicate()
        #expect(sut.model.banner != nil)

        sut.model.dismissBanner()

        #expect(sut.model.banner == nil)
    }

    @Test("a retry that succeeds clears the banner")
    func retrySuccessClearsBanner() async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(BudgetError.server)
        _ = await sut.model.duplicate()
        #expect(sut.model.banner?.actions == [.tryAgain, .dismiss])
        let copy = BudgetServiceFix.budget(2027)
        sut.manager.enqueue(copy)

        let result = await sut.model.duplicate()

        #expect(result == copy)
        #expect(sut.model.banner == nil)
    }

    // MARK: Cancellation and double tap

    @Test("a cancelled duplicate returns nil with no banner")
    func cancelled() async {
        let sut = makeSUT()
        sut.manager.enqueueFailure(CancellationError())

        let result = await sut.model.duplicate()

        #expect(result == nil)
        #expect(sut.model.banner == nil)
        #expect(sut.model.isDuplicating == false)
        #expect(sut.budgets.budgetsByYear.isEmpty)
    }

    @Test("a second tap while duplicating is ignored")
    func doubleTapIgnored() async {
        let sut = makeSUT()
        let copy = BudgetServiceFix.budget(2027)
        sut.manager.enqueue(copy, held: true)

        let first = Task { @MainActor in await sut.model.duplicate() }
        await sut.manager.gate.nextHeldCall()
        #expect(sut.model.isDuplicating == true)
        #expect(sut.model.canDuplicate == false, "the button is disabled while duplicating")

        let second = await sut.model.duplicate()
        #expect(second == nil)
        #expect(sut.manager.callCount == 1)

        sut.manager.gate.releaseAll()
        let firstResult = await first.value
        #expect(firstResult == copy)
        #expect(sut.model.isDuplicating == false)
        #expect(sut.manager.callCount == 1)
    }
}
