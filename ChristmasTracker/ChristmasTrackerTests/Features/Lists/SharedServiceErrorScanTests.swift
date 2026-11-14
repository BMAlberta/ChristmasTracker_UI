//
//  SharedServiceErrorScanTests.swift
//  ChristmasTrackerTests
//
//  UX1a Story U2: ListService and ChildService no longer have a shared published `error`. No
//  production file under Features/ other than the two services themselves reads
//  `listService.error` or `childService.error`, calls a removed `clearError`, or mentions the removed
//  members in code. Needs the checkout on disk, which scripts/test.sh has.
//
//  The rule is proven on in-memory strings before it runs on disk. Comments are ignored.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Shared service error scan Tests")
struct SharedServiceErrorScanTests {

    /// Reads of the removed shared members through the usual property names.
    static let pattern = #"\b(listService|childService|self\.listService|self\.childService)\s*\.\s*(error|clearError)\b"#

    /// The services themselves are the only files allowed to talk about their own members.
    static let allowedPrefixes = ["Features/Lists/Services/", "Features/Children/Services/"]

    // MARK: Scanner proofs (synthetic strings)

    @Test("the rule fires on reads of the removed shared members", arguments: [
        "if let failure = listService.error { show(failure) }",
        "Text(childService.error?.userMessage ?? \"\")",
        "listService.clearError()",
        "environment.listService.error",
        "let e = self.listService.error",
        "childService . error"
    ])
    func ruleFires(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(!(try ItemSourceScan.matchingLines(Self.pattern, in: code)).isEmpty, "\(source)")
    }

    @Test("the rule allows the scoped failures, other services' errors and comments", arguments: [
        "listService.listsLoadFailure",
        "listService.detailLoadFailure",
        "listService.clearListsLoadFailure()",
        "childService.phase",
        "childService.clearLoadFailure()",
        "itemService.listLoadError",
        "authService.error",
        "// listService.error is gone",
        "let myListService = 1"
    ])
    func ruleAllows(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(try ItemSourceScan.matchingLines(Self.pattern, in: code).isEmpty, "\(source)")
    }

    // MARK: On disk

    @Test("no production file under Features/ outside the two services reads their removed shared error")
    func noViewReadsSharedError() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        var scanned = 0
        var offenders: [String] = []

        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/") else { continue }
            guard !Self.allowedPrefixes.contains(where: { relative.hasPrefix($0) }) else { continue }
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            scanned += 1
            let lines = try ItemSourceScan.matchingLines(Self.pattern, in: code)
            if !lines.isEmpty { offenders.append("\(relative):\(lines)") }
        }

        #expect(scanned > 0, "the scan found no Features/ files")
        #expect(offenders.isEmpty, "shared service error is still read: \(offenders)")
    }

    @Test("ListService and ChildService declare no stored `error` property any more")
    func servicesDeclareNoSharedError() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let declaration = #"(?m)^    (private\(set\) )?var\s+error\s*:"#
        var scanned = 0
        var offenders: [String] = []

        for url in tree.all {
            let relative = tree.relativePath(url)
            guard Self.allowedPrefixes.contains(where: { relative.hasPrefix($0) }) else { continue }
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            guard code.contains("final class ListService") || code.contains("final class ChildService")
                    || code.contains("extension ListService") || code.contains("extension ChildService") else { continue }
            scanned += 1
            let lines = try ItemSourceScan.matchingLines(declaration, in: code)
            if !lines.isEmpty { offenders.append("\(relative):\(lines)") }
            #expect(!code.contains("func clearError"), "\(relative): clearError is removed")
        }

        #expect(scanned >= 2, "expected to scan the ListService and ChildService files")
        #expect(offenders.isEmpty, "a shared error is still declared: \(offenders)")
    }
}
