//
//  DestructiveRealFilesTests.swift
//  ChristmasTrackerTests
//
//  UX1b Story B2: runs DestructiveScanner over every .swift file under Features/ and App/ of the app.
//  OLD gap: the archive, leave, remove and dialog buttons in ListDetailView, MembersSectionView,
//  DashboardView and EditListView are destructive by role but carry the accent colour or nothing,
//  the member Remove icon button has no destructive role, and ProfileView marks sign out as
//  destructive. Needs the checkout on disk, which scripts/test.sh has.
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

    @Test("OLD: sign out is marked destructive; ProfileView must contain no role: .destructive")
    func signOutIsNeutral() throws {
        let profile = ItemSourceScan.codeOnly(try source(named: "ProfileView.swift", in: try scannedFiles()))
        let lines = profile.components(separatedBy: "\n").enumerated()
            .filter { $0.element.contains("role: .destructive") }
            .map { "ProfileView.swift:\($0.offset + 1)" }
        #expect(lines.isEmpty, "sign out must be neutral: \(lines.joined(separator: "; "))")
    }

    @Test("OLD: the Logout trigger has a raw red background; LogoutButtonView must use no red or destructive token")
    func logoutButtonViewIsNeutral() throws {
        let profile = try source(named: "ProfileView.swift", in: try scannedFiles())
        let found = try #require(
            DestructiveScanner.forbiddenTokenViolations(
                inType: "LogoutButtonView",
                tokens: [".red", "Color.red", "destructiveColor", "destructiveTint"],
                source: profile
            ),
            "LogoutButtonView was not found in ProfileView.swift"
        )
        #expect(found.isEmpty, "sign out must be neutral, red or destructive token at: \(found.map { "ProfileView.swift:\($0.line)" }.joined(separator: "; "))")
    }

    // ALLOWLIST: none. ErrorStateView.swift (DesignSystem/, not scanned here) also uses
    // .foregroundColor(.red); it is an error view, not a destructive control, out of B2 scope; banked.
    @Test("OLD: ProfileView paints Logout with raw .red; no view under Features/ or App/ may use raw red")
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
