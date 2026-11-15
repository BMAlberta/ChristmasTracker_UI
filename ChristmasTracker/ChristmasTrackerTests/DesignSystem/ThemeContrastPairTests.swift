//
//  ThemeContrastPairTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1, revised in PAL1-P1: contrast of the real catalog values (read from the colorset
//  JSON). Thresholds: TEXT 4.5, GRAPHIC 3.0. Every text pair must reach 4.5 (there is no exception
//  list for text any more). Supplementary graphic pairs (status and budget fills against surfaces)
//  should reach 3.0 because a state is always also stated in words; the light status fills that
//  cannot are exactly the ones `ThemeEdgeRule` marks for a graphic edge, and the one pinned
//  exception is the light budgetWarning fill, which no view uses since PAL1-P2.
//

import Testing
@testable import ChristmasTracker

@Suite("Theme contrast Tests")
struct ThemeContrastPairTests {

    private static let textThreshold = 4.5
    private static let graphicThreshold = 3.0

    private struct Pinned {
        let mode: String
        let foreground: String
        let background: String
        let floor: Double

        func matches(_ m: ThemePairMeasurement) -> Bool {
            m.mode == mode && m.foreground == foreground && m.background == background
        }

        var name: String { "\(foreground) on \(background) in \(mode)" }
    }

    /// The light budgetWarning fill (#D6B25E) stays below 3.0 on the page and card backgrounds. It is
    /// pinned, not excused. Since PAL1-P2 the near-limit bar uses budgetWarningBar, so no view draws
    /// budgetWarning (BudgetWarningBarScanTests checks that `budgetWarningColor` is referenced by no
    /// view file); the token and its colorset stay. Floors are the measured values rounded down to
    /// 2 decimals.
    private static let budgetWarningLightExceptions: [Pinned] = [
        Pinned(mode: "light", foreground: "budgetWarning", background: "surface", floor: 2.02),
        Pinned(mode: "light", foreground: "budgetWarning", background: "backgroundPrimary", floor: 1.92)
    ]

    private func measurements(_ kind: ThemePairKind) throws -> [ThemePairMeasurement] {
        let catalog = try ThemeCatalog.load(from: #filePath)
        return try ThemePairs.measureAll(catalog).filter { $0.kind == kind }
    }

    @Test("All pairs are measured")
    func pairCounts() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        let all = try ThemePairs.measureAll(catalog)
        #expect(all.count == ThemePairs.pairsPerMode * ThemeMode.allCases.count)
    }

    // MARK: TEXT

    @Test("Every text pair reaches 4.5 with no exceptions")
    func textPairs() throws {
        let text = try measurements(.text)
        #expect(text.count == 36)
        for m in text {
            #expect(m.ratio >= Self.textThreshold, "text pair below 4.5: \(m.description)")
        }
    }

    @Test("The former text exceptions now measure as the brief says (muted 4.67, dark accent 4.86) and pass 4.5")
    func formerExceptionsMeasure() throws {
        let text = try measurements(.text)
        func ratio(_ mode: String, _ fg: String, _ bg: String) throws -> Double {
            try #require(text.first { $0.mode == mode && $0.foreground == fg && $0.background == bg }).ratio
        }
        // Rounded to 2 decimals these measure 4.67 and 4.86; the floors are the unrounded values rounded down.
        #expect(try ratio("light", "textMuted", "backgroundSecondary") >= 4.66)
        #expect(try ratio("dark", "accent", "surface") >= 4.85)
        #expect(try ratio("dark", "budgetOver", "surface") >= 4.85)
    }

    // MARK: GRAPHIC

    @Test("Graphic pairs (primary, highlightStrong and budgetWarningBar against surfaces) reach 3.0")
    func graphicPairs() throws {
        let graphic = try measurements(.graphic)
        // Per mode: primary x2, highlightStrong x2, budgetWarningBar x3; two modes.
        #expect(graphic.count == 14)
        for m in graphic {
            #expect(m.ratio >= Self.graphicThreshold, "graphic pair below 3.0: \(m.description)")
        }
    }

    @Test("highlightStrong is measured on backgroundPrimary and surface, budgetWarningBar on three backgrounds, both modes")
    func newGraphicPairsPresent() throws {
        let graphic = try measurements(.graphic)
        for mode in ["light", "dark"] {
            for background in ["backgroundPrimary", "surface"] {
                #expect(graphic.contains { $0.mode == mode && $0.foreground == "highlightStrong" && $0.background == background },
                        "no highlightStrong on \(background) in \(mode)")
            }
            for background in ["backgroundPrimary", "surface", "backgroundSecondary"] {
                #expect(graphic.contains { $0.mode == mode && $0.foreground == "budgetWarningBar" && $0.background == background },
                        "no budgetWarningBar on \(background) in \(mode)")
            }
        }
    }

    // MARK: SUPPLEMENTARY GRAPHIC

    @Test("The computed edge set is exactly statusPartial and statusGifted today")
    func edgeSetIsPartialAndGifted() {
        #expect(ThemeEdgeRule.fillsNeedingEdge() == [.statusPartial, .statusGifted])
    }

    @Test("Every light status fill under 3.0 on backgroundPrimary or surface (measured from the catalog) is in the edge set")
    func everyWeakFillHasAnEdge() throws {
        let supplementary = try measurements(.supplementary)
        let edge = ThemeEdgeRule.fillsNeedingEdge()
        for fill in ThemeTestSupport.statusFills {
            let weak = supplementary.contains {
                $0.mode == "light" && $0.foreground == fill.rawValue
                    && ($0.background == "backgroundPrimary" || $0.background == "surface")
                    && $0.ratio < Self.graphicThreshold
            }
            if weak {
                #expect(edge.contains(fill), "\(fill.rawValue) is under 3.0 in light and has no edge")
            }
        }
    }

    @Test("Supplementary pairs reach 3.0 except the light fills in the edge set and the pinned budgetWarning pairs")
    func supplementaryPairs() throws {
        let edge = Set(ThemeEdgeRule.fillsNeedingEdge().map(\.rawValue))
        for m in try measurements(.supplementary) {
            if m.mode == "light" && edge.contains(m.foreground) { continue }
            if Self.budgetWarningLightExceptions.contains(where: { $0.matches(m) }) { continue }
            #expect(m.ratio >= Self.graphicThreshold, "supplementary pair below 3.0 and not excluded: \(m.description)")
        }
    }

    @Test("Edge-set fills are still under 3.0 against both backgrounds in light (the rule is not stale)")
    func edgeFillsAreWeak() throws {
        let supplementary = try measurements(.supplementary)
        for fill in ThemeEdgeRule.fillsNeedingEdge() {
            for background in ["backgroundPrimary", "surface"] {
                let m = try #require(supplementary.first {
                    $0.mode == "light" && $0.foreground == fill.rawValue && $0.background == background
                })
                #expect(m.ratio < Self.graphicThreshold, "now reaches 3.0: \(m.description)")
            }
        }
    }

    @Test("Each pinned budgetWarning pair is still below 3.0, at or above its floor, and names a real pair")
    func budgetWarningExceptionsPinned() throws {
        let supplementary = try measurements(.supplementary)
        for pinned in Self.budgetWarningLightExceptions {
            let m = try #require(supplementary.first { pinned.matches($0) }, "no such pair: \(pinned.name)")
            #expect(m.ratio < Self.graphicThreshold, "now reaches 3.0, remove the exception: \(m.description)")
            #expect(m.ratio >= pinned.floor, "below its floor \(pinned.floor): \(m.description)")
        }
    }
}
