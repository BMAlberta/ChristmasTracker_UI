//
//  MutationBanner.swift
//  ChristmasTracker
//
//  UX1a Story U3: the banner an initiating view holds in its own state after a THROWN mutation error.
//  Dismiss is always offered; Try Again exactly when the error is retryable. Nil for an ended session
//  (the sign-in flow takes over).
//

import Foundation

nonisolated enum MutationBanner {

    static func state(for error: ListError) -> InlineErrorBannerState? {
        guard error != .sessionEnded else { return nil }
        return InlineErrorBannerState(
            message: error.userMessage,
            canRetry: ListErrorPresentation(error).isRetryable,
            isDismissible: true
        )
    }

    static func state(for error: ChildError) -> InlineErrorBannerState? {
        guard error != .sessionEnded else { return nil }
        return InlineErrorBannerState(
            message: error.userMessage,
            canRetry: ChildErrorPresentation(error).isRetryable,
            isDismissible: true
        )
    }
}
