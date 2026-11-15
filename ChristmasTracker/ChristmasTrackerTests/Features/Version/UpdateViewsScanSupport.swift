// UpdateViewsScanSupport.swift
// ChristmasTrackerTests
//
// VER1 V2: loads the update screen sources from disk for the source-scan tests. Reuses
// ItemSourceTree (path from #filePath) and ItemSourceScan.codeOnly (comments stripped).
// A missing file is a failed expectation, never a pass over nothing.

import Foundation

nonisolated struct UpdateScannedFile: Sendable {
    let path: String
    /// Comments stripped, string contents intact.
    let code: String

    /// Every string literal in the code, including the quotes.
    var stringLiterals: [String] {
        guard let regex = try? NSRegularExpression(pattern: "\"(?:[^\"\\\\\\n]|\\\\.)*\"") else { return [] }
        let range = NSRange(code.startIndex..., in: code)
        return regex.matches(in: code, range: range).compactMap { match in
            Range(match.range, in: code).map { String(code[$0]) }
        }
    }

    func matches(_ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }
}

nonisolated enum UpdateViewsScan {
    static let viewsFolder = "Features/Version/Views/"
    static let requiredView = "Features/Version/Views/UpdateRequiredView.swift"
    static let promptModifier = "Features/Version/Views/UpdatePromptModifier.swift"
    static let presentation = "Features/Version/UpdatePresentation.swift"

    static func tree(from file: String = #filePath) -> ItemSourceTree? {
        ItemSourceTree.load(from: file)
    }

    static func load(_ relative: String, tree: ItemSourceTree) -> UpdateScannedFile? {
        guard tree.exists(relative), let raw = tree.source(relative) else { return nil }
        return UpdateScannedFile(path: relative, code: ItemSourceScan.codeOnly(raw))
    }

    /// The two new view files plus the presentation type.
    static func threeFiles(tree: ItemSourceTree) -> [UpdateScannedFile] {
        [requiredView, promptModifier, presentation].compactMap { load($0, tree: tree) }
    }

    /// Every Swift file in the Views folder (must include the two new ones).
    static func viewFiles(tree: ItemSourceTree) -> [UpdateScannedFile] {
        tree.all.compactMap { url -> UpdateScannedFile? in
            let relative = tree.relativePath(url)
            guard relative.hasPrefix(viewsFolder) else { return nil }
            return load(relative, tree: tree)
        }
    }
}
