//
//  MembersChildrenLogScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3b-M2: text-scan evidence that the new member and child code logs nothing but constant
//  strings. In GeneratedClientMemberRepository.swift, GeneratedClientChildRepository.swift and
//  ChildService.swift every `Log...(` call (LogDebug, LogInfo, LogWarning, LogError,
//  LogCritical) must have only string-literal text with NO interpolation `\(`: member emails,
//  names and child names must never reach a log, and the repositories need no counts.
//  (LogHygieneScanTests already scans all of Features/ for sensitive values; this is the
//  stricter rule for the three files.) Whole-line comments are ignored.
//
//  The source root is found from #filePath, so the checkout must be on disk.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Members and children log scan")
struct MembersChildrenLogScanTests {

    nonisolated static let scannedFiles = [
        "GeneratedClientMemberRepository.swift",
        "GeneratedClientChildRepository.swift",
        "ChildService.swift"
    ]

    private static let callPattern = #"\bLog(Debug|Info|Warning|Error|Critical)\s*\("#

    private static func appSourceRoot(from file: URL) -> URL? {
        var directory = file.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let root = directory.deletingLastPathComponent().appendingPathComponent("ChristmasTracker", isDirectory: true)
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

    private static func locate(_ name: String, under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.lastPathComponent == name {
            return url
        }
        return nil
    }

    /// Source text without whole-line comments.
    private static func codeLines(_ source: String) -> [String] {
        source.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }

    /// The full text of every Log call: from the call name to its matching close parenthesis
    /// (parentheses inside the call, including those of an interpolation, are balanced).
    private static func logCalls(in code: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: callPattern)
        let chars = Array(code)
        let ns = code as NSString
        var calls: [String] = []
        for match in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
            // Character offset of the opening parenthesis (the match ends right after it).
            let prefix = ns.substring(to: match.range.location + match.range.length)
            var index = Array(prefix).count
            var depth = 1
            while index < chars.count, depth > 0 {
                if chars[index] == "(" { depth += 1 }
                if chars[index] == ")" { depth -= 1 }
                index += 1
            }
            let start = Array(ns.substring(to: match.range.location)).count
            calls.append(String(chars[start..<min(index, chars.count)]))
        }
        return calls
    }

    @Test("the three files exist (so the scan cannot pass vacuously)")
    func filesExist() throws {
        let root = try #require(Self.appSourceRoot(from: URL(fileURLWithPath: #filePath).standardizedFileURL))

        for name in Self.scannedFiles {
            #expect(Self.locate(name, under: root) != nil, "\(name) must exist")
        }
    }

    @Test("every Log call in the three files has only constant string text (no interpolation)", arguments: MembersChildrenLogScanTests.scannedFiles)
    func logCallsAreConstant(name: String) throws {
        let root = try #require(Self.appSourceRoot(from: URL(fileURLWithPath: #filePath).standardizedFileURL))
        let url = try #require(Self.locate(name, under: root), "\(name) must exist")
        let code = Self.codeLines(try String(contentsOf: url, encoding: .utf8)).joined(separator: "\n")

        let calls = try Self.logCalls(in: code)

        for call in calls {
            #expect(!call.contains("\\("), "a Log call in \(name) interpolates a value: \(call)")
        }
    }

    @Test("the scanner itself flags an interpolated call and passes a constant one")
    func scannerSelfCheck() throws {
        let bad = try Self.logCalls(in: #"LogError("failed for \(child.firstName)", category: .business)"#)
        let good = try Self.logCalls(in: #"LogError("Add member failed", category: .business)"#)

        #expect(bad.count == 1 && bad[0].contains("\\("))
        #expect(good.count == 1 && !good[0].contains("\\("))
    }
}
