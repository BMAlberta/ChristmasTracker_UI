//
//  PurchaseHistoryModelSourceScanTests.swift
//  ChristmasTrackerTests
//
//  PH1-H2: the model files log nothing, use no SwiftUI, AnyView, Combine, GCD, force unwrap or as!,
//  and stay inside the size limits. Needs the checkout on disk (scripts/test.sh has it). Forbidden
//  literals are built by concatenation so this file never contains them.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history model source scan", .timeLimit(.minutes(1)))
struct PurchaseHistoryModelSourceScanTests {

    private func modelFiles() throws -> (tree: ItemSourceTree, files: [URL]) {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let files = tree.all.filter {
            let relative = tree.relativePath($0)
            return relative.hasPrefix("Features/PurchaseHistory/ViewState/")
                || relative == "Features/PurchaseHistory/Domain/PurchaseHistoryRecipient.swift"
        }
        return (tree, files)
    }

    @Test("The model files exist")
    func filesExist() throws {
        let (tree, files) = try modelFiles()
        let names = files.map { tree.relativePath($0) }

        #expect(names.contains("Features/PurchaseHistory/ViewState/PurchaseHistoryModel.swift"))
        #expect(names.contains("Features/PurchaseHistory/Domain/PurchaseHistoryRecipient.swift"))
    }

    @Test("The model files call no log, no Sentry and no print")
    func logsNothing() throws {
        let (tree, files) = try modelFiles()
        var found: [String] = []
        for url in files {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for word in ["Log" + "Debug(", "Log" + "Info(", "Log" + "Error(", "Log" + "Warning(", "Sentry", "addBreadcrumb"]
            where code.contains(word) {
                found.append("\(tree.relativePath(url)): \(word)")
            }
            for hit in try PurchaseHistoryScanRules.printViolations(in: code) { found.append("\(tree.relativePath(url)): \(hit)") }
        }
        #expect(found.isEmpty, "The model logs nothing:\n\(found.joined(separator: "\n"))")
    }

    @Test("No SwiftUI, AnyView, Combine, GCD, force unwrap or as! in the model files")
    func noForbiddenConstructs() throws {
        let (tree, files) = try modelFiles()
        var found: [String] = []
        for url in files {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for word in ["import " + "SwiftUI", "Any" + "View"] where code.contains(word) {
                found.append("\(tree.relativePath(url)): \(word)")
            }
            let bare = RecordPurchaseViewRules.bare(code)
            let hits = RecordPurchaseViewRules.combineAndDispatchViolations(inBare: bare)
                + RecordPurchaseViewRules.forceUnwrapViolations(inBare: bare)
                + (try PurchaseHistoryScanRules.asBangViolations(in: bare))
            for hit in hits { found.append("\(tree.relativePath(url)): \(hit)") }
        }
        #expect(found.isEmpty, "Forbidden constructs:\n\(found.joined(separator: "\n"))")
    }

    @Test("Every model file is under 400 lines")
    func fileSize() throws {
        let (tree, files) = try modelFiles()
        for url in files {
            let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).count
            #expect(lines < 400, "\(tree.relativePath(url)) has \(lines) lines")
        }
    }
}
