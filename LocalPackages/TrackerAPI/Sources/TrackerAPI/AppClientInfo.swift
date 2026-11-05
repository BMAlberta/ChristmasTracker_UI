// AppClientInfo.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

public struct AppClientInfo: Sendable {
    public let platform: String
    public let clientPlatform: String
    public let build: String
    public let version: String

    public init(platform: String, clientPlatform: String, build: String, version: String) {
        self.platform = platform
        self.clientPlatform = clientPlatform
        self.build = build
        self.version = version
    }
}
