//
//  ItemsSectionAvailabilityTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B0 (gap 2): the pure state function behind the items section.
//  Rules: hasRows -> content; else isLoading -> loading; else itemsFailure != nil -> unavailable;
//  else empty.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ItemsSectionAvailability")
struct ItemsSectionAvailabilityTests {

    @Test("rows win over everything: cached or fresh rows are content, loading or failed or not",
          arguments: [true, false], [nil, ItemError.network, ItemError.server])
    func rowsAreContent(isLoading: Bool, failure: ItemError?) {
        // Old behavior: no such state existed; a failure with rows was not distinguished from content.
        #expect(ItemsSectionAvailability.make(isLoading: isLoading, hasRows: true, itemsFailure: failure) == .content)
    }

    @Test("no rows while loading is loading, with or without a stale failure",
          arguments: [nil, ItemError.network])
    func loadingWithoutRows(failure: ItemError?) {
        // Old behavior: no such state existed; the section could not tell loading from empty.
        #expect(ItemsSectionAvailability.make(isLoading: true, hasRows: false, itemsFailure: failure) == .loading)
    }

    @Test("failed with no rows is unavailable, not empty",
          arguments: [ItemError.network, .server, .forbidden, .invalidResponse, .rateLimited(retryAfter: 3)])
    func failedWithNoRowsIsUnavailable(failure: ItemError) {
        // Old behavior: a failed items load with no rows showed the empty copy.
        let state = ItemsSectionAvailability.make(isLoading: false, hasRows: false, itemsFailure: failure)

        #expect(state == .unavailable)
        #expect(state != .empty)
    }

    @Test("loaded with no rows and no failure is empty")
    func loadedAndEmpty() {
        // Old behavior: the empty copy was shown for every no-rows case, failed or not.
        #expect(ItemsSectionAvailability.make(isLoading: false, hasRows: false, itemsFailure: nil) == .empty)
    }

    @Test("the unavailable text is the neutral copy that offers a retry")
    func unavailableTextIsNeutral() {
        // Old behavior: there was no unavailable copy, only the empty-list copy.
        #expect(ItemsSectionAvailability.unavailableText == "Items unavailable. Pull to refresh or tap Try Again.")
    }
}
