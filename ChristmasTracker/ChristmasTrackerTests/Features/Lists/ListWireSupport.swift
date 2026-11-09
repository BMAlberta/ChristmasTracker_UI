//
//  ListWireSupport.swift
//  ChristmasTrackerTests
//
//  Story I3a-L2: shared support for the list repository tests.
//
//  - `ListWire`: literal, guide-accurate JSON envelopes (success, error, message) including the
//    full `meta` object, built around the `ListFixtures` list and detail payloads.
//  - `ListFakeTransport`: a recording fake `ClientTransport` that plays scripted responses (or a
//    scripted throw) and captures the request line, headers and body bytes.
//  - Small fakes for the factory seams (token provider, session refresher, version handler).
//
//  All ids, names and addresses are fake. No real tokens.
//

import Foundation
import HTTPTypes
import OpenAPIRuntime
import TrackerAPI
@testable import ChristmasTracker

// MARK: - ListWire

nonisolated enum ListWire {

    /// The full `meta` object required by the generated schema (fractional-seconds timestamp).
    static let metaJSON = """
    {
      "timestamp": "2026-11-02T00:00:00.000Z",
      "requestId": "req-00000001",
      "sessionId": "sess-00000001"
    }
    """

    static func text(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    /// `{success: true, data: <data>, meta}` where `data` is already JSON text.
    static func success(data: String) -> String {
        """
        {
          "success": true,
          "data": \(data),
          "meta": \(metaJSON)
        }
        """
    }

    /// 200 body of GET /lists: an array of ListSummary (no `members` key).
    static func listsJSON(_ specs: [ListFixtures.Spec]) throws -> String {
        let items = try specs.map { text(try ListFixtures.summaryData($0)) }
        return success(data: "[" + items.joined(separator: ",") + "]")
    }

    /// 200/201 body carrying one ListDetail (`members` present only when the spec has them).
    static func detailJSON(_ spec: ListFixtures.Spec) throws -> String {
        success(data: text(try ListFixtures.detailData(spec)))
    }

    /// Same as `detailJSON` but with an explicit JSON `null` theme (the contract marks theme
    /// required and nullable).
    static func detailJSONWithNullTheme(_ spec: ListFixtures.Spec) throws -> String {
        guard var object = try JSONSerialization.jsonObject(with: ListFixtures.detailData(spec)) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        object["theme"] = NSNull()
        return success(data: text(try JSONSerialization.data(withJSONObject: object)))
    }

    /// 200 body of DELETE /lists/{id}: only a message.
    static func messageJSON(_ message: String = "List deleted") -> String {
        success(data: "{ \"message\": \"\(message)\" }")
    }

    /// The error envelope (client guide section 4) with the full `meta`.
    static func errorJSON(code: Int, errorCode: String, message: String, details: String? = nil) -> String {
        let detailsPart = details.map { ",\n    \"details\": \($0)" } ?? ""
        return """
        {
          "success": false,
          "error": {
            "code": \(code),
            "errorCode": "\(errorCode)",
            "message": "\(message)"\(detailsPart)
          },
          "meta": \(metaJSON)
        }
        """
    }

    // MARK: Documented error bodies

    static let tokenExpired = errorJSON(code: 1002, errorCode: "TOKEN_EXPIRED", message: "Your session has expired")
    static let notListOwner = errorJSON(code: 2003, errorCode: "NOT_LIST_OWNER", message: "Only the list owner can perform this action")
    static let listNotFound = errorJSON(code: 4003, errorCode: "LIST_NOT_FOUND", message: "List not found")
    static let recipientNotFound = errorJSON(code: 4010, errorCode: "RECIPIENT_NOT_FOUND", message: "Recipient not found")
    /// Same shape as `recipientNotFound`, different code (a plain not-found that must stay `.notFound`).
    static let personNotFound = errorJSON(code: 4011, errorCode: "PERSON_NOT_FOUND", message: "Recipient not found")
    static let listAlreadyExists = errorJSON(code: 5002, errorCode: "LIST_ALREADY_EXISTS", message: "List already exists")
    static let archivedList = errorJSON(code: 6402, errorCode: "CANNOT_EDIT_ARCHIVED_LIST", message: "Cannot edit an archived list")
    static let internalError = errorJSON(code: 9000, errorCode: "INTERNAL_ERROR", message: "Unexpected server error")
    static let rateLimit = errorJSON(code: 8001, errorCode: "RATE_LIMIT_EXCEEDED", message: "Too many requests. Please try again later")

    // MARK: HTTP helpers

    static func response(_ status: Int, retryAfter: String? = nil) -> HTTPResponse {
        var fields = HTTPFields()
        if let retryAfter, let name = HTTPField.Name("Retry-After") {
            fields[name] = retryAfter
        }
        return HTTPResponse(status: .init(code: status), headerFields: fields)
    }

    static func headerName(_ name: String) -> HTTPField.Name? {
        HTTPField.Name(name)
    }
}

// MARK: - ListFakeTransport

actor ListFakeTransport: ClientTransport {

    nonisolated struct Recorded: Sendable {
        let request: HTTPRequest
        let bodyData: Data?
        let operationID: String

        /// The request path without any query string.
        var pathOnly: String {
            let path = request.path ?? ""
            return String(path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        }

        /// True when the request line carries a query string of any kind.
        var hasQuery: Bool { (request.path ?? "").contains("?") }

        /// The JSON body decoded as a dictionary (nil when there is no body or it is not an object).
        var jsonObject: [String: Any]? {
            guard let bodyData else { return nil }
            return (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any]
        }
    }

    private var scripted: [(HTTPResponse, HTTPBody?)] = []
    private var scriptedThrow: (any Error)?
    private(set) var recorded: [Recorded] = []

    /// Queues `times` copies of the same response (a fresh body each time).
    func enqueue(status: Int, json: String, retryAfter: String? = nil, times: Int = 1) {
        for _ in 0..<times {
            scripted.append((ListWire.response(status, retryAfter: retryAfter), HTTPBody(json)))
        }
    }

    /// Queues a response with no body.
    func enqueueEmpty(status: Int) {
        scripted.append((ListWire.response(status), nil))
    }

    func enqueueThrow(_ error: any Error) {
        scriptedThrow = error
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var data: Data?
        if let body {
            var collected = Data()
            for try await chunk in body {
                collected.append(contentsOf: chunk)
            }
            data = collected
        }
        recorded.append(Recorded(request: request, bodyData: data, operationID: operationID))
        if let toThrow = scriptedThrow {
            scriptedThrow = nil
            throw toThrow
        }
        if scripted.isEmpty {
            return (HTTPResponse(status: .ok), nil)
        }
        return scripted.removeFirst()
    }

    var requestCount: Int { recorded.count }
    func lastRequest() -> Recorded? { recorded.last }
}

// MARK: - Seam fakes

nonisolated struct ListFakeTokenProvider: AccessTokenProviding {
    let token: String?
    func accessToken() async -> String? { token }
}

/// Records how many times the middleware asked for a refresh; optionally fails each refresh.
actor ListFakeRefresher: SessionRefreshing {
    private let failure: (any Error)?
    private(set) var callCount = 0

    init(failure: (any Error)? = nil) {
        self.failure = failure
    }

    func refresh() async throws {
        callCount += 1
        if let failure { throw failure }
    }
}

nonisolated struct ListFakeVersionHandler: VersionOutdatedHandling {
    func handleVersionOutdated(_ details: VersionOutdatedDetails) async {}
}
