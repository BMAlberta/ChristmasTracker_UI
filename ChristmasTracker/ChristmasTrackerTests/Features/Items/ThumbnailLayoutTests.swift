//
//  ThumbnailLayoutTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T6: thumbnail size and the Dynamic Type rule for the row.
//

import Testing
import SwiftUI
@testable import ChristmasTracker

@Suite("Thumbnail Layout Tests")
struct ThumbnailLayoutTests {

    @Test("The base size is 56")
    func baseSize() {
        #expect(ThumbnailLayout.baseSize == 56)
    }

    @Test("The row thumbnail is hidden exactly at accessibility sizes", arguments: DynamicTypeSize.allCases)
    func rowVisibility(size: DynamicTypeSize) {
        #expect(ThumbnailLayout.rowThumbnailVisible(for: size) == !size.isAccessibilitySize)
    }

    @Test("The maximum size is twice the base")
    func maximumSize() {
        #expect(ThumbnailLayout.maximumSize == 112)
    }

    @Test("A size below the maximum is unchanged")
    func clampedBelow() {
        #expect(ThumbnailLayout.clamped(80) == 80)
    }

    @Test("A size exactly at the maximum is unchanged")
    func clampedExact() {
        #expect(ThumbnailLayout.clamped(112) == 112)
    }

    @Test("A size above the maximum is capped")
    func clampedAbove() {
        #expect(ThumbnailLayout.clamped(150) == 112)
    }

    @Test("Both outcomes occur across the sizes")
    func bothOutcomesOccur() {
        let results = DynamicTypeSize.allCases.map { ThumbnailLayout.rowThumbnailVisible(for: $0) }
        #expect(results.contains(true))
        #expect(results.contains(false))
    }
}
