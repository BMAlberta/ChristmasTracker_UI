//
//  ItemErrorPresentation.swift
//  ChristmasTracker
//
//  How an ItemError is shown: which errors offer Try Again, which close the screen, and the
//  banner state. Pure; the messages come from `ItemError.userMessage` only.
//

import Foundation

nonisolated enum ItemErrorPresentation {

    /// True when repeating the same action can succeed.
    static func isRetryable(_ error: ItemError) -> Bool {
        switch error {
        case .network, .server, .rateLimited, .invalidResponse:
            true
        case .forbidden, .notFound, .unauthorized, .validation, .invalidPrice,
             .cannotDeleteWithPurchases, .sessionEnded:
            false
        }
    }

    /// The banner for an error, or nil when the sign-in flow takes over (`.sessionEnded`).
    static func banner(for error: ItemError, hasRetryAction: Bool) -> InlineErrorBannerState? {
        if error == .sessionEnded { return nil }
        return InlineErrorBannerState(
            message: error.userMessage,
            canRetry: hasRetryAction && isRetryable(error),
            isDismissible: true
        )
    }

    /// True when the item is gone, so the screen showing it closes.
    static func leavesScreen(_ error: ItemError) -> Bool {
        error == .notFound
    }
}
