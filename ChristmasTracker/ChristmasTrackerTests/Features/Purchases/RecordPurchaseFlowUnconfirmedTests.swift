//
//  RecordPurchaseFlowUnconfirmedTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: the unconfirmed paths of RecordPurchaseFlow. Every I4a rule is kept.
//  - serverError(.unconfirmed) from submitting (confirmed or not) goes to failed(.unconfirmed)
//    and the state holds no token afterwards.
//  - In failed(.unconfirmed): recordAgain -> submitting(isConfirmed: false) + send(nil);
//    checkItem -> editing + effect checkItem; retry is ignored; dismissError, editDetails and
//    cancel behave as for any failure.
//  - recordAgain and checkItem are ignored in every other state and after any other failure.
//
//  Fails today because .unconfirmed, .recordAgain, .checkItem and the checkItem effect do not
//  exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

extension PurchaseFlowHarness {
    /// A first submit answered by an unconfirmed failure.
    mutating func driveToUnconfirmed() {
        driveToFailed(.unconfirmed)
    }

    /// A confirmed resubmit (after Record Anyway) answered by an unconfirmed failure.
    mutating func driveToUnconfirmedAfterConfirmation() {
        driveToConfirmedSubmitting()
        send(.serverError(.unconfirmed))
    }
}

@Suite("Record purchase flow unconfirmed Tests")
struct RecordPurchaseFlowUnconfirmedTests {

    private func makeSUT() -> PurchaseFlowHarness { PurchaseFlowHarness() }

    // MARK: - Entering the state

    @Test("An unconfirmed error on the first submit fails with unconfirmed and no effect")
    func fromFirstSubmit() {
        var sut = makeSUT()
        sut.send(.submit)
        let effect = sut.send(.serverError(.unconfirmed))
        #expect(sut.state == .failed(.unconfirmed))
        #expect(effect == nil)
    }

    @Test("An unconfirmed error on a confirmed resubmit fails with unconfirmed and the token is gone")
    func fromConfirmedSubmit() {
        var sut = makeSUT()
        sut.driveToConfirmedSubmitting()
        #expect(sut.state == .submitting(isConfirmed: true))
        let effect = sut.send(.serverError(.unconfirmed))
        #expect(sut.state == .failed(.unconfirmed))
        #expect(effect == nil)
        #expect(!String(describing: sut.state).contains(PurchaseFlowHarness.tokenA))
        #expect(!String(reflecting: sut.state).contains(PurchaseFlowHarness.tokenA))
        #expect(!String(reflecting: sut.flow).contains(PurchaseFlowHarness.tokenA))
    }

    // MARK: - Record Again

    @Test("Record Again resubmits from a first-submit failure with no token",
          arguments: [false, true])
    func recordAgain(afterConfirmation: Bool) {
        var sut = makeSUT()
        if afterConfirmation { sut.driveToUnconfirmedAfterConfirmation() } else { sut.driveToUnconfirmed() }
        let effect = sut.send(.recordAgain)
        #expect(sut.state == .submitting(isConfirmed: false))
        #expect(effect == .send(confirmationToken: nil))
    }

    @Test("A record again that is answered with a confirmation requirement gets a fresh token, nothing is reused")
    func recordAgainThenConfirmation() {
        var sut = makeSUT()
        sut.driveToUnconfirmedAfterConfirmation()
        sut.send(.recordAgain)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        guard case let .awaitingConfirmation(pending) = sut.state else {
            Issue.record("expected awaitingConfirmation, got \(sut.state)")
            return
        }
        #expect(pending.token == PurchaseFlowHarness.tokenB)
        #expect(pending.notice == nil)
    }

    // MARK: - Check Item

    @Test("Check Item returns to editing and asks the caller to check the item")
    func checkItem() {
        var sut = makeSUT()
        sut.driveToUnconfirmed()
        let effect = sut.send(.checkItem)
        #expect(sut.state == .editing)
        #expect(effect == .checkItem)
    }

    // MARK: - Retry is ignored

    @Test("Retry is ignored in the unconfirmed state: no state change and no effect")
    func retryIgnored() {
        var sut = makeSUT()
        sut.driveToUnconfirmed()
        let effect = sut.send(.retry)
        #expect(sut.state == .failed(.unconfirmed))
        #expect(effect == nil)
    }

    // MARK: - Leaving as for any failure

