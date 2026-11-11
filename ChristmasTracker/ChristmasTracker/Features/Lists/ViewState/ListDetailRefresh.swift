//
//  ListDetailRefresh.swift
//  ChristmasTracker
//
//  The pure pieces behind the list detail screen's pull to refresh: the banner for a failed
//  detail refresh, and the choice between refreshing and loading the items.
//

import Foundation

nonisolated enum ListDetailRefresh {
    static let messagePrefix = "The list could not be refreshed. "

    enum ItemsStep: Equatable, Sendable {
        case refresh
        case load
    }

    /// Nil for no failure and for an ended session (the app is already leaving the screen).
    static func banner(for error: ListError?) -> InlineErrorBannerState? {
        guard let error, error != .sessionEnded else { return nil }
        return InlineErrorBannerState(
            message: messagePrefix + error.userMessage,
            canRetry: ListErrorPresentation(error).isRetryable,
            isDismissible: true
        )
    }

    /// Refresh when the item service already holds this list, else load it.
    static func itemsStep(currentItemsListId: String?, listId: String) -> ItemsStep {
        currentItemsListId == listId ? .refresh : .load
    }
}
