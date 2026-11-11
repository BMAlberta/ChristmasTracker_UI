//
//  DestructiveColorTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D (UI rule 3): Color.destructiveColor is system red, resolved per trait collection.
//  In both appearances it must equal the resolved UIColor.systemRed. A fixed RGB cannot satisfy
//  this, because systemRed differs between light and dark.
//
//  Fails today because Color.destructiveColor does not exist yet.
//

import Testing
import SwiftUI
import UIKit
@testable import ChristmasTracker

@Suite("destructiveColor Tests")
struct DestructiveColorTests {

    private struct RGBA: Equatable {
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

    @Test("Resolves to the system red in the given appearance", arguments: [UIUserInterfaceStyle.light, .dark])
    func matchesSystemRed(style: UIUserInterfaceStyle) {
        let actual = components(UIColor(Color.destructiveColor), style: style)
        let expected = components(UIColor.systemRed, style: style)
        #expect(actual.isClose(to: expected), "\(style.rawValue): \(actual) vs \(expected)")
    }

    @Test("Tracks the light and dark difference of system red (not a fixed RGB)")
    func followsSystemRedAcrossAppearances() {
        let token = Color.destructiveColor
        let lightDiffersFromDarkForSystemRed = !components(UIColor.systemRed, style: .light)
            .isClose(to: components(UIColor.systemRed, style: .dark))
        let tokenLight = components(UIColor(token), style: .light)
        let tokenDark = components(UIColor(token), style: .dark)
        #expect(tokenLight.isClose(to: tokenDark) == !lightDiffersFromDarkForSystemRed)
    }
}
