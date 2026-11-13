//
//  StatsScreenModelDeleteTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the delete flow of StatsScreenModel. The confirmation state lives in the model above any
//  row; success removes the budget and refreshes the stats; hasPurchases keeps the budget and shows the
//  server's message as a banner on the budget card; notFound counts as deleted; a cancelled delete sets
//  nothing; the card banner is local (dismiss, year change and leaving clear it) and nothing is written to
//  any shared error property.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenModel delete Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelDeleteTests {

    private let serverMessage = "Delete the purchases first."

    // MARK: Strings and confirmation state

    @Test("the delete strings are exactly as the brief says")
    func deleteStrings() {
        #expect(StatsScreenModel.deleteTitle(year: 2026) == "Delete the 2026 budget?")
        #expect(StatsScreenModel.deleteTitle(year: 2031) == "Delete the 2031 budget?")
        #expect(StatsScreenModel.deleteMessage == "Your spending is not affected. This can't be undone.")
        #expect(StatsScreenModel.deleteButtonTitle == "Delete Budget")
    }

    @Test("requestDelete raises the confirmation flag owned by the model, and the flag can be lowered")
    func requestDeleteSetsFlag() async {
        let sut = await makeLoadedStatsScreenSUT()
        #expect(sut.model.isShowingDeleteConfirmation == false)

        sut.model.requestDelete()
        #expect(sut.model.isShowingDeleteConfirmation == true)

        sut.model.isShowingDeleteConfirmation = false
        #expect(sut.model.isShowingDeleteConfirmation == false)
    }

    @Test("requestDelete alone calls no repository")
    func requestDeleteIsLocal() async {
        let sut = await makeLoadedStatsScreenSUT()
        let calls = sut.manager.callCount

        sut.model.requestDelete()

        #expect(sut.manager.callCount == calls)
    }

    // MARK: Success

    @Test("a confirmed delete calls the service, removes the budget from the screen and refreshes the stats")
    func confirmDeleteSuccess() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        #expect(sut.model.screenState?.kind == .budgeted)
        sut.manager.enqueueDeleted()
        sut.loader.enqueue(StatsScreenTest.statsWithoutBudget())

        sut.model.requestDelete()
        await sut.model.confirmDelete()

        #expect(sut.manager.calls.last == .delete(year: 2026))
        #expect(sut.budgets.budget(for: 2026) == nil)
        #expect(sut.loader.callCount == 2, "the stats are refreshed after the delete")
        #expect(sut.model.screenState?.budgetCard == nil)
        #expect(sut.model.screenState?.kind == .purchasesWithoutBudget)
        #expect(sut.model.showsCreateBudget == true)
        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("a notFound answer counts as already deleted: no banner, budget removed, stats refreshed")
    func confirmDeleteNotFound() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        sut.manager.enqueueFailure(BudgetError.notFound)
        sut.loader.enqueue(StatsScreenTest.statsWithoutBudget())

        await sut.model.confirmDelete()

        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.budgets.budget(for: 2026) == nil)
        #expect(sut.loader.callCount == 2)
        #expect(sut.model.screenState?.budgetCard == nil)
    }

    // MARK: Failure

    @Test("hasPurchases shows the server's message on the card and the budget stays")
    func confirmDeleteHasPurchases() async {
        let sut = await makeLoadedStatsScreenSUT(budgets: [BudgetServiceFix.budget(2026)])
        let before = sut.model.screenState

        await sut.showCardBanner(message: serverMessage)

        #expect(sut.model.budgetCardBanner == InlineErrorBannerState(message: serverMessage, actions: [.dismiss]))
        #expect(sut.budgets.budget(for: 2026) != nil, "the service keeps the budget")
        #expect(sut.model.screenState?.budgetCard != nil)
        #expect(sut.model.screenState == before)
    }

    @Test("a retryable delete error still offers only Dismiss on the card banner")
    func retryableDeleteErrorOnlyDismiss() async {
        let sut = await makeLoadedStatsScreenSUT()
        sut.manager.enqueueFailure(BudgetError.network)

        await sut.model.confirmDelete()

        let banner = sut.model.budgetCardBanner
        #expect(banner == InlineErrorBannerState(message: BudgetError.network.userMessage, actions: [.dismiss]))
        #expect(sut.budgets.budget(for: 2026) != nil)
    }

    @Test("a failed delete writes to no shared error property")
    func failedDeleteIsScoped() async {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.showCardBanner(message: serverMessage)

        #expect(sut.stats.loadFailure == nil, "the stats service's load failure is only for loads")
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.loadPhase == .content)
    }

    @Test("a cancelled delete sets no banner and removes nothing")
    func cancelledDeleteSetsNothing() async {
        let sut = await makeLoadedStatsScreenSUT()
        sut.manager.enqueueFailure(CancellationError())

        await sut.model.confirmDelete()

        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
        #expect(sut.budgets.budget(for: 2026) != nil)
        #expect(sut.model.screenState?.budgetCard != nil)
    }

    // MARK: Banner lifetime

    @Test("dismissing the card banner removes it")
    func dismissCardBanner() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.showCardBanner()
        #expect(sut.model.budgetCardBanner != nil)

        sut.model.dismissBudgetCardBanner()

        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.budgets.budget(for: 2026) != nil)
    }

    @Test("changing the year clears the card banner")
    func yearChangeClearsCardBanner() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.showCardBanner()
        sut.loader.enqueue(StatsFix.year(2025))

        await sut.model.select(year: 2025)

        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("leaving the screen clears the card banner")
    func disappearClearsCardBanner() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.showCardBanner()

        sut.model.onDisappear()

        #expect(sut.model.budgetCardBanner == nil)
    }

    @Test("a later successful delete clears an earlier card banner")
    func laterSuccessClearsBanner() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.showCardBanner()
        #expect(sut.model.budgetCardBanner != nil)
        sut.manager.enqueueDeleted()
        sut.loader.enqueue(StatsScreenTest.statsWithoutBudget())

        await sut.model.confirmDelete()

        #expect(sut.model.budgetCardBanner == nil)
        #expect(sut.budgets.budget(for: 2026) == nil)
    }
}
