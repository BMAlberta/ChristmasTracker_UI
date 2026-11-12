//
//  LogHygieneScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-K0: log hygiene. No log call under Features/ may interpolate a list id, list name,
//  email or person value.
//
//  What is scanned: every .swift file under ChristmasTracker/ChristmasTracker/Features/. A call
//  is `LogDebug(`, `LogInfo(`, `LogWarning(`, `LogError(` or `LogCritical(` (a `func` declaration
//  and a call on a comment line are skipped). The argument text runs to the matching close paren
//  and may span many lines. String literals are tracked so a `)` inside a literal does not end
//  the call. Only string INTERPOLATIONS `\( ... )` inside the arguments are examined.
//
//  PATTERN (documented): inside an interpolation, string literals are removed, then every
//  identifier or member path (a.b.c) is extracted. A path is sensitive when ANY of its
//  dot-separated components, compared case-insensitively and as a whole word, is one of
//      listId, email, name, displayName, firstName, lastName, memberId, childId, userId
//  or when the whole path, compared case-insensitively, ends with `list.id` (so `list.id`,
//  `self.list.id`) or `list.name` (already covered by the `name` component). Whole-word means
//  `error`, `count`, `statusCode`, `operation`, `lists`, `items`, `filename` and `named` are
//  not sensitive, but `listID`, `item.name` and `user.email` are.
//
//  F7 additions: (a) any component ending in `name` or `email`, or starting with `email`, is
//  sensitive unless it is in the documented non-person list (fileName, typeName, operationName,
//  categoryName, className); (b) an interpolation that is exactly one model object (list, detail,
//  member, members, child, children, person, user, item, items, or an identifier ending in Item,
//  Detail or List; bare or `self.x`) is sensitive. `items.count` and `\(error)` stay allowed.
//
//  ALLOWLIST: an explicit array of (relative path, line-text substring, reason). It starts EMPTY
//  and is only to be extended with a written reason.
//
//  The source root is found from #filePath (same approach as ListSourceScanTests), so the test
//  needs the checkout on disk, which `scripts/test.sh` has.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Log hygiene scan Tests")
struct LogHygieneScanTests {

    // MARK: - Allowlist

    struct AllowEntry: Sendable {
        let path: String          // relative to ChristmasTracker/ChristmasTracker, e.g. "Features/Items/Services/ItemService.swift"
        let lineContains: String  // substring of the offending source line
        let reason: String
    }

    /// Starts EMPTY on purpose.
    static let allowlist: [AllowEntry] = []

    // MARK: - Scanner

    struct Hit: Equatable, Sendable {
        let line: Int           // 1-based line of the interpolation in the scanned source
        let expression: String  // the text inside \( ... )
        let path: String        // the offending identifier or member path
    }

    private static let sensitiveComponents: Set<String> = [
        "listid", "email", "name", "displayname", "firstname", "lastname",
        "memberid", "childid", "userid"
    ]

    private static let sensitivePathSuffixes = ["list.id", "list.name"]

    private static let callPattern = #"\bLog(Debug|Info|Warning|Error|Critical)\s*\("#

    /// Identifier or member paths in an interpolation expression, with string literals removed.
    static func paths(inExpression expression: String) -> [String] {
        var withoutLiterals = expression
        if let literal = try? NSRegularExpression(pattern: #""[^"]*""#) {
            let whole = NSRange(withoutLiterals.startIndex..., in: withoutLiterals)
            withoutLiterals = literal.stringByReplacingMatches(in: withoutLiterals, range: whole, withTemplate: " ")
        }
        guard let regex = try? NSRegularExpression(
            pattern: #"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*"#
        ) else { return [] }
        let whole = NSRange(withoutLiterals.startIndex..., in: withoutLiterals)
        return regex.matches(in: withoutLiterals, range: whole).compactMap { match in
            Range(match.range, in: withoutLiterals).map { String(withoutLiterals[$0]) }
        }
    }

