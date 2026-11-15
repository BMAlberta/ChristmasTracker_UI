//
//  ThemeRGBTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: hex parsing and formatting of ThemeRGB.
//

import Testing
@testable import ChristmasTracker

@Suite("ThemeRGB Tests")
struct ThemeRGBTests {

    @Test("Parses #RRGGBB and RRGGBB, case-insensitive")
    func parses() {
        #expect(ThemeRGB(hex: "#1F4D3A") == ThemeRGB(red: 31, green: 77, blue: 58))
        #expect(ThemeRGB(hex: "1F4D3A") == ThemeRGB(red: 31, green: 77, blue: 58))
        #expect(ThemeRGB(hex: "#4fa58a") == ThemeRGB(red: 79, green: 165, blue: 138))
    }

    @Test("Formats as uppercase #RRGGBB")
    func formats() {
        #expect(ThemeRGB(red: 0, green: 10, blue: 255).hex == "#000AFF")
        #expect(ThemeRGB(red: 79, green: 165, blue: 138).hex == "#4FA58A")
    }

    @Test("Parse and format round trip", arguments: ["#000000", "#FFFFFF", "#1F4D3A", "#E06A75", "#0F1A17"])
    func roundTrip(hex: String) throws {
        let parsed = try #require(ThemeRGB(hex: hex))
        #expect(parsed.hex == hex)
    }

    @Test("Invalid input is nil", arguments: ["#12345", "12345", "GGGGGG", "#ZZZZZZ", "", "#", "#1234567", "12 456"])
    func invalid(text: String) {
        #expect(ThemeRGB(hex: text) == nil)
    }
}
