//
//  ListViewGuardsTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3 (Gate 2 fix round): the items-scope guard. Fake data only.
//
//  UX1a Story U3: the ListErrorDismissal suite that used to live here is REWRITTEN as
//  DismissedLoadsTests (Features/Shared/ErrorPolicy): ListErrorDismissal is removed with the
//  ListErrorBanner it served, and its rules (a dismissed failure is hidden, another one stays visible,
//  reset restores, dismissing nothing is a no-op) now belong to DismissedLoads, which hides by SOURCE.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List view guards Tests")
struct ListViewGuardsTests {

    // MARK: - ListItemsScope

    @Test("Same list id returns the items in order")
    func sameIdReturnsItems() {
        #expect(ListItemsScope.itemsToShow(["a", "b", "c"], currentListId: "list-1", listId: "list-1") == ["a", "b", "c"])
    }

    @Test("A different list id returns nothing")
    func differentIdEmpty() {
        #expect(ListItemsScope.itemsToShow(["a", "b"], currentListId: "list-2", listId: "list-1").isEmpty)
    }

    @Test("A nil current list id returns nothing")
    func nilIdEmpty() {
        #expect(ListItemsScope.itemsToShow(["a", "b"], currentListId: nil, listId: "list-1").isEmpty)
    }

    @Test("Empty items stay empty")
    func emptyStaysEmpty() {
        let none: [String] = []
        #expect(ListItemsScope.itemsToShow(none, currentListId: "list-1", listId: "list-1").isEmpty)
    }

    @Test("Works for any item type")
    func genericItems() {
        #expect(ListItemsScope.itemsToShow([1, 2], currentListId: "list-1", listId: "list-1") == [1, 2])
        #expect(ListItemsScope.itemsToShow([1, 2], currentListId: "list-9", listId: "list-1").isEmpty)
    }
}
