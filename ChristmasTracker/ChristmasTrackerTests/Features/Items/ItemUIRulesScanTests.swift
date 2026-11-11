//
//  ItemUIRulesScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-D: a narrow text scan over Features/Items (all .swift, comments stripped) for the
//  four UI rules. Each rule is a small pure function over source text that is first proven with
//  synthetic positive (must fire) and negative (must not fire) strings, then run over the real
//  sources. The checks are deliberately conservative text checks, not a Swift parser.
//
//  Rules:
//   1. no `.confirmationDialog` whose receiver chain starts at List, ScrollView, Form or NavigationStack
//   2. no raw red: `.red`, `Color.red`, `Color(.red)`
//   3. every `role: .destructive` Button has `destructiveColor` in the same button declaration
//      (the Button call, its trailing closure and the modifier chain that follows it)
//   4. any file that reads `loadError` also calls `clearLoadError()`
//   5. no `.alert(` in the Items views and components
//

import Testing
import Foundation
@testable import ChristmasTracker

// MARK: - Rule functions (pure, on comment-stripped source)

nonisolated enum ItemUIRules {

    static let containerHeads: Set<String> = ["List", "ScrollView", "Form", "NavigationStack"]

    /// Index of the start of the identifier that ends just before `end` (exclusive), or nil.
    private static func identifierRange(endingBefore end: String.Index, in code: String) -> Range<String.Index>? {
        var start = end
        while start > code.startIndex {
            let previous = code.index(before: start)
            let character = code[previous]
            if character.isLetter || character.isNumber || character == "_" { start = previous } else { break }
        }
        return start < end ? start..<end : nil
    }

    /// Index of the opener matching the closer at `closerIndex` (walking backwards), or nil.
    private static func matchingOpener(for closerIndex: String.Index, in code: String) -> String.Index? {
        let closer = code[closerIndex]
        let opener: Character = closer == ")" ? "(" : closer == "}" ? "{" : "["
        var depth = 0
        var index = closerIndex
        while true {
            if code[index] == closer { depth += 1 }
            if code[index] == opener {
                depth -= 1
                if depth == 0 { return index }
            }
            if index == code.startIndex { return nil }
            index = code.index(before: index)
        }
    }

    private static func skipWhitespaceBackwards(from index: String.Index, in code: String) -> String.Index {
        var current = index
        while current > code.startIndex, code[code.index(before: current)].isWhitespace {
            current = code.index(before: current)
        }
        return current
    }

    /// Walks back from a `.confirmationDialog` through the modifier chain to its head identifier.
    static func chainHead(before dot: String.Index, in code: String) -> String? {
        var cursor = skipWhitespaceBackwards(from: dot, in: code)
        while cursor > code.startIndex {
            let last = code.index(before: cursor)
            let character = code[last]
            if character == ")" || character == "}" || character == "]" {
                guard let opener = matchingOpener(for: last, in: code) else { return nil }
                cursor = skipWhitespaceBackwards(from: opener, in: code)
                continue
            }
            guard let range = identifierRange(endingBefore: cursor, in: code) else { return nil }
            let before = skipWhitespaceBackwards(from: range.lowerBound, in: code)
            if before > code.startIndex, code[code.index(before: before)] == "." {
                // A modifier in the chain: keep walking back past the dot.
                cursor = skipWhitespaceBackwards(from: code.index(before: before), in: code)
                continue
            }
            return String(code[range])
        }
        return nil
    }

    /// 1-based lines of `.confirmationDialog` modifiers attached (directly) to a container.
    static func confirmationDialogsOnContainers(in code: String) -> [Int] {
        var lines: [Int] = []
        var searchStart = code.startIndex
        while let range = code.range(of: ".confirmationDialog", range: searchStart..<code.endIndex) {
            searchStart = range.upperBound
            if let head = chainHead(before: range.lowerBound, in: code), containerHeads.contains(head) {
                lines.append(code[..<range.lowerBound].filter { $0 == "\n" }.count + 1)
            }
        }
        return lines
    }

    /// Lines with a raw red color token.
    static func rawRedLines(in code: String) -> [Int] {
        let pattern = #"\bColor\.red\b|\bColor\(\s*\.red\b|(?<![A-Za-z0-9_])\.red\b"#
        return (try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]
    }

    /// The text of a Button declaration starting at `start`: the call, trailing closure and the
    /// modifier chain that follows (each `.name`, optional `(...)`, optional `{...}`).
    static func declaration(startingAt start: String.Index, in code: String) -> String {
        var index = start
        func skipWhitespace() { while index < code.endIndex, code[index].isWhitespace { index = code.index(after: index) } }
        func skipBalanced() {
            guard index < code.endIndex else { return }
            let open = code[index]
            let close: Character = open == "(" ? ")" : open == "{" ? "}" : "]"
            var depth = 0
            while index < code.endIndex {
                if code[index] == open { depth += 1 }
                if code[index] == close {
                    depth -= 1
                    if depth == 0 { index = code.index(after: index); return }
                }
                index = code.index(after: index)
            }
        }
        // "Button"
        while index < code.endIndex, code[index].isLetter { index = code.index(after: index) }
        skipWhitespace()
        if index < code.endIndex, code[index] == "(" { skipBalanced() }
        var end = index
        skipWhitespace()
        if index < code.endIndex, code[index] == "{" { skipBalanced(); end = index }
        while true {
            skipWhitespace()
            // Labeled trailing closure: `label: { ... }`
            if index < code.endIndex, code[index].isLetter {
                var probe = index
                while probe < code.endIndex, code[probe].isLetter || code[probe].isNumber { probe = code.index(after: probe) }
                if probe < code.endIndex, code[probe] == ":" {
                    probe = code.index(after: probe)
                    while probe < code.endIndex, code[probe].isWhitespace { probe = code.index(after: probe) }
                    if probe < code.endIndex, code[probe] == "{" {
                        index = probe
                        skipBalanced()
                        end = index
                        continue
                    }
                }
                break
            }
            guard index < code.endIndex, code[index] == "." else { break }
            let next = code.index(after: index)
            guard next < code.endIndex, code[next].isLetter else { break }
            index = next
            while index < code.endIndex, code[index].isLetter || code[index].isNumber { index = code.index(after: index) }
            if index < code.endIndex, code[index] == "(" { skipBalanced() }
            let afterCall = index
            skipWhitespace()
            if index < code.endIndex, code[index] == "{" { skipBalanced() } else { index = afterCall }
            end = index
        }
        return String(code[start..<end])
    }

    /// 1-based lines of `role: .destructive` that are not inside a Button declaration naming destructiveColor.
    static func destructiveWithoutToken(in code: String) -> [Int] {
        var lines: [Int] = []
        let buttonRegex = try? NSRegularExpression(pattern: #"\bButton\s*\("#)
        var searchStart = code.startIndex
        while let range = code.range(of: "role: .destructive", range: searchStart..<code.endIndex) {
            searchStart = range.upperBound
            let line = code[..<range.lowerBound].filter { $0 == "\n" }.count + 1
            let prefix = String(code[..<range.lowerBound])
            let whole = NSRange(prefix.startIndex..., in: prefix)
            guard let match = buttonRegex?.matches(in: prefix, range: whole).last,
                  let matchRange = Range(match.range, in: code) else {
                lines.append(line)
                continue
            }
            let text = declaration(startingAt: matchRange.lowerBound, in: code)
            if !text.contains("destructiveColor") { lines.append(line) }
        }
        return lines
    }

    /// True when the code reads `loadError` but never calls `clearLoadError()`.
    static func readsLoadErrorWithoutClearing(_ code: String) -> Bool {
        let reads = (try? ItemSourceScan.matchingLines(#"\bloadError\b"#, in: code))?.isEmpty == false
        return reads && !code.contains("clearLoadError()")
    }

    static func alertLines(in code: String) -> [Int] {
        (try? ItemSourceScan.matchingLines(#"\.alert\("#, in: code)) ?? [-1]
    }
}

// MARK: - Tests

@Suite("Item UI rules scan Tests")
struct ItemUIRulesScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Rule 1: confirmationDialog

    @Test("A confirmationDialog on a List, ScrollView, Form or NavigationStack fires",
          arguments: [
            "List(items) { row in Text(row.name) }\n    .confirmationDialog(\"Delete?\", isPresented: $show) { }",
            "ScrollView {\n  Text(\"a\")\n}\n.padding()\n.confirmationDialog(\"Delete?\", isPresented: $show) { }",
            "Form { Text(\"a\") }.navigationTitle(\"x\").confirmationDialog(\"D\", isPresented: $s) { }",
            "NavigationStack { Text(\"a\") }\n.confirmationDialog(\"D\", isPresented: $s) { }",
            "ScrollView(.vertical, showsIndicators: false) { Text(\"a\") }.onAppear { go() }.confirmationDialog(\"D\", isPresented: $s) { }"
          ])
    func dialogOnContainerFires(source: String) {
        #expect(!ItemUIRules.confirmationDialogsOnContainers(in: code(source)).isEmpty, "\(source)")
    }

    @Test("A confirmationDialog on the triggering button or row does not fire",
          arguments: [
            "Button(role: .destructive) { show = true } label: { Text(\"Delete\") }\n    .tint(Color.destructiveColor)\n    .confirmationDialog(\"Delete?\", isPresented: $show) { }",
            "Button(\"Delete\") { show = true }.confirmationDialog(\"Delete?\", isPresented: $show) { }",
            "HStack { Text(\"a\") }.confirmationDialog(\"D\", isPresented: $s) { }",
            "List { Button(\"x\") { }.confirmationDialog(\"D\", isPresented: $s) { } }",
            "ForEach(items) { item in ItemRow(item: item).confirmationDialog(\"D\", isPresented: $s) { } }"
          ])
    func dialogOnTriggerDoesNotFire(source: String) {
        #expect(ItemUIRules.confirmationDialogsOnContainers(in: code(source)).isEmpty, "\(source)")
    }

    @Test("A confirmationDialog mentioned only in a comment does not fire")
    func dialogInCommentIgnored() {
        let source = "// List { }.confirmationDialog(\"x\", isPresented: $s) { }\nText(\"a\")"
        #expect(ItemUIRules.confirmationDialogsOnContainers(in: code(source)).isEmpty)
    }

    // MARK: Rule 2: raw red

    @Test("Raw red tokens fire", arguments: [
        "Text(\"a\").foregroundStyle(.red)",
        "let c = Color.red",
        "let c = Color(.red)",
        "Image(systemName: \"x\").foregroundColor(Color.red)",
        ".tint(.red)"
    ])
    func rawRedFires(source: String) {
        #expect(!ItemUIRules.rawRedLines(in: code(source)).isEmpty, "\(source)")
    }

    @Test("Tokens that merely contain red do not fire", arguments: [
        "Text(\"a\").foregroundStyle(Color.destructiveColor)",
        "Text(\"a\").redacted(reason: .placeholder)",
        "let c = UIColor.systemRed",
        "let name = \"shared\"",
        "// Color.red is forbidden\nlet a = 1"
    ])
    func rawRedDoesNotFire(source: String) {
        #expect(ItemUIRules.rawRedLines(in: code(source)).isEmpty, "\(source)")
    }

    // MARK: Rule 3: destructive needs the token

    @Test("A destructive button without destructiveColor fires", arguments: [
        "Button(\"Delete\", role: .destructive) { go() }",
        "Button(role: .destructive) { go() } label: { Text(\"Delete\") }",
        "Button(role: .destructive) { go() } label: { Text(\"Delete\") }\nButton(\"Other\") { }.tint(Color.destructiveColor)",
        "Button(\"Delete\", role: .destructive) { go() }.padding()"
    ])
    func destructiveWithoutTokenFires(source: String) {
        #expect(!ItemUIRules.destructiveWithoutToken(in: code(source)).isEmpty, "\(source)")
    }

    @Test("A destructive button with destructiveColor in its declaration does not fire", arguments: [
        "Button(\"Delete\", role: .destructive) { go() }.tint(Color.destructiveColor)",
        "Button(role: .destructive) { go() } label: { Text(\"Delete\") }\n    .tint(.destructiveColor)",
        "Button(\"Delete\", role: .destructive) { go() }\n    .padding()\n    .tint(Color.destructiveColor)\n    .confirmationDialog(\"D\", isPresented: $s) { }",
        "Button(\"Delete\", role: .destructive) { go() }\n    .tint(Color.destructiveColor)\nButton(\"Other\") { }"
    ])
    func destructiveWithTokenDoesNotFire(source: String) {
        #expect(ItemUIRules.destructiveWithoutToken(in: code(source)).isEmpty, "\(source)")
    }

    @Test("A non-destructive button without the token does not fire")
    func plainButtonDoesNotFire() {
        #expect(ItemUIRules.destructiveWithoutToken(in: code("Button(\"Save\", role: .cancel) { }")).isEmpty)
    }

    // MARK: Rule 4: loadError needs clearLoadError()

    @Test("Reading loadError without clearLoadError() fires")
    func loadErrorWithoutClearFires() {
        #expect(ItemUIRules.readsLoadErrorWithoutClearing(code("if let e = itemService.loadError { Text(e.userMessage) }")))
    }

    @Test("Reading loadError together with clearLoadError() does not fire")
    func loadErrorWithClearDoesNotFire() {
        let source = "if let e = itemService.loadError { Text(e.userMessage) }\n.onDisappear { itemService.clearLoadError() }"
        #expect(!ItemUIRules.readsLoadErrorWithoutClearing(code(source)))
    }

    @Test("A file that never reads loadError does not fire; a comment about it is ignored")
    func noLoadErrorDoesNotFire() {
        #expect(!ItemUIRules.readsLoadErrorWithoutClearing(code("Text(\"a\")")))
        #expect(!ItemUIRules.readsLoadErrorWithoutClearing(code("// shows loadError\nText(\"a\")")))
    }

    // MARK: Rule 5: no .alert(

    @Test("An .alert( call fires; alert words elsewhere do not")
    func alertRule() {
        #expect(!ItemUIRules.alertLines(in: code("Text(\"a\")\n.alert(\"Error\", isPresented: $s) { }")).isEmpty)
        #expect(ItemUIRules.alertLines(in: code("let alertCount = 1\n// .alert(\"x\")\nText(\"alert\")")).isEmpty)
    }

    // MARK: Real sources

    private func itemFiles(file: String = #filePath) throws -> (tree: ItemSourceTree, files: [URL]) {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        let files = tree.all.filter { tree.relativePath($0).hasPrefix("Features/Items/") }
        #expect(!files.isEmpty, "No files found under Features/Items/")
        return (tree, files)
    }

    private func scan(_ rule: (String) -> [Int]) throws -> [String] {
        let (tree, files) = try itemFiles()
        var found: [String] = []
        for url in files {
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in rule(source) { found.append("\(tree.relativePath(url)):\(line)") }
        }
        return found
    }

    @Test("Features/Items: no confirmationDialog on a List, ScrollView, Form or NavigationStack")
    func realDialogs() throws {
        let found = try scan { ItemUIRules.confirmationDialogsOnContainers(in: $0) }
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test("Features/Items: no raw red")
    func realRed() throws {
        let found = try scan { ItemUIRules.rawRedLines(in: $0) }
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test("Features/Items: every role: .destructive button names destructiveColor")
    func realDestructive() throws {
        let found = try scan { ItemUIRules.destructiveWithoutToken(in: $0) }
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }

    @Test("Features/Items: a file that reads loadError also calls clearLoadError()")
    func realLoadError() throws {
        let (tree, files) = try itemFiles()
        var offenders: [String] = []
        for url in files {
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if ItemUIRules.readsLoadErrorWithoutClearing(source) { offenders.append(tree.relativePath(url)) }
        }
        #expect(offenders.isEmpty, "\(offenders.joined(separator: "\n"))")
    }

    @Test("Features/Items views and components: no .alert(")
    func realAlerts() throws {
        let (tree, files) = try itemFiles()
        var found: [String] = []
        for url in files {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/Items/Views/") || relative.hasPrefix("Features/Items/Components/") else { continue }
            let source = ItemSourceScan.codeOnly(try String(contentsOf: url, encoding: .utf8))
            for line in ItemUIRules.alertLines(in: source) { found.append("\(relative):\(line)") }
        }
        #expect(found.isEmpty, "\(found.joined(separator: "\n"))")
    }
}
