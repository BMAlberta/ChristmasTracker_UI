//
//  ChildrenLoadStateTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: what the Children screen shows after a failed load. A failed phase with no children
//  is the full error (an InlineErrorBanner inside the empty content); a failed pull to refresh while
//  children are shown is the stale-data banner. Source .children. Fake data only.
//
//  ASSUMPTION (reported): ChildrenLoadState.make returns a ScreenLoadPresentation. The only call is in
//  makeSUT, so a different return type is a one-place change.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildrenLoadState Tests")
struct ChildrenLoadStateTests {

    private func makeSUT(
        phase: ChildrenLoadPhase,
        hasChildren: Bool,
        dismissed: DismissedLoads = DismissedLoads()
    ) -> ScreenLoadPresentation {
        ChildrenLoadState.make(phase: phase, hasChildren: hasChildren, dismissed: dismissed)
    }

    private func expectEmpty(_ sut: ScreenLoadPresentation) {
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(sut.leavesScreen == false)
        #expect(sut.signInTakesOver == false)
    }

    private func shownTexts(_ sut: ScreenLoadPresentation) -> [String] {
        sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }
    }

    @Test("without a failure nothing is shown", arguments: [
        ChildrenLoadPhase.idle, .loading, .loaded
    ], [false, true])
    func noFailure(phase: ChildrenLoadPhase, hasChildren: Bool) {
        expectEmpty(makeSUT(phase: phase, hasChildren: hasChildren))
    }

    @Test("a failed load with no children is the full error with the plain message and a retry of the children")
    func fullErrorWhenEmpty() {
        let sut = makeSUT(phase: .failed(.network), hasChildren: false)

        #expect(sut.fullError == LoadBanner(message: ChildError.network.userMessage, retryTargets: [.children]))
        #expect(sut.banners.isEmpty)
    }

    @Test("a failed pull to refresh while children are shown is the stale-data banner")
    func staleBannerWhenChildrenShown() {
        let sut = makeSUT(phase: .failed(.network), hasChildren: true)

        #expect(sut.banners == [LoadBanner(message: "Couldn't update. Showing saved data.", retryTargets: [.children])])
        #expect(sut.fullError == nil)
    }

    @Test("a server error with children shown is the stale-data banner", arguments: [ChildError.server, .invalidResponse])
    func staleBannerForServerErrors(error: ChildError) {
        let sut = makeSUT(phase: .failed(error), hasChildren: true)

        #expect(sut.banners == [LoadBanner(message: LoadFailurePolicy.staleDataText, retryTargets: [.children])])
    }

    @Test("a 403 never shows the stale-data text", arguments: [false, true])
    func forbiddenIsNeverStale(hasChildren: Bool) {
        let sut = makeSUT(phase: .failed(.forbidden), hasChildren: hasChildren)

        #expect(shownTexts(sut) == [ChildError.forbidden.userMessage])
    }

    @Test("the rate limit keeps its retry hint", arguments: [false, true])
    func rateLimitKeepsHint(hasChildren: Bool) {
        let sut = makeSUT(phase: .failed(.rateLimited(retryAfter: 30)), hasChildren: hasChildren)

        #expect(shownTexts(sut) == [ChildError.rateLimited(retryAfter: 30).userMessage])
        #expect(shownTexts(sut).first?.contains("30 seconds") == true)
    }

    @Test("a session end hands over to the sign-in flow and shows no banner", arguments: [false, true])
    func sessionEndTakesOver(hasChildren: Bool) {
        let sut = makeSUT(phase: .failed(.sessionEnded), hasChildren: hasChildren)

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
    }

    @Test("dismissing the children source hides the banner", arguments: [false, true])
    func dismissedHides(hasChildren: Bool) {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.children])

        expectEmpty(makeSUT(phase: .failed(.network), hasChildren: hasChildren, dismissed: dismissed))
    }

    @Test("after reset the failure shows again")
    func resetShowsAgain() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.children])
        dismissed.reset()

        let sut = makeSUT(phase: .failed(.network), hasChildren: false, dismissed: dismissed)

        #expect(sut.fullError != nil)
    }
}
