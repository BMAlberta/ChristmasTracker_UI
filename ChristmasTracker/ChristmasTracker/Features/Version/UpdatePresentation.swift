// UpdatePresentation.swift
// ChristmasTracker
//
// Pure copy and derived flags for the update screens. Nothing here logs or records
// release notes, versions or links.

import Foundation

nonisolated enum UpdatePresentation {
    static let appName = "Christmas Tracker"
    static let requiredTitle = "Update required"
    static let requiredSentence = "This version of Christmas Tracker is no longer supported. Update to keep using the app."
    static let noLinkMessage = "Ask the person who sent you the app for the update link."
    static let promptTitle = "Update available"

    private static let requiredNotesLimit = 500
    private static let promptNotesLimit = 200

    static func versionLine(installedVersion: String, installedBuild: String, required: RequiredUpdate) -> String {
        let installed = "You have \(installedVersion) (\(installedBuild))."
        let minimum = required.minimumVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !minimum.isEmpty, let build = required.minimumBuild else { return installed }
        return "\(installed) Required: \(minimum) (\(build))."
    }

    /// Plain text for the required screen: nil when blank, cut to 500 characters including the ellipsis.
    static func requiredNotes(_ notes: String?) -> String? {
        guard let trimmed = trimmedNotes(notes) else { return nil }
        guard trimmed.count > requiredNotesLimit else { return trimmed }
        return String(trimmed.prefix(requiredNotesLimit - 1)) + "…"
    }

    /// The alert message; the notes are included only when they are 200 characters or fewer.
    static func promptMessage(latestVersion: String, releaseNotes: String?) -> String {
        let base = "Version \(latestVersion) is available."
        guard let notes = trimmedNotes(releaseNotes), notes.count <= promptNotesLimit else { return base }
        return base + "\n\n" + notes
    }

    static func hidesContent(for decision: UpdateGate.Decision) -> Bool {
        if case .required = decision { return true }
        return false
    }

    static func installLink(for decision: UpdateGate.Decision) -> URL? {
        switch decision {
        case .none:
            return nil
        case .recommended(let policy):
            return UpdateInstallLink.url(from: policy.manifestURL?.absoluteString)
        case .required(let update):
            return UpdateInstallLink.url(from: update.manifest)
        }
    }

    static func showsPrompt(for decision: UpdateGate.Decision) -> Bool {
        guard case .recommended = decision else { return false }
        return installLink(for: decision) != nil
    }

    static func showsUpdateButton(for decision: UpdateGate.Decision) -> Bool {
        installLink(for: decision) != nil
    }

    private static func trimmedNotes(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
