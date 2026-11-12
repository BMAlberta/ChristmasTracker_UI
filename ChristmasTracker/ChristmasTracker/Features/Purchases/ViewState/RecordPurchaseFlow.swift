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

// MARK: - Token redaction
//
// Every type below stores a confirmation token. Descriptions, debug descriptions and Mirror
// children print `RedactedToken.placeholder` in its place; Equatable still compares the real
// tokens and the send effect still carries the real token.

nonisolated extension PendingConfirmation: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "PendingConfirmation(warnings: \(warnings.count), token: \(RedactedToken.placeholder), "
            + "issuedAt: \(issuedAt), notice: \(notice == nil ? "none" : "present"))"
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "warnings": warnings,
                "token": RedactedToken.placeholder,
                "issuedAt": issuedAt,
                "notice": notice as Any
            ],
            displayStyle: .struct
        )
    }
}

nonisolated extension RecordPurchaseFlowState: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        switch self {
        case .editing: return "editing"
        case .submitting(let isConfirmed): return "submitting(isConfirmed: \(isConfirmed))"
        case .awaitingConfirmation(let pending): return "awaitingConfirmation(\(pending))"
        case .expired: return "expired"
        case .recorded: return "recorded"
        case .failed: return "failed"
        }
    }

    var debugDescription: String { description }
}

nonisolated extension RecordPurchaseFlowEvent: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        switch self {
        case .submit: return "submit"
        case .serverCreated: return "serverCreated"
        case .serverConfirmationRequired(let warnings, _):
            return "serverConfirmationRequired(warnings: \(warnings.count), token: \(RedactedToken.placeholder))"
        case .serverError: return "serverError"
        case .confirm: return "confirm"
        case .cancel: return "cancel"
        case .editDetails: return "editDetails"
        case .clockTick: return "clockTick"
        case .retry: return "retry"
        case .dismissError: return "dismissError"
        }
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        switch self {
        case .serverConfirmationRequired(let warnings, _):
            return Mirror(
                self,
                children: ["serverConfirmationRequired": warnings, "token": RedactedToken.placeholder],
                displayStyle: .enum
            )
        default:
            return Mirror(self, children: [description: ()], displayStyle: .enum)
        }
    }
}

nonisolated extension RecordPurchaseFlowEffect: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        switch self {
        case .send(let token):
            return "send(confirmationToken: \(token == nil ? "nil" : RedactedToken.placeholder))"
        case .close:
            return "close"
        }
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        switch self {
        case .send(let token):
            return Mirror(
                self,
                children: ["send": token == nil ? "nil" : RedactedToken.placeholder],
                displayStyle: .enum
            )
        case .close:
            return Mirror(self, children: ["close": ()], displayStyle: .enum)
        }
    }
}

nonisolated extension RecordPurchaseFlow: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "RecordPurchaseFlow(state: \(state))" }

    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["state": state], displayStyle: .struct)
    }
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
