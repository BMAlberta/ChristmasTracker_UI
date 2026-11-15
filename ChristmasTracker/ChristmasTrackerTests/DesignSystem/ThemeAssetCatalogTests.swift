//
//  ThemeAssetCatalogTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: the colorset files on disk hold the brief's values. Reads every Contents.json
//  from the source tree (found from #filePath). The no-appearance fallback entry is ignored.
//

import Testing
@testable import ChristmasTracker

@Suite("Theme asset catalog Tests")
struct ThemeAssetCatalogTests {

    @Test("Every token's colorset exists and holds the brief's light and dark values", arguments: ThemeToken.allCases)
    func tokenValues(token: ThemeToken) throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        #expect(catalog.colorsets[token.colorsetName] != nil, "missing colorset \(token.colorsetName)")
        let entry = try catalog.entry(token.colorsetName)
        #expect(entry.light == ThemeTestSupport.expectedRGB(token, .light),
                "\(token.rawValue) light: \(entry.light.hex) vs \(ThemeTestSupport.expectedHex(token, .light))")
        #expect(entry.dark == ThemeTestSupport.expectedRGB(token, .dark),
                "\(token.rawValue) dark: \(entry.dark.hex) vs \(ThemeTestSupport.expectedHex(token, .dark))")
        #expect(entry.light == ThemeTokenTable.rgb(token, .light))
        #expect(entry.dark == ThemeTokenTable.rgb(token, .dark))
    }

    @Test("AccentColor (the app-level accent) holds the primary values")
    func appAccentIsPrimary() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        let entry = try catalog.entry("AccentColor")
        #expect(entry.light.hex == "#1F4D3A")
        #expect(entry.dark.hex == "#4FA58A")
    }

    @Test("The catalog has no colorsets beyond the 18 tokens, AccentColor and LaunchBackground")
    func noExtraColorsets() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        let expected = Set(ThemeToken.allCases.map(\.colorsetName)).union(["AccentColor", "LaunchBackground"])
        let actual = Set(catalog.colorsets.keys)
        #expect(actual.subtracting(expected).isEmpty, "unexpected colorsets: \(actual.subtracting(expected).sorted())")
        #expect(expected.subtracting(actual).isEmpty, "missing colorsets: \(expected.subtracting(actual).sorted())")
        #expect(catalog.colorsets.count == 20)
        #expect(catalog.colorsets["AppIcon"] == nil)
    }
}
