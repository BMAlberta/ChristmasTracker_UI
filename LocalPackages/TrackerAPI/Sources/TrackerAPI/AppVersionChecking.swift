// AppVersionChecking.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

public protocol AppVersionChecking: Sendable {
    func checkVersion() async throws -> VersionPolicy
}
