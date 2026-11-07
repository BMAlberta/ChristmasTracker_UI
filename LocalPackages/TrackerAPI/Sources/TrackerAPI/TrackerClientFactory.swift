// TrackerClientFactory.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

public enum TrackerClientFactory {
    public static func make(
        serverURL: URL,
        info: AppClientInfo,
        tokenProvider: any AccessTokenProviding,
        sessionRefresher: any SessionRefreshing,
        versionOutdatedHandler: any VersionOutdatedHandling,
        requestIDObserver: (any RequestIDObserving)? = nil,
        sessionEndingHandler: (any SessionEnding)? = nil,
        transport: (any ClientTransport)? = nil
    ) throws -> Client {
        let scheme = serverURL.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else {
            throw TrackerAPIError.invalidServerURL
        }
        guard let host = serverURL.host, !host.isEmpty else {
            throw TrackerAPIError.invalidServerURL
        }
        let path = serverURL.path
        guard path.isEmpty || path == "/" else {
            throw TrackerAPIError.invalidServerURL
        }

        let resolvedTransport: any ClientTransport
        if let injected = transport {
            resolvedTransport = injected
        } else {
            let session = URLSession(configuration: TrackerURLSessionConfiguration.make())
            resolvedTransport = URLSessionTransport(configuration: .init(session: session))
        }

        // Middleware order (outermost first; each wraps the ones after it):
        // 1. Headers: adds the platform, build, and version headers and observes the request ID.
        // 2. RefreshOn401: on a 401, refreshes once and replays through everything below it, so
        //    the replay passes through BearerAuth again and carries the fresh token.
        // 3. RateLimit: handles 429 (retry where safe, otherwise TrackerAPIError.rateLimited).
        // 4. VersionOutdated: reports a 426 to the version gate.
        // 5. SessionEnding (only when a handler is given): inside RefreshOn401 and RateLimit, so
        //    it inspects every 403 or 404 that comes back from the server, including one returned
        //    to a replay; a 403 or 404 is never retried, so the handler runs at most once per
        //    response. It is non-throwing and returns the body intact for the typed decoder.
        // 6. BearerAuth: innermost, so every attempt (including replays) reads the current token.
        var middleware: [any ClientMiddleware] = [
            HeadersMiddleware(info: info, requestIDObserver: requestIDObserver),
            RefreshOn401Middleware(refresher: sessionRefresher, tokenProvider: tokenProvider),
            RateLimitMiddleware(),
            VersionOutdatedMiddleware(handler: versionOutdatedHandler)
        ]
        if let sessionEndingHandler {
            middleware.append(SessionEndingMiddleware(handler: sessionEndingHandler))
        }
        middleware.append(BearerAuthMiddleware(tokenProvider: tokenProvider))
        return Client(
            serverURL: serverURL,
            configuration: Configuration(dateTranscoder: TrackerDateTranscoder()),
            transport: resolvedTransport,
            middlewares: middleware
        )
    }
}
