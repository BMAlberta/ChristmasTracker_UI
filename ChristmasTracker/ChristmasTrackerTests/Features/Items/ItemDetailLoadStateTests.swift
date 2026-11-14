//
//  ItemDetailLoadStateTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: ItemDetailLoadState replaces the Text-plus-Try-Again `notLoadedContent` of the item
//  detail screen. No item and a failure: the full error. Item shown and a failure: the stale-data
//  banner. Source .itemDetail. ItemDetailScreenState stays (ItemDetailScreenStateTests). Fake data only.
//
//  ASSUMPTION (reported): ItemDetailLoadState.make returns a ScreenLoadPresentation. Only the not
//  loading case (loading: false) is covered: what a banner does WHILE a retry is loading is not named
//  in the interface.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemDetailLoadState Tests")
struct ItemDetailLoadStateTests {

    private func makeSUT(
        hasItem: Bool,
        error: ItemError?,
        dismissed: DismissedLoads = DismissedLoads()
    ) -> ScreenLoadPresentation {
        ItemDetailLoadState.make(hasItem: hasItem, loading: false, error: error, dismissed: dismissed)
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

    @Test("no error: nothing is shown", arguments: [false, true])
    func noError(hasItem: Bool) {
        expectEmpty(makeSUT(hasItem: hasItem, error: nil))
    }

    @Test("no item and a failure: the full error with the plain message and a retry of the item")
    func fullErrorWithoutItem() {
        let sut = makeSUT(hasItem: false, error: .network)

        #expect(sut.fullError == LoadBanner(message: ItemError.network.userMessage, retryTargets: [.itemDetail]))
        #expect(sut.banners.isEmpty)
    }

    @Test("an item shown and a failure: the stale-data banner and no full error")
    func staleBannerWithItem() {
        let sut = makeSUT(hasItem: true, error: .network)

        #expect(sut.banners == [LoadBanner(message: "Couldn't update. Showing saved data.", retryTargets: [.itemDetail])])
        #expect(sut.fullError == nil)
    }

    @Test("connectivity failures with an item shown give the stale-data banner",
          arguments: [ItemError.network, .server, .invalidResponse])
    func staleBannerForConnectivity(error: ItemError) {
        let sut = makeSUT(hasItem: true, error: error)

        #expect(sut.banners.map(\.message) == [LoadFailurePolicy.staleDataText])
    }

    @Test("a 403 never shows the stale-data text", arguments: [false, true])
    func forbiddenIsNeverStale(hasItem: Bool) {
        let sut = makeSUT(hasItem: hasItem, error: .forbidden)

        #expect(shownTexts(sut) == [ItemError.forbidden.userMessage])
    }

    @Test("a gone item leaves the screen and shows no banner", arguments: [false, true])
    func notFoundLeaves(hasItem: Bool) {
        let sut = makeSUT(hasItem: hasItem, error: .notFound)

        #expect(sut.leavesScreen == true)
        #expect(ItemErrorPresentation.leavesScreen(.notFound) == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
    }

    @Test("a session end hands over to the sign-in flow and shows no banner", arguments: [false, true])
    func sessionEndTakesOver(hasItem: Bool) {
        let sut = makeSUT(hasItem: hasItem, error: .sessionEnded)

        #expect(sut.signInTakesOver == true)
        #expect(sut.banners.isEmpty)
        #expect(sut.fullError == nil)
    }

    @Test("the rate limit keeps its retry hint", arguments: [false, true])
    func rateLimitKeepsHint(hasItem: Bool) {
        let sut = makeSUT(hasItem: hasItem, error: .rateLimited(retryAfter: 30))

        #expect(shownTexts(sut) == [ItemError.rateLimited(retryAfter: 30).userMessage])
    }

    @Test("dismissing the item source hides the banner", arguments: [false, true])
    func dismissedHides(hasItem: Bool) {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.itemDetail])

        expectEmpty(makeSUT(hasItem: hasItem, error: .network, dismissed: dismissed))
    }

    @Test("after reset the failure shows again")
    func resetShowsAgain() {
        var dismissed = DismissedLoads()
        dismissed.dismiss([.itemDetail])
        dismissed.reset()

        let sut = makeSUT(hasItem: false, error: .network, dismissed: dismissed)

        #expect(sut.fullError != nil)
    }

    @Test("no failure of any kind ever carries the list-detail source")
    func targetsAreOnlyTheItemDetail() {
        for error in [ItemError.network, .server, .forbidden, .rateLimited(retryAfter: 3), .validation(message: "Fake")] {
            let sut = makeSUT(hasItem: true, error: error)
            let targets = sut.banners.flatMap(\.retryTargets) + (sut.fullError?.retryTargets ?? [])
            #expect(targets.allSatisfy { $0 == .itemDetail }, "\(error)")
        }
    }
}
