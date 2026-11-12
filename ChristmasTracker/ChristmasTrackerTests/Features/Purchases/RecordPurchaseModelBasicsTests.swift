//
//  RecordPurchaseModelBasicsTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): RecordPurchaseModel basics: the initial quantity, the read-only input lock,
//  and the created path (one service call, the draft and no token, finish == .recorded).
//
//  No test assumes that counts, statuses or quantities change after a purchase: the model does
//  not refresh anything, and the refresh plan only lists refreshes.
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model basics Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelBasicsTests {

    private func makeSUT(
        quantity: Int = 8,
        remaining: Int? = nil,
        capabilities: ListCapabilities = RecordPurchaseTestCaps.buyer
    ) async -> RecordPurchaseModelSUT {
        await makeRecordPurchaseModelSUT(
            item: ItemFixtures.item(id: "item-1", quantity: quantity, quantityRemaining: remaining),
            capabilities: capabilities
        )
    }

    // MARK: Initial quantity

    @Test("The initial quantity is the server's remaining when known and above zero",
          arguments: [(5, 5), (1, 1), (7, 7)])
    func initialQuantityFromRemaining(remaining: Int, expected: Int) async {
        let sut = await makeSUT(remaining: remaining)
        #expect(sut.model.input.quantity == expected)
    }

    @Test("The initial quantity is 1 when nothing remains")
    func initialQuantityZeroRemaining() async {
        let sut = await makeSUT(remaining: 0)
        #expect(sut.model.input.quantity == 1)
    }

    @Test("The initial quantity is 1 when quantityRemaining is unknown")
    func initialQuantityUnknown() async {
        let sut = await makeSUT(remaining: nil)
        #expect(sut.model.input.quantity == 1)
    }

    @Test("The initial quantity ignores quantityRemaining when the caller cannot see gift activity")
    func initialQuantityHiddenWithoutActivity() async {
        let sut = await makeSUT(remaining: 5, capabilities: RecordPurchaseTestCaps.buyerWithoutActivity)
        #expect(sut.model.input.quantity == 1)
    }

    // MARK: Input lock

    @Test("An assignment to the input is ignored while the form is read-only (awaiting confirmation)")
    func inputLockedWhileAwaiting() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting()
        #expect(sut.model.fieldsAreReadOnly == true)
        let before = sut.model.input

        sut.model.input.totalCostText = "99.00"
        sut.model.input.quantity = 9
        sut.model.input.storeName = "Other Store"
        #expect(sut.model.input == before)

        var replacement = before
        replacement.totalCostText = "1.00"
        sut.model.input = replacement
        #expect(sut.model.input == before)
    }

    @Test("An assignment to the input is ignored while a request is in flight")
    func inputLockedWhileSubmitting() async {
        let sut = await makeSUT()
        sut.fill()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = Task { @MainActor in await sut.model.recordTapped() }
        await sut.repo.gate.nextHeldCall()
        #expect(sut.model.fieldsAreReadOnly == true)
        #expect(sut.model.isSubmitting == true)
        let before = sut.model.input

        sut.model.input.totalCostText = "99.00"
        #expect(sut.model.input == before)

        sut.repo.gate.releaseAll()
        await task.value
    }

    @Test("The input is editable again after editing details")
    func inputEditableAfterEditDetails() async {
        let sut = await makeSUT()
        await sut.driveToAwaiting()

        sut.model.editDetails()
        sut.model.input.totalCostText = "30.00"

        #expect(sut.model.fieldsAreReadOnly == false)
        #expect(sut.model.input.totalCostText == "30.00")
    }

    // MARK: Created path

    @Test("A within-budget purchase makes one service call with the draft and no token, and finishes recorded")
    func createdPath() async {
        let sut = await makeSUT()
        let purchase = PurchaseFixtures.recordedPurchase(id: "purchase-9", quantity: 2)
        sut.repo.enqueue(created: purchase)
        sut.model.input.quantity = 2
        sut.model.input.totalCostText = "25.50"
        sut.model.input.storeName = "Fake Store"
        sut.model.input.notes = "   "
        #expect(sut.model.canTapRecord == true)
        #expect(sut.model.finish == nil)

        await sut.model.recordTapped()

        #expect(sut.repo.calls == [
            GatedPurchaseRecorder.Call(
                itemId: "item-1",
                draft: PurchaseFixtures.draft(quantity: 2, totalCost: "25.50", storeName: "Fake Store"),
                token: nil
            )
        ])
        #expect(sut.model.finish == .recorded(purchase))
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.panel == nil)
        #expect(sut.service.isMutating == false)
    }

    @Test("The model does not refresh or splice anything: the service is called once and only once")
    func noFollowUpCalls() async {
        let sut = await makeSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.fill()

        await sut.model.recordTapped()
        sut.model.expiryReached()

        #expect(sut.repo.callCount == 1)
    }

    @Test("An invalid form never calls the service", arguments: ["", "0", "12.345", "abc", "1000000.00"])
    func invalidFormSendsNothing(cost: String) async {
        let sut = await makeSUT()
        sut.model.input.totalCostText = cost
        #expect(sut.model.canTapRecord == false)

        await sut.model.recordTapped()

        #expect(sut.repo.callCount == 0)
        #expect(sut.model.finish == nil)
        #expect(sut.model.isShowingOverPurchasePrompt == false)
        #expect(sut.model.flow.state == .editing)
    }

    @Test("The model's summary matches the pure summary for the same item and flags")
    func summaryMatches() async {
        let item = ItemFixtures.item(name: "Fake Lamp", price: ItemFixtures.decimal("19.99"), quantity: 4, quantityRemaining: 3)
        let sut = await makeRecordPurchaseModelSUT(item: item)

        let expected = RecordPurchaseItemSummary(
            item: item, capabilities: RecordPurchaseTestCaps.buyer, currencyCode: "USD", locale: Locale(identifier: "en_US")
        )
        #expect(sut.model.summary == expected)
    }
}
