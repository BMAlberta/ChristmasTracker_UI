// Seams.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import OpenAPIRuntime

// MARK: - AccessTokenProviding
public protocol AccessTokenProviding: Sendable {
    func accessToken() async -> String?
}

// MARK: - SessionRefreshError
public enum SessionRefreshError: Error, Sendable {
    case credentialFailure
    case other(Error)
}

// MARK: - SessionRefreshing
public protocol SessionRefreshing: Sendable {
    func refresh() async throws
}

// MARK: - VersionOutdatedDetails
public struct VersionOutdatedDetails: Sendable {
    public let minimumVersion: String
    public let minimumBuild: Int?
    public let latestVersion: String?
    public let latestBuild: Int?
    public let manifestUrl: String?
    public let ipaUrl: String?

    public init(
        minimumVersion: String,
        minimumBuild: Int?,
        latestVersion: String?,
        latestBuild: Int?,
        manifestUrl: String?,
        ipaUrl: String?
    ) {
        self.minimumVersion = minimumVersion
        self.minimumBuild = minimumBuild
        self.latestVersion = latestVersion
        self.latestBuild = latestBuild
        self.manifestUrl = manifestUrl
        self.ipaUrl = ipaUrl
    }
}

// MARK: - VersionOutdatedHandling
public protocol VersionOutdatedHandling: Sendable {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async
}

// MARK: - RequestIDObserving
public protocol RequestIDObserving: Sendable {
    func observe(requestID: String) async
}

// MARK: - RateLimitSleeping
public protocol RateLimitSleeping: Sendable {
    func sleep(seconds: TimeInterval) async
}
