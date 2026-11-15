//
//  AppCardStyleTests.swift
//  ChristmasTrackerTests
//
//  TH1-T4: the card style constants and the inline error banner tint.
//

import SwiftUI
import Testing
@testable import ChristmasTracker

@Suite("AppCardStyle constants")
struct AppCardStyleTests {

    @Test func cornerRadiusIsTheMediumSpacing() {
        #expect(AppCardStyle.cornerRadius == AppSpacing.md)
    }

    @Test func borderWidthIsAHairlineOfOnePoint() {
        #expect(AppCardStyle.borderWidth == 1)
    }

    @Test func paddingIsTheMediumSpacing() {
        #expect(AppCardStyle.padding == AppSpacing.md)
    }

    @Test func appCardModifierComposesOnAView() {
        // Compile-level contract: `appCard()` exists on View and returns a View.
        let view: some View = Text("x").appCard()
        _ = view
    }

    @Test func inlineErrorBannerBackgroundOpacityIsTwelvePercent() {
        #expect(InlineErrorBannerStyle.backgroundOpacity == 0.12)
    }
}
