//
//  ScreenLoadPresentation.swift
//  ChristmasTracker
//
//  UX1a Story U3: what a screen renders after its loads, taken from LoadFailurePolicy. Dismissal is
//  applied before the call (see DismissedLoads): a screen passes only the failures still visible.
//

import Foundation

nonisolated struct ScreenLoadPresentation: Sendable, Equatable {
    /// Up to two banners above the content the screen still shows.
    let banners: [LoadBanner]
    /// The full error of a screen with nothing to show.
    let fullError: LoadBanner?
    let leavesScreen: Bool
    let signInTakesOver: Bool

    static let empty = ScreenLoadPresentation(
        banners: [],
        fullError: nil,
        leavesScreen: false,
        signInTakesOver: false
    )

    static func make(hasCachedData: Bool, failures: [LoadFailure]) -> ScreenLoadPresentation {
        switch LoadFailurePolicy.outcome(hasCachedData: hasCachedData, failures: failures) {
        case .none:
            return .empty
        case .staleData(let banner), .merged(let banner):
            return ScreenLoadPresentation(banners: [banner], fullError: nil, leavesScreen: false, signInTakesOver: false)
        case .banners(let banners):
            return ScreenLoadPresentation(banners: banners, fullError: nil, leavesScreen: false, signInTakesOver: false)
        case .fullError(let banner):
            return ScreenLoadPresentation(banners: [], fullError: banner, leavesScreen: false, signInTakesOver: false)
        case .leaveScreen:
            return ScreenLoadPresentation(banners: [], fullError: nil, leavesScreen: true, signInTakesOver: false)
        case .signInTakesOver:
            return ScreenLoadPresentation(banners: [], fullError: nil, leavesScreen: false, signInTakesOver: true)
        }
    }
}
