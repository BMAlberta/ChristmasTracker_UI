//
//  OperationLogging.swift
//  ChristmasTracker
//
//  The small logging seam used by the operation helper, the transport and the services. The
//  production type forwards to the global Log functions; tests inject a capturing sink. Only
//  allowed values (operation name, status, duration, counts, error category) may go into a message.
//

import Foundation

/// Sink for one log line. Implementations must be safe to call from any isolation.
nonisolated protocol OperationLogging: Sendable {
    func log(_ level: LogLevel, _ message: String, category: LogCategory)
}

/// Production sink: forwards to the global Log functions.
nonisolated struct AppOperationLog: OperationLogging {
    init() {}

    func log(_ level: LogLevel, _ message: String, category: LogCategory) {
        switch level {
        case .debug: LogDebug(message, category: category)
        case .info: LogInfo(message, category: category)
        case .warning: LogWarning(message, category: category)
        case .error: LogError(message, category: category)
        case .critical: LogCritical(message, category: category)
        }
    }
}

/// Whether per-step (debug) logging is on. True in Debug builds only; injectable so Release
/// behavior can be tested in a Debug run.
nonisolated struct LogVerbosity: Sendable {
    let isVerbose: Bool

    #if DEBUG
    static let current = LogVerbosity(isVerbose: true)
    #else
    static let current = LogVerbosity(isVerbose: false)
    #endif
}
