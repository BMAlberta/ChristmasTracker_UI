//
//  BudgetViewScanSources.swift
//  ChristmasTrackerTests
//
//  I5a Story C: finds the new view and model source files for the scan tests. The source root is found
//  from #filePath (ItemSourceTree), the way the other scan tests do. The view files are every Swift file
//  under the two Views folders; the model files are the three named ones. A required file that does not
//  exist is reported by the tests, not skipped.
//

import Foundation

nonisolated struct ScannedSource: Sendable {
    let path: String
    let raw: String
    /// Comments stripped, string contents intact.
    let code: String
    /// Comments stripped and string contents blanked.
    let bare: String

    var fileName: String { (path as NSString).lastPathComponent }
}

nonisolated enum BudgetViewSources {

    static let viewFolders: [String] = ["Features/Statistics/Views/", "Features/Budgets/Views/"]

    static let requiredViews: [String] = [
        "Features/Statistics/Views/StatsView.swift",
        "Features/Statistics/Views/StatsSummaryCardView.swift",
        "Features/Statistics/Views/BudgetCardView.swift",
        "Features/Statistics/Views/BudgetCardMenu.swift",
        "Features/Statistics/Views/SpendByPersonView.swift",
        "Features/Budgets/Views/BudgetEditorView.swift",
        "Features/Budgets/Views/DuplicateBudgetView.swift"
    ]

    static let requiredModels: [String] = [
        "Features/Statistics/ViewState/StatsScreenModel.swift",
        "Features/Budgets/ViewState/BudgetEditorModel.swift",
        "Features/Budgets/ViewState/DuplicateBudgetModel.swift"
    ]

    static let menuFile = "Features/Statistics/Views/BudgetCardMenu.swift"
    static let statsViewFile = "Features/Statistics/Views/StatsView.swift"
    static let editorViewFile = "Features/Budgets/Views/BudgetEditorView.swift"
    static let duplicateViewFile = "Features/Budgets/Views/DuplicateBudgetView.swift"

    static func make(path: String, raw: String) -> ScannedSource {
        let code = ItemSourceScan.codeOnly(raw)
        return ScannedSource(path: path, raw: raw, code: code, bare: RecordPurchaseViewRules.bare(code))
    }

    /// Every view file, found by folder (so an extra file such as a year picker is scanned too).
    static func views(from file: String) -> [ScannedSource]? {
        guard let tree = ItemSourceTree.load(from: file) else { return nil }
        var result: [ScannedSource] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard viewFolders.contains(where: { relative.hasPrefix($0) }),
                  let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            result.append(make(path: relative, raw: raw))
        }
        return result
    }

    /// The three model files that exist.
    static func models(from file: String) -> [ScannedSource]? {
        guard let tree = ItemSourceTree.load(from: file) else { return nil }
        return requiredModels.compactMap { relative in
            tree.source(relative).map { make(path: relative, raw: $0) }
        }
    }

    /// The required files that do not exist.
    static func missingFiles(from file: String) -> [String]? {
        guard let tree = ItemSourceTree.load(from: file) else { return nil }
        return (requiredViews + requiredModels).filter { !tree.exists($0) }
    }
}
