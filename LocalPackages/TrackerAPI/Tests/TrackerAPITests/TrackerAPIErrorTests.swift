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

    // NOTE: 1007 is UNUSED per Docs/error-codes.md. The contract change removes it from
    // credential-failure set; it now falls through to the default (showMessage) bucket.
    @Test("Error code 1007 (UNUSED) is NOT a credential failure")
    func code1007IsNowNotCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1007) == false)
    }

    @Test("Error code 1013 (REFRESH_TOKEN_REUSED) is a credential failure")
    func code1013IsCredentialFailure() {
        #expect(isCredentialFailure(errorCode: 1013) == true)
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

    // MARK: - classifyErrorCode — reLogin

    @Test("Error code 1005 classifies as .reLogin")
    func classify1005ReLogin() {
        #expect(classifyErrorCode(errorCode: 1005) == .reLogin)
    }

    @Test("Error code 1006 classifies as .reLogin")
    func classify1006ReLogin() {
        #expect(classifyErrorCode(errorCode: 1006) == .reLogin)
    }

    @Test("Error code 1013 classifies as .reLogin")
    func classify1013ReLogin() {
        #expect(classifyErrorCode(errorCode: 1013) == .reLogin)
    }

    // MARK: - classifyErrorCode — refreshAndReplay

    @Test("Error code 1002 classifies as .refreshAndReplay")
    func classify1002RefreshAndReplay() {
        #expect(classifyErrorCode(errorCode: 1002) == .refreshAndReplay)
    }

    @Test("Error code 1003 classifies as .refreshAndReplay")
    func classify1003RefreshAndReplay() {
        #expect(classifyErrorCode(errorCode: 1003) == .refreshAndReplay)
    }

    @Test("Error code 1004 classifies as .refreshAndReplay")
    func classify1004RefreshAndReplay() {
        #expect(classifyErrorCode(errorCode: 1004) == .refreshAndReplay)
    }

    // MARK: - classifyErrorCode — forceUpdate

    @Test("Error code 1014 classifies as .forceUpdate")
    func classify1014ForceUpdate() {
        #expect(classifyErrorCode(errorCode: 1014) == .forceUpdate)
    }

    // MARK: - classifyErrorCode — notFound

    @Test("Error code 4001 classifies as .notFound")
    func classify4001NotFound() {
        #expect(classifyErrorCode(errorCode: 4001) == .notFound)
    }

    @Test("Error code 4002 classifies as .notFound")
    func classify4002NotFound() {
        #expect(classifyErrorCode(errorCode: 4002) == .notFound)
    }

    @Test("Error code 4003 classifies as .notFound")
    func classify4003NotFound() {
        #expect(classifyErrorCode(errorCode: 4003) == .notFound)
    }

    @Test("Error code 4004 classifies as .notFound")
    func classify4004NotFound() {
        #expect(classifyErrorCode(errorCode: 4004) == .notFound)
    }

    @Test("Error code 4005 classifies as .notFound")
    func classify4005NotFound() {
        #expect(classifyErrorCode(errorCode: 4005) == .notFound)
    }

    @Test("Error code 4006 classifies as .notFound")
    func classify4006NotFound() {
        #expect(classifyErrorCode(errorCode: 4006) == .notFound)
    }

    @Test("Error code 4007 classifies as .notFound")
    func classify4007NotFound() {
        #expect(classifyErrorCode(errorCode: 4007) == .notFound)
    }

    // 4009 MEMBER_EMAIL_NOT_FOUND: HTTP 404 but client action is "show message"
    // per Docs/error-codes.md — not "treat as not found". Gate 1 spec was wrong to
    // list it under notFound.
    @Test("Error code 4009 classifies as .showMessage (MEMBER_EMAIL_NOT_FOUND shows a message per error-codes.md)")
    func classify4009ShowMessage() {
        #expect(classifyErrorCode(errorCode: 4009) == .showMessage)
    }

    @Test("Error code 4010 classifies as .notFound")
    func classify4010NotFound() {
        #expect(classifyErrorCode(errorCode: 4010) == .notFound)
    }

    // MARK: - classifyErrorCode — backOff

    @Test("Error code 8001 classifies as .backOff")
    func classify8001BackOff() {
        #expect(classifyErrorCode(errorCode: 8001) == .backOff)
    }

    @Test("Error code 8002 classifies as .backOff")
    func classify8002BackOff() {
        #expect(classifyErrorCode(errorCode: 8002) == .backOff)
    }

    @Test("Error code 9001 classifies as .backOff")
    func classify9001BackOff() {
        #expect(classifyErrorCode(errorCode: 9001) == .backOff)
    }

    @Test("Error code 9002 classifies as .backOff")
    func classify9002BackOff() {
        #expect(classifyErrorCode(errorCode: 9002) == .backOff)
    }

    // MARK: - classifyErrorCode — showMessage (representative set)

    @Test("Error code 1001 classifies as .showMessage")
    func classify1001ShowMessage() {
        #expect(classifyErrorCode(errorCode: 1001) == .showMessage)
    }

    @Test("Error code 1008 classifies as .showMessage")
    func classify1008ShowMessage() {
        #expect(classifyErrorCode(errorCode: 1008) == .showMessage)
    }

    @Test("Error code 1009 classifies as .showMessage")
    func classify1009ShowMessage() {
        #expect(classifyErrorCode(errorCode: 1009) == .showMessage)
    }

    @Test("Error code 1017 classifies as .showMessage")
    func classify1017ShowMessage() {
        #expect(classifyErrorCode(errorCode: 1017) == .showMessage)
    }

    @Test("Error code 2001 classifies as .showMessage")
    func classify2001ShowMessage() {
        #expect(classifyErrorCode(errorCode: 2001) == .showMessage)
    }

    @Test("Error code 3001 classifies as .showMessage")
    func classify3001ShowMessage() {
        #expect(classifyErrorCode(errorCode: 3001) == .showMessage)
    }

    @Test("Error code 5001 classifies as .showMessage")
    func classify5001ShowMessage() {
        #expect(classifyErrorCode(errorCode: 5001) == .showMessage)
    }

    @Test("Error code 6003 classifies as .showMessage")
    func classify6003ShowMessage() {
        #expect(classifyErrorCode(errorCode: 6003) == .showMessage)
    }

    @Test("Unknown code 9999 classifies as .showMessage")
    func classify9999ShowMessage() {
        #expect(classifyErrorCode(errorCode: 9999) == .showMessage)
    }

    // MARK: - classifyErrorCode — 1007 UNUSED maps to showMessage

    @Test("Error code 1007 (UNUSED) classifies as .showMessage (default bucket)")
    func classify1007UnusedShowMessage() {
        #expect(classifyErrorCode(errorCode: 1007) == .showMessage)
    }
}
