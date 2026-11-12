//
//  RecordPurchaseFlowConfirmationTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-A: the awaitingConfirmation and expired states of RecordPurchaseFlow, driven with an
//  injected clock. Covers: confirm, edit details (token discarded), cancel (close, no send), the
//  expiry exactly at 270 seconds and just before (on confirm and on clockTick), and the S12
//  replacement: a CONFIRMED resubmit answered by a NEW confirmation_required replaces the pending
//  confirmation (new warnings, new token, new issuedAt, the notice), sends nothing by itself, and
//  needs a NEW explicit confirm.
//
//  Fails today because RecordPurchaseFlow and its types do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase flow confirmation Tests")
struct RecordPurchaseFlowConfirmationTests {

    private let lifetime = RecordPurchaseFlow.confirmationLifetime

    private func makeAwaiting(
        warnings: [BudgetWarning] = [PurchaseFixtures.recipientWarning()]
    ) -> PurchaseFlowHarness {
        var sut = PurchaseFlowHarness()
        sut.driveToAwaiting(warnings: warnings)
        return sut
    }

    private func pending(_ sut: PurchaseFlowHarness) -> PendingConfirmation? {
        if case let .awaitingConfirmation(pending) = sut.state { return pending }
        return nil
    }

    // MARK: - confirm

    @Test("confirm before expiry resubmits with the pending token")
    func confirmSendsToken() {
        var sut = makeAwaiting()
        sut.clock.advance(by: 60)
        let effect = sut.send(.confirm)
        #expect(sut.state == .submitting(isConfirmed: true))
        #expect(effect == .send(confirmationToken: PurchaseFlowHarness.tokenA))
    }

    @Test("Any one warning's token is the pending token: two warnings share one token")
    func twoWarningsOneToken() {
        var sut = makeAwaiting(warnings: [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()])
        let effect = sut.send(.confirm)
        #expect(effect == .send(confirmationToken: PurchaseFlowHarness.tokenA))
    }

    @Test("The awaiting state keeps all warnings in order and has read-only fields and no notice")
    func awaitingContents() {
        let warnings = [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()]
        let sut = makeAwaiting(warnings: warnings)
        #expect(pending(sut)?.warnings == warnings)
        #expect(pending(sut)?.notice == nil)
        #expect(sut.flow.fieldsAreReadOnly)
        #expect(sut.flow.noticeText == nil)
    }

    // MARK: - expiry

    @Test("confirm exactly at 270 seconds is expired and sends nothing")
    func confirmAtLifetimeExpires() {
        var sut = makeAwaiting()
        sut.clock.advance(by: lifetime)
        let effect = sut.send(.confirm)
        #expect(sut.state == .expired)
        #expect(effect == nil)
    }

    @Test("confirm just before 270 seconds still sends", arguments: [269.999, 269, 1, 0])
    func confirmBeforeLifetimeSends(offset: TimeInterval) {
        var sut = makeAwaiting()
        sut.clock.advance(by: offset)
        let effect = sut.send(.confirm)
        #expect(sut.state == .submitting(isConfirmed: true), "\(offset)")
        #expect(effect == .send(confirmationToken: PurchaseFlowHarness.tokenA), "\(offset)")
    }

    @Test("confirm after 270 seconds is expired", arguments: [270.001, 299, 300, 3_600])
    func confirmAfterLifetimeExpires(offset: TimeInterval) {
        var sut = makeAwaiting()
        sut.clock.advance(by: offset)
        let effect = sut.send(.confirm)
        #expect(sut.state == .expired, "\(offset)")
        #expect(effect == nil, "\(offset)")
    }

    @Test("clockTick expires the confirmation at exactly 270 seconds and not before")
    func clockTickBoundary() {
        var sut = makeAwaiting()
        let before = sut.state
        sut.clock.advance(by: lifetime - 1)
        let early = sut.send(.clockTick)
        #expect(sut.state == before)
        #expect(early == nil)
        sut.clock.advance(by: 1)
        let atLimit = sut.send(.clockTick)
        #expect(sut.state == .expired)
        #expect(atLimit == nil)
    }

    @Test("clockTick right after issuing changes nothing")
    func clockTickFresh() {
        var sut = makeAwaiting()
        let before = sut.state
        let effect = sut.send(.clockTick)
        #expect(sut.state == before)
        #expect(effect == nil)
    }

