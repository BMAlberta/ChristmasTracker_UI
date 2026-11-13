//
//  BootstrapSourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: text-scan evidence that the legacy `AppDependencies.make()` real branch (the
//  silent fallback to `MockListRepository(withMockData: false)`) is gone. Comment lines are
//  ignored. The source root is found from #filePath, so the checkout must be on disk.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Bootstrap source scan Tests")
struct BootstrapSourceScanTests {

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

    /// Source text without whole-line comments.
    private static func codeLines(_ source: String) -> String {
        source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func makeSUT(file: String = #filePath) throws -> (root: URL, all: [URL]) {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        let all = Self.swiftFiles(under: root)
        try #require(!all.isEmpty, "No .swift files found under \(root.path)")
        return (root, all)
    }

    @Test("ChristmasTrackerApp.swift no longer has AppDependencies.make() or a legacy make() real branch")
    func legacyMakeIsGone() throws {
        let sut = try makeSUT()
        let appFile = sut.root.appendingPathComponent("ChristmasTrackerApp.swift")
        let code = Self.codeLines(try String(contentsOf: appFile, encoding: .utf8))

        #expect(!code.contains("AppDependencies.make()"))
        #expect(!code.contains("static func make()"))
        #expect(!code.contains("MockListRepository(withMockData: false)"))
    }

    // MARK: - F2: no Mock construction outside makeMock; init() builds no mock version repository

    /// The text between the first `{` after `marker` and its matching `}` (nil when not found).
    private static func braceBody(after marker: String, in code: String) -> (range: Range<Int>, text: String)? {
        let chars = Array(code)
        let markerChars = Array(marker)
        guard chars.count >= markerChars.count else { return nil }
        var start = -1
        for index in 0...(chars.count - markerChars.count) where Array(chars[index..<(index + markerChars.count)]) == markerChars {
            start = index
            break
        }
        guard start >= 0, let open = chars[start...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var cursor = open
        while cursor < chars.count {
            if chars[cursor] == "{" { depth += 1 }
            if chars[cursor] == "}" {
                depth -= 1
                if depth == 0 { return (open..<(cursor + 1), String(chars[open...cursor])) }
            }
            cursor += 1
        }
        return nil
    }

    @Test("Mock types are constructed in ChristmasTrackerApp.swift only inside makeMock (or a #Preview)")
    func mocksOnlyInMakeMock() throws {
        let sut = try makeSUT()
        let appFile = sut.root.appendingPathComponent("ChristmasTrackerApp.swift")
        let code = Self.codeLines(try String(contentsOf: appFile, encoding: .utf8))
        let makeMock = try #require(Self.braceBody(after: "func makeMock", in: code))
        let preview = Self.braceBody(after: "#Preview", in: code)

        // MockAPIClient was deleted in I4b; the `MockAPIClient.` alternative is kept harmlessly.
        let regex = try NSRegularExpression(pattern: #"\bMock[A-Za-z]+\(|\bMockAPIClient\."#)
        var offenders: [String] = []
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            // Character offset of the match start.
            let utf16Prefix = (code as NSString).substring(to: match.range.location)
            let offset = utf16Prefix.count
            let insideMakeMock = makeMock.range.contains(offset)
            let insidePreview = preview?.range.contains(offset) ?? false
            if !insideMakeMock && !insidePreview {
                offenders.append((code as NSString).substring(with: match.range))
            }
        }
        #expect(offenders.isEmpty, "Mock constructed outside makeMock: \(offenders)")
    }

    @Test("ChristmasTrackerApp.init() does not construct MockAppVersionRepository")
    func initBuildsNoMockVersionRepository() throws {
        let sut = try makeSUT()
        let appFile = sut.root.appendingPathComponent("ChristmasTrackerApp.swift")
        let code = Self.codeLines(try String(contentsOf: appFile, encoding: .utf8))
        let initBody = try #require(Self.braceBody(after: "init() {", in: code))

        #expect(!initBody.text.contains("MockAppVersionRepository("))
    }

    @Test("body shows ConfigurationErrorView first and ContentView only in the else branch")
    func bodyShowsConfigurationErrorInsteadOfContent() throws {
        let sut = try makeSUT()
        let appFile = sut.root.appendingPathComponent("ChristmasTrackerApp.swift")
        let code = Self.codeLines(try String(contentsOf: appFile, encoding: .utf8))
        let body = try #require(Self.braceBody(after: "var body: some Scene", in: code)).text

        let errorIndex = try #require(body.range(of: "ConfigurationErrorView")).lowerBound
        let contentIndex = try #require(body.range(of: "ContentView(") ?? body.range(of: "appContent")).lowerBound
        let elseIndex = try #require(body.range(of: "else")).lowerBound
        #expect(body.contains("ConfigurationErrorState.state(for:"))
        #expect(errorIndex < elseIndex)
        #expect(elseIndex < contentIndex)
    }

    @Test("No app code calls AppDependencies.make()")
    func noCallersOfLegacyMake() throws {
        let sut = try makeSUT()
        var offenders: [String] = []
        for url in sut.all {
            let code = Self.codeLines(try String(contentsOf: url, encoding: .utf8))
            if code.contains("AppDependencies.make()") {
                offenders.append(url.lastPathComponent)
            }
        }
        #expect(offenders.isEmpty, "Still calling AppDependencies.make(): \(offenders)")
    }
}
