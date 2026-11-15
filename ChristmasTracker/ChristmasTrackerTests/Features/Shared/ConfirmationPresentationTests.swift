//
//  ConfirmationPresentationTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: the pure transition table of ConfirmationPresentation. Every state times every
//  event, including the ignored ones. Deterministic: no sleeps, no tasks. Fake ids only.
//

import Testing
@testable import ChristmasTracker

@Suite("Confirmation presentation transition Tests")
struct ConfirmationPresentationTests {

    nonisolated enum Item: Hashable, Sendable {
        case leave
        case remove(id: String)
    }

    typealias Presentation = ConfirmationPresentation<Item>

    private static let alice = Item.remove(id: "user-alice")
    private static let bob = Item.remove(id: "user-bob")

    // MARK: - Factory

    private func makeSUT(confirming target: Item? = nil) -> Presentation {
        guard let target else { return .idle }
        return Presentation.idle.requesting(target)
    }

    // MARK: - Starting state

    @Test("OLD: the dialog state was a loose Bool/optional pair with no single idle value; the idle value is idle")
    func idleValue() {
        let sut = Presentation.idle
        #expect(sut.target == nil)
        #expect(sut.isIdle)
        #expect(!sut.isConfirming(Self.alice))
        #expect(!sut.isConfirming(.leave))
    }

    // MARK: - requesting

    @Test("OLD: a request could be replaced mid-dialog; requesting from idle confirms that target")
    func requestingFromIdle() {
        let sut = makeSUT().requesting(Self.alice)
        #expect(sut.target == Self.alice)
        #expect(!sut.isIdle)
        #expect(sut.isConfirming(Self.alice))
        #expect(!sut.isConfirming(Self.bob))
    }

    @Test("OLD: a second request replaced the open dialog's target; a second request is ignored")
    func secondRequestIgnored() {
        let first = makeSUT(confirming: Self.alice)
        let sut = first.requesting(Self.bob)
        #expect(sut == first)
        #expect(sut.isConfirming(Self.alice))
        #expect(!sut.isConfirming(Self.bob))
    }

    @Test("OLD: re-requesting the same target was a fresh set; the same request again changes nothing")
    func sameRequestAgainIgnored() {
        let first = makeSUT(confirming: Self.alice)
        #expect(first.requesting(Self.alice) == first)
    }

    // MARK: - cancelled

    @Test("OLD: dismissal cleared state through a set-then-clear binding; cancelled returns to idle")
    func cancelledFromConfirming() {
        let sut = makeSUT(confirming: Self.alice).cancelled()
        #expect(sut.isIdle)
        #expect(sut == Presentation.idle)
    }

    @Test("Cancelled from idle stays idle")
    func cancelledFromIdle() {
        #expect(makeSUT().cancelled().isIdle)
    }

    // MARK: - confirmed

    @Test("OLD: the confirm button read a loose optional; confirmed with the right target runs it and goes idle")
    func confirmedRightTarget() {
        let result = makeSUT(confirming: Self.alice).confirmed(Self.alice)
        #expect(result.presentation.isIdle)
        #expect(result.run == Self.alice)
    }

    @Test("OLD: a stale confirm could act on another target; confirmed with the wrong target is unchanged and runs nothing")
    func confirmedWrongTarget() {
        let start = makeSUT(confirming: Self.alice)
        let result = start.confirmed(Self.bob)
        #expect(result.presentation == start)
        #expect(result.run == nil)
    }

    @Test("OLD: a confirm after the dialog closed could still run; confirmed from idle runs nothing")
    func confirmedFromIdle() {
        let result = makeSUT().confirmed(Self.alice)
        #expect(result.presentation.isIdle)
        #expect(result.run == nil)
    }

    @Test("Confirming leave runs leave, not a member")
    func confirmedLeave() {
        let result = makeSUT(confirming: .leave).confirmed(.leave)
        #expect(result.run == Item.leave)
        #expect(result.presentation.isIdle)
    }

    // MARK: - targetsChanged

    @Test("OLD: a re-render or reload dismissed an open dialog; the same ids leave it unchanged")
    func targetsChangedSameIds() {
        let start = makeSUT(confirming: Self.alice)
        let sut = start.targetsChanged(existing: [Self.alice])
        #expect(sut == start)
        #expect(sut.isConfirming(Self.alice))
    }

    @Test("OLD: a reload with extra rows dismissed the dialog; extra ids leave it unchanged")
    func targetsChangedExtraIds() {
        let start = makeSUT(confirming: Self.alice)
        let sut = start.targetsChanged(existing: [Self.alice, Self.bob, .leave])
        #expect(sut == start)
    }

    @Test("OLD: a vanished target left a dialog open on nothing; a target no longer present resets to idle")
    func targetsChangedTargetGone() {
        let sut = makeSUT(confirming: Self.alice).targetsChanged(existing: [Self.bob])
        #expect(sut.isIdle)
    }

    @Test("A target gone with an empty set resets to idle")
    func targetsChangedEmptySet() {
        #expect(makeSUT(confirming: Self.alice).targetsChanged(existing: []).isIdle)
    }

    @Test("targetsChanged on idle stays idle")
    func targetsChangedFromIdle() {
        #expect(makeSUT().targetsChanged(existing: [Self.alice]).isIdle)
    }

    // MARK: - reset

    @Test("OLD: session end or disappear left the dialog state behind; reset from confirming is idle")
    func resetFromConfirming() {
        #expect(makeSUT(confirming: Self.bob).reset().isIdle)
    }

    @Test("Reset from idle stays idle")
    func resetFromIdle() {
        #expect(makeSUT().reset() == Presentation.idle)
    }

    // MARK: - Sequence

    @Test("A full cycle: request, targetsChanged with the same ids, confirm, then a new request works")
    func fullCycle() {
        var sut = makeSUT().requesting(Self.alice)
        sut = sut.targetsChanged(existing: [Self.alice, Self.bob])
        let result = sut.confirmed(Self.alice)
        #expect(result.run == Self.alice)
        sut = result.presentation.requesting(Self.bob)
        #expect(sut.isConfirming(Self.bob))
    }
}
