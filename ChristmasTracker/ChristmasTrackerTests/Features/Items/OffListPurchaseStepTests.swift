//
//  OffListPurchaseStepTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: the post-create state machine. A second create is impossible once an item
//  exists; a failed create returns to idle.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase step Tests")
struct OffListPurchaseStepTests {

    private let created = ItemFixtures.item(id: "item-new", name: "Fake Surprise")

    private func makeSUT(_ state: OffListPurchaseStep = .idle) -> OffListPurchaseStep { state }

    private func awaiting() -> OffListPurchaseStep {
        var sut = makeSUT()
        _ = sut.beginCreate()
        sut.createSucceeded(created, opensPurchase: true)
        return sut
    }

    private func finished() -> OffListPurchaseStep {
        var sut = awaiting()
        sut.purchaseFinished()
        return sut
    }

    @Test("Idle allows create and begins creating")
    func idleBegins() {
        var sut = makeSUT()
        #expect(sut.allowsCreate == true)
        #expect(sut.pendingItem == nil)
        #expect(sut.beginCreate() == true)
        #expect(sut == .creating)
        #expect(sut.allowsCreate == false)
        #expect(sut.pendingItem == nil)
    }

    @Test("A second beginCreate while creating returns false and changes nothing")
    func beginWhileCreating() {
        var sut = makeSUT(.creating)
        #expect(sut.beginCreate() == false)
        #expect(sut == .creating)
    }

    @Test("A second beginCreate after createdAwaitingPurchase returns false and keeps the item")
    func beginWhileAwaiting() {
        var sut = awaiting()
        #expect(sut == .createdAwaitingPurchase(created))
        #expect(sut.beginCreate() == false)
        #expect(sut == .createdAwaitingPurchase(created))
        #expect(sut.pendingItem == created)
        #expect(sut.allowsCreate == false)
    }

    @Test("A beginCreate after finished returns false")
    func beginWhileFinished() {
        var sut = finished()
        #expect(sut.beginCreate() == false)
        #expect(sut == .finished)
        #expect(sut.allowsCreate == false)
        #expect(sut.pendingItem == nil)
    }

    @Test("A failed create returns to idle and allows a new create")
    func failedReturnsToIdle() {
        var sut = makeSUT()
        _ = sut.beginCreate()
        sut.createFailed()
        #expect(sut == .idle)
        #expect(sut.allowsCreate == true)
        #expect(sut.beginCreate() == true)
        #expect(sut == .creating)
    }

    @Test("A successful create that opens the purchase waits for it with the item")
    func succeededOpens() {
        let sut = awaiting()
        #expect(sut.pendingItem == created)
        #expect(sut.allowsCreate == false)
    }

    @Test("A successful create that does not open the purchase is finished")
    func succeededWithoutPurchase() {
        var sut = makeSUT()
        _ = sut.beginCreate()
        sut.createSucceeded(created, opensPurchase: false)
        #expect(sut == .finished)
        #expect(sut.pendingItem == nil)
        #expect(sut.allowsCreate == false)
    }

    @Test("purchaseFinished moves createdAwaitingPurchase to finished and finished stays")
    func purchaseFinishedTransitions() {
        var sut = awaiting()
        sut.purchaseFinished()
        #expect(sut == .finished)
        #expect(sut.pendingItem == nil)
        sut.purchaseFinished()
        #expect(sut == .finished)
    }

    @Test("Out-of-order transitions are ignored")
    func outOfOrder() {
        var idle = makeSUT()
        idle.createSucceeded(created, opensPurchase: true)
        #expect(idle == .idle)
        idle.createSucceeded(created, opensPurchase: false)
        #expect(idle == .idle)
        idle.createFailed()
        #expect(idle == .idle)
        idle.purchaseFinished()
        #expect(idle == .idle)

        var creating = makeSUT(.creating)
        creating.purchaseFinished()
        #expect(creating == .creating)

        var waiting = awaiting()
        waiting.createFailed()
        #expect(waiting == .createdAwaitingPurchase(created))
        waiting.createSucceeded(ItemFixtures.item(id: "item-other"), opensPurchase: false)
        #expect(waiting == .createdAwaitingPurchase(created))

        var done = finished()
        done.createFailed()
        #expect(done == .finished)
        done.createSucceeded(created, opensPurchase: true)
        #expect(done == .finished)
    }

    @Test("allowsCreate is true only in idle")
    func allowsCreateOnlyIdle() {
        #expect(makeSUT(.idle).allowsCreate == true)
        #expect(makeSUT(.creating).allowsCreate == false)
        #expect(awaiting().allowsCreate == false)
        #expect(finished().allowsCreate == false)
    }

    @Test("pendingItem is non-nil only while awaiting the purchase")
    func pendingItemOnlyAwaiting() {
        #expect(makeSUT(.idle).pendingItem == nil)
        #expect(makeSUT(.creating).pendingItem == nil)
        #expect(awaiting().pendingItem == created)
        #expect(finished().pendingItem == nil)
    }
}
