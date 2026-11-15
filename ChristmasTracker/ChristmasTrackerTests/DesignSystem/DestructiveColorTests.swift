//
//  DestructiveColorTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1 (replaces the I3c-D system-red test): Color.destructiveColor is the accent
//  colorset (Cranberry), resolved per trait collection: #B23A48 in light, #E06A75 in dark.
//
//  Covers Color.destructiveColor in light and dark appearance.
//

import Testing
import SwiftUI
import UIKit
@testable import ChristmasTracker

@Suite("destructiveColor Tests")
struct DestructiveColorTests {

    private struct RGBA {
        var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat

        func isClose(to other: RGBA) -> Bool {
            abs(r - other.r) < 0.005 && abs(g - other.g) < 0.005
                && abs(b - other.b) < 0.005 && abs(a - other.a) < 0.005
        }
    }

    private func components(_ color: UIColor, style: UIUserInterfaceStyle) -> RGBA {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = color.resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: r, g: g, b: b, a: a)
    }

    private func expected(hex: String) throws -> RGBA {
        let rgb = try #require(ThemeRGB(hex: hex))
        return RGBA(r: CGFloat(rgb.red) / 255, g: CGFloat(rgb.green) / 255, b: CGFloat(rgb.blue) / 255, a: 1)
    }

    @Test("Resolves to the accent colorset value in the given appearance", arguments: [UIUserInterfaceStyle.light, .dark])
    func matchesAccent(style: UIUserInterfaceStyle) throws {
        let hex = style == .dark ? "#E06A75" : "#B23A48"
        let actual = components(UIColor(Color.destructiveColor), style: style)
        let wanted = try expected(hex: hex)
        #expect(actual.isClose(to: wanted), "\(style.rawValue): \(actual) vs \(wanted)")
    }

    @Test("Is the same color as the accent token in both appearances", arguments: [UIUserInterfaceStyle.light, .dark])
    func equalsAccentToken(style: UIUserInterfaceStyle) {
        let destructive = components(UIColor(Color.destructiveColor), style: style)
        let accent = components(UIColor(Color("accentColor")), style: style)
        #expect(destructive.isClose(to: accent))
    }

    @Test("Differs between light and dark (not a fixed RGB)")
    func differsAcrossAppearances() {
        let light = components(UIColor(Color.destructiveColor), style: .light)
        let dark = components(UIColor(Color.destructiveColor), style: .dark)
        #expect(!light.isClose(to: dark))
    }
}
