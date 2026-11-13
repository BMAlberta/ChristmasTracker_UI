//
//  RecordPurchaseFlowTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the transition table of RecordPurchaseFlow for the states editing, submitting,
//  failed and recorded, the fieldsAreReadOnly matrix, and the rule that a token never survives
//  outside awaitingConfirmation and the send effect. The confirmation states (awaiting, expiry,
//  the S12 replacement) are in RecordPurchaseFlowConfirmationTests; ignored events in
//  RecordPurchaseFlowIgnoredEventsTests.
//
//  Fails today because RecordPurchaseFlow and its state, event and effect types do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase flow Tests")
struct RecordPurchaseFlowTests {

    private func makeSUT() -> PurchaseFlowHarness { PurchaseFlowHarness() }

    // MARK: - Initial state

    @Test("A new flow is editing, with editable fields and no notice")
    func initialState() {
        let sut = makeSUT()
        #expect(sut.state == .editing)
        #expect(sut.flow.fieldsAreReadOnly == false)
        #expect(sut.flow.noticeText == nil)
    }

    @Test("The confirmation lifetime is 270 seconds, 30 seconds inside the server's 5 minutes")
    func lifetimeConstant() {
        #expect(RecordPurchaseFlow.confirmationLifetime == 270)
        #expect(RecordPurchaseFlow.confirmationLifetime < 300)
    }

    // MARK: - editing

    @Test("editing + submit goes to submitting(isConfirmed: false) and sends WITHOUT a token")
    func editingSubmit() {
        var sut = makeSUT()
        let effect = sut.send(.submit)
        #expect(sut.state == .submitting(isConfirmed: false))
        #expect(effect == .send(confirmationToken: nil))
    }

    @Test("editing + cancel closes the form and sends nothing")
    func editingCancel() {
        var sut = makeSUT()
        let effect = sut.send(.cancel)
        #expect(sut.state == .editing)
        #expect(effect == .close)
    }

    // MARK: - submitting

    @Test("submitting + serverCreated records the purchase")
    func submittingCreated() {
        var sut = makeSUT()
        sut.send(.submit)
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-9", quantity: 2)
        let effect = sut.send(.serverCreated(purchase))
        #expect(sut.state == .recorded(purchase))
        #expect(effect == nil)
    }

