//
//  InlineErrorBannerState.swift
//  ChristmasTracker
//
//  The pure state behind InlineErrorBanner: the message, the buttons and their fixed order
//  (Try Again, then Dismiss), and the accessibility texts.
//

import CoreGraphics
import Foundation

nonisolated enum InlineErrorBannerAction: Equatable, Sendable {
    case tryAgain
    case dismiss
    case checkItem
    case recordAgain

    var title: String {
        switch self {
        case .tryAgain: "Try Again"
        case .dismiss: "Dismiss"
        case .checkItem: "Check Item"
        case .recordAgain: "Record Again"
        }
    }
}

nonisolated struct InlineErrorBannerState: Equatable, Sendable {
    static let fallbackMessage = "Something went wrong. Please try again."
    /// Every banner button is at least this high (points).
    static let minimumButtonHeight: CGFloat = 44

    let message: String
    let actions: [InlineErrorBannerAction]

    init(message: String, canRetry: Bool, isDismissible: Bool) {
        var built: [InlineErrorBannerAction] = []
        if canRetry { built.append(.tryAgain) }
        if isDismissible { built.append(.dismiss) }
        self.init(message: message, actions: built)
    }

    /// The actions are kept exactly as given, in that order.
    init(message: String, actions: [InlineErrorBannerAction]) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.message = trimmed.isEmpty ? Self.fallbackMessage : message
        self.actions = actions
    }

    var accessibilityLabel: String { "Error. " + message }

    /// Posted to VoiceOver when the banner appears.
    var announcement: String { accessibilityLabel }
}
