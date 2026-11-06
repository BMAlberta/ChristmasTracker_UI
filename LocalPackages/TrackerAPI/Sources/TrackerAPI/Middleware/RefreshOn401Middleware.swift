// RefreshOn401Middleware.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import HTTPTypes
import OpenAPIRuntime

// NSLock protects refreshTask; both are accessed only under the lock.
// @unchecked Sendable is required because NSLock and Task<Void, Error>? are not
// Sendable by themselves, but all mutation is protected by the lock.
public final class RefreshOn401Middleware: ClientMiddleware, @unchecked Sendable {
    private let refresher: any SessionRefreshing
    private let tokenProvider: any AccessTokenProviding
    private let lock = NSLock()
    private var refreshTask: Task<Void, Error>?

    public init(refresher: any SessionRefreshing, tokenProvider: any AccessTokenProviding) {
        self.refresher = refresher
        self.tokenProvider = tokenProvider
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
        // Public ops: pass through, never refresh
        if publicOperationIDs.contains(operationID) {
            return try await next(request, body, baseURL)
        }

        // Non-re-iterable body: cannot replay, surface error directly if 401
        if let body, body.iterationBehavior == .single {
            let (response, responseBody) = try await next(request, body, baseURL)
            if response.status.code == 401 {
                throw TrackerAPIError.unauthorized
            }
            return (response, responseBody)
        }

        // Capture the token used for this request so we can detect if it has already rotated
        let requestToken = await tokenProvider.accessToken()

        // First attempt
        let (firstResponse, firstBody) = try await next(request, body, baseURL)
        guard firstResponse.status.code == 401 else {
            return (firstResponse, firstBody)
        }

        // Got 401 — check if the token has already been rotated by a concurrent caller
        let currentToken = await tokenProvider.accessToken()
        if currentToken != requestToken {
            // Token already rotated — replay once with no refresh
            let (replayResponse, replayBody) = try await next(request, body, baseURL)
            if replayResponse.status.code == 401 {
                throw TrackerAPIError.unauthorized
            }
            return (replayResponse, replayBody)
        }

        // Token unchanged — proceed with single-flight refresh using NSLock
        let task: Task<Void, Error> = lock.withLock {
            if let existing = refreshTask {
                return existing
            }
            let newTask = Task { [refresher] in
                try await refresher.refresh()
            }
            refreshTask = newTask
            return newTask
        }

        do {
            try await task.value
        } catch let refreshError as SessionRefreshError {
            // Clear the failed task so the next 401 triggers a fresh attempt
            lock.withLock { refreshTask = nil }
            if case .credentialFailure = refreshError {
                throw TrackerAPIError.unauthorized
            }
            throw refreshError
        } catch {
            // Clear the failed task so the next 401 triggers a fresh attempt
            lock.withLock { refreshTask = nil }
            throw error
        }

        // Do NOT clear refreshTask on success — concurrent requests that also received a
        // 401 must be able to find and reuse the same completed task rather than triggering
        // a redundant second refresh. The completed task's result is cached by Swift; any
        // subsequent `await task.value` returns immediately.

        // Replay with new token (bearer middleware will pick up fresh token)
        let (replayResponse, replayBody) = try await next(request, body, baseURL)
        if replayResponse.status.code == 401 {
            throw TrackerAPIError.unauthorized
        }
        return (replayResponse, replayBody)
    }
}
