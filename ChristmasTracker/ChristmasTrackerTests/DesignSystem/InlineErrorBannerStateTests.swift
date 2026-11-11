//
//  InlineErrorBannerStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D: the pure state behind InlineErrorBanner (UI rule 4). Fails today because
//  InlineErrorBannerState and InlineErrorBannerAction do not exist yet.
//

import Testing
import Foundation
import CoreGraphics
@testable import ChristmasTracker

@Suite("InlineErrorBannerState Tests")
struct InlineErrorBannerStateTests {

    private func makeSUT(
        message: String = "Couldn't reach the server.",
        canRetry: Bool = false,
        isDismissible: Bool = false
    ) -> InlineErrorBannerState {
        InlineErrorBannerState(message: message, canRetry: canRetry, isDismissible: isDismissible)
    }

    // MARK: - Actions: all four combinations and the order

    @Test("Only canRetry gives [tryAgain]")
    func onlyRetry() {
        #expect(makeSUT(canRetry: true, isDismissible: false).actions == [.tryAgain])
    }

    @Test("Only isDismissible gives [dismiss]")
    func onlyDismiss() {
        #expect(makeSUT(canRetry: false, isDismissible: true).actions == [.dismiss])
    }

    @Test("Both give [tryAgain, dismiss] in that order")
    func bothInOrder() {
        #expect(makeSUT(canRetry: true, isDismissible: true).actions == [.tryAgain, .dismiss])
    }

    @Test("Neither gives no actions")
    func neither() {
        #expect(makeSUT(canRetry: false, isDismissible: false).actions.isEmpty)
    }

    @Test("Titles are exactly Try Again and Dismiss")
    func titles() {
        #expect(InlineErrorBannerAction.tryAgain.title == "Try Again")
        #expect(InlineErrorBannerAction.dismiss.title == "Dismiss")
    }

    // MARK: - Message

    @Test("The message is kept as given")
    func messageKept() {
        #expect(makeSUT(message: "Too many requests.").message == "Too many requests.")
    }

    @Test("A blank or whitespace message becomes the fallback", arguments: ["", " ", "   ", "\n", "\t \n "])
    func blankFallback(message: String) {
        #expect(makeSUT(message: message).message == "Something went wrong. Please try again.")
    }

    // MARK: - Accessibility

    @Test("accessibilityLabel is Error. plus the message")
    func accessibilityLabel() {
        #expect(makeSUT(message: "Too many requests.").accessibilityLabel == "Error. Too many requests.")
    }

    @Test("announcement is the same text as the accessibility label")
    func announcement() {
        let sut = makeSUT(message: "Too many requests.")
        #expect(sut.announcement == "Error. Too many requests.")
        #expect(sut.announcement == sut.accessibilityLabel)
    }

    @Test("The blank-message fallback flows into the label and the announcement")
    func fallbackInLabels() {
        let sut = makeSUT(message: "  ")
        #expect(sut.accessibilityLabel == "Error. Something went wrong. Please try again.")
        #expect(sut.announcement == "Error. Something went wrong. Please try again.")
    }

    @Test("Buttons are at least 44 points high")
    func minimumButtonHeight() {
        #expect(InlineErrorBannerState.minimumButtonHeight == 44)
    }

    @Test("Equal inputs give equal states")
    func equatable() {
        #expect(makeSUT(canRetry: true, isDismissible: true) == makeSUT(canRetry: true, isDismissible: true))
        #expect(makeSUT(canRetry: true) != makeSUT(canRetry: false))
    }
}
