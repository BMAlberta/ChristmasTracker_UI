//
//  LoadBannerPresentation.swift
//  ChristmasTracker
//
//  UX1a Story U3: turns a policy LoadBanner into the state InlineErrorBanner renders. Every load
//  banner offers Try Again (the policy has no per-error retryability); Dismiss is left out for a
//  banner that must stay, such as the full error of a screen with nothing to show.
//

import Foundation

nonisolated enum LoadBannerPresentation {

    static func state(for banner: LoadBanner, dismissible: Bool = true) -> InlineErrorBannerState {
        InlineErrorBannerState(message: banner.message, canRetry: true, isDismissible: dismissible)
    }
}
