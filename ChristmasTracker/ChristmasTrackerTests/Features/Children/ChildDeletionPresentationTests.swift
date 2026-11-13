//
//  ChildDeletionPresentationTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-F1: the pure transition table of ChildDeletionPresentation. Every phase times every
//  event, including the ignored ones. Deterministic: no sleeps, no tasks. Fake ids only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child deletion presentation transition Tests")
struct ChildDeletionPresentationTests {

    typealias Kind = ChildDeletionPhaseKind

    private static let child = Kind.childId
    private static let other = Kind.otherChildId
    private static let plan = Kind.plan

    private nonisolated static let archivePlans: [ChildDeletionPlan] = [
        .archiveThenDelete(listIds: ["list-1"]),
        .archiveThenDelete(listIds: ["list-1", "list-2", "list-3"]),
        .deleteNow
    ]

    // MARK: - Factory

    private func makeSUT(_ kind: Kind = .idle, childId: String = Kind.childId) -> ChildDeletionPresentation {
        kind.make(childId: childId)
    }

    // MARK: - Starting states

    @Test("The idle value is idle")
    func idleValue() {
        let sut = ChildDeletionPresentation.idle
        #expect(sut.phase == .idle)
        #expect(sut.isIdle)
        #expect(sut.deletingChildId == nil)
    }

    // MARK: - requestDelete

    @Test("requestDelete from idle moves to planning for that child")
    func requestDeleteFromIdle() {
        let sut = makeSUT(.idle).requestDelete(childId: Self.child)
        #expect(sut.phase == .planning(childId: Self.child))
    }

    @Test("requestDelete is ignored while planning, confirming or executing (same child)",
          arguments: [Kind.planning, .confirming, .executing])
    func requestDeleteIgnoredSameChild(kind: Kind) {
        let before = makeSUT(kind)
        #expect(before.requestDelete(childId: Self.child) == before)
    }

    @Test("requestDelete for another child is ignored while not idle",
          arguments: [Kind.planning, .confirming, .executing])
    func requestDeleteIgnoredOtherChild(kind: Kind) {
        let before = makeSUT(kind)
        #expect(before.requestDelete(childId: Self.other) == before)
    }

    @Test("A second requestDelete after the first (the double Try Again) changes nothing")
    func doubleRequestDelete() {
        let first = makeSUT(.idle).requestDelete(childId: Self.child)
        #expect(first.requestDelete(childId: Self.child) == first)
        #expect(first.requestDelete(childId: Self.other) == first)
    }

    // MARK: - planReady

    @Test("planReady from planning with confirmation required gives confirming in one step",
          arguments: ChildDeletionPresentationTests.archivePlans)
    func planReadyRequiringConfirmation(plan: ChildDeletionPlan) {
        let transition = makeSUT(.planning).planReady(childId: Self.child, plan: plan, requiresConfirmation: true)
        #expect(transition.presentation.phase == .confirming(childId: Self.child, plan: plan))
        #expect(transition.presentation.isIdle == false)
        #expect(transition.banner == nil)
        #expect(transition.plan == nil)
    }

    @Test("planReady from planning without confirmation goes straight to executing with the plan",
          arguments: ChildDeletionPresentationTests.archivePlans)
    func planReadyWithoutConfirmation(plan: ChildDeletionPlan) {
        let transition = makeSUT(.planning).planReady(childId: Self.child, plan: plan, requiresConfirmation: false)
        #expect(transition.presentation.phase == .executing(childId: Self.child))
        #expect(transition.banner == nil)
        #expect(transition.plan == plan)
    }

    @Test("planReady with a blocked plan goes to idle with the blocked banner and no plan",
          arguments: [true, false])
    func planReadyBlocked(requiresConfirmation: Bool) {
        let transition = makeSUT(.planning)
            .planReady(childId: Self.child, plan: .blocked, requiresConfirmation: requiresConfirmation)
        #expect(transition.presentation.phase == .idle)
        #expect(transition.presentation.isIdle)
        #expect(transition.banner == .blocked)
        #expect(transition.plan == nil)
    }

