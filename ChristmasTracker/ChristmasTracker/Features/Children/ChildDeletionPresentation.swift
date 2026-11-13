//
//  ChildDeletionPresentation.swift
//  ChristmasTracker
//
//  The presentation state of one child deletion on the Children screen, as pure values. The
//  screen owns it (it outlives the list rows), and every change is one transition. A transition
//  that does not apply in the current phase, or names another child, returns the value unchanged
//  with no banner and no plan. Nothing here logs names or ids.
//

import Foundation

nonisolated enum ChildDeletionPhase: Equatable, Sendable {
    case idle
    case planning(childId: String)
    case confirming(childId: String, plan: ChildDeletionPlan)
    case executing(childId: String)
}

/// A request for the screen to show a banner; the banner itself is built by ChildrenState.
nonisolated enum ChildDeletionBannerRequest: Equatable, Sendable {
    case blocked
    case failed(ChildError)
}

nonisolated struct ChildDeletionPresentation: Equatable, Sendable {
    let phase: ChildDeletionPhase

    static let idle = ChildDeletionPresentation(phase: .idle)

    /// The result of a transition: the new value, a banner to show, and a plan to run.
    nonisolated struct Transition: Equatable, Sendable {
        let presentation: ChildDeletionPresentation
        let banner: ChildDeletionBannerRequest?
        let plan: ChildDeletionPlan?
    }

    // MARK: - Derived values

    /// The child whose deletion is planning or executing; nil while idle or confirming.
    var deletingChildId: String? {
        switch phase {
        case .planning(let childId), .executing(let childId): childId
        case .idle, .confirming: nil
        }
    }

    var isIdle: Bool {
        phase == .idle
    }

    func isConfirming(childId: String) -> Bool {
        confirmingPlan(for: childId) != nil
    }

    func confirmingPlan(for childId: String) -> ChildDeletionPlan? {
        if case .confirming(let confirmingId, let plan) = phase, confirmingId == childId {
            return plan
        }
        return nil
    }

    // MARK: - Transitions

    func requestDelete(childId: String) -> ChildDeletionPresentation {
        guard phase == .idle else { return self }
        return ChildDeletionPresentation(phase: .planning(childId: childId))
    }

    func planReady(childId: String, plan: ChildDeletionPlan, requiresConfirmation: Bool) -> Transition {
        guard phase == .planning(childId: childId) else { return unchanged }
        if plan == .blocked {
            return Transition(presentation: .idle, banner: .blocked, plan: nil)
        }
        if requiresConfirmation {
            return Transition(
                presentation: ChildDeletionPresentation(phase: .confirming(childId: childId, plan: plan)),
                banner: nil,
                plan: nil
            )
        }
        return Transition(
            presentation: ChildDeletionPresentation(phase: .executing(childId: childId)),
            banner: nil,
            plan: plan
        )
    }

    func planFailed(childId: String, error: ChildError) -> Transition {
        guard phase == .planning(childId: childId) else { return unchanged }
        return Transition(presentation: .idle, banner: .failed(error), plan: nil)
    }

    func cancelConfirmation() -> ChildDeletionPresentation {
        guard case .confirming = phase else { return self }
        return .idle
    }

    func confirm(childId: String, plan: ChildDeletionPlan) -> Transition {
        guard confirmingPlan(for: childId) == plan else { return unchanged }
        return Transition(
            presentation: ChildDeletionPresentation(phase: .executing(childId: childId)),
            banner: nil,
            plan: plan
        )
    }

    func executionFinished(childId: String) -> ChildDeletionPresentation {
        guard phase == .executing(childId: childId) else { return self }
        return .idle
    }

    func reset() -> ChildDeletionPresentation {
        .idle
    }

    func childrenChanged(existingIds: [String]) -> ChildDeletionPresentation {
        guard case .confirming(let childId, _) = phase, !existingIds.contains(childId) else { return self }
        return .idle
    }

    private var unchanged: Transition {
        Transition(presentation: self, banner: nil, plan: nil)
    }
}
