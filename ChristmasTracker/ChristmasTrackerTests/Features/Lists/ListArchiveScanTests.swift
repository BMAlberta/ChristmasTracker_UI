//
//  ListArchiveScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-A: text-scan evidence that deleting a list is presented as ARCHIVING it everywhere.
//
//  1. Neither Features/Lists nor Features/Dashboard references the deleted ListDeleteConfirmation
//     type, nor the old texts "Delete List" and "Delete this list?" (comments are ignored).
//  2. DashboardView.swift and ListDetailView.swift never read `.myRole` (the screens read flags).
//
//  Style follows ListSourceScanTests: the source root is found from #filePath, so the test needs
//  the checkout on disk, which `scripts/test.sh` has.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List archive scan Tests")
struct ListArchiveScanTests {

    // MARK: - Source discovery

    private static func appSourceRoot(from file: URL) -> URL? {
        var directory = file.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let root = directory.deletingLastPathComponent()
                    .appendingPathComponent("ChristmasTracker", isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return root
                }
                return nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    private static func swiftFiles(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }

    /// Removes block and line comments so a comment that mentions a pattern does not fail the scan.
    private static func codeOnly(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        var blockDepth = 0
        while index < source.endIndex {
            let next = source.index(after: index)
            let pair = next < source.endIndex ? String(source[index...next]) : ""
            if pair == "/*" {
                blockDepth += 1
                index = source.index(after: next)
            } else if pair == "*/" && blockDepth > 0 {
                blockDepth -= 1
                index = source.index(after: next)
            } else if blockDepth > 0 {
                if source[index] == "\n" { result.append("\n") }
                index = next
            } else if pair == "//" {
                while index < source.endIndex && source[index] != "\n" {
                    index = source.index(after: index)
                }
            } else {
                result.append(source[index])
                index = next
            }
        }
        return result
    }

    private static func matches(_ pattern: String, in code: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern)
        let whole = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: whole).map { match in
            let prefix = code.prefix(match.range.location)
            return prefix.filter { $0 == "\n" }.count + 1
        }
    }

    private struct Sources {
        let root: URL

        func files(inDirectory relative: String) -> [URL] {
            ListArchiveScanTests.swiftFiles(under: root.appendingPathComponent(relative, isDirectory: true))
        }

        func file(_ relative: String) -> URL {
            root.appendingPathComponent(relative)
        }

        func relative(_ url: URL) -> String {
            let rootPath = root.standardizedFileURL.path + "/"
            let path = url.standardizedFileURL.path
            return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
        }
    }

    private func makeSUT(file: String = #filePath) throws -> Sources {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        return Sources(root: root)
    }

    private func scopedFiles(_ sources: Sources) -> [URL] {
        sources.files(inDirectory: "Features/Lists") + sources.files(inDirectory: "Features/Dashboard")
    }

    // MARK: - Scanner self-checks

    @Test("The scan reaches the list and dashboard sources, including both screens")
    func scopeIsNotEmpty() throws {
        let sources = try makeSUT()
        let names = scopedFiles(sources).map(\.lastPathComponent)
        #expect(names.contains("ListService.swift"))
        #expect(names.contains("ListViewState.swift"))
        #expect(names.contains("ListDetailView.swift"))
        #expect(names.contains("DashboardView.swift"))
    }

    @Test("The patterns match the old wording and leave the new wording alone")
    func patternsAreExact() throws {
        let old = [
            "ListDeleteConfirmation.title", #"Button("Delete List", role: .destructive)"#,
            #"confirmationDialog("Delete this list?")"#
        ]
        let new = [
            "ListArchiveConfirmation.title", #"Button("Archive List", role: .destructive)"#,
            #"let text = "Delete Item""#, "ListDeleteConfirmationTests"
        ]
        for text in old {
            let hit = try Self.forbidden.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(hit, "Expected a match for: \(text)")
        }
        for text in new {
            let hit = try Self.forbidden.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(!hit, "Unexpected match for: \(text)")
        }
    }

    // MARK: - Rule 1: delete wording is gone

    static let forbidden: [(name: String, pattern: String)] = [
        ("ListDeleteConfirmation", #"\bListDeleteConfirmation\b"#),
        ("\"Delete List\"", #""Delete List""#),
        ("\"Delete this list?\"", #""Delete this list\?""#)
    ]

    @Test("Features/Lists and Features/Dashboard no longer mention ListDeleteConfirmation, \"Delete List\" or \"Delete this list?\"")
    func deleteWordingIsGone() throws {
        let sources = try makeSUT()
        var offenders: [String] = []
        for url in scopedFiles(sources) {
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for entry in Self.forbidden {
                for line in try Self.matches(entry.pattern, in: code) {
                    offenders.append("\(sources.relative(url)):\(line) \(entry.name)")
                }
            }
        }
        #expect(offenders.isEmpty, "Delete wording still present:\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: - Rule 2: the two screens read no role

    @Test("DashboardView.swift and ListDetailView.swift contain no .myRole")
    func screensReadNoRole() throws {
        let sources = try makeSUT()
        let screens = ["Features/Dashboard/Views/DashboardView.swift", "Features/Lists/Views/ListDetailView.swift"]
        var offenders: [String] = []
        for relative in screens {
            let url = sources.file(relative)
            let text = try #require(try? String(contentsOf: url, encoding: .utf8), "\(relative) must exist")
            let code = Self.codeOnly(text)
            for line in try Self.matches(#"\.myRole\b"#, in: code) {
                offenders.append("\(relative):\(line) .myRole")
            }
        }
        #expect(offenders.isEmpty, "Role reads found:\n\(offenders.joined(separator: "\n"))")
    }
}
