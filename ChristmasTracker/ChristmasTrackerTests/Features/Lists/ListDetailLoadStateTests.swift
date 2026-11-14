//
//  ListDetailLoadStateTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3 (the key acceptance): the list detail screen combines the service's detail load
//  failure (source .listDetail), the failure RETURNED by refreshListDetail (source .listDetail) and
//  the item service's list load error (source .items) into ONE policy call with hasCachedData =
//  hasDetail.
//   - the same category from detail and items: ONE banner whose Try Again repeats BOTH loads;
//   - different categories: two banners;
//   - a refresh failure and a detail failure of the same category: one banner;
//   - no detail shown: the full error;
//   - 403 and 404 never show "Couldn't update"; a gone list leaves; a session end shows no banner;
//   - the rate limit keeps its retry hint.
//  Fake data only.
//
//  ASSUMPTION (reported): ListDetailLoadState.make returns a ScreenLoadPresentation. The only call is
//  in makeSUT, so a different return type is a one-place change.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListDetailLoadState Tests")
struct ListDetailLoadStateTests {

    private let stale = LoadFailurePolicy.staleDataText

    private func makeSUT(
        hasDetail: Bool,
        detailFailure: ListError? = nil,
        refreshFailure: ListError? = nil,
        itemsFailure: ItemError? = nil,
        dismissed: DismissedLoads = DismissedLoads()
    ) -> ScreenLoadPresentation {
        ListDetailLoadState.make(
            hasDetail: hasDetail,
            detailFailure: detailFailure,
            refreshFailure: refreshFailure,
            itemsFailure: itemsFailure,
            dismissed: dismissed
        )
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

    // MARK: Nothing

    @Test("no failures: nothing is shown", arguments: [false, true])
    func noFailures(hasDetail: Bool) {
        expectEmpty(makeSUT(hasDetail: hasDetail))
    }

    // MARK: ONE banner for the same category

    @Test("detail and items failing with the same category give ONE banner that retries both",
          arguments: [(ListError.network, ItemError.network), (.server, .server), (.invalidResponse, .server)])
    func sameCategoryOneBanner(detail: ListError, items: ItemError) {
        let sut = makeSUT(hasDetail: true, detailFailure: detail, itemsFailure: items)

        #expect(sut.banners.count == 1, "one banner, not two")
        #expect(sut.banners.first?.message == stale)
        #expect(sut.banners.first?.retryTargets == [.listDetail, .items])
        #expect(sut.fullError == nil)
    }

    @Test("the refresh failure and the items failure of the same category give ONE banner that retries both")
    func refreshAndItemsOneBanner() {
        let sut = makeSUT(hasDetail: true, refreshFailure: .network, itemsFailure: .network)

        #expect(sut.banners.count == 1)
        #expect(sut.banners.first?.retryTargets == [.listDetail, .items])
    }

    @Test("detail, refresh and items all failing the same way give ONE banner with each source once")
    func allThreeOneBanner() {
        let sut = makeSUT(
            hasDetail: true,
            detailFailure: .network,
            refreshFailure: .network,
            itemsFailure: .network
        )

        #expect(sut.banners.count == 1)
        #expect(sut.banners.first?.message == stale)
        #expect(sut.banners.first?.retryTargets == [.listDetail, .items])
    }

    @Test("a refresh failure and a detail failure of the same category merge into one banner for the detail")
    func refreshAndDetailMerge() {
        let sut = makeSUT(hasDetail: true, detailFailure: .network, refreshFailure: .network)

        #expect(sut.banners.count == 1)
        #expect(sut.banners.first?.message == stale)
        #expect(sut.banners.first?.retryTargets == [.listDetail])
    }

    @Test("a lone refresh failure with the detail shown is the stale-data banner for the detail")
    func loneRefreshFailure() {
        let sut = makeSUT(hasDetail: true, refreshFailure: .server)

        #expect(sut.banners == [LoadBanner(message: stale, retryTargets: [.listDetail])])
    }

    @Test("a lone items failure with the detail shown is the stale-data banner for the items")
    func loneItemsFailure() {
        let sut = makeSUT(hasDetail: true, itemsFailure: .network)

        #expect(sut.banners == [LoadBanner(message: stale, retryTargets: [.items])])
    }

    // MARK: Two banners for different categories

    @Test("different categories give two banners, each retrying its own load")
    func differentCategoriesTwoBanners() {
        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .server)

        #expect(sut.banners.count == 2)
        #expect(sut.banners.map(\.retryTargets) == [[.listDetail], [.items]], "unreachable before server")
        #expect(sut.fullError == nil)
    }

    @Test("a connectivity failure next to a rate limit gives two banners and keeps the rate-limit hint")
    func connectivityAndRateLimit() {
        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .rateLimited(retryAfter: 30))

