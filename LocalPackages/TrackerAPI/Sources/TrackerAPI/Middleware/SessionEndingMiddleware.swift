// SessionEndingMiddleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Ends the session when an authenticated (non-public) operation returns
/// 403 ACCOUNT_DISABLED or 404 USER_NOT_FOUND (client guide section 4, C15).
///
/// Only 403 and 404 bodies are buffered. The body is peeked leniently for `error.errorCode`
/// and the response is returned with a rebuilt body of the same bytes, so the generated client
/// still decodes the typed `.forbidden` or `.notFound` output. The handler is called at most
/// once per response. Public operations (`publicOperationIDs`) pass through untouched.
/// The handler receives the bearer token of the request this middleware forwarded, so it must
/// sit inside BearerAuthMiddleware (see TrackerClientFactory).
public struct SessionEndingMiddleware: ClientMiddleware {
    private let handler: any SessionEnding

    public init(handler: any SessionEnding) {
        self.handler = handler
    }

    // @Instrumented is not used: TrackerAPI is a Swift package with no Sentry dependency
    // (see I1-a epic: "The package has no Sentry dependency"). The convention rule
    // applies to app-layer service and repository types only.
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        if publicOperationIDs.contains(operationID) {
            return try await next(request, body, baseURL)
        }

        let (response, responseBody) = try await next(request, body, baseURL)
        let statusCode = response.status.code
        guard statusCode == 403 || statusCode == 404, let responseBody else {
            return (response, responseBody)
        }

        // Buffer the full body so we can peek at it and return it to the caller
        var bufferedData = Data()
        for try await chunk in responseBody {
            bufferedData.append(contentsOf: chunk)
        }

        if let reason = Self.reason(statusCode: statusCode, data: bufferedData) {
            await handler.sessionEnded(reason: reason, requestToken: Self.bearerToken(in: request))
        }

        // Return the response with a rebuilt readable body of the same bytes
        return (response, HTTPBody(bufferedData))
    }

    /// The bearer token of the request this middleware forwarded: the text after the exact
    /// prefix `"Bearer "` in its Authorization header. Nil when the header is absent, does not
    /// start with that prefix, or has nothing after it. The value is never logged.
    private static func bearerToken(in request: HTTPRequest) -> String? {
        let prefix = "Bearer "
        guard let value = request.headerFields[.authorization], value.hasPrefix(prefix) else {
            return nil
        }
        let token = String(value.dropFirst(prefix.count))
        return token.isEmpty ? nil : token
    }

    private static func reason(statusCode: Int, data: Data) -> SessionEndReason? {
        guard let envelope = try? JSONDecoder().decode(ErrorEnvelopePeek.self, from: data),
              let errorCode = envelope.error?.errorCode else {
            return nil
        }
        switch (statusCode, errorCode) {
        case (403, "ACCOUNT_DISABLED"):
            return .accountDisabled
        case (404, "USER_NOT_FOUND"):
            return .userNotFound
        default:
            return nil
        }
    }
}

/// Lenient view of the error envelope: only `error.errorCode` is read; every field is optional
/// and any other content is ignored.
private struct ErrorEnvelopePeek: Decodable {
    struct ErrorBody: Decodable {
        let errorCode: String?
    }

    let error: ErrorBody?
}
