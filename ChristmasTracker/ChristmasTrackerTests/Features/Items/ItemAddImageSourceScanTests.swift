//
//  ItemAddImageSourceScanTests.swift
//  ChristmasTrackerTests
//
//  IMG1-P5: text scans (comments stripped) that keep the "Add image" button and its failure line in
//  one component, instantiated from the Links section only, never from the Add form, with the
//  shared copy, a spinner, a polite announcement, and no logging of urls.
//

import Testing
import Foundation
@testable import ChristmasTracker

@Suite("Item add image source scan Tests")
struct ItemAddImageSourceScanTests {

    private let buttonFile = "Features/Items/Components/ItemAddImageButton.swift"
    private let linksFile = "Features/Items/Components/ItemLinksSection.swift"
    private let addView = "Features/Items/Views/AddItemView.swift"
    private let editView = "Features/Items/Views/EditItemView.swift"
    private let validationFile = "Features/Items/ViewState/ItemFormValidation.swift"

    private func makeSUT() throws -> ItemSourceTree {
        try #require(ItemSourceTree.load(from: #filePath), "App source tree not found")
    }

    private func code(_ tree: ItemSourceTree, _ relative: String) throws -> String {
        ItemSourceScan.codeOnly(try #require(tree.source(relative), "Missing source file \(relative)"))
    }

    private func allCode(_ tree: ItemSourceTree) -> [(path: String, code: String)] {
        tree.all.compactMap { url in
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return (tree.relativePath(url), ItemSourceScan.codeOnly(source))
        }
    }

    // MARK: - One place

    @Test("ItemAddImageButton( is instantiated from ItemLinksSection.swift only, once")
    func buttonInstantiatedOnce() throws {
        let tree = try makeSUT()
        #expect(tree.exists(buttonFile), "ItemAddImageButton.swift is missing")
        let hits = allCode(tree).filter { $0.path != buttonFile && $0.code.contains("ItemAddImageButton(") }
        #expect(hits.map(\.path) == [linksFile], "files: \(hits.map(\.path))")
        let hit = try #require(hits.first)
        let calls = try ItemSourceScan.matchingLines(#"ItemAddImageButton\s*\("#, in: hit.code)
        #expect(calls.count == 1)
    }

    @Test("addImageRequested( is called from one file outside ViewState, at one call site")
    func triggerInOnePlace() throws {
        let tree = try makeSUT()
        let hits = allCode(tree).filter {
            !$0.path.hasPrefix("Features/Items/ViewState/") && $0.code.contains("addImageRequested(")
        }
        #expect(hits.count == 1, "files: \(hits.map(\.path))")
        let hit = try #require(hits.first)
        #expect([buttonFile, linksFile].contains(hit.path), "unexpected caller \(hit.path)")
        let calls = try ItemSourceScan.matchingLines(#"addImageRequested\s*\("#, in: hit.code)
        #expect(calls.count == 1, "one call site expected in \(hit.path)")
    }

    @Test("Neither form view mentions addImageRequested", arguments: [
        "Features/Items/Views/AddItemView.swift", "Features/Items/Views/EditItemView.swift"
    ])
    func formsDoNotTrigger(file: String) throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, file)).contains("addImageRequested"))
    }

    @Test("AddItemView does not mention ItemAddImageButton")
    func addViewHasNoButton() throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, addView)).contains("ItemAddImageButton"))
    }

    // MARK: - The button file

    @Test("The button uses the shared copy, a spinner and an accessibility hint")
    func buttonUsesCopy() throws {
        let tree = try makeSUT()
        let source = try code(tree, buttonFile)
        #expect(source.contains("ItemFormCopy.addImageTitle"))
        #expect(source.contains("ItemFormCopy.addImageFailure"))
        #expect(source.contains("ProgressView"))
        let hint = try NSRegularExpression(pattern: #"accessibilityHint\s*\([^)]*ItemFormCopy\.addImageHint"#)
        #expect(hint.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) != nil,
                "ItemFormCopy.addImageHint must be the accessibilityHint")
    }

    @Test("The failure line is announced politely")
    func failureAnnounced() throws {
        let tree = try makeSUT()
        let source = try code(tree, buttonFile)
        #expect(source.contains("AccessibilityNotification.Announcement"))
    }

    @Test("The failure string literal lives in exactly one app file, ItemFormValidation.swift")
    func failureLiteralOnce() throws {
        let tree = try makeSUT()
        let hits = allCode(tree).filter { $0.code.contains("Couldn't find an image for this link.") }
        #expect(hits.map(\.path) == [validationFile], "files: \(hits.map(\.path))")
    }

    // MARK: - Privacy, concurrency

    @Test("The button file reports and logs nothing", arguments: [
        "LogError", "LogInfo", "LogDebug", "LogWarning", "Logger", "print(", "NSLog", "os_log",
        "SentrySDK", "addBreadcrumb", "captureMessage", "capture(", "setExtra", "Breadcrumb"
    ])
    func buttonDoesNotLog(token: String) throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, buttonFile)).contains(token))
    }

    @Test("No new or touched file logs or reports a url", arguments: [
        "Features/Items/Components/ItemAddImageButton.swift", "Features/Items/Components/ItemLinksSection.swift",
        "Features/Items/ViewState/ItemImageFillModel.swift", "Features/Items/ViewState/ItemImageFillState.swift"
    ])
    func noUrlLogging(file: String) throws {
        let tree = try makeSUT()
        let pattern = #"(?i)(LogError|LogInfo|LogDebug|LogWarning|Logger|print|NSLog|os_log|addBreadcrumb|capture\w*|setExtra|setTag)\b[^\n]*url"#
        let lines = try ItemSourceScan.matchingLines(pattern, in: try code(tree, file))
        #expect(lines.isEmpty, "\(file) logs or reports a url on lines \(lines)")
    }

    @Test("The button file uses no reactive framework and no GCD queue", arguments: ["Com" + "bine", "Dispatch" + "Queue"])
    func noReactiveOrGCD(token: String) throws {
        let tree = try makeSUT()
        #expect(!(try code(tree, buttonFile)).contains(token))
    }
}
