//
//  RecordPurchaseFlow.swift
//  ChristmasTracker
//
//  The pure state machine of recording a purchase, including the budget confirmation. The clock
//  is injected. The confirmation token lives only inside `awaitingConfirmation` and in the
//  `send` effect; it is gone from the state after every transition out of it.
//

import Foundation

nonisolated struct PendingConfirmation: Equatable, Sendable {
    let warnings: [BudgetWarning]
    let token: String
    let issuedAt: Date
    let notice: String?
}

nonisolated enum RecordPurchaseFlowState: Equatable, Sendable {
    case editing
    /// Carries no token.
    case submitting(isConfirmed: Bool)
    case awaitingConfirmation(PendingConfirmation)
    /// The expired message with one button back to editing.
    case expired
    case recorded(RecordedPurchase)
    case failed(RecordPurchaseError)
}

nonisolated enum RecordPurchaseFlowEvent: Equatable, Sendable {
    case submit
    case serverCreated(RecordedPurchase)
    case serverConfirmationRequired(warnings: [BudgetWarning], token: String)
    case serverError(RecordPurchaseError)
    case confirm
    case cancel
    case editDetails
    case clockTick
    case retry
    case dismissError
}

nonisolated enum RecordPurchaseFlowEffect: Equatable, Sendable {
    /// The caller performs the request with the same draft.
    case send(confirmationToken: String?)
    /// The form closes without recording.
    case close
}

nonisolated struct RecordPurchaseFlow: Sendable {
    /// 4 minutes 30 seconds. The server's confirmation limit is 5 minutes; the client expires
    /// the confirmation earlier so a stale token is never sent. This is the only place it lives.
    static let confirmationLifetime: TimeInterval = 270

    private let now: @Sendable () -> Date
    private(set) var state: RecordPurchaseFlowState = .editing

    init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    var fieldsAreReadOnly: Bool {
        switch state {
        case .submitting, .awaitingConfirmation, .expired, .recorded: return true
        case .editing, .failed: return false
        }
    }

    var noticeText: String? {
        if case .awaitingConfirmation(let pending) = state { return pending.notice }
        return nil
    }

    mutating func handle(_ event: RecordPurchaseFlowEvent) -> RecordPurchaseFlowEffect? {
        switch state {
        case .editing:
            return handleEditing(event)
        case .submitting(let isConfirmed):
            return handleSubmitting(event, isConfirmed: isConfirmed)
        case .awaitingConfirmation(let pending):
            return handleAwaiting(event, pending: pending)
        case .expired:
            return handleLeavable(event, allowing: [.editDetails])
        case .failed:
            if event == .retry {
                state = .submitting(isConfirmed: false)
                return .send(confirmationToken: nil)
            }
            return handleLeavable(event, allowing: [.dismissError, .editDetails])
        case .recorded:
            return nil
        }
    }

    private mutating func handleEditing(_ event: RecordPurchaseFlowEvent) -> RecordPurchaseFlowEffect? {
        switch event {
        case .submit:
            state = .submitting(isConfirmed: false)
            return .send(confirmationToken: nil)
        case .cancel:
            return .close
        default:
            return nil
        }
    }

    private mutating func handleSubmitting(
        _ event: RecordPurchaseFlowEvent,
        isConfirmed: Bool
    ) -> RecordPurchaseFlowEffect? {
        switch event {
        case .serverCreated(let purchase):
            state = .recorded(purchase)
        case .serverConfirmationRequired(let warnings, let token):
            state = .awaitingConfirmation(PendingConfirmation(
                warnings: warnings,
                token: token,
                issuedAt: now(),
                notice: isConfirmed ? RecordPurchaseCopy.budgetChangedNotice : nil
            ))
        case .serverError(let error):
            state = .failed(error)
        default:
            break
        }
        return nil
    }

    private mutating func handleAwaiting(
        _ event: RecordPurchaseFlowEvent,
        pending: PendingConfirmation
    ) -> RecordPurchaseFlowEffect? {
        let isExpired = now().timeIntervalSince(pending.issuedAt) >= Self.confirmationLifetime
        switch event {
        case .confirm:
            if isExpired {
                state = .expired
                return nil
            }
            state = .submitting(isConfirmed: true)
            return .send(confirmationToken: pending.token)
        case .editDetails:
            state = .editing
        case .cancel:
            state = .editing
            return .close
        case .clockTick:
            if isExpired { state = .expired }
        default:
            break
        }
        return nil
    }

    /// Shared tail of expired and failed: the listed events go back to editing, cancel closes.
    private mutating func handleLeavable(
        _ event: RecordPurchaseFlowEvent,
        allowing events: [RecordPurchaseFlowEvent]
    ) -> RecordPurchaseFlowEffect? {
        if event == .cancel {
            state = .editing
            return .close
        }
        if events.contains(event) { state = .editing }
        return nil
    }
}