    @Test("Dismiss and Edit Details go back to editing with no effect", arguments: [
        RecordPurchaseFlowEvent.dismissError, .editDetails
    ])
    func dismissAndEdit(event: RecordPurchaseFlowEvent) {
        var sut = makeSUT()
        sut.driveToUnconfirmed()
        let effect = sut.send(event)
        #expect(sut.state == .editing)
        #expect(effect == nil)
    }

    @Test("Cancel goes back to editing and closes the form")
    func cancel() {
        var sut = makeSUT()
        sut.driveToUnconfirmed()
        let effect = sut.send(.cancel)
        #expect(sut.state == .editing)
        #expect(effect == .close)
    }

    @Test("Events that do not apply to a failure are ignored in the unconfirmed state")
    func otherEventsIgnored() {
        let events: [RecordPurchaseFlowEvent] = [
            .submit, .confirm, .clockTick,
            .serverCreated(PurchaseFixtures.recordedPurchase(id: "purchase-other")),
            .serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: "tok-IGNORED"),
            .serverError(.server)
        ]
        for event in events {
            var sut = makeSUT()
            sut.driveToUnconfirmed()
            let effect = sut.send(event)
            #expect(sut.state == .failed(.unconfirmed), "\(event)")
            #expect(effect == nil, "\(event)")
        }
    }

    // MARK: - Ignored elsewhere

    @Test("Record Again and Check Item are ignored in every state except the unconfirmed failure",
          arguments: PurchaseFlowStage.allCases)
    func ignoredInEveryOtherStage(stage: PurchaseFlowStage) {
        for event in [RecordPurchaseFlowEvent.recordAgain, .checkItem] {
            var sut = stage.makeHarness()
            let before = sut.state
            let effect = sut.send(event)
            #expect(sut.state == before, "\(stage) + \(event)")
            #expect(effect == nil, "\(stage) + \(event)")
        }
    }

    @Test("Record Again and Check Item are ignored after any other failure",
          arguments: PurchaseFixtures.allErrors)
    func ignoredAfterOtherFailures(error: PurchaseError) {
        for event in [RecordPurchaseFlowEvent.recordAgain, .checkItem] {
            var sut = makeSUT()
            sut.driveToFailed(error)
            let effect = sut.send(event)
            #expect(sut.state == .failed(error), "\(error) + \(event)")
            #expect(effect == nil, "\(error) + \(event)")
        }
    }

    // MARK: - Token never in state

    @Test("No state reached by the unconfirmed paths holds a token",
          arguments: [false, true])
    func tokenNeverInState(afterConfirmation: Bool) {
        var sut = makeSUT()
        if afterConfirmation { sut.driveToUnconfirmedAfterConfirmation() } else { sut.driveToUnconfirmed() }
        var seen: [RecordPurchaseFlowState] = [sut.state]
        sut.send(.recordAgain)
        seen.append(sut.state)
        sut.send(.serverError(.unconfirmed))
        seen.append(sut.state)
        sut.send(.checkItem)
        seen.append(sut.state)
        for state in seen {
            #expect(!String(describing: state).contains(PurchaseFlowHarness.tokenA))
            #expect(!String(reflecting: state).contains(PurchaseFlowHarness.tokenA))
            if case .awaitingConfirmation = state { Issue.record("a token-holding state was reached: \(state)") }
        }
    }

    @Test("The new events and the new effect print and reflect without a token")
    func newEventsAreTokenFree() {
        let texts = [
            String(describing: RecordPurchaseFlowEvent.recordAgain),
            String(reflecting: RecordPurchaseFlowEvent.recordAgain),
            String(describing: RecordPurchaseFlowEvent.checkItem),
            String(reflecting: RecordPurchaseFlowEvent.checkItem),
            String(describing: RecordPurchaseFlowEffect.checkItem),
            String(reflecting: RecordPurchaseFlowEffect.checkItem),
            String(describing: Mirror(reflecting: RecordPurchaseFlowEvent.recordAgain).children.map { "\($0.label ?? "")" }),
            String(describing: Mirror(reflecting: RecordPurchaseFlowEvent.checkItem).children.map { "\($0.label ?? "")" }),
            String(describing: Mirror(reflecting: RecordPurchaseFlowEffect.checkItem).children.map { "\($0.label ?? "")" })
        ]
        for text in texts {
            #expect(!text.isEmpty)
            #expect(!text.lowercased().contains("tok"), "\(text)")
        }
    }
}
