//
//  DialogScanRealFilesTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B1: runs DialogScanner over every .swift file under Features/ and App/ of the app.
//  OLD gap: ListDetailView, EditListView and ProfileView attach dialogs to a container or to the
//  screen's root view, so a re-render can dismiss them. Needs the checkout on disk, which
//  scripts/test.sh has.
//
//  ALLOWLIST (relative path to reason): the auth screens keep their own error and explanation
//  alerts (UX1b brief non-goal).
//

import Foundation
import Testing

@Suite("Dialog scan real files Tests")
struct DialogScanRealFilesTests {

    static let allowlist: [String: String] = [
        "Features/Authentication/Views/LoginView.swift":
            "the login screen keeps its own error and explanation alerts (brief non-goal)",
        "Features/Authentication/Views/RegistrationView.swift":
            "the registration screen keeps its own error alert (brief non-goal)"
    ]

    private struct Scanned {
        let relative: String
        let source: String
    }

    private func scannedFiles(file: String = #filePath) throws -> [Scanned] {
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        var result: [Scanned] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            guard relative.hasPrefix("Features/") || relative.hasPrefix("App/") else { continue }
            result.append(Scanned(relative: relative, source: try String(contentsOf: url, encoding: .utf8)))
        }
        #expect(result.count > 50, "the scan reached only \(result.count) files in Features/ and App/")
        return result
    }

    @Test("the scan reaches the screens with dialogs")
    func reachesTheScreens() throws {
        let names = Set(try scannedFiles().map { ($0.relative as NSString).lastPathComponent })
        for expected in ["ListDetailView.swift", "EditListView.swift", "ProfileView.swift", "DashboardView.swift", "ChildrenView.swift"] {
            #expect(names.contains(expected), "\(expected) is not scanned")
        }
    }

    @Test("the allowlisted files exist, so the exceptions are not stale")
    func allowlistIsNotStale() throws {
        let tree = try #require(ItemSourceTree.load(from: #filePath), "Could not find the app source folder")
        for (relative, reason) in Self.allowlist {
            #expect(tree.exists(relative), "allowlisted file is gone: \(relative) (\(reason))")
        }
    }

    @Test("OLD: ListDetailView, EditListView and ProfileView anchor dialogs to a container or root; none may")
    func noContainerAnchoredDialogs() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() where Self.allowlist[scanned.relative] == nil {
            for violation in DialogScanner.containerAnchoredViolations(in: scanned.source) {
                offenders.append("\(scanned.relative):\(violation.line) .\(violation.modifier) on \(violation.receiver)")
            }
        }
        #expect(offenders.isEmpty, "container-anchored dialogs: \(offenders.joined(separator: "; "))")
    }

    @Test("no Bool is set to true and cleared back to false in the same scope (no allowlist)")
    func noSetThenClear() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() {
            for line in DialogScanner.setThenClearViolations(in: scanned.source) {
                offenders.append("\(scanned.relative):\(line)")
            }
        }
        #expect(offenders.isEmpty, "set-then-clear: \(offenders.joined(separator: "; "))")
    }
}
