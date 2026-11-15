//
//  StatusStyleScanTests.swift
//  ChristmasTrackerTests
//
//  TH1-T3: source scans for the status views. Comments are stripped before matching.
//   1. no system color and no UIColor in the status files and the two item views
//   2. ItemStatus has no `var color`; `tokenColor` exists nowhere in the app sources
//   3. ItemRow and ItemDetailView show status through StatusPill
//   4. StatusPill and StatusDotLabel are one accessibility element; the dot scales; no hex strings;
//      `.white` appears only in an allowlist of files
//
//  `.white` allowlist (a file listed here may contain `.white`):
//   - Features/Items/Components/ItemStatusStyle.swift  the style layer that maps ThemeLabel to a Color
//   - DesignSystem/Colors/ThemeTokenTable.swift         pure data: `ThemeLabel.white`
//  (T5 removed the hand-built filled primary buttons; PrimaryButtonStyle takes its label from the table.)
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Status style scans")
struct StatusStyleScanTests {

    static let whiteAllowlist: Set<String> = [
        "Features/Items/Components/ItemStatusStyle.swift",
        "DesignSystem/Colors/ThemeTokenTable.swift"
    ]

    private func tree(_ file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    /// The code-only text of the single file with this name anywhere in the app sources.
    private func code(named name: String, in tree: ItemSourceTree) throws -> String {
        let matches = tree.all.filter { $0.lastPathComponent == name }
        #expect(matches.count == 1, "\(name) should exist exactly once, found \(matches.count)")
        let url = try #require(matches.first, "\(name) is missing")
        return ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private let statusFiles = [
        "ItemStatus.swift", "ItemStatusStyle.swift", "StatusPill.swift", "StatusDotLabel.swift",
        "ItemRow.swift", "ItemDetailView.swift"
    ]

    // MARK: 1. No system colors

    @Test func statusFilesUseNoSystemColor() throws {
        let tree = try tree()
        let pattern = #"\.(gray|orange|green|blue|purple|red|yellow|pink)\b"#
        for name in statusFiles {
            let lines = try ItemSourceScan.matchingLines(pattern, in: try code(named: name, in: tree))
            #expect(lines.isEmpty, "\(name) uses a system color at lines \(lines)")
        }
    }

    @Test func statusFilesUseNoUIColor() throws {
        let tree = try tree()
        for name in statusFiles {
            let source = try code(named: name, in: tree)
            #expect(!source.contains("UIColor"), "\(name) mentions UIColor")
            #expect(!source.contains("Color(uiColor:"), "\(name) uses Color(uiColor:)")
        }
    }

    // MARK: 2. Removed properties

    @Test func itemStatusHasNoColorProperty() throws {
        let source = try code(named: "ItemStatus.swift", in: try tree())
        let lines = try ItemSourceScan.matchingLines(#"\bvar\s+color\b"#, in: source)
        #expect(lines.isEmpty, "ItemStatus still declares var color at lines \(lines)")
    }

    @Test func tokenColorExistsNowhereInTheAppSources() throws {
        let tree = try tree()
        var offenders: [String] = []
        for url in tree.all {
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if source.contains("tokenColor") { offenders.append(tree.relativePath(url)) }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    // MARK: 3. Views use StatusPill

    @Test func itemRowAndItemDetailUseStatusPill() throws {
        let tree = try tree()
        for name in ["ItemRow.swift", "ItemDetailView.swift"] {
            #expect(try code(named: name, in: tree).contains("StatusPill("), "\(name) does not use StatusPill(")
        }
    }

    @Test func itemRowAndItemDetailDoNotRenderTheMarkerNameThemselves() throws {
        let tree = try tree()
        for name in ["ItemRow.swift", "ItemDetailView.swift"] {
            let source = try code(named: name, in: tree)
            #expect(!source.contains("marker.displayName"), "\(name) renders marker.displayName")
            #expect(!source.contains("statusMarker.displayName"), "\(name) renders statusMarker.displayName")
            #expect(!source.contains(".tokenColor"), "\(name) still uses .tokenColor")
        }
    }

    // MARK: 4. Pill and dot

    @Test func pillAndDotAreOneAccessibilityElement() throws {
        let tree = try tree()
        for name in ["StatusPill.swift", "StatusDotLabel.swift"] {
            let source = try code(named: name, in: tree)
            #expect(source.contains(".accessibilityElement(children: .ignore)"), "\(name) lacks .accessibilityElement(children: .ignore)")
            #expect(source.contains(".accessibilityLabel("), "\(name) lacks .accessibilityLabel(")
        }
    }

    @Test func dotSizeScalesWithDynamicType() throws {
        let source = try code(named: "StatusDotLabel.swift", in: try tree())
        #expect(source.contains("@ScaledMetric"))
    }

    @Test func pillAndDotHardCodeNoHexString() throws {
        let tree = try tree()
        for name in ["StatusPill.swift", "StatusDotLabel.swift"] {
            let lines = try ItemSourceScan.matchingLines(##""#?(0x)?[0-9A-Fa-f]{6}""##, in: try code(named: name, in: tree))
            #expect(lines.isEmpty, "\(name) has a hex string at lines \(lines)")
        }
    }

    @Test func whiteAppearsOnlyInTheAllowlistedFiles() throws {
        let tree = try tree()
        var offenders: [String] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/") || relative.hasPrefix("DesignSystem/") || relative.hasPrefix("App/") else { continue }
            guard !Self.whiteAllowlist.contains(relative) else { continue }
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try ItemSourceScan.matchingLines(#"\.white\b"#, in: source) {
                offenders.append("\(relative):\(line)")
            }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }
}
