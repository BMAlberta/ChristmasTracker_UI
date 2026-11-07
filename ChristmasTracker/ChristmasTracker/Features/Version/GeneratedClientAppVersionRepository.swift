// GeneratedClientAppVersionRepository.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation
import OpenAPIRuntime
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
        let output: Operations.CheckAppVersion.Output
        do {
            output = try await client.checkAppVersion(input)
        } catch let clientError as ClientError {
            // RateLimitMiddleware throws TrackerAPIError.rateLimited once its retries are
            // exhausted; the OpenAPI runtime wraps it in ClientError. Unwrap only that case so
            // VersionService can back off. Every other ClientError is rethrown unchanged.
            if let apiError = clientError.underlyingError as? TrackerAPIError,
               case .rateLimited = apiError {
                throw apiError
            }
            throw clientError
        }
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
            // Reached only when no RateLimitMiddleware handled the 429. No cap is applied here;
            // only RateLimitMiddleware caps a single wait.
            throw TrackerAPIError.rateLimited(retryAfter: retryAfterSeconds(from: err.error.details))
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

/// Reads `retryAfter` (seconds) from the free-form `error.details` of the generated Error schema.
/// Accepts an integer or floating-point JSON number. Anything else (no details, no key, or a
/// non-number such as a string or boolean) falls back to 1 second, the package default used by
/// `TrackerAPIError` (TrackerAPIError.swift:83, `retryAfter ?? 1`) and `RateLimitMiddleware`
/// (RateLimitMiddleware.swift:69, `?? 1.0`).
private nonisolated func retryAfterSeconds(
    from details: Components.Schemas._Error._ErrorPayload.DetailsPayload?
) -> TimeInterval {
    let packageDefault: TimeInterval = 1
    guard let raw = details?.additionalProperties.value["retryAfter"] ?? nil else {
        return packageDefault
    }
    if raw is Bool { return packageDefault }
    if let seconds = raw as? Int { return TimeInterval(seconds) }
    if let seconds = raw as? Double { return seconds }
    return packageDefault
}
