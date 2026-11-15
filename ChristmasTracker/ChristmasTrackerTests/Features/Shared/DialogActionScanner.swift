//
//  DialogActionScanner.swift
//  ChristmasTrackerTests
//
//  TH1.1 Story A2: pure scan helper over a source String (test target only).
//
//  Rule: a Button inside the trailing action closure of `.confirmationDialog(...) { }` or
//  `.alert(...) { }` whose title (the Button's first argument: a string literal or an identifier
//  path such as `ListArchiveConfirmation.confirmButtonTitle`) matches Delete, Remove, Archive,
//  Leave, Logout or Sign Out (case-insensitive) must carry `role: .destructive`. Buttons with
//  `role: .cancel` never count. The `message:` closure is not an action closure.
//
//  Known limit: a Button whose title is a generic name with no keyword (ChildrenView's and
//  MembersSectionView's member Remove `confirmation.confirmButtonTitle`) is not matched by the
//  keyword rule; pinned real-files tests cover those two instead.
//
//  Comments are stripped first (ItemSourceScan.codeOnly), so a keyword in a comment never fires.
//

import Foundation

nonisolated enum DialogActionScanner {

    struct Violation: Equatable {
        let line: Int
        let title: String
    }

    static let keywords = ["delete", "remove", "archive", "leave", "logout", "signout"]

    private static let dialogModifiers = [".confirmationDialog", ".alert"]

    struct Examined: Equatable {
        let line: Int
        let title: String
        let isDestructive: Bool
    }

    static func missingDestructiveRole(in source: String) -> [Violation] {
        examinedButtons(in: source)
            .filter { !$0.isDestructive }
            .map { Violation(line: $0.line, title: $0.title) }
    }

    /// Every non-cancel keyword-titled action button in a dialog or alert closure, compliant or not.
    static func examinedButtons(in source: String) -> [Examined] {
        let chars = Array(ItemSourceScan.codeOnly(source))
        var found: [Examined] = []
        for closure in actionClosures(in: chars) {
            let text = String(chars[closure.range])
            for statement in DestructiveScanner.buttonStatements(in: text) {
                let arguments = argumentText(of: statement.chain)
                let compact = arguments.filter { !$0.isWhitespace }
                guard !compact.contains("role:.cancel") else { continue }
                let title = firstArgument(of: arguments)
                let lowered = title.filter { !$0.isWhitespace }.lowercased()
                guard keywords.contains(where: { lowered.contains($0) }) else { continue }
                found.append(Examined(
                    line: closure.firstLine + statement.line - 1,
                    title: title,
                    isDestructive: statement.isDestructive
                ))
            }
        }
        return found
    }

    // MARK: - Parsing

    private struct ActionClosure {
        let range: Range<Int>
        let firstLine: Int
    }

    private static func actionClosures(in chars: [Character]) -> [ActionClosure] {
        var result: [ActionClosure] = []
        for modifier in dialogModifiers {
            let name = Array(modifier)
            var i = 0
            while i + name.count <= chars.count {
                defer { i += 1 }
                guard Array(chars[i..<(i + name.count)]) == name else { continue }
                var p = skipWhitespace(chars, from: i + name.count)
                guard p < chars.count, chars[p] == "(", let close = matchingClose(forOpenAt: p, in: chars) else { continue }
                p = skipWhitespace(chars, from: close + 1)
                guard p < chars.count, chars[p] == "{", let end = matchingClose(forOpenAt: p, in: chars) else { continue }
                let line = chars[0..<p].filter { $0 == "\n" }.count + 1
                result.append(ActionClosure(range: p..<(end + 1), firstLine: line))
            }
        }
        return result
    }

    /// The Button's argument list including parentheses, without its closures and modifiers.
    private static func argumentText(of chain: String) -> String {
        let chars = Array(chain)
        guard let open = chars.firstIndex(of: "("), let close = matchingClose(forOpenAt: open, in: chars) else { return "" }
        return String(chars[(open + 1)..<close])
    }

    /// Text up to the first comma that is not nested in brackets or a string literal.
    private static func firstArgument(of arguments: String) -> String {
        var depth = 0
        var inString = false
        var result = ""
        for c in arguments {
            if c == "\"" { inString.toggle() }
            if !inString {
                if c == "(" || c == "[" || c == "{" { depth += 1 }
                if c == ")" || c == "]" || c == "}" { depth -= 1 }
                if c == ",", depth == 0 { break }
            }
            result.append(c)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func skipWhitespace(_ chars: [Character], from start: Int) -> Int {
        var i = start
        while i < chars.count, chars[i].isWhitespace { i += 1 }
        return i
    }

    private static func matchingClose(forOpenAt open: Int, in chars: [Character]) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            let c = chars[i]
            if c == "(" || c == "{" || c == "[" { depth += 1 }
            if c == ")" || c == "}" || c == "]" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }
}
