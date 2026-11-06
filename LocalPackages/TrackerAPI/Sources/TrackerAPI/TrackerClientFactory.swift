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

        let middleware: [any ClientMiddleware] = [
            HeadersMiddleware(info: info, requestIDObserver: requestIDObserver),
            RefreshOn401Middleware(refresher: sessionRefresher, tokenProvider: tokenProvider),
            RateLimitMiddleware(),
            VersionOutdatedMiddleware(handler: versionOutdatedHandler),
            BearerAuthMiddleware(tokenProvider: tokenProvider)
        ]
        return Client(
            serverURL: serverURL,
            configuration: Configuration(dateTranscoder: TrackerDateTranscoder()),
            transport: resolvedTransport,
            middlewares: middleware
        )
    }
}
