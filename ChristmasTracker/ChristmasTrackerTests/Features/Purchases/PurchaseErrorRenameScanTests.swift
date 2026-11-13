//
//  PurchaseErrorRenameScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-D: the record error enum is renamed. `PurchaseError` is declared exactly once, in
//  Features/Purchases/Domain/PurchaseError.swift, and the previous name appears nowhere in any
//  production or test file, comments included (the raw text is scanned, not the comment-stripped
//  code). Names that merely contain the old word, such as the presentation type, keep their names
//  and are not flagged (word boundaries).
//
//  Self-protection: the old name is built from split literals, so this file never holds it as
//  one token (not even in comments), and no exclusion is needed.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("PurchaseError rename scan Tests")
struct PurchaseErrorRenameScanTests {

    private static let oldName = ["Record", "Purchase", "Error"].joined()
    private static let oldPattern = "\\b" + oldName + "\\b"
    private static let declarationPattern = #"\b(enum|struct|class|actor|protocol|typealias)\s+PurchaseError\b"#
    private static let domainFile = "Features/Purchases/Domain/PurchaseError.swift"

    private func makeSUT(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    // MARK: Scanner self-proofs

    @Test("The old-name scanner finds the name in code, in comments and in strings", arguments: [
        "let e: {OLD}",
        "throw {OLD}.server",
        "// thrown as {OLD}",
        "/* {OLD} */",
        "let s = \"{OLD}\"",
        "if let t = error as? {OLD} { throw t }"
    ])
    func oldNameScannerFinds(template: String) throws {
        let source = template.replacingOccurrences(of: "{OLD}", with: Self.oldName)
        #expect(try ItemSourceScan.matchingLines(Self.oldPattern, in: source).count == 1, "\(source)")
    }

    @Test("The old-name scanner leaves longer names and the new name alone", arguments: [
        "let p = {OLD}Presentation.self",
        "struct {OLD}Tests {}",
        "let e: PurchaseError",
        "throw PurchaseError.server",
        "let e: PurchaseManagementError"
    ])
    func oldNameScannerLeavesLookAlikes(template: String) throws {
        let source = template.replacingOccurrences(of: "{OLD}", with: Self.oldName)
        #expect(try ItemSourceScan.matchingLines(Self.oldPattern, in: source).isEmpty, "\(source)")
    }

    @Test("The declaration scanner finds declarations of the new name only", arguments: [
        ("enum PurchaseError: Error, Equatable, Sendable {", 1),
        ("nonisolated enum PurchaseError: Error {", 1),
        ("struct PurchaseError {}", 1),
        ("typealias PurchaseError = Other", 1),
        ("enum PurchaseErrorPresentation {", 0),
        ("enum PurchaseManagementError {", 0),
        ("let e: PurchaseError", 0),
        ("throw PurchaseError.server", 0)
    ])
    func declarationScanner(source: String, expected: Int) throws {
        #expect(try ItemSourceScan.matchingLines(Self.declarationPattern, in: source).count == expected, "\(source)")
    }

    // MARK: Real sources

    @Test("PurchaseError is declared once, as the record error enum, in Domain/PurchaseError.swift")
    func declaredOnceInTheDomainFile() throws {
        let tree = try makeSUT()
        let source = try #require(tree.source(Self.domainFile), "\(Self.domainFile) is missing")

        let own = try ItemSourceScan.matchingLines(Self.declarationPattern, in: ItemSourceScan.codeOnly(source))
        #expect(own.count == 1)
        #expect(try ItemSourceScan.matchingLines(#"\benum\s+PurchaseError\b"#, in: ItemSourceScan.codeOnly(source)).count == 1,
                "PurchaseError must be an enum")

        var declarations: [String] = []
        for url in tree.all {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try ItemSourceScan.matchingLines(Self.declarationPattern, in: code) {
                declarations.append("\(tree.relativePath(url)):\(line)")
            }
        }
        #expect(declarations.count == 1, "PurchaseError must be declared once: \(declarations)")
    }

    @Test("PurchaseError keeps the record error cases")
    func keepsTheRecordCases() throws {
        let tree = try makeSUT()
        let source = try #require(tree.source(Self.domainFile), "\(Self.domainFile) is missing")
        let body = try #require(ItemSourceScan.braceBody(after: "enum PurchaseError", in: ItemSourceScan.codeOnly(source)))
        for name in ["notFound", "unauthorized", "forbidden", "cannotPurchaseOwnList", "validation",
                     "invalidPrice", "rateLimited", "sessionEnded", "network", "invalidResponse", "server"] {
            #expect(body.contains("case \(name)") || body.contains(", \(name)"), "missing case \(name)")
        }
    }

    @Test("The old domain file is gone")
    func oldDomainFileIsGone() throws {
        let tree = try makeSUT()
        #expect(!tree.exists("Features/Purchases/Domain/" + Self.oldName + ".swift"))
    }

    @Test("The old name appears nowhere in any production or test file, comments included")
    func oldNameIsGone() throws {
        let files = try makeSUT().productionAndTestFiles()
        #expect(files.count > 100)
        var found: [String] = []
        for file in files {
            let raw = try String(contentsOf: file.url, encoding: .utf8)
            for line in try ItemSourceScan.matchingLines(Self.oldPattern, in: raw) {
                found.append("\(file.relative):\(line)")
            }
        }
        #expect(found.isEmpty, "The old name is still used:\n\(found.joined(separator: "\n"))")
    }
}
