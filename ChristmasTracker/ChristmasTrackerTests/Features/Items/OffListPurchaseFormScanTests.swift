//
//  OffListPurchaseFormScanTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O2: source scans for the Add Item form's "I already bought this" choice.
//
//   - the toggle text lives in one file (OffListPurchaseToggleSection.swift) used by AddItemView only;
//   - no purchase logic is copied: the purchase happens only through RecordPurchaseContent;
//   - the model is built with the starting input; all four finishes are handled and the refresh runs;
//   - a second create is impossible in code (OffListPurchaseStep, beginCreate);
//   - the new files do not log and do not interpolate a price, total or name;
//   - size limits and design tokens; ChristmasTrackerApp.swift is untouched.
//
//  A missing file is a failed expectation, never a pass over nothing.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase form scan Tests")
struct OffListPurchaseFormScanTests {

    private typealias Scan = PurchaseScreenScan

    private static let togglePath = "Features/Items/Components/OffListPurchaseToggleSection.swift"
    private static let addPath = "Features/Items/Views/AddItemView.swift"
    private static let editPath = "Features/Items/Views/EditItemView.swift"
    private static let detailPath = "Features/Items/Views/ItemDetailView.swift"
    private static let appPath = "App/ChristmasTrackerApp.swift"
    private static let literal = "I already bought this"

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func source(_ path: String, file: String = #filePath) throws -> ScreenSource {
        try #require(Scan.load(path, tree: try tree(file: file)), "\(path) is missing")
    }

    /// The new or touched files of this feature: toggle, AddItemView and every Features/Items file named
    /// OffListPurchase* or AddItem*.
    private func featureFiles(file: String = #filePath) throws -> [ScreenSource] {
        let tree = try tree(file: file)
        var byPath: [String: ScreenSource] = [:]
        for path in [Self.togglePath, Self.addPath] {
            if let loaded = Scan.load(path, tree: tree) { byPath[path] = loaded }
        }
        for prefix in ["OffListPurchase", "AddItem"] {
            for found in Scan.files(in: "Features/Items/", prefix: prefix, tree: tree) { byPath[found.path] = found }
        }
        return byPath.values.sorted { $0.path < $1.path }
    }

    // MARK: a. Built in one place

    @Test("The toggle literal appears only in OffListPurchaseToggleSection.swift")
    func literalInOneFile() throws {
        let tree = try tree()
        _ = try source(Self.togglePath)
        let holders = tree.all.compactMap { url -> String? in
            let relative = tree.relativePath(url)
            guard let loaded = Scan.load(relative, tree: tree), loaded.code.contains(Self.literal) else { return nil }
            return relative
        }
        #expect(holders == [Self.togglePath], "Found in: \(holders)")
    }

    @Test("The toggle section carries its footer and accessibility hint")
    func toggleTexts() throws {
        let toggle = try source(Self.togglePath)
        #expect(toggle.code.contains("struct OffListPurchaseToggleSection"))
        #expect(toggle.code.contains("You'll review the purchase next. It needs a price."))
        #expect(toggle.code.contains("Opens the purchase form after you add the item"))
    }

    @Test("AddItemView uses the toggle section; Edit and Detail never do")
    func toggleOnlyInAdd() throws {
        #expect(try source(Self.addPath).code.contains("OffListPurchaseToggleSection("))
        for path in [Self.editPath, Self.detailPath] {
            let other = try source(path)
            #expect(!other.code.contains("OffListPurchaseToggleSection"), "\(path)")
            #expect(!other.code.contains(Self.literal), "\(path)")
        }
    }

    // MARK: b. No purchase logic copied

    @Test("The feature files never touch the purchase service, repository, draft or token")
    func noPurchaseLogic() throws {
        let files = try featureFiles()
        _ = try source(Self.togglePath)
        let forbidden = ["PurchaseService", "purchaseService", "PurchaseRepositor", "recordPurchase(",
                         "PurchaseDraft(", "confirmationToken"]
        var found: [(String, [String])] = []
        for file in files {
            let hits = forbidden.filter { file.bare.contains($0) }
            if !hits.isEmpty { found.append((file.path, hits)) }
        }
        #expect(found.isEmpty, "Unexpected:\n\(Scan.describe(found))")
    }

