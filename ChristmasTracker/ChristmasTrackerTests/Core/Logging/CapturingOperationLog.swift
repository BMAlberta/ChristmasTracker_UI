//
//  CapturingOperationLog.swift
//  ChristmasTrackerTests
//
//  Test sink that records every line it receives. Shared by the logging tests.
//

import Foundation
@testable import ChristmasTracker

final class CapturingOperationLog: OperationLogging, @unchecked Sendable {

    struct Line: Equatable, Sendable {
        let level: LogLevel
        let message: String
        let category: LogCategory
    }

    private let lock = NSLock()
    private var storage: [Line] = []

    var lines: [Line] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func log(_ level: LogLevel, _ message: String, category: LogCategory) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(Line(level: level, message: message, category: category))
    }
}
