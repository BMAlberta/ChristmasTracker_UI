//
//  SourceAndTestFiles.swift
//  ChristmasTrackerTests
//
//  Story I4b-D: support for scans that cover production AND test sources. It reuses
//  `ItemSourceTree` (the app folder, found from #filePath) and reads the sibling
//  ChristmasTrackerTests folder the same way: the folder name is the one `ItemSourceTree.load`
//  already walks up to. Needs the checkout on disk, which scripts/test.sh has.
//

import Foundation

nonisolated struct SourceFile: Sendable {
    /// "ChristmasTracker/..." for production files and "ChristmasTrackerTests/..." for test files.
    let relative: String
    let url: URL
}

extension ItemSourceTree {

    /// Every .swift file of the app target and of the test target.
    func productionAndTestFiles() -> [SourceFile] {
        var result = all.map { SourceFile(relative: "ChristmasTracker/" + relativePath($0), url: $0) }
        let testRoot = root.deletingLastPathComponent().appendingPathComponent("ChristmasTrackerTests", isDirectory: true)
        if let enumerator = FileManager.default.enumerator(at: testRoot, includingPropertiesForKeys: nil) {
            let rootPath = testRoot.standardizedFileURL.path + "/"
            var tests: [SourceFile] = []
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let path = url.standardizedFileURL.path
                let tail = path.hasPrefix(rootPath) ? String(path.dropFirst(rootPath.count)) : path
                tests.append(SourceFile(relative: "ChristmasTrackerTests/" + tail, url: url))
            }
            result.append(contentsOf: tests.sorted { $0.relative < $1.relative })
        }
        return result
    }
}
