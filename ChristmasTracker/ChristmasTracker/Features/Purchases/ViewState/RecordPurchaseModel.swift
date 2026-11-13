//
//  RecordPurchaseModel.swift
//  ChristmasTracker
//
//  The controller behind the Record Purchase form. It drives the pure RecordPurchaseFlow and calls
//  PurchaseService. Every action is a no-op when the list's capability flag does not allow a
//  purchase (no role is ever read). It never computes a status, a count or a remaining value and
//  never refreshes anything: `finish == .recorded` is its only success signal.
//
//  The confirmation answer is held only inside the flow's pending confirmation, and the value
//  sent with the one service call is a local. Nothing here logs or exposes it.
//

import Foundation
import Observation

nonisolated enum RecordPurchaseFinish: Equatable, Sendable {
    case recorded(RecordedPurchase)
    case itemGone
    case cancelled
    /// After an unconfirmed failure: close the form so the host can force-refresh the item.
    case checkItem
}

@MainActor
@Observable
final class RecordPurchaseModel {

    // MARK: - Dependencies

    private let item: ListItem
    private let context: ItemListContext
    private let service: PurchaseService
    private let now: @Sendable () -> Date
    private let currencyCode: String
    private let locale: Locale

    // MARK: - State

    private var storedInput: RecordPurchaseFormInput
    private(set) var flow: RecordPurchaseFlow
    private(set) var finish: RecordPurchaseFinish?
    /// The binding of the confirmation dialog on the Record button.
    var isShowingOverPurchasePrompt = false
    /// The draft of the request in flight or awaiting confirmation; reused by the confirmed resubmit and retry.
    private var activeDraft: PurchaseDraft?
    /// Counts the confirmations shown, so the view restarts its expiry timer for a replacement.
    private(set) var awaitingEpoch = 0

    // MARK: - Initialization

    init(
        item: ListItem,
        context: ItemListContext,
        service: PurchaseService,
        now: @escaping @Sendable () -> Date = { Date() },
        currencyCode: String = "USD",
        locale: Locale = .current
    ) {
        self.item = item
        self.context = context
        self.service = service
        self.now = now
        self.currencyCode = currencyCode
        self.locale = locale
        self.flow = RecordPurchaseFlow(now: now)
        let known = context.capabilities.canSeeGiftActivity ? item.quantityRemaining : nil
        self.storedInput = RecordPurchaseFormInput(
            quantity: RecordPurchaseFormState.defaultQuantity(quantityRemaining: known),
            totalCostText: "",
            storeName: "",
            notes: "",
            confirmationNumber: "",
            trackingNumber: ""
        )
    }

    // MARK: - Derived state

    /// An assignment while the fields are read-only is ignored.
    var input: RecordPurchaseFormInput {
        get { storedInput }
        set {
            guard !flow.fieldsAreReadOnly else { return }
            storedInput = newValue
        }
    }

    var isAllowed: Bool { context.capabilities.canPurchase }

    var summary: RecordPurchaseItemSummary? {
        guard isAllowed else { return nil }
        return RecordPurchaseItemSummary(
            item: item, capabilities: context.capabilities, currencyCode: currencyCode, locale: locale
        )
    }

    var formState: RecordPurchaseFormState {
        let known = context.capabilities.canSeeGiftActivity ? item.quantityRemaining : nil
        return RecordPurchaseFormState(
            input: storedInput, quantityRemaining: known, currencyCode: currencyCode, locale: locale
        )
    }

    var fieldsAreReadOnly: Bool { flow.fieldsAreReadOnly }

    var overPurchasePrompt: OverPurchasePrompt? {
        guard isAllowed, isEditingOrFailed else { return nil }
        return formState.overPurchasePrompt
    }

    var panel: BudgetWarningPanelState? {
        guard isAllowed, case .awaitingConfirmation(let pending) = flow.state else { return nil }
        return BudgetWarningPanelState(
            warnings: pending.warnings, notice: pending.notice, currencyCode: currencyCode, locale: locale
        )
    }

    var showsExpired: Bool { isAllowed && flow.state == .expired }

    var errorBanner: InlineErrorBannerState? {
        guard isAllowed, case .failed(let error) = flow.state else { return nil }
        return RecordPurchaseErrorPresentation.banner(for: error)
    }

    var showsRecordButton: Bool {
        guard isAllowed else { return false }
        switch flow.state {
        case .editing, .submitting, .failed: return true
        case .awaitingConfirmation, .expired, .recorded: return false
        }
    }

