//
//  PurchaseFlowHarness.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: construction and driving helpers for RecordPurchaseFlow tests. The flow is a
//  value type, so the harness keeps it in a var and exposes the effect of each event. The clock
//  is a PurchaseTestClock (fixed start date, explicit offsets, no real time).
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated struct PurchaseFlowHarness {
    var flow: RecordPurchaseFlow
    let clock: PurchaseTestClock

    static let tokenA = "tok-A-FAKE"
    static let tokenB = "tok-B-FAKE"

    init(clock: PurchaseTestClock = PurchaseTestClock()) {
        self.clock = clock
        self.flow = RecordPurchaseFlow(now: clock.provider)
    }

    var state: RecordPurchaseFlowState { flow.state }

    @discardableResult
    mutating func send(_ event: RecordPurchaseFlowEvent) -> RecordPurchaseFlowEffect? {
        flow.handle(event)
    }

    /// The first submit, answered by a confirmation_required with `tokenA` (issuedAt = clock now).
    mutating func driveToAwaiting(
        warnings: [BudgetWarning] = [PurchaseFixtures.recipientWarning()],
        token: String = PurchaseFlowHarness.tokenA
    ) {
        send(.submit)
        send(.serverConfirmationRequired(warnings: warnings, token: token))
    }

    /// The flow after a first confirmation was confirmed: submitting(isConfirmed: true).
    mutating func driveToConfirmedSubmitting() {
        driveToAwaiting()
        send(.confirm)
    }

    mutating func driveToExpired() {
        driveToAwaiting()
        clock.advance(by: RecordPurchaseFlow.confirmationLifetime)
        send(.clockTick)
    }

    mutating func driveToFailed(_ error: RecordPurchaseError = .network) {
        send(.submit)
        send(.serverError(error))
    }

    mutating func driveToRecorded(_ purchase: RecordedPurchase = PurchaseFixtures.recordedPurchase()) {
        send(.submit)
        send(.serverCreated(purchase))
    }
}

/// The states of the transition table, for the ignored-event matrix.
nonisolated enum PurchaseFlowStage: CaseIterable, Sendable, CustomTestStringConvertible {
    case editing, submitting, confirmedSubmitting, awaiting, expired, failed, recorded

    var testDescription: String {
        switch self {
        case .editing: "editing"
        case .submitting: "submitting"
        case .confirmedSubmitting: "submitting(confirmed)"
        case .awaiting: "awaitingConfirmation"
        case .expired: "expired"
        case .failed: "failed"
        case .recorded: "recorded"
        }
    }

    func makeHarness() -> PurchaseFlowHarness {
        var harness = PurchaseFlowHarness()
        switch self {
        case .editing: break
        case .submitting: harness.send(.submit)
        case .confirmedSubmitting: harness.driveToConfirmedSubmitting()
        case .awaiting: harness.driveToAwaiting()
        case .expired: harness.driveToExpired()
        case .failed: harness.driveToFailed()
        case .recorded: harness.driveToRecorded()
        }
        return harness
    }

    /// Events the transition table does NOT list for this stage (so they must be ignored).
    var ignoredEvents: [RecordPurchaseFlowEvent] {
        let created = RecordPurchaseFlowEvent.serverCreated(PurchaseFixtures.recordedPurchase(id: "purchase-other"))
        let confirmationRequired = RecordPurchaseFlowEvent.serverConfirmationRequired(
            warnings: [PurchaseFixtures.totalWarning()], token: "tok-IGNORED"
        )
        let error = RecordPurchaseFlowEvent.serverError(.server)
        switch self {
        case .editing:
            return [created, confirmationRequired, error, .confirm, .editDetails, .clockTick, .retry, .dismissError]
        case .submitting, .confirmedSubmitting:
            return [.submit, .confirm, .cancel, .editDetails, .clockTick, .retry, .dismissError]
        case .awaiting:
            return [.submit, created, confirmationRequired, error, .retry, .dismissError]
        case .expired:
            return [.submit, .confirm, .clockTick, created, confirmationRequired, error, .retry, .dismissError]
        case .failed:
            return [.submit, .confirm, .clockTick, created, confirmationRequired, error]
        case .recorded:
            return [
                .submit, created, confirmationRequired, error, .confirm, .cancel, .editDetails,
                .clockTick, .retry, .dismissError
            ]
        }
    }
}
