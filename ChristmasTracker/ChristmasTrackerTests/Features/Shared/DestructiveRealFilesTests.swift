//
//  DestructiveRealFilesTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B2: runs DestructiveScanner over every .swift file under Features/ and App/ of the app.
//  OLD gap: the archive, leave, remove and dialog buttons in ListDetailView, MembersSectionView,
//  DashboardView and EditListView are destructive by role but carry the accent colour or nothing,
//  and the member Remove icon button has no destructive role. TH1.1 (Brian, 2026-11-14): sign out is
//  now destructive too, like Leave list. Needs the checkout on disk, which scripts/test.sh has.
//
//  ALLOWLIST: none.
//

import Foundation
import Testing

@Suite("Destructive real files Tests")
struct DestructiveRealFilesTests {

    private struct Scanned {
        let relative: String
        let source: String
    }

    private func scannedFiles(file: String = #filePath) throws -> [Scanned] {
        // TH1-T4: DesignSystem/ joins the scope (ErrorStateView's raw-red exception is gone).
        let tree = try #require(ItemSourceTree.load(from: file), "Could not find the app source folder")
        var result: [Scanned] = []
        for url in tree.all {
            let relative = tree.relativePath(url)
            let scopes = ["Features/", "App/", "DesignSystem/"]
            guard scopes.contains(where: { relative.hasPrefix($0) }) else { continue }
            result.append(Scanned(relative: relative, source: try String(contentsOf: url, encoding: .utf8)))
        }
        #expect(result.count > 50, "the scan reached only \(result.count) files in Features/ and App/")
        return result
    }

    private func source(named name: String, in files: [Scanned]) throws -> String {
        let match = files.first { ($0.relative as NSString).lastPathComponent == name }
        return try #require(match, "\(name) is not scanned").source
    }

    @Test("the scan reaches the screens with destructive controls")
    func reachesTheScreens() throws {
        let names = Set(try scannedFiles().map { ($0.relative as NSString).lastPathComponent })
        for expected in [
            "ListDetailView.swift", "MembersSectionView.swift", "DashboardView.swift", "EditListView.swift",
            "ProfileView.swift", "ItemDetailView.swift", "ChildrenView.swift"
        ] {
            #expect(names.contains(expected), "\(expected) is not scanned")
        }
    }

    @Test("Every destructive Button carries the destructive token (old gap: archive, leave, remove and dialog buttons had none)")
    func everyDestructiveButtonHasTheToken() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() {
            for violation in DestructiveScanner.destructiveButtonsMissingToken(in: scanned.source) {
                offenders.append("\(scanned.relative):\(violation.line)")
            }
        }
        #expect(offenders.isEmpty, "destructive buttons without the token: \(offenders.joined(separator: "; "))")
    }

    @Test("OLD: the Dashboard archive swipe action has no explicit tint; every destructive swipe action must")
    func everyDestructiveSwipeActionHasATint() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() {
            for violation in DestructiveScanner.swipeDestructiveMissingTint(in: scanned.source) {
                offenders.append("\(scanned.relative):\(violation.line)")
            }
        }
        #expect(offenders.isEmpty, "destructive swipe actions without an explicit tint: \(offenders.joined(separator: "; "))")
    }

    @Test("OLD: the member Remove icon button has no destructive role; it must have the role and the token")
    func memberRemoveButtonIsDestructive() throws {
        let members = try source(named: "MembersSectionView.swift", in: try scannedFiles())
        let remove = DestructiveScanner.buttonStatements(in: members)
            .filter { $0.chain.contains("listDetail.removeMemberButton") }
        let statement = try #require(remove.first, "the member Remove button was not found")
        #expect(statement.isDestructive, "MembersSectionView.swift:\(statement.line) Remove button has no role: .destructive")
    }

    // TH1.1: Brian reversed UX1b on 2026-11-14; Logout is destructive like Leave list.
    private func logoutStatements() throws -> (trigger: DestructiveScanner.ButtonStatement, dialog: DestructiveScanner.ButtonStatement) {
        let profile = try source(named: "ProfileView.swift", in: try scannedFiles())
        let statements = DestructiveScanner.buttonStatements(in: profile)
        let trigger = try #require(
            statements.first { $0.chain.contains("rectangle.portrait.and.arrow.right") },
            "the Logout trigger was not found"
        )
        let dialog = try #require(
            statements.first { $0.line != trigger.line && $0.chain.hasPrefix("(\"Logout\"") },
            "the dialog Logout button was not found"
        )
        return (trigger, dialog)
    }

    @Test("TH1.1: the Logout trigger is destructive, bordered, destructive-tinted and not the primary style")
    func logoutTriggerIsDestructive() throws {
        let trigger = try logoutStatements().trigger
        #expect(trigger.isDestructive, "ProfileView.swift:\(trigger.line) Logout trigger has no role: .destructive")
        #expect(trigger.chain.contains(".buttonStyle(.bordered)"))
        #expect(trigger.chain.contains("destructiveTint()"))
        #expect(!trigger.chain.contains("PrimaryButtonStyle"))
    }

    @Test("TH1.1: the dialog Logout button is destructive and destructive-tinted")
    func logoutDialogButtonIsDestructive() throws {
        let dialog = try logoutStatements().dialog
        #expect(dialog.isDestructive, "ProfileView.swift:\(dialog.line) dialog Logout has no role: .destructive")
        #expect(dialog.chain.contains("destructiveTint()"))
    }

    // ALLOWLIST: none. TH1-T4: ErrorStateView now uses Color.destructiveColor, so DesignSystem/ is scanned too.
    @Test("OLD: ProfileView paints Logout with raw .red; no view under Features/, App/ or DesignSystem/ may use raw red")
    func noRawRedInViews() throws {
        var offenders: [String] = []
        for scanned in try scannedFiles() {
            for violation in DestructiveScanner.rawRedViolations(in: scanned.source) {
                offenders.append("\(scanned.relative):\(violation.line)")
            }
        }
        #expect(offenders.isEmpty, "raw red colours (use DesignSystem tokens): \(offenders.joined(separator: "; "))")
    }
}
