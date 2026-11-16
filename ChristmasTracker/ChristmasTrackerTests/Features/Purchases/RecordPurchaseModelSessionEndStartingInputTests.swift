//
//  RecordPurchaseModelSessionEndStartingInputTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O2 (decision 9): a session end while the prefilled purchase call is in flight records
//  nothing and shows nothing beyond what the existing flow does (failed(.sessionEnded), no banner).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model session end with starting input Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelSessionEndStartingInputTests {

    private static let starting = RecordPurchaseFormInput(
        quantity: 2,
        totalCostText: "37.50",
        storeName: "",
        notes: "",
        confirmationNumber: "",
        trackingNumber: ""
    )

    private struct SUT {
        let model: RecordPurchaseModel
        let base: PurchaseServiceSUT
    }

    private func makeSUT() async -> SUT {
        let base = await makePurchaseServiceSUT()
        let model = RecordPurchaseModel(
            item: ItemFixtures.item(id: "item-1", quantity: 3),
            context: ItemListContext(capabilities: RecordPurchaseTestCaps.buyer),
            service: base.service,
            now: PurchaseTestClock().provider,
            currencyCode: "USD",
            locale: Locale(identifier: "en_US"),
            startingInput: Self.starting
        )
        return SUT(model: model, base: base)
    }

    @Test("a teardown while the prefilled record call is in flight records nothing and keeps the input")
    func teardownInFlight() async {
        let sut = await makeSUT()
        sut.base.repo.enqueue(created: PurchaseFixtures.recordedPurchase(), held: true)
        let task = Task { @MainActor in await sut.model.recordTapped() }
        await sut.base.repo.gate.nextHeldCall()

        await sut.base.manager.teardown(reason: .userLogout)
        sut.base.repo.gate.releaseAll()
        await task.value

        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == .failed(.sessionEnded))
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.isSubmitting == false)
        #expect(sut.model.input == Self.starting)
        #expect(sut.base.repo.callCount == 1)
        #expect(sut.base.service.isMutating == false)
    }

    @Test("a session end before the call starts leaves the starting input and the open form untouched")
    func teardownBeforeSubmit() async {
        let sut = await makeSUT()

        await sut.base.manager.teardown(reason: .sessionExpired)

        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.input == Self.starting)
        #expect(sut.base.repo.callCount == 0)
    }

    @Test("a cancelled caller (CancellationError from the repository) does not record either")
    func cancellationInFlight() async {
        let sut = await makeSUT()
        sut.base.repo.enqueueFailure(CancellationError())

        await sut.model.recordTapped()

        #expect(sut.model.finish == nil)
        #expect(sut.model.flow.state == .failed(.sessionEnded))
        #expect(sut.model.errorBanner == nil)
        #expect(sut.model.input == Self.starting)
    }
}
