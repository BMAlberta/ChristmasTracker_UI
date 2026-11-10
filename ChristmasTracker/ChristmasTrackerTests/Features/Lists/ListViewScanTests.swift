//
//  ListViewScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3a-L3: text-scan evidence that the list screens use design tokens and bind only to
//  the view states.
//
//  Scope: every .swift file under Features/Lists/Views and Features/Dashboard of the app
//  sources (comments stripped first). Nothing else is scanned.
//
//  Token rules (a match is an offender):
//   - system colour literal as a style:  .foregroundColor/.foregroundStyle/.background/.tint/
//     .fill/.stroke( .white|.black|.red|.blue|.green|.orange|.yellow|.gray|.purple|.pink )
//   - `Color.<system colour>` (same names), `Color(` and `UIColor(` initialisers
//   - any `.cornerRadius(` (there is no radius token; use a shape with a token)
//   - a numeric `.padding(` literal: `.padding(12)`, `.padding(.horizontal, 12)`,
//     `.padding([.top, .bottom], 12)`
//   - `.font(.system(` literals
//  Exempt (allowed): AppSpacing.*, EdgeInsets.app* , AppTypography `.appXxx` fonts, the named
//  colour tokens in AppColors (`.primaryColor`, `Color.surfaceColor`, ...), `.padding()` with
//  no argument or a non-numeric argument, `.frame(minHeight: 44)` style target sizes, and
//  SF Symbol name strings.
//
//  Binding rules (a match is an offender):
//   - `accessibilityIdentifier(` whose argument has string interpolation (`\(`) or `+`
//   - any reference to ListPermissions, `.capabilities`, `myRole`, `ListRole` (whole word;
//     ListRoleBadge is a different word) or construction `ListRoleBadge(`: views read the
//     view states, and the badge is built inside them.
//
//  The source root is found from #filePath, like ListSourceScanTests.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("List view scan Tests")
struct ListViewScanTests {

    // MARK: - Patterns

    private static let systemColours = "white|black|red|blue|green|orange|yellow|gray|purple|pink"

    static let tokenPatterns: [(name: String, pattern: String)] = [
        ("system colour as style",
         #"\.(?:foregroundColor|foregroundStyle|background|tint|fill|stroke)\(\s*\.(?:"# + systemColours + #")\b"#),
        ("Color.<system colour>", #"\bColor\.(?:"# + systemColours + #")\b"#),
        ("Color( literal", #"\bColor\("#),
        ("UIColor( literal", #"\bUIColor\("#),
        (".cornerRadius(", #"\.cornerRadius\("#),
        ("numeric .padding(", #"\.padding\(\s*(?:\.[A-Za-z]+\s*,\s*|\[[^\]]*\]\s*,\s*)?-?\d"#),
        (".font(.system(", #"\.font\(\s*\.system\("#)
    ]

    static let bindingPatterns: [(name: String, pattern: String)] = [
        ("accessibilityIdentifier with interpolation", #"accessibilityIdentifier\([^\n]*\\\("#),
        ("accessibilityIdentifier with concatenation", #"accessibilityIdentifier\([^\n)]*\+"#),
        ("ListPermissions", #"\bListPermissions\b"#),
        (".capabilities", #"\.capabilities\b"#),
        ("myRole", #"\bmyRole\b"#),
        ("ListRole", #"\bListRole\b"#),
        ("ListRoleBadge(", #"\bListRoleBadge\s*\("#)
    ]

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

    private struct Scope {
        let root: URL
        let files: [URL]

        func relative(_ url: URL) -> String {
            let rootPath = root.standardizedFileURL.path + "/"
            let path = url.standardizedFileURL.path
            return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
        }
    }

    private func makeSUT(file: String = #filePath) throws -> Scope {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        var files: [URL] = []
        for folder in ["Features/Lists/Views", "Features/Dashboard"] {
            files += Self.swiftFiles(under: root.appendingPathComponent(folder, isDirectory: true))
        }
        return Scope(root: root, files: files)
    }

    private func offenders(_ patterns: [(name: String, pattern: String)], in scope: Scope) throws -> [String] {
        var result: [String] = []
        for url in scope.files {
            let code = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for entry in patterns {
                for line in try Self.matches(entry.pattern, in: code) {
                    result.append("\(scope.relative(url)):\(line) \(entry.name)")
                }
            }
        }
        return result
    }

    // MARK: - Scanner self-checks

    @Test("The scan reaches the list views and the dashboard views")
    func scopeIsNotEmpty() throws {
        let scope = try makeSUT()
        let names = scope.files.map { $0.lastPathComponent }
        #expect(names.contains("ListDetailView.swift"))
        #expect(names.contains("CreateListView.swift"))
        #expect(names.contains("EditListView.swift"))
        #expect(names.contains("DashboardView.swift"))
    }

    @Test("Token patterns match raw styling and leave tokens alone")
    func tokenPatternsAreExact() throws {
        let bad = [
            ".foregroundColor(.white)", ".foregroundStyle(.red)", ".background(.black)",
            "Color.red", "Color(red: 1)", "UIColor(white: 1)", ".cornerRadius(12)",
            ".padding(16)", ".padding(.horizontal, 8)", ".padding([.top, .bottom], 4)",
            ".font(.system(size: 14))"
        ]
        let good = [
            ".foregroundColor(.textPrimaryColor)", ".background(Color.surfaceColor)",
            ".padding(AppSpacing.md)", ".padding(.horizontal, AppSpacing.sm)", ".padding()",
            ".padding(EdgeInsets.appScreenPadding)", ".font(.appBody)", ".frame(minHeight: 44)",
            ".foregroundColor(.accentColor)", "Color.clear"
        ]
        for text in bad {
            let hit = try Self.tokenPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(hit, "Expected a match for: \(text)")
        }
        for text in good {
            let hit = try Self.tokenPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(!hit, "Unexpected match for: \(text)")
        }
    }

    @Test("Binding patterns match direct permission, role and identifier misuse only")
    func bindingPatternsAreExact() throws {
        let bad = [
            #".accessibilityIdentifier("row-\(list.id)")"#,
            #".accessibilityIdentifier("row-" + list.id)"#,
            "ListPermissions(detail.capabilities)", "list.capabilities.canEditList",
            "list.myRole", "let role: ListRole", "ListRoleBadge(list: list)"
        ]
        let good = [
            #".accessibilityIdentifier("listDetail.editButton")"#,
            "ListRowState(list: list)", "ListDetailState(detail: detail)", "ListRoleBadge.Tone"
        ]
        for text in bad {
            let hit = try Self.bindingPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(hit, "Expected a match for: \(text)")
        }
        for text in good {
            let hit = try Self.bindingPatterns.contains { !(try Self.matches($0.pattern, in: text)).isEmpty }
            #expect(!hit, "Unexpected match for: \(text)")
        }
    }

    // MARK: - Rules

    @Test("List and dashboard views use design tokens only")
    func viewsUseTokensOnly() throws {
        let scope = try makeSUT()
        let found = try offenders(Self.tokenPatterns, in: scope)
        #expect(found.isEmpty, "Raw styling found:\n\(found.joined(separator: "\n"))")
    }

    @Test("List and dashboard views bind to view states only and put no list data in identifiers")
    func viewsBindToStatesOnly() throws {
        let scope = try makeSUT()
        let found = try offenders(Self.bindingPatterns, in: scope)
        #expect(found.isEmpty, "Direct permission, role or identifier misuse found:\n\(found.joined(separator: "\n"))")
    }
}
