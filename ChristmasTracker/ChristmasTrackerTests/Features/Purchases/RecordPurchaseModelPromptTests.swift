//
//  RecordPurchaseModelPromptTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): the SOFT over-purchase prompt. It appears only when quantityRemaining is known
//  (which needs canSeeGiftActivity) and the quantity exceeds it; tapping Record then sends nothing
//  until confirmOverPurchase; zero remaining has its own wording; an absent quantityRemaining never
//  prompts; the prompt never blocks a purchase.
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model over-purchase prompt Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelPromptTests {

    private func makeSUT(
        remaining: Int?,
        quantity: Int,
        capabilities: ListCapabilities = RecordPurchaseTestCaps.buyer
    ) async -> RecordPurchaseModelSUT {
        let sut = await makeRecordPurchaseModelSUT(
            item: ItemFixtures.item(id: "item-1", quantity: 10, quantityRemaining: remaining),
            capabilities: capabilities
        )
        sut.model.input.quantity = quantity
        sut.fill()
        return sut
    }

    @Test("Exceeding a known remaining shows the prompt state and sends nothing until confirmed")
    func exceededWaitsForConfirmation() async {
        let sut = await makeSUT(remaining: 2, quantity: 3)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(quantity: 3))
        let prompt = sut.model.overPurchasePrompt
        #expect(prompt?.title == "Record anyway?")
        #expect(prompt?.message == "Only 2 remaining. You're recording 3.")
        #expect(prompt?.confirmButtonTitle == "Continue Anyway")

        await sut.model.recordTapped()

        #expect(sut.model.isShowingOverPurchasePrompt == true)
        #expect(sut.repo.callCount == 0)
        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == .editing)

        await sut.model.confirmOverPurchase()

        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.repo.callCount == 1)
        #expect(sut.repo.calls.first?.draft.quantity == 3)
        #expect(sut.repo.calls.first?.token == nil)
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase(quantity: 3)))
    }

    @Test("Zero remaining has its own wording")
    func zeroRemainingWording() async {
        let sut = await makeSUT(remaining: 0, quantity: 1)

        let prompt = sut.model.overPurchasePrompt
        #expect(prompt?.title == "Record anyway?")
        #expect(prompt?.message == "This item has already been fully purchased, and others may have bought it too.")

        await sut.model.recordTapped()
        #expect(sut.model.isShowingOverPurchasePrompt == true)
        #expect(sut.repo.callCount == 0)
    }

    @Test("A quantity equal to or below the remaining quantity does not prompt and sends at once",
          arguments: [(3, 3), (3, 1), (5, 4)])
    func notExceeded(remaining: Int, quantity: Int) async {
        let sut = await makeSUT(remaining: remaining, quantity: quantity)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        #expect(sut.model.overPurchasePrompt == nil)

        await sut.model.recordTapped()

        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.repo.callCount == 1)
    }

    @Test("An absent quantityRemaining never prompts, whatever the quantity, and never blocks")
    func absentNeverPrompts() async {
        let sut = await makeSUT(remaining: nil, quantity: 50)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(quantity: 50))
        #expect(sut.model.overPurchasePrompt == nil)

        await sut.model.recordTapped()

        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.repo.calls.first?.draft.quantity == 50)
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase(quantity: 50)))
    }

    @Test("A remaining value the caller may not see (no gift activity) never prompts")
    func hiddenRemainingNeverPrompts() async {
        let sut = await makeSUT(remaining: 1, quantity: 5, capabilities: RecordPurchaseTestCaps.buyerWithoutActivity)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        #expect(sut.model.overPurchasePrompt == nil)

        await sut.model.recordTapped()

        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.repo.callCount == 1)
    }

    @Test("An invalid form shows no prompt and sends nothing")
    func invalidFormNoPrompt() async {
        let sut = await makeSUT(remaining: 1, quantity: 5)
        sut.model.input.totalCostText = ""
        #expect(sut.model.overPurchasePrompt == nil)

        await sut.model.recordTapped()

        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.repo.callCount == 0)
    }

    @Test("Dismissing the dialog sends nothing, and Record can be tapped again")
    func dismissingSendsNothing() async {
        let sut = await makeSUT(remaining: 2, quantity: 3)
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(quantity: 3))
        await sut.model.recordTapped()
        #expect(sut.model.isShowingOverPurchasePrompt == true)

        sut.model.isShowingOverPurchasePrompt = false
        #expect(sut.repo.callCount == 0)
        #expect(sut.model.canTapRecord == true)

        await sut.model.recordTapped()
        #expect(sut.model.isShowingOverPurchasePrompt == true)
        await sut.model.confirmOverPurchase()
        #expect(sut.repo.callCount == 1)
    }

    @Test("The prompt never affects whether the form is valid or what the draft is")
    func promptDoesNotChangeValidity() async {
        let sut = await makeSUT(remaining: 2, quantity: 3)
        #expect(sut.model.overPurchasePrompt != nil)
        #expect(sut.model.formState.isValid == true)
        #expect(sut.model.formState.draft?.quantity == 3)
        #expect(sut.model.canTapRecord == true)
    }

    @Test("The prompt is gone once the flow leaves editing (awaiting confirmation)")
    func promptOnlyWhileEditingOrFailed() async {
        let sut = await makeSUT(remaining: 2, quantity: 3)
        sut.enqueueConfirmation(token: RecordPurchaseTestToken.first)
        await sut.model.recordTapped()
        await sut.model.confirmOverPurchase()

        #expect(sut.model.panel != nil)
        #expect(sut.model.overPurchasePrompt == nil)
    }

    @Test("The prompt returns after a failure (retry path), still only for a known, exceeded quantity")
    func promptInFailedState() async {
        let sut = await makeSUT(remaining: 2, quantity: 3)
        sut.repo.enqueueFailure(PurchaseError.network)
        await sut.model.recordTapped()
        await sut.model.confirmOverPurchase()
        #expect(sut.model.flow.state == .failed(.network))

        #expect(sut.model.overPurchasePrompt != nil)
    }
}
