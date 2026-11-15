//
//  PurchaseHistoryViewScanTests.swift
//  ChristmasTrackerTests
//
//  PH1-H3: text scans over the new history views and the Statistics entry row. Layout at accessibility
//  sizes can only be checked at source level here (isAccessibilitySize is used where parts stack).
//  Comments are stripped and string contents blanked before the rules run, like the other view scans.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Purchase history view scan", .timeLimit(.minutes(1)))
struct PurchaseHistoryViewScanTests {

    private typealias Rules = RecordPurchaseViewRules
    private typealias Scan = PurchaseScreenScan

    static let viewFiles = [
        "Features/PurchaseHistory/Views/PurchaseHistoryView.swift",
        "Features/PurchaseHistory/Views/PurchaseHistoryRowView.swift",
        "Features/PurchaseHistory/Views/PurchaseHistoryFilterBar.swift",
        "Features/PurchaseHistory/Views/PurchaseHistoryPreviews.swift",
        "Features/Statistics/Views/PurchaseHistoryEntryRow.swift"
    ]

    private func tree(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    private func sources(file: String = #filePath) throws -> [ScreenSource] {
        let tree = try tree(file: file)
        return Self.viewFiles.compactMap { Scan.load($0, tree: tree) }
    }

    private func source(_ path: String, file: String = #filePath) throws -> ScreenSource {
        try #require(Scan.load(path, tree: try tree(file: file)), "\(path) is missing")
    }

    @Test("All five view files exist")
    func filesExist() throws {
        let tree = try tree()
        let missing = Self.viewFiles.filter { !tree.exists($0) }

        #expect(missing.isEmpty, "Missing: \(missing)")
    }

    @Test("No raw colors, system fonts, numeric padding, spacing or corner radius")
    func tokensOnly() throws {
        let all = try sources()
        #expect(all.count == Self.viewFiles.count)
        let found = all.map { ($0.path, Rules.rawStyleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }

        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("No bare number in a frame, offset or line width")
    func noBareNumbers() throws {
        let all = try sources()
        var found: [(String, [String])] = []
        for source in all {
            let lines = try ItemSourceScan.matchingLines(
                #"\.(frame|offset|lineWidth|cornerRadius)\([^)\n]*[:(]\s*[1-9]|lineWidth:\s*[1-9]"#, in: source.bare
            )
            if !lines.isEmpty { found.append((source.path, lines.map { "line \($0)" })) }
        }

        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("No AnyView, no onTapGesture, no lineLimit, no minimumScaleFactor")
    func noForbiddenViewConstructs() throws {
        let all = try sources()
        var found: [String] = []
        for source in all {
            for word in ["Any" + "View", "onTap" + "Gesture", ".line" + "Limit(", "minimum" + "ScaleFactor"]
            where source.bare.contains(word) {
                found.append("\(source.path): \(word)")
            }
        }

        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test("No force unwrap, no Combine or GCD, no print or Log call")
    func noUnsafeConstructs() throws {
        let all = try sources()
        let found = all.map {
            ($0.path, Rules.forceUnwrapViolations(inBare: $0.bare)
                + Rules.combineAndDispatchViolations(inBare: $0.bare)
                + Rules.logAndIdentifierViolations(inCode: $0.code))
        }.filter { !$0.1.isEmpty }

        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("No Double or Float on money in the views")
    func noDouble() throws {
        let found = try sources().map { ($0.path, Rules.doubleViolations(inBare: $0.bare)) }.filter { !$0.1.isEmpty }

        #expect(found.isEmpty, "\(Scan.describe(found))")
    }

    @Test("One view type per file")
    func oneViewPerFile() throws {
        for source in try sources() {
            let count = try ItemSourceScan.matchingLines(#"\bstruct\s+\w+\s*(<[^>]*>)?\s*:\s*[^{\n]*\bView\b"#, in: source.bare).count

            #expect(count <= 1, "\(source.path) declares \(count) views")
        }
    }

    @Test("Every new file is under 400 lines")
    func fileSize() throws {
        let tree = try tree()
        for path in Self.viewFiles {
            let text = try #require(tree.source(path), "\(path) is missing")
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count

            #expect(lines < 400, "\(path) has \(lines) lines")
        }
    }

    // MARK: Screen content

    @Test("The screen is built in .task from the environment service, with the route's year and person")
    func screenBuild() throws {
        let view = try source("Features/PurchaseHistory/Views/PurchaseHistoryView.swift")

        #expect(view.bare.contains("struct PurchaseHistoryView"))
        #expect(view.bare.contains("route: PurchaseHistoryRoute"))
        #expect(view.bare.contains("@Environment(\\.purchaseHistoryService)"))
        #expect(view.bare.contains("@Environment(\\.authenticationService)"))
        #expect(view.bare.contains("PurchaseHistoryModel("))
        #expect(view.bare.contains("defaultYear: route.year"))
        #expect(view.bare.contains("preselectedRecipient: route.recipient"))
        #expect(view.bare.contains(".task"))
        #expect(view.bare.contains("@State private var"))
        #expect(view.code.contains(".navigationTitle(\"Purchase History\")"))
    }

    @Test("The screen refreshes, reconciles the session, pages from the row and opens the purchase screen")
    func screenWiring() throws {
        let view = try source("Features/PurchaseHistory/Views/PurchaseHistoryView.swift")

        for needle in [
            ".refreshable", "model.refresh()", "sessionGeneration", "reconcileSession()", "InlineErrorBanner",
            "model.tryAgain()", "model.dismissStaleBanner()", "model.retryNextPage()", "model.clearFilters()",
            "loadNextPageIfNeeded(currentRowId:", "returnedFromPurchase()", "LazyVStack", "ManagePurchaseView(",
            "navigationDestination(item:", "openedPurchase", "currentUserId", "emptyKind", "isLoadingNextPage",
            "nextPageFailed", "ForEach(model.rows)"
        ] {
            #expect(view.bare.contains(needle), "PurchaseHistoryView does not mention \(needle)")
        }
        #expect(view.code.contains("No purchases yet."))
        #expect(view.code.contains("No purchases match these filters."))
        #expect(view.code.contains("Couldn't load more. Try again."))
        #expect(view.code.contains("Clear filters"))
    }

    @Test("The row and the filter bar stack at accessibility Dynamic Type sizes")
    func accessibilitySizes() throws {
        for path in [
            "Features/PurchaseHistory/Views/PurchaseHistoryRowView.swift",
            "Features/PurchaseHistory/Views/PurchaseHistoryFilterBar.swift"
        ] {
            let view = try source(path)

            #expect(view.bare.contains("isAccessibilitySize"), "\(path) never checks isAccessibilitySize")
            #expect(view.bare.contains("dynamicTypeSize"))
        }
    }

    @Test("The row is one button-trait element with the combined label and an untruncated amount")
    func rowAccessibility() throws {
        let row = try source("Features/PurchaseHistory/Views/PurchaseHistoryRowView.swift")

        #expect(row.bare.contains(".accessibilityElement(children: .ignore)")
                || row.bare.contains(".accessibilityElement(children: .combine)"))
        #expect(row.bare.contains(".accessibilityLabel("))
        #expect(row.bare.contains(".accessibilityAddTraits(.isButton)"))
        #expect(row.bare.contains("StatusDotLabel(shipping:"))
        #expect(row.bare.contains("PurchaseHistoryRowPresentation"))
        #expect(row.bare.contains("fixedSize(horizontal: false, vertical: true)"))
    }

    @Test("The filter bar has three menus with pickers, labels and values, and a Clear filters button")
    func filterBar() throws {
        let bar = try source("Features/PurchaseHistory/Views/PurchaseHistoryFilterBar.swift")

        #expect(Scan.occurrences(of: "Menu", in: bar.bare) >= 3)
        #expect(Scan.occurrences(of: "Picker(", in: bar.bare) >= 3)
        #expect(Scan.occurrences(of: ".accessibilityLabel(", in: bar.bare) >= 3)
        #expect(Scan.occurrences(of: ".accessibilityValue(", in: bar.bare) >= 3)
        #expect(bar.bare.contains("model.hasActiveFilters"))
        #expect(bar.bare.contains("model.clearFilters()"))
        #expect(bar.bare.contains("model.select("))
        #expect(bar.bare.contains("ScrollView(.horizontal"))
        #expect(bar.code.contains("Clear filters"))
    }

    @Test("The previews cover the loaded, loading, empty, no-match, failure and large dark states")
    func previews() throws {
        let previews = try source("Features/PurchaseHistory/Views/PurchaseHistoryPreviews.swift")

        #expect(Scan.occurrences(of: "#Preview", in: previews.bare) >= 7)
        #expect(previews.bare.contains("MockPurchaseHistoryRepository"))
        #expect(previews.bare.contains(".dark"))
        #expect(previews.bare.contains(".accessibility"))
    }

    @Test("The entry row is a plain Button with the Purchase History label and a minimum height")
    func entryRow() throws {
        let row = try source("Features/Statistics/Views/PurchaseHistoryEntryRow.swift")

        #expect(row.bare.contains("struct PurchaseHistoryEntryRow"))
        #expect(row.bare.contains("Button"))
        #expect(row.bare.contains("minimumButtonHeight"))
        #expect(row.bare.contains(".appCard()"))
        #expect(row.code.contains("\"Purchase History\""))
        #expect(row.bare.contains(".accessibilityAddTraits(.isButton)"))
        #expect(row.code.contains("chevron.right"))
    }
}
