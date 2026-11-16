//
//  RecordPurchaseModelStartingInputTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: the optional startingInput parameter. Nil is exactly today's model; a value is
//  the initial input and nothing else about the model changes.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model starting input Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelStartingInputTests {

    private static let starting = RecordPurchaseFormInput(
        quantity: 3,
        totalCostText: "37.50",
        storeName: "",
        notes: "",
        confirmationNumber: "",
        trackingNumber: ""
    )

    private func makeSUT(
        startingInput: RecordPurchaseFormInput?,
        item: ListItem = ItemFixtures.item(id: "item-1", quantity: 8, quantityRemaining: 5),
        capabilities: ListCapabilities = RecordPurchaseTestCaps.buyer
    ) async -> RecordPurchaseModel {
        let base = await makePurchaseServiceSUT()
        return RecordPurchaseModel(
            item: item,
            context: ItemListContext(capabilities: capabilities),
            service: base.service,
            now: PurchaseTestClock().provider,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US"),
            startingInput: startingInput
        )
    }

    @Test("With a nil starting input the initial input is the default")
    func nilIsDefault() async {
        let model = await makeSUT(startingInput: nil)
        #expect(model.input == RecordPurchaseFormInput(
            quantity: 5, totalCostText: "", storeName: "", notes: "", confirmationNumber: "", trackingNumber: ""
        ))
    }

    @Test("Omitting the parameter is the same as nil")
    func omittedIsNil() async {
        let base = await makePurchaseServiceSUT()
        let model = RecordPurchaseModel(
            item: ItemFixtures.item(id: "item-1", quantity: 8, quantityRemaining: 5),
            context: ItemListContext(capabilities: RecordPurchaseTestCaps.buyer),
            service: base.service,
            now: PurchaseTestClock().provider,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US")
        )
        let explicit = await makeSUT(startingInput: nil)
        #expect(model.input == explicit.input)
    }

    @Test("With a starting input the model's input equals it, whatever the remaining quantity")
    func startingInputIsInitial() async {
        let model = await makeSUT(startingInput: Self.starting)
        #expect(model.input == Self.starting)
        let unknownRemaining = await makeSUT(
            startingInput: Self.starting, item: ItemFixtures.item(id: "item-1", quantity: 1)
        )
        #expect(unknownRemaining.input == Self.starting)
    }

    @Test("Every other derived value matches the default model given the same input")
    func otherwiseLikeDefault() async {
        let withStarting = await makeSUT(startingInput: Self.starting)
        let defaultModel = await makeSUT(startingInput: nil)
        defaultModel.input = Self.starting

        #expect(withStarting.isAllowed == defaultModel.isAllowed)
        #expect(withStarting.isAllowed == true)
        #expect(withStarting.canTapRecord == defaultModel.canTapRecord)
        #expect(withStarting.canTapRecord == true)
        #expect(withStarting.fieldsAreReadOnly == false)
        #expect(withStarting.fieldsAreReadOnly == defaultModel.fieldsAreReadOnly)
        #expect(withStarting.finish == nil)
        #expect(withStarting.flow.state == .editing)
        #expect(withStarting.flow.state == defaultModel.flow.state)
        #expect(withStarting.isSubmitting == false)
        #expect(withStarting.errorBanner == nil)
        #expect(withStarting.panel == nil)
        #expect(withStarting.summary == defaultModel.summary)
    }

    @Test("A starting input without a total cannot be recorded yet")
    func startingInputWithoutTotal() async {
        var input = Self.starting
        input.totalCostText = ""
        let model = await makeSUT(startingInput: input)
        #expect(model.input == input)
        #expect(model.canTapRecord == false)
    }

    @Test("A model without purchase capability is not allowed even with a starting input")
    func notAllowedWithoutCapability() async {
        let model = await makeSUT(
            startingInput: Self.starting,
            capabilities: ItemFixtures.capabilities(canSeeGiftActivity: true, canPurchase: false)
        )
        #expect(model.isAllowed == false)
        #expect(model.canTapRecord == false)
        #expect(model.input == Self.starting)
    }

    @Test("The starting input stays editable like the default input")
    func stillEditable() async {
        let model = await makeSUT(startingInput: Self.starting)
        model.input.totalCostText = "40.00"
        model.input.storeName = "Fake Store"
        #expect(model.input.totalCostText == "40.00")
        #expect(model.input.storeName == "Fake Store")
        #expect(model.input.quantity == 3)
    }
}
