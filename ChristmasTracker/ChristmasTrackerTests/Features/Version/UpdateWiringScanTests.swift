// UpdateWiringScanTests.swift
// ChristmasTrackerTests
//
// VER1 V2: the update cover is wired at the app root, and the lock and privacy windows are
// untouched (they do not mention the new types).

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Update wiring scan Tests")
struct UpdateWiringScanTests {

    private func source(named name: String) throws -> String {
        let tree = try #require(UpdateViewsScan.tree(), "app source tree not found")
        let url = try #require(tree.all.first { $0.lastPathComponent == name }, "\(name) not found")
        let raw = try #require(tree.source(tree.relativePath(url)), "\(name) unreadable")
        return ItemSourceScan.codeOnly(raw)
    }

    @Test("the app root applies the update modifier")
    func rootAppliesModifier() throws {
        let app = try source(named: "ChristmasTrackerApp.swift")
        #expect(app.contains("updatePrompt("), "ChristmasTrackerApp.swift does not apply .updatePrompt(...)")
    }

    @Test("the app checks on foreground and still checks at launch")
    func foregroundAndLaunchChecks() throws {
        let app = try source(named: "ChristmasTrackerApp.swift")
        #expect(app.contains("checkIfDue"), "no foreground checkIfDue call")
        #expect(app.contains("scenePhase"), "scenePhase is not observed")
        #expect(app.contains(".active"), "no .active phase check")
        #expect(app.contains(".check()"), "the launch check no longer calls .check()")
    }

    @Test("the update prompt modifier file defines updatePrompt")
    func modifierDefined() throws {
        let tree = try #require(UpdateViewsScan.tree())
        let file = try #require(UpdateViewsScan.load(UpdateViewsScan.promptModifier, tree: tree),
                                "UpdatePromptModifier.swift is missing")
        #expect(file.code.contains("func updatePrompt("))
    }

    @Test("lock and privacy window files do not mention the update types")
    func windowsUntouched() throws {
        let names = [
            "LockWindowAdapter.swift",
            "PrivacyCoverWindowAdapter.swift",
            "AppWindowLevels.swift",
            "PrivacyCoverCoordinator.swift"
        ]
        for name in names {
            let code = try source(named: name)
            for type in ["UpdatePresentation", "UpdateGate", "UpdateRequiredView"] {
                #expect(!code.contains(type), "\(name) mentions \(type)")
            }
        }
    }
}
