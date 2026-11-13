//
//  InlineErrorBannerActionsTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: the additive banner actions Check Item and Record Again, and the initializer that
//  takes the actions directly. The existing initializer (canRetry, isDismissible) and its order
//  (Try Again, then Dismiss) are unchanged; InlineErrorBannerStateTests covers them.
//
//  Fails today because InlineErrorBannerAction.checkItem and .recordAgain and
//  InlineErrorBannerState.init(message:actions:) do not exist yet.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("InlineErrorBanner actions Tests")
struct InlineErrorBannerActionsTests {

    private func makeSUT(
        message: String = "We couldn't confirm whether this purchase was recorded.",
        actions: [InlineErrorBannerAction]
    ) -> InlineErrorBannerState {
        InlineErrorBannerState(message: message, actions: actions)
    }

    @Test("The new action titles are exactly Check Item and Record Again")
    func titles() {
        #expect(InlineErrorBannerAction.checkItem.title == "Check Item")
        #expect(InlineErrorBannerAction.recordAgain.title == "Record Again")
    }

    @Test("The existing action titles are unchanged")
    func existingTitles() {
        #expect(InlineErrorBannerAction.tryAgain.title == "Try Again")
        #expect(InlineErrorBannerAction.dismiss.title == "Dismiss")
    }

    @Test("The actions are kept exactly as given, in that order")
    func orderKept() {
        #expect(makeSUT(actions: [.checkItem, .recordAgain, .dismiss]).actions == [.checkItem, .recordAgain, .dismiss])
        #expect(makeSUT(actions: [.dismiss, .checkItem]).actions == [.dismiss, .checkItem])
        #expect(makeSUT(actions: [.recordAgain]).actions == [.recordAgain])
    }

    @Test("No actions gives no buttons")
    func noActions() {
        #expect(makeSUT(actions: []).actions.isEmpty)
    }

    @Test("The message is kept, and a blank message becomes the fallback", arguments: ["", " ", "\n", "\t \n "])
    func blankFallback(message: String) {
        #expect(makeSUT(message: message, actions: [.dismiss]).message == InlineErrorBannerState.fallbackMessage)
        #expect(makeSUT(message: "Plain text.", actions: [.dismiss]).message == "Plain text.")
    }

    @Test("The accessibility label and announcement are Error. plus the message")
    func accessibilityTexts() {
        let sut = makeSUT(message: "Plain text.", actions: [.checkItem, .recordAgain, .dismiss])
        #expect(sut.accessibilityLabel == "Error. Plain text.")
        #expect(sut.announcement == "Error. Plain text.")
    }

    @Test("The actions initializer equals the flag initializer for the old combinations")
    func equalsFlagInitializer() {
        #expect(makeSUT(message: "m", actions: [.tryAgain, .dismiss])
                == InlineErrorBannerState(message: "m", canRetry: true, isDismissible: true))
        #expect(makeSUT(message: "m", actions: [.tryAgain])
                == InlineErrorBannerState(message: "m", canRetry: true, isDismissible: false))
        #expect(makeSUT(message: "m", actions: [.dismiss])
                == InlineErrorBannerState(message: "m", canRetry: false, isDismissible: true))
        #expect(makeSUT(message: "m", actions: [])
                == InlineErrorBannerState(message: "m", canRetry: false, isDismissible: false))
    }

    @Test("Different actions or a different order give different states")
    func equatable() {
        #expect(makeSUT(actions: [.checkItem, .recordAgain]) != makeSUT(actions: [.recordAgain, .checkItem]))
        #expect(makeSUT(actions: [.checkItem]) != makeSUT(actions: [.recordAgain]))
        #expect(makeSUT(actions: [.checkItem, .recordAgain]) == makeSUT(actions: [.checkItem, .recordAgain]))
    }

    @Test("The old initializer never produces the new actions")
    func oldInitializerUnchanged() {
        for retry in [true, false] {
            for dismiss in [true, false] {
                let actions = InlineErrorBannerState(message: "m", canRetry: retry, isDismissible: dismiss).actions
                #expect(!actions.contains(.checkItem))
                #expect(!actions.contains(.recordAgain))
            }
        }
        #expect(InlineErrorBannerState(message: "m", canRetry: true, isDismissible: true).actions == [.tryAgain, .dismiss])
    }

    @Test("The buttons are still at least 44 points high")
    func minimumButtonHeight() {
        #expect(InlineErrorBannerState.minimumButtonHeight == 44)
    }
}
