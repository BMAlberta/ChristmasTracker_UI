//
//  RecordPurchaseErrorPresentation.swift
//  ChristmasTracker
//
//  The inline banner for an error while recording a purchase. The message is the error's plain
//  message; Try Again only when retrying can help; always dismissible. The ended session has no
//  banner: the sign-in flow takes over.
//

import Foundation

nonisolated enum RecordPurchaseErrorPresentation {
    static func banner(for error: RecordPurchaseError) -> InlineErrorBannerState? {
        if error == .sessionEnded { return nil }
        return InlineErrorBannerState(message: error.userMessage, canRetry: error.isRetryable, isDismissible: true)
    }
}
