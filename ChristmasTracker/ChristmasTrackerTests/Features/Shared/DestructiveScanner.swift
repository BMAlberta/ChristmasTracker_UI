//
//  DestructiveScanner.swift
//  ChristmasTrackerTests
//
//  UX1b Story B2: pure scan helpers over a source String (test target only).
//
//  A Button statement is read from `Button` through its argument list, its trailing action
//  closure, an optional `label:` closure, and its trailing modifier chain (`.name(...)` and
//  `.name { ... }`), ending at the next sibling statement. The arguments and closures of
//  presenting modifiers (confirmationDialog, alert, contextMenu, swipeActions, sheet, popover,
//  fullScreenCover) belong to other controls and are not part of the Button's own chain.
//
//  destructiveButtonsMissingToken: every Button with `role: .destructive` (button, menu item,
//  swipe action, context-menu item, dialog button) must contain `destructiveTint()` or
//  `Color.destructiveColor` (which covers `.tint(Color.destructiveColor)` and a label
//  foreground or background style) in its own chain.
//
//  swipeDestructiveMissingTint: a destructive Button inside a `.swipeActions { }` closure needs an
//  explicit tint in its modifier chain: `destructiveTint()` or `.tint(Color.destructiveColor)`.
//  A label foreground does not count: the swipe background is tinted, not the label.
//
//  Comments are stripped first, so a comment that mentions a token never fires.
//

import Foundation

