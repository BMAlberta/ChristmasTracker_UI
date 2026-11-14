//
//  ItemDetailLoadState.swift
//  ChristmasTracker
//
//  UX1a Story U3: what the item detail screen shows after a failed load. No item and a failure is the
//  full error; an item shown and a failure is the stale-data banner. While a load is running no
//  failure is shown (the retry is in progress).
//

import Foundation

nonisolated enum ItemDetailLoadState {

    static func make(
        hasItem: Bool,
        loading: Bool,
        error: ItemError?,
        dismissed: DismissedLoads
    ) -> ScreenLoadPresentation {
        guard !loading, let error else { return .empty }
        return ScreenLoadPresentation.make(
            hasCachedData: hasItem,
            failures: dismissed.visible([LoadFailure(error, source: .itemDetail)])
        )
    }
}
