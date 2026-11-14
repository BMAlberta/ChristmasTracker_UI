//
//  StatsScreenModelPolicyBannerTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: the Statistics banners (staleBanner with saved data on screen, failureBanner with
//  nothing to show) come from LoadFailurePolicy through ScreenLoadPresentation and
//  LoadBannerPresentation, with sources .stats and .budgets. The texts are the policy's:
//   - connectivity failure with saved data: "Couldn't update. Showing saved data.";
//   - 403 never shows that text (it shows its own plain message);
//   - the rate limit keeps its retry hint;
//   - no saved data: the plain message, Try Again only (a full error is not dismissible);
//   - a stats failure and a budgets failure of the same category are ONE banner;
//   - a session end shows no banner.
//
//  ASSUMPTION (reported): `staleBanner` and `failureBanner` keep their names and meaning (the
//  existing StatsScreenModel properties); the amendment names no new Stats property.
//
//  Determinism: gated fakes. No sleeps, no yield loops. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("StatsScreenModel policy banner Tests", .timeLimit(.minutes(1)))
@MainActor
struct StatsScreenModelPolicyBannerTests {

    /// What the policy says the saved-data banner is for a failure of `error` on the stats source.
    private func expectedStaleBanner(for error: BudgetError) throws -> InlineErrorBannerState {
        let presentation = ScreenLoadPresentation.make(
            hasCachedData: true,
            failures: [LoadFailure(error, source: .stats)]
        )
        let banner = try #require(presentation.banners.first)
        return LoadBannerPresentation.state(for: banner)
    }

    private func expectedFullErrorBanner(for error: BudgetError) throws -> InlineErrorBannerState {
        let presentation = ScreenLoadPresentation.make(
            hasCachedData: false,
            failures: [LoadFailure(error, source: .stats)]
        )
        let banner = try #require(presentation.fullError)
        return LoadBannerPresentation.state(for: banner, dismissible: false)
    }

    // MARK: Saved data on screen

    @Test("a connectivity failure with saved data shows the policy's stale-data banner",
          arguments: [BudgetError.network, .server, .invalidResponse])
    func connectivityIsStale(error: BudgetError) async throws {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh(with: error)

        #expect(sut.model.staleBanner == (try expectedStaleBanner(for: error)))
        #expect(sut.model.staleBanner?.message == LoadFailurePolicy.staleDataText)
        #expect(sut.model.staleBanner?.actions == [.tryAgain, .dismiss])
        #expect(sut.model.failureBanner == nil)
    }

    @Test("a 403 with saved data never shows the stale-data text")
    func forbiddenIsNeverStale() async throws {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh(with: .forbidden)

        let banner = try #require(sut.model.staleBanner)
        #expect(banner.message == BudgetError.forbidden.userMessage)
        #expect(banner.message != LoadFailurePolicy.staleDataText)
        #expect(banner == (try expectedStaleBanner(for: .forbidden)))
        #expect(sut.model.loadPhase == .content, "the saved data stays visible")
    }

    @Test("the rate limit with saved data keeps its retry hint")
    func rateLimitKeepsHint() async throws {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh(with: .rateLimited(retryAfter: 30))

        let banner = try #require(sut.model.staleBanner)
        #expect(banner.message == BudgetError.rateLimited(retryAfter: 30).userMessage)
    }

    @Test("a session end with saved data shows no banner")
    func sessionEndShowsNoBanner() async {
        let sut = await makeLoadedStatsScreenSUT()

        await sut.failRefresh(with: .sessionEnded)

        #expect(sut.model.staleBanner == nil)
        #expect(sut.model.failureBanner == nil)
    }

    @Test("the stats and the budgets loads failing the same way give ONE stale-data banner")
    func statsAndBudgetsSameCategoryOneBanner() async throws {
        let sut = await makeLoadedStatsScreenSUT()
        sut.manager.enqueueFailure(BudgetError.network)
        sut.loader.enqueueFailure(BudgetError.network)

        await sut.model.refresh()

        #expect(sut.model.staleBanner == StatsScreenTest.staleBanner)
        #expect(sut.model.failureBanner == nil)
    }

    // MARK: Nothing on screen

    @Test("a connectivity failure with nothing cached is the full error: plain message, Try Again only",
          arguments: [BudgetError.network, .server])
    func fullErrorWithoutData(error: BudgetError) async throws {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(error)

        await sut.model.onAppear()

        #expect(sut.model.failureBanner == (try expectedFullErrorBanner(for: error)))
        #expect(sut.model.failureBanner?.message == error.userMessage)
        #expect(sut.model.failureBanner?.actions == [.tryAgain])
        #expect(sut.model.staleBanner == nil, "the stale banner is only for saved data")
    }

    @Test("a full error never carries the stale-data text", arguments: [BudgetError.network, .forbidden, .server])
    func fullErrorIsNeverStale(error: BudgetError) async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(error)

        await sut.model.onAppear()

        #expect(sut.model.failureBanner?.message != LoadFailurePolicy.staleDataText)
    }

    @Test("a session end with nothing cached shows no banner")
    func sessionEndWithoutDataShowsNoBanner() async {
        let sut = makeStatsScreenSUT()
        sut.manager.enqueueList([])
        sut.loader.enqueueFailure(BudgetError.sessionEnded)

        await sut.model.onAppear()

        #expect(sut.model.failureBanner == nil)
        #expect(sut.model.staleBanner == nil)
    }
}