nonisolated enum DestructiveScanner {

    struct Violation: Equatable {
        let line: Int
    }

    /// One Button statement: its line, whether it carries `role: .destructive`, the text of its
    /// own chain (arguments, closures, modifiers) and the text of its modifiers alone.
    struct ButtonStatement: Equatable {
        let line: Int
        let start: Int
        let isDestructive: Bool
        let chain: String
        let modifiers: String
    }

    private static let presentingModifiers: Set<String> = [
        "confirmationDialog", "alert", "contextMenu", "swipeActions", "sheet", "popover", "fullScreenCover"
    ]

    // MARK: - Rules

    static func destructiveButtonsMissingToken(in source: String) -> [Violation] {
        buttonStatements(in: source)
            .filter { $0.isDestructive && !hasToken($0.chain) }
            .map { Violation(line: $0.line) }
    }

    static func swipeDestructiveMissingTint(in source: String) -> [Violation] {
        let chars = Array(ItemSourceScan.codeOnly(source))
        let ranges = swipeActionRanges(in: chars)
        return statements(in: chars)
            .filter { statement in
                statement.isDestructive
                    && ranges.contains(where: { $0.contains(statement.start) })
                    && !hasExplicitTint(statement.modifiers)
            }
            .map { Violation(line: $0.line) }
    }

    // MARK: - Raw red and neutral types

    /// Lines that use raw red as a colour: `.red` as a member (not `x.red`), or `Color.red`.
    static func rawRedViolations(in source: String) -> [Violation] {
        let code = ItemSourceScan.codeOnly(source)
        let pattern = #"(?<![A-Za-z0-9_)\]])\.red\b|\bColor\.red\b"#
        guard let lines = try? ItemSourceScan.matchingLines(pattern, in: code) else { return [] }
        return lines.map { Violation(line: $0) }
    }

    /// Lines inside the body of `struct <typeName>` that contain a forbidden token. Returns nil
    /// when the type is not found, so a renamed type cannot silently pass.
    static func forbiddenTokenViolations(inType typeName: String, tokens: [String], source: String) -> [Violation]? {
        let chars = Array(ItemSourceScan.codeOnly(source))
        let header = Array("struct \(typeName)")
        var i = 0
        while i + header.count <= chars.count {
            defer { i += 1 }
            guard Array(chars[i..<(i + header.count)]) == header else { continue }
            let after = i + header.count
            if after < chars.count, isIdentifier(chars[after]) { continue }
            guard let open = chars[after...].firstIndex(of: "{"),
                  let close = matchingClose(forOpenAt: open, in: chars) else { return nil }
            var found: [Violation] = []
            for line in lineNumber(of: open, in: chars)...lineNumber(of: close, in: chars) {
                let text = lineText(line, in: chars)
                if tokens.contains(where: { containsToken($0, in: text) }) { found.append(Violation(line: line)) }
            }
            return found
        }
        return nil
    }

    private static func lineText(_ line: Int, in chars: [Character]) -> String {
        String(chars).components(separatedBy: "\n")[line - 1]
    }

    /// `.red` and `Color.red` are matched as whole members; other tokens as plain substrings.
    private static func containsToken(_ token: String, in text: String) -> Bool {
        if token == ".red" || token == "Color.red" {
            let pattern = #"(?<![A-Za-z0-9_)\]])\.red\b|\bColor\.red\b"#
            return text.range(of: pattern, options: .regularExpression) != nil
        }
        return text.contains(token)
    }

    /// Every Button statement in the source, destructive or not.
    static func buttonStatements(in source: String) -> [ButtonStatement] {
        statements(in: Array(ItemSourceScan.codeOnly(source)))
    }

    private static func stripped(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    private static func hasToken(_ chain: String) -> Bool {
        let text = stripped(chain)
        return text.contains("destructiveTint()") || text.contains("Color.destructiveColor")
    }

    private static func hasExplicitTint(_ modifiers: String) -> Bool {
        let text = stripped(modifiers)
        return text.contains("destructiveTint()") || text.contains(".tint(Color.destructiveColor)")
    }

    // MARK: - Parsing

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
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

    private static func lineNumber(of index: Int, in chars: [Character]) -> Int {
        chars[0..<index].filter { $0 == "\n" }.count + 1
    }

    private static func statements(in chars: [Character]) -> [ButtonStatement] {
        let name = Array("Button")
        var found: [ButtonStatement] = []
        var i = 0
        while i + name.count <= chars.count {
            defer { i += 1 }
            guard Array(chars[i..<(i + name.count)]) == name else { continue }
            if i > 0, isIdentifier(chars[i - 1]) || chars[i - 1] == "." { continue }
            let afterName = i + name.count
            if afterName < chars.count, isIdentifier(chars[afterName]) { continue }
            let open = skipWhitespace(chars, from: afterName)
            guard open < chars.count, chars[open] == "(",
                  let close = matchingClose(forOpenAt: open, in: chars) else { continue }
            let arguments = String(chars[open...close])
            let compact = stripped(arguments)
            let isDestructive = compact.contains("role:.destructive") || compact.contains("role:ButtonRole.destructive")

            var chain = arguments
            var modifiers = ""
            var p = close + 1
            scanning: while true {
                let q = skipWhitespace(chars, from: p)
                guard q < chars.count else { break }
                let c = chars[q]
                if c == "{" {
                    guard let end = matchingClose(forOpenAt: q, in: chars) else { break }
                    chain += String(chars[q...end])
                    p = end + 1
                } else if isIdentifier(c) {
                    var k = q
                    while k < chars.count, isIdentifier(chars[k]) { k += 1 }
                    let label = String(chars[q..<k])
                    let colon = skipWhitespace(chars, from: k)
                    guard label == "label", colon < chars.count, chars[colon] == ":" else { break scanning }
                    let brace = skipWhitespace(chars, from: colon + 1)
                    guard brace < chars.count, chars[brace] == "{",
                          let end = matchingClose(forOpenAt: brace, in: chars) else { break scanning }
                    chain += String(chars[brace...end])
                    p = end + 1
                } else if c == "." {
                    var k = q + 1
                    while k < chars.count, isIdentifier(chars[k]) { k += 1 }
                    guard k > q + 1 else { break }
                    let modifier = String(chars[(q + 1)..<k])
                    var end = k - 1
                    if k < chars.count, chars[k] == "(", let close = matchingClose(forOpenAt: k, in: chars) {
                        end = close
                    }
                    let brace = skipWhitespace(chars, from: end + 1)
                    if brace < chars.count, chars[brace] == "{",
                       let close = matchingClose(forOpenAt: brace, in: chars) {
                        end = close
                    }
                    if !presentingModifiers.contains(modifier) {
                        let text = String(chars[q...end])
                        chain += text
                        modifiers += text
                    }
                    p = end + 1
                } else {
                    break
                }
            }
            found.append(ButtonStatement(
                line: lineNumber(of: i, in: chars),
                start: i,
                isDestructive: isDestructive,
                chain: chain,
                modifiers: modifiers
            ))
        }
        return found
    }

    private static func swipeActionRanges(in chars: [Character]) -> [Range<Int>] {
        let name = Array(".swipeActions")
        var ranges: [Range<Int>] = []
        var i = 0
        while i + name.count <= chars.count {
            defer { i += 1 }
            guard Array(chars[i..<(i + name.count)]) == name else { continue }
            var p = skipWhitespace(chars, from: i + name.count)
            if p < chars.count, chars[p] == "(", let close = matchingClose(forOpenAt: p, in: chars) {
                p = skipWhitespace(chars, from: close + 1)
            }
            if p < chars.count, chars[p] == "{", let close = matchingClose(forOpenAt: p, in: chars) {
                ranges.append(p..<close)
            }
        }
        return ranges
    }
}
