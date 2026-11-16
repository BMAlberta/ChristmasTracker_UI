//
//  ItemImageFillSourceScanTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P3: text scans (comments stripped) that keep the Add and Edit forms on the same trigger
//  path, keep URLs out of logs, and pin the spinner label and the preview thumbnail.
//
//  Assumption: each form holds its model in a property whose declaration mentions
//  ItemImageFillModel (e.g. `@State private var fill = ItemImageFillModel(...)`) and passes that
//  name inside the ItemFormFields( call.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item image fill source scan Tests")
struct ItemImageFillSourceScanTests {

    private let addView = "Features/Items/Views/AddItemView.swift"
    private let editView = "Features/Items/Views/EditItemView.swift"
    private let thumbnailFile = "Features/Items/Components/ItemThumbnail.swift"

    private func makeSUT() throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: #filePath), "App source tree not found")
    }

    private func code(_ tree: ItemSourceTree, _ relative: String) throws -> String {
        ItemSourceScan.codeOnly(try #require(tree.source(relative), "Missing source file \(relative)"))
    }

    private func codeFiles(_ tree: ItemSourceTree, under prefixes: [String]) -> [(path: String, code: String)] {
        tree.all.compactMap { url in
            let relative = tree.relativePath(url)
            guard prefixes.contains(where: { relative.hasPrefix($0) }),
                  let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (relative, ItemSourceScan.codeOnly(source))
        }
    }

    /// Text inside the parentheses of the first `header(` (header includes the open paren).
    private func parenBody(after header: String, in code: String) -> String? {
        guard let range = code.range(of: header) else { return nil }
        var depth = 1
        var index = range.upperBound
        while index < code.endIndex {
            if code[index] == "(" { depth += 1 }
            if code[index] == ")" {
                depth -= 1
                if depth == 0 { return String(code[range.upperBound..<index]) }
            }
            index = code.index(after: index)
        }
        return nil
    }

    // MARK: - Same trigger path

    @Test("Both forms own an ItemImageFillModel and pass it into ItemFormFields", arguments: [
        "Features/Items/Views/AddItemView.swift", "Features/Items/Views/EditItemView.swift"
    ])
    func formsPassTheModel(file: String) throws {
        let tree = try makeSUT()
        let source = try code(tree, file)
        #expect(source.contains("ItemImageFillModel"))

        let regex = try NSRegularExpression(pattern: #"(?:let|var)\s+(\w+)[^\n]*ItemImageFillModel"#)
        let match = try #require(regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
                                 "no property of type ItemImageFillModel in \(file)")
        let name = String(source[try #require(Range(match.range(at: 1), in: source))])
        let arguments = try #require(parenBody(after: "ItemFormFields(", in: source))
        #expect(arguments.contains(name), "\(file) must pass \(name) into ItemFormFields")
    }

    @Test("Neither form calls the trigger", arguments: [
        "Features/Items/Views/AddItemView.swift", "Features/Items/Views/EditItemView.swift"
    ])
    func formsDoNotTrigger(file: String) throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, file)).contains("urlEditingFinished"))
    }

    @Test("urlEditingFinished is called from exactly one place outside ViewState, in Features/Items/Components")
    func triggerInOnePlace() throws {
        let tree = try makeSUT()
        let hits = codeFiles(tree, under: [""]).filter {
            !$0.path.hasPrefix("Features/Items/ViewState/") && $0.code.contains("urlEditingFinished")
        }
        #expect(hits.count == 1, "files: \(hits.map(\.path))")
        let hit = try #require(hits.first)
        #expect(hit.path.hasPrefix("Features/Items/Components/"))
        let calls = try ItemSourceScan.matchingLines(#"urlEditingFinished\s*\("#, in: hit.code)
        #expect(calls.count == 1, "the trigger must be called from one line in \(hit.path)")
    }

    // MARK: - Logging, concurrency

    @Test("The fill state and model files contain no logging or reporting at all",
          arguments: ["LogError", "LogInfo", "LogDebug", "LogWarning", "Logger", "print(", "NSLog", "os_log",
                      "SentrySDK", "addBreadcrumb", "captureMessage", "capture(", "setExtra", "Breadcrumb"])
    func fillFilesDoNotLog(token: String) throws {
        let tree = try makeSUT()
        let files = codeFiles(tree, under: ["Features/Items/ViewState/"]).filter { $0.code.contains("ItemImageFill") }
        #expect(!files.isEmpty, "no ItemImageFill files in Features/Items/ViewState")
        for file in files {
            #expect(!file.code.contains(token), "\(file.path) must not contain \(token)")
        }
    }

    @Test("No item view or component logs a URL")
    func viewsDoNotLogUrls() throws {
        let tree = try makeSUT()
        let pattern = #"(?i)(LogError|LogInfo|LogDebug|LogWarning|Logger|print|NSLog|os_log|addBreadcrumb|capture\w*|setExtra|setTag)\b[^\n]*url"#
        for file in codeFiles(
            tree, under: ["Features/Items/ViewState/", "Features/Items/Views/", "Features/Items/Components/"]
        ) {
            let lines = try ItemSourceScan.matchingLines(pattern, in: file.code)
            #expect(lines.isEmpty, "\(file.path) logs or reports a url on lines \(lines)")
        }
    }

    @Test("The Items view state, views and components use no reactive framework and no GCD queue",
          arguments: ["Com" + "bine", "Dispatch" + "Queue"])
    func noReactiveOrGCD(token: String) throws {
        let tree = try makeSUT()
        for file in codeFiles(
            tree, under: ["Features/Items/ViewState/", "Features/Items/Views/", "Features/Items/Components/"]
        ) {
            #expect(!file.code.contains(token), "\(file.path) must not contain \(token)")
        }
    }

    // MARK: - Spinner and preview

    @Test("The spinner is a ProgressView labelled with ItemFormCopy.lookingForImage")
    func spinnerLabel() throws {
        let tree = try makeSUT()
        let files = codeFiles(tree, under: ["Features/Items/Components/"]).filter {
            $0.code.contains("ItemFormCopy.lookingForImage")
        }
        #expect(!files.isEmpty, "no component uses ItemFormCopy.lookingForImage")
        for file in files {
            #expect(file.code.contains("ProgressView"))
            #expect(file.code.contains("accessibilityLabel"))
        }
    }

    @Test("The preview thumbnail in the form is the existing ItemThumbnail")
    func previewUsesItemThumbnail() throws {
        let tree = try makeSUT()
        let users = codeFiles(tree, under: ["Features/Items/Components/"]).filter {
            $0.path != thumbnailFile && $0.code.contains("ItemThumbnail(")
        }
        #expect(!users.isEmpty, "no form component uses ItemThumbnail(")
        let formFiles = codeFiles(tree, under: ["Features/Items/Components/", "Features/Items/Views/"])
        #expect(!formFiles.contains { $0.code.contains("AsyncImage") && $0.path != thumbnailFile })
    }
}
