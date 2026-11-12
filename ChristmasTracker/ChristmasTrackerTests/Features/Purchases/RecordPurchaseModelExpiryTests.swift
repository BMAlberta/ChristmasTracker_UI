//
//  RecordPurchaseModelExpiryTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (e): expiry of a pending confirmation at 270 seconds (4:30; the server allows 5
//  minutes), driven only by the injected PurchaseTestClock. `confirmBudget` after expiry is refused
//  with no call; `expiryReached` moves to expired when due; the expired message has one way back to
//  editing; `expiryDelay` is the time left, never negative, and nil outside awaitingConfirmation.
//
//  Fails today because RecordPurchaseModel does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase model expiry Tests", .timeLimit(.minutes(1)))
@MainActor
struct RecordPurchaseModelExpiryTests {

    private let token = RecordPurchaseTestToken.first

    private func makeSUT() async -> RecordPurchaseModelSUT {
        let sut = await makeRecordPurchaseModelSUT(item: ItemFixtures.item(id: "item-1", quantity: 3))
        await sut.driveToAwaiting(token: token)
        return sut
    }

    // MARK: expiryDelay

    @Test("expiryDelay is nil while editing")
    func delayNilWhileEditing() async {
        let sut = await makeRecordPurchaseModelSUT()
        #expect(sut.model.expiryDelay == nil)
    }

    @Test("expiryDelay is the full lifetime right after the confirmation and shrinks with the clock")
    func delayShrinks() async {
        let sut = await makeSUT()
        #expect(sut.model.expiryDelay == .seconds(270))

        sut.clock.advance(by: 100)
        #expect(sut.model.expiryDelay == .seconds(170))

        sut.clock.advance(by: 169)
        #expect(sut.model.expiryDelay == .seconds(1))
    }

    @Test("expiryDelay is never negative", arguments: [270.0, 271.0, 3_600.0])
    func delayNeverNegative(seconds: TimeInterval) async {
        let sut = await makeSUT()
        sut.clock.advance(by: seconds)
        #expect(sut.model.expiryDelay == .zero)
    }

    @Test("expiryDelay is nil again after leaving awaitingConfirmation")
    func delayNilAfterLeaving() async {
        let sut = await makeSUT()
        sut.model.editDetails()
        #expect(sut.model.expiryDelay == nil)
    }

    // MARK: confirmBudget at the boundary

    @Test("confirmBudget just before 270 seconds still sends the token")
    func confirmJustBefore() async {
        let sut = await makeSUT()
        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        sut.clock.advance(by: 269)

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 2)
        #expect(sut.repo.calls[1].token == token)
        #expect(sut.model.showsExpired == false)
    }

    @Test("confirmBudget at exactly 270 seconds is refused: no call, the expired state")
    func confirmAtBoundary() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 270)

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.showsExpired == true)
        #expect(sut.model.flow.state == .expired)
        #expect(sut.model.panel == nil)
        #expect(sut.model.finish == nil)
        #expect(!String(describing: sut.model.flow).contains(token))
    }

    // MARK: expiryReached

    @Test("expiryReached before the deadline changes nothing")
    func reachedTooEarly() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 269)

        sut.model.expiryReached()

        #expect(sut.model.showsExpired == false)
        #expect(sut.model.panel != nil)
    }

    @Test("expiryReached when due shows the expired message and drops the panel and the token")
    func reachedWhenDue() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 270)

        sut.model.expiryReached()

        #expect(sut.model.showsExpired == true)
        #expect(RecordPurchaseCopy.expiredMessage == "This confirmation has expired. Review the details and record again.")
        #expect(sut.model.panel == nil)
        #expect(sut.model.expiryDelay == nil)
        #expect(sut.model.fieldsAreReadOnly == true)
        #expect(sut.model.showsRecordButton == false)
        #expect(!String(describing: sut.model.flow).contains(token))
        #expect(sut.repo.callCount == 1)
    }

    @Test("From expired, Edit Details goes back to editing and the next submit has no token")
    func expiredBackToEditing() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 300)
        sut.model.expiryReached()

        sut.model.editDetails()

        #expect(sut.model.showsExpired == false)
        #expect(sut.model.flow.state == .editing)
        #expect(sut.model.fieldsAreReadOnly == false)
        #expect(sut.model.showsRecordButton == true)

        sut.repo.enqueue(created: PurchaseFixtures.recordedPurchase())
        await sut.model.recordTapped()
        #expect(sut.repo.calls.last?.token == nil)
        #expect(sut.model.finish == .recorded(PurchaseFixtures.recordedPurchase()))
    }

    @Test("A confirm while expired sends nothing")
    func confirmWhileExpired() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 300)
        sut.model.expiryReached()

        await sut.model.confirmBudget()

        #expect(sut.repo.callCount == 1)
        #expect(sut.model.showsExpired == true)
    }

    @Test("A replacement confirmation (S12) restarts the clock from its own issue time")
    func replacementRestartsClock() async {
        let sut = await makeSUT()
        sut.clock.advance(by: 200)
        sut.enqueueConfirmation(token: RecordPurchaseTestToken.second, spent: "100.00")
        await sut.model.confirmBudget()

        #expect(sut.model.expiryDelay == .seconds(270))

        sut.clock.advance(by: 100)
        #expect(sut.model.expiryDelay == .seconds(170))
        sut.model.expiryReached()
        #expect(sut.model.showsExpired == false)
    }
}
