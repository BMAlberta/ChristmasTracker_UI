//
//  PurchaseTrackingChangeTests.swift
//  ChristmasTrackerTests
//
//  Story I4c-A (decision S15): the truth table of `PurchaseTrackingChange.derive(original:edited:)`.
//  Both sides are trimmed of whitespace and newlines (a nil original is empty). Empty original and
//  empty edit: unchanged. Non-empty original and empty edit: clear. Otherwise equal after trimming
//  is unchanged, else set(trimmed edit). The 100-unit limit is NOT applied here. Case matters.
//
//  These tests pin the PurchaseTrackingChange rules.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase tracking change Tests")
struct PurchaseTrackingChangeTests {

    // MARK: - Fixtures (fake data only)

    private static let units100 = String(repeating: "A", count: 100)
    private static let units101 = String(repeating: "A", count: 101)
    /// 98 units + an emoji (2 UTF-16 units) = exactly 100 units.
    private static let emojiAt100 = String(repeating: "A", count: 98) + "\u{1F600}"
    /// 99 units + an emoji (2 UTF-16 units) = 101 units.
    private static let emojiAt101 = String(repeating: "A", count: 99) + "\u{1F600}"

    /// The edited values, in the order the expected arrays below follow.
    private static let edits: [String] = [
        "", "   ", "\n", "TEST123", "  TEST123 ", "OTHER9", "test123",
        units100, units101, emojiAt100, emojiAt101
    ]

    struct Row: Sendable, CustomTestStringConvertible {
        let original: String?
        let edited: String
        let expected: PurchaseTrackingChange
        var testDescription: String { "original \(String(describing: original)) edited \(edited.count) chars -> \(expected)" }
    }

    private static func rows(original: String?, expected: [PurchaseTrackingChange]) -> [Row] {
        precondition(expected.count == edits.count, "one expected value per edited value")
        return zip(edits, expected).map { Row(original: original, edited: $0, expected: $1) }
    }

    /// An empty original (nil, "" or whitespace-only) can only be unchanged or set.
    private static let expectedForEmptyOriginal: [PurchaseTrackingChange] = [
        .unchanged, .unchanged, .unchanged,
        .set("TEST123"), .set("TEST123"), .set("OTHER9"), .set("test123"),
        .set(units100), .set(units101), .set(emojiAt100), .set(emojiAt101)
    ]

    static let table: [Row] =
        rows(original: nil, expected: expectedForEmptyOriginal)
        + rows(original: "", expected: expectedForEmptyOriginal)
        + rows(original: "   ", expected: expectedForEmptyOriginal)
        + rows(original: "TEST123", expected: [
            .clear, .clear, .clear,
            .unchanged, .unchanged, .set("OTHER9"), .set("test123"),
            .set(units100), .set(units101), .set(emojiAt100), .set(emojiAt101)
        ])

    // MARK: - Truth table

    @Test("derive: the full truth table", arguments: table)
    func truthTable(row: Row) {
        #expect(PurchaseTrackingChange.derive(original: row.original, edited: row.edited) == row.expected)
    }

    // MARK: - Further rows

    @Test("A padded original is compared after trimming")
    func paddedOriginal() {
        #expect(PurchaseTrackingChange.derive(original: "  TEST123 \n", edited: "TEST123") == .unchanged)
        #expect(PurchaseTrackingChange.derive(original: "  TEST123 \n", edited: "") == .clear)
        #expect(PurchaseTrackingChange.derive(original: "  TEST123 \n", edited: "OTHER9") == .set("OTHER9"))
    }

    @Test("Interior whitespace is kept")
    func interiorKept() {
        #expect(PurchaseTrackingChange.derive(original: "A1", edited: " A 1 ") == .set("A 1"))
    }

    @Test("The set value is trimmed on both ends including newlines")
    func setIsTrimmed() {
        #expect(PurchaseTrackingChange.derive(original: nil, edited: "\n\t A1 \n") == .set("A1"))
    }

    @Test("The 100-unit limit is not applied by derive")
    func limitNotApplied() {
        #expect(PurchaseTrackingChange.derive(original: nil, edited: Self.units101) == .set(Self.units101))
    }
}
