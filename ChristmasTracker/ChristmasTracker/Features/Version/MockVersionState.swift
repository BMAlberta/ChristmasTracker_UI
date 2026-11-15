// MockVersionState.swift
// ChristmasTracker
//
// Debug states for the update screens in mock mode (launch argument -mockVersionState).
// Never active in production.

import Foundation

nonisolated enum MockVersionState: Equatable, Sendable {
    case ok
    case recommended
    case required
    case requiredNoLink

    /// Maps a launch value to a state. Always nil in production.
    static func parse(_ raw: String?, environment: String) -> MockVersionState? {
        if environment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "production" { return nil }
        guard let raw else { return nil }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ok": return .ok
        case "recommended": return .recommended
        case "required": return .required
        case "requirednolink": return .requiredNoLink
        default: return nil
        }
    }

    var policy: VersionPolicy {
        switch self {
        case .ok:
            return make(.ok, manifest: nil, notes: nil)
        case .recommended:
            return make(.updateRecommended, manifest: Self.mockManifest, notes: "Faster lists and small fixes.")
        case .required:
            return make(.forceUpdate, manifest: Self.mockManifest, notes: "This release fixes a sign-in problem.")
        case .requiredNoLink:
            return make(.forceUpdate, manifest: nil, notes: nil)
        }
    }

    // The reserved .invalid TLD never resolves, so nothing real is addressed. This is the only
    // URL literal allowed, and only in this mock file.
    private static let mockManifest = URL(string: "https://updates.example.invalid/mock/manifest.plist")

    private func make(_ state: VersionPolicyState, manifest: URL?, notes: String?) -> VersionPolicy {
        VersionPolicy(
            state: state,
            minimumVersion: "2.0.0",
            recommendedVersion: "2.0.0",
            latestVersion: "2.0.0",
            minimumBuild: 200,
            latestBuild: 200,
            manifestURL: manifest,
            ipaURL: nil,
            releaseNotes: notes,
            enabled: true,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
