//
//  ItemSourceScanSupport.swift
//  ChristmasTrackerTests
//
//  Story I3c-B: shared helpers for the item text-scan tests (same approach as
//  ListSourceScanTests: the source root is found from #filePath, comments are stripped
//  before matching). Needs the checkout on disk, which scripts/test.sh has.
//

import Foundation

nonisolated struct ItemSourceTree: Sendable {
    let root: URL
    let all: [URL]

    /// Walks up from `file` to ChristmasTrackerTests, then to the sibling app folder
    /// `ChristmasTracker/ChristmasTracker`.
    static func load(from file: String) -> ItemSourceTree? {
        var directory = URL(fileURLWithPath: file).standardizedFileURL.deletingLastPathComponent()
        while directory.pathComponents.count > 1 {
            if directory.lastPathComponent == "ChristmasTrackerTests" {
                let root = directory.deletingLastPathComponent()
                    .appendingPathComponent("ChristmasTracker", isDirectory: true)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
                      isDirectory.boolValue,
                      let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                    return nil
                }
                var files: [URL] = []
                for case let url as URL in enumerator where url.pathExtension == "swift" {
                    files.append(url)
                }
                return ItemSourceTree(root: root, all: files.sorted { $0.path < $1.path })
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }

    func relativePath(_ url: URL) -> String {
        let rootPath = root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
    }

    func file(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }

    func exists(_ relative: String) -> Bool {
        FileManager.default.fileExists(atPath: file(relative).path)
    }

    func source(_ relative: String) -> String? {
        try? String(contentsOf: file(relative), encoding: .utf8)
    }
}

nonisolated enum ItemSourceScan {

    /// Removes block comments and line comments so a comment that mentions a token does not fail a scan.
    static func codeOnly(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        var blockDepth = 0
        while index < source.endIndex {
            let next = source.index(after: index)
            let pair = next < source.endIndex ? String(source[index...next]) : ""
            if pair == "/*" {
                blockDepth += 1
                index = source.index(after: next)
            } else if pair == "*/" && blockDepth > 0 {
                blockDepth -= 1
                index = source.index(after: next)
            } else if blockDepth > 0 {
                if source[index] == "\n" { result.append("\n") }
                index = next
            } else if pair == "//" {
                while index < source.endIndex && source[index] != "\n" {
                    index = source.index(after: index)
                }
            } else {
                result.append(source[index])
                index = next
            }
        }
        return result
    }

    /// Line numbers (1-based) of every match of `pattern` in `code`.
    static func matchingLines(_ pattern: String, in code: String) throws -> [Int] {
        let regex = try NSRegularExpression(pattern: pattern)
        let whole = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: whole).map { match in
            let prefix = code.prefix(match.range.location)
            return prefix.filter { $0 == "\n" }.count + 1
        }
    }

    /// The text from the first `{` after `header` to its matching `}`, or nil when not found.
    static func braceBody(after header: String, in code: String) -> String? {
        guard let headerRange = code.range(of: header),
              let open = code[headerRange.upperBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" {
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }
}
