//
//  DialogScanner.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: pure scan helpers over a source String (test target only).
//
//  containerAnchoredViolations: a `.confirmationDialog(` or `.alert(` modifier whose receiver chain
//  head is List, ScrollView, Form, NavigationStack, TabView, or the root view of the enclosing
//  `var body` (the first expression of the body). The head is found by walking the modifier chain
//  backwards over balanced (), {} and [] groups to the first identifier that is not a member access.
//  Triggers and rows are never violations even when they are the body's root: Button, Menu, Label,
//  LabeledContent, Toggle, Text, Image, Link and HStack (the row layout of a single list row).
//
//  setThenClearViolations: `flag = true` followed by `flag = false` for the same name in the same
//  brace scope with no `await` in between. `defer { flag = false }`, a clear in a nested or sibling
//  scope, a clear in another `case`, and a clear after a suspension are not flagged.
//
//  Comments are stripped first, so a comment that mentions a token never fires.
//

import Foundation

nonisolated enum DialogScanner {

    struct Violation: Equatable {
        let line: Int
        let modifier: String
        let receiver: String
    }

    static let containerHeads: Set<String> = ["List", "ScrollView", "Form", "NavigationStack", "TabView"]

    /// Receivers that are a trigger or a single row, even when they are the root of a `body`.
    static let triggerHeads: Set<String> = [
        "Button", "Menu", "Label", "LabeledContent", "Toggle", "Text", "Image", "Link", "HStack"
    ]

    private static let modifiers = ["confirmationDialog", "alert"]

    // MARK: - Anchoring

    static func containerAnchoredViolations(in source: String) -> [Violation] {
        let chars = Array(ItemSourceScan.codeOnly(source))
        let bodies = bodyRanges(in: chars)
        var found: [Violation] = []
        var index = 0
        while index < chars.count {
            defer { index += 1 }
            guard chars[index] == "." else { continue }
            guard let modifier = modifierName(at: index + 1, in: chars) else { continue }
            let head = chainHead(before: index, in: chars)
            guard !head.isEmpty else { continue }
            var isViolation = containerHeads.contains(head)
            if !isViolation, !triggerHeads.contains(head),
               let body = bodies.first(where: { $0.range.contains(index) }), body.rootHead == head {
                isViolation = true
            }
            if isViolation {
                let line = chars[0..<index].filter { $0 == "\n" }.count + 1
                found.append(Violation(line: line, modifier: modifier, receiver: head))
            }
        }
        return found
    }

    private static func modifierName(at start: Int, in chars: [Character]) -> String? {
        for name in modifiers {
            let letters = Array(name)
            guard start + letters.count <= chars.count,
                  Array(chars[start..<(start + letters.count)]) == letters else { continue }
            var next = start + letters.count
            while next < chars.count, chars[next].isWhitespace { next += 1 }
            if next < chars.count, chars[next] == "(" { return name }
        }
        return nil
    }

    private static func isIdentifier(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// The first non-member identifier of the chain that ends at the dot at `dotIndex`.
    private static func chainHead(before dotIndex: Int, in chars: [Character]) -> String {
        var i = dotIndex - 1
        while i >= 0 {
            while i >= 0, chars[i].isWhitespace { i -= 1 }
            guard i >= 0 else { return "" }
            let c = chars[i]
            if c == ")" || c == "}" || c == "]" {
                guard let open = matchingOpen(forCloseAt: i, in: chars) else { return "" }
                i = open - 1
                continue
            }
            if c == ":" {
                // A labelled trailing closure (`label: { ... }`): step over the label.
                i -= 1
                while i >= 0, chars[i].isWhitespace { i -= 1 }
                while i >= 0, isIdentifier(chars[i]) { i -= 1 }
                continue
            }
            guard isIdentifier(c) else { return "" }
            let end = i
            while i >= 0, isIdentifier(chars[i]) { i -= 1 }
            let name = String(chars[(i + 1)...end])
            var j = i
            while j >= 0, chars[j].isWhitespace { j -= 1 }
            if j >= 0, chars[j] == "." {
                i = j - 1
                continue
            }
            return name
        }
        return ""
    }

    private static func matchingOpen(forCloseAt close: Int, in chars: [Character]) -> Int? {
        var depth = 0
        var i = close
        while i >= 0 {
            let c = chars[i]
            if c == ")" || c == "}" || c == "]" { depth += 1 }
            if c == "(" || c == "{" || c == "[" {
                depth -= 1
                if depth == 0 { return i }
            }
            i -= 1
        }
        return nil
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

    // MARK: - Body roots

    private struct Body {
        let range: Range<Int>
        let rootHead: String
    }

    private static func bodyRanges(in chars: [Character]) -> [Body] {
        let header = Array("var body: some View")
        var bodies: [Body] = []
        var i = 0
        while i + header.count <= chars.count {
            if Array(chars[i..<(i + header.count)]) == header,
               let open = chars[(i + header.count)...].firstIndex(of: "{"),
               let close = matchingClose(forOpenAt: open, in: chars), close > open {
                let text = String(chars[(open + 1)..<close])
                bodies.append(Body(range: (open + 1)..<close, rootHead: rootHead(ofBody: text)))
                i = close
            } else {
                i += 1
            }
        }
        return bodies
    }

    /// The identifier that starts the first expression of a body, skipping `let`, `var` and `guard`
    /// lines and a leading `return`.
    private static func rootHead(ofBody text: String) -> String {
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("let ") || line.hasPrefix("var ") || line.hasPrefix("guard ") { continue }
            if line.hasPrefix("return ") { line = String(line.dropFirst("return ".count)) }
            return String(line.prefix { isIdentifier($0) })
        }
        return ""
    }

    // MARK: - Set then clear

    /// Lines of every `flag = false` that clears a flag set to true earlier in the same scope.
    static func setThenClearViolations(in source: String) -> [Int] {
        let lines = ItemSourceScan.codeOnly(source).components(separatedBy: "\n")
        var scopes: [[String: Int]] = [[:]]
        var found: [Int] = []
        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let (name, value) = boolAssignment(line) {
                if value {
                    scopes[scopes.count - 1][name] = offset + 1
                } else if scopes[scopes.count - 1][name] != nil {
                    found.append(offset + 1)
                    scopes[scopes.count - 1][name] = nil
                }
                continue
            }
            if line.hasPrefix("case ") || line.hasPrefix("default:") || line.hasPrefix("default :") {
                scopes[scopes.count - 1].removeAll()
            }
            if line.contains("await") {
                for k in scopes.indices { scopes[k].removeAll() }
            }
            for character in line {
                if character == "{" {
                    scopes.append([:])
                } else if character == "}", scopes.count > 1 {
                    scopes.removeLast()
                }
            }
        }
        return found
    }

    private static func boolAssignment(_ line: String) -> (String, Bool)? {
        let parts = line.components(separatedBy: " = ")
        guard parts.count == 2 else { return nil }
        let value: Bool
        switch parts[1].trimmingCharacters(in: .whitespaces) {
        case "true": value = true
        case "false": value = false
        default: return nil
        }
        var name = parts[0].trimmingCharacters(in: .whitespaces)
        if name.hasPrefix("self.") { name = String(name.dropFirst("self.".count)) }
        guard !name.isEmpty, name.allSatisfy({ isIdentifier($0) || $0 == "." }) else { return nil }
        return (name, value)
    }
}
