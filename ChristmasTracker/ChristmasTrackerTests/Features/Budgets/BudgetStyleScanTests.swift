//
//  BudgetStyleScanTests.swift
//  ChristmasTrackerTests
//
//  TH1-T3: source scans for the budget card. Comments are stripped before matching.
//   5. BudgetCardView takes its colors from the budget style, not from isOver ternaries, and always
//      renders the status words as Text
//   6. the near-limit threshold is declared once; no other file in Features/Budgets or
//      Features/Statistics holds a literal 0.9
//
//  The CreateBudgetButton struct (an unrelated primary action with its own tint) is excluded from the
//  `primaryColor` check; its tint belongs to the T5 button story.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Budget style scans")
struct BudgetStyleScanTests {

    private func tree(_ file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private let cardViewPath = "Features/Statistics/Views/BudgetCardView.swift"

    private func cardViewCode() throws -> String {
        let tree = try tree()
        let source = try #require(tree.source(cardViewPath), "BudgetCardView.swift is missing")
        return ItemSourceScan.codeOnly(source)
    }

    // MARK: 5. BudgetCardView

    @Test func cardViewHasNoDestructiveColor() throws {
        #expect(!(try cardViewCode()).contains("destructiveColor"))
    }

    @Test func cardViewHasNoPrimaryColorOutsideTheCreateButton() throws {
        var source = try cardViewCode()
        if let button = ItemSourceScan.braceBody(after: "struct CreateBudgetButton", in: source) {
            source = source.replacingOccurrences(of: button, with: "")
        }
        let lines = try ItemSourceScan.matchingLines(#"primaryColor"#, in: source)
        #expect(lines.isEmpty, "primaryColor at lines \(lines)")
    }

    @Test func cardViewHasNoIsOverColorTernary() throws {
        let lines = try ItemSourceScan.matchingLines(#"isOver\s*\?"#, in: try cardViewCode())
        #expect(lines.isEmpty, "isOver ternary at lines \(lines)")
    }

    @Test func cardViewUsesTheBudgetStyle() throws {
        let source = try cardViewCode()
        #expect(source.contains("level") || source.contains("BudgetStateStyle"))
    }

    @Test func cardViewAlwaysRendersTheStatusTextAsText() throws {
        let source = try cardViewCode()
        let card = try ItemSourceScan.matchingLines(#"Text\(\s*card\.statusText"#, in: source)
        let row = try ItemSourceScan.matchingLines(#"Text\(\s*row\.statusText"#, in: source)
        #expect(!card.isEmpty, "the card status is not rendered with Text(card.statusText")
        #expect(!row.isEmpty, "the person status is not rendered with Text(row.statusText")
    }

    // MARK: 6. One threshold

    @Test func nearLimitThresholdIsDeclaredInExactlyOneFile() throws {
        let tree = try tree()
        var declaring: [String] = []
        for url in tree.all {
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if source.contains("static let nearLimitThreshold") { declaring.append(tree.relativePath(url)) }
        }
        #expect(declaring.count == 1, "declared in: \(declaring)")
    }

    @Test func noOtherBudgetOrStatisticsFileHoldsALiteralNinetyPercent() throws {
        let tree = try tree()
        var declaring: Set<String> = []
        for url in tree.all {
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if source.contains("static let nearLimitThreshold") { declaring.insert(tree.relativePath(url)) }
        }
        var offenders: [String] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/Budgets/") || relative.hasPrefix("Features/Statistics/") else { continue }
            guard !declaring.contains(relative) else { continue }
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try ItemSourceScan.matchingLines(#"(?<![0-9.])0\.90?(?![0-9])"#, in: source) {
                offenders.append("\(relative):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }
}
