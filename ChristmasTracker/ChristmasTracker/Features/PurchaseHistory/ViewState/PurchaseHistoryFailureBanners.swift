//
//  PurchaseHistoryFailureBanners.swift
//  ChristmasTracker
//
//  PH1: turns a failed purchase history load into what the screen shows, through the shared load
//  policy. Pure; it logs nothing.
//

import Foundation

@MainActor
enum PurchaseHistoryFailureBanners {

    /// The classified failure of a load error. Any error that is not a PurchaseHistoryError counts as a
    /// server failure. Nil only when sign-in takes over (the model then shows no banner and keeps its
    /// state). A notFound is kept: the model has no navigation, so it shows it like any other failure.
    static func failure(for error: any Error) -> LoadFailure? {
        let typed = (error as? PurchaseHistoryError) ?? PurchaseHistoryError.server
        let failure = LoadFailure(typed, source: .purchaseHistory)
        if failure.category == .sessionEnded { return nil }
        return failure
    }

    /// The full error of a screen with nothing to show: Try Again only.
    static func fullError(for failure: LoadFailure) -> InlineErrorBannerState? {
        guard let banner = banner(for: failure, hasCachedData: false) else { return nil }
        return LoadBannerPresentation.state(for: banner, dismissible: false)
    }

    /// The dismissible banners over saved rows.
    static func stale(for failure: LoadFailure) -> [InlineErrorBannerState] {
        guard let banner = banner(for: failure, hasCachedData: true) else { return [] }
        return [LoadBannerPresentation.state(for: banner)]
    }

    /// The policy's banner. Only the leave-screen outcome of notFound is bypassed: its plain message
    /// is shown with Try Again.
    private static func banner(for failure: LoadFailure, hasCachedData: Bool) -> LoadBanner? {
        if failure.category == .notFound {
            return LoadBanner(message: failure.plainMessage, retryTargets: [failure.source])
        }
        let presentation = ScreenLoadPresentation.make(hasCachedData: hasCachedData, failures: [failure])
        return presentation.fullError ?? presentation.banners.first
    }
}
