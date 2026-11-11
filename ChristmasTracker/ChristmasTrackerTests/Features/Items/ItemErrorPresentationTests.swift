//
//  ItemErrorPresentationTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D: how an ItemError is presented. A table over EVERY ItemError case (the exhaustive
//  switch in `expectation(for:)` makes a new case a compile error here).
//
//  Fails today because ItemErrorPresentation does not exist yet.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("ItemErrorPresentation Tests")
struct ItemErrorPresentationTests {

    private struct Expectation {
        let retryable: Bool
        let hasBanner: Bool
        let leavesScreen: Bool
    }

    /// One row per case; exhaustive on purpose.
    private func expectation(for error: ItemError) -> Expectation {
        switch error {
        case .network, .server, .rateLimited, .invalidResponse:
            Expectation(retryable: true, hasBanner: true, leavesScreen: false)
        case .forbidden, .unauthorized, .validation, .invalidPrice, .cannotDeleteWithPurchases:
            Expectation(retryable: false, hasBanner: true, leavesScreen: false)
        case .notFound:
            Expectation(retryable: false, hasBanner: true, leavesScreen: true)
        case .sessionEnded:
            Expectation(retryable: false, hasBanner: false, leavesScreen: false)
        }
    }

    static let allCases: [ItemError] = [
        .notFound, .unauthorized, .forbidden, .validation(message: "Name is required."),
        .invalidPrice, .cannotDeleteWithPurchases, .rateLimited(retryAfter: 5), .sessionEnded,
        .network, .invalidResponse, .server
    ]

    @Test("isRetryable per case", arguments: ItemErrorPresentationTests.allCases)
    func isRetryable(error: ItemError) {
        #expect(ItemErrorPresentation.isRetryable(error) == expectation(for: error).retryable, "\(error)")
    }

    @Test("leavesScreen is true only for notFound", arguments: ItemErrorPresentationTests.allCases)
    func leavesScreen(error: ItemError) {
        #expect(ItemErrorPresentation.leavesScreen(error) == expectation(for: error).leavesScreen, "\(error)")
    }

    @Test("banner is nil only for sessionEnded", arguments: ItemErrorPresentationTests.allCases, [true, false])
    func bannerPresence(error: ItemError, hasRetryAction: Bool) {
        let banner = ItemErrorPresentation.banner(for: error, hasRetryAction: hasRetryAction)
        #expect((banner != nil) == expectation(for: error).hasBanner, "\(error)")
    }

    @Test("banner message is the error's userMessage, always dismissible", arguments: ItemErrorPresentationTests.allCases, [true, false])
    func bannerMessageAndDismiss(error: ItemError, hasRetryAction: Bool) throws {
        guard expectation(for: error).hasBanner else { return }
        let banner = try #require(ItemErrorPresentation.banner(for: error, hasRetryAction: hasRetryAction))
        #expect(banner.message == error.userMessage, "\(error)")
        #expect(banner.actions.contains(.dismiss), "\(error)")
    }

    @Test("banner offers Try Again only when a retry action exists AND the error is retryable",
          arguments: ItemErrorPresentationTests.allCases, [true, false])
    func bannerRetry(error: ItemError, hasRetryAction: Bool) throws {
        guard expectation(for: error).hasBanner else { return }
        let banner = try #require(ItemErrorPresentation.banner(for: error, hasRetryAction: hasRetryAction))
        let expectRetry = hasRetryAction && expectation(for: error).retryable
        #expect(banner.actions.contains(.tryAgain) == expectRetry, "\(error) hasRetryAction=\(hasRetryAction)")
        #expect(banner.actions == (expectRetry ? [.tryAgain, .dismiss] : [.dismiss]), "\(error)")
    }

    @Test("The banner for a retryable error equals the state built from its message")
    func bannerEqualsState() {
        let banner = ItemErrorPresentation.banner(for: .network, hasRetryAction: true)
        #expect(banner == InlineErrorBannerState(message: ItemError.network.userMessage,
                                                 canRetry: true, isDismissible: true))
    }
}