    @Test("expiry is measured from issuedAt, not from the first submit")
    func expiryFromIssuedAt() {
        var sut = PurchaseFlowHarness()
        sut.send(.submit)
        sut.clock.advance(by: 200)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenA))
        sut.clock.advance(by: 100)
        #expect(sut.send(.confirm) == .send(confirmationToken: PurchaseFlowHarness.tokenA))
    }

    @Test("expired shows the read-only state; editDetails returns to editing without an effect")
    func expiredEditDetails() {
        var sut = PurchaseFlowHarness()
        sut.driveToExpired()
        #expect(sut.flow.fieldsAreReadOnly)
        let effect = sut.send(.editDetails)
        #expect(sut.state == .editing)
        #expect(effect == nil)
    }

    @Test("expired + cancel closes the form")
    func expiredCancel() {
        var sut = PurchaseFlowHarness()
        sut.driveToExpired()
        let effect = sut.send(.cancel)
        #expect(sut.state == .editing)
        #expect(effect == .close)
    }

    @Test("After expiry a new submit goes out WITHOUT the old token")
    func submitAfterExpiryHasNoToken() {
        var sut = PurchaseFlowHarness()
        sut.driveToExpired()
        sut.send(.editDetails)
        let effect = sut.send(.submit)
        #expect(effect == .send(confirmationToken: nil))
    }

    // MARK: - editDetails and cancel

    @Test("editDetails returns to editing and discards the token: the next submit has none")
    func editDetailsDiscardsToken() {
        var sut = makeAwaiting()
        let effect = sut.send(.editDetails)
        #expect(sut.state == .editing)
        #expect(effect == nil)
        #expect(sut.flow.fieldsAreReadOnly == false)
        let next = sut.send(.submit)
        #expect(next == .send(confirmationToken: nil))
    }

    @Test("cancel closes the form and sends nothing; the token is gone")
    func cancelCloses() {
        var sut = makeAwaiting()
        let effect = sut.send(.cancel)
        #expect(effect == .close)
        #expect(sut.state == .editing)
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false)
        #expect(sut.send(.submit) == .send(confirmationToken: nil))
    }

    // MARK: - S12: a confirmed resubmit answered by a NEW confirmation_required

    @Test("S12 replaces the pending confirmation: new warnings, new token, new issuedAt, notice, no effect")
    func replacementOnConfirmedResubmit() {
        var sut = makeAwaiting()
        sut.clock.advance(by: 90)
        #expect(sut.send(.confirm) == .send(confirmationToken: PurchaseFlowHarness.tokenA))
        sut.clock.advance(by: 5)
        let newWarnings = [PurchaseFixtures.recipientWarning(spent: "120.00", overage: "45.50"), PurchaseFixtures.totalWarning()]

        let effect = sut.send(.serverConfirmationRequired(warnings: newWarnings, token: PurchaseFlowHarness.tokenB))

        #expect(effect == nil)
        #expect(sut.state == .awaitingConfirmation(PendingConfirmation(
            warnings: newWarnings, token: PurchaseFlowHarness.tokenB,
            issuedAt: PurchaseTestClock.start.addingTimeInterval(95),
            notice: RecordPurchaseCopy.budgetChangedNotice
        )))
        #expect(sut.flow.noticeText == RecordPurchaseCopy.budgetChangedNotice)
        #expect(sut.flow.fieldsAreReadOnly)
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenA) == false)
    }

    @Test("S12 never resubmits by itself: time passing and ticks send nothing, a NEW confirm is required")
    func replacementNeedsExplicitConfirm() {
        var sut = makeAwaiting()
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        sut.clock.advance(by: 10)
        #expect(sut.send(.clockTick) == nil)
        guard case .awaitingConfirmation = sut.state else {
            Issue.record("expected awaitingConfirmation, got \(sut.state)")
            return
        }
        let effect = sut.send(.confirm)
        #expect(effect == .send(confirmationToken: PurchaseFlowHarness.tokenB))
        #expect(sut.state == .submitting(isConfirmed: true))
    }

    @Test("After the replacement the lifetime restarts from the new issuedAt")
    func replacementRestartsLifetime() {
        var sut = makeAwaiting()
        sut.clock.advance(by: 100)
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        // 269 s after the new issuedAt is still valid, although 369 s passed since the first warning.
        sut.clock.advance(by: lifetime - 1)
        #expect(sut.send(.clockTick) == nil)
        #expect(pending(sut)?.token == PurchaseFlowHarness.tokenB)
        sut.clock.advance(by: 1)
        sut.send(.clockTick)
        #expect(sut.state == .expired)
    }

    @Test("A replacement can be replaced again, each time with the notice and a new token")
    func repeatedReplacement() {
        var sut = makeAwaiting()
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.recipientWarning()], token: "tok-C-FAKE"))
        #expect(pending(sut)?.token == "tok-C-FAKE")
        #expect(pending(sut)?.notice == RecordPurchaseCopy.budgetChangedNotice)
        #expect(String(describing: sut.state).contains(PurchaseFlowHarness.tokenB) == false)
    }

    @Test("From a replaced confirmation, editDetails returns to editing and the next submit has no token")
    func replacementThenEditDetails() {
        var sut = makeAwaiting()
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        sut.send(.editDetails)
        #expect(sut.state == .editing)
        #expect(sut.flow.noticeText == nil)
        #expect(sut.send(.submit) == .send(confirmationToken: nil))
    }

    @Test("The notice shows only on a replacement, never on the first confirmation or after returning to editing")
    func noticeOnlyOnReplacement() {
        var sut = makeAwaiting()
        #expect(sut.flow.noticeText == nil)
        sut.send(.confirm)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: PurchaseFlowHarness.tokenB))
        #expect(sut.flow.noticeText != nil)
        sut.send(.cancel)
        #expect(sut.flow.noticeText == nil)
        sut.send(.submit)
        sut.send(.serverConfirmationRequired(warnings: [PurchaseFixtures.totalWarning()], token: "tok-C-FAKE"))
        #expect(sut.flow.noticeText == nil)
    }
}
