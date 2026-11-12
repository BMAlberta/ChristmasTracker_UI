//
//  ListSegmentTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: ListSegment, the Active | Archived choice on the lists screen. Truth table over
//  every list status times every segment. Fake data only.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List segment Tests")
struct ListSegmentTests {

    private static let allStatuses: [ListStatus] = [.draft, .active, .archived]

    /// The oracle, written from the decision: Active shows ACTIVE and DRAFT, Archived shows ARCHIVED.
    private static func expectedInclusion(_ segment: ListSegment, _ status: ListStatus) -> Bool {
        switch segment {
        case .active: return status == .active || status == .draft
        case .archived: return status == .archived
        }
    }

    @Test("There are exactly two segments, active first")
    func caseList() {
        #expect(ListSegment.allCases == [.active, .archived])
    }

    @Test("The raw values are the lowercase case names")
    func rawValues() {
        #expect(ListSegment.active.rawValue == "active")
        #expect(ListSegment.archived.rawValue == "archived")
    }

    @Test("The titles are Active and Archived")
    func titles() {
        #expect(ListSegment.active.title == "Active")
        #expect(ListSegment.archived.title == "Archived")
    }

    @Test("includes(_:) is the status-by-segment truth table", arguments: ListSegment.allCases, ListSegmentTests.allStatuses)
    func includesTruthTable(segment: ListSegment, status: ListStatus) {
        #expect(segment.includes(status) == Self.expectedInclusion(segment, status))
    }

    @Test("Every status belongs to exactly one segment", arguments: ListSegmentTests.allStatuses)
    func everyStatusInExactlyOneSegment(status: ListStatus) {
        let owners = ListSegment.allCases.filter { $0.includes(status) }
        #expect(owners.count == 1)
    }

    @Test("DRAFT counts as active, never as archived")
    func draftIsActive() {
        #expect(ListSegment.active.includes(.draft))
        #expect(!ListSegment.archived.includes(.draft))
    }
}
