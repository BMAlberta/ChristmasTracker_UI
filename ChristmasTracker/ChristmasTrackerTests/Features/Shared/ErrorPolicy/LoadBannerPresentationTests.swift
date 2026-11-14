//
//  LoadBannerPresentationTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: LoadBannerPresentation.state(for:dismissible:) turns a policy LoadBanner into the
//  InlineErrorBannerState a screen renders. The message is the banner's message (a blank one falls
//  back to InlineErrorBannerState's fallback text), the actions are Try Again then Dismiss, and
//  Dismiss is left out when the banner is not dismissible. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("LoadBannerPresentation Tests")
struct LoadBannerPresentationTests {

    private func makeSUT(
        message: String = "Fake banner message",
        targets: [LoadSource] = [.lists]
    ) -> LoadBanner {
        LoadBanner(message: message, retryTargets: targets)
    }

    @Test("the state carries the banner's message")
    func messageIsCopied() {
        let state = LoadBannerPresentation.state(for: makeSUT(message: "Fake banner message"))

        #expect(state.message == "Fake banner message")
    }

    @Test("by default the actions are Try Again then Dismiss")
    func defaultActions() {
        let state = LoadBannerPresentation.state(for: makeSUT())

        #expect(state.actions == [.tryAgain, .dismiss])
    }

    @Test("dismissible true gives the same actions as the default")
    func explicitlyDismissible() {
        let state = LoadBannerPresentation.state(for: makeSUT(), dismissible: true)

        #expect(state.actions == [.tryAgain, .dismiss])
    }

    @Test("dismissible false leaves Dismiss out and keeps Try Again")
    func notDismissible() {
        let state = LoadBannerPresentation.state(for: makeSUT(), dismissible: false)

        #expect(state.actions == [.tryAgain])
        #expect(!state.actions.contains(.dismiss))
    }

    @Test("a blank message falls back to the standard text", arguments: ["", " ", "   ", "\n", " \t \n "])
    func blankMessageFallsBack(message: String) {
        let state = LoadBannerPresentation.state(for: makeSUT(message: message))

        #expect(state.message == InlineErrorBannerState.fallbackMessage)
        #expect(state.actions == [.tryAgain, .dismiss])
    }

    @Test("a blank message falls back also when the banner is not dismissible")
    func blankMessageFallsBackNotDismissible() {
        let state = LoadBannerPresentation.state(for: makeSUT(message: "  "), dismissible: false)

        #expect(state.message == InlineErrorBannerState.fallbackMessage)
        #expect(state.actions == [.tryAgain])
    }

    @Test("the stale-data text passes through unchanged")
    func staleTextPassesThrough() {
        let state = LoadBannerPresentation.state(for: makeSUT(message: LoadFailurePolicy.staleDataText))

        #expect(state.message == "Couldn't update. Showing saved data.")
    }

    @Test("a rate-limit message keeps its retry hint")
    func rateLimitHintSurvives() {
        let message = ListError.rateLimited(retryAfter: 30).userMessage
        let state = LoadBannerPresentation.state(for: makeSUT(message: message))

        #expect(state.message == message)
        #expect(state.message.contains("30 seconds"))
    }

    @Test("the retry targets do not change what is shown", arguments: [
        [LoadSource.lists], [.listDetail, .items], [.stats, .budgets], []
    ])
    func targetsDoNotChangeTheState(targets: [LoadSource]) {
        let baseline = LoadBannerPresentation.state(for: makeSUT(targets: [.lists]))
        let state = LoadBannerPresentation.state(for: makeSUT(targets: targets))

        #expect(state == baseline)
    }

    @Test("the accessibility label and announcement come from the state")
    func accessibilityTexts() {
        let state = LoadBannerPresentation.state(for: makeSUT(message: "Fake banner message"))

        #expect(state.accessibilityLabel == "Error. Fake banner message")
        #expect(state.announcement == state.accessibilityLabel)
    }
}
