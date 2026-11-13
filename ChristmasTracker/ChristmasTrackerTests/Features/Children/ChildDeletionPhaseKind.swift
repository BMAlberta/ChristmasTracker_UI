//
//  ChildDeletionPhaseKind.swift
//  ChristmasTrackerTests
//
//  Story I3d-F1: a test-only way to reach each phase of ChildDeletionPresentation through its
//  public transitions (no memberwise construction is assumed). Fake ids only.
//

import Testing
import Foundation
@testable import ChristmasTracker

nonisolated enum ChildDeletionPhaseKind: CaseIterable, Sendable, CustomTestStringConvertible {
    case idle
    case planning
    case confirming
    case executing

    static let childId = "child-1"
    static let otherChildId = "child-2"
    static let plan = ChildDeletionPlan.archiveThenDelete(listIds: ["list-1", "list-2"])
    static let otherPlan = ChildDeletionPlan.deleteNow

    var testDescription: String {
        switch self {
        case .idle: "idle"
        case .planning: "planning"
        case .confirming: "confirming"
        case .executing: "executing"
        }
    }

    /// The phases other than `self`.
    static func all(except excluded: [ChildDeletionPhaseKind]) -> [ChildDeletionPhaseKind] {
        allCases.filter { !excluded.contains($0) }
    }

    func make(
        childId: String = ChildDeletionPhaseKind.childId,
        plan: ChildDeletionPlan = ChildDeletionPhaseKind.plan
    ) -> ChildDeletionPresentation {
        let idle = ChildDeletionPresentation.idle
        switch self {
        case .idle:
            return idle
        case .planning:
            return idle.requestDelete(childId: childId)
        case .confirming:
            return idle.requestDelete(childId: childId)
                .planReady(childId: childId, plan: plan, requiresConfirmation: true).presentation
        case .executing:
            let confirming = idle.requestDelete(childId: childId)
                .planReady(childId: childId, plan: plan, requiresConfirmation: true).presentation
            return confirming.confirm(childId: childId, plan: plan).presentation
        }
    }
}
