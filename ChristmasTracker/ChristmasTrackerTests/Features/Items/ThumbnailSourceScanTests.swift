//
//  ThumbnailSourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story TH1-T6: text scans over the app sources (comments stripped) that keep image loading,
//  the shared URL cache, logging and wiring where the story puts them.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Thumbnail source scan Tests")
struct ThumbnailSourceScanTests {

    private let thumbnailFile = "Features/Items/Components/ItemThumbnail.swift"
    private let urlFile = "Features/Items/Components/ThumbnailURL.swift"
    private let clearableFile = "Features/Authentication/Services/ImageCacheClearable.swift"
    private let sessionManagerFile = "Features/Authentication/Services/SessionManager.swift"
    private let sessionClearableFile = "Features/Authentication/Services/SessionClearable.swift"

    private func makeSUT() throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: #filePath), "App source tree not found")
    }

    private func code(_ tree: ItemSourceTree, _ relative: String) throws -> String {
        let source = try #require(tree.source(relative), "Missing source file \(relative)")
        return ItemSourceScan.codeOnly(source)
    }

    private func filesContaining(_ token: String, in tree: ItemSourceTree, under prefix: String = "") -> [String] {
        tree.all.compactMap { url -> String? in
            let relative = tree.relativePath(url)
            guard relative.hasPrefix(prefix), let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return ItemSourceScan.codeOnly(source).contains(token) ? relative : nil
        }
    }

    @Test("AsyncImage appears only in ItemThumbnail.swift")
    func asyncImageOnlyInThumbnail() throws {
        let tree = try makeSUT()
        #expect(filesContaining("AsyncImage", in: tree) == [thumbnailFile])
    }

    @Test("No URLSession image loading appears under Features/Items", arguments: ["dataTask", "data(from:"])
    func noManualImageLoading(token: String) throws {
        let tree = try makeSUT()
        #expect(filesContaining(token, in: tree, under: "Features/Items/").isEmpty)
    }

    @Test("URLCache.shared appears only in the clearer file and SessionManager")
    func urlCacheSharedConfined() throws {
        let tree = try makeSUT()
        let found = Set(filesContaining("URLCache.shared", in: tree))
        let allowed: Set<String> = [clearableFile, sessionManagerFile]
        #expect(found.isSubset(of: allowed), "Unexpected URLCache.shared use: \(found.subtracting(allowed).sorted())")
        #expect(found.contains(clearableFile))
    }

    @Test("The thumbnail files contain no logging or reporting",
          arguments: ["Logger", "print(", "os_log", "SentrySDK", "captureMessage", "NSLog"])
    func noLogging(token: String) throws {
        let tree = try makeSUT()
        for file in [thumbnailFile, urlFile] {
            #expect(!(try code(tree, file)).contains(token), "\(file) must not contain \(token)")
        }
    }

    @Test("ItemThumbnail.swift hides itself from accessibility, scales and uses continuous corners",
          arguments: [".accessibilityHidden(true)", "@ScaledMetric", ".continuous"])
    func thumbnailTraits(token: String) throws {
        let tree = try makeSUT()
        #expect(try code(tree, thumbnailFile).contains(token))
    }

    @Test("The row and the detail view use ItemThumbnail",
          arguments: ["Features/Items/Components/ItemRow.swift", "Features/Items/Views/ItemDetailView.swift"])
    func screensUseThumbnail(file: String) throws {
        let tree = try makeSUT()
        #expect(try code(tree, file).contains("ItemThumbnail("))
    }

    @Test("The row hides the thumbnail through ThumbnailLayout.rowThumbnailVisible")
    func rowUsesLayoutRule() throws {
        let tree = try makeSUT()
        #expect(try code(tree, "Features/Items/Components/ItemRow.swift").contains("ThumbnailLayout.rowThumbnailVisible"))
    }

    @Test("The app registers ImageCacheClearable(cache: exactly once through register(")
    func appRegistersOnce() throws {
        let tree = try makeSUT()
        let app = try code(tree, "ChristmasTrackerApp.swift")
        #expect(app.components(separatedBy: "ImageCacheClearable(cache:").count - 1 == 1)
        #expect(app.contains("register("))
    }

    @Test("makeProductionClearables stays unchanged and does not mention ImageCacheClearable")
    func productionClearablesUnchanged() throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, sessionClearableFile)).contains("ImageCacheClearable"))
    }
}
