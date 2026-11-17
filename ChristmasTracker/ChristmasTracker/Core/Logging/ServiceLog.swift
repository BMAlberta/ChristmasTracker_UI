//
//  ServiceLog.swift
//  ChristmasTracker
//
//  The fixed step lines of a service operation: started, processed, skipped, cancelled, failed.
//  Only the operation name, a refresh reason, a count with a literal noun and fixed words ever go
//  into a line; never an error, id, year, name or amount. Per-step lines are Debug (verbose) only;
//  the failure line is written in every build, once per failure. Cancellation is never an error.
//

import Foundation

/// Why a refresh ran, when the caller knows.
nonisolated enum RefreshReason: String, Sendable {
    case pull
    case appear
    case tab
    case session
    case unspecified
}

nonisolated struct ServiceLog: Sendable {

    private let sink: any OperationLogging
    private let verbosity: LogVerbosity

    init(sink: any OperationLogging = AppOperationLog(), verbosity: LogVerbosity = .current) {
        self.sink = sink
        self.verbosity = verbosity
    }

    func started(_ op: String, reason: RefreshReason? = nil) {
        guard verbosity.isVerbose else { return }
        if let reason {
            sink.log(.debug, "\(op) started (\(reason.rawValue))", category: .business)
        } else {
            sink.log(.debug, "\(op) started", category: .business)
        }
    }

    /// `noun` is a literal such as "lists" or "items", never data.
    func processed(_ op: String, count: Int? = nil, noun: StaticString? = nil) {
        guard verbosity.isVerbose else { return }
        if let count, let noun {
            sink.log(.debug, "\(op) processed (\(count) \(noun))", category: .business)
        } else {
            sink.log(.debug, "\(op) processed", category: .business)
        }
    }

    func skipped(_ op: String) {
        guard verbosity.isVerbose else { return }
        sink.log(.debug, "\(op) skipped (already refreshing)", category: .business)
    }

    func cancelled(_ op: String) {
        guard verbosity.isVerbose else { return }
        sink.log(.debug, "\(op) cancelled", category: .business)
    }

    /// The one failure line of an operation; written in every build.
    func failed(_ op: String) {
        sink.log(.error, "\(op) failed", category: .business)
    }
}