    @Test("submitting + serverConfirmationRequired on a FIRST submit waits for confirmation, creates nothing")
    func submittingConfirmationRequired() {
        var sut = makeSUT()
        sut.send(.submit)
        sut.clock.advance(by: 7)
        let warnings = [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()]
        let effect = sut.send(.serverConfirmationRequired(warnings: warnings, token: PurchaseFlowHarness.tokenA))
        #expect(effect == nil)
        #expect(sut.state == .awaitingConfirmation(PendingConfirmation(
            warnings: warnings, token: PurchaseFlowHarness.tokenA,
            issuedAt: PurchaseTestClock.start.addingTimeInterval(7), notice: nil
        )))
        #expect(sut.flow.noticeText == nil)
    }

    @Test("submitting + serverError fails with that error, for every error", arguments: PurchaseFixtures.allErrors)
    func submittingError(error: PurchaseError) {
        var sut = makeSUT()
        sut.send(.submit)
        let effect = sut.send(.serverError(error))
        #expect(sut.state == .failed(error))
        #expect(effect == nil)
    }

    @Test("A confirmed submit answered with created records the purchase")
    func confirmedSubmitCreated() {
        var sut = makeSUT()
        sut.driveToConfirmedSubmitting()
        let purchase = PurchaseFixtures.recordedPurchase()
        sut.send(.serverCreated(purchase))
        #expect(sut.state == .recorded(purchase))
    }

    @Test("A confirmed submit answered with an error fails; the confirmed request carried the token only once")
    func confirmedSubmitError() {
        var sut = makeSUT()
        sut.driveToConfirmedSubmitting()
        let effect = sut.send(.serverError(.network))
        #expect(sut.state == .failed(.network))
        #expect(effect == nil)
    }

    // MARK: - failed

    @Test("failed + retry sends again WITHOUT a token, also after a confirmed attempt failed")
    func failedRetryHasNoToken() {
        var plain = makeSUT()
        plain.driveToFailed(.server)
        let first = plain.send(.retry)
        #expect(plain.state == .submitting(isConfirmed: false))
        #expect(first == .send(confirmationToken: nil))

        var confirmed = makeSUT()
        confirmed.driveToConfirmedSubmitting()
        confirmed.send(.serverError(.network))
        let second = confirmed.send(.retry)
        #expect(confirmed.state == .submitting(isConfirmed: false))
        #expect(second == .send(confirmationToken: nil))
    }

    @Test("A retried overage purchase asks again: the new confirmation_required is a FIRST one (no notice)")
    func retryThenConfirmationRequiredHasNoNotice() {
        var sut = makeSUT()
        sut.driveToConfirmedSubmitting()
        sut.send(.serverError(.network))
        sut.send(.retry)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        guard case let .awaitingConfirmation(pending) = sut.state else {
            Issue.record("expected awaitingConfirmation, got \(sut.state)")
            return
        }
        #expect(pending.token == PurchaseFlowHarness.tokenB)
        #expect(pending.notice == nil)
    }

    @Test("failed + dismissError and failed + editDetails return to editing without an effect")
    func failedBackToEditing() {
        for event in [RecordPurchaseFlowEvent.dismissError, .editDetails] {
            var sut = makeSUT()
            sut.driveToFailed(.server)
            let effect = sut.send(event)
            #expect(sut.state == .editing, "\(event)")
            #expect(effect == nil, "\(event)")
        }
    }

    @Test("failed + cancel closes the form and sends nothing")
    func failedCancel() {
        var sut = makeSUT()
        sut.driveToFailed(.server)
        let effect = sut.send(.cancel)
        #expect(sut.state == .editing)
        #expect(effect == .close)
    }

    // MARK: - recorded and a repeat purchase

    @Test("recorded is terminal: submit does nothing")
    func recordedIsTerminal() {
        var sut = makeSUT()
        let purchase = PurchaseFixtures.recordedPurchase()
        sut.driveToRecorded(purchase)
        let effect = sut.send(.submit)
        #expect(sut.state == .recorded(purchase))
        #expect(effect == nil)
    }

    @Test("A repeat purchase after recorded is a fresh flow: submit goes out send(nil) and asks again on overage")
    func repeatPurchaseIsAFreshFlow() {
        var first = makeSUT()
        first.driveToAwaiting()
        first.send(.confirm)
        first.send(.serverCreated(PurchaseFixtures.recordedPurchase()))
        guard case .recorded = first.state else {
            Issue.record("expected recorded, got \(first.state)")
            return
        }

        var repeatFlow = PurchaseFlowHarness(clock: first.clock)
        #expect(repeatFlow.state == .editing)
        let effect = repeatFlow.send(.submit)
        #expect(effect == .send(confirmationToken: nil))
        repeatFlow.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.recipientWarning()], token: PurchaseFlowHarness.tokenB))
        guard case let .awaitingConfirmation(pending) = repeatFlow.state else {
            Issue.record("expected awaitingConfirmation, got \(repeatFlow.state)")
            return
        }
        #expect(pending.token == PurchaseFlowHarness.tokenB)
        #expect(pending.notice == nil)
    }

    // MARK: - fieldsAreReadOnly

    @Test("Fields are read-only in submitting, awaiting, expired and recorded; editable in editing and failed",
          arguments: PurchaseFlowStage.allCases)
    func readOnlyMatrix(stage: PurchaseFlowStage) {
        let sut = stage.makeHarness()
        let expected: Bool
        switch stage {
        case .editing, .failed: expected = false
        case .submitting, .confirmedSubmitting, .awaiting, .expired, .recorded: expected = true
        }
        #expect(sut.flow.fieldsAreReadOnly == expected, "\(stage)")
    }

    // MARK: - The token is gone after every transition out of awaitingConfirmation

    @Test("After leaving awaitingConfirmation the token appears nowhere in the state",
          arguments: [RecordPurchaseFlowEvent.confirm, .editDetails, .cancel])
    func tokenDroppedOnLeaving(event: RecordPurchaseFlowEvent) {
        var sut = makeSUT()
        sut.driveToAwaiting()
        sut.send(event)
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false, "\(event)")
        sut.send(.serverCreated(PurchaseFixtures.recordedPurchase()))
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false, "\(event)")
    }

    @Test("After expiry the token appears nowhere in the state")
    func tokenDroppedOnExpiry() {
        var sut = makeSUT()
        sut.driveToExpired()
        #expect(sut.state == .expired)
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false)
    }

    @Test("After a failed confirmed request the token appears nowhere in the state")
    func tokenDroppedOnFailure() {
        var sut = makeSUT()
        sut.driveToConfirmedSubmitting()
        sut.send(.serverError(.network))
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false)
    }
}
