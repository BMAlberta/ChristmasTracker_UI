// UpdateViewsSourceScanTests.swift
// ChristmasTrackerTests
//
// VER1 V2: source scans over Features/Version/Views/ (UpdateRequiredView.swift and
// UpdatePromptModifier.swift) and Features/Version/UpdatePresentation.swift. A missing
// file is a failure, never a pass over an empty set.

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Update views source scan Tests")
struct UpdateViewsSourceScanTests {

    private func tree() throws -> ItemSourceTree {
        try #require(UpdateViewsScan.tree(), "app source tree not found")
    }

    private func viewFiles() throws -> [UpdateScannedFile] {
        let tree = try tree()
        let files = UpdateViewsScan.viewFiles(tree: tree)
        #expect(files.contains { $0.path == UpdateViewsScan.requiredView }, "UpdateRequiredView.swift is missing")
        #expect(files.contains { $0.path == UpdateViewsScan.promptModifier }, "UpdatePromptModifier.swift is missing")
        return files
    }

    private func threeFiles() throws -> [UpdateScannedFile] {
        let files = UpdateViewsScan.threeFiles(tree: try tree())
        #expect(files.count == 3, "expected UpdateRequiredView, UpdatePromptModifier and UpdatePresentation")
        return files
    }

    private func offenders(_ files: [UpdateScannedFile], pattern: String) -> [String] {
        files.filter { $0.matches(pattern) }.map(\.path)
    }

    // (a) no literal URL or host in the views

    @Test("views contain no URL or host string literal")
    func noLiteralURLs() throws {
        let files = try viewFiles()
        for file in files {
            for literal in file.stringLiterals {
                let lower = literal.lowercased()
                #expect(!lower.contains("http://"), "\(file.path): \(literal)")
                #expect(!lower.contains("https://"), "\(file.path): \(literal)")
                #expect(!lower.contains("itms-services"), "\(file.path): \(literal)")
                let hostLike = lower.range(
                    of: "[a-z0-9-]+\\.(com|org|net|io|app|dev|co|me|us|plist|ipa)\\b", options: .regularExpression)
                #expect(hostLike == nil, "\(file.path): host-like literal \(literal)")
            }
        }
    }

    // (b) the only thing opened is the install link

    @Test("views open only the UpdateInstallLink result")
    func opensOnlyInstallLink() throws {
        let files = try viewFiles()
        #expect(files.allSatisfy { !$0.matches("URL\\(string:") }, "URL(string:) found in a view file")
        let opening = files.filter { $0.matches("openURL\\(|\\.open\\(|\\bLink\\(") }
        #expect(!opening.isEmpty, "no view opens the install link at all")
        for file in opening {
            #expect(
                file.code.contains("UpdatePresentation.installLink") || file.code.contains("UpdateInstallLink.url"),
                "\(file.path) opens a URL that does not come from UpdatePresentation.installLink / UpdateInstallLink.url"
            )
        }
    }

    // (c) no auth service, session or store

    @Test("update files never touch authentication, session or stores")
    func noAuthOrStores() throws {
        let files = try threeFiles()
        let pattern = "authenticationService|AuthenticationService|SessionManager|\\blogout|\\bsignOut|\\b\\w*Store\\b"
        #expect(offenders(files, pattern: pattern).isEmpty, "\(offenders(files, pattern: pattern))")
    }

    // (d) nothing reaches a log

    @Test("update files never log or record")
    func noLogging() throws {
        let files = try threeFiles()
        let pattern = "\\bLogger\\b|\\bprint\\(|\\bLogInfo|\\bLogError|\\bLogWarning|SentrySDK|addBreadcrumb"
        #expect(offenders(files, pattern: pattern).isEmpty, "\(offenders(files, pattern: pattern))")
    }

    // (e) concurrency, force unwraps, dismissable sheets

    @Test("update files use no GCD, Combine, force cast or force try")
    func noBannedConstructs() throws {
        let files = try threeFiles()
        let pattern = "DispatchQueue|import Combine|\\bas!|\\btry!"
        #expect(offenders(files, pattern: pattern).isEmpty, "\(offenders(files, pattern: pattern))")
    }

    @Test("views present no sheet")
    func noSheet() throws {
        let files = try viewFiles()
        #expect(offenders(files, pattern: "\\.sheet\\(").isEmpty, "\(offenders(files, pattern: "\\.sheet\\("))")
    }

    // (e2) the cover hides and blocks the content behind it

    @Test("prompt modifier hides and disables the content using hidesContent")
    func coverBlocksContent() throws {
        let tree = try tree()
        let file = try #require(UpdateViewsScan.load(UpdateViewsScan.promptModifier, tree: tree),
                                "UpdatePromptModifier.swift is missing")
        #expect(file.code.contains(".accessibilityHidden("), "content is not hidden from accessibility")
        #expect(file.code.contains(".allowsHitTesting("), "content still receives touches")
        #expect(file.code.contains("hidesContent"), "the cover flag does not come from hidesContent")
    }

    // (e3) no dismissal path

    @Test("views have no dismissal path")
    func noDismissalPath() throws {
        let files = try viewFiles()
        let banned = [
            ".fullScreenCover(", ".sheet(", ".popover(", "interactiveDismissDisabled",
            ".onTapGesture", "DragGesture", ".swipeActions"
        ]
        for file in files {
            for token in banned {
                #expect(!file.code.contains(token), "\(file.path) contains \(token)")
            }
        }
    }

    // (f) design tokens only

    @Test("views use no raw color, system font or numeric padding")
    func tokensOnly() throws {
        let files = try viewFiles()
        #expect(offenders(files, pattern: "(?<![A-Za-z])Color\\(").isEmpty)
        #expect(offenders(files, pattern: "\\.font\\(\\.system").isEmpty)
        #expect(offenders(files, pattern: "\\.padding\\([^)]*[0-9]").isEmpty)
    }

    // (g) accessibility

    @Test("required view has the Update button label and a header trait")
    func accessibility() throws {
        let tree = try tree()
        let view = try #require(UpdateViewsScan.load(UpdateViewsScan.requiredView, tree: tree),
                                "UpdateRequiredView.swift is missing")
        #expect(view.code.contains("Update Christmas Tracker"))
        #expect(view.code.contains(".isHeader"))
    }
}