    var canTapRecord: Bool { isAllowed && isEditingOrFailed && formState.isValid }

    var isSubmitting: Bool {
        if case .submitting = flow.state { return true }
        return false
    }

    /// The time left until the 4:30 expiry; nil outside awaiting confirmation; never negative.
    var expiryDelay: Duration? {
        guard isAllowed, case .awaitingConfirmation(let pending) = flow.state else { return nil }
        let left = pending.issuedAt.timeIntervalSince(now()) + RecordPurchaseFlow.confirmationLifetime
        return .seconds(max(0, left))
    }

    private var isEditingOrFailed: Bool {
        switch flow.state {
        case .editing, .failed: return true
        case .submitting, .awaitingConfirmation, .expired, .recorded: return false
        }
    }

    // MARK: - Actions

    func recordTapped() async {
        guard canTapRecord else { return }
        if overPurchasePrompt != nil {
            isShowingOverPurchasePrompt = true
            return
        }
        await submit()
    }

    func confirmOverPurchase() async {
        isShowingOverPurchasePrompt = false
        guard canTapRecord else { return }
        await submit()
    }

    func confirmBudget() async {
        guard isAllowed else { return }
        guard case .send(let confirmationToken)? = flow.handle(.confirm) else { return }
        guard let draft = activeDraft ?? formState.draft else {
            _ = flow.handle(.serverError(.server))
            return
        }
        await perform(draft: draft, confirmationToken: confirmationToken)
    }

    func editDetails() {
        guard isAllowed else { return }
        _ = flow.handle(.editDetails)
        dropDraftIfEditing()
    }

    func cancel() {
        guard isAllowed else { return }
        if flow.handle(.cancel) == .close {
            activeDraft = nil
            finish = .cancelled
        }
    }

    func retry() async {
        guard isAllowed, let draft = activeDraft else { return }
        guard case .send(let confirmationToken)? = flow.handle(.retry) else { return }
        await perform(draft: draft, confirmationToken: confirmationToken)
    }

    /// After an unconfirmed failure only: closes the form so the item can be checked.
    func checkItem() {
        guard isAllowed else { return }
        if flow.handle(.checkItem) == .checkItem {
            activeDraft = nil
            finish = .checkItem
        }
    }

    /// After an unconfirmed failure only: a fresh submit of the same draft with no token, which
    /// runs the budget confirmation again.
    func recordAgain() async {
        guard isAllowed else { return }
        guard case .send(let confirmationToken)? = flow.handle(.recordAgain) else { return }
        guard let draft = activeDraft else {
            _ = flow.handle(.serverError(.server))
            return
        }
        await perform(draft: draft, confirmationToken: confirmationToken)
    }

    func dismissError() {
        guard isAllowed else { return }
        _ = flow.handle(.dismissError)
        dropDraftIfEditing()
    }

    func expiryReached() {
        guard isAllowed else { return }
        _ = flow.handle(.clockTick)
    }

    // MARK: - Private

    private func dropDraftIfEditing() {
        if flow.state == .editing { activeDraft = nil }
    }

    private func submit() async {
        guard let draft = formState.draft else { return }
        if case .failed = flow.state {
            _ = flow.handle(.dismissError)
        }
        guard case .send(let confirmationToken)? = flow.handle(.submit) else { return }
        activeDraft = draft
        await perform(draft: draft, confirmationToken: confirmationToken)
    }

    private func perform(draft: PurchaseDraft, confirmationToken: String?) async {
        do {
            let outcome = try await service.recordPurchase(
                itemId: item.id, draft: draft, confirmationToken: confirmationToken
            )
            apply(outcome)
        } catch let error as PurchaseError {
            _ = flow.handle(.serverError(error))
            if error.closesForm { finish = .itemGone }
        } catch is CancellationError {
            _ = flow.handle(.serverError(.sessionEnded))
        } catch {
            _ = flow.handle(.serverError(.server))
        }
    }

    private func apply(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .created(let purchase):
            _ = flow.handle(.serverCreated(purchase))
            activeDraft = nil
            finish = .recorded(purchase)
        case .confirmationRequired(let warnings, let confirmationToken):
            _ = flow.handle(.serverConfirmationRequired(warnings: warnings, token: confirmationToken))
            awaitingEpoch += 1
        }
    }
}
