//
//  BudgetScanSupport.swift
//  ChristmasTrackerTests
//
//  I5a Story B: text-scan helpers for the Statistics and Budgets repository and service sources. The
//  source root is found from #filePath (see ItemSourceTree), comments are stripped before matching
//  (ItemSourceScan.codeOnly). Each rule is proven on in-memory strings in BudgetSourceScanTests before
//  it runs on disk.
//
//  The words of the forbidden concurrency APIs are built from pieces, so this file (and the tests)
//  never contain them literally.
//

import Foundation

nonisolated enum BudgetScan {

    /// The production folders under scan (relative to the app source root).
    static let folders = [
        "Features/Statistics/Repositories/", "Features/Statistics/Services/",
        "Features/Budgets/Repositories/", "Features/Budgets/Services/"
    ]

    // MARK: Forbidden concurrency APIs

    static let forbiddenConcurrency: [String] = [
        "Dispatch" + "Queue", "Dispatch" + "Group", "Dispatch" + "Semaphore", "Dispatch" + "Source",
        "import " + "Combine", "Pass" + "throughSubject", "Current" + "ValueSubject", "Operation" + "Queue"
    ]

    static func concurrencyViolations(in code: String) -> [String] {
        forbiddenConcurrency.filter { code.contains($0) }.map { "forbidden API \($0)" }
    }

    // MARK: Raw errors, print, persistence

    static func rawErrorViolations(in code: String) -> [String] {
        var found: [String] = []
        let rules: [(String, String)] = [
            ("interpolated error", #"\\\(\s*(error|err|cause)\b"#),
            ("described error", #"String\((describing|reflecting):\s*(error|err|cause)\b"#),
            ("error.localizedDescription", #"\b(error|err|cause)\.localizedDescription\b"#),
            ("print, NSLog or os_log", #"\b(print|NSLog|os_log|debugPrint)\("#)
        ]
        for (name, pattern) in rules {
            for line in (try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1] {
                found.append("\(name) at line \(line)")
            }
        }
        return found
    }

    static func persistenceViolations(in code: String) -> [String] {
        let pattern = #"UserDefaults|@AppStorage|@SceneStorage|Keychain|NetworkCache|ItemDataStore|ListDataStore|FileManager|\.write\(to"#
        return ((try? ItemSourceScan.matchingLines(pattern, in: code)) ?? [-1]).map { "persistence API at line \($0)" }
    }

    // MARK: Sentry

    /// The text between the parentheses of every call whose name matches `pattern` (balanced parentheses).
    static func calls(matching pattern: String, in code: String) -> [(line: Int, text: String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [(-1, "bad pattern")] }
        var result: [(line: Int, text: String)] = []
        for match in regex.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
            guard let range = Range(match.range, in: code) else { continue }
            var depth = 1
            var index = range.upperBound
            while index < code.endIndex && depth > 0 {
                if code[index] == "(" { depth += 1 }
                if code[index] == ")" { depth -= 1 }
                if depth > 0 { index = code.index(after: index) }
            }
            let line = code[code.startIndex..<range.lowerBound].filter { $0 == "\n" }.count + 1
            result.append((line, String(code[range.upperBound..<index])))
        }
        return result
    }

    /// A Sentry data call (a tag, an extra, a breadcrumb, a capture), or a transaction or span call
    /// whose arguments interpolate a value (an amount, a name, an id or an error could ride in it).
    static func sentryViolations(in code: String) -> [String] {
        var found: [String] = []
        let dataPattern = #"\.(setData|setExtra|setTag|addBreadcrumb|capture)\(|SentrySDK\.capture|\bBreadcrumb\("#
        for line in (try? ItemSourceScan.matchingLines(dataPattern, in: code)) ?? [-1] {
            found.append("sentry data call at line \(line)")
        }
        for call in calls(matching: #"\b(startTransaction|startChild|configureScope|SentrySpan)\w*\("#, in: code)
        where call.text.contains("\\(") {
            found.append("sentry call interpolates a value at line \(call.line)")
        }
        return found
    }

    // MARK: Output switches

    static func defaultCaseViolations(in code: String) -> [String] {
        ((try? ItemSourceScan.matchingLines(#"(?m)^\s*default\s*:"#, in: code)) ?? [-1]).map { "default case at line \($0)" }
    }

    // MARK: @Instrumented

    /// The names of `async throws` functions that carry no @Instrumented attribute on the same line or
    /// within the three lines above their declaration.
    static func uninstrumentedAsyncThrows(in code: String) -> [String] {
        let lines = code.components(separatedBy: "\n")
        var found: [String] = []
        for (index, line) in lines.enumerated() {
            guard let nameRange = line.range(of: #"\bfunc\s+\w+"#, options: .regularExpression) else { continue }
            var signature = ""
            var hasBody = false
            for next in index..<min(index + 8, lines.count) {
                let isBlank = lines[next].trimmingCharacters(in: .whitespaces).isEmpty
                // A protocol requirement has no body: the next blank line or function ends the search.
                if next > index && (isBlank || lines[next].contains("func ")) { break }
                signature += lines[next] + " "
                if lines[next].contains("{") {
                    hasBody = true
                    break
                }
            }
            guard hasBody else { continue }
            let header = signature.components(separatedBy: "{").first ?? signature
            guard header.range(of: #"\basync\b[^{]*\bthrows\b"#, options: .regularExpression) != nil else { continue }
            let from = max(0, index - 3)
            let context = lines[from...index].joined(separator: "\n")
            if !context.contains("@Instrumented") {
                found.append(String(line[nameRange]).replacingOccurrences(of: "func ", with: ""))
            }
        }
        return found
    }
}
