//
//  ListSourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L1: text-scan evidence for two acceptance rules.
//
//  1. No list-scoped production file decides anything from the role: the patterns
//     `.myRole`, `isOwner` and `canEdit` (whole words) must not appear in code (comments are
//     ignored) in Features/Lists, Features/Dashboard, PreviewContent and the model files
//     Core/Models/{GiftList,ListDetail,ListCapabilities,ListPermissions}.swift.
//     ListRoleBadge.swift is the one file allowed to read `.myRole` (display only); it is
//     still scanned for `isOwner` and `canEdit`.
//     A bare `myRole` property declaration or a `myRole:` argument label is not a `.myRole`
//     access and is allowed. Item and purchase `canEdit` live outside the scoped files
//     (GiftItem.swift, ItemDetailView, PurchaseDetailView), so they are not flagged.
//     `canEditList` is a different word and is not flagged.
//  2. The hand-written list wire types are gone: no code anywhere in the app sources
//     mentions CreateListRequest, UpdateListRequest or ListResponse, and
//     NetworkListRepository.swift (and the type) no longer exists.
//
//  The source root is found from #filePath (the same approach as LegacyTokenSeamTests),
//  so the test needs the checkout on disk, which `scripts/test.sh` has.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List source scan Tests")
struct ListSourceScanTests {

    // MARK: - Source discovery

    /// Walks up from this file to ChristmasTrackerTests, then to the sibling app folder
    /// `ChristmasTracker/ChristmasTracker`.
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

    /// Removes block comments and line comments so a comment that mentions a pattern does not fail the scan.
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
        let all: [URL]

        func files(inDirectory relative: String) -> [URL] {
            let prefix = root.appendingPathComponent(relative, isDirectory: true).standardizedFileURL.path + "/"
            return all.filter { $0.standardizedFileURL.path.hasPrefix(prefix) }
        }

