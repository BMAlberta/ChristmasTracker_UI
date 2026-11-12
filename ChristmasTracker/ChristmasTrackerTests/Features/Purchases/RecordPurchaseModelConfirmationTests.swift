//
//  RecordPurchaseModelConfirmationTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): the budget confirmation path through the model.
//
//   - a confirmation_required answer creates nothing, shows the panel, and exposes no token;
//   - confirmBudget resubmits the IDENTICAL draft with the pending token;
//   - edit details discards the token (the next submit goes out without one);
//   - cancel finishes `cancelled`, makes no further call, and drops the token;
//   - S12: a confirmed resubmit answered by a NEW confirmation_required replaces the warnings and
//     token, shows the notice, makes NO automatic call, and needs a new explicit confirmBudget that
//     carries the NEW token;
//   - a repeat purchase after success goes out WITHOUT a token and is asked again.
//
//  Tokens are the distinctive fakes "tok-DISTINCT-123" and "tok-DISTINCT-456".
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model confirmation Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelConfirmationTests {

    private let tokenA = RecordPurchaseTestToken.first
    private let tokenB = RecordPurchaseTestToken.second

    private func makeSUT() async -> RecordPurchaseModelSUT {
        await makeRecordPurchaseModelSUT(item: ItemFixtures.item(id: "item-1", quantity: 3))
    }

    // MARK: First answer

    @Test("confirmation_required creates nothing and shows the inline panel with one row per warning")
    func firstConfirmation() async {
        let sut = await makeSUT()

        await sut.driveToAwaiting(token: tokenA)

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.finish == nil)
        let panel = sut.model.panel
        #expect(panel?.rows.map(\.label) == ["Over the budget for Pat Recipient", "Over your total budget"])
        #expect(panel?.noticeText == nil)
        #expect(sut.model.fieldsAreReadOnly == true)
        #expect(sut.model.showsRecordButton == false)
        #expect(sut.model.canTapRecord == false)
        #expect(sut.model.isSubmitting == false)
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.showsExpired == false)
        #expect(sut.service.isMutating == false)
    }

    @Test("The panel is built from the warnings with the model's currency and locale")
    func panelMatchesPureState() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)

        let expected = BudgetWarningPanelState(
            warnings: [PurchaseFixtures.recipientWarning(), PurchaseFixtures.totalWarning()],
            notice: nil, currencyCode: "USD", locale: Locale(identifier: "en_US")
        )
        #expect(sut.model.panel == expected)
    }

    // MARK: Confirm

    @Test("confirmBudget resubmits the identical draft with the pending token and records on created")
    func confirmResubmits() async {
        let sut = await makeSUT()
        sut.model.input.quantity = 2
        sut.model.input.storeName = "Fake Store"
        await sut.driveToAwaiting(token: tokenA)
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-7")
        sut.repo.enqueue(created: purchase)

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[0].token == nil)
        #expect(sut.repo.calls[1].token == tokenA)
        #expect(sut.repo.calls[1].draft == sut.repo.calls[0].draft)
        #expect(sut.repo.calls[1].itemId == sut.repo.calls[0].itemId)
        #expect(sut.model.finish == .recorded(purchase))
        #expect(sut.model.panel == nil)
    }

    @Test("A confirm without a pending confirmation does nothing")
    func confirmWithoutPending() async {
        let sut = await makeSUT()
        sut.fill()

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 0)
        #expect(sut.model.flow.state == .editing)
    }

    // MARK: Edit details

    @Test("Edit Details discards the token, unlocks the fields, and the next submit goes out WITHOUT a token")
    func editDetailsDiscardsToken() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)

        sut.model.editDetails()

        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.panel == nil)
        #expect(sut.model.fieldsAreReadOnly == false)
        #expect(sut.model.showsRecordButton == true)
        #expect(!String(describing: sut.model.flow).contains(tokenA))

        // A confirm now is a no-op: the token is gone.
        await sut.model.confirmBudget()
        #expect(sut.repo.callCount == 1)

        // The edited details go out as a fresh request without any token.
        sut.model.input.totalCostText = "30.00"
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        await sut.model.recordTapped()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[1].token == nil)
        #expect(sut.repo.calls[1].draft == PurchaseFixtures.draft(quantity: 1, totalCost: "30.00"))
    }

    // MARK: Cancel

    @Test("Cancel finishes cancelled, records nothing, makes no further call and drops the token")
    func cancelDropsToken() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)

        sut.model.cancel()

        #expect(sut.model.finish == .cancelled)
        #expect(sut.repo.callCount == 1)
        #expect(sut.model.panel == nil)
        #expect(!String(describing: sut.model.flow).contains(tokenA))

        await sut.model.confirmBudget()
        #expect(sut.repo.callCount == 1)
        #expect(sut.model.finish == .cancelled)
    }

    @Test("Cancel from the editing state finishes cancelled and sends nothing")
    func cancelWhileEditing() async {
        let sut = await makeSUT()

        sut.model.cancel()

        #expect(sut.model.finish == .cancelled)
        #expect(sut.repo.callCount == 0)
    }

    @Test("Cancel is ignored while a request is in flight")
    func cancelIgnoredInFlight() async {
        let sut = await makeSUT()
        sut.fill()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = Task { @MainActor in await sut.model.recordTapped() }
        await sut.repo.gate.nextHeldCall()

        sut.model.cancel()
        #expect(sut.model.finish == nil)

        sut.repo.gate.releaseAll()
        await task.value
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase()))
    }

    // MARK: S12

    @Test("S12: a confirmed resubmit answered by a new confirmation_required replaces the pending confirmation, shows the notice and makes no automatic call")
    func s12Replacement() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)
        sut.repo.enqueue(.success(.confirmationRequired(
            warnings: [PurchaseFixtures.recipientWarning(spent: "100.00", overage: "25.50")],
            token: tokenB
        )))

        await sut.model.confirmBudget()

        // Exactly the two calls made so far: nothing was resubmitted by itself.
        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[1].token == tokenA)
        #expect(sut.model.finish == nil)
        let panel = sut.model.panel
        #expect(panel?.rows.count == 1)
        #expect(panel?.noticeText == RecordPurchaseCopy.budgetChangedNotice)
        #expect(panel?.rows.first?.alreadySpentText == "$100.00")
        #expect(sut.model.fieldsAreReadOnly == true)
        #expect(sut.model.isSubmitting == false)
        #expect(!String(describing: sut.model.flow).contains(tokenA))
        #expect(!String(describing: sut.model.flow).contains(tokenB))
    }

    @Test("S12: the new explicit confirmBudget carries the NEW token, never the old one")
    func s12NewTokenOnNewConfirm() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)
        sut.enqueueConfirmation(token: tokenB, spent: "100.00")
        await sut.model.confirmBudget()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-8")
        sut.repo.enqueue(created: purchase)

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 3)
        #expect(sut.repo.calls[2].token == tokenB)
        #expect(sut.repo.calls[2].draft == sut.repo.calls[0].draft)
        #expect(sut.model.finish == .recorded(purchase))
    }

    @Test("S12: the notice is not shown for a first confirmation, and the replacement can repeat")
    func s12RepeatsWithoutLoop() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)
        #expect(sut.model.panel?.noticeText == nil)

        sut.enqueueConfirmation(token: tokenB, spent: "100.00")
        await sut.model.confirmBudget()
        sut.enqueueConfirmation(token: "tok-DISTINCT-789", spent: "110.00")
        await sut.model.confirmBudget()

        // Two explicit confirms, two resubmits, and no more.
        #expect(sut.repo.callCount == 3)
        #expect(sut.repo.calls.map(\.token) == [nil, tokenA, tokenB])
        #expect(sut.model.panel?.noticeText == RecordPurchaseCopy.budgetChangedNotice)
    }

    // MARK: Repeat purchase

    @Test("A repeat purchase after success goes out WITHOUT a token and is asked again")
    func repeatPurchaseAsksAgain() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(id: "purchase-1"))
        await sut.model.confirmBudget()
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase(id: "purchase-1")))

        // A new form for the same item (the sheet is presented again): same service, new model.
        let again = RecordPurchaseModel(
            item: ItemFixtures.item(id: "item-1", quantity: 3),
            context: ItemListContext(capabilities: RecordPurchaseTestCaps.buyer),
            service: sut.service, now: sut.clock.provider, currencyCode: "USD", locale: Locale(identifier: "en_US")
        )
        again.input.totalCostText = "25.50"
        sut.enqueueConfirmation(token: tokenB, spent: "115.50")

        await again.recordTapped()

        #expect(sut.repo.callCount == 3)
        #expect(sut.repo.calls[2].token == nil, "a token is never reused for a later attempt")
        #expect(again.finish == nil)
        #expect(again.panel != nil)
        #expect(again.panel?.noticeText == nil)
    }

    @Test("A retry after a failed confirmed resubmit goes out WITHOUT a token and is asked again")
    func retryAfterConfirmedFailureAsksAgain() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting(token: tokenA)
        sut.repo.enqueueFailure(PurchaseError.network)
        await sut.model.confirmBudget()
        #expect(sut.model.flow.state == .failed(.network))
        sut.enqueueConfirmation(token: tokenB)

        await sut.model.retry()

        #expect(sut.repo.calls.map(\.token) == [nil, tokenA, nil])
        #expect(sut.model.panel != nil)
        #expect(sut.model.finish == nil)
    }
}
