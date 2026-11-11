//
//  LegacyGiftItemScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-B (deviation D1.4): the legacy `GiftItem` token is confined. Outside a documented
//  allowlist no production file may contain it (comments are ignored), and the new item
//  files must never contain it.
//
//  The allowlist has PERMANENT entries (purchase folders, the legacy type's own file) and
//  TRANSITIONAL entries for the old item stack that Stories C and D delete. Every entry
//  carries a reason; the transitional ones are removed as those stories land.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Legacy GiftItem scan Tests")
struct LegacyGiftItemScanTests {

    private struct Entry {
        let path: String      // a file, or a folder when it ends with "/"
        let reason: String
    }

    private static let allowlist: [Entry] = [
        Entry(path: "Features/Purchases/", reason: "Purchase screens take GiftItem until package I4 (D1)."),
        Entry(path: "Core/Models/GiftItem.swift", reason: "The legacy type and the ListItem bridge live here until I4."),
        // TRANSITIONAL: deleted or rewritten by Stories C and D.
        Entry(path: "App/InertRepositories.swift", reason: "TRANSITIONAL: InertItemRepository moves to ListItem in Story C."),
        Entry(path: "Features/Items/", reason: "TRANSITIONAL: the old item stack (service, store, views, old repositories) is rewritten in Stories C and D. New files are checked separately below."),
        Entry(path: "Features/Lists/Views/ListDetailView.swift", reason: "TRANSITIONAL: its item section is rewritten in Story D."),
        Entry(path: "PreviewContent/", reason: "TRANSITIONAL: preview fixtures, if any, follow the item stack.")
    ]

    private static let newFiles = [
        "Core/Models/ListItem.swift",
        "Features/Items/ViewState/ItemPermissions.swift",
        "Features/Items/ViewState/ItemViewState.swift",
        "Features/Items/ViewState/ItemFormValidation.swift",
        "Features/Items/Repositories/ItemMapping.swift"
    ]

    private func makeSUT(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func isAllowed(_ relative: String) -> Bool {
        Self.allowlist.contains { entry in
            entry.path.hasSuffix("/") ? relative.hasPrefix(entry.path) : relative == entry.path
        }
    }

    private func offenders(in tree: ItemSourceTree, files: [URL]) throws -> [String] {
        var result: [String] = []
        for url in files {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try ItemSourceScan.matchingLines(#"\bGiftItem\b"#, in: code) {
                result.append("\(tree.relativePath(url)):\(line)")
            }
        }
        return result
    }

    @Test("Every allowlist entry has a reason")
    func entriesHaveReasons() {
        for entry in Self.allowlist {
            #expect(!entry.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(entry.path)")
        }
    }

    @Test("The scanner finds the token and ignores comments")
    func scannerSelfCheck() throws {
        #expect(try ItemSourceScan.matchingLines(#"\bGiftItem\b"#, in: "let x: GiftItem").count == 1)
        #expect(try ItemSourceScan.matchingLines(#"\bGiftItem\b"#, in: ItemSourceScan.codeOnly("// GiftItem\nlet a = 1")).isEmpty)
        #expect(try ItemSourceScan.matchingLines(#"\bGiftItem\b"#, in: "let x: GiftItemCell").isEmpty)
    }

    @Test("No production file outside the allowlist contains the GiftItem token")
    func noGiftItemOutsideAllowlist() throws {
        let tree = try makeSUT()
        #expect(!tree.all.isEmpty)
        let scanned = tree.all.filter { !isAllowed(tree.relativePath($0)) }
        #expect(!scanned.isEmpty)
        let found = try offenders(in: tree, files: scanned)
        #expect(found.isEmpty, "GiftItem referenced outside the allowlist:\n\(found.joined(separator: "\n"))")
    }

    @Test("The new item files exist and never contain the GiftItem token")
    func newFilesAreClean() throws {
        let tree = try makeSUT()
        var missing: [String] = []
        var files: [URL] = []
        for relative in Self.newFiles {
            if tree.exists(relative) { files.append(tree.file(relative)) } else { missing.append(relative) }
        }
        #expect(missing.isEmpty, "Expected new files are missing: \(missing)")
        let found = try offenders(in: tree, files: files)
        #expect(found.isEmpty, "New item files reference GiftItem:\n\(found.joined(separator: "\n"))")
    }

    @Test("New item services and screens, where present, never contain the GiftItem token")
    func newServicesAndScreensAreClean() throws {
        let tree = try makeSUT()
        let optional = [
            "Features/Items/Repositories/GeneratedClientItemRepository.swift"
        ]
        let files = optional.filter(tree.exists).map(tree.file)
        let found = try offenders(in: tree, files: files)
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }
}
