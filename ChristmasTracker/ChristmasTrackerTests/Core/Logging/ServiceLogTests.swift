//
//  ServiceLogTests.swift
//  ChristmasTrackerTests
//
//  LG1-L3: the ServiceLog helper writes the fixed step lines in verbose mode and only the failure
//  line otherwise; a cancellation is never an error.
//

import Foundation
import Testing
@testable import ChristmasTracker

struct ServiceLogTests {

    private func make(verbose: Bool) -> (ServiceLog, CapturingOperationLog) {
        let sink = CapturingOperationLog()
        return (ServiceLog(sink: sink, verbosity: LogVerbosity(isVerbose: verbose)), sink)
    }

    @Test("verbose mode writes started, processed, skipped and cancelled at debug in the business category")
    func verboseLines() {
        let (log, sink) = make(verbose: true)
        log.started("load things")
        log.started("load things", reason: .pull)
        log.processed("load things")
        log.processed("load things", count: 3, noun: "lists")
        log.skipped("load things")
        log.cancelled("load things")
        #expect(sink.lines.map(\.message) == [
            "load things started",
            "load things started (pull)",
            "load things processed",
            "load things processed (3 lists)",
            "load things skipped (already refreshing)",
            "load things cancelled"
        ])
        #expect(sink.lines.allSatisfy { $0.level == .debug && $0.category == .business })
    }

    @Test("failed logs one error line in verbose mode")
    func failedVerbose() {
        let (log, sink) = make(verbose: true)
        log.failed("load things")
        #expect(sink.lines == [.init(level: .error, message: "load things failed", category: .business)])
    }

    @Test("non-verbose mode logs only the failure line")
    func nonVerbose() {
        let (log, sink) = make(verbose: false)
        log.started("op", reason: .appear)
        log.processed("op", count: 2, noun: "items")
        log.skipped("op")
        log.cancelled("op")
        #expect(sink.lines.isEmpty)
        log.failed("op")
        #expect(sink.lines.map(\.message) == ["op failed"])
        #expect(sink.lines.map(\.level) == [.error])
    }

    @Test("cancelled is never an error level")
    func cancelledIsNotError() {
        let (log, sink) = make(verbose: true)
        log.cancelled("op")
        #expect(!sink.lines.contains { $0.level == .error || $0.level == .critical })
    }

    @Test("every refresh reason has a fixed raw value")
    func reasonRawValues() {
        #expect(RefreshReason.pull.rawValue == "pull")
        #expect(RefreshReason.appear.rawValue == "appear")
        #expect(RefreshReason.tab.rawValue == "tab")
        #expect(RefreshReason.session.rawValue == "session")
        #expect(RefreshReason.unspecified.rawValue == "unspecified")
    }
}
