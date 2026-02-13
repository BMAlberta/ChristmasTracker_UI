//
//  OSLogDestination.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 2/5/26.
//

import Foundation
import os.log
/// Log destination using iOS native os_log
nonisolated struct OSLogDestination: LogDestination {
    private let subsystem = "com.bmalberta.christmasTracker"
    private var logs: [LogCategory: OSLog] = [:]
    init() {
        // Create OSLog instances for each category
        for category in [LogCategory.network, .auth, .ui, .cache, .performance, .business] {
            logs[category] = OSLog(subsystem: subsystem, category: category.rawValue)
        }
    }
    func log(_ event: LogEvent) async {
        let log = logs[event.category] ?? OSLog.default
        let type = mapLogLevel(event.level)
        os_log("%{public}@", log: log, type: type, event.message)
    }
    func flush(_ events: [LogEvent]) async {
        for event in events {
            await log(event)
        }
    }
    private func mapLogLevel(_ level: LogLevel) -> OSLogType {
        switch level {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning, .error:
            return .error
        case .critical:
            return .fault
        }
    }
}
