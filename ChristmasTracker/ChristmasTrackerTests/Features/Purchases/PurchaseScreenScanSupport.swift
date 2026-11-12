//
//  PurchaseScreenScanSupport.swift
//  ChristmasTrackerTests
//
//  Story I4b-C: small helpers shared by the Story C source-scan tests. They reuse the existing
//  path mechanism (ItemSourceTree.load(from: #filePath)) and the existing comment and string
//  blanking (ItemSourceScan.codeOnly, RecordPurchaseViewRules.bare). A missing file is reported as
//  a missing file (a failed expectation), never as a crash and never as a pass over nothing.
//

import Foundation
@testable import ChristmasTracker

nonisolated struct ScreenSource: Sendable {
    let path: String
    /// Comments stripped, string contents intact.
    let code: String
    /// Comments stripped and string contents blanked.
    let bare: String
}

nonisolated enum PurchaseScreenScan {

    /// The source of one app file, or nil when it does not exist (or cannot be read).
    static func load(_ relative: String, tree: ItemSourceTree) -> ScreenSource? {
        guard tree.exists(relative), let raw = tree.source(relative) else { return nil }
        let code = ItemSourceScan.codeOnly(raw)
        return ScreenSource(path: relative, code: code, bare: RecordPurchaseViewRules.bare(code))
    }

    /// Every app file under `folder` whose file name starts with `prefix`, sorted by path.
    static func files(in folder: String, prefix: String, tree: ItemSourceTree) -> [ScreenSource] {
        tree.all.compactMap { url -> ScreenSource? in
            let relative = tree.relativePath(url)
            guard relative.hasPrefix(folder), url.lastPathComponent.hasPrefix(prefix) else { return nil }
            return load(relative, tree: tree)
        }
    }

    /// Every app file under `folder` (all of them), sorted by path.
    static func allFiles(in folder: String, tree: ItemSourceTree) -> [ScreenSource] {
        tree.all.compactMap { url -> ScreenSource? in
            let relative = tree.relativePath(url)
            guard relative.hasPrefix(folder) else { return nil }
            return load(relative, tree: tree)
        }
    }

    /// Number of non-overlapping occurrences of `needle` in `text`.
    static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return text.components(separatedBy: needle).count - 1
    }

    static func describe(_ found: [(String, [String])]) -> String {
        found.map { "\($0.0): \($0.1.joined(separator: ", "))" }.joined(separator: "\n")
    }
}
