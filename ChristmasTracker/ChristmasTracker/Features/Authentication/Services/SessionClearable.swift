//
//  SessionClearable.swift
//  ChristmasTracker

import Foundation

/// Adopted by any type that holds session-scoped state and must be cleared on logout
/// or session expiry.
internal protocol SessionClearable: AnyObject, Sendable {
    func clearForSession() async throws
}

/// The reason a session teardown was triggered.
internal enum TeardownReason: Sendable {
    case userLogout
    case sessionExpired
    case forcedUpdate
}
