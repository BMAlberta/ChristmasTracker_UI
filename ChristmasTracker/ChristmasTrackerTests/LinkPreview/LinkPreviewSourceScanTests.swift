//
//  LinkPreviewSourceScanTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P1 (decision 9): source scan over every file under Features/LinkPreview/, the environment key
//  file and App/LinkPreviewWiring.swift. The page URL and the image value never reach a log, report,
//  breadcrumb, span or error description:
//   - no Log*/setData/setExtra/setTag/breadcrumb/capture/startTransaction/startChild call interpolates;
//   - no breadcrumb or capture call at all, no print-style call;
//   - no error description (`localizedDescription`, `String(describing:)`, `String(reflecting:)`,
//     `\(error` / `\(String(describing`) anywhere in the files.
//
//  The scanners are proven on in-memory strings first. Comments are stripped before scanning. The file
//  list is required to be non-empty and to contain the expected files, so a missing implementation
//  fails here for the right reason (the scan is never vacuous).
//

import Foundation
import Testing
@testable import ChristmasTracker

nonisolated enum LinkPreviewScanRules {

    static let bannedPatterns: [(pattern: String, label: String)] = [
        (#"\.localizedDescription"#, "error description via localizedDescription"),
        (#"String\((describing|reflecting):"#, "String(describing:) / String(reflecting:)"),
        (#"\\\((error|err|e)\)"#, "error interpolated into a string"),
        (#"\baddBreadcrumb\("#, "breadcrumb call"),
        (#"\bBreadcrumb\("#, "breadcrumb construction"),
        (#"\bcapture(Error|Message|Exception)?\("#, "Sentry capture call"),
        (#"\b(print|NSLog|os_log|debugPrint|dump)\("#, "print-style call")
    ]

    static func violations(in code: String) throws -> [String] {
        var found = try PurchaseHistoryScanRules.interpolatingCalls(in: code)
        for (pattern, label) in bannedPatterns {
            for line in try ItemSourceScan.matchingLines(pattern, in: code) {
                found.append("\(label) at line \(line)")
            }
        }
        return found
    }
}

@Suite("Link preview source scan", .timeLimit(.minutes(1)))
struct LinkPreviewSourceScanTests {

    // MARK: Scanner self-proofs

    @Test("The scanner fires on a URL, a value or an error in a log, span, breadcrumb or description", arguments: [
        #"LogError("failed for \(pageURL)", category: .business)"#,
        #"LogInfo("image \(imageUrl)")"#,
        #"span.setData(value: "\(pageURL)", key: "url")"#,
        #"let text = error.localizedDescription"#,
        #"let text = String(describing: error)"#,
        #"LogError("failed: \(error)")"#,
        #"SentrySDK.addBreadcrumb(Breadcrumb())"#,
        #"SentrySDK.capture(error: error)"#,
        #"print("x")"#
    ])
    func scannerFires(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(try LinkPreviewScanRules.violations(in: code).isEmpty == false, "\(source)")
    }

    @Test("The scanner allows fixed text and comments", arguments: [
        #"LogError("link preview failed", category: .business)"#,
        #"let span = SentrySDK.startTransaction(name: "link-preview.imageUrl", operation: "service")"#,
        #"// LogInfo("page \(pageURL)")"#,
        "let value = LinkPreviewImageFilter.accepted(raw)"
    ])
    func scannerAllows(source: String) throws {
        let code = ItemSourceScan.codeOnly(source)
        #expect(try LinkPreviewScanRules.violations(in: code).isEmpty, "\(source)")
    }

    // MARK: Real sources

    private func newFiles() throws -> (tree: ItemSourceTree, files: [URL]) {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let files = tree.all.filter {
            let relative = tree.relativePath($0)
            return relative.hasPrefix("Features/LinkPreview/")
                || relative == "Core/Extensions/EnvironmentValues+LinkPreviewService.swift"
                || relative == "App/LinkPreviewWiring.swift"
        }
        return (tree, files)
    }

    @Test("The new files exist, so the scans are not vacuous")
    func newFilesExist() throws {
        let (tree, files) = try newFiles()
        let names = Set(files.map { tree.relativePath($0) })

        #expect(files.isEmpty == false, "no Features/LinkPreview files found")
        for expected in [
            "Core/Extensions/EnvironmentValues+LinkPreviewService.swift",
            "App/LinkPreviewWiring.swift",
            "Features/LinkPreview/Repositories/GeneratedClientLinkPreviewRepository.swift",
            "Features/LinkPreview/Repositories/MockLinkPreviewRepository.swift",
            "Features/LinkPreview/Services/LinkPreviewService.swift"
        ] {
            #expect(names.contains(expected), "missing \(expected)")
        }
    }

    @Test("No log, report, breadcrumb, span or error description in the new files carries a URL or value")
    func noUrlInLogs() throws {
        let (tree, files) = try newFiles()
        try #require(files.isEmpty == false, "no Features/LinkPreview files found")
        var found: [String] = []
        for url in files {
            let code = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for hit in try LinkPreviewScanRules.violations(in: code) {
                found.append("\(tree.relativePath(url)): \(hit)")
            }
        }
        #expect(found.isEmpty, "A URL or value may reach no log or report:\n\(found.joined(separator: "\n"))")
    }

    @Test("The repository method is instrumented")
    func repositoryIsInstrumented() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let raw = try #require(
            tree.source("Features/LinkPreview/Repositories/GeneratedClientLinkPreviewRepository.swift"),
            "GeneratedClientLinkPreviewRepository.swift must exist"
        )

        #expect(ItemSourceScan.codeOnly(raw).contains("@Instrumented"))
    }
}
