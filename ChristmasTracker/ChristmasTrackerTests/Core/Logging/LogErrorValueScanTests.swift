//
//  LogErrorValueScanTests.swift
//  ChristmasTrackerTests
//
//  Story I3c-E: no log call under Features/Items or Features/Lists may interpolate a RAW ERROR
//  VALUE. An error's description can carry a server message, an id, a name or an email, so the
//  log may say which operation failed (a constant or an `operation` label), a count, a status
//  code or a category, but never the error itself. (LogHygieneScanTests allows `\(error)`; this
//  is the stricter rule for the two folders.) Purchases folders are NOT scanned here; their
//  violations are carried to I4.
//
//  What is scanned: every .swift file under ChristmasTracker/ChristmasTracker/Features/Items and
//  Features/Lists. Call detection and interpolation extraction are the LogHygieneScanTests
//  helpers (`LogDebug(`...`LogCritical(`, multi-line, literals tracked, comment and `func` lines
//  skipped), and `LogHygieneScanTests.paths(inExpression:)` supplies identifier paths with string
//  literals removed.
//
//  PATTERN (documented): an interpolation is an error-value hit when any identifier path in it
//  has a dot-separated component that is
//    1. `error`, `err`, `e`, `ex`, `exception` or `failure`, compared case-insensitively and as a
//       whole word (so \(error), \(error.localizedDescription), \(String(describing: error)),
//       \(err), \(e), \(response.error));
//    2. an identifier ending in `Error` (case-sensitive), e.g. \(authError), \(underlyingError),
//       \(networkError); or
//    3. a name bound by `catch let NAME` in the same source file (a variable holding an Error
//       under a custom name, e.g. `catch let failureReason`).
//  Allowed: counts (`fetched.count`), constants, `operation`, `statusCode`, category strings,
//  `errorCount`/`errorCode` (not whole-word `error`, no `Error` suffix), and the word "error"
//  inside a string literal.
//
//  ALLOWLIST: an explicit array of (relative path, line-text substring, reason). It starts EMPTY
//  and is only to be extended with a written reason.
//
//  The source root is found from #filePath, so the checkout must be on disk.
//

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Log error value scan Tests")
struct LogErrorValueScanTests {

    // MARK: - Allowlist

    struct AllowEntry: Sendable {
        let path: String          // relative to ChristmasTracker/ChristmasTracker
        let lineContains: String
        let reason: String
    }

    /// Starts EMPTY on purpose.
    static let allowlist: [AllowEntry] = []

    // MARK: - Scanner

    private static let callPattern = #"\bLog(Debug|Info|Warning|Error|Critical)\s*\("#

    private static let errorWords: Set<String> = ["error", "err", "e", "ex", "exception", "failure"]

