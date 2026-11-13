//
//  ChildDeletionPresentationStabilityTests.swift
//  ChristmasTrackerTests
//
//  Story I3d-F1: the confirmation must survive everything that re-renders the rows (new row
//  values, a reloaded children list with the same ids, progress values recomputed, the swipe
//  closing). Only the child disappearing, cancel, confirm or reset may end it. Deterministic:
//  no sleeps, no tasks. Fake ids only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Child deletion presentation stability Tests")
struct ChildDeletionPresentationStabilityTests {

    private static let child = ChildDeletionPhaseKind.childId
    private static let other = ChildDeletionPhaseKind.otherChildId
    private static let plan = ChildDeletionPhaseKind.plan

    // MARK: - Factory

    private func makeSUT() -> ChildDeletionPresentation {
        ChildDeletionPhaseKind.confirming.make()
    }

    private func makeState(
        _ deletion: ChildDeletionPresentation,
        children: [Child] = ChildFixtures.twoChildren()
    ) -> ChildrenState {
        ChildrenState(children: children, phase: .loaded, deletion: deletion)
    }

    private func expectStillConfirming(_ sut: ChildDeletionPresentation, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(sut.isConfirming(childId: Self.child), sourceLocation: sourceLocation)
        #expect(sut.confirmingPlan(for: Self.child) == Self.plan, sourceLocation: sourceLocation)
        #expect(sut.phase == .confirming(childId: Self.child, plan: Self.plan), sourceLocation: sourceLocation)
    }

    // MARK: - Rows re-rendered

    @Test("Rebuilding ChildrenState with the same children does not change the confirmation")
    func rebuildingRowsKeepsConfirming() {
        let sut = makeSUT()
        let first = makeState(sut)
        let second = makeState(sut)
        #expect(first == second)
        expectStillConfirming(sut)
    }

    @Test("Rows rebuilt with new row values (renamed child, new relationship) keep the confirmation")
    func newRowValuesKeepConfirming() throws {
        let sut = makeSUT()
        let renamed = [
            ChildFixtures.child(id: "child-1", firstName: "Renamed", lastName: "Kid", displayName: "Renamed Kid", relationship: .guardian),
            ChildFixtures.child(id: "child-2", firstName: "Dana", lastName: "Dependent", displayName: nil, relationship: .guardian)
        ]
        let state = makeState(sut, children: renamed)
        let row = try #require(state.rows.first { $0.id == Self.child })
        #expect(row.title == "Renamed Kid")
        #expect(row.status == ChildRowDeletionStatus.none)
        expectStillConfirming(sut)
    }

    @Test("The confirming row stays a plain row with no spinner across rebuilds")
    func confirmingRowStaysPlain() throws {
        let sut = makeSUT()
        for _ in 0..<3 {
            let state = makeState(sut)
            let row = try #require(state.rows.first { $0.id == Self.child })
            #expect(row.status == ChildRowDeletionStatus.none)
            #expect(!row.showsProgress)
        }
        expectStillConfirming(sut)
    }

    // MARK: - Children list reloaded

    @Test("childrenChanged with the same ids keeps the confirmation")
    func sameIdsKeepConfirming() {
        let sut = makeSUT().childrenChanged(existingIds: [Self.child, Self.other])
        expectStillConfirming(sut)
    }

    @Test("childrenChanged with the same ids reordered keeps the confirmation")
    func reorderedIdsKeepConfirming() {
        let sut = makeSUT().childrenChanged(existingIds: [Self.other, Self.child])
        expectStillConfirming(sut)
    }

    @Test("childrenChanged with extra ids keeps the confirmation")
    func extraIdsKeepConfirming() {
        let sut = makeSUT().childrenChanged(existingIds: [Self.other, "child-3", Self.child, "child-4"])
        expectStillConfirming(sut)
    }

    @Test("Repeated childrenChanged calls with the child present keep the confirmation")
    func repeatedReloadsKeepConfirming() {
        var sut = makeSUT()
        for _ in 0..<5 {
            sut = sut.childrenChanged(existingIds: [Self.child, Self.other])
        }
        expectStillConfirming(sut)
    }

    // MARK: - Progress and derived values change

    @Test("Recomputing deletingChildId and the controls-enabled value does not change the confirmation")
    func derivedValuesKeepConfirming() {
        let sut = makeSUT()
        for _ in 0..<3 {
            #expect(sut.deletingChildId == nil)
            #expect(!ChildrenState.deleteControlsEnabled(isMutating: false, deletion: sut))
            #expect(!ChildrenState.deleteControlsEnabled(isMutating: true, deletion: sut))
        }
        expectStillConfirming(sut)
    }

    @Test("A mutation starting and ending elsewhere (isMutating flips) does not change the confirmation")
    func isMutatingFlipsKeepConfirming() {
        let sut = makeSUT()
        let before = makeState(sut)
        _ = ChildrenState.deleteControlsEnabled(isMutating: true, deletion: sut)
        _ = ChildrenState.deleteControlsEnabled(isMutating: false, deletion: sut)
        let after = makeState(sut)
        #expect(before == after)
        expectStillConfirming(sut)
    }

    // MARK: - The swipe closing (no-op events)

    @Test("requestDelete while confirming (same child or another) keeps the confirmation",
          arguments: [ChildDeletionPhaseKind.childId, ChildDeletionPhaseKind.otherChildId])
    func requestDeleteWhileConfirming(childId: String) {
        expectStillConfirming(makeSUT().requestDelete(childId: childId))
    }

    @Test("executionFinished for another child keeps the confirmation")
    func executionFinishedOtherChild() {
        expectStillConfirming(makeSUT().executionFinished(childId: Self.other))
    }

    @Test("executionFinished for the same child while confirming keeps the confirmation")
    func executionFinishedSameChildWhileConfirming() {
        expectStillConfirming(makeSUT().executionFinished(childId: Self.child))
    }

    @Test("A late planReady or planFailed while confirming keeps the confirmation")
    func lateAsyncResultsKeepConfirming() {
        let afterPlan = makeSUT().planReady(childId: Self.child, plan: Self.plan, requiresConfirmation: true)
        expectStillConfirming(afterPlan.presentation)
        let afterFail = makeSUT().planFailed(childId: Self.child, error: .server)
        expectStillConfirming(afterFail.presentation)
        #expect(afterFail.banner == nil)
    }

    // MARK: - What does end it

    @Test("The child disappearing resets confirming to idle with no banner request")
    func childDisappearing() {
        let sut = makeSUT().childrenChanged(existingIds: [Self.other])
        #expect(sut.phase == .idle)
        #expect(sut.confirmingPlan(for: Self.child) == nil)
    }

    @Test("childrenChanged does not touch planning or executing when the child is missing",
          arguments: [ChildDeletionPhaseKind.planning, ChildDeletionPhaseKind.executing])
    func runningPhasesSurviveChildrenChanged(kind: ChildDeletionPhaseKind) {
        let before = kind.make()
        #expect(before.childrenChanged(existingIds: []) == before)
        #expect(before.childrenChanged(existingIds: [Self.other]) == before)
        #expect(before.deletingChildId == Self.child)
    }

    @Test("Only cancel, confirm, reset or a vanished child end the confirmation")
    func onlyExplicitEventsEndConfirming() {
        #expect(makeSUT().cancelConfirmation().phase == .idle)
        #expect(makeSUT().reset().phase == .idle)
        #expect(makeSUT().confirm(childId: Self.child, plan: Self.plan).presentation.phase == .executing(childId: Self.child))
        #expect(makeSUT().childrenChanged(existingIds: []).phase == .idle)
    }
}
