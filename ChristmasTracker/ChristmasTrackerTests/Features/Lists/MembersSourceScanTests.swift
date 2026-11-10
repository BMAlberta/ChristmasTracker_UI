//
//  MembersSourceScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M1: text-scan evidence for the members rules.
//
//  1. The new view-state files (found by the type names they declare, wherever they end up)
//     never mention `myRole` at all (comments are ignored).
//  2. The membership role of a roster row is read only inside the members view-state file:
//     no production view under Features/Lists/Views or Features/Children/Views reads `.role`.
//     The `.myRole` / `isOwner` / `canEdit` scan of Features/Children and Features/Profile is an
//     addition to ListSourceScanTests.noRoleReadsInScope.
//
//  The source root is found from #filePath, like ListSourceScanTests.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Members source scan Tests")
struct MembersSourceScanTests {

    // MARK: - Allowlist

    /// Views allowed to match `\.role\b`. TEMPORARY: ListDetailView.swift still shows the old
    /// roster (`member.role.displayName`) until story M3 rebuilds it on MembersSectionState.
    /// Story M3 MUST delete this entry; `allowlistEntriesStillNeeded` fails once the entry is dead.
    private static let roleReadAllowlist: Set<String> = ["Features/Lists/Views/ListDetailView.swift"]

    // MARK: - Source discovery (same approach as ListSourceScanTests)

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
        let all = Self.swiftFiles(under: root)
        try #require(!all.isEmpty, "No .swift files found under \(root.path)")
        return Sources(root: root, all: all)
    }

    /// Production files whose code declares `struct|enum|class <name>`.
    private func files(declaring name: String, in sources: Sources) throws -> [URL] {
        let pattern = #"\b(?:struct|enum|class)\s+"# + name + #"\b"#
        return try sources.all.filter { url in
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            return !(try Self.matches(pattern, in: code)).isEmpty
        }
    }

    // MARK: - Scanner self-checks

    @Test("The .role pattern matches a membership role read and nothing longer")
    func rolePatternIsWordExact() throws {
        #expect(try Self.matches(#"\.role\b"#, in: "member.role.displayName").count == 1)
        #expect(try Self.matches(#"\.role\b"#, in: "row.role == .viewer").count == 1)
        #expect(try Self.matches(#"\.role\b"#, in: "row.roleLabel").isEmpty)
        #expect(try Self.matches(#"\.role\b"#, in: "let role: MemberRole").isEmpty)
        #expect(try Self.matches(#"\.role\b"#, in: "Text(row.kind.title)").isEmpty)
    }

    @Test("The type finder sees a declaration and ignores a mention in a comment")
    func finderIgnoresComments() throws {
        let pattern = #"\b(?:struct|enum|class)\s+MembersSectionState\b"#
        #expect(try Self.matches(pattern, in: "struct MembersSectionState {").count == 1)
        #expect(try Self.matches(pattern, in: Self.codeOnly("// struct MembersSectionState {\n")).isEmpty)
    }

    // MARK: - Rule 1: the view-state files never mention myRole

    @Test("The members, co-owner, children and recipient view-state files exist and never mention myRole")
    func viewStateFilesNeverMentionMyRole() throws {
        let sources = try makeSUT()
        let typeNames = [
            "MembersSectionState", "CoOwnerSectionState", "MemberRemoveConfirmation", "LeaveListConfirmation",
            "AddMemberFormValidation", "CoOwnerFormValidation", "ChildrenState", "CreateListRecipientOptions",
            "ChildFormValidation"
        ]
        var offenders: [String] = []
        var missing: [String] = []
        for name in typeNames {
            let found = try files(declaring: name, in: sources)
            if found.isEmpty {
                missing.append(name)
                continue
            }
            for url in found {
                let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
                for line in try Self.matches(#"\bmyRole\b"#, in: code) {
                    offenders.append("\(sources.relative(url)):\(line) myRole (declares \(name))")
                }
            }
        }
        #expect(missing.isEmpty, "No production file declares: \(missing)")
        #expect(offenders.isEmpty, "myRole mentioned in a view-state file:\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: - Rule 2: no view reads a roster row's membership role

    @Test("No view under Features/Lists/Views or Features/Children/Views reads .role")
    func viewsNeverReadMembershipRole() throws {
        let sources = try makeSUT()
        var scoped = sources.files(inDirectory: "Features/Lists/Views")
        scoped += sources.files(inDirectory: "Features/Children/Views")
        #expect(!scoped.isEmpty, "The Lists views must be reachable by the scan")

        var offenders: [String] = []
        for url in scoped {
            let name = sources.relative(url)
            if Self.roleReadAllowlist.contains(name) { continue }
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in try Self.matches(#"\.role\b"#, in: code) {
                offenders.append("\(name):\(line) .role")
            }
        }
        #expect(offenders.isEmpty, "A view reads a membership role; use MemberRowState:\n\(offenders.joined(separator: "\n"))")
    }

    @Test("Every allowlist entry is still needed (fails once story M3 rebuilds the roster, so the entry gets deleted)")
    func allowlistEntriesStillNeeded() throws {
        let sources = try makeSUT()
        for name in Self.roleReadAllowlist {
            let url = sources.root.appendingPathComponent(name)
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            let hits = try Self.matches(#"\.role\b"#, in: code)
            // While the old roster exists the entry is needed. Once the file stops reading
            // .role, the entry is dead and must be deleted: this test then fails to say so.
            #expect(!hits.isEmpty, "\(name) no longer reads .role: delete it from roleReadAllowlist")
        }
    }
}
