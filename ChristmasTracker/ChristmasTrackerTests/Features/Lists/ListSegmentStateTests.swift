//
//  ListSegmentStateTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListSegmentState, the rows and the empty-state copy of one segment of the lists
//  screen. Pure: the screen filters by search before it calls this. Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List segment state Tests")
struct ListSegmentStateTests {

    private func makeSUT(
        _ segment: ListSegment,
        lists: [GiftList] = [],
        isSearching: Bool = false
    ) -> ListSegmentState {
        ListSegmentState(segment: segment, lists: lists, isSearching: isSearching)
    }

    private func list(_ id: String, _ status: ListStatus) -> GiftList {
        ListFixtures.giftList(id: id, name: "Name of \(id)", status: status)
    }

    private var mixed: [GiftList] {
        [
            list("list-a1", .active), list("list-z1", .archived), list("list-d1", .draft),
            list("list-a2", .active), list("list-z2", .archived)
        ]
    }

    // MARK: - Rows

    @Test("The active segment keeps ACTIVE and DRAFT lists, in the given order")
    func activeRows() {
        let state = makeSUT(.active, lists: mixed)
        #expect(state.lists.map(\.id) == ["list-a1", "list-d1", "list-a2"])
    }

    @Test("The archived segment keeps ARCHIVED lists only, in the given order")
    func archivedRows() {
        let state = makeSUT(.archived, lists: mixed)
        #expect(state.lists.map(\.id) == ["list-z1", "list-z2"])
    }

    @Test("The order of the input is preserved, not sorted")
    func orderPreserved() {
        let reversed = Array(mixed.reversed())
        #expect(makeSUT(.active, lists: reversed).lists.map(\.id) == ["list-a2", "list-d1", "list-a1"])
        #expect(makeSUT(.archived, lists: reversed).lists.map(\.id) == ["list-z2", "list-z1"])
    }

    @Test("The rows are the unchanged lists (no rewriting)")
    func rowsAreUnchanged() {
        let input = mixed
        let state = makeSUT(.archived, lists: input)
        #expect(state.lists == input.filter { $0.status == .archived })
    }

    @Test("Searching does not change which lists the segment keeps", arguments: ListSegment.allCases)
    func searchingKeepsSameRows(segment: ListSegment) {
        let plain = makeSUT(segment, lists: mixed, isSearching: false)
        let searching = makeSUT(segment, lists: mixed, isSearching: true)
        #expect(plain.lists == searching.lists)
    }

    // MARK: - Empty copy: not searching

    @Test("Active, not searching, no lists: No active lists, with the create action")
    func activeEmpty() {
        let state = makeSUT(.active)
        #expect(state.lists.isEmpty)
        #expect(state.emptyTitle == "No active lists")
        #expect(!state.emptyMessage.isEmpty)
        #expect(state.showsCreateAction)
    }

    @Test("Active, not searching, only archived lists: the segment is empty and says No active lists")
    func activeEmptyWhenOnlyArchived() {
        let state = makeSUT(.active, lists: [list("list-z1", .archived)])
        #expect(state.lists.isEmpty)
        #expect(state.emptyTitle == "No active lists")
        #expect(state.showsCreateAction)
    }

    @Test("Archived, not searching, no lists: No archived lists, message explains, no create action")
    func archivedEmpty() {
        let state = makeSUT(.archived)
        #expect(state.lists.isEmpty)
        #expect(state.emptyTitle == "No archived lists")
        #expect(state.emptyMessage.lowercased().contains("archived"))
        #expect(!state.showsCreateAction)
    }

    @Test("Archived, not searching, only active lists: the segment is empty and says No archived lists")
    func archivedEmptyWhenOnlyActive() {
        let state = makeSUT(.archived, lists: [list("list-a1", .active), list("list-d1", .draft)])
        #expect(state.lists.isEmpty)
        #expect(state.emptyTitle == "No archived lists")
        #expect(!state.showsCreateAction)
    }

    // MARK: - Empty copy: searching

    @Test("Searching, either segment, no lists: No Results and the search message, no create action",
          arguments: ListSegment.allCases)
    func searchingEmpty(segment: ListSegment) {
        let state = makeSUT(segment, isSearching: true)
        #expect(state.lists.isEmpty)
        #expect(state.emptyTitle == "No Results")
        #expect(state.emptyMessage == "No lists match your search.")
        #expect(!state.showsCreateAction)
    }

    // MARK: - Create action truth table

    @Test("The create action shows only for the active segment while not searching",
          arguments: ListSegment.allCases, [false, true])
    func createActionTruthTable(segment: ListSegment, isSearching: Bool) {
        let state = makeSUT(segment, isSearching: isSearching)
        #expect(state.showsCreateAction == (segment == .active && !isSearching))
    }

    @Test("The empty copy differs between the two segments when not searching")
    func segmentsHaveDistinctCopy() {
        let active = makeSUT(.active)
        let archived = makeSUT(.archived)
        #expect(active.emptyTitle != archived.emptyTitle)
        #expect(active.emptyMessage != archived.emptyMessage)
    }
}
