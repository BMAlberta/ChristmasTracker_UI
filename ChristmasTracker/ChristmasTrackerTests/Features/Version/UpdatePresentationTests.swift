// UpdatePresentationTests.swift
// ChristmasTrackerTests
//
// VER1 V2: copy, version line, truncation and decision-derived flags of UpdatePresentation.

import Foundation
import Testing
@testable import ChristmasTracker

@Suite("Update presentation Tests")
struct UpdatePresentationTests {

    private let goodManifest = "https://example.com/app/manifest.plist"

    private func required(
        minimumVersion: String = "2.0",
        minimumBuild: Int? = 40,
        manifest: String? = "https://example.com/app/manifest.plist",
        notes: String? = nil
    ) -> RequiredUpdate {
        RequiredUpdate(minimumVersion: minimumVersion, minimumBuild: minimumBuild, manifest: manifest, releaseNotes: notes)
    }

    private func recommended(manifestURL: URL?) -> UpdateGate.Decision {
        .recommended(VersionTestFixtures.policy(state: .updateRecommended, manifestURL: manifestURL))
    }

    // MARK: - Copy

    @Test("fixed copy is exact")
    func copy() {
        #expect(UpdatePresentation.requiredTitle == "Update required")
        #expect(UpdatePresentation.requiredSentence
                == "This version of Christmas Tracker is no longer supported. Update to keep using the app.")
        #expect(UpdatePresentation.noLinkMessage == "Ask the person who sent you the app for the update link.")
        #expect(UpdatePresentation.promptTitle == "Update available")
        #expect(UpdatePresentation.appName == "Christmas Tracker")
    }

    // MARK: - Version line

    @Test("version line shows installed and required")
    func versionLineFull() {
        let line = UpdatePresentation.versionLine(installedVersion: "1.2", installedBuild: "30", required: required())
        #expect(line == "You have 1.2 (30). Required: 2.0 (40).")
    }

    @Test("version line drops Required when the minimum version is empty")
    func versionLineEmptyMinimum() {
        let line = UpdatePresentation.versionLine(
            installedVersion: "1.2", installedBuild: "30", required: required(minimumVersion: ""))
        #expect(line == "You have 1.2 (30).")
    }

    @Test("version line drops Required when the minimum build is nil")
    func versionLineNilBuild() {
        let line = UpdatePresentation.versionLine(
            installedVersion: "1.2", installedBuild: "30", required: required(minimumBuild: nil))
        #expect(line == "You have 1.2 (30).")
    }

    // MARK: - Required notes

    @Test("required notes are nil for nil, empty and whitespace-only")
    func requiredNotesEmpty() {
        #expect(UpdatePresentation.requiredNotes(nil) == nil)
        #expect(UpdatePresentation.requiredNotes("") == nil)
        #expect(UpdatePresentation.requiredNotes("   \n\t ") == nil)
    }

    @Test("required notes at or under 500 characters are unchanged")
    func requiredNotesUnchanged() {
        let exact = String(repeating: "a", count: 500)
        #expect(UpdatePresentation.requiredNotes("Fixes and polish") == "Fixes and polish")
        #expect(UpdatePresentation.requiredNotes(exact) == exact)
    }

    @Test("required notes over 500 characters become 499 plus an ellipsis")
    func requiredNotesTruncated() {
        let long = String(repeating: "a", count: 501)
        let result = UpdatePresentation.requiredNotes(long)
        #expect(result == String(repeating: "a", count: 499) + "…")
        #expect(result?.count == 500)
        let much = String(repeating: "b", count: 5000)
        #expect(UpdatePresentation.requiredNotes(much)?.count == 500)
    }

    @Test("required notes are plain text, returned verbatim")
    func requiredNotesVerbatim() {
        let markup = "**bold** <b>x</b>"
        #expect(UpdatePresentation.requiredNotes(markup) == markup)
    }

    // MARK: - Prompt message

    @Test("prompt message without notes")
    func promptNoNotes() {
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: nil) == "Version 3.1 is available.")
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: "") == "Version 3.1 is available.")
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: "  \n ") == "Version 3.1 is available.")
    }

    @Test("prompt message appends short notes after a blank line")
    func promptShortNotes() {
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: "Faster lists")
                == "Version 3.1 is available.\n\nFaster lists")
        let exact = String(repeating: "n", count: 200)
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: exact)
                == "Version 3.1 is available.\n\n" + exact)
    }

    @Test("prompt message omits notes over 200 characters entirely")
    func promptLongNotes() {
        let long = String(repeating: "n", count: 201)
        #expect(UpdatePresentation.promptMessage(latestVersion: "3.1", releaseNotes: long) == "Version 3.1 is available.")
    }

    // MARK: - Decision-derived flags

    @Test("only required hides content")
    func hidesContent() {
        #expect(UpdatePresentation.hidesContent(for: .required(required())))
        #expect(!UpdatePresentation.hidesContent(for: .none))
        #expect(!UpdatePresentation.hidesContent(for: recommended(manifestURL: URL(string: goodManifest))))
    }

    @Test("install link comes from UpdateInstallLink for required")
    func installLinkRequired() {
        #expect(UpdatePresentation.installLink(for: .required(required())) == UpdateInstallLink.url(from: goodManifest))
        #expect(UpdatePresentation.installLink(for: .required(required())) != nil)
        #expect(UpdatePresentation.installLink(for: .required(required(manifest: nil))) == nil)
        #expect(UpdatePresentation.installLink(for: .required(required(manifest: "http://example.com/m.plist"))) == nil)
    }

    @Test("install link comes from UpdateInstallLink for recommended")
    func installLinkRecommended() {
        let decision = recommended(manifestURL: URL(string: goodManifest))
        #expect(UpdatePresentation.installLink(for: decision) == UpdateInstallLink.url(from: goodManifest))
        #expect(UpdatePresentation.installLink(for: recommended(manifestURL: nil)) == nil)
    }

    @Test("no decision has no install link")
    func installLinkNone() {
        #expect(UpdatePresentation.installLink(for: .none) == nil)
    }

    @Test("prompt shows only for recommended with a link")
    func showsPrompt() {
        #expect(UpdatePresentation.showsPrompt(for: recommended(manifestURL: URL(string: goodManifest))))
        #expect(!UpdatePresentation.showsPrompt(for: recommended(manifestURL: nil)))
        #expect(!UpdatePresentation.showsPrompt(for: recommended(manifestURL: URL(string: "http://example.com/m.plist"))))
        #expect(!UpdatePresentation.showsPrompt(for: .none))
        #expect(!UpdatePresentation.showsPrompt(for: .required(required())))
    }

    @Test("update button shows when there is a link")
    func showsUpdateButton() {
        #expect(UpdatePresentation.showsUpdateButton(for: .required(required())))
        #expect(!UpdatePresentation.showsUpdateButton(for: .required(required(manifest: nil))))
        #expect(!UpdatePresentation.showsUpdateButton(for: .required(required(manifest: "   "))))
        #expect(UpdatePresentation.showsUpdateButton(for: recommended(manifestURL: URL(string: goodManifest))))
        #expect(!UpdatePresentation.showsUpdateButton(for: .none))
    }
}
