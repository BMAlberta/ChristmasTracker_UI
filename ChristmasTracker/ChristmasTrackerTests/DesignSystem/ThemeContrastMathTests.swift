//
//  ThemeContrastMathTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: WCAG relative luminance and contrast ratio.
//

import Testing
@testable import ChristmasTracker

@Suite("ThemeContrast Tests")
struct ThemeContrastMathTests {

    private let white = ThemeRGB(red: 255, green: 255, blue: 255)
    private let black = ThemeRGB(red: 0, green: 0, blue: 0)

    @Test("Black against white is 21:1")
    func blackOnWhite() {
        #expect(abs(ThemeContrast.ratio(black, white) - 21.0) < 0.001)
    }

    @Test("A color against itself is 1:1")
    func sameColor() {
        let color = ThemeRGB(red: 31, green: 77, blue: 58)
        #expect(abs(ThemeContrast.ratio(color, color) - 1.0) < 0.0001)
    }

    @Test("The ratio is symmetric and at least 1")
    func symmetric() {
        let a = ThemeRGB(red: 178, green: 58, blue: 72)
        let b = ThemeRGB(red: 250, green: 249, blue: 247)
        #expect(ThemeContrast.ratio(a, b) == ThemeContrast.ratio(b, a))
        #expect(ThemeContrast.ratio(a, b) >= 1.0)
    }

    @Test("Relative luminance of white is 1 and of black is 0")
    func luminanceExtremes() {
        #expect(abs(ThemeContrast.relativeLuminance(white) - 1.0) < 0.0001)
        #expect(abs(ThemeContrast.relativeLuminance(black) - 0.0) < 0.0001)
    }

    @Test("Mid-gray #808080 has the known luminance and ratio against white")
    func midGray() {
        let gray = ThemeRGB(red: 128, green: 128, blue: 128)
        #expect(abs(ThemeContrast.relativeLuminance(gray) - 0.21586) < 0.0005)
        #expect(abs(ThemeContrast.ratio(gray, white) - 3.9495) < 0.002)
    }

    @Test("#767676 against white is the well-known 4.54:1")
    func knownAAGray() {
        let gray = ThemeRGB(red: 118, green: 118, blue: 118)
        #expect(abs(ThemeContrast.ratio(gray, white) - 4.54) < 0.01)
    }
}
