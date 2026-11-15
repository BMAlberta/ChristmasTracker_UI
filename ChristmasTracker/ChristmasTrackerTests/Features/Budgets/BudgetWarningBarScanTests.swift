//
//  BudgetWarningBarScanTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P2: the near-limit bar fill uses `budgetWarningBar`; `budgetWarning` is not used by any view.
//  Comments are stripped before matching.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Budget warning bar scan")
struct BudgetWarningBarScanTests {

    /// Files that may name the bar token or its Color accessor: the table, the accessors, the
    /// token-to-Color mapping and the budget style.
    private static let barAllowlist: Set<String> = [
        "DesignSystem/Colors/ThemeTokenTable.swift",
        "DesignSystem/Colors/AppColors.swift",
        "Features/Items/Components/ItemStatusStyle.swift",
        "Features/Budgets/ViewState/BudgetStateStyle.swift"
    ]

    /// Files that may name `budgetWarningColor` or the `.budgetWarning` token: the table, the
    /// accessors and the token-to-Color mapping. No view file.
    private static let warningAllowlist: Set<String> = [
        "DesignSystem/Colors/ThemeTokenTable.swift",
        "DesignSystem/Colors/AppColors.swift",
        "Features/Items/Components/ItemStatusStyle.swift"
    ]

    private func tree() throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
    }

    private func offenders(pattern: String, allowed: Set<String>, in tree: ItemSourceTree) throws -> [String] {
        var result: [String] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard !allowed.contains(relative) else { continue }
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try ItemSourceScan.matchingLines(pattern, in: source) {
                result.append("\(relative):\(line)")
            }
        }
        return result
    }

    @Test func nearLimitUsesTheBarTokenAndTheOtherLevelsAreUnchanged() {
        #expect(BudgetStateStyle.style(for: .nearLimit).token == .budgetWarningBar)
        #expect(BudgetStateStyle.style(for: .under).token == .budgetSafe)
        #expect(BudgetStateStyle.style(for: .over).token == .budgetOver)
    }

    @Test func theBarTokenIsUsedOnlyOnTheBarPath() throws {
        let found = try offenders(pattern: #"budgetWarningBar"#, allowed: Self.barAllowlist, in: try tree())
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test func budgetWarningIsReferencedByNoViewFile() throws {
        let found = try offenders(
            pattern: #"budgetWarningColor|\.budgetWarning\b"#, allowed: Self.warningAllowlist, in: try tree()
        )
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test func theBudgetBarColorComesFromTheStyleToken() throws {
        let tree = try tree()
        let mapping = try #require(tree.source("Features/Items/Components/ItemStatusStyle.swift"))
        #expect(ItemSourceScan.codeOnly(mapping).contains("BudgetStateStyle.style(for: level).token"))
    }
}
