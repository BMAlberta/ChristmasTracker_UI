//
//  StatusEdgeSourceScanTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P2: StatusPill and StatusDotLabel draw the edge through the table-driven rule and keep out
//  raw colors and hard-coded status names. Comments are stripped before matching.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Status edge source scan")
struct StatusEdgeSourceScanTests {

    private static let files = ["StatusPill.swift", "StatusDotLabel.swift"]

    private func code(named name: String) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let matches = tree.all.filter { $0.lastPathComponent == name }
        #expect(matches.count == 1, "\(name) should exist exactly once, found \(matches.count)")
        let url = try #require(matches.first, "\(name) is missing")
        return ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    @Test(arguments: StatusEdgeSourceScanTests.files)
    func viewDrawsTheEdgeFromTheStyleRule(_ name: String) throws {
        let source = try code(named: name)
        #expect(source.contains("style.edge"), "\(name) does not use the StatusStyle edge helper")
        #expect(source.contains("strokeBorder") || source.contains(".stroke("), "\(name) draws no stroke")
        #expect(source.contains("StatusStyle.edgeWidth"), "\(name) does not use the named edge width")
    }

    @Test func theStyleHelperIsDrivenByThemeEdgeRule() throws {
        let source = try code(named: "ItemStatusStyle.swift")
        #expect(source.contains("ThemeEdgeRule.fillsNeedingEdge()"))
        #expect(source.contains(".highlightStrong"))
    }

    @Test(arguments: StatusEdgeSourceScanTests.files)
    func viewContainsNoRawColor(_ name: String) throws {
        let source = try code(named: name)
        for needle in ["Color(red", "Color(.sRGB", "UIColor", "#colorLiteral"] {
            #expect(!source.contains(needle), "\(name) contains \(needle)")
        }
        let hex = try ItemSourceScan.matchingLines(##""#?(0x)?[0-9A-Fa-f]{6}""##, in: source)
        #expect(hex.isEmpty, "\(name) has a hex string at lines \(hex)")
        let literal = try ItemSourceScan.matchingLines(#"\.(white|black)\b"#, in: source)
        #expect(literal.isEmpty, "\(name) uses .white or .black at lines \(literal)")
    }

    @Test(arguments: StatusEdgeSourceScanTests.files)
    func viewHardCodesNoStatusForTheEdge(_ name: String) throws {
        let source = try code(named: name)
        let names = try ItemSourceScan.matchingLines(
            #"\.(partial|gifted|statusPartial|statusGifted)\b|"(Partial|Gifted)""#, in: source
        )
        #expect(names.isEmpty, "\(name) names a status at lines \(names)")
        let widths = try ItemSourceScan.matchingLines(#"lineWidth:\s*[0-9]"#, in: source)
        #expect(widths.isEmpty, "\(name) uses a bare line width at lines \(widths)")
    }
}
