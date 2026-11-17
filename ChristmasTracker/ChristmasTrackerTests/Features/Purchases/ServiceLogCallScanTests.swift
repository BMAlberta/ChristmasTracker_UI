//
//  ServiceLogCallScanTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3: the sibling of the `Log*(` hygiene scans for the ServiceLog step lines. Every
//  `log.started(`, `log.processed(`, `log.cancelled(`, `log.failed(` and `log.skipped(` call in a scanned
//  service has an argument list that is exactly one of:
//    - the operation identifier `op` / `opName`, or a string literal with no interpolation;
//    - `op, count: <identifier or member path>, noun: "<literal>"`;
//    - `op, reason: <identifier>`.
//  Every `let op = ...` / `let opName = ...` is a string literal with no interpolation. So an id, a
//  name, an amount or an error can never reach a step line. To cover another service, add its path
//  to `ServiceLogCallScan.files`.
//
//  Calls are read across line breaks (from the opening parenthesis to its matching one). Comments
//  are stripped first. The scanner is proven on in-memory strings before it runs on disk.
//

import Testing
import Foundation
@testable import ChristmasTracker

nonisolated enum ServiceLogCallScan {

    /// Service files under the app source folder that write step lines through ServiceLog.
    static let files = [
        "Features/Purchases/Services/PurchaseService.swift",
        "Features/Items/Services/ItemService.swift",
        "Features/Children/Services/ChildService.swift",
        "Features/Lists/Services/ListService.swift",
        "Features/LinkPreview/Services/LinkPreviewService.swift",
        "Core/API/VersionService.swift"
    ]

    private static let literal = #""(?:[^"\\]|\\[^(])*""#
    private static let opName = #"(?:op|opName)"#
    private static let allowed = [
        "^\(opName)$",
        "^\(literal)$",
        "^\(opName), count: [A-Za-z_][A-Za-z0-9_.]*, noun: \(literal)$",
        "^\(literal), count: [A-Za-z_][A-Za-z0-9_.]*, noun: \(literal)$",
        "^\(opName), reason: [A-Za-z_][A-Za-z0-9_]*$"
    ]

    struct Call: Equatable {
        let line: Int
        let text: String
    }

    /// Every `log.<step>(...)` call in `code`, with the text between its parentheses.
    static func calls(in code: String) throws -> [Call] {
        let regex = try NSRegularExpression(pattern: #"\blog\.(?:started|processed|cancelled|failed|skipped)\("#)
        var result: [Call] = []
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let range = Range(match.range, in: code) else { continue }
            var depth = 1
            var index = range.upperBound
            while index < code.endIndex && depth > 0 {
                if code[index] == "(" { depth += 1 }
                if code[index] == ")" { depth -= 1 }
                if depth > 0 { index = code.index(after: index) }
            }
            let text = String(code[range.upperBound..<index])
            let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
            result.append(Call(line: line, text: text))
        }
        return result
    }

    private static func matches(_ pattern: String, _ text: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Short descriptions of every step call or `let op` that is not one of the allowed shapes.
    static func violations(in code: String) throws -> [String] {
        var found: [String] = []
        for call in try calls(in: code) {
            let text = call.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            var ok = false
            for pattern in allowed {
                if try matches(pattern, text) { ok = true }
            }
            if !ok { found.append("step log call has a disallowed argument list at line \(call.line)") }
        }
        let lets = try NSRegularExpression(pattern: #"\blet (?:op|opName)\b[^=\n]*=\s*([^\n]*)"#)
        for match in lets.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let range = Range(match.range(at: 1), in: code) else { continue }
            let value = String(code[range]).trimmingCharacters(in: .whitespaces)
            if !(try matches("^\(literal)$", value)) {
                let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
                found.append("operation name is not a plain string literal at line \(line)")
            }
        }
        return found
    }
}

@Suite("ServiceLog call scan Tests")
struct ServiceLogCallScanTests {

    private func code(_ source: String) -> String { ItemSourceScan.codeOnly(source) }

    // MARK: Scanner self-proofs

    @Test("The scanner fires on interpolation, non-literal arguments and a non-literal noun", arguments: [
        #"log.started("x \(price)")"#,
        #"log.failed("failed \(error)")"#,
        "log.processed(notes)",
        "log.failed(String(describing: error))",
        "log.started(op, reason: .pull)",
        "log.processed(op, count: items.count, noun: nounVariable)",
        #"log.processed(op, count: items.count, noun: "\(name)")"#,
        "log.processed(op, count: total + 1, noun: \"items\")",
        "log.started(op, extra)",
        "log.skipped(item.name)",
        "log.cancelled(\n    name\n)",
        #"let op = "load \(name)""#,
        "let op = someName",
        "let opName = makeName()"
    ])
    func scannerFires(source: String) throws {
        #expect(!(try ServiceLogCallScan.violations(in: code(source))).isEmpty, "\(source)")
    }

    @Test("The scanner allows the fixed step line shapes, comments and look-alike names", arguments: [
        "log.started(op)",
        "log.started(opName)",
        #"log.failed("purchase management")"#,
        "log.started(op, reason: reason)",
        "log.processed(op)",
        "log.processed(op, count: items.count, noun: \"items\")",
        "log.processed(op, count: fetched.count, noun: \"children\")",
        "log.processed(\n    op,\n    count: rows.count,\n    noun: \"rows\"\n)",
        "log.cancelled(op)",
        "log.skipped(op)",
        #"let op = "load items""#,
        #"let opName = "create item""#,
        #"// log.started("x \(price)")"#,
        "/* log.processed(notes) */",
        "catalog.started(thing)",
        "let operation = makeName()"
    ])
    func scannerAllows(source: String) throws {
        #expect(try ServiceLogCallScan.violations(in: code(source)).isEmpty, "\(source)")
    }

    @Test("The scanner finds each call, its line, and reads past parentheses inside the argument")
    func scannerReadsCalls() throws {
        let source = "let a = 1\nlog.started(\"one (two)\")\nlet b = 2\nlog.failed(op)"
        let calls = try ServiceLogCallScan.calls(in: source)
        #expect(calls.map(\.line) == [2, 4])
        #expect(calls.first?.text == "\"one (two)\"")
        #expect(calls.last?.text == "op")
    }

    // MARK: The scanned services

    @Test("Every step log call and operation name in a scanned service is fixed", arguments: ServiceLogCallScan.files)
    func serviceLogCallsAreFixed(path: String) throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        let source = try #require(tree.source(path), "Could not read \(path)")
        let stripped = code(source)

        #expect(!(try ServiceLogCallScan.calls(in: stripped)).isEmpty, "\(path) has no step log calls: scan is vacuous")
        let violations = try ServiceLogCallScan.violations(in: stripped)
        #expect(violations.isEmpty, "\(path):\n\(violations.joined(separator: "\n"))")
    }
}
