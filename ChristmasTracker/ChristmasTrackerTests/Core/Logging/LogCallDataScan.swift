//
//  LogCallDataScan.swift
//  ChristmasTrackerTests
//
//  LG1-L4, rule R2 scanner: "no data in a log call". It reads, across line breaks and with strings and nested
//  interpolations understood, every
//    - `LogDebug/Info/Warning/Error/Critical(` call: the first argument must be ONE string literal, then
//      only an optional `category: .<case>`;
//    - `log.log(` / `sink.log(` call (the transport): `<level>, <one string literal>, category: .<case>`
//      where level is `.<case>` or `<flag> ? .<case> : .<case>`;
//    - `log.<started|processed|cancelled|failed|skipped>(` call and `let op` / `let opName`: delegated to
//      `ServiceLogCallScan` (fixed shapes only);
//    - `op:` / `opName:` argument at a call site: a string literal or the pass-through `op` / `opName`
//      (the parameter declaration `op: String` is fine).
//  Every interpolation `\(expression)` inside a log string must be one of the allowed shapes below.
//

import Foundation

nonisolated enum LogCallDataScan {

    /// Identifier names that may be interpolated. All are operation names, counters, durations, status codes
    /// or fixed categories. `parts` and `detail` are the transport's locals, built only from `status`, `ms`,
    /// a sanitized request id and the stable error category. `archivedCount` is a plain integer counter.
    static let allowedNames: Set<String> = [
        "operationID", "operation", "op", "opName", "attempt", "status", "ms", "duration", "requestID", "requestId",
        "category", "count", "noun", "reason", "method", "parts", "detail", "archivedCount"
    ]

    /// Non-name shapes: the method raw value, a `<path>.count`, and the transport's joined parts.
    private static let allowedShapes = [
        #"^method\.rawValue$"#,
        #"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\.count$"#,
        #"^parts\.joined\(separator: ", "\)$"#
    ]

    private static let functionShape = #"^""(?:, category: \.[A-Za-z]+)?$"#
    private static let transportShape = #"^(?:\.[A-Za-z]+|[A-Za-z_][A-Za-z0-9_]* \? \.[A-Za-z]+ : \.[A-Za-z]+), "#
        + #"\"{2}, category: \.[A-Za-z]+$"#
    private static let badOpArgument = #"\b(?:op|opName): (?!String\b)(?!op\b)(?!opName\b)"#
        + #"(?!"(?:[^"\\]|\\[^(])*")"#

    private struct Call {
        let line: Int
        let name: String
        let isTransport: Bool
        let outside: String
        let interpolations: [String]
    }

    // MARK: Reading a call

    /// Reads from `start` (just after an opening parenthesis) to its matching one.
    private static func readCall(
        _ chars: [Character], from start: Int
    ) -> (outside: String, interps: [String], end: Int) {
        var depth = 1
        var index = start
        var outside = ""
        var interps: [String] = []
        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                let read = readString(chars, from: index + 1)
                interps += read.interps
                outside += "\"\""
                index = read.end
                continue
            }
            if char == "(" { depth += 1 }
            if char == ")" {
                depth -= 1
                if depth == 0 { return (outside, interps, index) }
            }
            outside.append(char)
            index += 1
        }
        return (outside, interps, index)
    }

    /// Reads a string body from `start` (after the opening quote); returns the interpolation expressions and
    /// the index just after the closing quote.
    private static func readString(_ chars: [Character], from start: Int) -> (interps: [String], end: Int) {
        var index = start
        var interps: [String] = []
        while index < chars.count {
            if chars[index] == "\\" && index + 1 < chars.count {
                if chars[index + 1] == "(" {
                    let inner = readCall(chars, from: index + 2)
                    interps.append(String(chars[(index + 2)..<min(inner.end, chars.count)]))
                    index = inner.end + 1
                } else {
                    index += 2
                }
                continue
            }
            if chars[index] == "\"" { return (interps, index + 1) }
            index += 1
        }
        return (interps, index)
    }

    private static func calls(in code: String) throws -> [Call] {
        let chars = Array(code)
        let sources: [(pattern: String, transport: Bool)] = [
            (#"\bLog(?:Debug|Info|Warning|Error|Critical)\("#, false),
            (#"\b(?:log|sink)\.log\("#, true)
        ]
        var result: [Call] = []
        for source in sources {
            let regex = try NSRegularExpression(pattern: source.pattern)
            for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                guard let range = Range(match.range, in: code) else { continue }
                let offset = code.distance(from: code.startIndex, to: range.upperBound)
                let read = readCall(chars, from: offset)
                let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
                result.append(Call(line: line, name: String(code[range].dropLast()), isTransport: source.transport,
                                   outside: read.outside.split(whereSeparator: \.isWhitespace).joined(separator: " "),
                                   interpolations: read.interps))
            }
        }
        return result.sorted { $0.line < $1.line }
    }

    /// Number of `Log*(` calls (false) or `log.log(` / `sink.log(` calls (true) in `code`.
    static func callCount(in code: String, transport: Bool) throws -> Int {
        try calls(in: code).filter { $0.isTransport == transport }.count
    }

    // MARK: Checking

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isAllowed(_ expression: String) -> Bool {
        let text = expression.trimmingCharacters(in: .whitespaces)
        if allowedNames.contains(text) { return true }
        return allowedShapes.contains { matches($0, text) }
    }

    /// Short descriptions of every disallowed log call, `op:` argument, step call or `let op`.
    static func violations(in code: String) throws -> [String] {
        var found: [String] = []
        for call in try calls(in: code) {
            let shape = call.isTransport ? transportShape : functionShape
            if !matches(shape, call.outside) {
                found.append("\(call.name)( has a non-literal or unexpected argument at line \(call.line)")
            }
            for expression in call.interpolations where !isAllowed(expression) {
                found.append("\(call.name)( interpolates `\(expression)` at line \(call.line)")
            }
        }
        for line in try ItemSourceScan.matchingLines(badOpArgument, in: code) {
            found.append("op argument is not a string literal or op/opName at line \(line)")
        }
        found += try ServiceLogCallScan.violations(in: code)
        return found
    }
}
