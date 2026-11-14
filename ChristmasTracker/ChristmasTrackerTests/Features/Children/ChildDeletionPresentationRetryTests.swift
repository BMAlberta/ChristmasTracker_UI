//
//  ChildDeletionPresentationRetryTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B5: OLD behavior: Try Again always continued without a new dialog (planReady with
//  requiresConfirmation: false). NEW: retryPlanReady re-confirms when the recomputed plan would
//  archive a list the user never confirmed. Deterministic, pure. Fake ids only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Child deletion presentation retry Tests")
struct ChildDeletionPresentationRetryTests {

    typealias Kind = ChildDeletionPhaseKind

    private static let child = Kind.childId
    private static let other = Kind.otherChildId
    private static let confirmed = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2"])

    private func planning(_ childId: String = Kind.childId) -> ChildDeletionPresentation {
        Kind.planning.make(childId: childId)
    }

    // MARK: - Continues (subset / equal / deleteNow)

    @Test("OLD: Try Again always continued without a new dialog; a subset or equal plan continues to executing with the plan",
          arguments: [
              ChildDeletionPlan.archiveThenDelete(listIds: ["list-2"]),
              .archiveThenDelete(listIds: ["list-2", "list-1"]),
              .archiveThenDelete(listIds: ["list-1", "list-2"])
          ])
    func subsetOrEqualContinues(plan: ChildDeletionPlan) {
        let transition = planning().retryPlanReady(childId: Self.child, plan: plan, confirmedPlan: Self.confirmed)
        #expect(transition.presentation.phase == .executing(childId: Self.child))
        #expect(transition.plan == plan)
        #expect(transition.banner == nil)
    }

    @Test("OLD: Try Again always continued without a new dialog; deleteNow executes with the plan")
    func deleteNowExecutes() {
        let transition = planning().retryPlanReady(childId: Self.child, plan: .deleteNow, confirmedPlan: Self.confirmed)
        #expect(transition.presentation.phase == .executing(childId: Self.child))
        #expect(transition.plan == .deleteNow)
        #expect(transition.banner == nil)
    }

    // MARK: - Re-confirms (superset / disjoint)

    @Test("OLD: Try Again always continued without a new dialog; a superset or disjoint plan returns to confirming with the NEW plan",
          arguments: [
              ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2", "list-3"]),
              .archiveThenDelete(listIds: ["list-8", "list-9"]),
              .archiveThenDelete(listIds: ["list-2", "list-7"])
          ])
    func unconfirmedReconfirms(plan: ChildDeletionPlan) {
        let transition = planning().retryPlanReady(childId: Self.child, plan: plan, confirmedPlan: Self.confirmed)
        #expect(transition.presentation.phase == .confirming(childId: Self.child, plan: plan))
        #expect(transition.presentation.isConfirming(childId: Self.child))
        #expect(transition.presentation.confirmingPlan(for: Self.child) == plan)
        #expect(transition.plan == nil)
        #expect(transition.banner == nil)
    }

    @Test("OLD: Try Again always continued without a new dialog; the first confirmation being deleteNow makes any archive plan unconfirmed")
    func confirmedDeleteNowThenArchive() {
        let plan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1"])
        let transition = planning().retryPlanReady(childId: Self.child, plan: plan, confirmedPlan: .deleteNow)
        #expect(transition.presentation.phase == .confirming(childId: Self.child, plan: plan))
        #expect(transition.plan == nil)
        #expect(transition.banner == nil)
    }

    // MARK: - Blocked

    @Test("OLD: Try Again always continued without a new dialog; a blocked plan goes to idle with the blocked banner and no plan")
    func blockedGoesIdle() {
        let transition = planning().retryPlanReady(childId: Self.child, plan: .blocked, confirmedPlan: Self.confirmed)
        #expect(transition.presentation.phase == .idle)
        #expect(transition.presentation.isIdle)
        #expect(transition.banner == .blocked)
        #expect(transition.plan == nil)
    }

    // MARK: - Ignored