    @Test("planReady is ignored outside planning (idle, confirming, executing), whatever the plan",
          arguments: [Kind.idle, .confirming, .executing],
          ChildDeletionPresentationTests.archivePlans + [.blocked])
    func planReadyIgnoredWrongPhase(kind: Kind, plan: ChildDeletionPlan) {
        let before = makeSUT(kind)
        for requires in [true, false] {
            let transition = before.planReady(childId: Self.child, plan: plan, requiresConfirmation: requires)
            #expect(transition.presentation == before)
            #expect(transition.banner == nil)
            #expect(transition.plan == nil)
        }
    }

    @Test("planReady for another child while planning is ignored", arguments: ChildDeletionPresentationTests.archivePlans + [.blocked])
    func planReadyIgnoredOtherChild(plan: ChildDeletionPlan) {
        let before = makeSUT(.planning)
        for requires in [true, false] {
            let transition = before.planReady(childId: Self.other, plan: plan, requiresConfirmation: requires)
            #expect(transition.presentation == before)
            #expect(transition.banner == nil)
            #expect(transition.plan == nil)
        }
    }

    // MARK: - planFailed

    @Test("planFailed from planning goes to idle with the failed banner request",
          arguments: [ChildError.server, .network, .rateLimited(retryAfter: 5), .sessionEnded])
    func planFailedFromPlanning(error: ChildError) {
        let transition = makeSUT(.planning).planFailed(childId: Self.child, error: error)
        #expect(transition.presentation.phase == .idle)
        #expect(transition.banner == .failed(error))
        #expect(transition.plan == nil)
    }

    @Test("planFailed is ignored outside planning (idle, confirming, executing)",
          arguments: [Kind.idle, .confirming, .executing])
    func planFailedIgnoredWrongPhase(kind: Kind) {
        let before = makeSUT(kind)
        let transition = before.planFailed(childId: Self.child, error: .server)
        #expect(transition.presentation == before)
        #expect(transition.banner == nil)
        #expect(transition.plan == nil)
    }

    @Test("planFailed for another child while planning is ignored")
    func planFailedIgnoredOtherChild() {
        let before = makeSUT(.planning)
        let transition = before.planFailed(childId: Self.other, error: .server)
        #expect(transition.presentation == before)
        #expect(transition.banner == nil)
        #expect(transition.plan == nil)
    }

    // MARK: - cancelConfirmation

    @Test("cancelConfirmation from confirming goes to idle (nothing is deleted)")
    func cancelFromConfirming() {
        let sut = makeSUT(.confirming).cancelConfirmation()
        #expect(sut.phase == .idle)
        #expect(sut.deletingChildId == nil)
    }

    @Test("cancelConfirmation is ignored while idle, planning or executing",
          arguments: [Kind.idle, .planning, .executing])
    func cancelIgnored(kind: Kind) {
        let before = makeSUT(kind)
        #expect(before.cancelConfirmation() == before)
    }

    // MARK: - confirm

    @Test("confirm from confirming moves to executing with the plan set")
    func confirmFromConfirming() {
        let transition = makeSUT(.confirming).confirm(childId: Self.child, plan: Self.plan)
        #expect(transition.presentation.phase == .executing(childId: Self.child))
        #expect(transition.plan == Self.plan)
        #expect(transition.banner == nil)
    }

    @Test("A second confirm is ignored: the plan is handed out exactly once")
    func secondConfirmIgnored() {
        let first = makeSUT(.confirming).confirm(childId: Self.child, plan: Self.plan)
        #expect(first.plan == Self.plan)
        let second = first.presentation.confirm(childId: Self.child, plan: Self.plan)
        #expect(second.presentation == first.presentation)
        #expect(second.plan == nil)
        #expect(second.banner == nil)
    }

