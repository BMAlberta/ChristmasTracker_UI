//
//  RecordPurchaseErrorPresentation.swift
//  ChristmasTracker
//
//  The inline banner for an error while recording a purchase. The message is the error's plain
//  message; Try Again only when retrying can help; always dismissible. The ended session has no
//  banner: the sign-in flow takes over. An unconfirmed failure has no Try Again; it offers the two
//  actions Check Item and Record Again instead.
//

import Foundation

nonisolated struct UnconfirmedPurchaseActions: Equatable, Sendable {
    let checkItemTitle: String
    let recordAgainTitle: String
}

nonisolated enum RecordPurchaseErrorPresentation {
    static func banner(for error: RecordPurchaseError) -> InlineErrorBannerState? {
        if error == .sessionEnded { return nil }
        return InlineErrorBannerState(message: error.userMessage, canRetry: error.isRetryable, isDismissible: true)
    }

    /// Non-nil only for an unconfirmed failure.
    static func unconfirmedActions(for error: RecordPurchaseError) -> UnconfirmedPurchaseActions? {
        guard error == .unconfirmed else { return nil }
        return UnconfirmedPurchaseActions(checkItemTitle: "Check Item", recordAgainTitle: "Record Again")
    }
}
