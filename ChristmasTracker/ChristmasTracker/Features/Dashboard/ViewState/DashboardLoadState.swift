//
//  DashboardLoadState.swift
//  ChristmasTracker
//
//  UX1a Story U3: what the lists dashboard shows after a failed lists load. The archive failure is a
//  mutation error: the dashboard holds it as its own banner and it is never part of this presentation.
//

import Foundation

nonisolated enum DashboardLoadState {

    static func make(
        hasCachedLists: Bool,
        listsFailure: ListError?,
        archiveFailure: ListError?,
        dismissed: DismissedLoads
    ) -> ScreenLoadPresentation {
        // The archive failure is accepted so the call site names it, and deliberately ignored.
        _ = archiveFailure
        let failures = listsFailure.map { [LoadFailure($0, source: .lists)] } ?? []
        return ScreenLoadPresentation.make(
            hasCachedData: hasCachedLists,
            failures: dismissed.visible(failures)
        )
    }
}
