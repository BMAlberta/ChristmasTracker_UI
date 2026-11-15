//
//  ThemeContrastPairTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: contrast of the real catalog values (read from the colorset JSON). Thresholds:
//  TEXT 4.5, GRAPHIC 3.0. Supplementary graphic pairs (status and budget fills against surfaces)
//  should reach 3.0, because a state is always also stated in words; those that cannot are on an
//  explicit list with a pinned floor. Two text pairs are known and pinned (brief decision 7).
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

    /// Text pairs that are known to fall under 4.5. Floors are placeholders for the implementer to
    /// tighten to the measured value rounded down to 2 decimals.
    private static let knownTextExceptions: [Pinned] = [
        Pinned(mode: "light", foreground: "textMuted", background: "backgroundSecondary", floor: 4.21),
        Pinned(mode: "dark", foreground: "accent", background: "surface", floor: 4.38),
        // Same color pair as the accent exception above (budgetOver is #E06A75 in dark, identical to accent).
        Pinned(mode: "dark", foreground: "budgetOver", background: "surface", floor: 4.38)
    ]

    /// Supplementary graphic pairs that measure under 3.0. Floors are placeholders (1.9) for the
    /// implementer to tighten to the measured value rounded down to 2 decimals.
    private static let supplementaryGraphicExceptions: [Pinned] = [
        Pinned(mode: "light", foreground: "statusPartial", background: "surface", floor: 2.02),
        Pinned(mode: "light", foreground: "statusPartial", background: "backgroundPrimary", floor: 1.92),
        Pinned(mode: "light", foreground: "statusGifted", background: "surface", floor: 2.41),
        Pinned(mode: "light", foreground: "statusGifted", background: "backgroundPrimary", floor: 2.29),
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

    @Test("Text pairs reach 4.5 unless pinned as a known exception")
    func textPairs() throws {
        for m in try measurements(.text) where !Self.knownTextExceptions.contains(where: { $0.matches(m) }) {
            #expect(m.ratio >= Self.textThreshold, "text pair below 4.5 with no exception: \(m.description)")
        }
    }

    @Test("Each known text exception is below 4.5, at or above its floor, and names a real pair")
    func knownTextExceptionsPinned() throws {
        let text = try measurements(.text)
        for pinned in Self.knownTextExceptions {
            let m = try #require(text.first { pinned.matches($0) }, "no such pair: \(pinned.name)")
            #expect(m.ratio < Self.textThreshold, "now reaches 4.5, remove the exception: \(m.description)")
            #expect(m.ratio >= pinned.floor, "below its floor \(pinned.floor): \(m.description)")
        }
    }

    // MARK: GRAPHIC

    @Test("Graphic pairs (primary tint against surface and background) reach 3.0")
    func graphicPairs() throws {
        let graphic = try measurements(.graphic)
        #expect(graphic.count == 4)
        for m in graphic {
            #expect(m.ratio >= Self.graphicThreshold, "graphic pair below 3.0: \(m.description)")
        }
    }

    // MARK: SUPPLEMENTARY GRAPHIC

    @Test("Supplementary pairs reach 3.0 unless on the exception list")
    func supplementaryPairs() throws {
        for m in try measurements(.supplementary) where !Self.supplementaryGraphicExceptions.contains(where: { $0.matches(m) }) {
            #expect(m.ratio >= Self.graphicThreshold, "supplementary pair below 3.0 and not listed: \(m.description)")
        }
    }

    @Test("Each supplementary exception is still below 3.0, at or above its floor, and names a real pair")
    func supplementaryExceptionsPinned() throws {
        let supplementary = try measurements(.supplementary)
        for pinned in Self.supplementaryGraphicExceptions {
            let m = try #require(supplementary.first { pinned.matches($0) }, "no such pair: \(pinned.name)")
            #expect(m.ratio < Self.graphicThreshold, "now reaches 3.0, remove the exception: \(m.description)")
            #expect(m.ratio >= pinned.floor, "below its floor \(pinned.floor): \(m.description)")
        }
    }
}
