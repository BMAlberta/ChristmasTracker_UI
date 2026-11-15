//
//  ListRoleBadgeSourceScanTests.swift
//  ChristmasTrackerTests
//
//  PAL1-P3: no role badge path uses the gold or cranberry colors, and the badge view draws from
//  the look with tokens only. Comments are stripped before matching.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("ListRoleBadge source scan")
struct ListRoleBadgeSourceScanTests {

    private func code(named name: String) throws -> String {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let matches = tree.all.filter { $0.lastPathComponent == name }
        #expect(matches.count == 1, "\(name) should exist exactly once, found \(matches.count)")
        let url = try #require(matches.first, "\(name) is missing")
        return ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// The `ListBadge` struct only (up to the first preview that follows it).
    private func badgeRegion() throws -> String {
        let source = try code(named: "ListComponents.swift")
        let start = try #require(source.range(of: "struct ListBadge"), "ListBadge not found")
        let rest = source[start.lowerBound...]
        let tail = rest.dropFirst("struct ListBadge".count)
        if let next = tail.range(of: "\n#Preview") {
            return String(rest[rest.startIndex..<next.lowerBound])
        }
        return String(rest)
    }

    private static let banned = [
        "highlightColor", "accentColor", ".highlight", ".accent", "highlightStrong",
        "destructiveColor", "statusWrapped", "statusGifted", "statusPartial"
    ]

    @Test func roleBadgeFileUsesNeitherGoldNorCranberry() throws {
        let source = try code(named: "ListRoleBadge.swift")
        for needle in Self.banned {
            #expect(!source.contains(needle), "ListRoleBadge.swift contains \(needle)")
        }
    }

    @Test func badgeViewUsesNeitherGoldNorCranberry() throws {
        let region = try badgeRegion()
        for needle in Self.banned {
            #expect(!region.contains(needle), "ListBadge contains \(needle)")
        }
    }

    @Test func badgeViewDrawsFromTheLookWithTokensOnly() throws {
        let region = try badgeRegion()
        #expect(region.contains("tone.look"))
        #expect(region.contains("look.fillColor"))
        #expect(region.contains("look.borderColor"))
        #expect(region.contains("look.textColor"))
        #expect(region.contains("strokeBorder"))
        #expect(region.contains("RoleBadgeLook.borderWidth"))
        for needle in ["UIColor", "#colorLiteral", "surfaceColor"] {
            #expect(!region.contains(needle), "ListBadge contains \(needle)")
        }
        let initializers = try ItemSourceScan.matchingLines(#"\bColor\("#, in: region)
        #expect(initializers.isEmpty, "ListBadge calls a Color initializer at lines \(initializers)")
        let literal = try ItemSourceScan.matchingLines(#"\.(white|black)\b"#, in: region)
        #expect(literal.isEmpty, "ListBadge uses .white or .black at lines \(literal)")
        let widths = try ItemSourceScan.matchingLines(#"lineWidth:\s*[0-9]"#, in: region)
        #expect(widths.isEmpty, "ListBadge uses a bare line width at lines \(widths)")
    }

    @Test func lookMappingReadsOnlyTheToneNotARole() throws {
        let source = try code(named: "ListRoleBadge.swift")
        let start = try #require(source.range(of: "RoleBadgeLook"), "RoleBadgeLook not found")
        let tail = String(source[start.lowerBound...])
        let roles = try ItemSourceScan.matchingLines(#"\bListRole\b|\bmyRole\b|\brole\b"#, in: tail)
        #expect(roles.isEmpty, "the look region mentions a role at lines \(roles)")
    }
}