    /// Names bound with `catch let NAME` in the source.
    static func catchBoundNames(in source: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\bcatch\s+(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)"#) else {
            return []
        }
        var names: Set<String> = []
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            if let range = Range(match.range(at: 1), in: source) { names.insert(String(source[range])) }
        }
        return names
    }

    static func isErrorValue(path: String, catchNames: Set<String>) -> Bool {
        path.split(separator: ".").map(String.init).contains { component in
            errorWords.contains(component.lowercased())
                || (component.hasSuffix("Error") && component.count > "Error".count)
                || catchNames.contains(component)
        }
    }

    /// All raw-error interpolations in log calls of one source text.
    static func errorValueHits(in source: String) -> [LogHygieneScanTests.Hit] {
        guard let call = try? NSRegularExpression(pattern: callPattern) else { return [] }
        let catchNames = catchBoundNames(in: source)
        let lines = source.components(separatedBy: "\n")
        var hits: [LogHygieneScanTests.Hit] = []
        for (lineIndex, text) in lines.enumerated() {
            for match in call.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let prefix = String(text[text.startIndex..<matchRange.lowerBound])
                if prefix.contains("//") || prefix.contains("func ") { continue }
                let rest = String(text[matchRange.upperBound...])
                let following = lines[(lineIndex + 1)...].prefix(60)
                let tail = Array(([rest] + following).joined(separator: "\n"))
                for interpolation in LogHygieneScanTests.interpolations(inCallTail: tail) {
                    for path in LogHygieneScanTests.paths(inExpression: interpolation.expression)
                    where isErrorValue(path: path, catchNames: catchNames) {
                        hits.append(LogHygieneScanTests.Hit(
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

    private static let scannedFolders = ["Features/Items", "Features/Lists"]

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
        let files: [URL]
    }

    private func makeSUT(file: String = #filePath) throws -> Sources {
        let thisFile = URL(fileURLWithPath: file).standardizedFileURL
        let root = try #require(Self.appSourceRoot(from: thisFile),
                                "Could not find the ChristmasTracker app source folder from \(thisFile.path)")
        var files: [URL] = []
        for folder in Self.scannedFolders {
            files += Self.swiftFiles(under: root.appendingPathComponent(folder, isDirectory: true))
        }
        try #require(!files.isEmpty, "No .swift files found under \(Self.scannedFolders)")
        return Sources(root: root, files: files)
    }

    private func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }

    // MARK: - Scanner self-tests (positive)

    @Test("every form of interpolating the error identifier is a hit",
          arguments: [
              #"LogError("failed: \(error)")"#,
              #"LogError("failed: \(error.localizedDescription)")"#,
              #"LogError("failed: \(String(describing: error))")"#,
              #"LogWarning("failed: \(err)")"#,
              #"LogInfo("failed: \(e)")"#,
              #"LogError("failed: \(self.error)")"#,
              #"LogError("failed: \(response.error)")"#,
              #"LogCritical("failed: \(authError)", category: .business)"#,
              #"LogError("failed: \(underlyingError.localizedDescription)")"#,
              #"LogDebug("failed: \(error as NSError)")"#,
              #"LogError("failed: \(Self.describe(error))")"#
          ])
    func hitsOnErrorForms(source: String) {
        #expect(LogErrorValueScanTests.errorValueHits(in: source).isEmpty == false, "\(source)")
    }

    @Test("a variable bound by catch let is treated as an error value")
    func hitsOnCatchBoundVariable() {
        let source = #"""
        func run() async {
            do {
                try await work()
            } catch let failureReason {
                LogError("failed: \(failureReason)", category: .business)
            }
        }
        """#
        let hits = Self.errorValueHits(in: source)
        #expect(hits.map(\.path) == ["failureReason"])
        #expect(hits.first?.line == 5)
    }

    @Test("a multi-line call reports the line of the error interpolation")
    func hitOnMultiLineCall() {
        let source = #"""
        func load() {
            LogError(
                "Could not load: \(error.localizedDescription)",
                category: .business
            )
        }
        """#
        let hits = Self.errorValueHits(in: source)
        #expect(hits.map(\.path) == ["error.localizedDescription"])
        #expect(hits.first?.line == 3)
    }

    @Test("one hit per error interpolation when a call has several")
    func severalHitsInOneCall() {
        #expect(Self.errorValueHits(in: #"LogError("a \(error) b \(err)")"#).count == 2)
    }

    // MARK: - Scanner self-tests (negative)

    @Test("counts, operation labels, status codes and constants are not hits",
          arguments: [
              #"LogInfo("Loaded \(fetched.count) items", category: .business)"#,
              #"LogError("\(operation) failed", category: .business)"#,
              #"LogWarning("status \(statusCode)")"#,
              #"LogError("Add member failed", category: .business)"#,
              #"LogError("failed with code \(errorCode) after \(errorCount) tries")"#,
              #"LogInfo("category \(category.rawValue)")"#
          ])
    func noHitOnSafeInterpolations(source: String) {
        #expect(LogErrorValueScanTests.errorValueHits(in: source).isEmpty, "\(source)")
    }

    @Test("the word error inside a string literal or message is not a hit")
    func literalErrorWordIsNotAHit() {
        #expect(Self.errorValueHits(in: #"LogError("error loading items")"#).isEmpty)
        #expect(Self.errorValueHits(in: #"LogInfo("v \(flag ? "error" : "ok")")"#).isEmpty)
    }

    @Test("a catch-bound name that is not interpolated is not a hit")
    func catchBoundButNotLogged() {
        let source = #"""
        do { try await work() } catch let failureReason {
            handle(failureReason)
            LogError("work failed", category: .business)
        }
        """#
        #expect(Self.errorValueHits(in: source).isEmpty)
    }

    @Test("comments and function declarations are not calls")
    func commentsAndDeclarationsSkipped() {
        #expect(Self.errorValueHits(in: #"// LogError("x \(error)")"#).isEmpty)
        #expect(Self.errorValueHits(in: #"/// LogError("x \(error)")"#).isEmpty)
        #expect(Self.errorValueHits(in: "nonisolated func LogError(_ error: Error) {}").isEmpty)
    }

    @Test("a literal parenthesis inside the message does not end the call early")
    func parenInsideLiteral() {
        #expect(Self.errorValueHits(in: #"LogError("done :) \(error)")"#).map(\.path) == ["error"])
    }

    // MARK: - The scan

    @Test("The scanner reaches the Items and Lists sources")
    func scannerReachesFolders() throws {
        let sources = try makeSUT()
        let names = sources.files.map { relativePath($0, root: sources.root) }
        #expect(names.contains { $0.hasPrefix("Features/Items/") })
        #expect(names.contains { $0.hasPrefix("Features/Lists/") })
    }

    @Test("No log call under Features/Items or Features/Lists interpolates a raw error value")
    func noRawErrorInterpolationInItemsAndListsLogs() throws {
        let sources = try makeSUT()
        var offenders: [String] = []
        for url in sources.files {
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.components(separatedBy: "\n")
            let name = relativePath(url, root: sources.root)
            for hit in Self.errorValueHits(in: text) {
                let lineText = hit.line >= 1 && hit.line <= lines.count ? lines[hit.line - 1] : ""
                let allowed = Self.allowlist.contains {
                    $0.path == name && lineText.contains($0.lineContains)
                }
                if !allowed {
                    offenders.append("\(name):\(hit.line) interpolates \(hit.path)")
                }
            }
        }
        #expect(offenders.isEmpty, "Raw error values in log calls:\n\(offenders.joined(separator: "\n"))")
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
