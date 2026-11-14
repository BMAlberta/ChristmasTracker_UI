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

    static let budgetNotFoundMessage = "Couldn't find that budget. Try again."
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

    /// The in-flight loads this model started, so onDisappear can cancel them.
    private var loadTasks: [UUID: Task<Void, Never>] = [:]

    /// The key in `loadTasks` of the Edit or Duplicate load-first task, which select(year:) cancels.
    private var loadFirstTaskId: UUID?

    /// The Edit or Duplicate step that Try Again of the card banner repeats.
    private var pendingBudgetStep: BudgetCardStep?

    private enum BudgetCardStep {
        case edit, duplicate
    }

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

    /// The failure of the last load of the SELECTED year: the stats service's failure for that
    /// year, else this screen's own. A failure of another year never shows here.
    private var loadError: BudgetError? {
        statsService.failure(forYear: selectedYear) ?? budgetListFailure
    }

    var loadPhase: LoadPhase {
        if screenState != nil { return .content }
        if let loadError { return .failed(message: loadError.userMessage) }
        return .loading
    }

    /// The stats failure of the selected year (source .stats) and this screen's budget list failure
    /// (source .budgets), the inputs of LoadFailurePolicy.
    private var loadFailures: [LoadFailure] {
        var failures: [LoadFailure] = []
        if let stats = statsService.failure(forYear: selectedYear) {
            failures.append(LoadFailure(stats, source: .stats))
        }
        if let budgets = budgetListFailure {
            failures.append(LoadFailure(budgets, source: .budgets))
        }
        return failures
    }

    /// The banners over saved data, from the policy: ONE for failures of the same category, at most
    /// two when the categories differ. Empty when dismissed, when nothing is saved, or when a gone
    /// resource or a session end takes over.
    var staleBanners: [InlineErrorBannerState] {
        guard screenState != nil, dismissedFailureCount != failureCount else { return [] }
        return ScreenLoadPresentation.make(hasCachedData: true, failures: loadFailures).banners
            .map { LoadBannerPresentation.state(for: $0) }
    }

    var staleBanner: InlineErrorBannerState? {
        staleBanners.first
    }

    /// The full error of a screen with nothing to show: Try Again only.
    var failureBanner: InlineErrorBannerState? {
        guard screenState == nil else { return nil }
        let presentation = ScreenLoadPresentation.make(hasCachedData: false, failures: loadFailures)
        guard let banner = presentation.fullError ?? presentation.banners.first else { return nil }
        return LoadBannerPresentation.state(for: banner, dismissible: false)
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await load(force: false)
    }

    func onDisappear() {
        for task in loadTasks.values { task.cancel() }
        statsService.clearLoadFailure()
        budgetListFailure = nil
        dismissedFailureCount = nil
        budgetCardBanner = nil
        pendingBudgetStep = nil
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
        if let id = loadFirstTaskId { loadTasks[id]?.cancel() }
        budgetCardBanner = nil
        pendingBudgetStep = nil
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
        pendingBudgetStep = nil
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
        // The follow-up refresh may fail: the deleted budget must not stay in the stats cache.
        statsService.dropBudget(year: year)
        await refreshStats(year: year)
    }

    func dismissBudgetCardBanner() {
        budgetCardBanner = nil
        pendingBudgetStep = nil
    }

    // MARK: - Sheets

    func presentCreate() {
        presentedSheet = .create
    }

    /// Opens the edit sheet. When the budget cache lacks the selected year (the stats show a
    /// budget the cache does not hold) the budgets are loaded first; a failed load sets a
    /// retryable card banner and opens nothing.
    func presentEdit() async {
        await present(.edit)
    }

    /// Like presentEdit, for the duplicate sheet.
    func presentDuplicate() async {
        await present(.duplicate)
    }

    /// Try Again of the card banner: repeats the step that failed (edit or duplicate). Does
    /// nothing when no step is pending.
    func retryBudgetCardAction() async {
        guard let step = pendingBudgetStep else { return }
        await present(step)
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
        pendingBudgetStep = nil
        selectedYear = budget.year
        await refreshStats(year: budget.year)
    }

    private func load(force: Bool) async {
        await runTracked { [self] in
            budgetListFailure = nil
            let year = selectedYear
            let listFailure = await budgetService.loadBudgets(force: force)
            if Task.isCancelled { return }
            if year == selectedYear { budgetListFailure = listFailure }
            if force {
                await statsService.refresh(year: year)
            } else {
                await statsService.load(year: year)
            }
            if Task.isCancelled { return }
            noteLoadOutcome()
        }
    }

    private func refreshStats(year: Int) async {
        await runTracked { [self] in
            await statsService.refresh(year: year)
            if Task.isCancelled { return }
            noteLoadOutcome()
        }
    }

    /// Runs `work` in a task the model owns, so onDisappear can cancel it. A cancelled task writes
    /// no failure (the services record nothing for a cancelled call) and the work skips its
    /// bookkeeping. Cancelling the caller cancels the task too.
    private func runTracked(isLoadFirst: Bool = false, _ work: @escaping @MainActor () async -> Void) async {
        let id = UUID()
        let task = Task { @MainActor in await work() }
        loadTasks[id] = task
        if isLoadFirst { loadFirstTaskId = id }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        loadTasks[id] = nil
        if loadFirstTaskId == id { loadFirstTaskId = nil }
    }

    private func present(_ step: BudgetCardStep) async {
        let year = selectedYear
        if let budget = budgetService.budget(for: year) {
            open(step, budget)
            return
        }
        pendingBudgetStep = step
        await runTracked(isLoadFirst: true) { [self] in
            let failure = await budgetService.loadBudgets(force: true)
            // A late completion of another year's step must neither open a sheet nor set a banner.
            if Task.isCancelled || year != selectedYear { return }
            if let failure {
                budgetCardBanner = InlineErrorBannerState(
                    message: failure.userMessage,
                    actions: [.tryAgain, .dismiss]
                )
                return
            }
            guard let budget = budgetService.budget(for: year) else {
                budgetCardBanner = InlineErrorBannerState(
                    message: Self.budgetNotFoundMessage,
                    actions: [.tryAgain, .dismiss]
                )
                return
            }
            open(step, budget)
        }
    }

    private func open(_ step: BudgetCardStep, _ budget: Budget) {
        budgetCardBanner = nil
        pendingBudgetStep = nil
        switch step {
        case .edit: presentedSheet = .edit(budget)
        case .duplicate: presentedSheet = .duplicate(budget)
        }
    }

    private func noteLoadOutcome() {
        if loadError != nil { failureCount += 1 }
    }
}
