//
//  PurchaseLogHygieneScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-D: log hygiene for the whole Features/Purchases folder. Every `Log*(` call there
//  (LogDebug, LogInfo, LogWarning, LogError, ...) takes a plain string literal as its message and
//  that literal interpolates nothing. An id, a name, an amount, a note, a tracking number or a raw
//  error can only reach a log through an interpolation or a non-literal message, so both are
//  forbidden. The static lines in PurchaseService are the allowed kind.
//
//  Calls are read across line breaks (the text from the opening parenthesis to its matching one).
//  Comments are stripped first. The scanner is proven on in-memory strings before it runs on disk.
//

import Testing
import Foundation
@testable import ChristmasTracker

nonisolated enum PurchaseLogScan {

    struct Call: Equatable {
        let line: Int
        let text: String
    }

    /// Every `Log*(...)` call in `code`, with the text between its parentheses.
    static func calls(in code: String) throws -> [Call] {
        let regex = try NSRegularExpression(pattern: #"\bLog[A-Za-z]*\("#)
        var result: [Call] = []
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
            let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
            result.append(Call(line: line, text: text))
        }
        return result
    }

    /// Short descriptions of every call that is not a static string literal.
    static func violations(in code: String) throws -> [String] {
        var found: [String] = []
        for call in try calls(in: code) {
            let trimmed = call.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.hasPrefix("\"") {
                found.append("log message is not a string literal at line \(call.line)")
            }
            if call.text.contains("\\(") {
                found.append("log call interpolates a value at line \(call.line)")
            }
        }
        return found
    }
}

@Suite("Purchase log hygiene scan Tests")
struct PurchaseLogHygieneScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner self-proofs

    @Test("The log scanner fires on interpolated ids, names, amounts, notes, tracking numbers and errors", arguments: [
        #"LogDebug("Fetching purchases for item \(itemId)", category: .business)"#,
        #"LogInfo("Created purchase \(purchase.id)", category: .business)"#,
        #"LogInfo("Paid \(totalCost)", category: .business)"#,
        #"LogInfo("Note \(notes)", category: .business)"#,
        #"LogInfo("Tracking \(trackingNumber)", category: .business)"#,
        #"LogError("Mock error: \(error)")"#,
        #"LogError("failed: \(String(describing: error))", category: .business)"#,
        #"LogWarning("store \(store)", category: .business)"#,
        "LogInfo(\n    \"split across lines \\(itemName)\",\n    category: .business\n)"
    ])
    func scannerFires(source: String) throws {
        #expect(!(try PurchaseLogScan.violations(in: code(source))).isEmpty, "\(source)")
    }

    @Test("The log scanner fires when the message is not a string literal", arguments: [
        "LogError(message, category: .business)",
        "LogInfo(String(describing: purchase))",
        "LogDebug(error.localizedDescription)"
    ])
    func scannerFiresOnNonLiteral(source: String) throws {
        #expect(!(try PurchaseLogScan.violations(in: code(source))).isEmpty, "\(source)")
    }

    @Test("The log scanner allows static strings, comments and look-alike names", arguments: [
        #"LogError("record purchase failed", category: .business)"#,
        #"LogError("purchase management failed", category: .business)"#,
        #"LogInfo("Purchase requires confirmation (budget warning)", category: .business)"#,
        "LogInfo(\n    \"split across lines\",\n    category: .business\n)",
        #"// LogInfo("Created purchase \(purchase.id)")"#,
        "/* LogError(\"x \\(error)\") */",
        "let blogPost = 1",
        "let catalog = makeCatalog(for: item)"
    ])
    func scannerAllows(source: String) throws {
        #expect(try PurchaseLogScan.violations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("The log scanner finds each call, its line, and reads past parentheses inside the message")
    func scannerReadsCalls() throws {
        let source = "let a = 1\nLogInfo(\"one (two)\")\nlet b = 2\nLogError(\"three\", category: .business)"
        let calls = try PurchaseLogScan.calls(in: source)
        #expect(calls.map(\.line) == [2, 4])
        #expect(calls.first?.text == "\"one (two)\"")
    }

    // MARK: Real sources

    @Test("No log call anywhere in Features/Purchases interpolates a value or logs a non-literal message")
    func purchasesLogOnlyStaticStrings() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let purchaseFiles = tree.all.filter { tree.relativePath($0).hasPrefix("Features/Purchases/") }
        #expect(purchaseFiles.count > 10)
        var found: [String] = []
        for url in purchaseFiles {
            let stripped = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for violation in try PurchaseLogScan.violations(in: stripped) {
                found.append("\(tree.relativePath(url)): \(violation)")
            }
        }
        #expect(found.isEmpty, "Purchase log calls must be static strings:\n\(found.joined(separator: "\n"))")
    }

    @Test("PurchaseService still has its static log lines, so the scan is not vacuous")
    func serviceStaticLinesExist() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let source = try #require(tree.source("Features/Purchases/Services/PurchaseService.swift"))
        let calls = try PurchaseLogScan.calls(in: ItemSourceScan.codeOnly(source))
        #expect(calls.count == 2, "PurchaseService has exactly its two static log lines, found \(calls.count)")
        #expect(try PurchaseLogScan.violations(in: ItemSourceScan.codeOnly(source)).isEmpty)
    }
}
