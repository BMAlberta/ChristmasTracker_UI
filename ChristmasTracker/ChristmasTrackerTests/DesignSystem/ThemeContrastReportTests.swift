//
//  ThemeContrastReportTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T1: prints the measured contrast table so it can be pasted into a report.
//  Line format: CONTRAST|<mode>|<foreground>|<background>|<ratio, 2 decimals>|<threshold kind>
//

import Testing
@testable import ChristmasTracker

@Suite("Theme contrast report")
struct ThemeContrastReportTests {

    @Test("Prints one CONTRAST row for every pair tested, in both modes")
    func printsTable() throws {
        let catalog = try ThemeCatalog.load(from: #filePath)
        let rows = try ThemePairs.measureAll(catalog)
        let lines = rows.map(\.tableLine)
        for line in lines { print(line) }

        #expect(lines.count == ThemePairs.pairsPerMode * 2)
        #expect(Set(lines).count == lines.count, "duplicate rows")
        for mode in ["light", "dark"] {
            let forMode = lines.filter { $0.hasPrefix("CONTRAST|\(mode)|") }
            #expect(forMode.count == ThemePairs.pairsPerMode, "\(mode) rows")
        }
        for kind in ["text", "graphic", "supplementary"] {
            #expect(lines.contains { $0.hasSuffix("|\(kind)") }, "no \(kind) rows")
        }
        for line in lines {
            let fields = line.split(separator: "|", omittingEmptySubsequences: false)
            #expect(fields.count == 6, "bad row: \(line)")
            if fields.count == 6 {
                #expect(fields[0] == "CONTRAST")
                let ratio = String(fields[4])
                #expect(Double(ratio) != nil && ratio.split(separator: ".").last?.count == 2, "bad ratio in \(line)")
            }
        }
    }
}
