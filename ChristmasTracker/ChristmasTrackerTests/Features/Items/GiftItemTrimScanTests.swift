//
//  GiftItemTrimScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D: GiftItem no longer has the computed members isAvailable, isPurchased and
//  canEdit (only the old item screens used them). A removed member cannot be tested by compile,
//  so this scans GiftItem.swift (comments ignored) for the three names.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("GiftItem trim scan Tests")
struct GiftItemTrimScanTests {

    private let removed = ["isAvailable", "isPurchased", "canEdit"]

    @Test("The scanner finds a member name and ignores comments")
    func scannerSelfCheck() throws {
        let pattern = #"\b(isAvailable|isPurchased|canEdit)\b"#
        #expect(try ItemSourceScan.matchingLines(pattern, in: "var isPurchased: Bool { true }").count == 1)
        #expect(try ItemSourceScan.matchingLines(pattern, in: ItemSourceScan.codeOnly("// canEdit\nlet a = 1")).isEmpty)
        #expect(try ItemSourceScan.matchingLines(pattern, in: "var canEditList: Bool").isEmpty)
    }

    @Test("GiftItem.swift declares none of isAvailable, isPurchased, canEdit", arguments: ["isAvailable", "isPurchased", "canEdit"])
    func memberRemoved(name: String) throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let raw = try #require(tree.source("Core/Models/GiftItem.swift"), "GiftItem.swift not found")
        let code = ItemSourceScan.codeOnly(raw)
        let lines = try ItemSourceScan.matchingLines("\\b\(name)\\b", in: code)
        #expect(lines.isEmpty, "GiftItem.swift still names \(name) on lines \(lines)")
    }
}
