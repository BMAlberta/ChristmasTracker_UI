//
//  OffListPurchaseScanTests.swift
//  ChristmasTrackerTests
//
//  Story OL1-O1: privacy scan of the two new rule files. They contain no logging or reporting
//  calls and no string interpolation of a price, total or name. The scanner is proven on
//  in-memory strings before it runs on disk. A missing file is a failed expectation.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Off-list purchase scan Tests")
struct OffListPurchaseScanTests {

    private static let files = [
        "Features/Items/ViewState/OffListPurchaseOption.swift",
        "Features/Items/ViewState/OffListPurchaseStep.swift"
    ]

    private static let loggingPatterns = [
        #"\bLog[A-Za-z]*\s*\("#,
        #"\bprint\s*\("#,
        #"\bdebugPrint\s*\("#,
        #"\bLogger\b"#,
        #"\bos_log\b"#,
        #"\bNSLog\b"#,
        #"\bSentrySDK\b"#
    ]

    private static let interpolationPattern = #"\\\([^)]*(?i:price|total|cost|name|cents|amount)[^)]*\)"#

    private func violations(in code: String) throws -> [String] {
        var found: [String] = []
        for pattern in Self.loggingPatterns where !(try ItemSourceScan.matchingLines(pattern, in: code)).isEmpty {
            found.append("logging or reporting call matching \(pattern)")
        }
        if !(try ItemSourceScan.matchingLines(Self.interpolationPattern, in: code)).isEmpty {
            found.append("interpolation of a price, total or name")
        }
        return found
    }

    // MARK: Scanner self-proofs

    @Test("The scanner fires on logging and on interpolated price, total and name", arguments: [
        #"LogInfo("Added")"#,
        #"LogError("failed", category: .business)"#,
        #"print("x")"#,
        "let log = Logger(subsystem: \"a\", category: \"b\")",
        "SentrySDK.capture(message: \"x\")",
        #"let s = "Total \(totalText)""#,
        #"let s = "Price \(priceText)""#,
        #"let s = "Item \(item.name)""#
    ])
    func scannerFires(source: String) throws {
        #expect(!(try violations(in: ItemSourceScan.codeOnly(source))).isEmpty, "\(source)")
    }

    @Test("The scanner allows plain rule code and comments", arguments: [
        "let cents = price * quantity",
        "// LogInfo(\"x \\(totalText)\") is only a comment",
        "var totalCents: Int? { nil }",
        "let blogPost = 1"
    ])
    func scannerAllows(source: String) throws {
        #expect(try violations(in: ItemSourceScan.codeOnly(source)).isEmpty, "\(source)")
    }

    // MARK: Real sources

    @Test("The new rule files exist")
    func filesExist() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        for relative in Self.files {
            #expect(tree.exists(relative), "Missing \(relative)")
        }
    }

    @Test("The new rule files have no logging, reporting or sensitive interpolation")
    func rulesAreQuiet() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        var found: [String] = []
        var scanned = 0
        for relative in Self.files {
            guard let source = tree.source(relative) else { continue }
            scanned += 1
            for violation in try violations(in: ItemSourceScan.codeOnly(source)) {
                found.append("\(relative): \(violation)")
            }
        }
        #expect(scanned == Self.files.count, "Both rule files must be readable")
        #expect(found.isEmpty, "Unexpected:\n\(found.joined(separator: "\n"))")
    }
}
