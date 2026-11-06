// APIModeResolverTests.swift
// ChristmasTrackerTests
//
// Failing tests for Story B2 — Interface 1: resolveAPIMode(infoValue:override:environment:)
// and Interface 2: makeClientInfo(from:).
//
// These tests will fail to compile until the implementer adds the production symbols.

import Testing
import Foundation
import TrackerAPI
@testable import ChristmasTracker

// MARK: - resolveAPIMode Tests

@Suite("resolveAPIMode Tests")
struct APIModeResolverTests {

    // MARK: - Production environment: infoValue always wins

    @Test("production + info=mock + override=real → .mock (info wins)")
    func productionInfoMockOverrideReal() {
        let result = resolveAPIMode(infoValue: "mock", override: "real", environment: "production")
        #expect(result == .mock)
    }

    @Test("production + info=real + override=mock → .real (info wins)")
    func productionInfoRealOverrideMock() {
        let result = resolveAPIMode(infoValue: "real", override: "mock", environment: "production")
        #expect(result == .real)
    }

    @Test("production + info=mock + override=garbage → .mock (override ignored)")
    func productionInfoMockOverrideGarbage() {
        let result = resolveAPIMode(infoValue: "mock", override: "garbage", environment: "production")
        #expect(result == .mock)
    }

    // MARK: - Non-production: recognized override wins

    @Test("development + info=mock + override=real → .real (override wins)")
    func developmentInfoMockOverrideReal() {
        let result = resolveAPIMode(infoValue: "mock", override: "real", environment: "development")
        #expect(result == .real)
    }

    @Test("development + info=real + override=mock → .mock (override wins)")
    func developmentInfoRealOverrideMock() {
        let result = resolveAPIMode(infoValue: "real", override: "mock", environment: "development")
        #expect(result == .mock)
    }

    // MARK: - Non-production: nil or empty override falls back to infoValue

    @Test("development + info=mock + override=nil → .mock (info used)")
    func developmentInfoMockOverrideNil() {
        let result = resolveAPIMode(infoValue: "mock", override: nil, environment: "development")
        #expect(result == .mock)
    }

    @Test("development + info=nil + override=nil → .real (nil info defaults to real)")
    func developmentNilInfoNilOverride() {
        let result = resolveAPIMode(infoValue: nil, override: nil, environment: "development")
        #expect(result == .real)
    }

    // MARK: - Non-production: unrecognized override falls back to infoValue

    @Test("development + info=mock + override=garbage → .mock (bad override ignored, info wins)")
    func developmentInfoMockOverrideGarbage() {
        let result = resolveAPIMode(infoValue: "mock", override: "garbage", environment: "development")
        #expect(result == .mock)
    }

    // MARK: - Non-production: case-insensitive override matching

    @Test("qa + info=mock + override=REAL (uppercase) → .real (case-insensitive)")
    func qaInfoMockOverrideUppercaseReal() {
        let result = resolveAPIMode(infoValue: "mock", override: "REAL", environment: "qa")
        #expect(result == .real)
    }

    @Test("qa + info=mock + override=MOCK (uppercase) → .mock (case-insensitive)")
    func qaInfoMockOverrideUppercaseMock() {
        let result = resolveAPIMode(infoValue: "mock", override: "MOCK", environment: "qa")
        #expect(result == .mock)
    }
}

// MARK: - makeClientInfo Tests

@Suite("makeClientInfo Tests")
struct MakeClientInfoTests {

    // MARK: Helper
    private func makeSUT(info: [String: Any]?) -> AppClientInfo {
        makeClientInfo(from: info)
    }

    // MARK: - Both keys present

    @Test("both CFBundleShortVersionString and CFBundleVersion present → returns correct version and build")
    func bothKeysPresentReturnsCorrectValues() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "2.1.0",
            "CFBundleVersion": "42"
        ]
        let clientInfo = makeSUT(info: info)
        #expect(clientInfo.version == "2.1.0")
        #expect(clientInfo.build == "42")
    }

    // MARK: - Both keys absent

    @Test("nil info → version and build both fall back to 0")
    func nilInfoFallsBackToZero() {
        let clientInfo = makeSUT(info: nil)
        #expect(clientInfo.version == "0")
        #expect(clientInfo.build == "0")
    }

    @Test("empty dict → version and build both fall back to 0")
    func emptyDictFallsBackToZero() {
        let clientInfo = makeSUT(info: [:])
        #expect(clientInfo.version == "0")
        #expect(clientInfo.build == "0")
    }

    // MARK: - Only version present

    @Test("only CFBundleShortVersionString present → correct version, build falls back to 0")
    func onlyVersionPresent() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.3.5"]
        let clientInfo = makeSUT(info: info)
        #expect(clientInfo.version == "1.3.5")
        #expect(clientInfo.build == "0")
    }

    // MARK: - platform and clientPlatform are always "ios"

    @Test("platform is always ios regardless of info dict")
    func platformIsAlwaysIOS() {
        let clientInfo = makeSUT(info: nil)
        #expect(clientInfo.platform == "ios")
    }

    @Test("clientPlatform is always ios regardless of info dict")
    func clientPlatformIsAlwaysIOS() {
        let clientInfo = makeSUT(info: nil)
        #expect(clientInfo.clientPlatform == "ios")
    }

    @Test("platform and clientPlatform are ios even when both bundle keys present")
    func platformAndClientPlatformAreIOSWhenKeysPresent() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "3.0.0",
            "CFBundleVersion": "100"
        ]
        let clientInfo = makeSUT(info: info)
        #expect(clientInfo.platform == "ios")
        #expect(clientInfo.clientPlatform == "ios")
    }
}
