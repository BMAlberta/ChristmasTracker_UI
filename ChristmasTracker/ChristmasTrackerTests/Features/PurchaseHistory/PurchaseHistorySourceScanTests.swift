//
//  PurchaseHistorySourceScanTests.swift
//  ChristmasTrackerTests
//
//  PH1-H1 AC8: source scan over every file under Features/PurchaseHistory/ and the new environment file.
//   - no Log*/print/os_log/Sentry breadcrumb or span-data call interpolates a value (an id, an amount, a
//     name, a cursor, an error), and no print/os_log/NSLog is used at all;
//   - no Combine, no DispatchQueue (and other GCD), no force unwrap, no `as!`.
//
//  The scanners are proven on in-memory strings before they run on disk. Comments are stripped first.
//  Needs the checkout on disk (scripts/test.sh has it).
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum PurchaseHistoryScanRules {

    /// Calls that can carry data to a log or to Sentry, with the text between their parentheses.
    private static let dataCallPattern =
        #"\b(Log[A-Za-z]*|setData|setExtra|setTag|addBreadcrumb|Breadcrumb|capture(Error|Message|Exception)?|startTransaction|startChild)\("#

    static func interpolatingCalls(in code: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: dataCallPattern)
        var found: [String] = []
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let range = Range(match.range, in: code) else { continue }
            var depth = 1
            var index = range.upperBound
            while index < code.endIndex && depth > 0 {
                if code[index] == "(" { depth += 1 }
                if code[index] == ")" { depth -= 1 }
                if depth > 0 { index = code.index(after: index) }
            }
            let text = String(code[range.upperBound..<index])
            if text.contains("\\(") {
                let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
                found.append("\(code[range].dropLast()) interpolates a value at line \(line)")
            }
        }
        return found
    }

    static func printViolations(in code: String) throws -> [String] {
        try ItemSourceScan.matchingLines(#"\b(print|NSLog|os_log|debugPrint|dump)\("#, in: code)
            .map { "print-style call at line \($0)" }
    }

    static func asBangViolations(in bare: String) throws -> [String] {
        try ItemSourceScan.matchingLines(#"\bas!"#, in: bare).map { "as! at line \($0)" }
    }
}

@Suite("Purchase history source scan", .timeLimit(.minutes(1)))
struct PurchaseHistorySourceScanTests {

    // MARK: Scanner self-proofs

    @Test("The interpolation scanner fires on ids, amounts, names, cursors and errors in logs and Sentry data", arguments: [
        #"LogDebug("Loading history for \(recipientId)", category: .business)"#,
        #"LogError("failed: \(error)", category: .business)"#,
        #"LogInfo("cursor \(cursor)")"#,
        #"span.setData(value: "\(row.totalCost)", key: "total")"#,
        #"SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: "x \(itemName)"))"#,
        "LogInfo(\n    \"split \\(itemName)\",\n    category: .business\n)"
    ])
    func interpolationScannerFires(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(try PurchaseHistoryScanRules.interpolatingCalls(in: code).isEmpty == false, "\(source)")
    }

    @Test("The interpolation scanner allows static strings and comments", arguments: [
        #"LogError("purchase history failed", category: .business)"#,
        #"let span = SentrySDK.startTransaction(name: "purchase-history.loadPage", operation: "service")"#,
        #"// LogInfo("Created \(purchase.id)")"#,
        "let catalog = makeCatalog(for: item)"
    ])
    func interpolationScannerAllows(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(try PurchaseHistoryScanRules.interpolatingCalls(in: code).isEmpty, "\(source)")
    }

    @Test("The print scanner fires on print, NSLog and os_log", arguments: [
        #"print("x")"#, #"NSLog("x")"#, #"os_log("x")"#, #"debugPrint(row)"#
    ])
    func printScannerFires(source: String) throws {
        #expect(try PurchaseHistoryScanRules.printViolations(in: source).isEmpty == false)
    }

    @Test("The force unwrap and as! scanners fire on unsafe code and allow safe code")
    func unsafeScanners() throws {
        let unsafe = RecordPurchaseViewRules.bare("let a = value!\nlet b = x as! Int\nlet c = try! load()")
        let safe = RecordPurchaseViewRules.bare("let a = value ?? 0\nif !flag { return }\nif a != b { return }")

        #expect(RecordPurchaseViewRules.forceUnwrapViolations(inBare: unsafe).isEmpty == false)
        #expect(try PurchaseHistoryScanRules.asBangViolations(in: unsafe).isEmpty == false)
        #expect(RecordPurchaseViewRules.forceUnwrapViolations(inBare: safe).isEmpty)
        #expect(try PurchaseHistoryScanRules.asBangViolations(in: safe).isEmpty)
    }

    @Test("The Combine and GCD scanner fires on imports and queues")
    func gcdScannerFires() {
        #expect(RecordPurchaseViewRules.combineAndDispatchViolations(inBare: "import Combine").isEmpty == false)
        #expect(RecordPurchaseViewRules.combineAndDispatchViolations(inBare: "DispatchQueue.main.async {}").isEmpty == false)
        #expect(RecordPurchaseViewRules.combineAndDispatchViolations(inBare: "let x = 1").isEmpty)
    }

    // MARK: Real sources

    private func newFiles() throws -> (tree: ItemSourceTree, files: [URL]) {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let files = tree.all.filter {
            let relative = tree.relativePath($0)
            return relative.hasPrefix("Features/PurchaseHistory/")
                || relative == "Core/Extensions/EnvironmentValues+PurchaseHistoryService.swift"
        }
        return (tree, files)
    }

    @Test("The new files exist: the data layer is not empty, so the scans are not vacuous")
    func newFilesExist() throws {
        let (tree, files) = try newFiles()
        let names = Set(files.map { tree.relativePath($0) })

        #expect(files.count >= 10, "found \(files.count) new files")
        for expected in [
            "Core/Extensions/EnvironmentValues+PurchaseHistoryService.swift",
            "Features/PurchaseHistory/Repositories/GeneratedClientPurchaseHistoryRepository.swift",
            "Features/PurchaseHistory/Repositories/MockPurchaseHistoryRepository.swift",
            "Features/PurchaseHistory/Services/PurchaseHistoryService.swift"
        ] {
            #expect(names.contains(expected), "missing \(expected)")
        }
    }

    @Test("No log, print or Sentry data call in the new files interpolates a value or prints anything")
    func noSensitiveLogging() throws {
        let (tree, files) = try newFiles()
        var found: [String] = []
        for url in files {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for hit in try PurchaseHistoryScanRules.interpolatingCalls(in: code) { found.append("\(tree.relativePath(url)): \(hit)") }
            for hit in try PurchaseLogScan.violations(in: code) { found.append("\(tree.relativePath(url)): \(hit)") }
            for hit in try PurchaseHistoryScanRules.printViolations(in: code) { found.append("\(tree.relativePath(url)): \(hit)") }
        }
        #expect(found.isEmpty, "Nothing sensitive may reach a log or Sentry:\n\(found.joined(separator: "\n"))")
    }

    @Test("No Combine, no GCD, no force unwrap and no as! in the new files")
    func noUnsafeConstructs() throws {
        let (tree, files) = try newFiles()
        var found: [String] = []
        for url in files {
            let bare = RecordPurchaseViewRules.bare(ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8)))
            let hits = RecordPurchaseViewRules.combineAndDispatchViolations(inBare: bare)
                + RecordPurchaseViewRules.forceUnwrapViolations(inBare: bare)
                + (try PurchaseHistoryScanRules.asBangViolations(in: bare))
            for hit in hits { found.append("\(tree.relativePath(url)): \(hit)") }
        }
        #expect(found.isEmpty, "Unsafe constructs in new files:\n\(found.joined(separator: "\n"))")
    }

    @Test("The repository method is instrumented")
    func repositoryIsInstrumented() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let raw = try #require(tree.source("Features/PurchaseHistory/Repositories/GeneratedClientPurchaseHistoryRepository.swift"))
        let code = ItemSourceScan.codeOnly(raw)

        #expect(code.contains("@Instrumented"))
    }
}