    @Test("confirm with a mismatched plan is ignored, so a stale dialog cannot delete anything")
    func confirmMismatchedPlanIgnored() {
        let before = makeSUT(.confirming)
        let transition = before.confirm(childId: Self.child, plan: Kind.otherPlan)
        #expect(transition.presentation == before)
        #expect(transition.plan == nil)
        #expect(transition.banner == nil)
    }

    @Test("confirm for another child while confirming is ignored")
    func confirmOtherChildIgnored() {
        let before = makeSUT(.confirming)
        let transition = before.confirm(childId: Self.other, plan: Self.plan)
        #expect(transition.presentation == before)
        #expect(transition.plan == nil)
    }

    @Test("confirm is ignored while idle, planning or executing (a dismissed dialog cannot delete)",
          arguments: [Kind.idle, .planning, .executing])
    func confirmWrongPhaseIgnored(kind: Kind) {
        let before = makeSUT(kind)
        let transition = before.confirm(childId: Self.child, plan: Self.plan)
        #expect(transition.presentation == before)
        #expect(transition.plan == nil)
        #expect(transition.banner == nil)
    }

    @Test("confirm after cancelConfirmation is ignored")
    func confirmAfterCancelIgnored() {
        let cancelled = makeSUT(.confirming).cancelConfirmation()
        let transition = cancelled.confirm(childId: Self.child, plan: Self.plan)
        #expect(transition.presentation == cancelled)
        #expect(transition.plan == nil)
    }

    // MARK: - executionFinished

    @Test("executionFinished from executing goes to idle")
    func executionFinishedFromExecuting() {
        let sut = makeSUT(.executing).executionFinished(childId: Self.child)
        #expect(sut.phase == .idle)
        #expect(sut.isIdle)
    }

    @Test("executionFinished for another child while executing is ignored")
    func executionFinishedOtherChildIgnored() {
        let before = makeSUT(.executing)
        #expect(before.executionFinished(childId: Self.other) == before)
    }

    @Test("executionFinished is ignored while idle, planning or confirming",
          arguments: [Kind.idle, .planning, .confirming])
    func executionFinishedWrongPhaseIgnored(kind: Kind) {
        let before = makeSUT(kind)
        #expect(before.executionFinished(childId: Self.child) == before)
    }

    // MARK: - reset

    @Test("reset goes to idle from every phase", arguments: Kind.allCases)
    func resetFromEveryPhase(kind: Kind) {
        let sut = makeSUT(kind).reset()
        #expect(sut.phase == .idle)
        #expect(sut.isIdle)
        #expect(sut.deletingChildId == nil)
    }

    // MARK: - childrenChanged

    @Test("childrenChanged keeps confirming while the child is still present")
    func childrenChangedPresent() {
        let before = makeSUT(.confirming)
        #expect(before.childrenChanged(existingIds: [Self.child]) == before)
        #expect(before.childrenChanged(existingIds: [Self.other, Self.child]) == before)
    }

    @Test("childrenChanged resets confirming to idle when the child is gone")
    func childrenChangedGone() {
        let sut = makeSUT(.confirming).childrenChanged(existingIds: [Self.other])
        #expect(sut.phase == .idle)
        #expect(makeSUT(.confirming).childrenChanged(existingIds: []).phase == .idle)
    }

    @Test("childrenChanged never touches idle, planning or executing, even if the child is missing",
          arguments: [Kind.idle, .planning, .executing])
    func childrenChangedOtherPhases(kind: Kind) {
        let before = makeSUT(kind)
        #expect(before.childrenChanged(existingIds: []) == before)
        #expect(before.childrenChanged(existingIds: [Self.other]) == before)
        #expect(before.childrenChanged(existingIds: [Self.child]) == before)
    }

    // MARK: - One-step confirmation and derived values

