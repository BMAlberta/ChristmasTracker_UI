//
//  ListDetailLoadState.swift
//  ChristmasTracker
//
//  UX1a Story U3: the list detail screen combines the detail load failure, the failure returned by a
//  detail refresh (both source .listDetail) and the item service's list load error (source .items) into
//  ONE policy call, with the cached data being the detail that is shown.
//

import Foundation

nonisolated enum ListDetailLoadState {

    static func make(
        hasDetail: Bool,
        detailFailure: ListError?,
        refreshFailure: ListError?,
        itemsFailure: ItemError?,
        dismissed: DismissedLoads
    ) -> ScreenLoadPresentation {
        var failures: [LoadFailure] = []
        if let detailFailure { failures.append(LoadFailure(detailFailure, source: .listDetail)) }
        if let refreshFailure { failures.append(LoadFailure(refreshFailure, source: .listDetail)) }
        if let itemsFailure { failures.append(LoadFailure(itemsFailure, source: .items)) }
        return ScreenLoadPresentation.make(
            hasCachedData: hasDetail,
            failures: dismissed.visible(failures)
        )
    }
}
