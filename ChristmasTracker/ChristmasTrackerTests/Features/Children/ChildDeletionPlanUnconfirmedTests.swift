//
//  ChildDeletionPlanUnconfirmedTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B5: OLD behavior: Try Again always continued without a new dialog, whatever the
//  recomputed plan archived. NEW: a plan that would archive a list the user never confirmed is
//  "unconfirmed". The pure comparison lives on ChildDeletionPlan. Fake ids only.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ChildDeletionPlan unconfirmed lists Tests")
struct ChildDeletionPlanUnconfirmedTests {

    private func archive(_ ids: String...) -> ChildDeletionPlan {
        .archiveThenDelete(listIds: ids)
    }

    // MARK: - archiveListIds

    @Test("OLD: Try Again always continued without a new dialog; archiveListIds returns the ids in order")
    func archiveListIdsInOrder() {
        #expect(archive("list-2", "list-1", "list-3").archiveListIds == ["list-2", "list-1", "list-3"])
    }

    @Test("OLD: Try Again always continued without a new dialog; deleteNow and blocked have no archive ids")
    func archiveListIdsEmpty() {
        #expect(ChildDeletionPlan.deleteNow.archiveListIds.isEmpty)
        #expect(ChildDeletionPlan.blocked.archiveListIds.isEmpty)
        #expect(ChildDeletionPlan.archiveThenDelete(listIds: []).archiveListIds.isEmpty)
    }

    // MARK: - hasUnconfirmedLists

    @Test("OLD: Try Again always continued without a new dialog; a subset of the confirmed lists is confirmed")
    func subsetIsConfirmed() {
        let confirmed = archive("list-1", "list-2", "list-3")
        #expect(archive("list-1", "list-3").hasUnconfirmedLists(comparedTo: confirmed) == false)
        #expect(archive("list-2").hasUnconfirmedLists(comparedTo: confirmed) == false)
    }

    @Test("OLD: Try Again always continued without a new dialog; an equal set is confirmed")
    func equalIsConfirmed() {
        let confirmed = archive("list-1", "list-2")
        #expect(archive("list-1", "list-2").hasUnconfirmedLists(comparedTo: confirmed) == false)
    }

    @Test("OLD: Try Again always continued without a new dialog; a superset has an unconfirmed list")
    func supersetIsUnconfirmed() {
        let confirmed = archive("list-1", "list-2")
        #expect(archive("list-1", "list-2", "list-3").hasUnconfirmedLists(comparedTo: confirmed))
    }

    @Test("OLD: Try Again always continued without a new dialog; a disjoint set is unconfirmed")
    func disjointIsUnconfirmed() {
        let confirmed = archive("list-1", "list-2")
        #expect(archive("list-8", "list-9").hasUnconfirmedLists(comparedTo: confirmed))
    }

    @Test("OLD: Try Again always continued without a new dialog; partial overlap with one new list is unconfirmed")
    func partialOverlapIsUnconfirmed() {
        let confirmed = archive("list-1", "list-2")
        #expect(archive("list-2", "list-7").hasUnconfirmedLists(comparedTo: confirmed))
    }

    @Test("OLD: Try Again always continued without a new dialog; the order of the ids does not matter")
    func orderInsensitive() {
        let confirmed = archive("list-1", "list-2", "list-3")
        #expect(archive("list-3", "list-1", "list-2").hasUnconfirmedLists(comparedTo: confirmed) == false)
        #expect(archive("list-3", "list-2").hasUnconfirmedLists(comparedTo: confirmed) == false)
        #expect(archive("list-3", "list-4", "list-1").hasUnconfirmedLists(comparedTo: confirmed))
    }

    @Test("OLD: Try Again always continued without a new dialog; empty plan against a non-empty confirmed plan is confirmed")
    func emptyAgainstNonEmpty() {
        let confirmed = archive("list-1")
        #expect(ChildDeletionPlan.archiveThenDelete(listIds: []).hasUnconfirmedLists(comparedTo: confirmed) == false)
    }

    @Test("OLD: Try Again always continued without a new dialog; a non-empty plan against an empty confirmed plan is unconfirmed")
    func nonEmptyAgainstEmpty() {
        let confirmed = ChildDeletionPlan.archiveThenDelete(listIds: [])
        #expect(archive("list-1").hasUnconfirmedLists(comparedTo: confirmed))
    }

    @Test("OLD: Try Again always continued without a new dialog; deleteNow never has unconfirmed lists")
    func deleteNowIsConfirmed() {
        #expect(ChildDeletionPlan.deleteNow.hasUnconfirmedLists(comparedTo: archive("list-1")) == false)
        #expect(ChildDeletionPlan.deleteNow.hasUnconfirmedLists(comparedTo: .deleteNow) == false)
        #expect(ChildDeletionPlan.deleteNow.hasUnconfirmedLists(comparedTo: .blocked) == false)
    }

    @Test("OLD: Try Again always continued without a new dialog; a blocked plan has no ids so no unconfirmed lists")
    func blockedHasNone() {
        #expect(ChildDeletionPlan.blocked.hasUnconfirmedLists(comparedTo: archive("list-1")) == false)
        #expect(ChildDeletionPlan.blocked.hasUnconfirmedLists(comparedTo: .deleteNow) == false)
    }

    @Test("OLD: Try Again always continued without a new dialog; a confirmed deleteNow or blocked plan confirms no archive list")
    func confirmedWithoutIds() {
        #expect(archive("list-1").hasUnconfirmedLists(comparedTo: .deleteNow))
        #expect(archive("list-1").hasUnconfirmedLists(comparedTo: .blocked))
    }
}
