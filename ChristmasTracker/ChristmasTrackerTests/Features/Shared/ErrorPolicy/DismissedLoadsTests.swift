//
//  DismissedLoadsTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U3: DismissedLoads is the dismissal helper that replaces ListErrorDismissal. A screen
//  filters out the failures the user dismissed BEFORE calling ScreenLoadPresentation.make. A failure of
//  a dismissed SOURCE is hidden; a failure of any other source stays visible; reset() restores
//  everything. It replaces the ListErrorDismissal tests of ListViewGuardsTests. Fake data only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("DismissedLoads Tests")
struct DismissedLoadsTests {

    private typealias F = LoadFailureFixtures

    private func makeSUT() -> DismissedLoads {
        DismissedLoads()
    }

    private let detail = F.failure(.unreachable, .listDetail)
    private let items = F.failure(.unreachable, .items)
    private let lists = F.failure(.server, .lists)

    @Test("nothing dismissed: every failure is visible, in order")
    func initiallyEverythingVisible() {
        let sut = makeSUT()

        #expect(sut.visible([detail, items, lists]) == [detail, items, lists])
    }

    @Test("visible of no failures is empty, also after a dismissal")
    func visibleEmpty() {
        var sut = makeSUT()
        #expect(sut.visible([]).isEmpty)

        sut.dismiss([.listDetail])

        #expect(sut.visible([]).isEmpty)
    }

    @Test("dismissing a source hides only the failures of that source")
    func dismissHidesOnlyThatSource() {
        var sut = makeSUT()

        sut.dismiss([.listDetail])

        #expect(sut.visible([detail, items, lists]) == [items, lists])
    }

    @Test("dismissing several sources hides all of them and nothing else")
    func dismissSeveralSources() {
        var sut = makeSUT()

        sut.dismiss([.listDetail, .items])

        #expect(sut.visible([detail, items, lists]) == [lists])
    }

    @Test("dismissals accumulate across calls")
    func dismissalsAccumulate() {
        var sut = makeSUT()
        sut.dismiss([.listDetail])
        sut.dismiss([.items])

        #expect(sut.visible([detail, items, lists]) == [lists])
    }

    @Test("dismissing no sources changes nothing")
    func dismissNothing() {
        var sut = makeSUT()

        sut.dismiss([])

        #expect(sut.visible([detail, items, lists]) == [detail, items, lists])
    }

    @Test("a different failure of another source stays visible")
    func otherSourceStaysVisible() {
        var sut = makeSUT()
        sut.dismiss([.items])
        let newFailureOfAnotherSource = F.failure(.server, .listDetail)

        #expect(sut.visible([newFailureOfAnotherSource]) == [newFailureOfAnotherSource])
    }

    @Test("a dismissed source stays hidden even when its failure changes, until reset")
    func dismissedSourceStaysHiddenWithNewFailure() {
        var sut = makeSUT()
        sut.dismiss([.listDetail])
        let changed = F.failure(.server, .listDetail)

        #expect(sut.visible([changed]).isEmpty)
    }

    @Test("reset restores every dismissed failure")
    func resetRestores() {
        var sut = makeSUT()
        sut.dismiss([.listDetail, .items, .lists])
        #expect(sut.visible([detail, items, lists]).isEmpty)

        sut.reset()

        #expect(sut.visible([detail, items, lists]) == [detail, items, lists])
    }

    @Test("reset on a fresh value is harmless")
    func resetFresh() {
        var sut = makeSUT()

        sut.reset()

        #expect(sut.visible([lists]) == [lists])
    }

    @Test("a repeat failure after a new load (reset) shows again")
    func repeatFailureScenario() {
        var sut = makeSUT()
        sut.dismiss([.lists])
        #expect(sut.visible([lists]).isEmpty)

        sut.reset()

        #expect(sut.visible([lists]) == [lists])
    }

    @Test("dismissing every source of a screen leaves no banner and no full error", arguments: [false, true])
    func dismissedFailuresProduceNothing(hasCachedData: Bool) {
        var sut = makeSUT()
        sut.dismiss([.listDetail, .items])

        let presentation = ScreenLoadPresentation.make(
            hasCachedData: hasCachedData,
            failures: sut.visible([detail, items])
        )

        #expect(presentation.banners.isEmpty)
        #expect(presentation.fullError == nil)
        #expect(presentation.leavesScreen == false)
        #expect(presentation.signInTakesOver == false)
    }

    @Test("dismissing one of two failures leaves the other banner")
    func dismissOneOfTwoLeavesTheOther() {
        var sut = makeSUT()
        sut.dismiss([.items])

        let presentation = ScreenLoadPresentation.make(
            hasCachedData: true,
            failures: sut.visible([detail, F.failure(.server, .items)])
        )

        #expect(presentation.banners.map(\.retryTargets) == [[.listDetail]])
    }

    @Test("the visible failures keep their category, source and message")
    func visibleFailuresAreUnchanged() {
        var sut = makeSUT()
        sut.dismiss([.lists])
        let withHint = F.failure(.rateLimited, .items, message: "Fake hint", retryAfter: 7)

        #expect(sut.visible([lists, withHint]) == [withHint])
    }
}
