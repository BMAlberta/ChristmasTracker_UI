//
//  ThemeContrast.swift
//  ChristmasTracker
//
//  Pure WCAG contrast math over sRGB bytes. Used by tests (and later style code) to prove that
//  the theme's color pairs reach the required contrast. No UI, no I/O.
//

import Foundation

/// An opaque sRGB color as three bytes (0...255).
nonisolated struct ThemeRGB: Equatable, Hashable, Sendable {
    let red: Int
    let green: Int
    let blue: Int

    init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses "#RRGGBB" or "RRGGBB" (case-insensitive). Anything else is nil.
    init?(hex: String) {
        var digits = Substring(hex)
        if digits.hasPrefix("#") {
            digits = digits.dropFirst()
        }
        guard digits.count == 6, digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            return nil
        }
        guard let value = Int(digits, radix: 16) else {
            return nil
        }
        self.init(red: (value >> 16) & 0xFF, green: (value >> 8) & 0xFF, blue: value & 0xFF)
    }

    /// Uppercase "#RRGGBB".
    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }
}

/// WCAG 2.x relative luminance and contrast ratio.
nonisolated enum ThemeContrast {

    static func relativeLuminance(_ color: ThemeRGB) -> Double {
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// Contrast ratio from 1 to 21. Symmetric: the lighter color is always the numerator.
    static func ratio(_ first: ThemeRGB, _ second: ThemeRGB) -> Double {
        let a = relativeLuminance(first)
        let b = relativeLuminance(second)
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linear(_ byte: Int) -> Double {
        let channel = Double(byte) / 255.0
        if channel <= 0.04045 {
            return channel / 12.92
        }
        return pow((channel + 0.055) / 1.055, 2.4)
    }
}