    private nonisolated static let ignoredPlans: [ChildDeletionPlan] = [
        .archiveThenDelete(listIds: ["list-1"]),
        .archiveThenDelete(listIds: ["list-1", "list-2", "list-3"]),
        .deleteNow,
        .blocked
    ]

    @Test("OLD: Try Again always continued without a new dialog; outside planning the call changes nothing",
          arguments: [Kind.idle, .confirming, .executing],
          ChildDeletionPresentationRetryTests.ignoredPlans)
    func wrongPhaseIgnored(kind: Kind, plan: ChildDeletionPlan) {
        let before = kind.make()
        let transition = before.retryPlanReady(childId: Self.child, plan: plan, confirmedPlan: Self.confirmed)
        #expect(transition.presentation == before)
        #expect(transition.banner == nil)
        #expect(transition.plan == nil)
    }

    @Test("OLD: Try Again always continued without a new dialog; a result for another child changes nothing",
          arguments: ChildDeletionPresentationRetryTests.ignoredPlans)
    func wrongChildIgnored(plan: ChildDeletionPlan) {
        let before = planning()
        let transition = before.retryPlanReady(childId: Self.other, plan: plan, confirmedPlan: Self.confirmed)
        #expect(transition.presentation == before)
        #expect(transition.banner == nil)
        #expect(transition.plan == nil)
    }

    // MARK: - Cancel and confirm after a re-confirmation

    @Test("OLD: Try Again always continued without a new dialog; cancelConfirmation after a re-confirmation is idle")
    func cancelAfterReconfirmation() {
        let newPlan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2", "list-3"])
        let reconfirming = planning()
            .retryPlanReady(childId: Self.child, plan: newPlan, confirmedPlan: Self.confirmed).presentation
        let cancelled = reconfirming.cancelConfirmation()
        #expect(cancelled.phase == .idle)
        #expect(cancelled.isIdle)
        #expect(cancelled.deletingChildId == nil)
        #expect(cancelled.confirm(childId: Self.child, plan: newPlan).plan == nil)
    }

    @Test("OLD: Try Again always continued without a new dialog; confirming the new plan runs it exactly once")
    func confirmNewPlanRuns() throws {
        let newPlan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2", "list-3"])
        let reconfirming = planning()
            .retryPlanReady(childId: Self.child, plan: newPlan, confirmedPlan: Self.confirmed).presentation
        let confirmed = reconfirming.confirm(childId: Self.child, plan: newPlan)
        #expect(confirmed.presentation.phase == .executing(childId: Self.child))
        #expect(try #require(confirmed.plan) == newPlan)
        #expect(confirmed.banner == nil)
        let second = confirmed.presentation.confirm(childId: Self.child, plan: newPlan)
        #expect(second.plan == nil)
    }

    @Test("OLD: Try Again always continued without a new dialog; confirming the OLD plan from the re-confirmation is ignored")
    func confirmOldPlanIgnored() {
        let newPlan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2", "list-3"])
        let reconfirming = planning()
            .retryPlanReady(childId: Self.child, plan: newPlan, confirmedPlan: Self.confirmed).presentation
        let transition = reconfirming.confirm(childId: Self.child, plan: Self.confirmed)
        #expect(transition.presentation == reconfirming)
        #expect(transition.plan == nil)
    }

    // MARK: - Double Try Again

    @Test("OLD: Try Again always continued without a new dialog; a double Try Again (requestDelete while not idle) changes nothing",
          arguments: [Kind.planning, .confirming, .executing])
    func doubleTryAgainIgnored(kind: Kind) {
        let before = kind.make()
        #expect(before.requestDelete(childId: Self.child) == before)
        #expect(before.requestDelete(childId: Self.other) == before)
    }

    @Test("OLD: Try Again always continued without a new dialog; requestDelete during a re-confirmation changes nothing")
    func doubleTryAgainDuringReconfirmation() {
        let newPlan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2", "list-3"])
        let reconfirming = planning()
            .retryPlanReady(childId: Self.child, plan: newPlan, confirmedPlan: Self.confirmed).presentation
        #expect(reconfirming.requestDelete(childId: Self.child) == reconfirming)
    }
}
