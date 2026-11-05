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
        requestIDObserver: (any RequestIDObserving)? = nil
    ) -> Client {
        let session = URLSession(configuration: TrackerURLSessionConfiguration.make())
        let transport = URLSessionTransport(configuration: .init(session: session))
        let middleware: [any ClientMiddleware] = [
            HeadersMiddleware(info: info, requestIDObserver: requestIDObserver),
            RefreshOn401Middleware(refresher: sessionRefresher, tokenProvider: tokenProvider),
            RateLimitMiddleware(),
            VersionOutdatedMiddleware(handler: versionOutdatedHandler),
            BearerAuthMiddleware(tokenProvider: tokenProvider)
        ]
        return Client(serverURL: serverURL, transport: transport, middlewares: middleware)
    }
}
