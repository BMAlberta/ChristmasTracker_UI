// HeadersMiddleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

private let xPlatform: HTTPField.Name = {
    guard let n = HTTPField.Name("X-Platform") else {
        preconditionFailure("X-Platform is not a valid HTTP header field name")
    }
    return n
}()
private let xBuild: HTTPField.Name = {
    guard let n = HTTPField.Name("X-Build") else {
        preconditionFailure("X-Build is not a valid HTTP header field name")
    }
    return n
}()
private let xAppVersion: HTTPField.Name = {
    guard let n = HTTPField.Name("X-App-Version") else {
        preconditionFailure("X-App-Version is not a valid HTTP header field name")
    }
    return n
}()
private let xClientPlatform: HTTPField.Name = {
    guard let n = HTTPField.Name("X-Client-Platform") else {
        preconditionFailure("X-Client-Platform is not a valid HTTP header field name")
    }
    return n
}()
private let xRequestId: HTTPField.Name = {
    guard let n = HTTPField.Name("X-Request-Id") else {
        preconditionFailure("X-Request-Id is not a valid HTTP header field name")
    }
    return n
}()

public struct HeadersMiddleware: ClientMiddleware {
    private let info: AppClientInfo
    private let requestIDObserver: (any RequestIDObserving)?

    public init(info: AppClientInfo, requestIDObserver: (any RequestIDObserving)? = nil) {
        self.info = info
        self.requestIDObserver = requestIDObserver
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var req = request
        req.headerFields[xPlatform] = info.platform
        req.headerFields[xBuild] = info.build
        req.headerFields[xAppVersion] = info.version
        req.headerFields[xClientPlatform] = info.clientPlatform
        let requestID = UUID().uuidString
        req.headerFields[xRequestId] = requestID
        await requestIDObserver?.observe(requestID: requestID)
        return try await next(req, body, baseURL)
    }
}
