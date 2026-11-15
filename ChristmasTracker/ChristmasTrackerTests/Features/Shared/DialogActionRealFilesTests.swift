//
//  DialogActionRealFilesTests.swift
//  ChristmasTrackerTests
//
//  TH1.1 Story A2: runs DialogActionScanner over every .swift file under Features/ and App/ of the
//  app. Every confirmationDialog or alert action button titled Delete, Remove, Archive, Leave,
//  Logout or Sign Out must carry `role: .destructive`. Needs the checkout on disk, which
//  scripts/test.sh has.
//
//  ALLOWLIST: none. Login and Registration alerts have no keyword button, and over-purchase
//  "Continue Anyway" has no keyword title, so none of them needs an exception.
//  Known limit: ChildrenView's and MembersSectionView's member Remove dialog buttons use the
//  generic `confirmation.confirmButtonTitle`, which the keyword rule cannot see; pinned tests
//  below assert both carry the role.
//

import Foundation
import Testing

@Suite("Dialog action real files Tests")
struct DialogActionRealFilesTests {

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

    @Test("every keyword dialog button (Delete, Remove, Archive, Leave, Logout, Sign Out) has role: .destructive")
    func everyKeywordDialogButtonIsDestructive() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() {
            for violation in DialogActionScanner.missingDestructiveRole(in: scanned.source) {
                offenders.append("\(scanned.relative):\(violation.line) \(violation.title)")
            }
        }
        #expect(offenders.isEmpty, "dialog buttons without role: .destructive: \(offenders.joined(separator: "; "))")
    }

    @Test("the scan examines at least 8 keyword action buttons (it would otherwise pass vacuously)")
    func scanExaminesRealDialogButtons() throws {
        var examined = 0
        for scanned in try scannedFiles() {
            examined += DialogActionScanner.examinedButtons(in: scanned.source).count
        }
        // Logout, Archive x2, Leave, Delete Item, Delete purchase, Budget delete, Co-owner remove.
        #expect(examined >= 8, "only \(examined) keyword dialog buttons examined")
    }

    @Test("MembersSectionView's member Remove confirm button is destructive (outside the keyword rule)")
    func membersConfirmIsDestructive() throws {
        let files = try scannedFiles()
        let members = try #require(files.first { $0.relative.hasSuffix("MembersSectionView.swift") }, "MembersSectionView.swift is not scanned")
        let confirm = DestructiveScanner.buttonStatements(in: members.source)
            .first { $0.chain.contains("confirmation.confirmButtonTitle") }
        let statement = try #require(confirm, "the MembersSectionView confirm button was not found")
        #expect(statement.isDestructive, "MembersSectionView.swift:\(statement.line) confirm button has no role: .destructive")
    }

    @Test("ChildrenView's generic confirm button is destructive (outside the keyword rule)")
    func childrenConfirmIsDestructive() throws {
        let files = try scannedFiles()
        let children = try #require(files.first { $0.relative.hasSuffix("ChildrenView.swift") }, "ChildrenView.swift is not scanned")
        let confirm = DestructiveScanner.buttonStatements(in: children.source)
            .first { $0.chain.contains("confirmation.confirmButtonTitle") }
        let statement = try #require(confirm, "the ChildrenView confirm button was not found")
        #expect(statement.isDestructive, "ChildrenView.swift:\(statement.line) confirm button has no role: .destructive")
    }
}
