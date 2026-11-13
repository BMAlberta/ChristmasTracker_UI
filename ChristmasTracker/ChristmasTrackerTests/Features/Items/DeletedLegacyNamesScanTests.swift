//
//  DeletedLegacyNamesScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-D: the legacy purchase stack, the legacy gift item type, the old API client plumbing
//  and its mocks are deleted. This scan proves no production or test source still names any of
//  the deleted types, the deleted files are gone, and the `apiClient` environment value is gone.
//  Comments are ignored (`ItemSourceScan.codeOnly`).
//
//  Self-protection: every name is built from split literals (`name("A", "B")`), so this file never
//  holds a deleted name as one token, and this file is also excluded by path.
//
//  Live look-alikes that must NOT be flagged (proved below with in-memory strings):
//   - `ItemPurchaseRow` and other longer identifiers (word boundaries);
//   - `OpenAPIRuntime`, `OpenAPIURLSession` (not the same word as the client protocol);
//   - generated types with the `Components.Schemas.` prefix, such as the generated shipping
//     status and the generated purchase summary (a negative lookbehind on the prefix).
//
//  Not scanned on purpose: the bare word for the legacy purchase model (too generic; the
//  generated `Components.Schemas.` purchase type and the live domain words use it), and the
//  device fingerprint service (deleted in I4b; it is not in the scan list).
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Deleted legacy names scan Tests")
struct DeletedLegacyNamesScanTests {

    private static func name(_ parts: String...) -> String { parts.joined() }

    /// Deleted identifiers (types, protocols, the environment value).
    static let deletedNames: [String] = [
        name("Gift", "Item"),
        name("MockItem", "Data"),
        name("MockPurchase", "Data"),
        name("PurchaseHistory", "View"),
        name("PurchaseDetail", "View"),
        name("PurchaseEdit", "View"),
        name("EditPurchase", "View"),
        name("Purchase", "Row"),
        name("Purchase", "Repository"),
        name("NetworkPurchase", "Repository"),
        name("MockPurchase", "Repository"),
        name("Purchase", "Person"),
        name("Shipping", "Status"),
        name("CreatePurchase", "Request"),
        name("UpdatePurchase", "Request"),
        name("Purchase", "Response"),
        name("Purchases", "Response"),
        name("Purchases", "Data"),
        name("CreatePurchase", "Response"),
        name("CreatePurchase", "Data"),
        name("Purchase", "Warning"),
        name("Warning", "Details"),
        name("API", "Client"),
        name("NetworkAPI", "Client"),
        name("MockAPI", "Client"),
        name("InertAPI", "Client"),
        name("HTTP", "Method"),
        name("api", "Client")
    ]

    /// Deleted files, relative to the app source folder.
    private static let deletedFiles: [String] = [
        "Features/Purchases/Views/" + name("PurchaseHistory", "View.swift"),
        "Features/Purchases/Views/" + name("PurchaseDetail", "View.swift"),
        "Features/Purchases/Views/" + name("PurchaseEdit", "View.swift"),
        "Features/Purchases/Components/" + name("Purchase", "Row.swift"),
        "Features/Purchases/Repositories/" + name("Purchase", "Repository.swift"),
        "Features/Purchases/Repositories/" + name("NetworkPurchase", "Repository.swift"),
        "Features/Purchases/Repositories/" + name("MockPurchase", "Repository.swift"),
        "Core/Models/" + name("Purchase", ".swift"),
        "Core/Models/" + name("Gift", "Item.swift"),
        "Features/Items/Repositories/" + name("MockItem", "Data.swift"),
        "Core/Networking/" + name("API", "Client.swift"),
        "Core/Networking/" + name("HTTP", "Method.swift"),
        "Core/Networking/" + name("NetworkAPI", "Client.swift"),
        "Core/Networking/" + name("MockAPI", "Client.swift"),
        "Core/Extensions/" + name("EnvironmentValues+API", "Client.swift")
    ]

    private struct Exclusion {
        let path: String      // relative to the Xcode project folder, as SourceFile.relative
        let reason: String
    }

    private static let exclusions: [Exclusion] = [
        Exclusion(path: "ChristmasTrackerTests/Features/Items/DeletedLegacyNamesScanTests.swift",
                  reason: "This scan; it holds the names as pattern data (also split into literals)."),
        Exclusion(path: "ChristmasTrackerTests/Features/Purchases/RecordPurchaseViewScanRules.swift",
                  reason: "Its rule pattern lists the legacy names so that the new record views can never use them."),
        Exclusion(path: "ChristmasTrackerTests/Features/Purchases/RecordPurchaseViewScanTests.swift",
                  reason: "Its self-proof inputs plant legacy names to prove the view rule fires."),
        Exclusion(path: "ChristmasTrackerTests/Features/Purchases/ManagePurchaseViewScanTests.swift",
                  reason: "Its rule pattern forbids the legacy view names in the new manage screen."),
        Exclusion(path: "ChristmasTrackerTests/Features/Purchases/PurchaseSourceScanTests.swift",
                  reason: "Its legacy-file set names the legacy file names it excludes from the new-source scans.")
    ]

    // MARK: Scanner

    /// A deleted name not preceded by the generated `Schemas.` prefix, on word boundaries.
    private static func pattern(for names: [String]) -> String {
        "(?<!Schemas\\.)\\b(" + names.joined(separator: "|") + ")\\b"
    }

    private static func hits(in source: String, names: [String] = deletedNames) throws -> [Int] {
        try ItemSourceScan.matchingLines(pattern(for: names), in: ItemSourceScan.codeOnly(source))
    }

