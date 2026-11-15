//
//  AppButtonStyleTests.swift
//  ChristmasTrackerTests
//
//  TH1-T5: the pure button contract. Primary actions use a custom style (capsule, primary fill, a
//  contrast-tested label); secondary actions are bordered and take the app tint; destructive actions
//  are bordered with the accent tint and the destructive role, never filled.
//

import Foundation
import CoreGraphics
import Testing
@testable import ChristmasTracker

@Suite("App button style")
struct AppButtonStyleTests {

    // MARK: - Specs

    @Test func primarySpec() {
        #expect(AppButtonKind.primary.spec == AppButtonSpec(appearance: .customPrimary, tint: .primary, isDestructiveRole: false))
    }

    @Test func secondarySpec() {
        #expect(AppButtonKind.secondary.spec == AppButtonSpec(appearance: .bordered, tint: .primary, isDestructiveRole: false))
    }

    @Test func destructiveSpec() {
        #expect(AppButtonKind.destructive.spec == AppButtonSpec(appearance: .bordered, tint: .accent, isDestructiveRole: true))
    }

    @Test func destructiveIsNeverCustomPrimary() {
        #expect(AppButtonKind.destructive.spec.appearance != .customPrimary)
    }

    @Test func onlyPrimaryIsCustomPrimary() {
        let custom = AppButtonKind.allCases.filter { $0.spec.appearance == .customPrimary }
        #expect(custom == [.primary])
    }

    @Test func onlyDestructiveHasTheDestructiveRole() {
        let destructive = AppButtonKind.allCases.filter { $0.spec.isDestructiveRole }
        #expect(destructive == [.destructive])
    }

    @Test func allThreeKindsExist() {
        #expect(AppButtonKind.allCases.count == 3)
    }

    // MARK: - Label table

    @Test func lightLabelIsWhite() {
        #expect(PrimaryButtonLabelTable.label(mode: .light) == .white)
    }

    @Test func darkLabelIsTheBackgroundPrimaryToken() {
        #expect(PrimaryButtonLabelTable.label(mode: .dark) == .token(.backgroundPrimary))
    }

    @Test func labelReachesFourPointFiveOnThePrimaryFillInBothModes() {
        for mode in ThemeMode.allCases {
            let fill = ThemeTokenTable.rgb(.primary, mode)
            let label = ThemeStatusLabelTable.rgb(PrimaryButtonLabelTable.label(mode: mode), mode)
            let ratio = ThemeContrast.ratio(label, fill)
            #expect(ratio >= 4.5, "\(mode) ratio \(ratio)")
        }
    }

    @Test func lightLabelIsWhiteOnEvergreen() {
        let ratio = ThemeContrast.ratio(ThemeRGB(red: 255, green: 255, blue: 255), ThemeTokenTable.rgb(.primary, .light))
        #expect(ratio >= 4.5)
    }

    @Test func darkLabelIsNearBlackOnTheDarkEvergreen() {
        let label = ThemeStatusLabelTable.rgb(PrimaryButtonLabelTable.label(mode: .dark), .dark)
        #expect(label == ThemeRGB(hex: "#0F1A17"))
        #expect(ThemeTokenTable.rgb(.primary, .dark) == ThemeRGB(hex: "#4FA58A"))
        #expect(ThemeContrast.ratio(label, ThemeTokenTable.rgb(.primary, .dark)) >= 4.5)
    }

    @Test func whiteOnTheDarkFillWouldFail() {
        // The reason the dark label is not white.
        let white = ThemeRGB(red: 255, green: 255, blue: 255)
        #expect(ThemeContrast.ratio(white, ThemeTokenTable.rgb(.primary, .dark)) < 4.5)
    }

    // MARK: - Height

    @Test func minimumHeightIsFortyFour() {
        #expect(PrimaryButtonLabelTable.minimumHeight == 44)
    }

    @Test func minimumHeightMatchesTheBannerButtonHeight() {
        #expect(PrimaryButtonLabelTable.minimumHeight == InlineErrorBannerState.minimumButtonHeight)
    }
}
