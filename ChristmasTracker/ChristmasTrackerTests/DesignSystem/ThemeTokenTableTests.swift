//
//  ThemeTokenTableTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: ThemeToken names, ThemeTokenTable values, and the pill label table.
//

import Testing
@testable import ChristmasTracker

@Suite("ThemeToken and table Tests")
struct ThemeTokenTableTests {

    @Test("There are 20 tokens")
    func tokenCount() {
        #expect(ThemeToken.allCases.count == 20)
    }

    @Test("The two PAL1 tokens have the revised values and colorset names")
    func pal1Tokens() {
        #expect(ThemeToken.highlightStrong.colorsetName == "highlightStrongColor")
        #expect(ThemeToken.budgetWarningBar.colorsetName == "budgetWarningBarColor")
        for token in [ThemeToken.highlightStrong, .budgetWarningBar] {
            #expect(ThemeTokenTable.rgb(token, .light).hex == "#9C7A2E")
            #expect(ThemeTokenTable.rgb(token, .dark).hex == "#E4C76A")
        }
    }

    @Test("Each token maps to its colorset name", arguments: ThemeToken.allCases)
    func colorsetName(token: ThemeToken) {
        #expect(token.colorsetName == ThemeTestSupport.expectedColorsetNames[token])
    }

    @Test("Colorset names are unique")
    func colorsetNamesUnique() {
        let names = ThemeToken.allCases.map(\.colorsetName)
        #expect(Set(names).count == names.count)
    }

    @Test("ThemeTokenTable matches the brief in both modes", arguments: ThemeToken.allCases)
    func tableValues(token: ThemeToken) {
        for mode in ThemeMode.allCases {
            #expect(
                ThemeTokenTable.rgb(token, mode) == ThemeTestSupport.expectedRGB(token, mode),
                "\(token.rawValue) \(ThemeTestSupport.modeName(mode))"
            )
        }
    }

    @Test("Pill label in light mode: white on dark fills, textPrimary on gold fills")
    func lightLabels() {
        for fill in [ThemeToken.statusAvailable, .statusPurchased, .statusShipped, .statusWrapped] {
            #expect(ThemeStatusLabelTable.label(onFill: fill, mode: .light) == .white, "\(fill.rawValue)")
        }
        for fill in [ThemeToken.statusPartial, .statusGifted] {
            #expect(ThemeStatusLabelTable.label(onFill: fill, mode: .light) == .token(.textPrimary), "\(fill.rawValue)")
        }
    }

    @Test("Pill label in dark mode is backgroundPrimary on every status fill")
    func darkLabels() {
        for fill in ThemeTestSupport.statusFills {
            #expect(ThemeStatusLabelTable.label(onFill: fill, mode: .dark) == .token(.backgroundPrimary), "\(fill.rawValue)")
        }
    }

    @Test("Label RGB: white is #FFFFFF in both modes, tokens come from the token table")
    func labelRGB() {
        let white = ThemeRGB(red: 255, green: 255, blue: 255)
        for mode in ThemeMode.allCases {
            #expect(ThemeStatusLabelTable.rgb(.white, mode) == white)
            #expect(ThemeStatusLabelTable.rgb(.token(.textPrimary), mode) == ThemeTokenTable.rgb(.textPrimary, mode))
            #expect(ThemeStatusLabelTable.rgb(.token(.backgroundPrimary), mode) == ThemeTokenTable.rgb(.backgroundPrimary, mode))
        }
    }
}
