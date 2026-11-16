//
//  OffListPurchaseSheetSessionEndTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O2 (decision 9): a session end while the purchase sheet is open leaves the step as it
//  is until the sheet reports purchaseFinished; after that a second create is impossible.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase sheet session end Tests", .timeLimit(.minutes(1)))
@MainActor
struct OffListPurchaseSheetSessionEndTests {

    private let created = ItemFixtures.item(id: "item-new", name: "Fake Surprise")

    private func makeSUT() -> OffListPurchaseStep {
        var step = OffListPurchaseStep.idle
        _ = step.beginCreate()
        step.createSucceeded(created, opensPurchase: true)
        return step
    }

    @Test("a session end leaves pendingItem unchanged until purchaseFinished, then a create is rejected")
    func sessionEndWhileSheetOpen() async throws {
        var step = makeSUT()
        let items = await makeItemServiceSUT()
        let purchases = await makePurchaseServiceSUT()
        await items.manager.teardown(reason: .sessionExpired)
        try await purchases.service.clearForSession()

        #expect(step == .createdAwaitingPurchase(created))
        #expect(step.pendingItem == created)
        #expect(step.allowsCreate == false)
        #expect(step.beginCreate() == false)
        #expect(step.pendingItem == created)

        step.purchaseFinished()

        #expect(step == .finished)
        #expect(step.pendingItem == nil)
        #expect(step.beginCreate() == false)
        #expect(step == .finished)
        #expect(step.allowsCreate == false)
    }

    @Test("a late createFailed or createSucceeded after the session end does not change the awaiting step")
    func lateCreateResultsAreIgnored() async {
        var step = makeSUT()
        let items = await makeItemServiceSUT()
        await items.manager.teardown(reason: .userLogout)

        step.createFailed()
        step.createSucceeded(ItemFixtures.item(id: "item-other"), opensPurchase: true)

        #expect(step == .createdAwaitingPurchase(created))
    }
}