    @Test("The purchase happens only through RecordPurchaseContent")
    func usesRecordPurchaseContent() throws {
        #expect(try source(Self.addPath).code.contains("RecordPurchaseContent("))
    }

    // MARK: c. Starting input

    @Test("The model is built with the starting input")
    func startingInput() throws {
        let files = try featureFiles()
        #expect(files.contains { $0.code.contains("startingInput:") }, "No feature file passes startingInput:")
    }

    // MARK: d. Finishes and refresh

    @Test("AddItemView handles all four finishes and runs the shared refresh")
    func addHandlesFinishes() throws {
        let add = try source(Self.addPath)
        for marker in [".recorded", ".itemGone", ".cancelled", ".checkItem", "runAfterPurchase("] {
            #expect(add.code.contains(marker), "AddItemView is missing \(marker)")
        }
    }

    @Test("ItemDetailView refreshes through the runner method")
    func detailUsesRunnerMethod() throws {
        let detail = try source(Self.detailPath)
        #expect(detail.code.contains("runAfterPurchase(itemId:"))
        if let body = ItemSourceScan.braceBody(after: "func refreshAfterPurchase", in: detail.bare) {
            #expect(!body.contains("PurchaseRefreshPlan.steps("), "the plan is built in the runner method only")
        }
    }

    // MARK: e. Second create impossible

    @Test("The second create is impossible in code")
    func secondCreateGuarded() throws {
        let add = try source(Self.addPath)
        #expect(add.code.contains("OffListPurchaseStep"))
        #expect(add.code.contains("beginCreate()"))
    }

    // MARK: f. Privacy

    private static let loggingPatterns = [
        #"\bLog[A-Za-z]*\s*\("#, #"\bprint\s*\("#, #"\bdebugPrint\s*\("#,
        #"\bLogger\b"#, #"\bos_log\b"#, #"\bNSLog\b"#, #"\bSentrySDK\b"#
    ]
    private static let interpolationPattern = #"\\\([^)]*(?i:price|total|cost|name|cents|amount)[^)]*\)"#

    @Test("The feature files have no logging and no price, total or name interpolation")
    func quiet() throws {
        let files = try featureFiles()
        _ = try source(Self.togglePath)
        var found: [String] = []
        for file in files {
            for pattern in Self.loggingPatterns
            where !(try ItemSourceScan.matchingLines(pattern, in: file.code)).isEmpty {
                found.append("\(file.path): logging matching \(pattern)")
            }
            if !(try ItemSourceScan.matchingLines(Self.interpolationPattern, in: file.code)).isEmpty {
                found.append("\(file.path): interpolation of a price, total or name")
            }
        }
        #expect(found.isEmpty, "Unexpected:\n\(found.joined(separator: "\n"))")
    }

    // MARK: g. Size and tokens

    @Test("The two view files stay short")
    func sizes() throws {
        for path in [Self.addPath, Self.togglePath] {
            let tree = try tree()
            let raw = try #require(tree.source(path), "\(path) is missing")
            let lines = raw.components(separatedBy: "\n")
            #expect(lines.count < 400, "\(path) has \(lines.count) lines")
            let long = lines.enumerated().filter { $0.element.count > 120 }.map { $0.offset + 1 }
            #expect(long.isEmpty, "\(path) lines over 120 characters: \(long)")
        }
    }

    @Test("The toggle section uses design tokens: no raw color, numeric spacing or system font")
    func tokensOnly() throws {
        let toggle = try source(Self.togglePath)
        for pattern in [#"\bColor\("#, #"\.padding\([^)]*\d"#, #"\.font\(\.system"#] {
            #expect(try ItemSourceScan.matchingLines(pattern, in: toggle.bare).isEmpty, "matched \(pattern)")
        }
    }

    // MARK: h. App file untouched

    @Test("ChristmasTrackerApp.swift is not touched by this feature")
    func appUntouched() throws {
        let tree = try tree()
        let url = try #require(tree.all.first { $0.lastPathComponent == "ChristmasTrackerApp.swift" },
                               "ChristmasTrackerApp.swift is missing")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("OffListPurchase"))
    }
}
