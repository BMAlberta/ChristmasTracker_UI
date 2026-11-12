//
//  ItemDetailScreenState.swift
//  ChristmasTracker
//

import Foundation

/// What the item detail screen shows. Pure and total: the screen can never fall into a spinner
/// when nothing is loading.
nonisolated enum ItemDetailScreenState: Equatable, Sendable {
    case loaded(ListItem)
    case loading
    case error(InlineErrorBannerState)
    case notLoaded

    static let notLoadedMessage = "This item could not be loaded."

    /// Rule, in order: an item -> loaded; loading, or the load has not started yet -> loading
    /// (the only spinner); an error that has a banner -> error; otherwise not loaded.
    static func resolve(
        item: ListItem?,
        isLoading: Bool,
        hasStartedLoading: Bool,
        error: ItemError?
    ) -> ItemDetailScreenState {
        if let item { return .loaded(item) }
        if isLoading || !hasStartedLoading { return .loading }
        if let error, let banner = ItemErrorPresentation.banner(for: error, hasRetryAction: true) {
            return .error(banner)
        }
        return .notLoaded
    }
}
