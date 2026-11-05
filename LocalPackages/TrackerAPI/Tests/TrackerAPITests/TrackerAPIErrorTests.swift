// TrackerAPIErrorTests.swift
// Christmas Tracker
// Copyright © 2026 BMAlberta. All rights reserved.

import Testing
import Foundation
import TrackerAPI

@Suite("TrackerAPIError — error code mapping")
struct TrackerAPIErrorTests {

    // MARK: - Credential failure codes map to .unauthorized / isCredentialFailure == true

    @Test("Error code 1005 (REFRESH_TOKEN_EXPIRED) is a credential failure")
    func code1005IsCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1005) == true)
    }

    @Test("Error code 1006 (REFRESH_TOKEN_INVALID) is a credential failure")
    func code1006IsCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1006) == true)
    }

    @Test("Error code 1007 (SESSION_EXPIRED) is a credential failure")
    func code1007IsCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1007) == true)
    }

    // MARK: - Non-credential codes are NOT credential failures

    @Test("Error code 1001 (INVALID_CREDENTIALS) is NOT a credential failure")
    func code1001IsNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1001) == false)
    }

    @Test("Error code 1002 (TOKEN_EXPIRED) is NOT a credential failure")
    func code1002IsNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1002) == false)
    }

    @Test("Error code 1003 (TOKEN_INVALID) is NOT a credential failure")
    func code1003IsNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1003) == false)
    }

    @Test("Error code 1004 (TOKEN_MISSING) is NOT a credential failure")
    func code1004IsNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1004) == false)
    }

    @Test("Error code 1008 (ACCOUNT_DISABLED) is NOT a credential failure")
    func code1008IsNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1008) == false)
    }

    // MARK: - HTTP status → TrackerAPIError mapping

    @Test("HTTP 403 maps to TrackerAPIError.forbidden")
    func http403MapsForbidden() {
        let error = mapHTTPStatus(403, retryAfter: nil, versionDetails: nil)
        if case .forbidden = error {
            // Expected
        } else {
            Issue.record("Expected .forbidden but got \(error)")
        }
    }

    @Test("HTTP 404 maps to TrackerAPIError.notFound")
    func http404MapsNotFound() {
        let error = mapHTTPStatus(404, retryAfter: nil, versionDetails: nil)
        if case .notFound = error {
            // Expected
        } else {
            Issue.record("Expected .notFound but got \(error)")
        }
    }

    @Test("HTTP 409 maps to TrackerAPIError.conflict")
    func http409MapsConflict() {
        let error = mapHTTPStatus(409, retryAfter: nil, versionDetails: nil)
        if case .conflict = error {
            // Expected
        } else {
            Issue.record("Expected .conflict but got \(error)")
        }
    }

    @Test("HTTP 429 maps to TrackerAPIError.rateLimited with retryAfter value")
    func http429MapsRateLimited() {
        let error = mapHTTPStatus(429, retryAfter: 5.0, versionDetails: nil)
        if case .rateLimited(let retryAfter) = error {
            #expect(retryAfter == 5.0)
        } else {
            Issue.record("Expected .rateLimited but got \(error)")
        }
    }

    @Test("HTTP 426 maps to TrackerAPIError.versionOutdated")
    func http426MapsVersionOutdated() {
        let details = VersionOutdatedDetails(
            minimumVersion: "2.0.0",
            minimumBuild: 10,
            latestVersion: "2.1.0",
            latestBuild: 20,
            manifestUrl: nil,
            ipaUrl: nil
        )
        let error = mapHTTPStatus(426, retryAfter: nil, versionDetails: details)
        if case .versionOutdated(let d) = error {
            #expect(d.minimumVersion == "2.0.0")
        } else {
            Issue.record("Expected .versionOutdated but got \(error)")
        }
    }

    @Test("HTTP 500 maps to TrackerAPIError.server(500)")
    func http500MapsServer500() {
        let error = mapHTTPStatus(500, retryAfter: nil, versionDetails: nil)
        if case .server(let code) = error {
            #expect(code == 500)
        } else {
            Issue.record("Expected .server(500) but got \(error)")
        }
    }

    @Test("HTTP 503 maps to TrackerAPIError.server(503)")
    func http503MapsServer503() {
        let error = mapHTTPStatus(503, retryAfter: nil, versionDetails: nil)
        if case .server(let code) = error {
            #expect(code == 503)
        } else {
            Issue.record("Expected .server(503) but got \(error)")
        }
    }

    @Test("HTTP 418 (unexpected) maps to TrackerAPIError.undocumented(status: 418)")
    func http418MapsUndocumented() {
        let error = mapHTTPStatus(418, retryAfter: nil, versionDetails: nil)
        if case .undocumented(let status) = error {
            #expect(status == 418)
        } else {
            Issue.record("Expected .undocumented(status: 418) but got \(error)")
        }
    }
}
