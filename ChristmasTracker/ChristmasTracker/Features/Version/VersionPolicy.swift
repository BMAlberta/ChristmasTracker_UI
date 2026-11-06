// VersionPolicy.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

enum VersionPolicyState: Equatable, Sendable {
    case ok
    case updateRecommended
    case forceUpdate

    // Explicit nonisolated == required because SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
    // would otherwise produce a @MainActor-isolated synthesis.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.ok, .ok), (.updateRecommended, .updateRecommended), (.forceUpdate, .forceUpdate):
            return true
        default:
            return false
        }
    }
}

// nonisolated stored properties: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would make
// property getters @MainActor by default; nonisolated allows access from any context since
// VersionPolicy is a Sendable value type with no shared mutable state.
struct VersionPolicy: Equatable, Sendable {
    nonisolated var state: VersionPolicyState
    nonisolated var minimumVersion: String
    nonisolated var recommendedVersion: String
    nonisolated var latestVersion: String
    nonisolated var minimumBuild: Int
    nonisolated var latestBuild: Int
    nonisolated var manifestURL: URL?
    nonisolated var ipaURL: URL?
    nonisolated var releaseNotes: String?
    nonisolated var enabled: Bool
    nonisolated var updatedAt: Date

    nonisolated init(
        state: VersionPolicyState,
        minimumVersion: String,
        recommendedVersion: String,
        latestVersion: String,
        minimumBuild: Int,
        latestBuild: Int,
        manifestURL: URL?,
        ipaURL: URL?,
        releaseNotes: String?,
        enabled: Bool,
        updatedAt: Date
    ) {
        self.state = state
        self.minimumVersion = minimumVersion
        self.recommendedVersion = recommendedVersion
        self.latestVersion = latestVersion
        self.minimumBuild = minimumBuild
        self.latestBuild = latestBuild
        self.manifestURL = manifestURL
        self.ipaURL = ipaURL
        self.releaseNotes = releaseNotes
        self.enabled = enabled
        self.updatedAt = updatedAt
    }
}
