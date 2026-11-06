// BearerAuthMiddleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

public struct BearerAuthMiddleware: ClientMiddleware {
    private let tokenProvider: any AccessTokenProviding

    public init(tokenProvider: any AccessTokenProviding) {
        self.tokenProvider = tokenProvider
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard !publicOperationIDs.contains(operationID),
              let token = await tokenProvider.accessToken() else {
            return try await next(request, body, baseURL)
        }
        var req = request
        req.headerFields[.authorization] = "Bearer \(token)"
        return try await next(req, body, baseURL)
    }
}
