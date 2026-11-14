//
//  StatsScreenModelStaleBannerTests.swift
//  ChristmasTrackerTests
//
//  I5a Story C: the stale-data failure of StatsScreenModel. A refresh that fails while saved data is on
//  screen shows "Couldn't update. Showing saved data." with Try Again and Dismiss; Dismiss hides it until
//  the next failure; leaving the screen clears it. The load error is the stats service's own property
//  and is cleared with the screen; nothing else carries it.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenModel stale banner Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelStaleBannerTests {

    @Test("the stale banner text and actions are exactly as the brief says")
    func staleBannerText() async {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh()

        let banner = sut.model.staleBanner
        #expect(banner?.message == "Couldn't update. Showing saved data.")
        #expect(banner?.actions == [.tryAgain, .dismiss])
        #expect(banner == StatsScreenTest.staleBanner)
    }

    @Test("a failed refresh keeps the saved data on screen and in the content phase")
    func savedDataStaysVisible() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"))
        let before = sut.model.screenState

        await sut.failRefresh()

        #expect(sut.model.loadPhase == .content)
        #expect(sut.model.screenState == before)
        #expect(sut.model.failureBanner == nil, "the full-screen failure is only for an empty screen")
    }

    // REWRITTEN (UX1a U3): this test used to pin that a 403 is shown as "Couldn't update. Showing saved
    // data.". The policy forbids that: a 403 is never shown as a failed update, it shows its own plain
    // message (still with Try Again and Dismiss, saved data still visible). The connectivity cases keep
    // the stale text (staleBannerText above, StatsScreenModelPolicyBannerTests).
    @Test("a non-retryable failure shows its own plain message, never the stale-data text")
    func staleBannerForNonRetryableFailure() async {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh(with: .forbidden)

        #expect(sut.model.staleBanner?.message == BudgetError.forbidden.userMessage)
        #expect(sut.model.staleBanner?.message != StatsScreenTest.staleMessage)
        #expect(sut.model.staleBanner?.actions == [.tryAgain, .dismiss])
        #expect(sut.model.loadPhase == .content, "the saved data stays visible")
    }

    @Test("no stale banner while the refresh succeeds")
    func noBannerOnSuccess() async {
        let sut = await makeLoadedStatsScreenSUT()
        sut.scriptAppear(stats: StatsFix.year(2026, spent: "300"), budgets: [BudgetServiceFix.budget(2026)])

        await sut.model.refresh()

        #expect(sut.model.staleBanner == nil)
    }

    @Test("Dismiss hides the stale banner")
    func dismissHides() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh()
        #expect(sut.model.staleBanner != nil)

        sut.model.dismissStaleBanner()

        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.loadPhase == .content)
    }

    @Test("a new failure after a dismissal shows the stale banner again")
    func newFailureShowsAgain() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh()
        sut.model.dismissStaleBanner()
        #expect(sut.model.staleBanner == nil)

        await sut.failRefresh()

        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner)
    }

    @Test("leaving the screen clears the banner and the stats service's load failure")
    func disappearClears() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh()
        #expect(sut.stats.loadFailure != nil)

        sut.model.onDisappear()

        #expect(sut.model.staleBanner == nil)
        #expect(sut.stats.loadFailure == nil)
    }

    @Test("after leaving and coming back the old failure is not shown, even if it was dismissed before")
    func reappearAfterDisappear() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh()
        sut.model.dismissStaleBanner()
        sut.model.onDisappear()

        await sut.model.onAppear()
        #expect(sut.model.staleBanner == nil)

        await sut.failRefresh()
        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner, "the dismissal state was reset by leaving")
    }

    @Test("Try Again from the stale banner refetches and, on success, removes the banner and shows new data")
    func tryAgainFromStaleBanner() async {
        let sut = await makeLoadedStatsScreenSUT(stats: StatsFix.year(2026, spent: "100"))
        await sut.failRefresh()
        #expect(sut.model.staleBanner != nil)
        sut.scriptAppear(stats: StatsFix.year(2026, spent: "999"), budgets: [BudgetServiceFix.budget(2026)])

        await sut.model.tryAgain()

        #expect(sut.model.staleBanner == nil)
        let expected = StatsScreenTest.expectedState(
            year: 2026, stats: StatsFix.year(2026, spent: "999"), budget: BudgetServiceFix.budget(2026)
        )
        #expect(sut.model.screenState == expected)
    }

    @Test("a failed refresh of one year does not put a banner on a year that was fetched fine")
    func successfulSelectAfterFailureClears() async {
        let sut = await makeLoadedStatsScreenSUT()
        await sut.failRefresh()
        sut.loader.enqueue(StatsFix.year(2025, spent: "40"))

        await sut.model.select(year: 2025)

        #expect(sut.model.staleBanner == nil, "the successful load of 2025 cleared the load failure")
        #expect(sut.model.screenState?.year == 2025)
    }
}
