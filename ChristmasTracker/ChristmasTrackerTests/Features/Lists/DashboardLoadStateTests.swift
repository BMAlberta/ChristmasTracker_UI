//
//  DashboardLoadStateTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: what the lists dashboard shows after a failed load. The lists failure goes through
//  LoadFailurePolicy with source .lists. The archive failure is a MUTATION error: it is never part of
//  the load presentation (the dashboard shows it as its own local banner). Fake data only.
//
//  ASSUMPTION (reported): DashboardLoadState.make returns a ScreenLoadPresentation. The only call is in
//  makeSUT, so a different return type is a one-place change.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("DashboardLoadState Tests")
struct DashboardLoadStateTests {

    private func makeSUT(
        hasCachedLists: Bool,
        listsFailure: ListError? = nil,
        archiveFailure: ListError? = nil,
        dismissed: DismissedLoads = DismissedLoads()
    ) -> ScreenLoadPresentation {
        DashboardLoadState.make(
            hasCachedLists: hasCachedLists,
            listsFailure: listsFailure,
            archiveFailure: archiveFailure,
            dismissed: dismissed
        )
    }

    private func expectEmpty(_ sut: ScreenLoadPresentation) {
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(sut.leavesScreen == false)
        #expect(sut.signInTakesOver == false)
    }

    @Test("no failure: nothing is shown", arguments: [false, true])
    func noFailure(hasCachedLists: Bool) {
        expectEmpty(makeSUT(hasCachedLists: hasCachedLists))
    }

    @Test("saved lists and an unreachable server: the stale-data banner that retries the lists")
    func staleBannerWithCachedLists() {
        let sut = makeSUT(hasCachedLists: true, listsFailure: .network)

        #expect(sut.banners == [LoadBanner(message: "Couldn't update. Showing saved data.", retryTargets: [.lists])])
        #expect(sut.fullError == nil)
    }

    @Test("saved lists and a server error: the stale-data banner", arguments: [ListError.server, .invalidResponse])
    func staleBannerForServerErrors(error: ListError) {
        let sut = makeSUT(hasCachedLists: true, listsFailure: error)

        #expect(sut.banners == [LoadBanner(message: LoadFailurePolicy.staleDataText, retryTargets: [.lists])])
    }

    @Test("no lists and a failed load: the full error with the plain message")
    func fullErrorWithoutLists() {
        let sut = makeSUT(hasCachedLists: false, listsFailure: .network)

        #expect(sut.fullError == LoadBanner(message: ListError.network.userMessage, retryTargets: [.lists]))
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError?.message != LoadFailurePolicy.staleDataText)
    }

    @Test("a 403 never shows the stale-data text", arguments: [false, true])
    func forbiddenIsNeverStale(hasCachedLists: Bool) {
        let sut = makeSUT(hasCachedLists: hasCachedLists, listsFailure: .forbidden)
        let texts = sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }

        #expect(texts == [ListError.forbidden.userMessage])
    }

    @Test("the rate limit keeps its retry hint", arguments: [false, true])
    func rateLimitKeepsHint(hasCachedLists: Bool) {
        let sut = makeSUT(hasCachedLists: hasCachedLists, listsFailure: .rateLimited(retryAfter: 30))
        let texts = sut.banners.map(\.message) + [sut.fullError?.message].compactMap { $0 }

        #expect(texts == [ListError.rateLimited(retryAfter: 30).userMessage])
        #expect(texts.first?.contains("30 seconds") == true)
    }

    @Test("a session end hands over to the sign-in flow and shows no banner", arguments: [false, true])
    func sessionEndTakesOver(hasCachedLists: Bool) {
        let sut = makeSUT(hasCachedLists: hasCachedLists, listsFailure: .sessionEnded)

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
    }

    @Test("dismissing the lists source hides the banner")
    func dismissedHidesBanner() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.lists])

        expectEmpty(makeSUT(hasCachedLists: true, listsFailure: .network, dismissed: dismissed))
    }

    @Test("dismissal is cleared by reset: the same failure shows again")
    func resetShowsAgain() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.lists])
        dismissed.reset()

        let sut = makeSUT(hasCachedLists: true, listsFailure: .network, dismissed: dismissed)

        #expect(sut.banners.count == 1)
    }

    // MARK: The archive failure is a mutation error

    @Test("an archive failure alone adds nothing to the load presentation", arguments: [false, true])
    func archiveFailureIsNotALoad(hasCachedLists: Bool) {
        for error in [ListError.network, .server, .forbidden, .rateLimited(retryAfter: 5), .archivedReadOnly] {
            expectEmpty(makeSUT(hasCachedLists: hasCachedLists, archiveFailure: error))
        }
    }

    @Test("an archive failure next to a lists failure does not change the load banner")
    func archiveFailureDoesNotChangeTheLoadBanner() {
        let withoutArchive = makeSUT(hasCachedLists: true, listsFailure: .network)
        let withArchive = makeSUT(hasCachedLists: true, listsFailure: .network, archiveFailure: .server)

        #expect(withArchive.banners == withoutArchive.banners)
        #expect(withArchive.banners.flatMap(\.retryTargets) == [.lists], "Try Again repeats the lists load only")
    }

    @Test("an archive failure of any kind, a session end included, is not part of the load presentation")
    func archiveSessionEndIsNotALoad() {
        expectEmpty(makeSUT(hasCachedLists: true, archiveFailure: .sessionEnded))
    }
}
