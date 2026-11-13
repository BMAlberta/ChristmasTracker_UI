//
//  StatsScreenModel.swift
//  ChristmasTracker
//
//  I5a Story C: the logic of the Statistics tab. The view renders this state and sends events. The
//  model reads the cached stats and budgets from the two services, owns the delete confirmation above
//  every row, owns the sheet being presented, and holds its own errors: the stats service's load
//  failure (screen scoped, cleared on disappear), the budget list failure of this screen, and the card
//  banner of a failed delete. Nothing here is shared with another screen and nothing is logged.
//

import Foundation
import Observation

@MainActor
@Observable
final class StatsScreenModel {

    // MARK: - Types

    enum LoadPhase: Equatable {
        case loading
        case failed(message: String)
        case content
    }

    enum Sheet: Identifiable, Equatable {
        case create
        case edit(Budget)
        case duplicate(Budget)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let budget): "edit-\(budget.year)"
            case .duplicate(let budget): "duplicate-\(budget.year)"
            }
        }
    }

    // MARK: - Strings

    static let staleMessage = "Couldn't update. Showing saved data."
    static let deleteMessage = "Your spending is not affected. This can't be undone."
    static let deleteButtonTitle = "Delete Budget"

    static func deleteTitle(year: Int) -> String {
        "Delete the \(year) budget?"
    }

    let createBudgetTitle = "Create Budget"

    // MARK: - Dependencies

    private let statsService: StatsService
    private let budgetService: BudgetService
    private let listService: ListService
    private let currencyCode: String
    private let locale: Locale

    // MARK: - State

    let currentYear: Int
    var selectedYear: Int
    var isShowingDeleteConfirmation = false
    var presentedSheet: Sheet?
    private(set) var budgetCardBanner: InlineErrorBannerState?

    /// The budget list failure of this screen; cleared at the next load and on disappear.
    private var budgetListFailure: BudgetError?

    /// Counts the loads that ended with a failure, so a new identical failure is a new event.
    private var failureCount = 0
    private var dismissedFailureCount: Int?

    // MARK: - Initialization

    init(
        statsService: StatsService,
        budgetService: BudgetService,
        listService: ListService,
        now: @escaping @MainActor () -> Date,
        calendar: Calendar,
        currencyCode: String,
        locale: Locale
    ) {
        self.statsService = statsService
        self.budgetService = budgetService
        self.listService = listService
        self.currencyCode = currencyCode
        self.locale = locale
        let year = BudgetYearChoices.currentYear(now: now(), calendar: calendar)
        self.currentYear = year
        self.selectedYear = year
    }

    // MARK: - Derived state

    var yearChoices: [Int] {
        BudgetYearChoices.pickerYears(
            availableYears: statsService.stats(for: selectedYear)?.availableYears ?? [],
            budgetYears: Array(budgetService.budgetsByYear.keys),
            currentYear: currentYear
        )
    }

    var screenState: StatsScreenState? {
        guard let stats = statsService.stats(for: selectedYear) else { return nil }
        return StatsScreenState.make(
            year: selectedYear,
            stats: stats,
            budget: budgetService.budget(for: selectedYear),
            currencyCode: currencyCode,
            locale: locale
        )
    }

    var showsCreateBudget: Bool { screenState?.showsCreateBudget ?? false }

    /// The failure of the last load: the stats service's, else this screen's own.
    private var loadError: BudgetError? {
        statsService.loadFailure ?? budgetListFailure
    }

    var loadPhase: LoadPhase {
        if screenState != nil { return .content }
        if let loadError { return .failed(message: loadError.userMessage) }
        return .loading
    }

    var staleBanner: InlineErrorBannerState? {
        guard screenState != nil, loadError != nil, dismissedFailureCount != failureCount else { return nil }
        return InlineErrorBannerState(message: Self.staleMessage, actions: [.tryAgain, .dismiss])
    }

    var failureBanner: InlineErrorBannerState? {
        guard screenState == nil, let loadError else { return nil }
        return InlineErrorBannerState(
            message: loadError.userMessage,
            actions: loadError.isRetryable ? [.tryAgain] : []
        )
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await load(force: false)
    }

    func onDisappear() {
        statsService.clearLoadFailure()
        budgetListFailure = nil
        dismissedFailureCount = nil
        budgetCardBanner = nil
    }

    /// Pull to refresh: both fetches are forced.
    func refresh() async {
        await load(force: true)
    }

    func tryAgain() async {
        await load(force: true)
    }

    func select(year: Int) async {
        selectedYear = year
        budgetCardBanner = nil
        await load(force: false)
    }

    func dismissStaleBanner() {
        dismissedFailureCount = failureCount
    }

    // MARK: - Delete

    func requestDelete() {
        isShowingDeleteConfirmation = true
    }

    func confirmDelete() async {
        isShowingDeleteConfirmation = false
        budgetCardBanner = nil
        let year = selectedYear
        do {
            try await budgetService.delete(year: year)
        } catch is CancellationError {
            return
        } catch let failure as BudgetError {
            budgetCardBanner = InlineErrorBannerState(message: failure.userMessage, actions: [.dismiss])
            return
        } catch {
            budgetCardBanner = InlineErrorBannerState(message: BudgetError.server.userMessage, actions: [.dismiss])
            return
        }
        await statsService.refresh(year: year)
        noteLoadOutcome()
    }

    func dismissBudgetCardBanner() {
        budgetCardBanner = nil
    }

    // MARK: - Sheets

    func presentCreate() {
        presentedSheet = .create
    }

    func presentEdit() {
        guard let budget = budgetService.budget(for: selectedYear) else { return }
        presentedSheet = .edit(budget)
    }

    func presentDuplicate() {
        guard let budget = budgetService.budget(for: selectedYear) else { return }
        presentedSheet = .duplicate(budget)
    }

    func makeEditorModel(for sheet: Sheet) -> BudgetEditorModel? {
        let mode: BudgetEditorModel.Mode
        let spendYear: Int
        switch sheet {
        case .create:
            let budgetYears = Array(budgetService.budgetsByYear.keys)
            mode = .create(
                years: BudgetYearChoices.createYears(budgetYears: budgetYears, currentYear: currentYear),
                defaultYear: BudgetYearChoices.defaultCreateYear(budgetYears: budgetYears, currentYear: currentYear)
            )
            spendYear = selectedYear
        case .edit(let budget):
            mode = .edit(budget)
            spendYear = budget.year
        case .duplicate:
            return nil
        }
        return BudgetEditorModel(
            mode: mode,
            budgetService: budgetService,
            listService: listService,
            spend: statsService.stats(for: spendYear)?.spendByRecipient ?? [],
            locale: locale,
            currencyCode: currencyCode
        )
    }

    func makeDuplicateModel(for budget: Budget) -> DuplicateBudgetModel {
        let budgetYears = Array(budgetService.budgetsByYear.keys)
        return DuplicateBudgetModel(
            source: budget,
            budgetService: budgetService,
            years: BudgetYearChoices.duplicateYears(budgetYears: budgetYears, currentYear: currentYear),
            defaultYear: BudgetYearChoices.defaultDuplicateYear(budgetYears: budgetYears, currentYear: currentYear)
        )
    }

    func didSave(_ budget: Budget) async {
        await finishSheet(showing: budget)
    }

    func didDuplicate(_ budget: Budget) async {
        await finishSheet(showing: budget)
    }

    // MARK: - Private

    /// Closes the sheet, shows the returned budget (already cached by the service) and refreshes the
    /// stats of its year even when they are cached.
    private func finishSheet(showing budget: Budget) async {
        presentedSheet = nil
        budgetCardBanner = nil
        selectedYear = budget.year
        await statsService.refresh(year: budget.year)
        noteLoadOutcome()
    }

    private func load(force: Bool) async {
        budgetListFailure = nil
        let year = selectedYear
        budgetListFailure = await budgetService.loadBudgets(force: force)
        if force {
            await statsService.refresh(year: year)
        } else {
            await statsService.load(year: year)
        }
        noteLoadOutcome()
    }

    private func noteLoadOutcome() {
        if loadError != nil { failureCount += 1 }
    }
}
