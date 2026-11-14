//
//  BudgetEditorModelSaveTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: BudgetEditorModel.save(). Create sends year, total and recipients (possibly empty); edit
//  sends only what changed; the returned budget is the stored one. A mutation error is held only in the
//  model's own banner (message from the error, Try Again only when retryable, always Dismiss); the
//  BudgetService publishes nothing. Cancellation returns nil without a banner; a second save while saving
//  is ignored.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("BudgetEditorModel save Tests", .timeLimit(.minutes(1)))
@MainActor
struct BudgetEditorModelSaveTests {

    private func dec(_ text: String) -> Decimal { BudgetFixtures.dec(text) }

    // MARK: Create

    @Test("create success returns the stored budget and sends year, total and recipients")
    func createSuccess() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        let stored = EditorTest.stored(year: 2026, total: "1000")
        sut.manager.enqueue(stored)

        let saved = await sut.model.save()

        #expect(saved == stored)
        let request = CreateBudgetRequest(
            year: 2026, totalBudget: dec("1000"), recipients: [BudgetLimit(recipientId: "p-a", maxSpend: dec("400"))]
        )
        #expect(sut.manager.calls == [.create(request)])
        #expect(sut.model.banner == nil)
        #expect(sut.model.isSaving == false)
        #expect(sut.budgets.budget(for: 2026) == stored, "the service cached the returned budget")
    }

    @Test("create uses the chosen year")
    func createChosenYear() async {
        let sut = makeBudgetEditorSUT(mode: .create(years: [2026, 2027], defaultYear: 2026))
        sut.model.setTotalText("200")
        sut.model.setYear(2027)
        sut.manager.enqueue(EditorTest.stored(year: 2027, total: "200"))

        let saved = await sut.model.save()

        #expect(saved?.year == 2027)
        #expect(sut.manager.calls == [.create(CreateBudgetRequest(year: 2027, totalBudget: dec("200"), recipients: []))])
    }

    @Test("a total-only budget is saved with an empty recipients array")
    func totalOnlyCreate() async {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("300.50")
        sut.manager.enqueue(EditorTest.stored(total: "300.50"))

        let saved = await sut.model.save()

        #expect(saved != nil)
        #expect(sut.manager.calls == [.create(CreateBudgetRequest(year: 2026, totalBudget: dec("300.50"), recipients: []))])
    }

    @Test("save does nothing when Save is disabled")
    func saveWhenDisabled() async {
        let sut = makeBudgetEditorSUT()

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.manager.callCount == 0)
        #expect(sut.model.banner == nil)
    }

    // MARK: Edit

    @Test("edit sends only the total when only the total changed")
    func editOnlyTotal() async {
        let sut = makeEditEditorSUT()
        sut.model.setTotalText("600")
        let stored = EditorTest.stored(year: 2026, total: "600")
        sut.manager.enqueue(stored)

        let saved = await sut.model.save()

        #expect(saved == stored)
        #expect(sut.manager.calls == [.update(UpdateBudgetRequest(year: 2026, totalBudget: dec("600"), recipients: nil))])
    }

    @Test("edit sends only the full recipient list when only a limit changed")
    func editOnlyLimit() async {
        let sut = makeEditEditorSUT()
        sut.model.setLimitText("210", for: "r1")
        sut.manager.enqueue(EditorTest.stored(year: 2026, total: "500"))

        _ = await sut.model.save()

        let limits = [
            BudgetLimit(recipientId: "r1", maxSpend: dec("210")),
            BudgetLimit(recipientId: "r2", maxSpend: dec("250"))
        ]
        #expect(sut.manager.calls == [.update(UpdateBudgetRequest(year: 2026, totalBudget: nil, recipients: limits))])
    }

    @Test("edit sends the full list when a person was added, and the total only if it changed too")
    func editPersonAdded() async {
        let sut = makeEditEditorSUT()
        sut.model.addPerson(EditorTest.alex)
        sut.model.setLimitText("10", for: "p-a")
        sut.manager.enqueue(EditorTest.stored(year: 2026, total: "500"))

        _ = await sut.model.save()

        let limits = [
            BudgetLimit(recipientId: "r1", maxSpend: dec("200")),
            BudgetLimit(recipientId: "r2", maxSpend: dec("250")),
            BudgetLimit(recipientId: "p-a", maxSpend: dec("10"))
        ]
        #expect(sut.manager.calls == [.update(UpdateBudgetRequest(year: 2026, totalBudget: nil, recipients: limits))])
    }

    @Test("edit sends the shorter list when a person was removed")
    func editPersonRemoved() async {
        let sut = makeEditEditorSUT()
        sut.model.removePerson(recipientId: "r2")
        sut.manager.enqueue(EditorTest.stored(year: 2026, total: "500"))

        _ = await sut.model.save()

        let limits = [BudgetLimit(recipientId: "r1", maxSpend: dec("200"))]
        #expect(sut.manager.calls == [.update(UpdateBudgetRequest(year: 2026, totalBudget: nil, recipients: limits))])
    }

    @Test("edit sends the total and the list when both changed")
    func editTotalAndLimit() async {
        let sut = makeEditEditorSUT()
        sut.model.setTotalText("700")
        sut.model.setLimitText("300", for: "r2")
        sut.manager.enqueue(EditorTest.stored(year: 2026, total: "700"))

        _ = await sut.model.save()

        let limits = [
            BudgetLimit(recipientId: "r1", maxSpend: dec("200")),
            BudgetLimit(recipientId: "r2", maxSpend: dec("300"))
        ]
        #expect(sut.manager.calls == [.update(UpdateBudgetRequest(year: 2026, totalBudget: dec("700"), recipients: limits))])
    }

    @Test("edit with nothing changed sends nothing")
    func editNothingChanged() async {
        let sut = makeEditEditorSUT()

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.manager.callCount == 0)
    }

    // MARK: Errors

    @Test("a failed save returns nil and shows the banner with the message and actions of the error",
          arguments: MutationFailureCases.all)
    func failedSaveBanner(failure: MutationFailureCase) async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(failure.error)

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.model.banner == InlineErrorBannerState(message: failure.message, actions: failure.actions))
        #expect(sut.model.isSaving == false)
        #expect(sut.budgets.budgetsByYear.isEmpty, "a failed save stores nothing")
    }

    @Test("a 409 on create shows its message inside the sheet")
    func conflictMessage() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.alreadyExists(message: "You already have a budget for 2026."))

        _ = await sut.model.save()

        #expect(sut.model.banner?.message == "You already have a budget for 2026.")
    }

    @Test("a 422 sum error shows its message inside the sheet")
    func sumErrorMessage() async {
        let sut = makeEditEditorSUT()
        sut.model.setTotalText("600")
        sut.manager.enqueueFailure(BudgetError.sumExceedsTotal(message: "Limits add up to more than the total"))

        _ = await sut.model.save()

        #expect(sut.model.banner?.message == "Limits add up to more than the total")
    }

    @Test("a 400 INVALID_PRICE shows the validation message")
    func invalidPriceMessage() async {
        let sut = makeBudgetEditorSUT()
        sut.model.setTotalText("300")
        sut.manager.enqueueFailure(BudgetError.validation(message: "Price must have at most two decimals."))

        _ = await sut.model.save()

        #expect(sut.model.banner?.message == "Price must have at most two decimals.")
        #expect(sut.model.banner?.actions == [.dismiss])
    }

    @Test("Dismiss removes the banner and keeps the draft")
    func dismissBanner() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.network)
        _ = await sut.model.save()
        #expect(sut.model.banner != nil)
        let draft = sut.model.draft

        sut.model.dismissBanner()

        #expect(sut.model.banner == nil)
        #expect(sut.model.draft == draft)
    }

    @Test("a retry that succeeds clears the banner and returns the budget")
    func retrySuccessClearsBanner() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.network)
        let first = await sut.model.save()
        #expect(first == nil)
        #expect(sut.model.banner?.actions == [.tryAgain, .dismiss])
        let stored = EditorTest.stored()
        sut.manager.enqueue(stored)

        let second = await sut.model.save()

        #expect(second == stored)
        #expect(sut.model.banner == nil)
        #expect(sut.manager.callCount == 2)
    }

    @Test("the error lives only in the model: the service caches nothing and publishes no error")
    func errorIsLocal() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(BudgetError.alreadyExists(message: "You already have a budget for 2026."))

        _ = await sut.model.save()

        #expect(sut.model.banner != nil)
        #expect(sut.budgets.budgetsByYear.isEmpty)
        #expect(sut.budgets.isLoading == false)
    }

    // MARK: Cancellation and double tap

    @Test("a cancelled save returns nil with no banner and stores nothing")
    func cancelledSave() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        sut.manager.enqueueFailure(CancellationError())

        let saved = await sut.model.save()

        #expect(saved == nil)
        #expect(sut.model.banner == nil)
        #expect(sut.model.isSaving == false)
        #expect(sut.budgets.budgetsByYear.isEmpty)
    }

    @Test("a second save while saving is ignored")
    func secondSaveIsIgnored() async {
        let sut = makeBudgetEditorSUT()
        sut.fillValidCreateDraft()
        let stored = EditorTest.stored()
        sut.manager.enqueue(stored, held: true)

        let first = Task { @MainActor in await sut.model.save() }
        await sut.manager.gate.nextHeldCall()
        #expect(sut.model.isSaving == true)
        #expect(sut.model.canSave == false, "Save is disabled while saving")

        let second = await sut.model.save()
        #expect(second == nil)
        #expect(sut.manager.callCount == 1, "the second tap did not reach the repository")

        sut.manager.gate.releaseAll()
        let firstResult = await first.value
        #expect(firstResult == stored)
        #expect(sut.model.isSaving == false)
        #expect(sut.manager.callCount == 1)
        #expect(sut.model.banner == nil)
    }
}
