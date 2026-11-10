//
//  MembersChildrenViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M3: text-scan evidence over the new and changed screens.
//
//  Scope (found by scanning folders, comments stripped first):
//   - Features/Lists/Views/**        (members section, add sheet, co-owner control, recipient picker)
//   - Features/Children/Views/**     (NEW folder: the test fails with a clear message until it exists)
//   - Features/Profile/Views/**
//   - App/ConfigurationErrorView.swift
//
//  Rules:
//   (a) no `.myRole`, `isOwner`, `canEdit` in any scoped file
//   (b) no `.role` read in any scoped file (the row role is read in MembersSectionState only)
//   (c) design tokens only in Features/Children/Views (the Lists views are covered by
//       ListViewScanTests; legacy Profile code is untouched and not scanned for styling)
//   (d) no `accessibilityIdentifier(` with string interpolation or concatenation in Lists,
//       Children and Profile views
//   (e) no Log* or print calls in Features/Children/Views
//   (f) binding scans: the screens use the pure view states and the services
//   (g) no user-visible string literal in the Lists or Children views mentions blindness
//       or surprises
//
//  The source root is found from #filePath, like ListViewScanTests.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Members and children view scan Tests")
struct MembersChildrenViewScanTests {

    // MARK: - Patterns

    private static let roleAndFlagPatterns: [(name: String, pattern: String)] = [
        (".myRole", #"\.myRole\b"#),
        ("isOwner", #"\bisOwner\b"#),
        ("canEdit", #"\bcanEdit\b"#)
    ]

    private static let membershipRolePattern = #"\.role\b"#

    private static let identifierPatterns: [(name: String, pattern: String)] = [
        ("accessibilityIdentifier with interpolation", #"accessibilityIdentifier\([^\n]*\\\("#),
        ("accessibilityIdentifier with concatenation", #"accessibilityIdentifier\([^\n)]*\+"#)
    ]

    private static let loggingPatterns: [(name: String, pattern: String)] = [
        ("Log call", #"\bLog(?:Debug|Info|Warning|Error|Critical)\s*\("#),
        ("print", #"\bprint\s*\("#),
        ("debugPrint", #"\bdebugPrint\s*\("#),
        ("NSLog", #"\bNSLog\s*\("#),
        ("os_log", #"\bos_log\s*\("#),
        ("Logger(", #"\bLogger\s*\("#)
    ]

    /// The forbidden queue API, spelled in two parts so this file never contains the word itself.
    private static let queuePattern = #"\bDispatch"# + #"Queue\b"#

    private static let stringLiteralPattern = #""(?:[^"\\\n]|\\.)*""#
    private static let blindnessPattern = "blind|surprise"

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

    private static func matches(_ pattern: String, in code: String, caseInsensitive: Bool = false) throws -> [Int] {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let whole = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: whole).map { match in
            let prefix = code.prefix(match.range.location)
            return prefix.filter { $0 == "\n" }.count + 1
        }
    }

    /// Line numbers of string literals that contain `blind` or `surprise` (any case).
    private static func blindnessLiteralLines(in code: String) throws -> [Int] {
        let literal = try NSRegularExpression(pattern: stringLiteralPattern)
        let word = try NSRegularExpression(pattern: blindnessPattern, options: [.caseInsensitive])
        var lines: [Int] = []
        let whole = NSRange(code.startIndex..., in: code)
        for match in literal.matches(in: code, range: whole) {
            guard let range = Range(match.range, in: code) else { continue }
            let text = String(code[range])
            if word.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                lines.append(code.prefix(match.range.location).filter { $0 == "\n" }.count + 1)
            }
        }
        return lines
    }

    private struct Scope {
        let root: URL
        let lists: [URL]
        let children: [URL]
        let profile: [URL]
        let configuration: [URL]

        var all: [URL] { lists + children + profile + configuration }

        func relative(_ url: URL) -> String {
            let rootPath = root.standardizedFileURL.path + "/"
            let path = url.standardizedFileURL.path
            return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
        }

        func file(_ name: String, in urls: [URL]) -> URL? {
            urls.first { $0.lastPathComponent == name }
        }
    }

    private func makeSUT(file: String = #filePath) throws -> Scope {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        func folder(_ relative: String) -> [URL] {
            Self.swiftFiles(under: root.appendingPathComponent(relative, isDirectory: true))
        }
        let configuration = root.appendingPathComponent("App/ConfigurationErrorView.swift")
        return Scope(
            root: root,
            lists: folder("Features/Lists/Views"),
            children: folder("Features/Children/Views"),
            profile: folder("Features/Profile/Views"),
            configuration: FileManager.default.fileExists(atPath: configuration.path) ? [configuration] : []
        )
    }

    private func code(_ url: URL) throws -> String {
        Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func offenders(
        _ patterns: [(name: String, pattern: String)],
        in urls: [URL],
        scope: Scope
    ) throws -> [String] {
        var result: [String] = []
        for url in urls {
            let text = try code(url)
            for entry in patterns {
                for line in try Self.matches(entry.pattern, in: text) {
                    result.append("\(scope.relative(url)):\(line) \(entry.name)")
                }
            }
        }
        return result
    }

    // MARK: - Scanner self-checks

    @Test("Scope: the Children views folder exists and the scan reaches every screen")
    func scopeReachesTheScreens() throws {
        let scope = try makeSUT()
        #expect(!scope.children.isEmpty,
                "Features/Children/Views does not exist or has no .swift files: story M3 creates ChildrenView there")
        let listNames = scope.lists.map(\.lastPathComponent)
        for name in ["ListDetailView.swift", "CreateListView.swift", "EditListView.swift"] {
            #expect(listNames.contains(name), "\(name) missing from Features/Lists/Views")
        }
        #expect(scope.profile.map(\.lastPathComponent).contains("ProfileView.swift"))
        #expect(!scope.configuration.isEmpty, "App/ConfigurationErrorView.swift missing")
    }

    @Test("The role and flag patterns match the misuse and nothing longer")
    func roleAndFlagPatternsAreExact() throws {
        for pattern in Self.roleAndFlagPatterns.map(\.pattern) + [Self.membershipRolePattern] {
            _ = try Self.matches(pattern, in: "")
        }
        let bad = ["list.myRole", "if isOwner {", "if detail.canEdit {", "member.role.displayName", "row.role == .viewer"]
        let good = ["row.roleLabel", "let role: MemberRole", "canEditList", "isOwnerBadge", "$selectedRole", "ListRoleBadge"]
        let all = Self.roleAndFlagPatterns.map(\.pattern) + [Self.membershipRolePattern]
        for text in bad {
            let hit = try all.contains { !(try Self.matches($0, in: text)).isEmpty }
            #expect(hit, "Expected a match for: \(text)")
        }
        for text in good {
            let hit = try all.contains { !(try Self.matches($0, in: text)).isEmpty }
            #expect(!hit, "Unexpected match for: \(text)")
        }
    }

    @Test("The logging and queue patterns match calls and leave other words alone")
    func loggingPatternsAreExact() throws {
        let bad = [#"LogError("x")"#, #"print("x")"#, #"LogInfo ("x")"#, #"NSLog("x")"#]
        let good = ["blogPrint", "fingerprint(x)", "LogLevel.info", "let printer = 1"]
        for text in bad {
            let hit = try Self.loggingPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(hit, "Expected a match for: \(text)")
        }
        for text in good {
            let hit = try Self.loggingPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(!hit, "Unexpected match for: \(text)")
        }
        #expect(try !Self.matches(Self.queuePattern, in: "let q = Dispatch" + "Queue.main").isEmpty)
        #expect(try Self.matches(Self.queuePattern, in: "Task { @MainActor in }").isEmpty)
    }

    @Test("The blindness finder reads string literals only")
    func blindnessFinderIsExact() throws {
        #expect(try Self.blindnessLiteralLines(in: #"Text("You are Blind to this")"#) == [1])
        #expect(try Self.blindnessLiteralLines(in: #"Text("A SURPRISE for them")"#) == [1])
        #expect(try Self.blindnessLiteralLines(in: "let isBlind = false\nlet surpriseMode = 1").isEmpty)
        #expect(try Self.blindnessLiteralLines(in: #"Text("For me")"#).isEmpty)
    }

    // MARK: - (a) and (b): no role reads

    @Test("(a) No scoped file mentions .myRole, isOwner or canEdit")
    func noRoleOrOwnerReads() throws {
        let scope = try makeSUT()
        #expect(!scope.all.isEmpty)
        let found = try offenders(Self.roleAndFlagPatterns, in: scope.all, scope: scope)
        #expect(found.isEmpty, "Role or owner read in a view:\n\(found.joined(separator: "\n"))")
    }

    @Test("(b) No scoped file reads a ListMember .role")
    func noMembershipRoleReads() throws {
        let scope = try makeSUT()
        let found = try offenders([("ListMember .role", Self.membershipRolePattern)], in: scope.all, scope: scope)
        #expect(found.isEmpty, "A view reads a membership role; use MemberRowState:\n\(found.joined(separator: "\n"))")
    }

    // MARK: - (c): tokens in the new Children views

    @Test("(c) The Children views use design tokens only")
    func childrenViewsUseTokens() throws {
        let scope = try makeSUT()
        try #require(!scope.children.isEmpty, "Features/Children/Views does not exist yet")
        let found = try offenders(ListViewScanTests.tokenPatterns, in: scope.children, scope: scope)
        #expect(found.isEmpty, "Raw styling found:\n\(found.joined(separator: "\n"))")
    }

    // MARK: - (d): identifiers

    @Test("(d) No accessibility identifier in the Lists, Children or Profile views has interpolation")
    func identifiersAreConstant() throws {
        let scope = try makeSUT()
        let urls = scope.lists + scope.children + scope.profile
        let found = try offenders(Self.identifierPatterns, in: urls, scope: scope)
        #expect(found.isEmpty, "Data in an accessibility identifier:\n\(found.joined(separator: "\n"))")
    }

    // MARK: - (e): no logging in the Children views, no queue API anywhere in scope

    @Test("(e) The Children views make no Log or print calls")
    func childrenViewsDoNotLog() throws {
        let scope = try makeSUT()
        try #require(!scope.children.isEmpty, "Features/Children/Views does not exist yet")
        let found = try offenders(Self.loggingPatterns, in: scope.children, scope: scope)
        #expect(found.isEmpty, "Logging in a Children view:\n\(found.joined(separator: "\n"))")
    }

    @Test("No scoped view uses the forbidden queue API")
    func noQueueAPI() throws {
        let scope = try makeSUT()
        let found = try offenders([("queue API", Self.queuePattern)], in: scope.all, scope: scope)
        #expect(found.isEmpty, "Forbidden queue API:\n\(found.joined(separator: "\n"))")
    }

    // MARK: - (f): the views use the pure states and the services

    private func requireText(_ needle: String, in url: URL?, label: String) throws {
        let file = try #require(url, "\(label) is missing")
        let text = try code(file)
        #expect(text.contains(needle), "\(label) must reference `\(needle)`")
    }

    @Test("(f) The Children views declare ChildrenView and bind to the child states and service")
    func childrenViewBindings() throws {
        let scope = try makeSUT()
        try #require(!scope.children.isEmpty, "Features/Children/Views does not exist yet")
        let declaring = try scope.children.filter {
            !(try Self.matches(#"\bstruct\s+ChildrenView\b"#, in: try code($0))).isEmpty
        }
        let childrenView = try #require(declaring.first, "No file in Features/Children/Views declares `struct ChildrenView`")
        try requireText("childService", in: childrenView, label: "ChildrenView")
        try requireText("ChildrenState(", in: childrenView, label: "ChildrenView")
        try requireText("deleteConfirmation(for", in: childrenView, label: "ChildrenView")

        let allChildrenText = try scope.children.map { try code($0) }.joined(separator: "\n")
        #expect(allChildrenText.contains("ChildFormValidation.canSubmit"),
                "The add-child sheet must gate Add with ChildFormValidation.canSubmit")
        #expect(allChildrenText.contains("isMutating"),
                "The Children views must disable controls while childService.isMutating")
    }

    @Test("(f) The Lists views bind to the members, co-owner and recipient states and the services")
    func listsViewBindings() throws {
        let scope = try makeSUT()
        let allListsText = try scope.lists.map { try code($0) }.joined(separator: "\n")
        #expect(allListsText.contains("AddMemberFormValidation.canSubmit"),
                "The add-member sheet must gate Add with AddMemberFormValidation.canSubmit")

        let detail = scope.file("ListDetailView.swift", in: scope.lists)
        try requireText("MembersSectionState(", in: detail, label: "ListDetailView")
        try requireText("isMutating", in: detail, label: "ListDetailView")
        try requireText("removeConfirmation(for", in: detail, label: "ListDetailView")
        try requireText("leaveConfirmation", in: detail, label: "ListDetailView")

        let edit = scope.file("EditListView.swift", in: scope.lists)
        try requireText("CoOwnerSectionState(", in: edit, label: "EditListView")
        try requireText("CoOwnerFormValidation.canSubmit", in: edit, label: "EditListView")

        let create = scope.file("CreateListView.swift", in: scope.lists)
        try requireText("CreateListRecipientOptions(", in: create, label: "CreateListView")
        try requireText("childService", in: create, label: "CreateListView")
        try requireText("resolvedSelection", in: create, label: "CreateListView")
    }

    @Test("(f) ProfileView references ChildrenView")
    func profileReferencesChildrenView() throws {
        let scope = try makeSUT()
        let profile = scope.file("ProfileView.swift", in: scope.profile)
        let file = try #require(profile, "ProfileView.swift is missing")
        let hits = try Self.matches(#"\bChildrenView\b"#, in: try code(file))
        #expect(!hits.isEmpty, "ProfileView must navigate to ChildrenView")
    }

    // MARK: - (g): no blindness wording in user-visible text

    @Test("(g) No string literal in the Lists or Children views mentions blindness or surprises")
    func noBlindnessWording() throws {
        let scope = try makeSUT()
        var found: [String] = []
        for url in scope.lists + scope.children {
            for line in try Self.blindnessLiteralLines(in: try code(url)) {
                found.append("\(scope.relative(url)):\(line)")
            }
        }
        #expect(found.isEmpty, "Blindness wording in a string literal:\n\(found.joined(separator: "\n"))")
    }
}