    /// F7 rule (a): a component that ENDS with `name` or `email` (listName, recipientName,
    /// ownerEmail, userEmail), or STARTS with `email` (emailAddress), is sensitive, except these
    /// non-person names (compared case-insensitively, whole component):
    ///   filename      a file on disk, not a person
    ///   typename      a Swift type name
    ///   operationname a service operation label
    ///   categoryname  a log or item category label
    ///   classname     a Swift class name
    private static let nonPersonNameComponents: Set<String> = [
        "filename", "typename", "operationname", "categoryname", "classname"
    ]

    /// F7 rule (b): an interpolation that is exactly one of these (bare or `self.x`) dumps a whole
    /// model object, which carries names, ids or emails. `items.count` is a different expression
    /// and is not affected.
    private static let wholeObjectNames: Set<String> = [
        "list", "detail", "member", "members", "child", "children", "person", "user", "item", "items"
    ]

    /// Whole-object identifiers by suffix, e.g. `updatedItem`, `newDetail`, `currentList`.
    private static let wholeObjectSuffixes = ["Item", "Detail", "List"]

    /// When the whole interpolation is one bare identifier (or `self.x`) naming a model object,
    /// returns that identifier; otherwise nil. `\(error)` and `\(authError)` are not objects.
    static func wholeObjectIdentifier(inExpression expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"^(?:self\.)?([A-Za-z_][A-Za-z0-9_]*)$"#),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let range = Range(match.range(at: 1), in: trimmed) else { return nil }
        let identifier = String(trimmed[range])
        if wholeObjectNames.contains(identifier.lowercased()) { return identifier }
        if wholeObjectSuffixes.contains(where: { identifier.hasSuffix($0) && identifier.count > $0.count }) {
            return identifier
        }
        return nil
    }

    static func isSensitive(path: String) -> Bool {
        let lowered = path.lowercased()
        if sensitivePathSuffixes.contains(where: { lowered == $0 || lowered.hasSuffix("." + $0) }) {
            return true
        }
        return lowered.split(separator: ".").map(String.init).contains { component in
            if sensitiveComponents.contains(component) { return true }
            if nonPersonNameComponents.contains(component) { return false }
            return component.hasSuffix("name") || component.hasSuffix("email") || component.hasPrefix("email")
        }
    }

    /// Interpolations `\( ... )` found in the argument text of one call (text starts right after the
    /// opening paren of the call). Returns (expression, line offset from the first line of `tail`).
    static func interpolations(inCallTail tail: [Character]) -> [(expression: String, lineOffset: Int)] {
        var found: [(String, Int)] = []
        var index = 0
        var depth = 1
        var inString = false
        var triple = false
        var line = 0

        func isTripleQuote(at position: Int) -> Bool {
            position + 2 < tail.count && tail[position] == "\"" && tail[position + 1] == "\"" && tail[position + 2] == "\""
        }

        while index < tail.count && depth > 0 {
            let char = tail[index]
            if char == "\n" { line += 1 }
            if inString {
                if char == "\\" && index + 1 < tail.count {
                    if tail[index + 1] == "(" {
                        var nested = 1
                        var cursor = index + 2
                        var expression = ""
                        let startLine = line
                        while cursor < tail.count {
                            let inner = tail[cursor]
                            if inner == "\n" { line += 1 }
                            if inner == "(" {
                                nested += 1
                            } else if inner == ")" {
                                nested -= 1
                                if nested == 0 { break }
                            }
                            expression.append(inner)
                            cursor += 1
                        }
                        found.append((expression, startLine))
                        index = cursor + 1
                        continue
                    }
                    if tail[index + 1] == "\n" { line += 1 }
                    index += 2
                    continue
                }
                if triple {
                    if isTripleQuote(at: index) {
                        inString = false
                        triple = false
                        index += 3
                        continue
                    }
                } else if char == "\"" {
                    inString = false
                }
                index += 1
                continue
            }
            if isTripleQuote(at: index) {
                inString = true
                triple = true
                index += 3
                continue
            }
            switch char {
            case "\"": inString = true
            case "(": depth += 1
            case ")": depth -= 1
            default: break
            }
            index += 1
        }
        return found
    }

