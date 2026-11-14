//
//  BudgetEditorModel.swift
//  ChristmasTracker
//
//  I5a Story C: the logic of the budget editor sheet (create and edit). It owns the draft, the live
//  validation and summary line, the person picker (loaded cache-first through the ListService) and the
//  save call. A mutation error is held only in this model's banner; the person picker never blocks
//  saving a total-only budget. Nothing here is logged.
//

import Foundation
import Observation

@MainActor
@Observable
final class BudgetEditorModel {

    // MARK: - Types

    enum Mode: Equatable {
        case create(years: [Int], defaultYear: Int?)
        case edit(Budget)
    }

    enum PickerState: Equatable {
        case loading
        case failed(message: String)
        case ready([BudgetRecipientOption])
    }

    private enum PickerLoad {
        case loading
        case failed(String)
        case loaded
    }

    // MARK: - Dependencies

    private let mode: Mode
    private let budgetService: BudgetService
    private let listService: ListService
    private let spend: [RecipientSpend]
    private let locale: Locale
    private let currencyCode: String

    // MARK: - State

    private(set) var draft: BudgetDraft
    private(set) var isSaving = false
    private(set) var banner: InlineErrorBannerState?
    private var pickerLoad: PickerLoad = .loading
    private var baseOptions: [BudgetRecipientOption] = []

    // MARK: - Initialization

    init(
        mode: Mode,
        budgetService: BudgetService,
        listService: ListService,
        spend: [RecipientSpend],
        locale: Locale,
        currencyCode: String
    ) {
        self.mode = mode
        self.budgetService = budgetService
        self.listService = listService
        self.spend = spend
        self.locale = locale
        self.currencyCode = currencyCode
        switch mode {
        case .create(let years, let defaultYear):
            draft = BudgetDraft(year: defaultYear ?? years.first ?? 0, totalText: "", recipients: [])
        case .edit(let budget):
            draft = BudgetDraft(
                year: budget.year,
                totalText: Self.amountText(budget.totalBudget, locale: locale),
                recipients: budget.recipients.map {
                    BudgetRecipientDraft(
                        recipientId: $0.recipientId,
                        name: $0.recipientName,
                        limitText: Self.amountText($0.maxSpend, locale: locale)
                    )
                }
            )
        }
    }

    // MARK: - Header

    var title: String {
        switch mode {
        case .create: "New Budget"
        case .edit(let budget): "\(budget.year) Budget"
        }
    }

    var availableYears: [Int] {
        switch mode {
        case .create(let years, _): years
        case .edit: []
        }
    }

    var isYearEditable: Bool {
        if case .create = mode { return true }
        return false
    }

    // MARK: - Validation

    var validation: BudgetValidation {
        BudgetValidation.validate(draft, locale: locale)
    }

    var summaryLine: String? {
        validation.summaryLine(currencyCode: currencyCode, locale: locale)
    }

    var summaryIsError: Bool {
        validation.issues.contains(.limitsExceedTotal)
    }

    var canSave: Bool {
        guard !isSaving, validation.isValid else { return false }
        switch mode {
        case .create(let years, _):
            return years.contains(draft.year)
        case .edit(let original):
            return BudgetRequestBuilder.hasChanges(draft: draft, original: original, locale: locale)
        }
    }

    // MARK: - Person picker

    var picker: PickerState {
        switch pickerLoad {
        case .loading: .loading
        case .failed(let reason): .failed(message: reason)
        case .loaded: .ready(BudgetRecipientOptions.unused(baseOptions, in: draft))
        }
    }

    /// Cache-first: the lists are fetched only when the service has none.
    func loadOptions() async {
        var loadFailure: ListError?
        if listService.lists.isEmpty {
            pickerLoad = .loading
            // The editor's failure goes to the picker state only: nothing the Lists screen reads.
            loadFailure = await listService.loadLists(reportingFailure: false)
        }
        if listService.lists.isEmpty, let loadFailure {
            // No saved people exist here, so the policy's answer is the full error (plain message).
            let presentation = ScreenLoadPresentation.make(
                hasCachedData: false,
                failures: [LoadFailure(loadFailure, source: .people)]
            )
            pickerLoad = .failed(presentation.fullError?.message ?? loadFailure.userMessage)
            return
        }
        baseOptions = BudgetRecipientOptions.build(
            lists: listService.lists,
            existing: existingRecipients,
            spend: spend
        )
        pickerLoad = .loaded
    }

    private var existingRecipients: [RecipientBudget] {
        if case .edit(let budget) = mode { return budget.recipients }
        return []
    }

    // MARK: - Editing

    func setTotalText(_ text: String) {
        draft.totalText = text
    }

    func setLimitText(_ text: String, for recipientId: String) {
        guard let index = draft.recipients.firstIndex(where: { $0.recipientId == recipientId }) else { return }
        draft.recipients[index].limitText = text
    }

    func setYear(_ year: Int) {
        draft.year = year
    }

    func addPerson(_ option: BudgetRecipientOption) {
        guard !draft.recipients.contains(where: { $0.recipientId == option.id }) else { return }
        draft.recipients.append(
            BudgetRecipientDraft(recipientId: option.id, name: option.displayName, limitText: "")
        )
    }

    func removePerson(recipientId: String) {
        draft.recipients.removeAll { $0.recipientId == recipientId }
    }

    // MARK: - Save

    func dismissBanner() {
        banner = nil
    }

    func save() async -> Budget? {
        guard canSave else { return nil }
        isSaving = true
        banner = nil
        defer { isSaving = false }
        do {
            switch mode {
            case .create:
                guard let request = BudgetRequestBuilder.create(draft: draft, locale: locale) else { return nil }
                return try await budgetService.create(request)
            case .edit(let original):
                guard let request = BudgetRequestBuilder.update(draft: draft, original: original, locale: locale)
                else { return nil }
                return try await budgetService.update(request)
            }
        } catch is CancellationError {
            return nil
        } catch let failure as BudgetError {
            banner = Self.bannerState(for: failure)
            return nil
        } catch {
            banner = Self.bannerState(for: .server)
            return nil
        }
    }

    // MARK: - Private

    private static func bannerState(for failure: BudgetError) -> InlineErrorBannerState {
        InlineErrorBannerState(
            message: failure.userMessage,
            actions: failure.isRetryable ? [.tryAgain, .dismiss] : [.dismiss]
        )
    }

    /// The amount as plain text with two decimals and no grouping, in the locale's decimal separator,
    /// so the amount parser accepts it back.
    private static func amountText(_ value: Decimal, locale: Locale) -> String {
        value.formatted(
            Decimal.FormatStyle(locale: locale)
                .precision(.fractionLength(2))
                .grouping(.never)
        )
    }
}
