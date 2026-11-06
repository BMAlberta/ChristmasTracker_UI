// GeneratedClientAppVersionRepository.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import TrackerAPI
import TrackerInstrumentation

final class GeneratedClientAppVersionRepository: AppVersionChecking {
    private let client: any APIProtocol
    private let info: AppClientInfo
    // nonisolated(unsafe): written and read only within checkVersion(), which is called in
    // sequence by callers; no concurrent mutation in practice.
    nonisolated(unsafe) private var cachedPolicy: VersionPolicy?

    // nonisolated init: stores parameters only; no main-actor state touched.
    nonisolated init(client: any APIProtocol, info: AppClientInfo) {
        self.client = client
        self.info = info
    }

    @Instrumented
    func checkVersion() async throws -> VersionPolicy {
        let input = Operations.CheckAppVersion.Input(
            query: .init(
                platform: "ios",
                version: info.version,
                build: Int(info.build)
            ),
            headers: .init(accept: [])
        )
        let output = try await client.checkAppVersion(input)
        switch output {
        case .ok(let ok):
            let data = try ok.body.json.data
            let policy = VersionPolicy(
                state: mapState(data.state),
                minimumVersion: data.minimumVersion,
                recommendedVersion: data.recommendedVersion,
                latestVersion: data.latestVersion,
                minimumBuild: data.minimumBuild,
                latestBuild: data.latestBuild,
                manifestURL: data.manifestUrl.flatMap { URL(string: $0) },
                ipaURL: data.ipaUrl.flatMap { URL(string: $0) },
                releaseNotes: data.releaseNotes,
                enabled: data.enabled,
                updatedAt: data.updatedAt
            )
            cachedPolicy = policy
            return policy
        case .notModified:
            if let cached = cachedPolicy { return cached }
            throw TrackerAPIError.undocumented(status: 304)
        case .badRequest(let r):
            let err = try r.body.json
            throw TrackerAPIError.validation(err.error.message)
        case .tooManyRequests(let r):
            let err = try r.body.json
            // RateLimitMiddleware retries exhaust before reaching here; this is a defensive fallback.
            throw TrackerAPIError.rateLimited(retryAfter: TimeInterval(err.error.code))
        case .internalServerError:
            throw TrackerAPIError.server(500)
        case .undocumented(let statusCode, _):
            throw TrackerAPIError.undocumented(status: statusCode)
        }
    }
}

private func mapState(
    _ state: Operations.CheckAppVersion.Output.Ok.Body.JsonPayload.DataPayload.StatePayload
) -> VersionPolicyState {
    switch state {
    case .ok: return .ok
    case .updateRecommended: return .updateRecommended
    case .forceUpdate: return .forceUpdate
    }
}
