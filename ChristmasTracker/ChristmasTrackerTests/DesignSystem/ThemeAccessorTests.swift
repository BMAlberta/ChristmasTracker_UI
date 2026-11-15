//
//  ThemeAccessorTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: DesignSystem/Colors/AppColors.swift is scanned as text. Every Color("...")
//  names a real colorset, every token has an accessor with its hex values documented, the budget
//  accessors exist, and destructiveColor is the accent colorset.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("AppColors accessor Tests")
struct ThemeAccessorTests {

    private static let path = "DesignSystem/Colors/AppColors.swift"

    private func loadSource() throws -> String {
        let tree = try #require(ItemSourceTree.load(from: #filePath))
        return try #require(tree.source(Self.path))
    }

    private func referencedNames(_ source: String) throws -> [String] {
        let code = ItemSourceScan.codeOnly(source)
        let regex = try NSRegularExpression(pattern: #"Color\("([^"]+)"\)"#)
        let range = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: range).compactMap { match in
            Range(match.range(at: 1), in: code).map { String(code[$0]) }
        }
    }

    @Test("Every Color(\"name\") in AppColors names an existing colorset")
    func referencedColorsetsExist() throws {
        let source = try loadSource()
        let catalog = try ThemeCatalog.load(from: #filePath)
        let names = try referencedNames(source)
        #expect(!names.isEmpty)
        for name in names {
            #expect(catalog.colorsets[name] != nil, "Color(\"\(name)\") has no colorset")
        }
    }

    @Test("Every token's colorset is referenced by an accessor", arguments: ThemeToken.allCases)
    func tokenHasAccessor(token: ThemeToken) throws {
        let names = try referencedNames(try loadSource())
        #expect(names.contains(token.colorsetName), "no accessor for \(token.colorsetName)")
    }

    @Test("Budget accessors exist and use their own colorsets", arguments: ["budgetSafeColor", "budgetWarningColor", "budgetOverColor"])
    func budgetAccessor(name: String) throws {
        let code = ItemSourceScan.codeOnly(try loadSource())
        let matches = try ItemSourceScan.matchingLines(
            #"static\s+(let|var)\s+"# + name + #"\s*(:\s*Color\s*)?=\s*Color\(""# + name + #""\)"#, in: code)
        #expect(matches.count == 1, "expected one accessor for \(name)")
    }

    @Test("destructiveColor is Color(\"accentColor\") with no UIColor or systemRed")
    func destructiveIsAccent() throws {
        let code = ItemSourceScan.codeOnly(try loadSource())
        let lines = code.components(separatedBy: "\n")
        let line = try #require(lines.first { $0.contains("destructiveColor") })
        #expect(line.contains(#"Color("accentColor")"#), "destructiveColor line: \(line)")
        #expect(!line.contains("UIColor"))
        #expect(!line.contains("systemRed"))
        let afterEquals = line.split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(afterEquals == #"Color("accentColor")"#)
    }

    @Test("Each token's accessor doc comment lists its light and dark hex", arguments: ThemeToken.allCases)
    func docCommentsHaveHex(token: ThemeToken) throws {
        let source = try loadSource()
        let lines = source.components(separatedBy: "\n")
        let needle = #"Color("\#(token.colorsetName)")"#
        let index = try #require(lines.firstIndex { line in
            line.contains("static") && line.contains(needle) && !line.contains("destructiveColor")
        })
        var comment: [String] = []
        var cursor = index - 1
        while cursor >= 0, lines[cursor].trimmingCharacters(in: .whitespaces).hasPrefix("///") {
            comment.append(lines[cursor])
            cursor -= 1
        }
        let text = comment.joined(separator: "\n").uppercased()
        #expect(text.contains(ThemeTestSupport.expectedHex(token, .light)),
                "\(token.rawValue): doc comment lacks \(ThemeTestSupport.expectedHex(token, .light))")
        #expect(text.contains(ThemeTestSupport.expectedHex(token, .dark)),
                "\(token.rawValue): doc comment lacks \(ThemeTestSupport.expectedHex(token, .dark))")
    }
}
