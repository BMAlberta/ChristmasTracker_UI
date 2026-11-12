//
//  RecordPurchaseUnconfirmedErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: PurchaseError.unconfirmed ("the server may have recorded the purchase")
//  and the failure kind of every case, plus the banner and the two-action presentation.
//
//  Fails today because PurchaseError.unconfirmed, failureKind and the presentation
//  additions do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Record purchase unconfirmed error Tests")
struct RecordPurchaseUnconfirmedErrorTests {

    // MARK: - The error

    @Test("The unconfirmed message is the fixed sentence")
    func message() {
        #expect(PurchaseError.unconfirmed.userMessage == "We couldn't confirm whether this purchase was recorded.")
        #expect(PurchaseError.unconfirmed.errorDescription == PurchaseError.unconfirmed.userMessage)
    }

    @Test("Unconfirmed is not retryable and does not close the form")
    func flags() {
        #expect(!PurchaseError.unconfirmed.isRetryable)
        #expect(!PurchaseError.unconfirmed.closesForm)
    }

    @Test("Only unconfirmed has the unconfirmed failure kind; every other case is definitive",
          arguments: PurchaseFixtures.allErrorsWithUnconfirmed)
    func failureKind(error: PurchaseError) {
        #expect(error.failureKind == (error == .unconfirmed ? .unconfirmed : .definitive), "\(error)")
    }

    @Test("The unconfirmed message differs from every other message", arguments: PurchaseFixtures.allErrors)
    func messageDistinct(other: PurchaseError) {
        #expect(PurchaseError.unconfirmed.userMessage != other.userMessage)
    }

    // MARK: - Presentation

    // Story I4b-C changed this on purpose: the Story A banner was dismiss-only; it now offers
    // Check Item, Record Again and Dismiss, in that order, and still no Try Again.
    @Test("The unconfirmed banner has the message, Check Item, Record Again and Dismiss, and no Try Again")
    func banner() {
        let banner = RecordPurchaseErrorPresentation.banner(for: .unconfirmed)
        #expect(banner == InlineErrorBannerState(
            message: "We couldn't confirm whether this purchase was recorded.",
            actions: [.checkItem, .recordAgain, .dismiss]
        ))
        #expect(banner?.actions.contains(.tryAgain) == false)
    }

    @Test("The two unconfirmed actions are Check Item and Record Again")
    func actions() throws {
        let actions = try #require(RecordPurchaseErrorPresentation.unconfirmedActions(for: .unconfirmed))
        #expect(actions.checkItemTitle == "Check Item")
        #expect(actions.recordAgainTitle == "Record Again")
    }

    @Test("No other error has the unconfirmed actions", arguments: PurchaseFixtures.allErrors)
    func noActionsForOthers(error: PurchaseError) {
        #expect(RecordPurchaseErrorPresentation.unconfirmedActions(for: error) == nil, "\(error)")
    }
}
