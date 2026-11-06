// VersionPolicy.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

public enum VersionPolicyState: Equatable, Sendable {
    case ok
    case updateRecommended
    case forceUpdate
}

public struct VersionPolicy: Equatable, Sendable {
    public var state: VersionPolicyState
    public var minimumVersion: String
    public var recommendedVersion: String
    public var latestVersion: String
    public var minimumBuild: Int
    public var latestBuild: Int
    public var manifestURL: URL?
    public var ipaURL: URL?
    public var releaseNotes: String?
    public var enabled: Bool
    public var updatedAt: Date

    public init(
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
