//
//  CoreNetworkingContentsScanTests.swift
//  ChristmasTrackerTests
//
//  Story I4b-D: after the legacy API client plumbing is deleted, Core/Networking holds exactly
//  the three live files: NetworkCache.swift (a live session-clearable class), CacheScope.swift
//  (the scope type of its invalidate method) and Repository.swift (the marker protocol of the item,
//  list, member and child repository protocols). Anything else in the folder is a failure.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Core/Networking contents scan Tests")
struct CoreNetworkingContentsScanTests {

    static let expected: Set<String> = ["NetworkCache.swift", "CacheScope.swift", "Repository.swift"]

    /// File names that are present but not expected, and expected names that are missing.
    static func differences(from names: [String]) -> (unexpected: [String], missing: [String]) {
        let present = Set(names.filter { $0 != ".DS_Store" })
        return (present.subtracting(expected).sorted(), expected.subtracting(present).sorted())
    }

    // MARK: Scanner self-proofs

    @Test("The comparison accepts exactly the three live files, in any order")
    func acceptsTheExpectedSet() {
        let result = Self.differences(from: ["Repository.swift", "NetworkCache.swift", "CacheScope.swift"])
        #expect(result.unexpected.isEmpty)
        #expect(result.missing.isEmpty)
    }

    @Test("The comparison flags a planted extra file and ignores .DS_Store")
    func flagsAPlantedExtraFile() {
        let planted = "Planted" + "Client.swift"
        let result = Self.differences(from: Array(Self.expected) + [planted, ".DS_Store"])
        #expect(result.unexpected == [planted])
        #expect(result.missing.isEmpty)
    }

    @Test("The comparison flags a missing live file")
    func flagsAMissingFile() {
        let result = Self.differences(from: ["NetworkCache.swift", "Repository.swift"])
        #expect(result.missing == ["CacheScope.swift"])
        #expect(result.unexpected.isEmpty)
    }

    @Test("The comparison flags a nested folder as unexpected")
    func flagsAFolder() {
        let result = Self.differences(from: Array(Self.expected) + ["Helpers"])
        #expect(result.unexpected == ["Helpers"])
    }

    // MARK: Real folder

    @Test("Core/Networking contains exactly NetworkCache.swift, CacheScope.swift and Repository.swift")
    func folderHoldsExactlyTheLiveFiles() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let folder = tree.file("Core/Networking")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        let result = Self.differences(from: names)
        #expect(result.unexpected.isEmpty, "Remove from Core/Networking: \(result.unexpected)")
        #expect(result.missing.isEmpty, "Missing from Core/Networking: \(result.missing)")
    }

    @Test("The three live files still declare the live types")
    func liveFilesDeclareTheirTypes() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let checks: [(file: String, pattern: String)] = [
            ("Core/Networking/NetworkCache.swift", #"\b(actor|class)\s+NetworkCache\b"#),
            ("Core/Networking/CacheScope.swift", #"\benum\s+CacheScope\b"#),
            ("Core/Networking/Repository.swift", #"\bprotocol\s+Repository\b"#)
        ]
        for check in checks {
            let source = try #require(tree.source(check.file), "\(check.file) is missing")
            let hits = try ItemSourceScan.matchingLines(check.pattern, in: ItemSourceScan.codeOnly(source))
            #expect(hits.count == 1, "\(check.file)")
        }
    }
}
