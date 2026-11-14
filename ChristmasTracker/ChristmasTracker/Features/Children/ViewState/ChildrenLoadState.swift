//
//  ChildrenLoadState.swift
//  ChristmasTracker
//
//  UX1a Story U3: what the Children screen shows after a failed load. A failed phase with no children
//  is the full error; a failed pull to refresh while children are shown is the stale-data banner.
//

import Foundation

nonisolated enum ChildrenLoadState {

    static func make(
        phase: ChildrenLoadPhase,
        hasChildren: Bool,
        dismissed: DismissedLoads
    ) -> ScreenLoadPresentation {
        guard case .failed(let error) = phase else { return .empty }
        return ScreenLoadPresentation.make(
            hasCachedData: hasChildren,
            failures: dismissed.visible([LoadFailure(error, source: .children)])
        )
    }
}