    @Test("planReady lands directly in confirming for exactly that child with that plan")
    func confirmingInOneStep() {
        let planning = makeSUT(.planning)
        let result = planning.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true).presentation
        #expect(result.phase == .confirming(childId: Self.child, plan: Self.plan))
        #expect(result.isConfirming(childId: Self.child))
        #expect(result.confirmingPlan(for: Self.child) == Self.plan)
    }

    @Test("deletingChildId is derived: set while planning and executing, nil while idle and confirming")
    func deletingChildIdDerived() {
        #expect(makeSUT(.idle).deletingChildId == nil)
        #expect(makeSUT(.planning).deletingChildId == Self.child)
        #expect(makeSUT(.confirming).deletingChildId == nil)
        #expect(makeSUT(.executing).deletingChildId == Self.child)
    }

    @Test("isIdle is true only for the idle phase")
    func isIdleDerived() {
        #expect(makeSUT(.idle).isIdle)
        #expect(!makeSUT(.planning).isIdle)
        #expect(!makeSUT(.confirming).isIdle)
        #expect(!makeSUT(.executing).isIdle)
    }

    @Test("isConfirming and confirmingPlan answer only for the confirming child")
    func confirmingQueries() {
        let confirming = makeSUT(.confirming)
        #expect(confirming.isConfirming(childId: Self.child))
        #expect(!confirming.isConfirming(childId: Self.other))
        #expect(confirming.confirmingPlan(for: Self.child) == Self.plan)
        #expect(confirming.confirmingPlan(for: Self.other) == nil)
        for kind in [Kind.idle, .planning, .executing] {
            let sut = makeSUT(kind)
            #expect(!sut.isConfirming(childId: Self.child))
            #expect(sut.confirmingPlan(for: Self.child) == nil)
        }
    }

    // MARK: - The child vanishing while planning

    @Test("requestDelete, planReady (confirmation required), then childrenChanged without the child ends idle with no banner")
    func childVanishedDuringPlanning() {
        var sut = makeSUT(.idle).requestDelete(childId: Self.child)
        let transition = sut.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true)
        #expect(transition.presentation.isConfirming(childId: Self.child))
        sut = transition.presentation.childrenChanged(existingIds: [Self.other])
        #expect(sut.phase == .idle)
        #expect(sut.isIdle)
        #expect(sut.deletingChildId == nil)
        #expect(sut.confirmingPlan(for: Self.child) == nil)
        #expect(sut.confirm(childId: Self.child, plan: Self.plan).plan == nil)
    }

    @Test("The same sequence with the child still present stays confirming")
    func childPresentAfterPlanning() {
        var sut = makeSUT(.idle).requestDelete(childId: Self.child)
        sut = sut.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true).presentation
        sut = sut.childrenChanged(existingIds: [Self.other, Self.child])
        #expect(sut.phase == .confirming(childId: Self.child, plan: Self.plan))
    }

    // MARK: - Whole flows

    @Test("Happy path: request, plan ready, confirm, finished returns to idle")
    func wholeHappyPath() throws {
        var sut = makeSUT(.idle).requestDelete(childId: Self.child)
        sut = sut.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true).presentation
        let confirmed = sut.confirm(childId: Self.child, plan: Self.plan)
        #expect(try #require(confirmed.plan) == Self.plan)
        sut = confirmed.presentation.executionFinished(childId: Self.child)
        #expect(sut.phase == .idle)
    }

    @Test("Cancel path: request, plan ready, cancel returns to idle and nothing is handed out")
    func wholeCancelPath() {
        var sut = makeSUT(.idle).requestDelete(childId: Self.child)
        sut = sut.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true).presentation
        sut = sut.cancelConfirmation()
        #expect(sut.phase == .idle)
        #expect(sut.confirm(childId: Self.child, plan: Self.plan).plan == nil)
    }

    @Test("Try Again path: request, plan ready without confirmation, finished returns to idle")
    func wholeTryAgainPath() {
        var sut = makeSUT(.idle).requestDelete(childId: Self.child)
        let transition = sut.planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: false)
        #expect(transition.plan == Self.plan)
        sut = transition.presentation.executionFinished(childId: Self.child)
        #expect(sut.phase == .idle)
    }
}
