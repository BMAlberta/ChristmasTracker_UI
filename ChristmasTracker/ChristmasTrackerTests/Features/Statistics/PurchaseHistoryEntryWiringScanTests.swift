//
//  PurchaseHistoryEntryWiringScanTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: the Statistics screen opens the history. Source scans of the wiring in StatsView and
//  SpendByPersonView (the entry row, the destination, the tappable spend rows and their hint).
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history entry wiring scan", .timeLimit(.minutes(1)))
struct PurchaseHistoryEntryWiringScanTests {

    private typealias Scan = PurchaseScreenScan

    private func source(_ path: String, file: String = #filePath) throws -> ScreenSource {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        return try #require(Scan.load(path, tree: tree), "\(path) is missing")
    }

    @Test("StatsView owns the route, pushes the history and passes onOpenHistory down")
    func statsViewWiring() throws {
        let view = try source("Features/Statistics/Views/StatsView.swift")

        #expect(view.bare.contains("@State private var historyRoute: PurchaseHistoryRoute?"))
        #expect(view.bare.contains(".navigationDestination(item: $historyRoute)"))
        #expect(view.bare.contains("PurchaseHistoryView(route:"))
        #expect(Scan.occurrences(of: "onOpenHistory", in: view.bare) >= 4)
        #expect(view.bare.contains("PurchaseHistoryEntryRow"))
        #expect(view.bare.contains("PurchaseHistoryRoute.fromHistoryRow("))
        #expect(view.bare.contains("PurchaseHistoryRoute.fromSpendRow("))
        #expect(view.bare.contains("model.selectedYear"))
        #expect(view.bare.contains("model.yearChoices"))
    }

    @Test("The spend rows are plain buttons that call onSelect, with the hint and the button trait")
    func spendRowWiring() throws {
        let view = try source("Features/Statistics/Views/SpendByPersonView.swift")

        #expect(view.bare.contains("onSelect"))
        #expect(view.bare.contains("Button"))
        #expect(view.bare.contains(".buttonStyle(.plain)"))
        #expect(view.bare.contains(".accessibilityAddTraits(.isButton)"))
        #expect(view.bare.contains(".accessibilityHint("))
        #expect(view.code.contains("Opens purchase history for \\(row.name)"))
        #expect(view.bare.contains(".accessibilityLabel(row.accessibilityLabel)"))
        #expect(!view.bare.contains("onTap" + "Gesture"))
    }

    @Test("The history entry row sits in the stats state view, after the spend list")
    func entryRowPlacement() throws {
        let view = try source("Features/Statistics/Views/StatsView.swift")
        let spend = try #require(view.bare.range(of: "SpendByPersonView("))
        let entry = try #require(view.bare.range(of: "PurchaseHistoryEntryRow {"))

        #expect(spend.lowerBound < entry.lowerBound)
    }

    @Test("The StatsView growth stays small and the file stays under 400 lines")
    func sizes() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath))
        for path in ["Features/Statistics/Views/StatsView.swift", "Features/Statistics/Views/SpendByPersonView.swift"] {
            let text = try #require(tree.source(path))
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count

            #expect(lines < 400, "\(path) has \(lines) lines")
        }
    }
}
