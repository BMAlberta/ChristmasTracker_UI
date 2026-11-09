//
//  ListViewGuardsTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3 (Gate 2 fix round): the error-dismissal helper and the items-scope guard.
//  Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List view guards Tests")
struct ListViewGuardsTests {

    nonisolated static let allErrors: [ListError] = [
        .forbidden, .notFound, .recipientNotFound, .duplicateRecipientYear, .archivedReadOnly,
        .validation(message: "Name is too long."), .rateLimited(retryAfter: 12),
        .unauthorized, .sessionEnded, .network, .invalidResponse, .server
    ]

    private func makeSUT() -> ListErrorDismissal {
        ListErrorDismissal()
    }

    // MARK: - ListErrorDismissal

    @Test("Initially the current error is visible")
    func initialShowsError() {
        let sut = makeSUT()
        #expect(sut.dismissed == nil)
        #expect(sut.visible(.network) == .network)
    }

    @Test("visible(nil) is nil")
    func visibleNil() {
        var sut = makeSUT()
        #expect(sut.visible(nil) == nil)
        sut.dismiss(.server)
        #expect(sut.visible(nil) == nil)
    }

    @Test("dismiss(nil) is a no-op")
    func dismissNilNoOp() {
        var sut = makeSUT()
        sut.dismiss(nil)
        #expect(sut.dismissed == nil)
        #expect(sut.visible(.server) == .server)
        sut.dismiss(.network)
        sut.dismiss(nil)
        #expect(sut.dismissed == .network)
        #expect(sut.visible(.network) == nil)
    }

    @Test("A dismissed error is hidden, a different error is shown", arguments: allErrors)
    func dismissedHiddenOthersShown(error: ListError) {
        var sut = makeSUT()
        sut.dismiss(error)
        #expect(sut.visible(error) == nil)
        let other: ListError = error == .server ? .network : .server
        #expect(sut.visible(other) == other)
    }

    @Test("reset shows the same error again (repeat failure after a new operation)", arguments: allErrors)
    func resetShowsAgain(error: ListError) {
        var sut = makeSUT()
        sut.dismiss(error)
        sut.reset()
        #expect(sut.dismissed == nil)
        #expect(sut.visible(error) == error)
    }

    @Test("Delete fails with network, is dismissed, retried, and the same failure shows")
    func repeatFailureScenario() {
        var sut = makeSUT()
        sut.dismiss(.network)
        #expect(sut.visible(.network) == nil)
        sut.reset()
        #expect(sut.visible(.network) == .network)
    }

    @Test("Associated values take part in equality")
    func associatedValuesCompared() {
        var sut = makeSUT()
        sut.dismiss(.validation(message: "A"))
        #expect(sut.visible(.validation(message: "A")) == nil)
        #expect(sut.visible(.validation(message: "B")) == .validation(message: "B"))
        sut.reset()
        sut.dismiss(.rateLimited(retryAfter: 5))
        #expect(sut.visible(.rateLimited(retryAfter: 5)) == nil)
        #expect(sut.visible(.rateLimited(retryAfter: 6)) == .rateLimited(retryAfter: 6))
    }

    @Test("A second dismiss replaces the first")
    func secondDismissReplaces() {
        var sut = makeSUT()
        sut.dismiss(.network)
        sut.dismiss(.server)
        #expect(sut.visible(.server) == nil)
        #expect(sut.visible(.network) == .network)
    }

    @Test("reset on a fresh value is harmless")
    func resetFresh() {
        var sut = makeSUT()
        sut.reset()
        #expect(sut.visible(.server) == .server)
    }

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
