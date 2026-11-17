//
//  LoggingClientTransport.swift
//  ChristmasTracker
//
//  A ClientTransport that wraps another one and writes metadata-only lines to the operation log
//  (category .network). It sits below every middleware, so it sees each real attempt. Only the
//  operation id, method, attempt number, status, duration in ms, request id and a fixed error
//  category are ever put into a message. Bodies, URLs, paths, headers and error text never are.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession
import TrackerAPI

nonisolated final class LoggingClientTransport: ClientTransport, Sendable {

    private static let requestIDName = HTTPField.Name("X-Request-Id")

    private let inner: any ClientTransport
    private let log: any OperationLogging
    private let verbosity: LogVerbosity
    private let now: @Sendable () -> ContinuousClock.Instant
    private let attempts = AttemptCounter()

    init(
        wrapping inner: any ClientTransport,
        log: any OperationLogging,
        verbosity: LogVerbosity,
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now }
    ) {
        self.inner = inner
        self.log = log
        self.verbosity = verbosity
        self.now = now
    }

    /// The production transport: the URLSession transport built with the shared configuration.
    static func production() -> LoggingClientTransport {
        let session = URLSession(configuration: TrackerURLSessionConfiguration.make())
        return LoggingClientTransport(
            wrapping: URLSessionTransport(configuration: .init(session: session)),
            log: AppOperationLog(),
            verbosity: .current
        )
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let requestID = Self.requestIDName.flatMap { request.headerFields[$0] }
        let attempt = attempts.begin(id: requestID)
        if verbosity.isVerbose {
            let method = request.method.rawValue
            log.log(.debug, "\(operationID) request made (\(method), attempt \(attempt))", category: .network)
        }
        let start = now()
        do {
            let (response, responseBody) = try await inner.send(
                request, body: body, baseURL: baseURL, operationID: operationID
            )
            let ms = Self.milliseconds(from: start, to: now())
            let status = response.status.code
            attempts.finish(id: requestID, keep: status == 401 || status == 429)
            let responseID = Self.requestIDName.flatMap { response.headerFields[$0] }
            let loggable = [responseID, requestID].compactMap { $0 }.first(where: Self.isLoggable)
            logResponse(operationID: operationID, status: status, ms: ms, requestID: loggable)
            return (response, responseBody)
        } catch {
            let ms = Self.milliseconds(from: start, to: now())
            attempts.finish(id: requestID, keep: false)
            logFailure(operationID: operationID, error: error, ms: ms)
            throw error
        }
    }

    // MARK: - Logging

    private func logResponse(operationID: String, status: Int, ms: Int, requestID: String?) {
        let idPart = requestID.map { "request id \($0)" }
        let isProblem = status >= 400
        if verbosity.isVerbose {
            let parts = ["\(status)", "\(ms) ms"] + (idPart.map { [$0] } ?? [])
            log.log(isProblem ? .warning : .debug,
                    "\(operationID) response received (\(parts.joined(separator: ", ")))",
                    category: .network)
            return
        }
        guard isProblem, ![401, 404, 409, 426].contains(status) else { return }
        let parts = ["\(status)"] + (idPart.map { [$0] } ?? [])
        log.log(.warning, "\(operationID) response received (\(parts.joined(separator: ", ")))", category: .network)
    }

    private func logFailure(operationID: String, error: any Error, ms: Int) {
        if TransportErrorCategory.isCancellation(error) {
            if verbosity.isVerbose {
                log.log(.debug, "\(operationID) request cancelled (\(ms) ms)", category: .network)
            }
            return
        }
        let category = TransportErrorCategory.category(for: error)
        let detail = verbosity.isVerbose ? "\(category), \(ms) ms" : category
        log.log(.error, "\(operationID) request failed (\(detail))", category: .network)
    }

    /// Number of request ids currently tracked for attempt counting (test seam).
    var trackedRequestCount: Int { attempts.count }

    /// A request id is logged only if it is 1 to 64 characters, all in [A-Za-z0-9-].
    private static func isLoggable(_ id: String) -> Bool {
        guard (1...64).contains(id.utf8.count) else { return false }
        return id.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 45
        }
    }

    private static func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant) -> Int {
        let components = (end - start).components
        return Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}

/// Counts sends per request id so a replay (401) or retry (429) is a higher attempt number.
nonisolated private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    /// Ids in insertion order, oldest first; at most `limit` entries.
    private var order: [String] = []
    private let limit = 64

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return counts.count
    }

    /// Returns this send's attempt number and records it. No id means every send is attempt 1.
    /// When a 65th distinct id arrives the oldest is evicted.
    func begin(id: String?) -> Int {
        guard let id else { return 1 }
        lock.lock()
        defer { lock.unlock() }
        if let existing = counts[id] {
            counts[id] = existing + 1
            return existing + 1
        }
        if order.count >= limit {
            counts[order.removeFirst()] = nil
        }
        order.append(id)
        counts[id] = 1
        return 1
    }

    /// Discards the id unless the outcome invites another attempt (401 or 429).
    func finish(id: String?, keep: Bool) {
        guard let id, !keep else { return }
        lock.lock()
        defer { lock.unlock() }
        if counts.removeValue(forKey: id) != nil {
            order.removeAll { $0 == id }
        }
    }
}