    private func makeSUT(file: String = #filePath) throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
    }

    // MARK: Scanner self-proofs

    @Test("The scanner finds every deleted name planted in code", arguments: DeletedLegacyNamesScanTests.deletedNames)
    func scannerFindsEachName(planted: String) throws {
        #expect(try Self.hits(in: "let value: \(planted)").count == 1, "\(planted)")
        #expect(try Self.hits(in: "let value = \(planted)(x: 1)").count == 1, "\(planted)")
    }

    @Test("The scanner reports the line of a match")
    func scannerReportsLines() throws {
        let source = "let a = 1\nlet b: \(Self.name("Gift", "Item"))\nlet c = 3"
        #expect(try Self.hits(in: source) == [2])
    }

    @Test("The scanner ignores comments")
    func scannerIgnoresComments() throws {
        let planted = Self.name("Mock", "Item", "Data")
        let sources = [
            "// \(planted) was removed",
            "/* block mentions \(planted) */",
            "let a = 1 // trailing \(planted)",
            "/* multi\nline \(planted)\n*/\nlet b = 2"
        ]
        for source in sources {
            #expect(source.contains(planted))
            #expect(try Self.hits(in: source).isEmpty, "\(source)")
        }
    }

    @Test("The scanner does not flag live look-alikes", arguments: [
        "ItemPurchaseRow(state: state)",
        "struct ItemPurchaseRowState {}",
        "import OpenAPIRuntime",
        "import OpenAPIURLSession",
        "let status: Components.Schemas.ShippingStatus",
        "let sum: Components.Schemas.PurchaseSummary",
        "func map(_ p: Components.Schemas.PurchaseResponse) {}",
        "let status: PurchaseShippingStatus",
        "let x: PurchaseManaging",
        "let n = GiftItemCell()",
        "let m = MyAPIClientFactory()",
        "let h = HTTPMethods",
        "let c = apiClients"
    ])
    func scannerDoesNotFlagLookAlikes(source: String) throws {
        #expect(try Self.hits(in: source).isEmpty, "\(source)")
    }

    @Test("The scanner flags the bare name but not the generated prefixed one on the same line")
    func prefixOnlyProtectsTheGeneratedType() throws {
        let bare = Self.name("Shipping", "Status")
        #expect(try Self.hits(in: "let a: \(bare), b: Components.Schemas.\(bare)").count == 1)
        #expect(try Self.hits(in: "let a: Components.Schemas.\(bare)").isEmpty)
    }

    @Test("Exclusions each carry a reason and are exactly the known data files")
    func exclusionsAreStated() {
        for entry in Self.exclusions {
            #expect(!entry.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(entry.path)")
        }
        #expect(Self.exclusions.count == 5)
    }

    @Test("Production and test files are both enumerated, and every exclusion exists")
    func treeCoversProductionAndTests() throws {
        let files = try makeSUT().productionAndTestFiles()
        let relatives = Set(files.map(\.relative))
        #expect(relatives.contains("ChristmasTracker/ChristmasTrackerApp.swift"))
        #expect(relatives.contains("ChristmasTrackerTests/Features/Items/DeletedLegacyNamesScanTests.swift"))
        for entry in Self.exclusions {
            #expect(relatives.contains(entry.path), "exclusion does not exist: \(entry.path)")
        }
    }

    // MARK: Real sources

    @Test("No production or test source (outside the stated exclusions) names a deleted type or the apiClient value")
    func noDeletedNameInCode() throws {
        let files = try makeSUT().productionAndTestFiles()
        let excluded = Set(Self.exclusions.map(\.path))
        let scanned = files.filter { !excluded.contains($0.relative) }
        #expect(scanned.count > 100)
        var found: [String] = []
        for file in scanned {
            let source = try String(contentsOf: file.url, encoding: .utf8)
            for line in try Self.hits(in: source) {
                found.append("\(file.relative):\(line)")
            }
        }
        #expect(found.isEmpty, "Deleted names still referenced:\n\(found.joined(separator: "\n"))")
    }

    @Test("The deleted files no longer exist")
    func deletedFilesAreGone() throws {
        let tree = try makeSUT()
        let stillThere = Self.deletedFiles.filter(tree.exists)
        #expect(stillThere.isEmpty, "Files that must be deleted: \(stillThere)")
    }

    @Test("The deleted test files no longer exist")
    func deletedTestFilesAreGone() throws {
        let relatives = Set(try makeSUT().productionAndTestFiles().map(\.relative))
        #expect(!relatives.contains("ChristmasTrackerTests/Core/Networking/" + Self.name("MockAPI", "ClientTests.swift")))
        #expect(!relatives.contains("ChristmasTrackerTests/Features/Items/" + Self.name("Gift", "ItemTrimScanTests.swift")))
        #expect(!relatives.contains("ChristmasTrackerTests/Features/Items/" + Self.name("LegacyGift", "ItemScanTests.swift")))
    }

    @Test("ItemStatus moved to its own file before the gift item file was deleted")
    func itemStatusLivesInItsOwnFile() throws {
        let tree = try makeSUT()
        let source = try #require(tree.source("Core/Models/ItemStatus.swift"), "Core/Models/ItemStatus.swift is missing")
        let hits = try ItemSourceScan.matchingLines(#"\benum ItemStatus\b"#, in: ItemSourceScan.codeOnly(source))
        #expect(hits.count == 1)
    }
}
