//
//  RecordPurchaseUnconfirmedErrorTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-A: RecordPurchaseError.unconfirmed ("the server may have recorded the purchase")
//  and the failure kind of every case, plus the banner and the two-action presentation.
//
//  Fails today because RecordPurchaseError.unconfirmed, failureKind and the presentation
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
        #expect(RecordPurchaseError.unconfirmed.userMessage == "We couldn't confirm whether this purchase was recorded.")
        #expect(RecordPurchaseError.unconfirmed.errorDescription == RecordPurchaseError.unconfirmed.userMessage)
    }

    @Test("Unconfirmed is not retryable and does not close the form")
    func flags() {
        #expect(!RecordPurchaseError.unconfirmed.isRetryable)
        #expect(!RecordPurchaseError.unconfirmed.closesForm)
    }

    @Test("Only unconfirmed has the unconfirmed failure kind; every other case is definitive",
          arguments: PurchaseFixtures.allErrorsWithUnconfirmed)
    func failureKind(error: RecordPurchaseError) {
        #expect(error.failureKind == (error == .unconfirmed ? .unconfirmed : .definitive), "\(error)")
    }

    @Test("The unconfirmed message differs from every other message", arguments: PurchaseFixtures.allErrors)
    func messageDistinct(other: RecordPurchaseError) {
        #expect(RecordPurchaseError.unconfirmed.userMessage != other.userMessage)
    }

    // MARK: - Presentation

    @Test("The unconfirmed banner has the message, no Try Again and is dismissible")
    func banner() {
        let banner = RecordPurchaseErrorPresentation.banner(for: .unconfirmed)
        #expect(banner == InlineErrorBannerState(
            message: "We couldn't confirm whether this purchase was recorded.", canRetry: false, isDismissible: true
        ))
    }

    @Test("The two unconfirmed actions are Check Item and Record Again")
    func actions() throws {
        let actions = try #require(RecordPurchaseErrorPresentation.unconfirmedActions(for: .unconfirmed))
        #expect(actions.checkItemTitle == "Check Item")
        #expect(actions.recordAgainTitle == "Record Again")
    }

    @Test("No other error has the unconfirmed actions", arguments: PurchaseFixtures.allErrors)
    func noActionsForOthers(error: RecordPurchaseError) {
        #expect(RecordPurchaseErrorPresentation.unconfirmedActions(for: error) == nil, "\(error)")
    }
}
