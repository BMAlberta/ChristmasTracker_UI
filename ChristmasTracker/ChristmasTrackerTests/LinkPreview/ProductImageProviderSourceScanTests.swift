//
//  ProductImageProviderSourceScanTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P4 (decisions 12 to 14): source scans over the app target.
//   - `import LinkPresentation` and `value(forKey:` each appear in exactly one app file,
//     Features/LinkPreview/Providers/LinkPresentationProductImageProvider.swift;
//   - that file carries the marker `APPSTORE-BLOCKER: non-public key path` (checked on the raw text,
//     the marker is a comment);
//   - every `value(forKey:` there has a `responds(to:` within the previous 6 lines, and there are at
//     least as many guards as reads;
//   - the file uses withTaskCancellationHandler and a `.cancel()` call (cancelling the task cancels the
//     LPMetadataProvider) and sets `timeout`;
//   - the `imageMetadata` key path appears in no other app file (comments excluded).
//
//  URL-in-log rules are NOT repeated: LinkPreviewSourceScanTests already scans every file under
//  Features/LinkPreview/, the new Providers/ files included. The new files are asserted to exist here
//  so none of these scans is vacuous.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Product image provider source scan", .timeLimit(.minutes(1)))
struct ProductImageProviderSourceScanTests {

    private static let providerPath = "Features/LinkPreview/Providers/LinkPresentationProductImageProvider.swift"

    private func tree() throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
    }

    private func providerSource(_ tree: ItemSourceTree) throws -> String {
        try #require(tree.source(Self.providerPath), "\(Self.providerPath) must exist")
    }

    /// Relative paths of the app files whose code (comments stripped) matches `pattern`.
    private func filesMatching(_ pattern: String, in tree: ItemSourceTree) throws -> [String] {
        var found: [String] = []
        for url in tree.all {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if try ItemSourceScan.matchingLines(pattern, in: ItemSourceScan.codeOnly(raw)).isEmpty == false {
                found.append(tree.relativePath(url))
            }
        }
        return found
    }

    @Test("The provider files exist")
    func filesExist() throws {
        let tree = try tree()
        for relative in [
            "Features/LinkPreview/Providers/ProductImageProviding.swift",
            Self.providerPath,
            "Features/LinkPreview/Providers/MockProductImageProvider.swift",
            "Features/LinkPreview/Providers/InertProductImageProvider.swift",
            "Features/LinkPreview/Domain/ProductImageURLNormalizer.swift"
        ] {
            #expect(tree.exists(relative), "missing \(relative)")
        }
    }

    @Test("import LinkPresentation appears in exactly one app file: the provider")
    func importIsIsolated() throws {
        let files = try filesMatching(#"import\s+LinkPresentation\b"#, in: try tree())

        #expect(files == [Self.providerPath], "found in: \(files)")
    }

    @Test("value(forKey: appears in exactly one app file: the provider")
    func kvcIsIsolated() throws {
        let files = try filesMatching(#"value\(forKey:"#, in: try tree())

        #expect(files == [Self.providerPath], "found in: \(files)")
    }

    @Test("the imageMetadata key path appears in no other app file")
    func keyPathIsIsolated() throws {
        let files = try filesMatching("imageMetadata", in: try tree()).filter { $0 != Self.providerPath }

        #expect(files.isEmpty, "found in: \(files)")
    }

    @Test("the provider carries the App Store blocker marker")
    func marker() throws {
        let raw = try providerSource(try tree())

        #expect(raw.contains("APPSTORE-BLOCKER: non-public key path"))
    }

    @Test("every value(forKey: has a responds(to: guard within the previous 6 lines")
    func everyReadIsGuarded() throws {
        let code = ItemSourceScan.codeOnly(try providerSource(try tree()))
        let lines = code.components(separatedBy: "\n")
        let reads = lines.indices.filter { lines[$0].contains("value(forKey:") }
        let guards = lines.filter { $0.contains("responds(to:") }.count

        try #require(reads.isEmpty == false, "the provider must read the key paths with value(forKey:")
        #expect(guards >= reads.count, "\(guards) responds(to:) guards for \(reads.count) value(forKey:) reads")
        for index in reads {
            let window = lines[max(0, index - 6)...index]
            #expect(window.contains { $0.contains("responds(to:") },
                    "value(forKey:) at line \(index + 1) has no responds(to:) guard in the 6 lines before it")
        }
    }

    @Test("both key paths are read through NSSelectorFromString guards")
    func bothHopsGuarded() throws {
        let code = ItemSourceScan.codeOnly(try providerSource(try tree()))

        #expect(code.contains(#"NSSelectorFromString("imageMetadata")"#))
        #expect(code.contains(#"NSSelectorFromString("URL")"#))
    }

    @Test("cancelling the task cancels the metadata fetch, and a timeout is set")
    func cancellationAndTimeout() throws {
        let code = ItemSourceScan.codeOnly(try providerSource(try tree()))

        #expect(code.contains("withTaskCancellationHandler"))
        #expect(code.contains(".cancel()"))
        #expect(code.contains("timeout"))
    }
}