        #expect(sut.banners.count == 2)
        #expect(sut.banners.map(\.message).contains(stale))
        #expect(sut.banners.map(\.message).contains(ItemError.rateLimited(retryAfter: 30).userMessage))
    }

    // MARK: No detail: the full error

    @Test("no detail shown and a failed detail load: the full error with the plain message")
    func fullErrorWithoutDetail() {
        let sut = makeSUT(hasDetail: false, detailFailure: .network)

        #expect(sut.fullError == LoadBanner(message: ListError.network.userMessage, retryTargets: [.listDetail]))
        #expect(sut.banners.isEmpty)
    }

    @Test("no detail and detail plus items failing the same way: one full error that retries both")
    func fullErrorRetriesBoth() {
        let sut = makeSUT(hasDetail: false, detailFailure: .network, itemsFailure: .network)

        #expect(sut.fullError?.retryTargets == [.listDetail, .items])
        #expect(sut.fullError?.message == ListError.network.userMessage)
        #expect(sut.banners.isEmpty)
    }

    @Test("no detail never shows the stale-data text", arguments: [ListError.network, .server, .invalidResponse])
    func noDetailNeverStale(error: ListError) {
        let sut = makeSUT(hasDetail: false, detailFailure: error, refreshFailure: error, itemsFailure: .network)

        #expect(!shownTexts(sut).contains(stale))
    }

    // MARK: 403 and 404

    @Test("a 403 of the detail never shows the stale-data text", arguments: [false, true])
    func forbiddenIsNeverStale(hasDetail: Bool) {
        let sut = makeSUT(hasDetail: hasDetail, detailFailure: .forbidden)

        #expect(shownTexts(sut) == [ListError.forbidden.userMessage])
    }

    @Test("a 403 of the refresh or the items never shows the stale-data text", arguments: [false, true])
    func forbiddenElsewhereIsNeverStale(hasDetail: Bool) {
        let refresh = makeSUT(hasDetail: hasDetail, refreshFailure: .forbidden)
        let items = makeSUT(hasDetail: hasDetail, itemsFailure: .forbidden)

        #expect(!shownTexts(refresh).contains(stale))
        #expect(!shownTexts(items).contains(stale))
    }

    @Test("a gone list leaves the screen and shows no banner", arguments: [false, true])
    func notFoundLeaves(hasDetail: Bool) {
        let sut = makeSUT(hasDetail: hasDetail, detailFailure: .notFound)

        #expect(sut.leavesScreen == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(shownTexts(sut).contains(stale) == false)
    }

    @Test("a gone list found by the refresh or by the items load also leaves")
    func notFoundFromOtherSourcesLeaves() {
        #expect(makeSUT(hasDetail: true, refreshFailure: .notFound).leavesScreen == true)
        #expect(makeSUT(hasDetail: true, itemsFailure: .notFound).leavesScreen == true)
    }

    @Test("a gone list wins over a connectivity failure of the items")
    func notFoundBeatsItemsFailure() {
        let sut = makeSUT(hasDetail: true, detailFailure: .notFound, itemsFailure: .network)

        #expect(sut.leavesScreen == true)
        #expect(sut.banners.isEmpty)
    }

    // MARK: Session end

    @Test("a session end takes over and shows no banner", arguments: [false, true])
    func sessionEndTakesOver(hasDetail: Bool) {
        let sut = makeSUT(hasDetail: hasDetail, detailFailure: .sessionEnded)

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
        #expect(sut.leavesScreen == false)
    }

    @Test("a session end of the refresh or the items also takes over")
    func sessionEndFromOtherSources() {
        #expect(makeSUT(hasDetail: true, refreshFailure: .sessionEnded).signInTakesOver == true)
        #expect(makeSUT(hasDetail: true, itemsFailure: .sessionEnded).signInTakesOver == true)
    }

    @Test("a session end wins over another failure")
    func sessionEndBeatsOthers() {
        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .sessionEnded)

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
    }

    // MARK: Rate limit

    @Test("the rate limit keeps its retry hint, with or without the detail", arguments: [false, true])
    func rateLimitKeepsHint(hasDetail: Bool) {
        let sut = makeSUT(hasDetail: hasDetail, detailFailure: .rateLimited(retryAfter: 30))

        #expect(shownTexts(sut) == [ListError.rateLimited(retryAfter: 30).userMessage])
        #expect(shownTexts(sut).first?.contains("30 seconds") == true)
    }

    // MARK: Dismissal

    @Test("dismissing both sources hides the single merged banner")
    func dismissBothHidesMerged() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.listDetail, .items])

        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .network, dismissed: dismissed)

        expectEmpty(sut)
    }

    @Test("dismissing the detail leaves the banner of the items failure")
    func dismissDetailLeavesItems() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.listDetail])

        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .server, dismissed: dismissed)

        #expect(sut.banners.map(\.retryTargets) == [[.items]])
    }

    @Test("dismissing the refresh failure also hides a detail failure (same source)")
    func dismissListDetailHidesBothDetailFailures() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.listDetail])

        let sut = makeSUT(hasDetail: true, detailFailure: .network, refreshFailure: .network, dismissed: dismissed)

        expectEmpty(sut)
    }

    @Test("after reset the dismissed failure shows again")
    func resetShowsAgain() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.listDetail, .items])
        dismissed.reset()

        let sut = makeSUT(hasDetail: true, detailFailure: .network, itemsFailure: .network, dismissed: dismissed)

        #expect(sut.banners.count == 1)
    }

    // MARK: The items section has no banner of its own

    @Test("the merged banner is the only error output: there is no separate refresh or items banner")
    func singleOutput() {
        let sut = makeSUT(hasDetail: true, detailFailure: .network, refreshFailure: .network, itemsFailure: .network)

        #expect(sut.banners.count + (sut.fullError == nil ? 0 : 1) == 1)
    }
}
