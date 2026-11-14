//
//  ListDetailRefreshTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-F2: the pure pieces behind the detail screen's pull to refresh.
//  - ListDetailRefresh.itemsStep chooses between refreshing and loading the items.
//
//  UX1a Story U3: the ListDetailRefresh.banner(for:) tests that used to live here (nil for no error and
//  for a session end, "The list could not be refreshed. " prefix, Try Again only when retryable) are
//  REMOVED with the banner path: the detail refresh failure now goes through ListDetailLoadState and
//  LoadFailurePolicy (see ListDetailLoadStateTests: refresh failure alone, merged with a detail
//  failure, session end shows nothing, rate limit hint kept), and the texts and actions are those of
//  LoadBannerPresentationTests / ScreenLoadPresentationTests.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListDetailRefresh")
struct ListDetailRefreshTests {

    // MARK: - itemsStep

    @Test("the items are refreshed when the item service already holds this list")
    func sameListRefreshes() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-1", listId: "list-1") == .refresh)
    }

    @Test("the items are loaded when the item service holds no list")
    func noListLoads() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: nil, listId: "list-1") == .load)
    }

    @Test("the items are loaded when the item service holds another list")
    func otherListLoads() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-2", listId: "list-1") == .load)
    }

    @Test("the comparison is exact, not case-insensitive or prefix based")
    func exactComparison() {
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "LIST-1", listId: "list-1") == .load)
        #expect(ListDetailRefresh.itemsStep(currentItemsListId: "list-10", listId: "list-1") == .load)
    }
}
