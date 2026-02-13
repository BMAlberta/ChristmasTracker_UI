//
//  LogDestination.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/3/26.
//

import Foundation

/// Protocol for log destinations
protocol LogDestination: Sendable {
    /// Log a single event (for immediate critical/error events)
    func log(_ event: LogEvent) async
    /// Flush buffered events
    func flush(_ events: [LogEvent]) async
}

enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
}
// MARK: - LogCategory
enum LogCategory: String, Codable, Sendable {
    case network // API calls, network errors, latency
    case auth // Login, logout, token refresh, biometric
    case ui // View lifecycle, user interactions, navigation
    case cache // Cache hits/misses, invalidation
    case performance // Signposts, memory, slow operations
    case business // Feature events (purchase, invite, create list)
}
struct SignpostInfo: Sendable, Codable {
    let name: String
    let id: UUID
    let state: SignpostState
}
enum SignpostState: String, Codable, Sendable {
    case begin
    case end
    case event
}
