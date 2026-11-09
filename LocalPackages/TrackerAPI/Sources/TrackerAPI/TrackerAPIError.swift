// TrackerAPIError.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Foundation

public enum TrackerAPIError: Error, Sendable {
    case unauthorized
    case forbidden
    case invalidServerURL
    case notFound
    case conflict
    case validation(String)
    case rateLimited(retryAfter: TimeInterval)
    case versionOutdated(VersionOutdatedDetails)
    case server(Int)
    case network(Error)
    case decoding(Error)
    case undocumented(status: Int)
}

/// Returns true for error codes that indicate the refresh token is permanently invalid.
/// These codes mean: show login screen, do not retry with the same credentials.
public func isCredentialFailure(errorCode: Int) -> Bool {
    switch errorCode {
    case 1005, // REFRESH_TOKEN_EXPIRED
         1006, // REFRESH_TOKEN_INVALID
         1013: // REFRESH_TOKEN_MISSING
        return true
    default:
        return false
    }
}

public enum ErrorCodeClassification: Sendable, Equatable {
    case reLogin
    case refreshAndReplay
    case forceUpdate
    case notFound
    case backOff
    case showMessage
}

public func classifyErrorCode(errorCode: Int) -> ErrorCodeClassification {
    switch errorCode {
    case 1005, 1006, 1013,
         1008, // ACCOUNT_DISABLED
         4002: // USER_NOT_FOUND
        return .reLogin
    case 1002, 1003, 1004:
        return .refreshAndReplay
    case 1014:
        return .forceUpdate
    case 4001, 4003, 4004, 4005, 4006, 4007, 4010, 4011: // 4011 PERSON_NOT_FOUND
        return .notFound
    case 8001, 8002, 9001, 9002:
        return .backOff
    default:
        return .showMessage
    }
}

/// Maps an HTTP status code to a TrackerAPIError.
public func mapHTTPStatus(
    _ status: Int,
    retryAfter: TimeInterval?,
    versionDetails: VersionOutdatedDetails?
) -> TrackerAPIError {
    switch status {
    case 401: return .unauthorized
    case 403: return .forbidden
    case 404: return .notFound
    case 409: return .conflict
    case 426:
        return .versionOutdated(
            versionDetails ?? VersionOutdatedDetails(
                minimumVersion: "",
                minimumBuild: nil,
                latestVersion: nil,
                latestBuild: nil,
                manifestUrl: nil,
                ipaUrl: nil
            )
        )
    case 429: return .rateLimited(retryAfter: retryAfter ?? 1)
    case 400: return .validation("validation error")
    case 422: return .validation("unprocessable entity")
    case 500...599: return .server(status)
    default: return .undocumented(status: status)
    }
}