        func file(_ relative: String) -> URL {
            root.appendingPathComponent(relative)
        }
    }

    private func makeSUT(file: String = #filePath) throws -> Sources {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        let all = Self.swiftFiles(under: root)
        try #require(!all.isEmpty, "No .swift files found under \(root.path)")
        return Sources(root: root, all: all)
    }

    private func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }

    // MARK: - Scanner self-checks

    @Test("The scanner reaches the list, dashboard, preview and model sources")
    func scannerReachesScopedSources() throws {
        let sources = try makeSUT()
        #expect(!sources.files(inDirectory: "Features/Lists").isEmpty)
        #expect(!sources.files(inDirectory: "Features/Dashboard").isEmpty)
        #expect(!sources.files(inDirectory: "PreviewContent").isEmpty)
        #expect(FileManager.default.fileExists(atPath: sources.file("Core/Models/GiftList.swift").path))
        #expect(FileManager.default.fileExists(atPath: sources.file("Core/Models/ListDetail.swift").path))
    }

    @Test("The comment stripper removes comments and keeps code")
    func commentStripperWorks() {
        let source = "let a = 1 // list.myRole here\n/* isOwner\n canEdit */ let b = 2\nlet c = x.canEditList\n"
        let code = Self.codeOnly(source)
        #expect(code.contains("let a = 1"))
        #expect(code.contains("let b = 2"))
        #expect(code.contains("x.canEditList"))
        #expect(!code.contains("myRole"))
        #expect(!code.contains("isOwner"))
        #expect(!code.contains("canEdit "))
    }

    @Test("The patterns match what they should and nothing more")
    func patternsAreWordExact() throws {
        #expect(try Self.matches(#"\.myRole\b"#, in: "x.myRole == .owner").count == 1)
        #expect(try Self.matches(#"\.myRole\b"#, in: "let myRole: ListRole").isEmpty)
        #expect(try Self.matches(#"\.myRole\b"#, in: "init(myRole: .owner)").isEmpty)
        #expect(try Self.matches(#"\bcanEdit\b"#, in: "x.canEdit").count == 1)
        #expect(try Self.matches(#"\bcanEdit\b"#, in: "x.canEditList").isEmpty)
        #expect(try Self.matches(#"\bisOwner\b"#, in: "if list.isOwner {").count == 1)
        #expect(try Self.matches(#"\bisOwner\b"#, in: "let isOwnerOfThing = 1").isEmpty)
    }

    // MARK: - Rule 1: no role reads in scope

    @Test("No scoped production file reads .myRole, isOwner or canEdit (ListRoleBadge may read .myRole)")
    func noRoleReadsInScope() throws {
        let sources = try makeSUT()

        var scoped: [URL] = []
        scoped += sources.files(inDirectory: "Features/Lists")
        scoped += sources.files(inDirectory: "Features/Dashboard")
        scoped += sources.files(inDirectory: "PreviewContent")
        let modelFiles = ["GiftList", "ListDetail", "ListCapabilities", "ListPermissions", "ListRoleBadge"]
        var missing: [String] = []
        for name in modelFiles {
            let url = sources.file("Core/Models/\(name).swift")
            if FileManager.default.fileExists(atPath: url.path) {
                scoped.append(url)
            } else {
                missing.append("Core/Models/\(name).swift")
            }
        }
        #expect(missing.isEmpty, "Expected model files are missing: \(missing)")

        let badge = sources.file("Core/Models/ListRoleBadge.swift").standardizedFileURL.path
        var offenders: [String] = []
        for url in scoped {
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let name = relativePath(url, root: sources.root)
            let isBadge = url.standardizedFileURL.path == badge
            if !isBadge {
                for line in try Self.matches(#"\.myRole\b"#, in: code) { offenders.append("\(name):\(line) .myRole") }
            }
            for line in try Self.matches(#"\bisOwner\b"#, in: code) { offenders.append("\(name):\(line) isOwner") }
            for line in try Self.matches(#"\bcanEdit\b"#, in: code) { offenders.append("\(name):\(line) canEdit") }
        }
        #expect(offenders.isEmpty, "Role-based reads found:\n\(offenders.joined(separator: "\n"))")
    }

    @Test("ListPermissions and ListCapabilities exist and never mention myRole at all")
    func permissionsNeverMentionRole() throws {
        let sources = try makeSUT()
        for name in ["ListPermissions", "ListCapabilities"] {
            let url = sources.file("Core/Models/\(name).swift")
            let text = try #require(try? String(contentsOf: url, encoding: .utf8),
                                    "Core/Models/\(name).swift must exist")
            let code = Self.codeOnly(text)
            #expect(try Self.matches(#"\bmyRole\b"#, in: code).isEmpty, "\(name).swift must not mention myRole")
        }
    }

    // MARK: - Rule 2: hand-written wire types are gone

    @Test("NetworkListRepository.swift no longer exists")
    func networkListRepositoryFileIsGone() throws {
        let sources = try makeSUT()
        let stillThere = sources.all.filter { $0.lastPathComponent == "NetworkListRepository.swift" }
        #expect(stillThere.isEmpty, "Still present: \(stillThere.map { relativePath($0, root: sources.root) })")
    }

    @Test("No app code mentions CreateListRequest, UpdateListRequest, ListResponse or NetworkListRepository")
    func handWrittenWireTypesAreGone() throws {
        let sources = try makeSUT()
        let patterns = [
            #"\bCreateListRequest\b"#,
            #"\bUpdateListRequest\b"#,
            #"\bListResponse\b"#,
            #"\bNetworkListRepository\b"#
        ]
        var offenders: [String] = []
        for url in sources.all {
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for pattern in patterns {
                for line in try Self.matches(pattern, in: code) {
                    offenders.append("\(relativePath(url, root: sources.root)):\(line) \(pattern)")
                }
            }
        }
        #expect(offenders.isEmpty, "Hand-written list wire types still referenced:\n\(offenders.joined(separator: "\n"))")
    }
}
