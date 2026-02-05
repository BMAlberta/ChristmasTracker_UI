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
    func log(
        _ event: LogEvent) async
    /// Flush buffered events
    func flush(
        _ events: [LogEvent]) async
}
/// Log event model
struct LogEvent: Sendable, Codable {
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]
    let signpost: SignpostInfo?
    let duration: TimeInterval?
    let memoryUsage: UInt64?
}
enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
}
enum LogCategory: String, Codable, Sendable {
    case network
    case auth
    case ui
    case cache
    case performance
    case business
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