    /// All sensitive interpolations in log calls of one source text.
    static func sensitiveHits(in source: String) -> [Hit] {
        guard let call = try? NSRegularExpression(pattern: callPattern) else { return [] }
        let lines = source.components(separatedBy: "\n")
        var hits: [Hit] = []
        for (lineIndex, text) in lines.enumerated() {
            let whole = NSRange(text.startIndex..., in: text)
            for match in call.matches(in: text, range: whole) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let prefix = String(text[text.startIndex..<matchRange.lowerBound])
                if prefix.contains("//") || prefix.contains("func ") { continue }
                let rest = String(text[matchRange.upperBound...])
                let following = lines[(lineIndex + 1)...].prefix(60)
                let tail = Array(([rest] + following).joined(separator: "\n"))
                for interpolation in interpolations(inCallTail: tail) {
                    if let object = wholeObjectIdentifier(inExpression: interpolation.expression) {
                        hits.append(Hit(
                            line: lineIndex + 1 + interpolation.lineOffset,
                            expression: interpolation.expression,
                            path: object
                        ))
                        continue
                    }
                    for path in paths(inExpression: interpolation.expression) where isSensitive(path: path) {
                        hits.append(Hit(
                            line: lineIndex + 1 + interpolation.lineOffset,
                            expression: interpolation.expression,
                            path: path
                        ))
                    }
                }
            }
        }
        return hits
    }

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

    private struct Sources {
        let root: URL
        let features: [URL]
    }

    private func makeSUT(file: String = #filePath) throws -> Sources {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        let featuresDirectory = root.appendingPathComponent("Features", isDirectory: true)
        let files = Self.swiftFiles(under: featuresDirectory)
        try #require(!files.isEmpty, "No .swift files found under \(featuresDirectory.path)")
        return Sources(root: root, features: files)
    }

    private func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }

    // MARK: - Scanner self-tests

    @Test("a log call that interpolates a list id is a hit")
    func hitOnListId() {
        let hits = Self.sensitiveHits(in: #"LogInfo("Loaded \(items.count) items for list \(listId)")"#)
        #expect(hits.map(\.path) == ["listId"])
        #expect(hits.first?.line == 1)
    }

    @Test("a multi-line log call that interpolates a list name is a hit on the right line")
    func hitOnMultiLineCall() {
        let source = #"""
        func load() {
            LogWarning(
                "Could not load \(list.name)",
                category: .business
            )
        }
        """#
        let hits = Self.sensitiveHits(in: source)
        #expect(hits.map(\.path) == ["list.name"])
        #expect(hits.first?.line == 3)
    }

    @Test("email, person-name and id components are hits, case-insensitively")
    func hitsOnPersonValues() {
        #expect(Self.sensitiveHits(in: #"LogDebug("user \(user.email)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogError("hi \(displayName)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("hi \(firstName) \(lastName)")"#).count == 2)
        #expect(Self.sensitiveHits(in: #"LogInfo("m \(memberId) c \(childId) u \(userId)")"#).count == 3)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(listID)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(item.name)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(self.list.id)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogCritical("x \(list.id)", category: .business)"#).count == 1)
    }

    @Test("operation, error, count and status code interpolations are not hits")
    func noHitOnSafeInterpolations() {
        #expect(Self.sensitiveHits(in: #"LogError("\(operation) failed")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogInfo("Fetched \(lists.count) lists")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogError("failed: \(error)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogWarning("status \(statusCode) for \(filename)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogInfo("none of \(items.count) items")"#).isEmpty)
    }

    @Test("components ending with name or email, or starting with email, are hits")
    func hitsOnNameAndEmailSuffixes() {
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(listName)")"#).map(\.path) == ["listName"])
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(recipientName)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(ownerEmail)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(emailAddress)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(session.userEmail)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(detail.recipientName)")"#).count == 1)
    }

    @Test("the explicit non-person name allowlist is not a hit")
    func nonPersonNamesAllowed() {
        for component in ["fileName", "typeName", "operationName", "categoryName", "className"] {
            #expect(Self.sensitiveHits(in: "LogInfo(\"x \\(\(component))\")").isEmpty, "\(component)")
            #expect(Self.sensitiveHits(in: "LogInfo(\"x \\(self.\(component))\")").isEmpty, "self.\(component)")
        }
    }

    @Test("interpolating a whole model object is a hit")
    func wholeObjectsAreHits() {
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(list)")"#).map(\.path) == ["list"])
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(self.member)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(members)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(children)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(person) \(user)")"#).count == 2)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(item)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(items)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(detail)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(updatedItem)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(newDetail)")"#).count == 1)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(currentList)")"#).count == 1)
    }

    @Test("counts, errors and sub-properties of objects are not whole-object hits")
    func notWholeObjects() {
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(items.count)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(lists.count)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(members.count)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogError("x \(error)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogError("x \(authError)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"LogInfo("x \(list.status)")"#).isEmpty)
    }

    @Test("a literal parenthesis inside the message does not end the call early")
    func parenInsideLiteral() {
        let hits = Self.sensitiveHits(in: #"LogInfo("done :) for \(listId)")"#)
        #expect(hits.map(\.path) == ["listId"])
    }

    @Test("a sensitive word inside a string literal within an interpolation is not a hit")
    func literalInsideInterpolation() {
        #expect(Self.sensitiveHits(in: #"LogInfo("v \(flag ? "email" : "none")")"#).isEmpty)
    }

    @Test("comments and function declarations are not calls")
    func commentsAndDeclarationsSkipped() {
        #expect(Self.sensitiveHits(in: #"// LogInfo("x \(listId)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: #"/// LogInfo("x \(listId)")"#).isEmpty)
        #expect(Self.sensitiveHits(in: "nonisolated func LogInfo(_ message: String) {}").isEmpty)
    }

    @Test("a message with no interpolation is never a hit, even if it names the pattern")
    func plainMessage() {
        #expect(Self.sensitiveHits(in: #"LogInfo("loaded email list")"#).isEmpty)
    }

    // MARK: - The scan

    @Test("The scanner reaches the Features sources")
    func scannerReachesFeatures() throws {
        let sources = try makeSUT()
        let names = sources.features.map { relativePath($0, root: sources.root) }
        #expect(names.contains { $0.hasPrefix("Features/Lists/") })
        #expect(names.contains { $0.hasPrefix("Features/Items/") })
    }

    @Test("No log call under Features interpolates a list id, list name, email or person value")
    func noSensitiveInterpolationInFeatureLogs() throws {
        let sources = try makeSUT()
        var offenders: [String] = []
        for url in sources.features {
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.components(separatedBy: "\n")
            let name = relativePath(url, root: sources.root)
            for hit in Self.sensitiveHits(in: text) {
                let lineText = hit.line >= 1 && hit.line <= lines.count ? lines[hit.line - 1] : ""
                let allowed = Self.allowlist.contains {
                    $0.path == name && lineText.contains($0.lineContains)
                }
                if !allowed {
                    offenders.append("\(name):\(hit.line) interpolates \(hit.path)")
                }
            }
        }
        #expect(offenders.isEmpty, "Sensitive values in log calls:\n\(offenders.joined(separator: "\n"))")
    }

    @Test("every allowlist entry has a path, a substring and a reason")
    func allowlistEntriesAreComplete() {
        for entry in Self.allowlist {
            #expect(!entry.path.isEmpty)
            #expect(!entry.lineContains.isEmpty)
            #expect(!entry.reason.isEmpty)
        }
    }
}
