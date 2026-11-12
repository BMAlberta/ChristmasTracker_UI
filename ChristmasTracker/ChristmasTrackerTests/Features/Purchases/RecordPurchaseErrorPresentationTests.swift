//
//  RecordPurchaseErrorPresentationTests.swift
//  ChristmasTrackerTests
//
//  Story I4a-C (b): the banner for every RecordPurchaseError. Message is the error's userMessage,
//  Try Again only when the error is retryable, always dismissible, and no banner at all for
//  .sessionEnded (the sign-in flow takes over).
//
//  Fails today because RecordPurchaseErrorPresentation does not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase error presentation Tests")
struct RecordPurchaseErrorPresentationTests {

    private func makeSUT(_ error: RecordPurchaseError) -> InlineErrorBannerState? {
        RecordPurchaseErrorPresentation.banner(for: error)
    }

    @Test("Every error except sessionEnded has a banner with the error's plain message",
          arguments: PurchaseFixtures.allErrors.filter { $0 != .sessionEnded })
    func messageMatches(error: RecordPurchaseError) throws {
        let banner = try #require(makeSUT(error))
        #expect(banner.message == error.userMessage)
    }

    @Test("The banner offers Try Again exactly when the error is retryable, and is always dismissible",
          arguments: PurchaseFixtures.allErrors.filter { $0 != .sessionEnded })
    func actionsMatch(error: RecordPurchaseError) throws {
        let banner = try #require(makeSUT(error))
        let expected = InlineErrorBannerState(message: error.userMessage, canRetry: error.isRetryable, isDismissible: true)
        #expect(banner == expected)
    }

    @Test("sessionEnded has no banner")
    func sessionEndedHasNone() {
        #expect(makeSUT(.sessionEnded) == nil)
    }

    @Test("Retryable errors: network, server, rateLimited, invalidResponse",
          arguments: [RecordPurchaseError.network, .server, .rateLimited(retryAfter: 30), .invalidResponse])
    func retryable(error: RecordPurchaseError) throws {
        let banner = try #require(makeSUT(error))
        #expect(banner == InlineErrorBannerState(message: error.userMessage, canRetry: true, isDismissible: true))
    }

    @Test("Not retryable: notFound, unauthorized, forbidden, cannotPurchaseOwnList, validation, invalidPrice",
          arguments: [
            RecordPurchaseError.notFound, .unauthorized, .forbidden, .cannotPurchaseOwnList,
            .validation(message: "Total cost must be positive"), .invalidPrice
          ])
    func notRetryable(error: RecordPurchaseError) throws {
        let banner = try #require(makeSUT(error))
        #expect(banner == InlineErrorBannerState(message: error.userMessage, canRetry: false, isDismissible: true))
    }
}
