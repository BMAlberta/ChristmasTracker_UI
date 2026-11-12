//
//  ItemErrorScopeScanTests.swift
//  ChristmasTrackerTests
//
//  Fix pass F1: a screen never references the other screen's load error or clear method.
//   - ListDetailView.swift must not contain `clearDetailLoadError` or `detailLoadError`
//   - ItemDetailView.swift must not contain `clearListLoadError` or `listLoadError`
//
//  The check is a narrow text scan over comment-stripped source. It is first proven with
//  synthetic positive (must fire) and negative (must not fire) strings, then run over the
//  real files.
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum ItemErrorScope {

    static let listScreenForbidden = ["clearDetailLoadError", "detailLoadError"]
    static let detailScreenForbidden = ["clearListLoadError", "listLoadError"]

    /// The forbidden identifiers that appear (as whole identifiers) in the comment-stripped code.
    static func violations(in code: String, forbidden: [String]) -> [String] {
        forbidden.filter { name in
            ((try? ItemSourceScan.matchingLines("\\b\(name)\\b", in: code)) ?? [-1]).isEmpty == false
        }
    }
}

@Suite("Item error scope scan Tests")
struct ItemErrorScopeScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner proof (synthetic strings)

    @Test("The list screen rule fires on any mention of the detail error or its clear call", arguments: [
        "if let e = itemService.detailLoadError { Text(e.userMessage) }",
        ".onDisappear { itemService.clearDetailLoadError() }",
        "itemService.clearDetailLoadError()",
        "let e = itemService.detailLoadError"
    ])
    func listRuleFires(source: String) {
        let found = ItemErrorScope.violations(in: code(source), forbidden: ItemErrorScope.listScreenForbidden)
        #expect(!found.isEmpty, "\(source)")
    }

    @Test("The detail screen rule fires on any mention of the list error or its clear call", arguments: [
        "if let e = itemService.listLoadError { Text(e.userMessage) }",
        ".onDisappear { itemService.clearListLoadError() }",
        "itemService.clearListLoadError()",
        "let e = itemService.listLoadError"
    ])
    func detailRuleFires(source: String) {
        let found = ItemErrorScope.violations(in: code(source), forbidden: ItemErrorScope.detailScreenForbidden)
        #expect(!found.isEmpty, "\(source)")
    }

    @Test("The list screen rule does not fire on its own error, comments or look-alike names", arguments: [
        "if let e = itemService.listLoadError { Text(e.userMessage) }\n.onDisappear { itemService.clearListLoadError() }",
        "// never read detailLoadError here\nText(\"a\")",
        "/* clearDetailLoadError() belongs to the item screen */\nText(\"a\")",
        "let detailLoadErrors = 1",
        "let mydetailLoadError = 1",
        "Text(\"a\")"
    ])
    func listRuleDoesNotFire(source: String) {
        let found = ItemErrorScope.violations(in: code(source), forbidden: ItemErrorScope.listScreenForbidden)
        #expect(found.isEmpty, "\(source)")
    }

    @Test("The detail screen rule does not fire on its own error, comments or look-alike names", arguments: [
        "if let e = itemService.detailLoadError { Text(e.userMessage) }\n.onDisappear { itemService.clearDetailLoadError() }",
        "// never read listLoadError here\nText(\"a\")",
        "/* clearListLoadError() belongs to the list screen */\nText(\"a\")",
        "let listLoadErrors = 1",
        "let mylistLoadError = 1",
        "Text(\"a\")"
    ])
    func detailRuleDoesNotFire(source: String) {
        let found = ItemErrorScope.violations(in: code(source), forbidden: ItemErrorScope.detailScreenForbidden)
        #expect(found.isEmpty, "\(source)")
    }

    @Test("Each rule reports which identifier it found")
    func reportsTheIdentifier() {
        let source = "itemService.detailLoadError\nitemService.clearDetailLoadError()"
        let found = ItemErrorScope.violations(in: code(source), forbidden: ItemErrorScope.listScreenForbidden)
        #expect(Set(found) == ["detailLoadError", "clearDetailLoadError"])
    }

    // MARK: Real sources

    private func realSource(_ relative: String, file: String = #filePath) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let raw = try #require(tree.source(relative), "Could not read \(relative)")
        let stripped = ItemSourceScan.codeOnly(raw)
        #expect(!stripped.isEmpty, "\(relative) is empty after stripping comments")
        return stripped
    }

    @Test("ListDetailView.swift does not reference the item screen's error or clear method")
    func realListDetailView() throws {
        let source = try realSource("Features/Lists/Views/ListDetailView.swift")

        let found = ItemErrorScope.violations(in: source, forbidden: ItemErrorScope.listScreenForbidden)

        #expect(found.isEmpty, "ListDetailView.swift references: \(found.joined(separator: ", "))")
    }

    @Test("ItemDetailView.swift does not reference the list screen's error or clear method")
    func realItemDetailView() throws {
        let source = try realSource("Features/Items/Views/ItemDetailView.swift")

        let found = ItemErrorScope.violations(in: source, forbidden: ItemErrorScope.detailScreenForbidden)

        #expect(found.isEmpty, "ItemDetailView.swift references: \(found.joined(separator: ", "))")
    }
}
